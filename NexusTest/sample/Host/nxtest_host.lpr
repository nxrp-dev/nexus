program nxtest_host;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, DynLibs, fpjson, tpNXTest;

type
  TNXTestInitFunc = function: Integer; cdecl;
  TNXTestReleaseProc = procedure; cdecl;
  TNXTestExecuteCommandFunc = function(ARequest: PAnsiChar; var AResultId: Integer; var AResultSize: Integer): Integer; cdecl;
  TNXTestReadResultFunc = function(AResultId: Integer; ABuffer: PAnsiChar; ABufferSize: Integer; var ABytesWritten: Integer): Integer; cdecl;

function ExecuteCommand(AExecuteCommand: TNXTestExecuteCommandFunc; AReadResult: TNXTestReadResultFunc; const ARequest: string): string;
var
  lStatus: Integer;
  lResultId: Integer;
  lResultSize: Integer;
  lBytesWritten: Integer;
  lBuffer: PAnsiChar;
begin
  Result := '';
  lResultId := 0;
  lResultSize := 0;

  lStatus := AExecuteCommand(PAnsiChar(ARequest), lResultId, lResultSize);
  if lStatus <> cNXTestSuccess then
    raise Exception.CreateFmt('NXTest_ExecuteCommand failed. Status=%d', [lStatus]);

  if lResultSize <= 0 then
    raise Exception.CreateFmt('NXTest_ExecuteCommand returned invalid result size. ResultSize=%d', [lResultSize]);

  GetMem(lBuffer, lResultSize);
  try
    lBytesWritten := 0;
    lStatus := AReadResult(lResultId, lBuffer, lResultSize, lBytesWritten);
    if lStatus <> cNXTestSuccess then
      raise Exception.CreateFmt('NXTest_ReadResult failed. Status=%d BytesWritten=%d', [lStatus, lBytesWritten]);

    if lBytesWritten <> lResultSize then
      raise Exception.CreateFmt('NXTest_ReadResult returned unexpected size. Expected=%d Actual=%d', [lResultSize, lBytesWritten]);

    Result := StrPas(lBuffer);
  finally
    FreeMem(lBuffer);
  end;
end;

function BuildRequest(AId: Integer; const AMethod: string; AParams: TJSONObject = nil): string;
var
  lRequest: TJSONObject;
begin
  lRequest := TJSONObject.Create;
  try
    lRequest.Add('jsonrpc', '2.0');
    lRequest.Add('id', AId);
    lRequest.Add('method', AMethod);

    if Assigned(AParams) then
      lRequest.Add('params', AParams)
    else
      lRequest.Add('params', TJSONObject.Create);

    Result := lRequest.AsJSON;
  finally
    lRequest.Free;
  end;
end;

function BuildSingleStringParam(const AName, AValue: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add(AName, AValue);
end;

procedure Run;
var
  lLibraryName: string;
  lHandle: TLibHandle;
  lInit: TNXTestInitFunc;
  lRelease: TNXTestReleaseProc;
  lExecuteCommand: TNXTestExecuteCommandFunc;
  lReadResult: TNXTestReadResultFunc;
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
    Pointer(lReadResult) := GetProcedureAddress(lHandle, 'NXTest_ReadResult');

    if not Assigned(lInit) or not Assigned(lRelease) or not Assigned(lExecuteCommand) or not Assigned(lReadResult) then
      raise Exception.Create('The library does not expose the required NXTest functions.');

    lStatus := lInit();
    if lStatus <> cNXTestSuccess then
      raise Exception.CreateFmt('NXTest_Init failed. Status=%d', [lStatus]);

    try
      if (ParamCount = 1) or SameText(ParamStr(2), 'list') then
        WriteLn(ExecuteCommand(lExecuteCommand, lReadResult, BuildRequest(1, cNXTestMethodListTests)))
      else if SameText(ParamStr(2), 'capabilities') then
        WriteLn(ExecuteCommand(lExecuteCommand, lReadResult, BuildRequest(1, cNXTestMethodGetCapabilities)))
      else if SameText(ParamStr(2), 'run-all') then
        WriteLn(ExecuteCommand(lExecuteCommand, lReadResult, BuildRequest(1, cNXTestMethodRunAll)))
      else if SameText(ParamStr(2), 'run-test') then
      begin
        if ParamCount < 3 then
          raise Exception.Create('run-test requires a test id.');
        WriteLn(ExecuteCommand(lExecuteCommand, lReadResult, BuildRequest(1, cNXTestMethodRunTest, BuildSingleStringParam('test', ParamStr(3)))));
      end
      else if SameText(ParamStr(2), 'run-suite') then
      begin
        if ParamCount < 3 then
          raise Exception.Create('run-suite requires a suite name.');
        WriteLn(ExecuteCommand(lExecuteCommand, lReadResult, BuildRequest(1, cNXTestMethodRunSuite, BuildSingleStringParam('suite', ParamStr(3)))));
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
