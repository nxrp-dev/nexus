unit tsNXTaskExecutionTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXTaskExecutionTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes, SysUtils, Process, obNXTestContext, obNXTestSuite, obNXTaskModel,
  obNXTaskResolver, obNXTaskExecutor, tsNXTaskTestSupport;

function NXTaskTestPathForSyntax(const APath: string): string;
begin
  Result := StringReplace(APath, '\', '/', [rfReplaceAll]);
end;

function NXTaskRunProcess(const AExecutable, AWorkingDirectory: string;
  AArguments: array of string; out AOutput: string): Integer;
var
  lBuffer: array[0..2047] of Byte;
  lBytesRead: LongInt;
  lIndex: Integer;
  lOutput: TStringStream;
  lProcess: TProcess;
begin
  lOutput := TStringStream.Create('');
  lProcess := TProcess.Create(nil);
  try
    lProcess.Executable := AExecutable;
    if AWorkingDirectory <> '' then
      lProcess.CurrentDirectory := AWorkingDirectory;
    for lIndex := Low(AArguments) to High(AArguments) do
      lProcess.Parameters.Add(AArguments[lIndex]);
    lProcess.Options := [poUsePipes, poStderrToOutPut];
    lProcess.Execute;
    while lProcess.Running do
    begin
      while lProcess.Output.NumBytesAvailable > 0 do
      begin
        lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
        if lBytesRead > 0 then
          lOutput.Write(lBuffer, lBytesRead);
      end;
      Sleep(10);
    end;
    while lProcess.Output.NumBytesAvailable > 0 do
    begin
      lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
      if lBytesRead > 0 then
        lOutput.Write(lBuffer, lBytesRead);
    end;
    Result := lProcess.ExitStatus;
    AOutput := Trim(lOutput.DataString);
  finally
    lProcess.Free;
    lOutput.Free;
  end;
end;

procedure NXTaskRequireGit(AContext: TNXTestContext);
var
  lOutput: string;
begin
  try
    if NXTaskRunProcess('git', '', ['--version'], lOutput) <> 0 then
      AContext.Skip('Git executable is not available.');
  except
    on E: Exception do
      AContext.Skip('Git executable is not available.');
  end;
end;

procedure NXTaskRequireLazBuild(AContext: TNXTestContext);
var
  lOutput: string;
begin
  try
    if NXTaskRunProcess('lazbuild', '', ['--version'], lOutput) <> 0 then
      AContext.Skip('lazbuild executable is not available.');
  except
    on E: Exception do
      AContext.Skip('lazbuild executable is not available.');
  end;
end;

procedure NXTaskRequireNpm(AContext: TNXTestContext);
var
  lExecutable: string;
  lOutput: string;
begin
  {$ifdef MSWINDOWS}
  lExecutable := 'npm.cmd';
  {$else}
  lExecutable := 'npm';
  {$endif}
  try
    if NXTaskRunProcess(lExecutable, '', ['--version'], lOutput) <> 0 then
      AContext.Skip('npm executable is not available.');
  except
    on E: Exception do
      AContext.Skip('npm executable is not available.');
  end;
end;

procedure NXTaskRemoveTree(const APath: string);
var
  lSearch: TSearchRec;
begin
  if not DirectoryExists(APath) then
    Exit;
  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, lSearch) = 0 then
  begin
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') then
        begin
          if (lSearch.Attr and faDirectory) <> 0 then
            NXTaskRemoveTree(IncludeTrailingPathDelimiter(APath) + lSearch.Name)
          else
            DeleteFile(IncludeTrailingPathDelimiter(APath) + lSearch.Name);
        end;
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;
  RemoveDir(APath);
end;

procedure NXTaskRunGitChecked(AContext: TNXTestContext; const AWorkingDirectory: string;
  AArguments: array of string);
var
  lOutput: string;
begin
  if NXTaskRunProcess('git', AWorkingDirectory, AArguments, lOutput) <> 0 then
    AContext.Fail('Git fixture setup failed: ' + lOutput);
end;

procedure NXTaskWriteTextFile(const APath, AText: string);
var
  lFile: TStringList;
