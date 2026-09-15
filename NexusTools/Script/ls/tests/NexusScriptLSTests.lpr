program NexusScriptLSTests;

{$mode objfpc}{$H+}

uses
  SysUtils, obNXTestRegistry, obNXTestSuite, obNXTestResult, tsNexusScriptLSShellTests;

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
    RegisterNexusScriptLSShellTests(lRegistry);
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
  Run;
end.
