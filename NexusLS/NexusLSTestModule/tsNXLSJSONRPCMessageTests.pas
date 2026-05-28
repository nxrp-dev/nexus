unit tsNXLSJSONRPCMessageTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSJSONRPCMessageTests(ARegistry: TNXTestRegistry);

implementation

uses
  fpjson,
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  obNXTestContext,
  obNXTestSuite;

type
  TNXTestVoidParamsRequest = class(TNXJSONRPCRequest)
  public
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

class function TNXTestVoidParamsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSInitializedParams;
end;

function TNXTestVoidParamsRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSNullResult.CreateValue;
end;

procedure TestParseRequestWithOmittedParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/void"}',
    TNXTestVoidParamsRequest);
  try
    AContext.AssertTrue(lMessage is TNXTestVoidParamsRequest,
      'Parser should create the requested request class.');
    AContext.AssertFalse(lMessage.HasParams,
      'Omitted params should be treated as absent.');
  finally
    lMessage.Free;
  end;
end;

procedure TestParseRequestWithObjectParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/void","params":{}}',
    TNXTestVoidParamsRequest);
  try
    AContext.AssertTrue(lMessage.HasParams,
      'Object params should be assigned.');
    AContext.AssertTrue(lMessage.params is TNXLSInitializedParams,
      'Object params should be converted to the declared params type.');
  finally
    lMessage.Free;
  end;
end;

procedure TestParseRequestWithNullParams(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"test/void","params":null}',
    TNXTestVoidParamsRequest);
  try
    AContext.AssertTrue(lMessage.HasParams,
      'Null params should be accepted for object-shaped void params.');
    AContext.AssertTrue(lMessage.params is TNXLSInitializedParams,
      'Null params should still produce the declared params type.');
  finally
    lMessage.Free;
  end;
end;

procedure TestRejectParamsWhenRequestDoesNotAcceptParams(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage(
      '{"jsonrpc":"2.0","id":1,"method":"test/noParams","params":{}}',
      TNXJSONRPCRequest).Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;

  AContext.AssertTrue(lRaised,
    'Requests without a params class should reject supplied params.');
end;

procedure RegisterNXLSJSONRPCMessageTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.Legacy.JSONRPC');
  lSuite.AddTest('ParseRequestWithOmittedParams',
    @TestParseRequestWithOmittedParams);
  lSuite.AddTest('ParseRequestWithObjectParams', @TestParseRequestWithObjectParams);
  lSuite.AddTest('ParseRequestWithNullParams', @TestParseRequestWithNullParams);
  lSuite.AddTest('RejectParamsWhenRequestDoesNotAcceptParams',
    @TestRejectParamsWhenRequestDoesNotAcceptParams);
end;

end.
