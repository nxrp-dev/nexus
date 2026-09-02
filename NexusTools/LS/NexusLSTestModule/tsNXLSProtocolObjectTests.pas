unit tsNXLSProtocolObjectTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSProtocolObjectTests(ARegistry: TNXTestRegistry);

implementation

uses
  fpjson,
  jsonparser,
  obNXJSONRPCMessages,
  obNXLSAllRequests,
  obNXLSDispatcher,
  obNXTestContext,
  obNXTestSuite;

procedure TestInitializeDispatchReturnsCapabilities(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lResponse: string;
  lHandled: Boolean;
  lJSON: TJSONData;
  lObject: TJSONObject;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}');
  lJSON := nil;
  try
    lHandled := TNXLSDispatcher.DispatchMessage(lMessage, lResponse);
    AContext.AssertTrue(lHandled,
      'Initialize request should produce a JSON-RPC response.');
    lJSON := GetJSON(lResponse);
    AContext.AssertTrue(lJSON is TJSONObject,
      'Initialize response should be a JSON object.');
    lObject := TJSONObject(lJSON);
    AContext.AssertTrue(lObject.Find('error') = nil,
      'Initialize response should not contain an error object.');
    AContext.AssertTrue(lObject.Find('result') <> nil,
      'Initialize response should contain a result object.');
    AContext.AssertTrue(lObject.Objects['result'].Find('capabilities') <> nil,
      'Initialize result should contain server capabilities.');
  finally
    lJSON.Free;
    lMessage.Free;
  end;
end;

procedure RegisterNXLSProtocolObjectTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.ProtocolDispatch');
  lSuite.AddTest('InitializeDispatchReturnsCapabilities',
    @TestInitializeDispatchReturnsCapabilities);
end;

end.
