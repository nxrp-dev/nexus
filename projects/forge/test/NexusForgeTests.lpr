(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program NexusForgeTests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, obNXTestRegistry, obNXTestSuite, obNXTestResult,
  tsNXForgeTests, tsNexusSystemTests {$IFDEF UNIX}, BaseUnix{$ENDIF};

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
    if ParamStr(1) <> '--system' then RegisterForgeTests(lRegistry);
    RegisterNexusSystemTests(lRegistry);
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
  if ParamStr(1) = '-iW' then WriteLn('1.0-ForgeIdentityTest')
  else if ParamStr(1) = '-iD' then WriteLn('2026/10/19')
  else if ParamStr(1) = 'child' then
  begin
    if ParamStr(2) = 'streams' then
    begin
      Write(StringOfChar('O', 1048576));
      Write(StdErr, StringOfChar('E', 1048576));
    end
    else if ParamStr(2) = 'cwd' then WriteLn(GetCurrentDir)
    else if ParamStr(2) = 'fail' then
    begin
      WriteLn(StdErr, 'failure');
      ExitCode := 7;
    end
    {$IFDEF UNIX}
    else if ParamStr(2) = 'signal' then
    begin
      if fpKill(fpGetPid, SIGKILL) <> 0 then RaiseLastOSError;
    end
    {$ENDIF}
    else WriteLn('ok');
  end
  else Run;
end.


