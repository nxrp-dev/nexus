unit tsNXTestJSONRPCHardeningTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXTestJSONRPCHardeningTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  obNXClassFactory,
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSDispatcher,
  obNXTestContext,
  obNXTestModule,
  obNXTestRPCRequests,
  obNXTestSuite,
  tpNXTest;

type
  TNXTestNamedParams = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
  published
    property name: TNXJSONString read Fname write Fname;
  end;

  TNXTestNestedChild = class(TNXJSONObject)
  private
    Fvalue: TNXJSONString;
  published
    property value: TNXJSONString read Fvalue write Fvalue;
  end;

  TNXTestNestedParent = class(TNXJSONObject)
  private
    Fchild: TNXTestNestedChild;
  published
    property child: TNXTestNestedChild read Fchild write Fchild;
  end;

  TNXTestObjectParamsRequest = class(TNXJSONRPCRequest)
  public
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXTestArrayParamsRequest = class(TNXJSONRPCRequest)
  public
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXTestNoParamsRequest = class(TNXJSONRPCRequest)
  public
    function Execute: TNXJSONValue; override;
  end;

  TNXTestResultValue = class(TNXJSONObject)
  end;

  TNXTestDefaultResultClassRequest = class(TNXJSONRPCRequest)
  public
    function Execute: TNXJSONValue; override;
    function PublicPrepareResult: TNXJSONValue;
  end;

  TNXTestDeclaredResultRequest = class(TNXJSONRPCRequest)
  public
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
    function PublicPrepareResult: TNXJSONValue;
  end;

  TNXTestNullAllowedResultRequest = class(TNXJSONRPCRequest)
  public
    class function AllowsNullResult: Boolean; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXTestWrongResultDispatchRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXTestNullResultDispatchRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  end;

class function TNXTestObjectParamsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXTestNamedParams;
end;

function TNXTestObjectParamsRequest.Execute: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXTestArrayParamsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXJSONArray;
end;

function TNXTestArrayParamsRequest.Execute: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

function TNXTestNoParamsRequest.Execute: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

function TNXTestDefaultResultClassRequest.Execute: TNXJSONValue;
begin
  Result := nil;
end;

function TNXTestDefaultResultClassRequest.PublicPrepareResult: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXTestDeclaredResultRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXTestResultValue;
end;

function TNXTestDeclaredResultRequest.Execute: TNXJSONValue;
begin
  Result := TNXTestResultValue.Create;
end;

function TNXTestDeclaredResultRequest.PublicPrepareResult: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXTestNullAllowedResultRequest.AllowsNullResult: Boolean;
begin
  Result := True;
end;

function TNXTestNullAllowedResultRequest.Execute: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXTestWrongResultDispatchRequest.GetFactoryName: string;
begin
  Result := 'test/resultWrong';
end;

class function TNXTestWrongResultDispatchRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXTestResultValue;
end;

function TNXTestWrongResultDispatchRequest.Execute: TNXJSONValue;
begin
  Result := TNXJSONArray.Create;
end;

class function TNXTestNullResultDispatchRequest.GetFactoryName: string;
begin
  Result := 'test/resultNull';
end;

function TNXTestNullResultDispatchRequest.Execute: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

function NXTestParse(const AJSON: string): TNXJSONRPCMessage;
begin
  Result := TNXJSONRPC.ParseMessage(AJSON);
end;

function NXTestRoundTrip(AMessage: TNXJSONRPCMessage): TNXJSONRPCMessage;
var
  lJSON: TJSONData;
begin
  lJSON := AMessage.ToJSONData;
  try
    Result := TNXJSONRPC.ParseMessage(lJSON.AsJSON);
  finally
    lJSON.Free;
  end;
end;

procedure NXTestAssertID(AContext: TNXTestContext; AMessage: TNXJSONRPCMessage;
  const AExpectedJSON: string);
var
  lJSON: TJSONData;
