(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program nxbuildTests;

{$mode objfpc}{$H+}

uses
  obNXTestRegistry, obNXTestResult, tsNXBuildTests, tsNXBuildDependencyTests;

procedure RunTests(AKnownProjectIssues: Boolean);
var
  lRegistry: TNXTestRegistry;
  lResult: TNXTestResult;
  lSuite, lTest, lPassed, lFailed: Integer;
begin
  lRegistry := TNXTestRegistry.Create;
  lPassed := 0;
  lFailed := 0;
  try
    if AKnownProjectIssues then
      RegisterNXBuildKnownProjectIssues(lRegistry)
    else
    begin
      RegisterNXBuildTests(lRegistry);
      RegisterNXBuildDependencyTests(lRegistry);
    end;
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
  if (ParamCount > 0) and (ParamStr(1) = '--nxbuild-command') then
    ExitCode := NXBuildRunCommandLine
  else if (ParamCount > 0) and (ParamStr(1) = '--nxbuild-dependency-tool') then
    ExitCode := NXBuildRunDependencyTool
  else if (ParamCount > 0) and (ParamStr(1) = '--nxbuild-test-tool') then
    ExitCode := NXBuildRunTestTool
  else if (ParamCount > 0) and (ParamStr(1) = '--nxbuild-source-tool') then
    ExitCode := NXBuildRunSourceTool
  else
    RunTests((ParamCount > 0) and (ParamStr(1) = '--known-project-issues'));
end.
