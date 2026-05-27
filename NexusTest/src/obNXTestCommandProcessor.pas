unit obNXTestCommandProcessor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, obNXTestRegistry, obNXTestRunner,
  obNXTestResult, tpNXTest;

type
  TNXTestCommandProcessor = class
  private
    FRegistry: TNXTestRegistry;
    FRunner: TNXTestRunner;
    function CreateResponse(AId: TJSONData; AResult: TJSONData): TJSONObject;
    function CreateError(AId: TJSONData; ACode: Integer; const AMessage: string): TJSONObject;
    function CloneId(AId: TJSONData): TJSONData;
    function GetStringParam(AParams: TJSONData; const AName: string): string;
    function HandleCommand(ARequest: TJSONObject): TJSONObject;
    function HandleGetCapabilities(ARequest: TJSONObject): TJSONObject;
    function HandleListTests(ARequest: TJSONObject): TJSONObject;
    function HandleRunAll(ARequest: TJSONObject): TJSONObject;
    function HandleRunSuite(ARequest: TJSONObject): TJSONObject;
    function HandleRunTest(ARequest: TJSONObject): TJSONObject;
  public
    constructor Create(ARegistry: TNXTestRegistry);
    destructor Destroy; override;

    function ExecuteCommand(const ARequest: string): string;
  end;

implementation

constructor TNXTestCommandProcessor.Create(ARegistry: TNXTestRegistry);
begin
  inherited Create;
  FRegistry := ARegistry;
  FRunner := TNXTestRunner.Create(FRegistry);
end;

destructor TNXTestCommandProcessor.Destroy;
begin
  FRunner.Free;
  inherited Destroy;
end;

function TNXTestCommandProcessor.CloneId(AId: TJSONData): TJSONData;
begin
  if Assigned(AId) then
    Result := AId.Clone
  else
    Result := TJSONNull.Create;
end;

function TNXTestCommandProcessor.CreateResponse(AId: TJSONData; AResult: TJSONData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('jsonrpc', '2.0');
  Result.Add('id', CloneId(AId));
  Result.Add('result', AResult);
end;

function TNXTestCommandProcessor.CreateError(AId: TJSONData; ACode: Integer; const AMessage: string): TJSONObject;
var
  lError: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('jsonrpc', '2.0');
  Result.Add('id', CloneId(AId));

  lError := TJSONObject.Create;
  lError.Add('code', ACode);
  lError.Add('message', AMessage);
  Result.Add('error', lError);
end;

function TNXTestCommandProcessor.GetStringParam(AParams: TJSONData; const AName: string): string;
var
  lObject: TJSONObject;
  lData: TJSONData;
begin
  Result := '';
  if not (AParams is TJSONObject) then
    Exit;

  lObject := TJSONObject(AParams);
  lData := lObject.Find(AName);
  if Assigned(lData) then
    Result := lData.AsString;
end;

function TNXTestCommandProcessor.HandleGetCapabilities(ARequest: TJSONObject): TJSONObject;
var
  lCapabilities: TJSONObject;
  lMethods: TJSONArray;
begin
  lCapabilities := TJSONObject.Create;
  lCapabilities.Add('apiVersion', cNXTestApiVersion);
  lCapabilities.Add('protocol', 'json-rpc-2.0');

  lMethods := TJSONArray.Create;
  lMethods.Add(cNXTestMethodGetCapabilities);
  lMethods.Add(cNXTestMethodListTests);
  lMethods.Add(cNXTestMethodRunTest);
  lMethods.Add(cNXTestMethodRunSuite);
  lMethods.Add(cNXTestMethodRunAll);
  lCapabilities.Add('methods', lMethods);

  Result := CreateResponse(ARequest.Find('id'), lCapabilities);
end;

function TNXTestCommandProcessor.HandleListTests(ARequest: TJSONObject): TJSONObject;
begin
  Result := CreateResponse(ARequest.Find('id'), FRegistry.ToJsonObject);
end;

function TNXTestCommandProcessor.HandleRunAll(ARequest: TJSONObject): TJSONObject;
var
  lObject: TJSONObject;
begin
  lObject := TJSONObject.Create;
  lObject.Add('results', FRunner.RunAll);
  Result := CreateResponse(ARequest.Find('id'), lObject);
end;

function TNXTestCommandProcessor.HandleRunSuite(ARequest: TJSONObject): TJSONObject;
var
  lSuiteName: string;
  lObject: TJSONObject;
begin
  lSuiteName := GetStringParam(ARequest.Find('params'), 'suite');
  if lSuiteName = '' then
    Exit(CreateError(ARequest.Find('id'), cNXTestErrorInvalidRequest, 'Missing suite parameter.'));

  if not Assigned(FRegistry.FindSuite(lSuiteName)) then
    Exit(CreateError(ARequest.Find('id'), cNXTestErrorUnknownTest, 'Unknown suite.'));

  lObject := TJSONObject.Create;
  lObject.Add('suite', lSuiteName);
  lObject.Add('results', FRunner.RunSuite(lSuiteName));
  Result := CreateResponse(ARequest.Find('id'), lObject);
end;

function TNXTestCommandProcessor.HandleRunTest(ARequest: TJSONObject): TJSONObject;
var
  lTestId: string;
  lTestResult: TNXTestResult;
  lJsonResult: TJSONObject;
begin
  lTestId := GetStringParam(ARequest.Find('params'), 'test');
  if lTestId = '' then
    Exit(CreateError(ARequest.Find('id'), cNXTestErrorInvalidRequest, 'Missing test parameter.'));

  lTestResult := FRunner.RunTest(lTestId);
  if not Assigned(lTestResult) then
    Exit(CreateError(ARequest.Find('id'), cNXTestErrorUnknownTest, 'Unknown test.'));

  lJsonResult := lTestResult.ToJsonObject;
  Result := CreateResponse(ARequest.Find('id'), lJsonResult);
end;

function TNXTestCommandProcessor.HandleCommand(ARequest: TJSONObject): TJSONObject;
var
  lMethod: string;
begin
  lMethod := ARequest.Get('method', '');

  if lMethod = cNXTestMethodGetCapabilities then
    Result := HandleGetCapabilities(ARequest)
  else if lMethod = cNXTestMethodListTests then
    Result := HandleListTests(ARequest)
  else if lMethod = cNXTestMethodRunTest then
    Result := HandleRunTest(ARequest)
  else if lMethod = cNXTestMethodRunSuite then
    Result := HandleRunSuite(ARequest)
  else if lMethod = cNXTestMethodRunAll then
    Result := HandleRunAll(ARequest)
  else
    Result := CreateError(ARequest.Find('id'), cNXTestErrorUnknownCommand, 'Unknown command.');
end;

function TNXTestCommandProcessor.ExecuteCommand(const ARequest: string): string;
var
  lData: TJSONData;
  lResponse: TJSONObject;
begin
  lData := nil;
  lResponse := nil;
  try
    lData := GetJSON(ARequest);
    if not (lData is TJSONObject) then
      lResponse := CreateError(nil, cNXTestErrorInvalidRequest, 'Request must be a JSON object.')
    else
      lResponse := HandleCommand(TJSONObject(lData));

    Result := lResponse.AsJSON;
  except
    on E: Exception do
    begin
      FreeAndNil(lResponse);
      lResponse := CreateError(nil, cNXTestErrorInternal, E.Message);
      Result := lResponse.AsJSON;
    end;
  end;

  lResponse.Free;
  lData.Free;
end;

end.
