program nxtest_host;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, DynLibs, tpNXTest;

type
  TNXTestInitFunc = function: Integer; cdecl;
  TNXTestReleaseProc = procedure; cdecl;
  TNXTestExecuteCommandFunc = function(ARequest: PChar; AResponse: PChar; AResponseSize: Integer; var ABytesWritten: Integer): Integer; cdecl;

function ExecuteCommand(AExecuteCommand: TNXTestExecuteCommandFunc; const ARequest: string): string;
var
  lStatus: Integer;
  lBytesWritten: Integer;
  lBuffer: PChar;
  lBufferSize: Integer;
begin
  Result := '';
  lBufferSize := 1024 * 1024;
  GetMem(lBuffer, lBufferSize);
  try
    lBytesWritten := 0;
    lStatus := AExecuteCommand(PChar(ARequest), lBuffer, lBufferSize, lBytesWritten);
    if lStatus = cNXTestErrorBufferTooSmall then
      raise Exception.CreateFmt('Response buffer too small. Required=%d', [lBytesWritten]);
    if lStatus <> cNXTestSuccess then
      raise Exception.CreateFmt('NXTest_ExecuteCommand failed. Status=%d', [lStatus]);

    Result := StrPas(lBuffer);
  finally
    FreeMem(lBuffer);
  end;
end;

function BuildRequest(AId: Integer; const AMethod, AParams: string): string;
begin
  if AParams = '' then
    Result := Format('{"jsonrpc":"2.0","id":%d,"method":"%s","params":{}}', [AId, AMethod])
  else
    Result := Format('{"jsonrpc":"2.0","id":%d,"method":"%s","params":%s}', [AId, AMethod, AParams]);
end;

procedure Run;
var
  lLibraryName: string;
  lHandle: TLibHandle;
  lInit: TNXTestInitFunc;
  lRelease: TNXTestReleaseProc;
  lExecuteCommand: TNXTestExecuteCommandFunc;
  lStatus: Integer;
begin
  if ParamCount < 1 then
  begin
    WriteLn('Usage: nxtest_host <test-library> [command]');
    WriteLn('Commands: capabilities, list, run-all, run-test <test-id>, run-suite <suite>');
    Halt(1);
  end;

  lLibraryName := ParamStr(1);
  lHandle := LoadLibrary(lLibraryName);
  if lHandle = 0 then
    raise Exception.Create('Unable to load library: ' + lLibraryName);

  try
    Pointer(lInit) := GetProcedureAddress(lHandle, 'NXTest_Init');
    Pointer(lRelease) := GetProcedureAddress(lHandle, 'NXTest_Release');
    Pointer(lExecuteCommand) := GetProcedureAddress(lHandle, 'NXTest_ExecuteCommand');

    if not Assigned(lInit) or not Assigned(lRelease) or not Assigned(lExecuteCommand) then
      raise Exception.Create('The library does not expose the required NXTest functions.');

    lStatus := lInit();
    if lStatus <> cNXTestSuccess then
      raise Exception.CreateFmt('NXTest_Init failed. Status=%d', [lStatus]);

    try
      if (ParamCount = 1) or SameText(ParamStr(2), 'list') then
        WriteLn(ExecuteCommand(lExecuteCommand, BuildRequest(1, cNXTestMethodListTests, '')))
      else if SameText(ParamStr(2), 'capabilities') then
        WriteLn(ExecuteCommand(lExecuteCommand, BuildRequest(1, cNXTestMethodGetCapabilities, '')))
      else if SameText(ParamStr(2), 'run-all') then
        WriteLn(ExecuteCommand(lExecuteCommand, BuildRequest(1, cNXTestMethodRunAll, '')))
      else if SameText(ParamStr(2), 'run-test') then
      begin
        if ParamCount < 3 then
          raise Exception.Create('run-test requires a test id.');
        WriteLn(ExecuteCommand(lExecuteCommand, BuildRequest(1, cNXTestMethodRunTest, Format('{"test":"%s"}', [ParamStr(3)]))));
      end
      else if SameText(ParamStr(2), 'run-suite') then
      begin
        if ParamCount < 3 then
          raise Exception.Create('run-suite requires a suite name.');
        WriteLn(ExecuteCommand(lExecuteCommand, BuildRequest(1, cNXTestMethodRunSuite, Format('{"suite":"%s"}', [ParamStr(3)]))));
      end
      else
        raise Exception.Create('Unknown command: ' + ParamStr(2));
    finally
      lRelease();
    end;
  finally
    UnloadLibrary(lHandle);
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      Halt(1);
    end;
  end;
end.
