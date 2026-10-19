(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit utNXForgeFileOperations;

{$mode delphi}{$H+}

interface

uses obNexusScriptLive, tpNexusScriptLive, obNXForgeInvocation;

function IsForgeFileOperation(const AKind: string): Boolean;
procedure PrepareForgeFileOperation(AOperation: TNexusScriptLiveDefinition;
  AInvocation: TNXForgeInvocation);
procedure ExecuteForgeFileOperation(AInvocation: TNXForgeInvocation);

implementation

uses Classes, SysUtils, StrUtils, PasZLibIO, tpNXForge, utNXForgePaths,
  utNXForgeBuildIdentity, utNXForgePackageSDK, utNXForgePackageBuild
  {$IFDEF UNIX}, BaseUnix{$ENDIF};

function IsForgeFileOperation(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'CreateDirectory') or
    SameText(AKind, 'WriteTextFile') or SameText(AKind, 'CopyFile') or
    SameText(AKind, 'CompareFiles') or SameText(AKind, 'DeletePath') or
    SameText(AKind, 'Archive') or SameText(AKind, 'BuildIdentity') or
    SameText(AKind, 'PackageSDKOptions') or SameText(AKind, 'PackageSDKManifest') or
    SameText(AKind, 'PackageBuildPrepare') or SameText(AKind, 'PackageBundlePublish');
end;

function PropertyText(AOperation: TNexusScriptLiveDefinition;
  const AName: string): string;
var
  lProperty: TNexusScriptLiveProperty;
begin
  lProperty := AOperation.FindProperty(AName);
  if (lProperty = nil) or (lProperty.Value.Kind <> nslvText) then
    raise Exception.Create(AOperation.Name + ': missing text property ' + AName);
  Result := lProperty.Value.AsText;
end;

function OptionalText(AOperation: TNexusScriptLiveDefinition;
  const AName: string): string;
begin
  Result := '';
  if AOperation.FindProperty(AName) <> nil then
    Result := PropertyText(AOperation, AName);
end;

function OptionalBoolean(AOperation: TNexusScriptLiveDefinition;
  const AName: string; ADefault: Boolean): Boolean;
begin
  Result := ADefault;
  if AOperation.FindProperty(AName) <> nil then
    Result := SameText(PropertyText(AOperation, AName), 'True');
end;

function OperationPath(const ABase, APath: string): string;
begin
  if (ExtractFileDrive(APath) <> '') or
    ((APath <> '') and IsPathDelimiter(APath, 1)) then Result := ExpandFileName(APath)
  else Result := ExpandFileName(IncludeTrailingPathDelimiter(ABase) + APath);
end;

function CopyIncludeMasks(AOperation: TNexusScriptLiveDefinition): TStringArray;
var
  lProperty: TNexusScriptLiveProperty;
  lArray: TNexusScriptLiveValue;
  lIndex: Integer;
  lMask: string;
begin
  Result := nil;
  lProperty := AOperation.FindProperty('IncludeMasks');
  if lProperty = nil then Exit;
  lArray := lProperty.Value;
  SetLength(Result, lArray.Items.Count);
  for lIndex := 0 to lArray.Items.Count - 1 do
  begin
    lMask := lArray.Items[lIndex].AsText;
    if (Trim(lMask) = '') or (Pos('/', lMask) > 0) or
      (Pos('\', lMask) > 0) or (Pos(':', lMask) > 0) then
      raise Exception.Create(AOperation.Name +
        ': IncludeMasks entries must be nonempty filename masks: ' + lMask);
    Result[lIndex] := lMask;
  end;
end;

procedure PrepareForgeFileOperation(AOperation: TNexusScriptLiveDefinition;
  AInvocation: TNXForgeInvocation);
var
  lLeft, lRight: string;
  lProperty: TNexusScriptLiveProperty;
  lArray: TNexusScriptLiveValue;
  lDirectories: TStringArray;
  lIndex: Integer;
begin
  if SameText(AOperation.Kind, 'CreateDirectory') then
  begin
    AInvocation.Kind := fokCreateDirectory;
    AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('Path').Value, AInvocation.WorkingDirectory);
  end
  else if SameText(AOperation.Kind, 'WriteTextFile') then
  begin
    AInvocation.Kind := fokWriteTextFile;
    AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('Path').Value, AInvocation.WorkingDirectory);
    AInvocation.ArtifactText := PropertyText(AOperation, 'Text');
  end
  else if SameText(AOperation.Kind, 'BuildIdentity') then
  begin
    AInvocation.Kind := fokBuildIdentity;
    if (Trim(PropertyText(AOperation, 'Repository')) = '') or
      (Trim(PropertyText(AOperation, 'OutputDirectory')) = '') then
      raise Exception.Create('BuildIdentity requires nonempty Repository and OutputDirectory paths');
    AInvocation.SourcePath := ForgeValuePath(AOperation.FindProperty('Repository').Value, AInvocation.WorkingDirectory);
    AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('OutputDirectory').Value, AInvocation.WorkingDirectory);
  end
  else if SameText(AOperation.Kind, 'PackageSDKOptions') then
  begin
    AInvocation.Kind := fokPackageSDKOptions;
    if (Trim(PropertyText(AOperation, 'BootstrapDirectory')) = '') or
      (Trim(PropertyText(AOperation, 'OutputDirectory')) = '') then
      raise Exception.Create('PackageSDKOptions requires nonempty BootstrapDirectory and OutputDirectory paths');
    AInvocation.SourcePath := ForgeValuePath(AOperation.FindProperty('BootstrapDirectory').Value, AInvocation.WorkingDirectory);
    AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('OutputDirectory').Value, AInvocation.WorkingDirectory);
  end
  else if SameText(AOperation.Kind, 'PackageSDKManifest') then
  begin
    AInvocation.Kind := fokPackageSDKManifest;
    if Trim(PropertyText(AOperation, 'Directory')) = '' then
      raise Exception.Create('PackageSDKManifest requires a nonempty Directory path');
    AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('Directory').Value, AInvocation.WorkingDirectory);
  end
  else if SameText(AOperation.Kind, 'PackageBuildPrepare') then
  begin
    AInvocation.Kind := fokPackageBuildPrepare;
    if (Trim(PropertyText(AOperation, 'SDKDirectory')) = '') or
      (Trim(PropertyText(AOperation, 'WorkDirectory')) = '') then
      raise Exception.Create('PackageBuildPrepare requires nonempty SDKDirectory and WorkDirectory');
    AInvocation.SourcePath := ForgeValuePath(AOperation.FindProperty('SDKDirectory').Value, AInvocation.WorkingDirectory);
    AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('WorkDirectory').Value, AInvocation.WorkingDirectory);
    lProperty := AOperation.FindProperty('PackageDirectories');
    if lProperty <> nil then
    begin
      lArray := lProperty.Value;
      SetLength(lDirectories, lArray.Items.Count);
      for lIndex := 0 to lArray.Items.Count - 1 do
      begin
        if Trim(lArray.Items[lIndex].AsText) = '' then
          raise Exception.Create('PackageDirectories entries must be nonempty');
        lDirectories[lIndex] := ForgeValuePath(lArray.Items[lIndex], AInvocation.WorkingDirectory);
      end;
      AInvocation.PackageDirectories := lDirectories;
    end;
  end
  else if SameText(AOperation.Kind, 'PackageBundlePublish') then
  begin
    AInvocation.Kind := fokPackageBundlePublish;
    if (Trim(PropertyText(AOperation, 'WorkDirectory')) = '') or
      (Trim(PropertyText(AOperation, 'OutputDirectory')) = '') then
      raise Exception.Create('PackageBundlePublish requires nonempty WorkDirectory and OutputDirectory');
    AInvocation.SourcePath := ForgeValuePath(AOperation.FindProperty('WorkDirectory').Value, AInvocation.WorkingDirectory);
    AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('OutputDirectory').Value, AInvocation.WorkingDirectory);
    AInvocation.PackageName := PropertyText(AOperation, 'Name');
    AInvocation.PackageKind := PropertyText(AOperation, 'Kind');
  end
  else if SameText(AOperation.Kind, 'CompareFiles') then
  begin
    AInvocation.Kind := fokCompareFiles;
    lLeft := PropertyText(AOperation, 'Left');
    lRight := PropertyText(AOperation, 'Right');
    if (Trim(lLeft) = '') or (Trim(lRight) = '') then
      raise Exception.Create('CompareFiles requires nonempty Left and Right paths');
    AInvocation.LeftPath := ForgeValuePath(AOperation.FindProperty('Left').Value, AInvocation.WorkingDirectory);
    AInvocation.RightPath := ForgeValuePath(AOperation.FindProperty('Right').Value, AInvocation.WorkingDirectory);
  end
  else if SameText(AOperation.Kind, 'DeletePath') then
  begin
    AInvocation.Kind := fokDeletePath;
    AInvocation.SourcePath := ForgeValuePath(AOperation.FindProperty('Path').Value, AInvocation.WorkingDirectory);
    AInvocation.Recursive := OptionalBoolean(AOperation, 'Recursive', False);
    AInvocation.MissingOk := OptionalBoolean(AOperation, 'MissingOk', True);
  end
  else
  begin
    AInvocation.SourcePath := ForgeValuePath(AOperation.FindProperty('Source').Value, AInvocation.WorkingDirectory);
    AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('Destination').Value, AInvocation.WorkingDirectory);
    AInvocation.Overwrite := OptionalBoolean(AOperation, 'Overwrite', False);
    AInvocation.ExcludeNames := OptionalText(AOperation, 'ExcludeNames');
    if SameText(AOperation.Kind, 'CopyFile') then
    begin
      AInvocation.Kind := fokCopyFile;
      AInvocation.Recursive := OptionalBoolean(AOperation, 'Recursive', False);
      AInvocation.CleanDestination := OptionalBoolean(AOperation,
        'CleanDestination', False);
      AInvocation.IncludeMasks := CopyIncludeMasks(AOperation);
    end
    else
    begin
      AInvocation.Kind := fokArchive;
      AInvocation.ArchiveOperation := PropertyText(AOperation, 'Operation');
      if not SameText(AInvocation.ArchiveOperation, 'Zip') and
        not SameText(AInvocation.ArchiveOperation, 'Unzip') then
        raise Exception.Create('Archive Operation must be Zip or Unzip');
      AInvocation.Recursive := OptionalBoolean(AOperation, 'Recursive', True);
    end;
  end;
