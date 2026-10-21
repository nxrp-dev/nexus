// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program nxbuildEngineTests;

{$mode objfpc}{$H+}

uses obNXTestRegistry, obNXTestResult, tsNXBuildEngineTests;

var
  lRegistry: TNXTestRegistry;
  lResult: TNXTestResult;
  lSuite, lTest, lPassed, lFailed: Integer;
  lFilter: string;
begin
  if (ParamCount < 1) or (ParamCount > 3) then
  begin
    WriteLn('Usage: nxbuildEngineTests <actual-Nexus2DEngine.nxproject> [--test=TestId | actual-Solar2DSimulator [original-reproduction-main.lua]]');
    Halt(2);
  end;
  lFilter := '';
  if Copy(ParamStr(2), 1, 7) = '--test=' then
  begin
    if ParamCount <> 2 then Halt(2);
    lFilter := Copy(ParamStr(2), 8, MaxInt);
    if lFilter = '' then Halt(2);
  end;
  lRegistry := TNXTestRegistry.Create;
  lPassed := 0;
  lFailed := 0;
  try
    RegisterNXBuildEngineTests(lRegistry, ParamStr(1));
    if (ParamCount >= 2) and (lFilter = '') then
      RegisterNXBuildEngineRuntimeTests(lRegistry, ParamStr(2), ParamStr(3));
    for lSuite := 0 to lRegistry.SuiteCount - 1 do
      for lTest := 0 to lRegistry.Suites[lSuite].TestCount - 1 do
      begin
        if (lFilter <> '') and
          (lRegistry.Suites[lSuite].Tests[lTest].TestId <> lFilter) then Continue;
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
end.