begin
  lJSON := AMessage.IDJSON;
  try
    AContext.AssertEquals(AExpectedJSON, lJSON.AsJSON, 'Unexpected JSON-RPC id.');
  finally
    lJSON.Free;
  end;
end;

procedure NXTestAssertObjectName(AContext: TNXTestContext;
  AValue: TNXJSONValue; const AExpectedName: string);
var
  lJSON: TJSONData;
begin
  AContext.AssertTrue(AValue <> nil, 'Expected JSON object value.');
  lJSON := AValue.ToJSONData;
  try
    AContext.AssertTrue(lJSON is TJSONObject, 'Expected JSON object.');
    AContext.AssertEquals(AExpectedName, TJSONObject(lJSON).Strings['name'],
      'JSON object name should round-trip.');
  finally
    lJSON.Free;
  end;
end;

procedure NXTestAssertArrayIntegers(AContext: TNXTestContext;
  AValue: TNXJSONValue; const AFirstValue, ASecondValue: Integer);
var
  lJSON: TJSONData;
begin
  AContext.AssertTrue(AValue <> nil, 'Expected JSON array value.');
  lJSON := AValue.ToJSONData;
  try
    AContext.AssertTrue(lJSON is TJSONArray, 'Expected JSON array.');
    AContext.AssertEquals(2, TJSONArray(lJSON).Count,
      'JSON array should round-trip item count.');
    AContext.AssertEquals(AFirstValue, TJSONArray(lJSON).Integers[0],
      'First JSON array value should round-trip.');
    AContext.AssertEquals(ASecondValue, TJSONArray(lJSON).Integers[1],
      'Second JSON array value should round-trip.');
  finally
    lJSON.Free;
  end;
end;

procedure NXTestAssertObjectBoolean(AContext: TNXTestContext;
  AValue: TNXJSONValue; const AName: string; const AExpectedValue: Boolean);
var
  lJSON: TJSONData;
begin
  AContext.AssertTrue(AValue <> nil, 'Expected JSON object value.');
  lJSON := AValue.ToJSONData;
  try
    AContext.AssertTrue(lJSON is TJSONObject, 'Expected JSON object.');
    AContext.AssertTrue(TJSONObject(lJSON).Booleans[AName] = AExpectedValue,
      'JSON object boolean should round-trip.');
  finally
    lJSON.Free;
  end;
end;

procedure NXTestAssertError(AContext: TNXTestContext; AValue: TNXJSONValue;
  const AExpectedCode: Integer; const AExpectedMessage: string);
var
  lJSON: TJSONData;
begin
  AContext.AssertTrue(AValue <> nil, 'Expected JSON-RPC error value.');
  lJSON := AValue.ToJSONData;
  try
    AContext.AssertTrue(lJSON is TJSONObject, 'Expected JSON-RPC error object.');
    AContext.AssertEquals(AExpectedCode, TJSONObject(lJSON).Integers['code'],
      'JSON-RPC error code should round-trip.');
    AContext.AssertEquals(AExpectedMessage, TJSONObject(lJSON).Strings['message'],
      'JSON-RPC error message should round-trip.');
  finally
    lJSON.Free;
  end;
end;

procedure NXTestAssertObjectValue(AContext: TNXTestContext; AValue: TNXJSONValue;
  const AMessage: string);
var
  lJSON: TJSONData;
begin
  AContext.AssertTrue(AValue <> nil, 'Expected JSON object value.');
  lJSON := AValue.ToJSONData;
  try
    AContext.AssertTrue(lJSON.JSONType = jtObject, AMessage);
  finally
    lJSON.Free;
  end;
end;

procedure TestRequestNoParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":1,"method":"nxtest/listTests"}');
  try
    AContext.AssertEquals(Integer(rpcRequest), Integer(lMessage.Kind),
      'Expected request.');
    AContext.AssertFalse(lMessage.HasParams, 'Request should not have params.');
  finally
    lMessage.Free;
  end;
end;