end;

procedure EnsureDirectory(const APath: string);
begin
  if not DirectoryExists(APath) and not ForceDirectories(APath) then
    raise Exception.Create('Could not create directory: ' + APath);
end;

procedure RemoveDirectoryTree(const APath: string);
var
  lChild: string;
  lSearch: TSearchRec;
begin
  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, lSearch) = 0 then
  try
    repeat
      if (lSearch.Name = '.') or (lSearch.Name = '..') then Continue;
      lChild := IncludeTrailingPathDelimiter(APath) + lSearch.Name;
      if (lSearch.Attr and faDirectory) <> 0 then RemoveDirectoryTree(lChild)
      else if not DeleteFile(lChild) then
        raise Exception.Create('Could not delete file: ' + lChild);
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;
  if not RemoveDir(APath) then
    raise Exception.Create('Could not remove directory: ' + APath);
end;

procedure CopyOneFile(const ASource, ADestination: string; AOverwrite: Boolean);
var
  lDestination: string;
  lInput, lOutput: TFileStream;
  {$IFDEF UNIX}lStat: Stat;{$ENDIF}
begin
  lDestination := ADestination;
  if DirectoryExists(lDestination) then
    lDestination := IncludeTrailingPathDelimiter(lDestination) + ExtractFileName(ASource);
  if SameFileName(ASource, lDestination) then
    raise Exception.Create('CopyFile source and destination are the same: ' + ASource);
  if FileExists(lDestination) and not AOverwrite then
    raise Exception.Create('CopyFile destination already exists: ' + lDestination);
  EnsureDirectory(ExtractFileDir(lDestination));
  lInput := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    {$IFDEF UNIX}
    if fpFStat(lInput.Handle, lStat) <> 0 then RaiseLastOSError;
    {$ENDIF}
    lOutput := TFileStream.Create(lDestination, fmCreate);
    try
      lOutput.CopyFrom(lInput, 0);
    finally
      lOutput.Free;
    end;
  finally
    lInput.Free;
  end;
  {$IFDEF UNIX}
  if fpChmod(lDestination, lStat.st_mode and (S_IRWXU or S_IRWXG or S_IRWXO)) <> 0 then
    RaiseLastOSError;
  {$ENDIF}
