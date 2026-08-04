unit obNXTaskCLI;

{$mode objfpc}{$H+}

interface

type
  TNXTaskCLI = class
  private
    class function Arg(AIndex: Integer): string;
    class function TargetArg(const ADefault: string): string;
    class function SamplePath(const AName: string): string;
    class procedure PrintUsage;
    class function RunParse(const AFileName: string): Integer;
    class function RunExpand(const AFileName: string): Integer;
    class function RunInspect(const AFileName, ATarget: string): Integer;
    class function RunExecute(const AFileName, ATarget: string): Integer;
    class function RunTests: Integer;
    class procedure AssertContains(const AText, AExpected, AMessage: string);
    class procedure AssertEquals(const AExpected, AActual, AMessage: string);
  public
    class function Execute: Integer;
  end;

implementation

uses
  Classes, SysUtils, obNXTaskModel, obNXTaskParser, obNXTaskValidation,
  obNXTaskResolver, obNXTaskDump, obNXTaskTargets, obNXTaskExecutor;

class function TNXTaskCLI.Arg(AIndex: Integer): string;
begin
  if ParamCount >= AIndex then
    Result := ParamStr(AIndex)
  else
    Result := '';
end;

class function TNXTaskCLI.TargetArg(const ADefault: string): string;
var
  lIndex: Integer;
begin
  Result := ADefault;
  lIndex := 1;
  while lIndex <= ParamCount do
  begin
    if ParamStr(lIndex) = '-target' then
    begin
      if lIndex < ParamCount then
        Result := ParamStr(lIndex + 1);
      Exit;
    end;
    Inc(lIndex);
  end;
end;

