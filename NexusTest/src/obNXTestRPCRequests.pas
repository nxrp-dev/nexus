unit obNXTestRPCRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXTestGetCapabilitiesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXTestListTestsRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXTestRunAllRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXTestRunSuiteRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXTestRunTestRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  SysUtils,
  fpjson,
  obNXClassFactory,
  obNXTestModule,
  obNXTestRPCValues,
  tpNXTest;

function CurrentModule: TNXTestModule;
begin
  Result := TNXTestModule.Current;
end;

class function TNXTestGetCapabilitiesRequest.GetFactoryName: string;
begin
  Result := cNXTestMethodGetCapabilities;
end;

function TNXTestGetCapabilitiesRequest.Execute: TNXJSONValue;
var
  lCapabilities: TJSONObject;
  lMethods: TJSONArray;
begin
  lCapabilities := TJSONObject.Create;
  try
    lCapabilities.Add('apiVersion', cNXTestApiVersion);
    lCapabilities.Add('protocol', 'json-rpc-2.0');

    lMethods := TJSONArray.Create;
    lMethods.Add(cNXTestMethodGetCapabilities);
    lMethods.Add(cNXTestMethodListTests);
    lMethods.Add(cNXTestMethodRunTest);
    lMethods.Add(cNXTestMethodRunSuite);
    lMethods.Add(cNXTestMethodRunAll);
    lCapabilities.Add('methods', lMethods);

    Result := NXTestJSONValueFromObject(lCapabilities);
    lCapabilities := nil;
  finally
    lCapabilities.Free;
  end;
end;

class function TNXTestListTestsRequest.GetFactoryName: string;
begin
  Result := cNXTestMethodListTests;
end;

function TNXTestListTestsRequest.Execute: TNXJSONValue;
begin
  Result := NXTestJSONValueFromObject(CurrentModule.Registry.ToJsonObject);
end;

class function TNXTestRunAllRequest.GetFactoryName: string;
begin
  Result := cNXTestMethodRunAll;
end;

function TNXTestRunAllRequest.Execute: TNXJSONValue;
var
  lObject: TJSONObject;
begin
  lObject := TJSONObject.Create;
  try
    lObject.Add('results', CurrentModule.Runner.RunAll);
    Result := NXTestJSONValueFromObject(lObject);
    lObject := nil;
  finally
    lObject.Free;
  end;
end;

class function TNXTestRunSuiteRequest.GetFactoryName: string;
begin
  Result := cNXTestMethodRunSuite;
end;

class function TNXTestRunSuiteRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXTestRunSuiteParams;
end;

function TNXTestRunSuiteRequest.Execute: TNXJSONValue;
var
  lParams: TNXTestRunSuiteParams;
  lSuiteName: string;
  lObject: TJSONObject;
begin
  if not (params is TNXTestRunSuiteParams) then
    raise ENXTestRPC.CreateCode(TNXJSONRPC.InvalidParams, cNXTestErrorInvalidRequest, 'Missing suite parameter.');

  lParams := TNXTestRunSuiteParams(params);
  lSuiteName := lParams.suite.Value;
  if lSuiteName = '' then
    raise ENXTestRPC.CreateCode(TNXJSONRPC.InvalidParams, cNXTestErrorInvalidRequest, 'Missing suite parameter.');

  if not Assigned(CurrentModule.Registry.FindSuite(lSuiteName)) then
    raise ENXTestRPC.CreateCode(TNXJSONRPC.InvalidParams, cNXTestErrorUnknownTest, 'Unknown suite.');

  lObject := TJSONObject.Create;
  try
    lObject.Add('suite', lSuiteName);
    lObject.Add('results', CurrentModule.Runner.RunSuite(lSuiteName));
    Result := NXTestJSONValueFromObject(lObject);
    lObject := nil;
  finally
    lObject.Free;
  end;
end;

class function TNXTestRunTestRequest.GetFactoryName: string;
begin
  Result := cNXTestMethodRunTest;
end;

class function TNXTestRunTestRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXTestRunTestParams;
end;

function TNXTestRunTestRequest.Execute: TNXJSONValue;
var
  lParams: TNXTestRunTestParams;
  lTestId: string;
  lJsonResult: TJSONObject;
begin
  if not (params is TNXTestRunTestParams) then
    raise ENXTestRPC.CreateCode(TNXJSONRPC.InvalidParams, cNXTestErrorInvalidRequest, 'Missing test parameter.');

  lParams := TNXTestRunTestParams(params);
  lTestId := lParams.test.Value;
  if lTestId = '' then
    raise ENXTestRPC.CreateCode(TNXJSONRPC.InvalidParams, cNXTestErrorInvalidRequest, 'Missing test parameter.');

  lJsonResult := CurrentModule.Runner.RunTest(lTestId);
  if not Assigned(lJsonResult) then
    raise ENXTestRPC.CreateCode(TNXJSONRPC.InvalidParams, cNXTestErrorUnknownTest, 'Unknown test.');

  Result := NXTestJSONValueFromObject(lJsonResult);
end;

initialization
  TNXClassFactory.RegisterClass(TNXTestGetCapabilitiesRequest);
  TNXClassFactory.RegisterClass(TNXTestListTestsRequest);
  TNXClassFactory.RegisterClass(TNXTestRunAllRequest);
  TNXClassFactory.RegisterClass(TNXTestRunSuiteRequest);
  TNXClassFactory.RegisterClass(TNXTestRunTestRequest);

end.