procedure TestRequestNullParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/object","params":null}',
    TNXTestObjectParamsRequest);
  try
    AContext.AssertTrue(lMessage.HasParams, 'Null params should be assigned.');
    AContext.AssertTrue(lMessage.params is TNXTestNamedParams,
      'Null object params should produce declared params object.');
  finally
    lMessage.Free;
  end;
end;

procedure TestRequestObjectParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lObject: TJSONData;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/object","params":{"name":"alpha"}}',
    TNXTestObjectParamsRequest);
  try
    AContext.AssertTrue(lMessage.params is TNXTestNamedParams,
      'Object params should use declared object params class.');
    lObject := lMessage.params.ToJSONData;
    try
      AContext.AssertEquals('alpha', TJSONObject(lObject).Strings['name'],
        'Object params should preserve field value.');
    finally
      lObject.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestRequestArrayParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lArray: TJSONData;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/array","params":[1,"two"]}',
    TNXTestArrayParamsRequest);
  try
    AContext.AssertTrue(lMessage.params is TNXJSONArray,
      'Array params should use declared array params class.');
    lArray := lMessage.params.ToJSONData;
    try
      AContext.AssertEquals(2, TJSONArray(lArray).Count,
        'Array params should preserve item count.');
    finally
      lArray.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestRequestStringID(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":"abc","method":"nxtest/listTests"}');
  try
    NXTestAssertID(AContext, lMessage, '"abc"');
  finally
    lMessage.Free;
  end;
end;

procedure TestRequestNumericID(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":42,"method":"nxtest/listTests"}');
  try
    NXTestAssertID(AContext, lMessage, '42');
  finally
    lMessage.Free;
  end;
end;

procedure TestRequestNullID(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":null,"method":"nxtest/listTests"}');
  try
    NXTestAssertID(AContext, lMessage, 'null');
  finally
    lMessage.Free;
  end;
end;

procedure TestRejectInvalidJSON(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage('{bad json').Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;

  AContext.AssertTrue(lRaised, 'Invalid JSON should raise JSON-RPC parse error.');
end;

procedure TestRejectMissingMethod(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage('{"jsonrpc":"2.0","id":1}').Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;

  AContext.AssertTrue(lRaised, 'Request without method should be rejected.');
end;

procedure TestRejectNonStringMethod(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage('{"jsonrpc":"2.0","id":1,"method":3}').Free;
  except
    on Exception do
      lRaised := True;
  end;

  AContext.AssertTrue(lRaised, 'Request with non-string method should be rejected.');
end;

procedure TestRejectMissingJSONRPCVersion(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage('{"id":1,"method":"nxtest/listTests"}').Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;

  AContext.AssertTrue(lRaised, 'Missing jsonrpc should be rejected.');
end;

procedure TestRejectWrongJSONRPCVersion(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage('{"jsonrpc":"1.0","id":1,"method":"nxtest/listTests"}').Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;

  AContext.AssertTrue(lRaised, 'Wrong jsonrpc version should be rejected.');
end;

procedure TestResponseSuccessObjectResult(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lJSON: TJSONData;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":1,"result":{"ok":true}}');
  try
    AContext.AssertEquals(Integer(rpcSuccessResponse), Integer(lMessage.Kind),
      'Expected success response.');
    lJSON := lMessage.result.ToJSONData;
    try
      AContext.AssertTrue(lJSON.JSONType = jtObject,
        'Object result should preserve object JSON.');
      AContext.AssertTrue(TJSONObject(lJSON).Booleans['ok'],
        'Object result should preserve field value.');
    finally
      lJSON.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestResponseSuccessArrayResult(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":1,"result":[1,2]}');
  try
    AContext.AssertEquals(Integer(rpcSuccessResponse), Integer(lMessage.Kind),
      'Expected success response.');
    AContext.AssertTrue(lMessage.result is TNXJSONArray,
      'Array result should parse as array value.');
  finally
    lMessage.Free;
  end;
end;

procedure TestResponseSuccessNullResult(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":1,"result":null}');
  try
    AContext.AssertEquals(Integer(rpcSuccessResponse), Integer(lMessage.Kind),
      'Expected success response.');
    AContext.AssertTrue(lMessage.result is TNXJSONNull,
      'Null result should parse as null value.');
  finally
    lMessage.Free;
  end;
end;

procedure TestResponseError(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse(
    '{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"boom"}}');
  try
    AContext.AssertEquals(Integer(rpcErrorResponse), Integer(lMessage.Kind),
      'Expected error response.');
  finally
    lMessage.Free;
  end;
end;

procedure TestRejectResponseWithResultAndError(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage(
      '{"jsonrpc":"2.0","id":1,"result":null,"error":{"code":-1,"message":"bad"}}').Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;

  AContext.AssertTrue(lRaised,
    'Response with both result and error should be rejected.');
end;

procedure TestRejectMalformedErrorObject(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage('{"jsonrpc":"2.0","id":1,"error":{}}').Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;

  AContext.AssertTrue(lRaised, 'Malformed error object should be rejected.');
end;

procedure TestRoundTripRequestObjectParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lRoundTrip: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/object","params":{"name":"alpha"}}',
    TNXTestObjectParamsRequest);
  try
    lRoundTrip := NXTestRoundTrip(lMessage);
    try
      AContext.AssertEquals(Integer(rpcRequest), Integer(lRoundTrip.Kind),
        'Round-tripped object params request should remain a request.');
      NXTestAssertID(AContext, lRoundTrip, '1');
      NXTestAssertObjectName(AContext, lRoundTrip.params, 'alpha');
    finally
      lRoundTrip.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestRoundTripRequestArrayParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lRoundTrip: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/array","params":[1,2]}',
    TNXTestArrayParamsRequest);
  try
    lRoundTrip := NXTestRoundTrip(lMessage);
    try
      AContext.AssertEquals(Integer(rpcRequest), Integer(lRoundTrip.Kind),
        'Round-tripped array params request should remain a request.');
      NXTestAssertArrayIntegers(AContext, lRoundTrip.params, 1, 2);
    finally
      lRoundTrip.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestRoundTripRequestNullParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lRoundTrip: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/object","params":null}',
    TNXTestObjectParamsRequest);
  try
    lRoundTrip := NXTestRoundTrip(lMessage);
    try
      AContext.AssertEquals(Integer(rpcRequest), Integer(lRoundTrip.Kind),
        'Round-tripped null params request should remain a request.');
      AContext.AssertTrue(lRoundTrip.HasParams,
        'Round-tripped null params should remain assigned.');
      NXTestAssertObjectValue(AContext, lRoundTrip.params,
        'Typed null params should round-trip as the declared params object.');
    finally
      lRoundTrip.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestRoundTripSuccessResponse(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lRoundTrip: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":1,"result":{"ok":true}}');
  try
    lRoundTrip := NXTestRoundTrip(lMessage);
    try
      AContext.AssertEquals(Integer(rpcSuccessResponse), Integer(lRoundTrip.Kind),
        'Round-tripped success response should remain success.');
      NXTestAssertObjectBoolean(AContext, lRoundTrip.result, 'ok', True);
    finally
      lRoundTrip.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestRoundTripErrorResponse(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lRoundTrip: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse(
    '{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"boom"}}');
  try
    lRoundTrip := NXTestRoundTrip(lMessage);
    try
      AContext.AssertEquals(Integer(rpcErrorResponse), Integer(lRoundTrip.Kind),
        'Round-tripped error response should remain error.');
      NXTestAssertError(AContext, lRoundTrip.error, -32603, 'boom');
    finally
      lRoundTrip.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestRoundTripStringID(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lRoundTrip: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":"abc","method":"nxtest/listTests"}');
  try
    lRoundTrip := NXTestRoundTrip(lMessage);
    try
      NXTestAssertID(AContext, lRoundTrip, '"abc"');
    finally
      lRoundTrip.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestRoundTripNumericID(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lRoundTrip: TNXJSONRPCMessage;
begin
  lMessage := NXTestParse('{"jsonrpc":"2.0","id":42,"method":"nxtest/listTests"}');
  try
    lRoundTrip := NXTestRoundTrip(lMessage);
    try
      NXTestAssertID(AContext, lRoundTrip, '42');
    finally
      lRoundTrip.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestNestedAssignedObjectSerializesParent(AContext: TNXTestContext);
var
  lParent: TNXTestNestedParent;
  lJSON: TJSONData;
  lObject: TJSONObject;
begin
  lParent := TNXTestNestedParent.Create;
  try
    lParent.child.value.Value := 'nested';
    lJSON := lParent.ToJSONData;
    try
      AContext.AssertTrue(lJSON is TJSONObject,
        'Nested JSON parent should serialize as an object.');
      lObject := TJSONObject(lJSON);
      AContext.AssertTrue(lObject.Find('child') is TJSONObject,
        'Assigned nested child should force parent child object serialization.');
      AContext.AssertEquals('nested',
        TJSONObject(lObject.Find('child')).Strings['value'],
        'Nested child value should serialize.');
    finally
      lJSON.Free;
    end;
  finally
    lParent.Free;
  end;
end;

procedure TestResultClassDefaultsToNil(AContext: TNXTestContext);
begin
  AContext.AssertTrue(TNXTestDefaultResultClassRequest.GetResultClass = nil,
    'JSON-RPC requests should not declare a result class by default.');
end;

procedure TestAllowsNullResultDefaultsToFalse(AContext: TNXTestContext);
begin
  AContext.AssertFalse(TNXTestDefaultResultClassRequest.AllowsNullResult,
    'JSON-RPC requests should not allow null results by default.');
end;

procedure TestPrepareResultRequiresResultClass(AContext: TNXTestContext);
var
  lRequest: TNXTestDefaultResultClassRequest;
  lRaised: Boolean;
begin
  lRaised := False;
  lRequest := TNXTestDefaultResultClassRequest.Create;
  try
    try
      lRequest.PublicPrepareResult.Free;
    except
      on ENXJSONRPC do
        lRaised := True;
    end;
  finally
    lRequest.Free;
  end;

  AContext.AssertTrue(lRaised,
    'PrepareResult should reject requests without a declared result class.');
end;

procedure TestValidateResultRejectsNilResult(AContext: TNXTestContext);
var
  lRequest: TNXTestDefaultResultClassRequest;
  lRaised: Boolean;
begin
  lRaised := False;
  lRequest := TNXTestDefaultResultClassRequest.Create;
  try
    try
      lRequest.ValidateResult(nil);
    except
      on ENXJSONRPC do
        lRaised := True;
    end;
  finally
    lRequest.Free;
  end;

  AContext.AssertTrue(lRaised,
    'ValidateResult should reject nil because nil is not a JSON-RPC result object.');
end;

procedure TestValidateResultRejectsDefaultNullResult(AContext: TNXTestContext);
var
  lRequest: TNXTestDefaultResultClassRequest;
  lResult: TNXJSONValue;
  lRaised: Boolean;
begin
  lRaised := False;
  lRequest := TNXTestDefaultResultClassRequest.Create;
  lResult := TNXJSONNull.Create;
  try
    try
      lRequest.ValidateResult(lResult);
    except
      on ENXJSONRPC do
        lRaised := True;
    end;
  finally
    lResult.Free;
    lRequest.Free;
  end;

  AContext.AssertTrue(lRaised,
    'ValidateResult should reject null unless the request allows null results.');
end;

procedure TestValidateResultAcceptsAllowedNullResult(AContext: TNXTestContext);
var
  lRequest: TNXTestNullAllowedResultRequest;
  lResult: TNXJSONValue;
begin
  lRequest := TNXTestNullAllowedResultRequest.Create;
  lResult := TNXJSONNull.Create;
  try
    lRequest.ValidateResult(lResult);
    AContext.AssertTrue(True,
      'ValidateResult should accept null when the request allows null results.');
  finally
    lResult.Free;
    lRequest.Free;
  end;
end;

procedure TestValidateResultRejectsWrongDeclaredResultClass(AContext: TNXTestContext);
var
  lRequest: TNXTestDeclaredResultRequest;
  lResult: TNXJSONValue;
  lRaised: Boolean;
begin
  lRaised := False;
  lRequest := TNXTestDeclaredResultRequest.Create;
  lResult := TNXJSONArray.Create;
  try
    try
      lRequest.ValidateResult(lResult);
    except
      on ENXJSONRPC do
        lRaised := True;
    end;
  finally
    lResult.Free;
    lRequest.Free;
  end;

  AContext.AssertTrue(lRaised,
    'ValidateResult should reject results outside the declared result class.');
end;

procedure TestValidateResultAcceptsDeclaredResultClass(AContext: TNXTestContext);
var
  lRequest: TNXTestDeclaredResultRequest;
  lResult: TNXJSONValue;
begin
  lRequest := TNXTestDeclaredResultRequest.Create;
  lResult := TNXTestResultValue.Create;
  try
    lRequest.ValidateResult(lResult);
    AContext.AssertTrue(True,
      'ValidateResult should accept a matching declared result class.');
  finally
    lResult.Free;
    lRequest.Free;
  end;
end;

procedure TestDispatcherValidatesResultAfterExecute(AContext: TNXTestContext);
var
  lDispatched: Boolean;
  lResponse: string;
  lMessage: TNXJSONRPCMessage;
  lErrorJSON: TJSONData;
begin
  if not TNXClassFactory.Registered(TNXTestWrongResultDispatchRequest.GetFactoryName) then
    TNXClassFactory.RegisterClass(TNXTestWrongResultDispatchRequest);

  lDispatched := TNXLSDispatcher.DispatchMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/resultWrong"}', lResponse);
  AContext.AssertTrue(lDispatched,
    'Dispatcher should return an error response for invalid request results.');

  lMessage := TNXJSONRPC.ParseMessage(lResponse);
  try
    AContext.AssertEquals(Integer(rpcErrorResponse), Integer(lMessage.Kind),
      'Dispatcher should convert result validation failure to an error response.');
    lErrorJSON := lMessage.error.ToJSONData;
    try
      AContext.AssertEquals(TNXJSONRPC.InternalError,
        TJSONObject(lErrorJSON).Integers['code'],
        'Invalid Execute result should be reported as an internal error.');
    finally
      lErrorJSON.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure TestDispatcherRejectsNullResultByDefault(AContext: TNXTestContext);
var
  lDispatched: Boolean;
  lResponse: string;
  lMessage: TNXJSONRPCMessage;
  lErrorJSON: TJSONData;
begin
  if not TNXClassFactory.Registered(TNXTestNullResultDispatchRequest.GetFactoryName) then
    TNXClassFactory.RegisterClass(TNXTestNullResultDispatchRequest);

  lDispatched := TNXLSDispatcher.DispatchMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/resultNull"}', lResponse);
  AContext.AssertTrue(lDispatched,
    'Dispatcher should return an error response for disallowed null results.');

  lMessage := TNXJSONRPC.ParseMessage(lResponse);
  try
    AContext.AssertEquals(Integer(rpcErrorResponse), Integer(lMessage.Kind),
      'Dispatcher should convert disallowed null result to an error response.');
    lErrorJSON := lMessage.error.ToJSONData;
    try
      AContext.AssertEquals(TNXJSONRPC.InternalError,
        TJSONObject(lErrorJSON).Integers['code'],
        'Disallowed null result should be reported as an internal error.');
    finally
      lErrorJSON.Free;
    end;
  finally
    lMessage.Free;
  end;
end;

procedure NXTestRegisterEmpty(ARegistry: TNXTestRegistry);
begin
end;

procedure TestBoundaryExactResultSize(AContext: TNXTestContext);
var
  lModule: TNXTestModule;
  lResultId: Integer;
  lResultSize: Integer;
  lBytesWritten: Integer;
  lBuffer: PAnsiChar;
  lStatus: Integer;
begin
  lModule := TNXTestModule.Create(@NXTestRegisterEmpty);
  try
    lStatus := lModule.ExecuteCommand(
      PAnsiChar('{"jsonrpc":"2.0","id":1,"method":"nxtest/listTests"}'),
      lResultId, lResultSize);
    AContext.AssertEquals(cNXTestSuccess, lStatus,
      'ExecuteCommand should succeed.');
    AContext.AssertTrue(lResultSize > 0, 'ExecuteCommand should report size.');

    GetMem(lBuffer, lResultSize);
    try
      lStatus := lModule.ReadResult(lResultId, lBuffer, lResultSize,
        lBytesWritten);
      AContext.AssertEquals(cNXTestSuccess, lStatus,
        'ReadResult should accept exact size.');
      AContext.AssertEquals(lResultSize, lBytesWritten,
        'ReadResult should write exact size including terminator.');
    finally
      FreeMem(lBuffer);
    end;
  finally
    lModule.Free;
  end;
end;

procedure TestBoundaryTooSmallBuffer(AContext: TNXTestContext);
var
  lModule: TNXTestModule;
  lResultId: Integer;
  lResultSize: Integer;
  lBytesWritten: Integer;
  lBuffer: PAnsiChar;
  lStatus: Integer;
begin
  lModule := TNXTestModule.Create(@NXTestRegisterEmpty);
  try
    lStatus := lModule.ExecuteCommand(
      PAnsiChar('{"jsonrpc":"2.0","id":1,"method":"nxtest/listTests"}'),
      lResultId, lResultSize);
    AContext.AssertEquals(cNXTestSuccess, lStatus,
      'ExecuteCommand should succeed.');

    GetMem(lBuffer, lResultSize - 1);
    try
      lStatus := lModule.ReadResult(lResultId, lBuffer, lResultSize - 1,
        lBytesWritten);
      AContext.AssertEquals(cNXTestErrorBufferTooSmall, lStatus,
        'ReadResult should reject small buffers.');
      AContext.AssertEquals(lResultSize, lBytesWritten,
        'Small-buffer read should report required size.');
    finally
      FreeMem(lBuffer);
    end;
  finally
    lModule.Free;
  end;
end;

procedure TestBoundarySuccessfulReadConsumesResult(AContext: TNXTestContext);
var
  lModule: TNXTestModule;
  lResultId: Integer;
  lResultSize: Integer;
  lBytesWritten: Integer;
  lBuffer: PAnsiChar;
  lStatus: Integer;
begin
  lModule := TNXTestModule.Create(@NXTestRegisterEmpty);
  try
    lStatus := lModule.ExecuteCommand(
      PAnsiChar('{"jsonrpc":"2.0","id":1,"method":"nxtest/listTests"}'),
      lResultId, lResultSize);
    AContext.AssertEquals(cNXTestSuccess, lStatus,
      'ExecuteCommand should succeed.');

    GetMem(lBuffer, lResultSize);
    try
      lStatus := lModule.ReadResult(lResultId, lBuffer, lResultSize,
        lBytesWritten);
      AContext.AssertEquals(cNXTestSuccess, lStatus,
        'First ReadResult should succeed.');
      lStatus := lModule.ReadResult(lResultId, lBuffer, lResultSize,
        lBytesWritten);
      AContext.AssertEquals(cNXTestErrorUnknownResult, lStatus,
        'Successful read should consume result.');
    finally
      FreeMem(lBuffer);
    end;
  finally
    lModule.Free;
  end;
end;

procedure RegisterNXTestJSONRPCHardeningTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusTest.Protocol.JSONRPC');
  lSuite.AddTest('RequestNoParams', @TestRequestNoParams);
  lSuite.AddTest('RequestNullParams', @TestRequestNullParams);
  lSuite.AddTest('RequestObjectParams', @TestRequestObjectParams);
  lSuite.AddTest('RequestArrayParams', @TestRequestArrayParams);
  lSuite.AddTest('RequestStringID', @TestRequestStringID);
  lSuite.AddTest('RequestNumericID', @TestRequestNumericID);
  lSuite.AddTest('RequestNullID', @TestRequestNullID);
  lSuite.AddTest('RejectInvalidJSON', @TestRejectInvalidJSON);
  lSuite.AddTest('RejectMissingMethod', @TestRejectMissingMethod);
  lSuite.AddTest('RejectNonStringMethod', @TestRejectNonStringMethod);
  lSuite.AddTest('RejectMissingJSONRPCVersion', @TestRejectMissingJSONRPCVersion);
  lSuite.AddTest('RejectWrongJSONRPCVersion', @TestRejectWrongJSONRPCVersion);
  lSuite.AddTest('ResponseSuccessObjectResult', @TestResponseSuccessObjectResult);
  lSuite.AddTest('ResponseSuccessArrayResult', @TestResponseSuccessArrayResult);
  lSuite.AddTest('ResponseSuccessNullResult', @TestResponseSuccessNullResult);
  lSuite.AddTest('ResponseError', @TestResponseError);
  lSuite.AddTest('RejectResponseWithResultAndError',
    @TestRejectResponseWithResultAndError);
  lSuite.AddTest('RejectMalformedErrorObject', @TestRejectMalformedErrorObject);
  lSuite.AddTest('RoundTripRequestObjectParams', @TestRoundTripRequestObjectParams);
  lSuite.AddTest('RoundTripRequestArrayParams', @TestRoundTripRequestArrayParams);
  lSuite.AddTest('RoundTripRequestNullParams', @TestRoundTripRequestNullParams);
  lSuite.AddTest('RoundTripSuccessResponse', @TestRoundTripSuccessResponse);
  lSuite.AddTest('RoundTripErrorResponse', @TestRoundTripErrorResponse);
  lSuite.AddTest('RoundTripStringID', @TestRoundTripStringID);
  lSuite.AddTest('RoundTripNumericID', @TestRoundTripNumericID);
  lSuite.AddTest('NestedAssignedObjectSerializesParent',
    @TestNestedAssignedObjectSerializesParent);
  lSuite.AddTest('ResultClassDefaultsToNil', @TestResultClassDefaultsToNil);
  lSuite.AddTest('AllowsNullResultDefaultsToFalse',
    @TestAllowsNullResultDefaultsToFalse);
  lSuite.AddTest('PrepareResultRequiresResultClass',
    @TestPrepareResultRequiresResultClass);
  lSuite.AddTest('ValidateResultRejectsNilResult',
    @TestValidateResultRejectsNilResult);
  lSuite.AddTest('ValidateResultRejectsDefaultNullResult',
    @TestValidateResultRejectsDefaultNullResult);
  lSuite.AddTest('ValidateResultAcceptsAllowedNullResult',
    @TestValidateResultAcceptsAllowedNullResult);
  lSuite.AddTest('ValidateResultRejectsWrongDeclaredResultClass',
    @TestValidateResultRejectsWrongDeclaredResultClass);
  lSuite.AddTest('ValidateResultAcceptsDeclaredResultClass',
    @TestValidateResultAcceptsDeclaredResultClass);
  lSuite.AddTest('DispatcherValidatesResultAfterExecute',
    @TestDispatcherValidatesResultAfterExecute);
  lSuite.AddTest('DispatcherRejectsNullResultByDefault',
    @TestDispatcherRejectsNullResultByDefault);
  lSuite.AddTest('BoundaryExactResultSize', @TestBoundaryExactResultSize);
  lSuite.AddTest('BoundaryTooSmallBuffer', @TestBoundaryTooSmallBuffer);
  lSuite.AddTest('BoundarySuccessfulReadConsumesResult',
    @TestBoundarySuccessfulReadConsumesResult);
end;

end.
