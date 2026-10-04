unit utNXForgeFileOperations;

{$mode delphi}{$H+}

interface

uses obNexusScriptModel, obNXForgeInvocation;

function IsForgeFileOperation(const AKind: string): Boolean;
procedure PrepareForgeFileOperation(AOperation: TNexusScriptCompiledDefinition;
  AInvocation: TNXForgeInvocation);
procedure ExecuteForgeFileOperation(AInvocation: TNXForgeInvocation);

implementation

uses Classes, SysUtils, zipper, tpNXForge;

function IsForgeFileOperation(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'WriteTextFile') or SameText(AKind, 'CopyFile') or
    SameText(AKind, 'DeletePath') or SameText(AKind, 'Archive');
end;

function PropertyText(AOperation: TNexusScriptCompiledDefinition;
  const AName: string): string;
var
  lProperty: TNexusScriptCompiledProperty;
begin
  lProperty := AOperation.FindProperty(AName);
  if (lProperty = nil) or not lProperty.Value.HasEffectiveText then
    raise Exception.Create(AOperation.Name + ': missing text property ' + AName);
  Result := lProperty.Value.EffectiveText;
end;

function OptionalText(AOperation: TNexusScriptCompiledDefinition;
  const AName: string): string;
begin
  Result := '';
  if AOperation.FindProperty(AName) <> nil then
    Result := PropertyText(AOperation, AName);
end;

function OptionalBoolean(AOperation: TNexusScriptCompiledDefinition;
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

procedure PrepareForgeFileOperation(AOperation: TNexusScriptCompiledDefinition;
  AInvocation: TNXForgeInvocation);
begin
  if SameText(AOperation.Kind, 'WriteTextFile') then
  begin
    AInvocation.Kind := fokWriteTextFile;
    AInvocation.OutputPath := OperationPath(AInvocation.WorkingDirectory,
      PropertyText(AOperation, 'Path'));
    AInvocation.ArtifactText := PropertyText(AOperation, 'Text');
  end
  else if SameText(AOperation.Kind, 'DeletePath') then
  begin
    AInvocation.Kind := fokDeletePath;
    AInvocation.SourcePath := OperationPath(AInvocation.WorkingDirectory,
      PropertyText(AOperation, 'Path'));
    AInvocation.Recursive := OptionalBoolean(AOperation, 'Recursive', False);
    AInvocation.MissingOk := OptionalBoolean(AOperation, 'MissingOk', True);
  end
  else
  begin
    AInvocation.SourcePath := OperationPath(AInvocation.WorkingDirectory,
      PropertyText(AOperation, 'Source'));
    AInvocation.OutputPath := OperationPath(AInvocation.WorkingDirectory,
      PropertyText(AOperation, 'Destination'));
    AInvocation.Overwrite := OptionalBoolean(AOperation, 'Overwrite', False);
    AInvocation.ExcludeNames := OptionalText(AOperation, 'ExcludeNames');
    if SameText(AOperation.Kind, 'CopyFile') then
    begin
      AInvocation.Kind := fokCopyFile;
      AInvocation.Recursive := OptionalBoolean(AOperation, 'Recursive', False);
      AInvocation.CleanDestination := OptionalBoolean(AOperation,
        'CleanDestination', False);
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
    lOutput := TFileStream.Create(lDestination, fmCreate);
    try
      lOutput.CopyFrom(lInput, 0);
    finally
      lOutput.Free;
    end;
  finally
    lInput.Free;
  end;
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

procedure CopyDirectory(const ASource, ADestination: string; AOverwrite: Boolean;
  AExcludeNames: TStrings);
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
        CopyDirectory(lSource, lDestination, AOverwrite, AExcludeNames)
      else CopyOneFile(lSource, lDestination, AOverwrite);
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
    CopyOneFile(AInvocation.SourcePath, AInvocation.OutputPath, AInvocation.Overwrite)
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
        AInvocation.Overwrite, lExcludeNames);
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

procedure ExecuteForgeFileOperation(AInvocation: TNXForgeInvocation);
begin
  AInvocation.Started := True;
  try
    case AInvocation.Kind of
      fokWriteTextFile: ExecuteWriteTextFile(AInvocation);
      fokCopyFile: ExecuteCopy(AInvocation);
      fokDeletePath: ExecuteDelete(AInvocation);
      fokArchive: ExecuteArchive(AInvocation);
      else raise Exception.Create('Not a Forge file operation');
    end;
    AInvocation.Completed := True;
  except
    on E: Exception do AInvocation.Diagnostic := E.Message;
  end;
end;

end.