end;

function ExcludeList(const AText: string): TStringList;
var
  lIndex: Integer;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.StrictDelimiter := True;
  Result.Delimiter := ';';
  Result.DelimitedText := AText;
  for lIndex := Result.Count - 1 downto 0 do
    if Trim(Result[lIndex]) = '' then Result.Delete(lIndex)
    else Result[lIndex] := Trim(Result[lIndex]);
end;

function IncludedFile(const AName: string; const AIncludeMasks: TStringArray): Boolean;
var
  lMask: string;
begin
  if Length(AIncludeMasks) = 0 then Exit(True);
  for lMask in AIncludeMasks do
    if IsWild(AName, lMask, {$IFDEF WINDOWS}True{$ELSE}False{$ENDIF}) then Exit(True);
  Result := False;
end;

procedure CopyDirectory(const ASource, ADestination: string; AOverwrite: Boolean;
  AExcludeNames: TStrings; const AIncludeMasks: TStringArray);
var
  lSearch: TSearchRec;
  lSource, lDestination: string;
begin
  if FileExists(ADestination) then
    raise Exception.Create('CopyFile recursive destination is a file: ' + ADestination);
  EnsureDirectory(ADestination);
  if FindFirst(IncludeTrailingPathDelimiter(ASource) + '*', faAnyFile, lSearch) <> 0 then Exit;
  try
    repeat
      if (lSearch.Name = '.') or (lSearch.Name = '..') or
        (AExcludeNames.IndexOf(lSearch.Name) >= 0) then Continue;
      lSource := IncludeTrailingPathDelimiter(ASource) + lSearch.Name;
      lDestination := IncludeTrailingPathDelimiter(ADestination) + lSearch.Name;
      if (lSearch.Attr and faDirectory) <> 0 then
        CopyDirectory(lSource, lDestination, AOverwrite, AExcludeNames, AIncludeMasks)
      else if IncludedFile(lSearch.Name, AIncludeMasks) then
        CopyOneFile(lSource, lDestination, AOverwrite);
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;
end;

