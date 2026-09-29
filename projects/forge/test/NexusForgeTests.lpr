program NexusForgeTests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, obNXTestRegistry, obNXTestSuite, obNXTestResult,
  tsNXForgeTests, tsNXForgePackageTests;

procedure ChildFile(const AMode: string);
var
  lText: TStringList;
begin
  lText := TStringList.Create;
  try
    if (AMode = 'create') or (AMode = 'partial') then lText.Text := 'package-data'
    else lText.LoadFromFile(ParamStr(3));
    if (AMode = 'create') or (AMode = 'partial') then lText.SaveToFile(ParamStr(3))
    else lText.SaveToFile('done.txt');
    if AMode = 'partial' then ExitCode := 7;
  finally
    lText.Free;
  end;
end;

procedure Run;
var
  lRegistry: TNXTestRegistry;
  lResult: TNXTestResult;
  lSuite, lTest, lPassed, lFailed: Integer;
begin
  lRegistry := TNXTestRegistry.Create;
  lPassed := 0;
  lFailed := 0;
  try
    RegisterForgeTests(lRegistry);
    RegisterForgePackageTests(lRegistry);
    for lSuite := 0 to lRegistry.SuiteCount - 1 do
      for lTest := 0 to lRegistry.Suites[lSuite].TestCount - 1 do
      begin
        lResult := lRegistry.Suites[lSuite].Tests[lTest].Execute(
          lRegistry.Suites[lSuite].Name);
        try
          if lResult.Status = tsPassed then Inc(lPassed) else Inc(lFailed);
          WriteLn(lResult.StatusText, ' ', lResult.TestId, ' ',
            lResult.Message, ' ', lResult.ErrorMessage);
        finally
          lResult.Free;
        end;
      end;
    WriteLn(lPassed, ' passed; ', lFailed, ' failed/errors/skipped');
    if (lFailed <> 0) or (lPassed = 0) then ExitCode := 1;
  finally
    lRegistry.Free;
  end;
end;

begin
  if ParamStr(1) = 'child' then
  begin
    HeapTrc.GlobalSkipIfNoLeaks := True;
    if ParamStr(2) = 'streams' then
    begin
      Write(StringOfChar('O', 1048576));
      Write(StdErr, StringOfChar('E', 1048576));
    end
    else if (ParamStr(2) = 'create') or (ParamStr(2) = 'consume') or
      (ParamStr(2) = 'partial') then ChildFile(ParamStr(2))
    else if ParamStr(2) = 'cwd' then WriteLn(GetCurrentDir)
    else if ParamStr(2) = 'fail' then
    begin
      WriteLn(StdErr, 'failure');
      ExitCode := 7;
    end
    else WriteLn('ok');
  end
  else Run;
end.