begin
  if ExtractFileDir(APath) <> '' then
    ForceDirectories(ExtractFileDir(APath));
  lFile := TStringList.Create;
  try
    lFile.LineBreak := #10;
    lFile.Text := AText;
    lFile.SaveToFile(APath);
  finally
    lFile.Free;
  end;
end;

function NXTaskReadTrimmedTextFile(const APath: string): string;
var
  lFile: TStringList;
begin
  lFile := TStringList.Create;
  try
    lFile.LoadFromFile(APath);
    Result := Trim(lFile.Text);
  finally
    lFile.Free;
  end;
end;

procedure TestReleaseExecutionTrace(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lExecutor: TNXTaskExecutor;
  lDocument: TNXTaskDocument;
  lText: string;
begin
  lResolver := TNXTaskResolver.Create;
  lExecutor := TNXTaskExecutor.Create;
  try
    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('root.nxtask'));
    try
      lText := lExecutor.Execute(lDocument, 'Release',
        ExtractFileDir(NXTaskSamplePath('root.nxtask')));
      NXTaskAssertContains(AContext, lText, 'enter NexusBuild',
        'Execution should enter root.');
      NXTaskAssertContains(AContext, lText,
        'trace EmitPackage "Packaging release output"',
        'Execution should invoke Trace action.');
      AContext.AssertFalse(Pos('action Group', lText) > 0,
        'Group action should not add duplicate trace output.');
    finally
      lDocument.Free;
    end;
  finally
    lExecutor.Free;
    lResolver.Free;
  end;
end;

procedure TestWriteTextFile(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lExecutor: TNXTaskExecutor;
  lDocument: TNXTaskDocument;
  lOutputPath: string;
  lOutput: TStringList;
begin
  lResolver := TNXTaskResolver.Create;
  lExecutor := TNXTaskExecutor.Create;
  try
    lOutputPath := ExpandFileName(IncludeTrailingPathDelimiter(
      ExtractFileDir(NXTaskSamplePath('write-file.nxtask'))) +
      'artifacts\write-text.txt');
    if FileExists(lOutputPath) then
      DeleteFile(lOutputPath);

    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('write-file.nxtask'));
    try
      lExecutor.Execute(lDocument, 'Debug',
        ExtractFileDir(NXTaskSamplePath('write-file.nxtask')));
      AContext.AssertTrue(FileExists(lOutputPath),
        'WriteTextFile should create output file.');
      lOutput := TStringList.Create;
      try
        lOutput.LoadFromFile(lOutputPath);
        AContext.AssertEquals('Hello NexusTask', Trim(lOutput.Text),
          'WriteTextFile should write deterministic content.');
      finally
        lOutput.Free;
      end;
    finally
      lDocument.Free;
      if FileExists(lOutputPath) then
        DeleteFile(lOutputPath);
    end;
  finally
    lExecutor.Free;
    lResolver.Free;
  end;
end;

