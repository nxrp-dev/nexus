(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupFileInstaller;

{$mode delphi}{$H+}

interface

uses obNXSetupModel, obNXSetupPlan;

type
  TNXSetupFileInstaller = class
  public
    class function Install(ADocument: TNXSetupDocument; APlan: TNXSetupPlan;
      const ARoot: string; const AArchiveFile: string = ''; ARepair: Boolean = False): string; static;
    class procedure Uninstall(const AStateFile: string); static;
    class procedure Recover(const AStateFolder: string); static;
  end;

implementation

uses Classes, SysUtils, Generics.Collections, tpNXSetup, obNXSetupState,
  obNXSetupLocations, utNXSetupPaths, utNXSetupFiles, utNXSetupStreams
  {$ifdef windows}, Windows{$else}, BaseUnix, Unix{$endif};

type
  TNXSetupMutation = class
  private
    FTarget, FTemporary, FBackup: string;
  end;

  TNXSetupTransaction = class
  private
    FFolder, FWork: string;
    FCommitted: Boolean;
    FChanges: TObjectList<TNXSetupMutation>;
    FDirectories: TStringList;
    FLock: THandle;
    procedure Save;
    procedure Read;
    procedure Rollback;
    procedure Cleanup;
  public
    constructor Create(const AFolder: string);
    destructor Destroy; override;
    procedure BeginWork;
    procedure MakeDirectory(const APath: string; AState: TNXSetupState);
    procedure Publish(const ASource, ATarget: string);
    procedure Remove(const ATarget: string);
    procedure Commit;
    procedure Recover;
  end;

constructor TNXSetupTransaction.Create(const AFolder: string);
begin
  inherited Create;
  FLock := THandle(-1);
  FFolder := IncludeTrailingPathDelimiter(AFolder);
  CheckRegularPath(FFolder);
  CheckRegularPath(FFolder + 'lock');
  FChanges := TObjectList<TNXSetupMutation>.Create(True);
  FDirectories := TStringList.Create;
  {$ifdef windows}
  FLock := CreateFileW(PWideChar(UnicodeString(FFolder + 'lock')),
    GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if FLock = INVALID_HANDLE_VALUE then
    raise ENXSetup.Create('Another operation owns this installation, or its state is not writable.');
  {$else}
  FLock := fpOpen(FFolder + 'lock', O_RDWR or O_CREAT, &600);
  if (FLock = THandle(-1)) or (fpFlock(FLock, LOCK_EX or LOCK_NB) <> 0) then
    raise ENXSetup.Create('Another operation owns this installation, or its state is not writable.');
  {$endif}
end;

destructor TNXSetupTransaction.Destroy;
begin
  {$ifdef windows}
  if FLock <> INVALID_HANDLE_VALUE then CloseHandle(FLock);
  {$else}
  if FLock <> THandle(-1) then fpClose(FLock);
  {$endif}
  FDirectories.Free;
  FChanges.Free;
  inherited Destroy;
end;

procedure TNXSetupTransaction.Save;
var
  lStream: TFileStream;
  lChange: TNXSetupMutation;
  lPath: string;
begin
  CheckRegularPath(FFolder + 'journal.new');
  lStream := TFileStream.Create(FFolder + 'journal.new', fmCreate);
  try
    WriteText(lStream, 'NXJournal1');
    WriteText(lStream, ExtractFileName(FWork));
    WriteNumber(lStream, Ord(FCommitted));
    WriteNumber(lStream, FChanges.Count);
    for lChange in FChanges do
    begin
      WriteText(lStream, lChange.FTarget);
      WriteText(lStream, lChange.FTemporary);
      WriteText(lStream, lChange.FBackup);
    end;
    WriteNumber(lStream, FDirectories.Count);
    for lPath in FDirectories do WriteText(lStream, lPath);
  finally
    lStream.Free;
  end;
  ReplaceSetupFile(FFolder + 'journal.new', FFolder + 'journal');
end;

procedure TNXSetupTransaction.Read;
var
  lStream: TFileStream;
  lName: string;
  lFlag: QWord;
  lIndex, lCount: Integer;
  lChange: TNXSetupMutation;
begin
  lStream := TFileStream.Create(FFolder + 'journal', fmOpenRead or fmShareDenyWrite);
  try
    if ReadText(lStream) <> 'NXJournal1' then raise EReadError.Create('Unknown recovery journal.');
    lName := ReadText(lStream);
    if (ExtractFileName(lName) <> lName) or (Pos('nxsetup-', lName) <> 1) then
      raise EReadError.Create('Invalid journal work directory.');
    FWork := FFolder + lName;
    lFlag := ReadNumber(lStream);
    if lFlag > 1 then raise EReadError.Create('Invalid journal state.');
    FCommitted := lFlag = 1;
    lCount := ReadCount(lStream);
    for lIndex := 1 to lCount do
    begin
      lChange := TNXSetupMutation.Create;
      FChanges.Add(lChange);
      lChange.FTarget := ReadText(lStream);
      lChange.FTemporary := ReadText(lStream);
      lChange.FBackup := ReadText(lStream);
      if not IsAbsolutePath(lChange.FTarget) or
        not (SameFileName(Copy(lChange.FTemporary, 1, Length(lChange.FTarget) + 7),
          lChange.FTarget + '.nxnew-') or
          SameFileName(Copy(lChange.FTemporary, 1, Length(lChange.FTarget) + 11),
          lChange.FTarget + '.nxrestore-')) or
        not SameFileName(ExtractFileDir(lChange.FTarget), ExtractFileDir(lChange.FTemporary)) then
        raise EReadError.Create('Invalid recovery destination.');
      if (lChange.FBackup <> '') and (ExtractFileName(lChange.FBackup) <> lChange.FBackup) then
        raise EReadError.Create('Invalid recovery backup.');
      CheckRegularPath(lChange.FTarget);
      CheckRegularPath(lChange.FTemporary);
    end;
    lCount := ReadCount(lStream);
    for lIndex := 1 to lCount do
    begin
      lName := ReadText(lStream);
      if not IsAbsolutePath(lName) then raise EReadError.Create('Invalid recovery directory.');
      CheckRegularPath(lName);
      FDirectories.Add(lName);
    end;
    RequireEnd(lStream);
  finally
    lStream.Free;
  end;
end;

procedure TNXSetupTransaction.BeginWork;
begin
  if FileExists(FFolder + 'journal') then
    raise ENXSetup.Create('An interrupted operation needs recovery before installation can continue.');
  FWork := SetupWorkFolder(FFolder);
  Save;
end;

procedure TNXSetupTransaction.MakeDirectory(const APath: string; AState: TNXSetupState);
var
  lPath, lParent: string;
begin
  lPath := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
  CheckRegularPath(lPath);
  if DirectoryExists(lPath) then Exit;
  lParent := ExtractFileDir(lPath);
  if (lParent <> '') and not SameFileName(lParent, lPath) then MakeDirectory(lParent, AState);
  FDirectories.Add(lPath);
  Save; // Journal intent before mutating the destination.
  if not CreateDir(lPath) then raise ENXSetup.Create('Cannot create destination: ' + lPath);
  if AState <> nil then AState.Directories.Add(lPath);
end;

procedure TNXSetupTransaction.Publish(const ASource, ATarget: string);
var
  lChange: TNXSetupMutation;
  lGuid: TGUID;
begin
  CheckRegularPath(ATarget);
  lChange := TNXSetupMutation.Create;
  try
    lChange.FTarget := ATarget;
    CreateGUID(lGuid);
    lChange.FTemporary := ATarget + '.nxnew-' + GUIDToString(lGuid);
    if FileExists(lChange.FTemporary) then raise ENXSetup.Create('Temporary destination already exists.');
    if FileExists(ATarget) then
    begin
      lChange.FBackup := IntToStr(FChanges.Count + 1) + '.backup';
      CopySetupFile(ATarget, IncludeTrailingPathDelimiter(FWork) + lChange.FBackup);
    end;
  except
    lChange.Free;
    raise;
  end;
  FChanges.Add(lChange);
  Save;
  CopySetupFile(ASource, lChange.FTemporary);
  ReplaceSetupFile(lChange.FTemporary, ATarget);
end;

procedure TNXSetupTransaction.Remove(const ATarget: string);
var
  lChange: TNXSetupMutation;
  lGuid: TGUID;
begin
  CheckRegularPath(ATarget);
  if not FileExists(ATarget) then Exit;
  lChange := TNXSetupMutation.Create;
  try
    lChange.FTarget := ATarget;
    CreateGUID(lGuid);
    lChange.FTemporary := ATarget + '.nxrestore-' + GUIDToString(lGuid);
    lChange.FBackup := IntToStr(FChanges.Count + 1) + '.backup';
    CopySetupFile(ATarget, IncludeTrailingPathDelimiter(FWork) + lChange.FBackup);
  except
    lChange.Free;
    raise;
  end;
  FChanges.Add(lChange);
  Save;
  RemoveSetupFile(ATarget);
end;

procedure TNXSetupTransaction.Rollback;
var
  lIndex: Integer;
  lChange: TNXSetupMutation;
begin
  for lIndex := FChanges.Count - 1 downto 0 do
  begin
    lChange := FChanges[lIndex];
    CheckRegularPath(lChange.FTarget);
    RemoveSetupFile(lChange.FTemporary);
    if lChange.FBackup <> '' then
    begin
      CopySetupFile(IncludeTrailingPathDelimiter(FWork) + lChange.FBackup, lChange.FTemporary);
      ReplaceSetupFile(lChange.FTemporary, lChange.FTarget);
    end
    else RemoveSetupFile(lChange.FTarget);
  end;
  for lIndex := FDirectories.Count - 1 downto 0 do
    if DirectoryExists(FDirectories[lIndex]) and not RemoveDir(FDirectories[lIndex]) then
      raise ENXSetup.Create('Recovery cannot remove destination directory: ' + FDirectories[lIndex]);
end;

procedure TNXSetupTransaction.Cleanup;
begin
  RemoveSetupFile(FFolder + 'journal');
  RemoveSetupFile(FFolder + 'journal.new');
  RemoveSetupTree(FWork);
end;

procedure TNXSetupTransaction.Commit;
begin
  FCommitted := True;
  Save;
  Cleanup;
end;

procedure TNXSetupTransaction.Recover;
begin
  if not FileExists(FFolder + 'journal') then Exit;
  Read;
  if not FCommitted then Rollback;
  Cleanup;
end;

type
  TNXSetupFileOperation = class
  private
    FSource, FDestination: string;
    FReplace, FKeep: Boolean;
  end;

procedure AddOperation(AOperations: TObjectList<TNXSetupFileOperation>;
  const ASource, ADestination: string; APayload: TNXSetupPayload; ARepair: Boolean);
var
  lOperation: TNXSetupFileOperation;
begin
  CheckRegularPath(ASource);
  CheckRegularPath(ADestination);
  if not FileExists(ASource) then raise ENXSetup.Create('Payload file is missing: ' + ASource);
  if DirectoryExists(ADestination) then raise ENXSetup.Create('File destination is a directory: ' + ADestination);
  for lOperation in AOperations do
    if PathContains(lOperation.FDestination, ADestination) or
      PathContains(ADestination, lOperation.FDestination) then
      raise ENXSetup.Create('Payload file destinations overlap: ' + ADestination);
  lOperation := TNXSetupFileOperation.Create;
  AOperations.Add(lOperation);
  lOperation.FSource := ASource;
  lOperation.FDestination := ADestination;
  lOperation.FKeep := APayload.KeepOnUninstall;
  lOperation.FReplace := FileNeedsReplacement(ASource, ADestination,
    APayload.PreserveExisting, APayload.IgnoreVersion, ARepair);
end;

procedure ExpandPlan(APlan: TNXSetupPlan; AOperations: TObjectList<TNXSetupFileOperation>;
  ADirectories: TStringList; ARepair: Boolean);
var
  lFile: TNXSetupPlannedFile;
  lFiles, lFolders: TStringList;
  lRelative: string;
  lDirectory: string;
  lOperation: TNXSetupFileOperation;
begin
  if APlan.Dependencies.Count <> 0 then
    raise ENXSetup.Create('Selected dependencies require installer providers; file-only installation cannot satisfy them yet.');
  if APlan.Shortcuts.Count <> 0 then
    raise ENXSetup.Create('Shortcut execution is not implemented yet; no files have been installed.');
  lFiles := TStringList.Create;
  lFolders := TStringList.Create;
  try
    for lFile in APlan.Files do
      if lFile.Payload.Kind = spkFile then
        AddOperation(AOperations, lFile.Source, lFile.Destination, lFile.Payload, ARepair)
      else
      begin
        lFiles.Clear;
        lFolders.Clear;
        CollectSetupTree(lFile.Source, '', lFiles, lFolders);
        for lRelative in lFolders do
          ADirectories.Add(TNXSetupLocations.RelativePath(lFile.Destination, lRelative));
        for lRelative in lFiles do
          AddOperation(AOperations, IncludeTrailingPathDelimiter(lFile.Source) + lRelative,
            TNXSetupLocations.RelativePath(lFile.Destination, lRelative), lFile.Payload, ARepair);
      end;
    for lDirectory in ADirectories do
    begin
      CheckRegularPath(lDirectory);
      if FileExists(lDirectory) then raise ENXSetup.Create('Directory destination is a file: ' + lDirectory);
      for lOperation in AOperations do
        if PathContains(lOperation.FDestination, lDirectory) then
          raise ENXSetup.Create('File and directory destinations collide: ' + lDirectory);
    end;
  finally
    lFolders.Free;
    lFiles.Free;
  end;
end;

procedure RecordMissingDirectories(AState: TNXSetupState; const AFolder: string);
var
  lParent: string;
begin
  if DirectoryExists(AFolder) then Exit;
  lParent := ExtractFileDir(AFolder);
  if (lParent <> '') and not SameFileName(lParent, AFolder) then RecordMissingDirectories(AState, lParent);
  AState.Directories.Add(AFolder);
end;

class function TNXSetupFileInstaller.Install(ADocument: TNXSetupDocument;
  APlan: TNXSetupPlan; const ARoot: string; const AArchiveFile: string;
  ARepair: Boolean): string;
var
  lOperations: TObjectList<TNXSetupFileOperation>;
  lDirectories: TStringList;
  lState, lOldState: TNXSetupState;
  lTransaction: TNXSetupTransaction;
  lOperation: TNXSetupFileOperation;
  lOwned: TNXSetupInstalledFile;
  lFolder, lRoot, lDirectory, lPrivateFile, lPrivateRoot: string;
  lStream: TFileStream;
begin
  if not IsAbsolutePath(ARoot) then raise ENXSetup.Create('Application root must be absolute.');
  lRoot := ExcludeTrailingPathDelimiter(ExpandFileName(ARoot));
  if SameFileName(ExtractFileDir(lRoot), lRoot) then raise ENXSetup.Create('Application root cannot be a volume root.');
  lFolder := TNXSetupState.Folder(lRoot, ADocument.Product.Id);
  lPrivateRoot := IncludeTrailingPathDelimiter(lRoot) + '.nx' + PathDelim + 'setup';
  CheckRegularPath(lFolder);
  lOperations := TObjectList<TNXSetupFileOperation>.Create(True);
  lDirectories := TStringList.Create;
  lState := TNXSetupState.Create(ADocument.Product.Id, ADocument.Product.Version, lRoot);
  lOldState := nil;
  lTransaction := nil;
  try
    ExpandPlan(APlan, lOperations, lDirectories, ARepair);
    lState.Seeds.Assign(APlan.Seeds);
    lState.Bindings.Assign(APlan.Bindings);
    for lOperation in lOperations do
      if PathContains(lPrivateRoot, lOperation.FDestination) or
        PathContains(lOperation.FDestination, lPrivateRoot) then
        raise ENXSetup.Create('Payload collides with private Setup state.');
    for lDirectory in lDirectories do
      if PathContains(lPrivateRoot, lDirectory) then
        raise ENXSetup.Create('Payload directory collides with private Setup state.');
    RecordMissingDirectories(lState, lFolder);
    if not ForceDirectories(lFolder) then raise ENXSetup.Create('Cannot create private Setup state.');
    lTransaction := TNXSetupTransaction.Create(lFolder);
    Result := IncludeTrailingPathDelimiter(lFolder) + 'installation';
    if FileExists(Result) then
    begin
      lOldState := TNXSetupState.LoadFile(Result);
      for lOwned in lOldState.Files do lState.RecordFile(lOwned.Path, lOwned.KeepOnUninstall);
      lState.Directories.AddStrings(lOldState.Directories);
    end;
    lTransaction.BeginWork;
    try
      for lDirectory in lDirectories do lTransaction.MakeDirectory(lDirectory, lState);
      for lOperation in lOperations do
        if lOperation.FReplace then
        begin
          lTransaction.MakeDirectory(ExtractFileDir(lOperation.FDestination), lState);
          lTransaction.Publish(lOperation.FSource, lOperation.FDestination);
        end;
      { Update policy for already-owned skipped files, but never adopt a
        preexisting file just because version/preservation rules skipped it. }
      for lOperation in lOperations do
        if lOperation.FReplace or (lState.FindFile(lOperation.FDestination) <> nil) then
          lState.RecordFile(lOperation.FDestination, lOperation.FKeep);
      lPrivateFile := IncludeTrailingPathDelimiter(lTransaction.FWork) + 'source';
      lStream := TFileStream.Create(lPrivateFile, fmCreate);
      try ADocument.SourceContext.SaveToStream(lStream); finally lStream.Free; end;
      lTransaction.Publish(lPrivateFile, IncludeTrailingPathDelimiter(lFolder) + 'source');
      if AArchiveFile <> '' then
        lTransaction.Publish(AArchiveFile, IncludeTrailingPathDelimiter(lFolder) + 'payload.zip');
      lPrivateFile := IncludeTrailingPathDelimiter(lTransaction.FWork) + 'installation';
      lStream := TFileStream.Create(lPrivateFile, fmCreate);
      try lState.SaveToStream(lStream); finally lStream.Free; end;
      lTransaction.Publish(lPrivateFile, Result);
      lTransaction.Commit;
    except
      on lError: Exception do
      begin
        if not lTransaction.FCommitted then
        begin
          lTransaction.Rollback;
          lTransaction.Cleanup;
        end;
        raise;
      end;
    end;
  finally
    lTransaction.Free;
    lOldState.Free;
    lState.Free;
    lDirectories.Free;
    lOperations.Free;
  end;
end;

class procedure TNXSetupFileInstaller.Recover(const AStateFolder: string);
var
  lTransaction: TNXSetupTransaction;
begin
  lTransaction := TNXSetupTransaction.Create(AStateFolder);
  try lTransaction.Recover; finally lTransaction.Free; end;
end;

function DirectoryEmpty(const AFolder: string): Boolean;
var
  lSearch: TSearchRec;
begin
  Result := True;
  if FindFirst(IncludeTrailingPathDelimiter(AFolder) + '*', faAnyFile, lSearch) = 0 then
  try
    repeat
      if (lSearch.Name <> '.') and (lSearch.Name <> '..') then Exit(False);
    until FindNext(lSearch) <> 0;
  finally
    SysUtils.FindClose(lSearch);
  end;
end;

class procedure TNXSetupFileInstaller.Uninstall(const AStateFile: string);
var
  lState: TNXSetupState;
  lTransaction: TNXSetupTransaction;
  lFile: TNXSetupInstalledFile;
  lFolder: string;
  lIndex: Integer;
begin
  lState := TNXSetupState.LoadFile(AStateFile);
  lTransaction := nil;
  try
    lFolder := ExtractFileDir(AStateFile);
    lTransaction := TNXSetupTransaction.Create(lFolder);
    lTransaction.BeginWork;
    try
      for lFile in lState.Files do
        if not lFile.KeepOnUninstall then lTransaction.Remove(lFile.Path);
      lTransaction.Remove(IncludeTrailingPathDelimiter(lFolder) + 'source');
      lTransaction.Remove(IncludeTrailingPathDelimiter(lFolder) + 'payload.zip');
      lTransaction.Remove(AStateFile);
      lTransaction.Commit;
    except
      if not lTransaction.FCommitted then
      begin
        lTransaction.Rollback;
        lTransaction.Cleanup;
      end;
      raise;
    end;
    FreeAndNil(lTransaction);
    RemoveSetupFile(IncludeTrailingPathDelimiter(lFolder) + 'lock');
    for lIndex := lState.Directories.Count - 1 downto 0 do
    begin
      CheckRegularPath(lState.Directories[lIndex]);
      if DirectoryExists(lState.Directories[lIndex]) and DirectoryEmpty(lState.Directories[lIndex]) and
        not RemoveDir(lState.Directories[lIndex]) then
        raise ENXSetup.Create('Cannot remove empty installed directory: ' + lState.Directories[lIndex]);
    end;
  finally
    lTransaction.Free;
    lState.Free;
  end;
end;

end.