procedure ExecuteCopy(AInvocation: TNXForgeInvocation);
var
  lExcludeNames: TStringList;
  lSourceRoot, lDestinationRoot: string;
begin
  if FileExists(AInvocation.SourcePath) then
  begin
    if IncludedFile(ExtractFileName(AInvocation.SourcePath), AInvocation.IncludeMasks) then
      CopyOneFile(AInvocation.SourcePath, AInvocation.OutputPath, AInvocation.Overwrite);
  end
  else if DirectoryExists(AInvocation.SourcePath) then
  begin
    if not AInvocation.Recursive then
      raise Exception.Create('CopyFile source is a directory but Recursive is false: ' +
        AInvocation.SourcePath);
    lSourceRoot := IncludeTrailingPathDelimiter(AInvocation.SourcePath);
    lDestinationRoot := IncludeTrailingPathDelimiter(AInvocation.OutputPath);
    {$IFDEF WINDOWS}
    lSourceRoot := AnsiLowerCase(lSourceRoot);
    lDestinationRoot := AnsiLowerCase(lDestinationRoot);
    {$ENDIF}
    if Pos(lSourceRoot, lDestinationRoot) = 1 then
      raise Exception.Create('CopyFile destination is inside its source: ' +
        AInvocation.OutputPath);
    if AInvocation.CleanDestination and
      (Pos(lDestinationRoot, lSourceRoot) = 1) then
      raise Exception.Create('CopyFile CleanDestination contains its source: ' +
        AInvocation.OutputPath);
    if AInvocation.CleanDestination and DirectoryExists(AInvocation.OutputPath) then
      RemoveDirectoryTree(AInvocation.OutputPath);
    lExcludeNames := ExcludeList(AInvocation.ExcludeNames);
    try
      CopyDirectory(AInvocation.SourcePath, AInvocation.OutputPath,
        AInvocation.Overwrite, lExcludeNames, AInvocation.IncludeMasks);
    finally
      lExcludeNames.Free;
    end;
  end
  else raise Exception.Create('CopyFile source does not exist: ' + AInvocation.SourcePath);