procedure TestCopyFileCopiesSingleFile(AContext: TNXTestContext);
var
  lBasePath: string;
  lDestinationPath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lSourcePath: string;
  lTaskFile: string;
  lText: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-copy-' +
    GUIDToString(lGuid);
  lSourcePath := IncludeTrailingPathDelimiter(lBasePath) + 'source.txt';
  lDestinationPath := IncludeTrailingPathDelimiter(lBasePath) + 'out\copy.txt';
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'copy.nxtask';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(lSourcePath, 'copy me');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Copy CopyFile {');
      lFile.Add('    Source: "source.txt"');
      lFile.Add('    Destination: "out/copy.txt"');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lText := lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'CopyFile should copy a valid file without diagnostics.');
        AContext.AssertEquals('copy me',
          NXTaskReadTrimmedTextFile(lDestinationPath),
          'CopyFile should preserve file content.');
        NXTaskAssertContains(AContext, lText, 'copy ',
          'CopyFile should trace copied files.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestCopyFileRequiresOverwriteForExistingDestination(
  AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-copy-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'copy.nxtask';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) + 'source.txt',
      'new');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) + 'copy.txt',
      'old');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Copy CopyFile {');
      lFile.Add('    Source: "source.txt"');
      lFile.Add('    Destination: "copy.txt"');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        NXTaskAssertDiagnostic(AContext, lExecutor.Diagnostics,
          'NXTask.Action.CopyFile.Exists',
          'CopyFile should reject overwrite unless Overwrite is true.');
        AContext.AssertEquals('old', NXTaskReadTrimmedTextFile(
          IncludeTrailingPathDelimiter(lBasePath) + 'copy.txt'),
          'CopyFile should leave destination content unchanged.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestCopyFileOverwritesWhenRequested(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-copy-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'copy.nxtask';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) + 'source.txt',
      'new');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) + 'copy.txt',
      'old');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Copy CopyFile {');
      lFile.Add('    Source: "source.txt"');
      lFile.Add('    Destination: "copy.txt"');
      lFile.Add('    Overwrite: true');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'CopyFile should allow overwrite when requested.');
        AContext.AssertEquals('new', NXTaskReadTrimmedTextFile(
          IncludeTrailingPathDelimiter(lBasePath) + 'copy.txt'),
          'CopyFile should replace destination content.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestCopyFileCopiesDirectoryRecursively(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-copy-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'copy.nxtask';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'source\a.txt', 'root');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'source\nested\b.txt', 'nested');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Copy CopyFile {');
      lFile.Add('    Source: "source"');
      lFile.Add('    Destination: "dest"');
      lFile.Add('    Recursive: true');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'CopyFile should copy directories recursively when requested.');
        AContext.AssertEquals('root', NXTaskReadTrimmedTextFile(
          IncludeTrailingPathDelimiter(lBasePath) + 'dest\a.txt'),
          'CopyFile should copy root directory files.');
        AContext.AssertEquals('nested', NXTaskReadTrimmedTextFile(
          IncludeTrailingPathDelimiter(lBasePath) + 'dest\nested\b.txt'),
          'CopyFile should copy nested files.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestCopyFileExcludesNamedRecursiveItems(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-copy-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'copy.nxtask';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'source\unit.pas', 'unit sample; end.');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'source\.git', 'gitdir: ../.git/modules/sample');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'source\.gitignore', '*.o');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'source\nested\.git', 'gitdir: ../../.git/modules/nested');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'source\nested\keep.txt', 'keep');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'dest\.git', 'stale metadata');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'dest\obsolete.txt', 'stale file');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Copy CopyFile {');
      lFile.Add('    Source: "source"');
      lFile.Add('    Destination: "dest"');
      lFile.Add('    Recursive: true');
      lFile.Add('    ExcludeNames: ".git;.gitignore"');
      lFile.Add('    CleanDestination: true');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'CopyFile should support recursive named exclusions.');
        AContext.AssertTrue(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'dest\unit.pas'), 'CopyFile should still copy regular files.');
        AContext.AssertTrue(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'dest\nested\keep.txt'),
          'CopyFile should still copy regular nested files.');
        AContext.AssertFalse(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'dest\.git'), 'CopyFile should exclude top-level named files.');
        AContext.AssertFalse(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'dest\.gitignore'), 'CopyFile should exclude listed metadata files.');
        AContext.AssertFalse(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'dest\nested\.git'), 'CopyFile should exclude nested named files.');
        AContext.AssertFalse(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'dest\obsolete.txt'),
          'CopyFile should clean stale destination files when requested.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestDeletePathDeletesSingleFile(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTargetPath: string;
  lTaskFile: string;
  lText: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-delete-' +
    GUIDToString(lGuid);
  lTargetPath := IncludeTrailingPathDelimiter(lBasePath) + 'remove.txt';
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'delete.nxtask';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(lTargetPath, 'remove me');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Remove DeletePath {');
      lFile.Add('    Path: "remove.txt"');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lText := lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'DeletePath should delete a valid file without diagnostics.');
        AContext.AssertFalse(FileExists(lTargetPath),
          'DeletePath should remove the file.');
        NXTaskAssertContains(AContext, lText, 'delete ',
          'DeletePath should trace deleted paths.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestDeletePathDeletesDirectoryRecursively(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTargetPath: string;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-delete-' +
    GUIDToString(lGuid);
  lTargetPath := IncludeTrailingPathDelimiter(lBasePath) + 'remove';
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'delete.nxtask';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lTargetPath) +
      'nested\artifact.o', 'object');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Remove DeletePath {');
      lFile.Add('    Path: "remove"');
      lFile.Add('    Recursive: true');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'DeletePath should delete a recursive directory without diagnostics.');
        AContext.AssertFalse(DirectoryExists(lTargetPath),
          'DeletePath should remove the directory tree.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestDeletePathDeletesRecursiveWildcardFiles(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-delete-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'delete.nxtask';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'toolchain\a.ppu', 'compiled unit');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'toolchain\nested\b.ppu', 'nested compiled unit');
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) +
      'toolchain\nested\keep.pas', 'unit keep; end.');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Remove DeletePath {');
      lFile.Add('    Path: "toolchain/*.ppu"');
      lFile.Add('    Recursive: true');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'DeletePath should delete recursive wildcard files without diagnostics.');
        AContext.AssertFalse(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'toolchain\a.ppu'), 'DeletePath should remove root wildcard match.');
        AContext.AssertFalse(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'toolchain\nested\b.ppu'),
          'DeletePath should remove nested wildcard match.');
        AContext.AssertTrue(FileExists(IncludeTrailingPathDelimiter(lBasePath) +
          'toolchain\nested\keep.pas'),
          'DeletePath wildcard should not delete nonmatching files.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestDeletePathReportsMissingWhenRequired(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-delete-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'delete.nxtask';

  ForceDirectories(lBasePath);
  try
    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Remove DeletePath {');
      lFile.Add('    Path: "missing.txt"');
      lFile.Add('    MissingOk: false');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        NXTaskAssertDiagnostic(AContext, lExecutor.Diagnostics,
          'NXTask.Action.DeletePath.Missing',
          'DeletePath should report missing paths when MissingOk is false.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestDiagnosticsResetBetweenExecuteOperations(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lExecutor: TNXTaskExecutor;
  lDocument: TNXTaskDocument;
begin
  lResolver := TNXTaskResolver.Create;
  lExecutor := TNXTaskExecutor.Create;
  try
    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('unknown-action.nxtask'));
    try
      lExecutor.Execute(lDocument, 'Debug',
        ExtractFileDir(NXTaskSamplePath('unknown-action.nxtask')));
      AContext.AssertTrue(lExecutor.Diagnostics.HasErrors,
        'Unknown action should produce executor diagnostics.');
    finally
      lDocument.Free;
    end;

    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('root.nxtask'));
    try
      lExecutor.Execute(lDocument, 'Debug',
        ExtractFileDir(NXTaskSamplePath('root.nxtask')));
      AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
        'Valid execution should not retain previous diagnostics.');
    finally
      lDocument.Free;
    end;
  finally
    lExecutor.Free;
    lResolver.Free;
  end;
