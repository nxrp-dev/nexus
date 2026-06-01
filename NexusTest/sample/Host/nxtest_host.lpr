program nxtest_host;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, DynLibs, fpjson, jsonparser, tpNXTest;

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
      lRequest.Add('params', AParams);

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

function NXHostCleanFileName(const AValue: string): string;
var
  lIndex: Integer;
begin
  Result := AValue;
  for lIndex := 1 to Length(Result) do
    if not (Result[lIndex] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.']) then
      Result[lIndex] := '-';
end;

function NXHostArtifactDirectory: string;
var
  lDirectory: string;
begin
  lDirectory := GetEnvironmentVariable('NEXUS_TEST_ARTIFACT_DIR');
  if lDirectory <> '' then
    Exit(IncludeTrailingPathDelimiter(lDirectory));

  lDirectory := IncludeTrailingPathDelimiter(GetCurrentDir) + 'output';
  if DirectoryExists(lDirectory) then
    Exit(IncludeTrailingPathDelimiter(lDirectory) + 'NexusTestHost' +
      DirectorySeparator + 'test-artifacts' + DirectorySeparator);

  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'test-artifacts' + DirectorySeparator;
end;

function NXHostJSONText(AObject: TJSONObject; const AName: string): string;
var
  lValue: TJSONData;
begin
  Result := '';
  lValue := AObject.Find(AName);
  if Assigned(lValue) then
    Result := lValue.AsString;
end;

function NXHostJSONInt(AObject: TJSONObject; const AName: string): Integer;
var
  lValue: TJSONData;
begin
  Result := 0;
  lValue := AObject.Find(AName);
  if Assigned(lValue) then
    Result := lValue.AsInteger;
end;

procedure NXHostAddTextLine(ALines: TStrings; const AName: string;
  const AValue: Integer);
begin
  ALines.Add(Format('%s: %d', [AName, AValue]));
end;

procedure NXHostWriteTestSummaryArtifacts(const ALibraryName, ACommand,
  ASuiteName, AResponse: string);
var
  lData: TJSONData;
  lResponse: TJSONObject;
  lResult: TJSONObject;
  lResults: TJSONArray;
  lTest: TJSONObject;
  lSummary: TJSONObject;
  lLines: TStringList;
  lDirectory: string;
  lBaseName: string;
  lStatus: string;
  lIndex: Integer;
  lTotal: Integer;
  lPassed: Integer;
  lFailed: Integer;
  lError: Integer;
  lSkipped: Integer;
  lNotRun: Integer;
  lOther: Integer;
  lDurationMs: Integer;
begin
  lData := GetJSON(AResponse);
  try
    if (lData.JSONType <> jtObject) then
      Exit;

    lResponse := TJSONObject(lData);
    if not Assigned(lResponse.Find('result')) or
      (lResponse.Find('result').JSONType <> jtObject) then
      Exit;

    lResult := TJSONObject(lResponse.Find('result'));
    if not Assigned(lResult.Find('results')) or
      (lResult.Find('results').JSONType <> jtArray) then
      Exit;

    lResults := TJSONArray(lResult.Find('results'));
    lTotal := lResults.Count;
    lPassed := 0;
    lFailed := 0;
    lError := 0;
    lSkipped := 0;
    lNotRun := 0;
    lOther := 0;
    lDurationMs := 0;

    for lIndex := 0 to lResults.Count - 1 do
    begin
      if lResults.Items[lIndex].JSONType <> jtObject then
      begin
        Inc(lOther);
        Continue;
      end;

      lTest := TJSONObject(lResults.Items[lIndex]);
      lStatus := NXHostJSONText(lTest, 'status');
      lDurationMs := lDurationMs + NXHostJSONInt(lTest, 'durationMs');

      if SameText(lStatus, cNXTestStatusPassed) then
        Inc(lPassed)
      else if SameText(lStatus, cNXTestStatusFailed) then
        Inc(lFailed)
      else if SameText(lStatus, cNXTestStatusError) then
        Inc(lError)
      else if SameText(lStatus, cNXTestStatusSkipped) then
        Inc(lSkipped)
      else if SameText(lStatus, cNXTestStatusNotRun) then
        Inc(lNotRun)
      else
        Inc(lOther);
    end;

    lSummary := TJSONObject.Create;
    try
      lSummary.Add('schema', 'nexus-test-summary-v1');
      lSummary.Add('generatedAt', FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', Now));
      lSummary.Add('command', ACommand);
      lSummary.Add('library', ExpandFileName(ALibraryName));
      if ASuiteName <> '' then
        lSummary.Add('suite', ASuiteName);
      lSummary.Add('total', lTotal);
      lSummary.Add('passed', lPassed);
      lSummary.Add('failed', lFailed);
      lSummary.Add('error', lError);
      lSummary.Add('skipped', lSkipped);
      lSummary.Add('notRun', lNotRun);
      lSummary.Add('other', lOther);
      lSummary.Add('durationMs', lDurationMs);
      lSummary.Add('successful', (lFailed = 0) and (lError = 0));
      lSummary.Add('results', lResults.Clone);

      lDirectory := NXHostArtifactDirectory;
      ForceDirectories(lDirectory);
      lBaseName := 'nxtest-' + NXHostCleanFileName(ACommand);
      if ASuiteName <> '' then
        lBaseName := lBaseName + '-' + NXHostCleanFileName(ASuiteName);
      lBaseName := lBaseName + '-summary';

      lLines := TStringList.Create;
      try
        lLines.Add('Nexus test summary');
        lLines.Add('Command: ' + ACommand);
        if ASuiteName <> '' then
          lLines.Add('Suite: ' + ASuiteName);
        lLines.Add('Library: ' + ExpandFileName(ALibraryName));
        NXHostAddTextLine(lLines, 'Total', lTotal);
        NXHostAddTextLine(lLines, 'Passed', lPassed);
        NXHostAddTextLine(lLines, 'Failed', lFailed);
        NXHostAddTextLine(lLines, 'Error', lError);
        NXHostAddTextLine(lLines, 'Skipped', lSkipped);
        NXHostAddTextLine(lLines, 'Not run', lNotRun);
        NXHostAddTextLine(lLines, 'Other', lOther);
        NXHostAddTextLine(lLines, 'Duration ms', lDurationMs);
        lLines.SaveToFile(lDirectory + lBaseName + '.txt');
      finally
        lLines.Free;
      end;

      with TStringList.Create do
      try
        Text := lSummary.FormatJSON;
        SaveToFile(lDirectory + lBaseName + '.json');
      finally
        Free;
      end;
    finally
      lSummary.Free;
    end;
  finally
    lData.Free;
  end;
end;

procedure NXHostPrintRunResult(AExecuteCommand: TNXTestExecuteCommandFunc;
  AReadResult: TNXTestReadResultFunc; const ALibraryName, ACommand,
  ARequest: string; const ASuiteName: string = '');
var
  lResponse: string;
begin
  lResponse := ExecuteCommand(AExecuteCommand, AReadResult, ARequest);
  WriteLn(lResponse);

  try
    NXHostWriteTestSummaryArtifacts(ALibraryName, ACommand, ASuiteName, lResponse);
  except
    on E: Exception do
      WriteLn(StdErr, 'Unable to write test summary artifact: ' + E.Message);
  end;
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
        NXHostPrintRunResult(lExecuteCommand, lReadResult, lLibraryName, 'run-all',
          BuildRequest(1, cNXTestMethodRunAll))
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
        NXHostPrintRunResult(lExecuteCommand, lReadResult, lLibraryName,
          'run-suite', BuildRequest(1, cNXTestMethodRunSuite,
          BuildSingleStringParam('suite', ParamStr(3))), ParamStr(3));
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