end;

procedure DeleteMatchingFiles(const ARoot, AMask: string; ARecursive: Boolean);
var
  lSearch: TSearchRec;
  lChild: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ARoot) + AMask, faAnyFile, lSearch) = 0 then
  try
    repeat
      if (lSearch.Name = '.') or (lSearch.Name = '..') or
        ((lSearch.Attr and faDirectory) <> 0) then Continue;
      lChild := IncludeTrailingPathDelimiter(ARoot) + lSearch.Name;
      if not DeleteFile(lChild) then
        raise Exception.Create('Could not delete file: ' + lChild);
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;
  if not ARecursive then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ARoot) + '*', faDirectory, lSearch) = 0 then
  try
    repeat
      if (lSearch.Name = '.') or (lSearch.Name = '..') or
        ((lSearch.Attr and faDirectory) = 0) then Continue;
      DeleteMatchingFiles(IncludeTrailingPathDelimiter(ARoot) + lSearch.Name,
        AMask, True);
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;
end;

procedure ExecuteDelete(AInvocation: TNXForgeInvocation);
var
  lMask, lRoot: string;
begin
  lMask := ExtractFileName(AInvocation.SourcePath);
  if (Pos('*', lMask) > 0) or (Pos('?', lMask) > 0) then
  begin
    lRoot := ExtractFileDir(AInvocation.SourcePath);
    if not DirectoryExists(lRoot) then
    begin
      if not AInvocation.MissingOk then
        raise Exception.Create('DeletePath root directory does not exist: ' + lRoot);
      Exit;
    end;
    DeleteMatchingFiles(lRoot, lMask, AInvocation.Recursive);
  end
  else if FileExists(AInvocation.SourcePath) then
  begin
    if not DeleteFile(AInvocation.SourcePath) then
      raise Exception.Create('Could not delete file: ' + AInvocation.SourcePath);
  end
  else if DirectoryExists(AInvocation.SourcePath) then
  begin
    if AInvocation.Recursive then RemoveDirectoryTree(AInvocation.SourcePath)
    else if not RemoveDir(AInvocation.SourcePath) then
      raise Exception.Create('Directory is not empty or could not be removed: ' +
        AInvocation.SourcePath);
  end
  else if not AInvocation.MissingOk then
    raise Exception.Create('DeletePath path does not exist: ' + AInvocation.SourcePath);
end;

procedure AddZipEntries(AEntries: TZipFileEntries; AExcludeNames: TStrings;
  const ASourceRoot, ACurrentPath: string; ARecursive: Boolean);