end;

procedure TestAssertIsNotABuiltInAction(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lExecutor: TNXTaskExecutor;
  lDocument: TNXTaskDocument;
begin
  lResolver := TNXTaskResolver.Create;
  lExecutor := TNXTaskExecutor.Create;
  try
    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('assert-unknown.nxtask'));
    try
      lExecutor.Execute(lDocument, 'Debug',
        ExtractFileDir(NXTaskSamplePath('assert-unknown.nxtask')));
      NXTaskAssertDiagnostic(AContext, lExecutor.Diagnostics,
        'NXTask.Execute.UnknownAction',
        'Assert should not be registered as a built-in action.');
    finally
      lDocument.Free;
    end;
  finally
    lExecutor.Free;
    lResolver.Free;
  end;
end;

procedure TestGitClonesFreshFolderAndPullsExistingRepo(AContext: TNXTestContext);
var
  lBasePath: string;
  lClonePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lOutput: string;
  lRepoPath: string;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
  lText: string;
begin
  NXTaskRequireGit(AContext);
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-git-' +
    GUIDToString(lGuid);
  lRepoPath := IncludeTrailingPathDelimiter(lBasePath) + 'source';
  lClonePath := IncludeTrailingPathDelimiter(lBasePath) + 'clone';
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'git.nxtask';

  ForceDirectories(lRepoPath);
  try
    NXTaskRunGitChecked(AContext, lRepoPath, ['init']);
    NXTaskRunGitChecked(AContext, lRepoPath,
      ['config', 'user.email', 'nxtask@example.invalid']);
    NXTaskRunGitChecked(AContext, lRepoPath,
      ['config', 'user.name', 'NexusTask Test']);

    lFile := TStringList.Create;
    try
      lFile.Text := 'hello from git' + LineEnding;
      lFile.SaveToFile(IncludeTrailingPathDelimiter(lRepoPath) + 'README.md');
    finally
      lFile.Free;
    end;
    NXTaskRunGitChecked(AContext, lRepoPath, ['add', 'README.md']);
    NXTaskRunGitChecked(AContext, lRepoPath, ['commit', '-m', 'initial']);

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Fetch Git {');
      lFile.Add('    Repository: ' + NXTaskQuoteString(
        NXTaskTestPathForSyntax(lRepoPath)));
      lFile.Add('    Directory: ' + NXTaskQuoteString(
        NXTaskTestPathForSyntax(lClonePath)));
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lText := lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'Git clone should not produce diagnostics.');
        AContext.AssertTrue(FileExists(IncludeTrailingPathDelimiter(lClonePath) +
          'README.md'), 'Git action should clone into the requested directory.');
        NXTaskAssertContains(AContext, lText, 'git clone',
          'Git action should trace clone operations.');

        lOutput := lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'Git pull should not produce diagnostics.');
        NXTaskAssertContains(AContext, lOutput, 'git pull',
          'Git action should pull when the directory is already a Git repo.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestLazBuildBuildsProject(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lProjectPath: string;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
  lText: string;
begin
  NXTaskRequireLazBuild(AContext);
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-lazbuild-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'lazbuild.nxtask';
  lProjectPath := ExpandFileName('NexusTools\Task\NexusTaskTest.lpi');

  ForceDirectories(lBasePath);
  try
    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Build LazBuild {');
      lFile.Add('    Project: ' + NXTaskQuoteString(
        NXTaskTestPathForSyntax(lProjectPath)));
      lFile.Add('    Quiet: true');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lText := lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'LazBuild action should not produce diagnostics for a valid project.');
        NXTaskAssertContains(AContext, lText, 'lazbuild',
          'LazBuild action should trace successful builds.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestNpmRunsPackageScript(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lMarkerPath: string;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
  lText: string;
begin
  NXTaskRequireNpm(AContext);
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-npm-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'npm.nxtask';
  lMarkerPath := IncludeTrailingPathDelimiter(lBasePath) + 'marker.txt';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) + 'package.json',
      '{"scripts":{"mark":"node -e \"require(''fs'').writeFileSync(''marker.txt'',''ok'')\""}}');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Mark Npm {');
      lFile.Add('    Script: "mark"');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lText := lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'Npm action should run a valid package script.');
        AContext.AssertEquals('ok', NXTaskReadTrimmedTextFile(lMarkerPath),
          'Npm package script should create its expected output.');
        NXTaskAssertContains(AContext, lText, 'npm ',
          'Npm action should trace successful npm executions.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestNpmRejectsCommandAndScript(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-npm-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'npm.nxtask';

  ForceDirectories(lBasePath);
  try
    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Bad Npm {');
      lFile.Add('    Command: "ci"');
      lFile.Add('    Script: "package"');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        NXTaskAssertDiagnostic(AContext, lExecutor.Diagnostics,
          'NXTask.Action.Npm.Mode',
          'Npm action should reject Command and Script together.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure TestFpcBuildsProgram(AContext: TNXTestContext);
var
  lBasePath: string;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lFile: TStringList;
  lGuid: TGuid;
  lOutputPath: string;
  lResolver: TNXTaskResolver;
  lTaskFile: string;
begin
  CreateGUID(lGuid);
  lBasePath := IncludeTrailingPathDelimiter(GetTempDir) + 'nxtask-fpc-' +
    GUIDToString(lGuid);
  lTaskFile := IncludeTrailingPathDelimiter(lBasePath) + 'fpc.nxtask';
  lOutputPath := IncludeTrailingPathDelimiter(lBasePath) + 'out\hello';

  ForceDirectories(lBasePath);
  try
    NXTaskWriteTextFile(IncludeTrailingPathDelimiter(lBasePath) + 'hello.lpr',
      'program hello;' + LineEnding + 'begin' + LineEnding +
      '  WriteLn(''hello'');' + LineEnding + 'end.');

    lFile := TStringList.Create;
    try
      lFile.LineBreak := #10;
      lFile.Add('Root Group {');
      lFile.Add('  Build Fpc {');
      lFile.Add('    Source: "hello.lpr"');
      lFile.Add('    UnitOutputDirectory: "out/units"');
      lFile.Add('    OutputDirectory: "out"');
      lFile.Add('    OutputName: "hello"');
      lFile.Add('  }');
      lFile.Add('}');
      lFile.SaveToFile(lTaskFile);
    finally
      lFile.Free;
    end;

    lResolver := TNXTaskResolver.Create;
    lExecutor := TNXTaskExecutor.Create;
    try
      lDocument := lResolver.MaterializeFile(lTaskFile);
      try
        lExecutor.Execute(lDocument, 'Debug', lBasePath);
        AContext.AssertFalse(lExecutor.Diagnostics.HasErrors,
          'Fpc action should build a valid program.');
        AContext.AssertTrue(FileExists(lOutputPath),
          'Fpc action should create the expected executable.');
      finally
        lDocument.Free;
      end;
    finally
      lExecutor.Free;
      lResolver.Free;
    end;
  finally
    NXTaskRemoveTree(lBasePath);
  end;
end;

procedure RegisterNXTaskExecutionTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusTask.Execution');
  lSuite.AddTest('ReleaseExecutionTrace', @TestReleaseExecutionTrace);
  lSuite.AddTest('WriteTextFile', @TestWriteTextFile);
  lSuite.AddTest('CopyFileCopiesSingleFile', @TestCopyFileCopiesSingleFile);
  lSuite.AddTest('CopyFileRequiresOverwriteForExistingDestination',
    @TestCopyFileRequiresOverwriteForExistingDestination);
  lSuite.AddTest('CopyFileOverwritesWhenRequested',
    @TestCopyFileOverwritesWhenRequested);
  lSuite.AddTest('CopyFileCopiesDirectoryRecursively',
    @TestCopyFileCopiesDirectoryRecursively);
  lSuite.AddTest('CopyFileExcludesNamedRecursiveItems',
    @TestCopyFileExcludesNamedRecursiveItems);
  lSuite.AddTest('DeletePathDeletesSingleFile',
    @TestDeletePathDeletesSingleFile);
  lSuite.AddTest('DeletePathDeletesDirectoryRecursively',
    @TestDeletePathDeletesDirectoryRecursively);
  lSuite.AddTest('DeletePathDeletesRecursiveWildcardFiles',
    @TestDeletePathDeletesRecursiveWildcardFiles);
  lSuite.AddTest('DeletePathReportsMissingWhenRequired',
    @TestDeletePathReportsMissingWhenRequired);
  lSuite.AddTest('DiagnosticsResetBetweenExecuteOperations',
    @TestDiagnosticsResetBetweenExecuteOperations);
  lSuite.AddTest('AssertIsNotABuiltInAction', @TestAssertIsNotABuiltInAction);
  lSuite.AddTest('GitClonesFreshFolderAndPullsExistingRepo',
    @TestGitClonesFreshFolderAndPullsExistingRepo);
  lSuite.AddTest('LazBuildBuildsProject', @TestLazBuildBuildsProject);
  lSuite.AddTest('NpmRunsPackageScript', @TestNpmRunsPackageScript);
  lSuite.AddTest('NpmRejectsCommandAndScript', @TestNpmRejectsCommandAndScript);
  lSuite.AddTest('FpcBuildsProgram', @TestFpcBuildsProgram);
end;

end.
