unit tsNXJSONRPCEnvelopeTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXJSONRPCEnvelopeTests(ARegistry: TNXTestRegistry);

implementation

uses
  SysUtils,
  fpjson,
  obNXJSONRPCMessages,
  obNXTestContext,
  obNXTestSuite;

procedure TestStandardRejectsMissingVersion(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage('{"id":1,"method":"test/request"}').Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;
  AContext.AssertTrue(lRaised,
    'Standard policy must reject a missing jsonrpc member.');
end;

procedure TestHeaderlessAcceptsMissingVersion(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"id":1,"method":"test/request"}', jepHeaderless);
  try
    AContext.AssertEquals(Integer(rpcRequest), Integer(lMessage.Kind),
      'Headerless policy should accept a request without jsonrpc.');
  finally
    lMessage.Free;
  end;
end;

procedure TestHeaderlessRejectsWrongVersion(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage(
      '{"jsonrpc":"1.0","id":1,"method":"test/request"}',
      jepHeaderless).Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;
  AContext.AssertTrue(lRaised,
    'Headerless policy must reject an invalid present version.');
end;

procedure TestHeaderlessResponsesOmitVersion(AContext: TNXTestContext);
var
  lResponse: TJSONObject;
begin
  lResponse := TNXJSONRPC.CreateSuccessResponse(nil, nil, jepHeaderless);
  try
    AContext.AssertTrue(lResponse.Find('jsonrpc') = nil,
      'Headerless success response should omit jsonrpc.');
    AContext.AssertTrue(lResponse.Find('result') <> nil,
      'Headerless success response should contain result.');
  finally
    lResponse.Free;
  end;

  lResponse := TNXJSONRPC.CreateErrorResponse(nil,
    TNXJSONRPC.MethodNotFound, 'unknown', nil, jepHeaderless);
  try
    AContext.AssertTrue(lResponse.Find('jsonrpc') = nil,
      'Headerless error response should omit jsonrpc.');
    AContext.AssertTrue(lResponse.Find('error') <> nil,
      'Headerless error response should contain error.');
  finally
    lResponse.Free;
  end;
end;

procedure RegisterNXJSONRPCEnvelopeTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusJSONRPC.Envelope');
  lSuite.AddTest('StandardRejectsMissingVersion',
    @TestStandardRejectsMissingVersion);
  lSuite.AddTest('HeaderlessAcceptsMissingVersion',
    @TestHeaderlessAcceptsMissingVersion);
  lSuite.AddTest('HeaderlessRejectsWrongVersion',
    @TestHeaderlessRejectsWrongVersion);
  lSuite.AddTest('HeaderlessResponsesOmitVersion',
    @TestHeaderlessResponsesOmitVersion);
end;

end.