var
  lSearch: TSearchRec;
  lChild, lEntryName: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ACurrentPath) + '*', faAnyFile, lSearch) <> 0 then Exit;
  try
    repeat
      if (lSearch.Name = '.') or (lSearch.Name = '..') or
        (AExcludeNames.IndexOf(lSearch.Name) >= 0) then Continue;
      lChild := IncludeTrailingPathDelimiter(ACurrentPath) + lSearch.Name;
      if (lSearch.Attr and faDirectory) <> 0 then
      begin
        if ARecursive then AddZipEntries(AEntries, AExcludeNames,
          ASourceRoot, lChild, True);
      end
      else
      begin
        lEntryName := ExtractRelativePath(IncludeTrailingPathDelimiter(ASourceRoot),
          lChild);
        lEntryName := StringReplace(lEntryName, '\', '/', [rfReplaceAll]);
        AEntries.AddFileEntry(lChild, lEntryName);
      end;
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;
end;

procedure ExecuteZip(AInvocation: TNXForgeInvocation);
var
  lEntries: TZipFileEntries;
  lExcludeNames: TStringList;
  lZipper: TZipper;
begin
  if not FileExists(AInvocation.SourcePath) and
    not DirectoryExists(AInvocation.SourcePath) then
    raise Exception.Create('Archive source does not exist: ' + AInvocation.SourcePath);
  if FileExists(AInvocation.OutputPath) then
  begin
    if not AInvocation.Overwrite then
      raise Exception.Create('Archive destination already exists: ' + AInvocation.OutputPath);
    if not DeleteFile(AInvocation.OutputPath) then
      raise Exception.Create('Could not remove existing archive: ' + AInvocation.OutputPath);
  end;
  EnsureDirectory(ExtractFileDir(AInvocation.OutputPath));
  lEntries := TZipFileEntries.Create(TZipFileEntry);
  lExcludeNames := ExcludeList(AInvocation.ExcludeNames);
  try
    if FileExists(AInvocation.SourcePath) then
      lEntries.AddFileEntry(AInvocation.SourcePath,
        ExtractFileName(AInvocation.SourcePath))
    else if DirectoryExists(AInvocation.SourcePath) then
      AddZipEntries(lEntries, lExcludeNames, AInvocation.SourcePath,
        AInvocation.SourcePath, AInvocation.Recursive)
    else raise Exception.Create('Archive source does not exist: ' + AInvocation.SourcePath);
    lZipper := TZipper.Create;
    try
      lZipper.FileName := AInvocation.OutputPath;
      lZipper.ZipFiles(lEntries);
    finally
      lZipper.Free;
    end;
  finally
    lExcludeNames.Free;
    lEntries.Free;
  end;
end;

function IsWithinDirectory(const ARoot, APath: string): Boolean;
var
  lRoot, lPath: string;
begin
  lRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARoot));
  lPath := ExpandFileName(APath);
  {$IFDEF WINDOWS}
  lRoot := AnsiLowerCase(lRoot);
  lPath := AnsiLowerCase(lPath);
  {$ENDIF}
  Result := SameFileName(ExcludeTrailingPathDelimiter(lRoot), lPath) or
    (Pos(lRoot, lPath) = 1);
end;

procedure ExecuteUnzip(AInvocation: TNXForgeInvocation);
var
  lUnZipper: TUnZipper;
  lEntry: TFullZipFileEntry;
  lIndex: Integer;
  lTarget: string;
begin
  if not FileExists(AInvocation.SourcePath) then
    raise Exception.Create('Archive source does not exist: ' + AInvocation.SourcePath);
  if FileExists(AInvocation.OutputPath) then
    raise Exception.Create('Archive unzip destination is a file: ' + AInvocation.OutputPath);
  lUnZipper := TUnZipper.Create;
  try
    lUnZipper.FileName := AInvocation.SourcePath;
    lUnZipper.OutputPath := AInvocation.OutputPath;
    lUnZipper.Examine;
    for lIndex := 0 to lUnZipper.Entries.Count - 1 do
    begin
      lEntry := lUnZipper.Entries[lIndex];
      lTarget := OperationPath(AInvocation.OutputPath,
        StringReplace(lEntry.DiskFileName, '/', DirectorySeparator,
        [rfReplaceAll]));
      if not IsWithinDirectory(AInvocation.OutputPath, lTarget) then
        raise Exception.Create('Archive entry escapes destination: ' +
          lEntry.DiskFileName);
      if not lEntry.IsDirectory and FileExists(lTarget) and
        not AInvocation.Overwrite then
        raise Exception.Create('Archive extraction destination already exists: ' +
          lTarget);
    end;
    EnsureDirectory(AInvocation.OutputPath);
    lUnZipper.UnZipAllFiles;
  finally
    lUnZipper.Free;
  end;
end;

procedure ExecuteArchive(AInvocation: TNXForgeInvocation);
begin
  if SameText(AInvocation.ArchiveOperation, 'Zip') then ExecuteZip(AInvocation)
  else if SameText(AInvocation.ArchiveOperation, 'Unzip') then ExecuteUnzip(AInvocation)
  else raise Exception.Create('Archive Operation must be Zip or Unzip');
end;

procedure ExecuteWriteTextFile(AInvocation: TNXForgeInvocation);
var
  lFile: TStringList;
