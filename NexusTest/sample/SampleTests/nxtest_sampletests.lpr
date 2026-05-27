library nxtest_sampletests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  tpNXTest,
  obNXTestRegistry,
  obNXTestCommandProcessor,
  tsSampleTests;

type
  TNXStoredCommandResult = class
  private
    FResultId: Integer;
    FResponse: string;
  public
    constructor Create(AResultId: Integer; const AResponse: string);

    property ResultId: Integer read FResultId;
    property Response: string read FResponse;
  end;

var
  gRegistry: TNXTestRegistry = nil;
  gProcessor: TNXTestCommandProcessor = nil;
  gResults: TList = nil;
  gNextResultId: Integer = 1;

constructor TNXStoredCommandResult.Create(AResultId: Integer; const AResponse: string);
begin
  inherited Create;
  FResultId := AResultId;
  FResponse := AResponse;
end;

procedure ClearStoredResults;
var
  lIndex: Integer;
begin
  if not Assigned(gResults) then
    Exit;

  for lIndex := 0 to gResults.Count - 1 do
    TObject(gResults[lIndex]).Free;
  gResults.Clear;
end;

function FindStoredResultIndex(AResultId: Integer): Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  if not Assigned(gResults) then
    Exit;

  for lIndex := 0 to gResults.Count - 1 do
  begin
    if TNXStoredCommandResult(gResults[lIndex]).ResultId = AResultId then
      Exit(lIndex);
  end;
end;

function StoreCommandResult(const AResponse: string; var AResultId: Integer; var AResultSize: Integer): Integer;
var
  lStoredResult: TNXStoredCommandResult;
begin
  if not Assigned(gResults) then
    Exit(cNXTestErrorNotInitialized);

  AResultId := gNextResultId;
  Inc(gNextResultId);

  lStoredResult := TNXStoredCommandResult.Create(AResultId, AResponse);
  gResults.Add(lStoredResult);

  AResultSize := Length(AResponse) + 1;
  Result := cNXTestSuccess;
end;

function NXTest_Init: Integer; cdecl;
begin
  if Assigned(gRegistry) then
    Exit(cNXTestSuccess);

  try
    gRegistry := TNXTestRegistry.Create;
    RegisterSampleTests(gRegistry);
    gProcessor := TNXTestCommandProcessor.Create(gRegistry);
    gResults := TList.Create;
    gNextResultId := 1;
    Result := cNXTestSuccess;
  except
    on E: Exception do
      Result := cNXTestErrorInternal;
  end;
end;

procedure NXTest_Release; cdecl;
begin
  ClearStoredResults;
  FreeAndNil(gResults);
  FreeAndNil(gProcessor);
  FreeAndNil(gRegistry);
end;

function NXTest_ExecuteCommand(ARequest: PChar; var AResultId: Integer; var AResultSize: Integer): Integer; cdecl;
var
  lResponse: string;
begin
  AResultId := 0;
  AResultSize := 0;

  if not Assigned(gProcessor) then
    Exit(cNXTestErrorNotInitialized);

  if ARequest = nil then
    Exit(cNXTestErrorInvalidRequest);

  try
    lResponse := gProcessor.ExecuteCommand(StrPas(ARequest));
    Result := StoreCommandResult(lResponse, AResultId, AResultSize);
  except
    on E: Exception do
      Result := cNXTestErrorInternal;
  end;
end;

function NXTest_ReadResult(AResultId: Integer; ABuffer: PChar; ABufferSize: Integer; var ABytesWritten: Integer): Integer; cdecl;
var
  lIndex: Integer;
  lStoredResult: TNXStoredCommandResult;
  lRequiredSize: Integer;
begin
  ABytesWritten := 0;

  if not Assigned(gResults) then
    Exit(cNXTestErrorNotInitialized);

  if ABuffer = nil then
    Exit(cNXTestErrorInvalidArgument);

  lIndex := FindStoredResultIndex(AResultId);
  if lIndex < 0 then
    Exit(cNXTestErrorUnknownResult);

  lStoredResult := TNXStoredCommandResult(gResults[lIndex]);
  lRequiredSize := Length(lStoredResult.Response) + 1;

  if ABufferSize < lRequiredSize then
    Exit(cNXTestErrorBufferTooSmall);

  StrPCopy(ABuffer, lStoredResult.Response);
  ABytesWritten := lRequiredSize;

  gResults.Delete(lIndex);
  lStoredResult.Free;

  Result := cNXTestSuccess;
end;

exports
  NXTest_Init,
  NXTest_Release,
  NXTest_ExecuteCommand,
  NXTest_ReadResult;

begin
end.