class function TNXTaskCLI.SamplePath(const AName: string): string;
begin
  Result := ExpandFileName(IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    '..\..\samples\' + AName);
  if not FileExists(Result) then
    Result := ExpandFileName('samples\' + AName);
  if not FileExists(Result) then
    Result := ExpandFileName('NexusTask\samples\' + AName);
end;

class procedure TNXTaskCLI.PrintUsage;
begin
  WriteLn('NexusTaskTest parse <file>');
  WriteLn('NexusTaskTest expand <file>');
  WriteLn('NexusTaskTest inspect <file> -target <target>');
  WriteLn('NexusTaskTest execute <file> -target <target>');
  WriteLn('NexusTaskTest test');
end;

class function TNXTaskCLI.RunParse(const AFileName: string): Integer;
var
  lParser: TNXTaskParser;
  lDocument: TNXTaskDocument;
  lValidator: TNXTaskValidator;
begin
  lParser := TNXTaskParser.Create;
  lValidator := TNXTaskValidator.Create;
  try
    lDocument := lParser.ParseFile(AFileName);
    try
      lValidator.ValidateDocument(lDocument);
      Write(TNXTaskDumper.DumpDocument(lDocument, True));
      Write(TNXTaskDumper.DumpDiagnostics(lDocument.Diagnostics));
      if lDocument.Diagnostics.HasErrors then
        Result := 1
      else
        Result := 0;
    finally
      lDocument.Free;
    end;
  finally
    lValidator.Free;
    lParser.Free;
  end;
end;

class function TNXTaskCLI.RunExpand(const AFileName: string): Integer;
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(AFileName);
    try
      Write(TNXTaskDumper.DumpDocument(lDocument, False));
      Write(TNXTaskDumper.DumpDiagnostics(lResolver.Diagnostics));
      if lResolver.Diagnostics.HasErrors then
        Result := 1
      else
        Result := 0;
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

class function TNXTaskCLI.RunInspect(const AFileName, ATarget: string): Integer;
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(AFileName);
    try
      Write(TNXTaskTargetInspector.Inspect(lDocument, ATarget));
      Write(TNXTaskDumper.DumpDiagnostics(lResolver.Diagnostics));
      if lResolver.Diagnostics.HasErrors then
        Result := 1
      else
        Result := 0;
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

class function TNXTaskCLI.RunExecute(const AFileName, ATarget: string): Integer;
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
begin
  lResolver := TNXTaskResolver.Create;
  lExecutor := TNXTaskExecutor.Create;
  try
    lDocument := lResolver.MaterializeFile(AFileName);
    try
      Write(lExecutor.Execute(lDocument, ATarget, ExtractFileDir(ExpandFileName(AFileName))));
      Write(TNXTaskDumper.DumpDiagnostics(lResolver.Diagnostics));
      Write(TNXTaskDumper.DumpDiagnostics(lExecutor.Diagnostics));
      if lResolver.Diagnostics.HasErrors or lExecutor.Diagnostics.HasErrors then
        Result := 1
      else
        Result := 0;
    finally
      lDocument.Free;
    end;
  finally
    lExecutor.Free;
    lResolver.Free;
  end;
end;

class procedure TNXTaskCLI.AssertContains(const AText, AExpected,
  AMessage: string);
begin
  if Pos(AExpected, AText) = 0 then
    raise Exception.Create(AMessage + ' Missing: ' + AExpected);
end;

class procedure TNXTaskCLI.AssertEquals(const AExpected, AActual,
  AMessage: string);
begin
  if AExpected <> AActual then
    raise Exception.CreateFmt('%s Expected "%s" got "%s".',
      [AMessage, AExpected, AActual]);
end;

class function TNXTaskCLI.RunTests: Integer;
var
  lParser: TNXTaskParser;
  lValidator: TNXTaskValidator;
  lDocument: TNXTaskDocument;
  lResolver: TNXTaskResolver;
  lMaterialized: TNXTaskDocument;
  lExecutor: TNXTaskExecutor;
  lText: string;
  lOutputPath: string;
  lOutput: TStringList;
  lTestCount: Integer;
  lFirstPos: Integer;
  lExpandedPos: Integer;
  lLastPos: Integer;
begin
  lTestCount := 0;
  lParser := TNXTaskParser.Create;
  lValidator := TNXTaskValidator.Create;
  lResolver := TNXTaskResolver.Create;
  lExecutor := TNXTaskExecutor.Create;
  try
    lDocument := lParser.ParseFile(SamplePath('root.nxtask'));
    try
      lValidator.ValidateDocument(lDocument);
      lText := TNXTaskDumper.DumpDocument(lDocument, True);
      AssertContains(lText, 'task NexusBuild action Group targets(Debug, Release)',
        'Parse should include root task.');
      AssertContains(lText, 'property RetryCount = integer 3',
        'Parse should preserve integer type.');
      AssertContains(lText, 'property WarningThreshold = float 0.75',
        'Parse should preserve float type.');
      Inc(lTestCount);
    finally
      lDocument.Free;
    end;

    lMaterialized := lResolver.MaterializeFile(SamplePath('root.nxtask'));
    try
      lText := TNXTaskDumper.DumpDocument(lMaterialized, False);
      AssertContains(lText, 'property Mode = string "ObjFPC"',
        'External node expansion should add properties.');
      AssertContains(lText, 'property Output = string "artifacts"',
        'Expanded local reference should use declaration context.');
      Inc(lTestCount);

      lText := TNXTaskTargetInspector.Inspect(lMaterialized, 'Debug');
      if Pos('Package Group', lText) > 0 then
        raise Exception.Create('Release-only package should not appear in Debug projection.');
      Inc(lTestCount);

      lText := lExecutor.Execute(lMaterialized, 'Release',
        ExtractFileDir(SamplePath('root.nxtask')));
      AssertContains(lText, 'enter NexusBuild',
        'Execution should enter root.');
      AssertContains(lText, 'trace EmitPackage "Packaging release output"',
        'Execution should invoke Trace action.');
      Inc(lTestCount);
    finally
      lMaterialized.Free;
    end;

    lDocument := lParser.ParseFile(SamplePath('errors\duplicates.nxtask'));
    try
      lValidator.ValidateDocument(lDocument);
      AssertEquals('True', BoolToStr(lDocument.Diagnostics.HasErrors, True),
        'Duplicate sample should produce diagnostics.');
      Inc(lTestCount);
    finally
      lDocument.Free;
    end;

    lOutputPath := ExpandFileName(IncludeTrailingPathDelimiter(
      ExtractFileDir(SamplePath('write-file.nxtask'))) + 'artifacts\write-text.txt');
    if FileExists(lOutputPath) then
      DeleteFile(lOutputPath);
    lMaterialized := lResolver.MaterializeFile(SamplePath('write-file.nxtask'));
    try
      lExecutor.Execute(lMaterialized, 'Debug', ExtractFileDir(SamplePath('write-file.nxtask')));
      if not FileExists(lOutputPath) then
        raise Exception.Create('WriteTextFile should create output file.');
      lOutput := TStringList.Create;
      try
        lOutput.LoadFromFile(lOutputPath);
        AssertEquals('Hello NexusTask', Trim(lOutput.Text),
          'WriteTextFile should write deterministic content.');
      finally
        lOutput.Free;
      end;
      Inc(lTestCount);
    finally
      lMaterialized.Free;
      if FileExists(lOutputPath) then
        DeleteFile(lOutputPath);
    end;

    lMaterialized := lResolver.MaterializeFile(SamplePath('parent-excludes-child.nxtask'));
    try
      lText := TNXTaskTargetInspector.Inspect(lMaterialized, 'Test');
      if Pos('Child Trace', lText) > 0 then
        raise Exception.Create('Child must not be evaluated when parent excludes target.');
      lText := lExecutor.Execute(lMaterialized, 'Test',
        ExtractFileDir(SamplePath('parent-excludes-child.nxtask')));
      if Pos('must not run', lText) > 0 then
        raise Exception.Create('Child action must not run when parent excludes target.');
      Inc(lTestCount);
    finally
      lMaterialized.Free;
    end;

    lMaterialized := lResolver.MaterializeFile(SamplePath('ordered-expansion.nxtask'));
    try
      lText := lExecutor.Execute(lMaterialized, 'Debug',
        ExtractFileDir(SamplePath('ordered-expansion.nxtask')));
      lFirstPos := Pos('trace First "first"', lText);
      lExpandedPos := Pos('trace Expanded "expanded"', lText);
      lLastPos := Pos('trace Last "last"', lText);
      if (lFirstPos = 0) or (lExpandedPos = 0) or (lLastPos = 0) or
        (lFirstPos > lExpandedPos) or (lExpandedPos > lLastPos) then
        raise Exception.Create('Expanded task should preserve declaration order.');
      Inc(lTestCount);
    finally
      lMaterialized.Free;
    end;
    WriteLn('tests passed ', lTestCount);
    Result := 0;
  finally
    lExecutor.Free;
    lResolver.Free;
    lValidator.Free;
    lParser.Free;
  end;
end;

class function TNXTaskCLI.Execute: Integer;
var
  lCommand: string;
  lFileName: string;
begin
  lCommand := Arg(1);
  if lCommand = 'test' then
    Exit(RunTests);

  lFileName := Arg(2);
  if (lCommand = '') or (lFileName = '') then
  begin
    PrintUsage;
    Exit(1);
  end;

  if lCommand = 'parse' then
    Result := RunParse(lFileName)
  else if lCommand = 'expand' then
    Result := RunExpand(lFileName)
  else if lCommand = 'inspect' then
    Result := RunInspect(lFileName, TargetArg('Debug'))
  else if lCommand = 'execute' then
    Result := RunExecute(lFileName, TargetArg('Debug'))
  else
  begin
    PrintUsage;
    Result := 1;
  end;
end;

end.
