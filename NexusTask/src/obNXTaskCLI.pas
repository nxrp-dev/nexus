unit obNXTaskCLI;

{$mode objfpc}{$H+}

interface

type
  TNXTaskCLI = class
  private
    class function Arg(AIndex: Integer): string;
    class function TargetArg(const ADefault: string): string;
    class procedure PrintUsage;
    class function RunParse(const AFileName: string): Integer;
    class function RunExpand(const AFileName: string): Integer;
    class function RunInspect(const AFileName, ATarget: string): Integer;
    class function RunExecute(const AFileName, ATarget: string): Integer;
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

class procedure TNXTaskCLI.PrintUsage;
begin
  WriteLn('NexusTaskTest parse <file>');
  WriteLn('NexusTaskTest expand <file>');
  WriteLn('NexusTaskTest inspect <file> -target <target>');
  WriteLn('NexusTaskTest execute <file> -target <target>');
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
      Write(TNXTaskDumper.DumpDiagnostics(lResolver.Diagnostics));
      if lResolver.Diagnostics.HasErrors then
      begin
        Result := 1
      end
      else
      begin
        Write(lExecutor.Execute(lDocument, ATarget, ExtractFileDir(ExpandFileName(AFileName))));
        Write(TNXTaskDumper.DumpDiagnostics(lExecutor.Diagnostics));
        if lExecutor.Diagnostics.HasErrors then
          Result := 1
        else
          Result := 0;
      end;
    finally
      lDocument.Free;
    end;
  finally
    lExecutor.Free;
    lResolver.Free;
  end;
end;

class function TNXTaskCLI.Execute: Integer;
var
  lCommand: string;
  lFileName: string;
begin
  lCommand := Arg(1);
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