begin
  EnsureDirectory(ExtractFileDir(AInvocation.OutputPath));
  lFile := TStringList.Create;
  try
    lFile.LineBreak := #10;
    lFile.Text := AInvocation.ArtifactText;
    lFile.SaveToFile(AInvocation.OutputPath);
  finally
    lFile.Free;
  end;
end;

procedure CompareStreams(ALeft, ARight: TStream);
var
  lLeftBuffer, lRightBuffer: array[0..65535] of Byte;
  lLeftSize, lRightSize, lLimit, lOffset: Int64;
  lCount, lIndex: Integer;
begin
  lLeftSize := ALeft.Size;
  lRightSize := ARight.Size;
  lLimit := lLeftSize;
  if lRightSize < lLimit then lLimit := lRightSize;
  lOffset := 0;
  while lOffset < lLimit do
  begin
    lCount := SizeOf(lLeftBuffer);
    if lLimit - lOffset < lCount then lCount := lLimit - lOffset;
    ALeft.ReadBuffer(lLeftBuffer, lCount);
    ARight.ReadBuffer(lRightBuffer, lCount);
    for lIndex := 0 to lCount - 1 do
      if lLeftBuffer[lIndex] <> lRightBuffer[lIndex] then
        raise Exception.Create('Files differ at byte offset ' + IntToStr(lOffset + lIndex));
    Inc(lOffset, lCount);
  end;
  if lLeftSize <> lRightSize then
    raise Exception.CreateFmt('Files differ at byte offset %d (end of file; sizes %d and %d)',
      [lLimit, lLeftSize, lRightSize]);
end;

procedure ExecuteCompareFiles(AInvocation: TNXForgeInvocation);
var
  lLeft, lRight: TFileStream;
begin
  try
    if not FileExists(AInvocation.LeftPath) then
      raise Exception.Create('Left file does not exist or is not a file');
    if not FileExists(AInvocation.RightPath) then
      raise Exception.Create('Right file does not exist or is not a file');
    lLeft := TFileStream.Create(AInvocation.LeftPath, fmOpenRead or fmShareDenyWrite);
    try
      lRight := TFileStream.Create(AInvocation.RightPath, fmOpenRead or fmShareDenyWrite);
      try
        CompareStreams(lLeft, lRight);
      finally
        lRight.Free;
      end;
    finally
      lLeft.Free;
    end;
  except
    on E: Exception do
      raise Exception.Create('CompareFiles "' + AInvocation.LeftPath + '" and "' +
        AInvocation.RightPath + '": ' + E.Message);
  end;
end;

procedure ExecuteForgeFileOperation(AInvocation: TNXForgeInvocation);
begin
  AInvocation.Started := True;
  try
    case AInvocation.Kind of
      fokCreateDirectory: EnsureDirectory(AInvocation.OutputPath);
      fokWriteTextFile: ExecuteWriteTextFile(AInvocation);
      fokCopyFile: ExecuteCopy(AInvocation);
      fokCompareFiles: ExecuteCompareFiles(AInvocation);
      fokDeletePath: ExecuteDelete(AInvocation);
      fokArchive: ExecuteArchive(AInvocation);
      fokBuildIdentity: AInvocation.StdOut := WriteForgeBuildIdentity(
        AInvocation.SourcePath, AInvocation.OutputPath,
        GetEnvironmentVariable('SOURCE_DATE_EPOCH'));
      fokPackageSDKOptions: AInvocation.StdOut := WriteForgePackageSDKOptions(
        AInvocation.SourcePath, AInvocation.OutputPath);
      fokPackageSDKManifest: AInvocation.StdOut := WriteForgePackageSDKManifest(
        AInvocation.OutputPath);
      fokPackageBuildPrepare: AInvocation.StdOut := PrepareForgePackageBuild(
        AInvocation.SourcePath, AInvocation.OutputPath, AInvocation.PackageDirectories);
      fokPackageBundlePublish: AInvocation.StdOut := PublishForgePackageBundle(
        AInvocation.SourcePath, AInvocation.OutputPath, AInvocation.PackageName,
        AInvocation.PackageKind);
      else raise Exception.Create('Not a Forge file operation');
    end;
    AInvocation.Completed := True;
  except
    on E: Exception do AInvocation.Diagnostic := E.Message;
  end;
end;

end.
