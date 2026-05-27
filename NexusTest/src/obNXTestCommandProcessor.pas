unit obNXTestCommandProcessor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, obNXTestRegistry, obNXTestRunner,
  tpNXTest;

type
  TNXTestCommandProcessor = class
  private
    FRegistry: TNXTestRegistry;
    FRunner: TNXTestRunner;
    function CloneId(AId: TJSONData): TJSONData;
    function CreateResponse(AId: TJSONData; AResult: TJSONData): TJSONObject;
    function CreateError(AId: TJSONData; ACode: Integer; const AMessage: string; ANXTestCode: Integer = 0): TJSONObject;
    function GetStringParam(AParams: TJSONData; const AName: string): string;
    function IsStringValue(AData: TJSONData): Boolean;
    function IsObjectValue(AData: TJSONData): Boolean;
    function ValidateRequest(ARequest: TJSONObject; out AError: TJSONObject): Boolean;
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

function TNXTestCommandProcessor.CreateError(AId: TJSONData; ACode: Integer; const AMessage: string; ANXTestCode: Integer): TJSONObject;
var
  lError: TJSONObject;
  lData: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('jsonrpc', '2.0');
  Result.Add('id', CloneId(AId));

  lError := TJSONObject.Create;
  lError.Add('code', ACode);
  lError.Add('message', AMessage);

  if ANXTestCode <> 0 then
  begin
    lData := TJSONObject.Create;
    lData.Add('nxtestCode', ANXTestCode);
    lError.Add('data', lData);
  end;

  Result.Add('error', lError);
end;

function TNXTestCommandProcessor.IsStringValue(AData: TJSONData): Boolean;
begin
  Result := Assigned(AData) and (AData.JSONType = jtString);
end;

function TNXTestCommandProcessor.IsObjectValue(AData: TJSONData): Boolean;
begin
  Result := Assigned(AData) and (AData.JSONType = jtObject);
end;

function TNXTestCommandProcessor.GetStringParam(AParams: TJSONData; const AName: string): string;
var
  lData: TJSONData;
begin
  Result := '';
  if not IsObjectValue(AParams) then
    Exit;

  lData := TJSONObject(AParams).Find(AName);
  if IsStringValue(lData) then
    Result := lData.AsString;
end;

function TNXTestCommandProcessor.ValidateRequest(ARequest: TJSONObject; out AError: TJSONObject): Boolean;
var
  lJsonRpc: TJSONData;
  lMethod: TJSONData;
  lParams: TJSONData;
begin
  Result := False;
  AError := nil;

  lJsonRpc := ARequest.Find('jsonrpc');
  if (not IsStringValue(lJsonRpc)) or (lJsonRpc.AsString <> '2.0') then
  begin
    AError := CreateError(ARequest.Find('id'), cJsonRpcInvalidRequest, 'Invalid or missing jsonrpc value.', cNXTestErrorInvalidRequest);
    Exit;
  end;

  lMethod := ARequest.Find('method');
  if not IsStringValue(lMethod) then
  begin
    AError := CreateError(ARequest.Find('id'), cJsonRpcInvalidRequest, 'Invalid or missing method value.', cNXTestErrorInvalidRequest);
    Exit;
  end;

  lParams := ARequest.Find('params');
  if Assigned(lParams) and (lParams.JSONType <> jtObject) then
  begin
    AError := CreateError(ARequest.Find('id'), cJsonRpcInvalidParams, 'Params must be a JSON object.', cNXTestErrorInvalidRequest);
    Exit;
  end;

  Result := True;
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
    Exit(CreateError(ARequest.Find('id'), cJsonRpcInvalidParams, 'Missing suite parameter.', cNXTestErrorInvalidRequest));

  if not Assigned(FRegistry.FindSuite(lSuiteName)) then
    Exit(CreateError(ARequest.Find('id'), cJsonRpcInvalidParams, 'Unknown suite.', cNXTestErrorUnknownTest));

  lObject := TJSONObject.Create;
  lObject.Add('suite', lSuiteName);
  lObject.Add('results', FRunner.RunSuite(lSuiteName));
  Result := CreateResponse(ARequest.Find('id'), lObject);
end;

function TNXTestCommandProcessor.HandleRunTest(ARequest: TJSONObject): TJSONObject;
var
  lTestId: string;
  lJsonResult: TJSONObject;
begin
  lTestId := GetStringParam(ARequest.Find('params'), 'test');
  if lTestId = '' then
    Exit(CreateError(ARequest.Find('id'), cJsonRpcInvalidParams, 'Missing test parameter.', cNXTestErrorInvalidRequest));

  lJsonResult := FRunner.RunTest(lTestId);
  if not Assigned(lJsonResult) then
    Exit(CreateError(ARequest.Find('id'), cJsonRpcInvalidParams, 'Unknown test.', cNXTestErrorUnknownTest));

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
    Result := CreateError(ARequest.Find('id'), cJsonRpcMethodNotFound, 'Method not found.', cNXTestErrorUnknownCommand);
end;

function TNXTestCommandProcessor.ExecuteCommand(const ARequest: string): string;
var
  lData: TJSONData;
  lResponse: TJSONObject;
begin
  lData := nil;
  lResponse := nil;
  try
    try
      lData := GetJSON(ARequest);
    except
      on E: Exception do
        lResponse := CreateError(nil, cJsonRpcParseError, 'Parse error.', cNXTestErrorInvalidRequest);
    end;

    if not Assigned(lResponse) then
    begin
      try
        if not (lData is TJSONObject) then
          lResponse := CreateError(nil, cJsonRpcInvalidRequest, 'Request must be a JSON object.', cNXTestErrorInvalidRequest)
        else if ValidateRequest(TJSONObject(lData), lResponse) then
          lResponse := HandleCommand(TJSONObject(lData));
      except
        on E: Exception do
        begin
          FreeAndNil(lResponse);
          lResponse := CreateError(nil, cJsonRpcInternalError, E.Message, cNXTestErrorInternal);
        end;
      end;
    end;

    Result := lResponse.AsJSON;
  finally
    lResponse.Free;
    lData.Free;
  end;
end;

end.
