unit tsNXLSProtocolObjectTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSProtocolObjectTests(ARegistry: TNXTestRegistry);

implementation

uses
  SysUtils,
  fpjson,
  jsonparser,
  obNXLSTransport,
  obNXJSONValues,
  obNXJSONRPCMessages,
  obNXLSDispatcher,
  obNXLSOutboundDispatcher,
  obNXLSProtocolBase,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  obNXLSWorkspaceEditRequests,
  obNXTestContext,
  obNXTestSuite;

type
  TNXLSProtocolTestTransport = class(TNXLSTransport)
  private
    FOpen: Boolean;
    FOutput: string;
  protected
    function ReadLine(out ALine: string): Boolean; override;
    function ReadContent(const ALength: Integer; out AContent: string): Boolean; override;
    procedure WriteContent(const AContent: string); override;
  public
    procedure Open; override;
    procedure Close; override;
    function IsOpen: Boolean; override;
    function LastPayload: string;
  end;

  TNXLSTestApplyEditRequest = class(TNXLSWorkspaceApplyEditRequest)
  public
    class var Processed: Boolean;
    class var Applied: Boolean;
    class var URI: string;
    procedure ProcessOutboundResult; override;
  end;

function TNXLSProtocolTestTransport.ReadLine(out ALine: string): Boolean;
begin
  ALine := '';
  Result := False;
end;

function TNXLSProtocolTestTransport.ReadContent(const ALength: Integer;
  out AContent: string): Boolean;
begin
  AContent := '';
  Result := False;
end;

procedure TNXLSProtocolTestTransport.WriteContent(const AContent: string);
begin
  FOutput := FOutput + AContent;
end;

procedure TNXLSProtocolTestTransport.Open;
begin
  FOpen := True;
end;

procedure TNXLSProtocolTestTransport.Close;
begin
  FOpen := False;
end;

function TNXLSProtocolTestTransport.IsOpen: Boolean;
begin
  Result := FOpen;
end;

function TNXLSProtocolTestTransport.LastPayload: string;
var
  lPos: Integer;
begin
  Result := '';
  lPos := Pos(#13#10#13#10, FOutput);
  if lPos > 0 then
    Result := Copy(FOutput, lPos + 4, MaxInt);
end;

procedure TNXLSTestApplyEditRequest.ProcessOutboundResult;
begin
  Processed := True;
  Applied := result.applied.Value;
  URI := TNXLSTextDocumentEdit(params.edit.documentChanges[0]).textDocument.uri.Value;
end;

procedure NXLSSetPosition(APosition: TNXLSPosition; const ALine,
  ACharacter: Integer);
begin
  APosition.line.Value := ALine;
  APosition.character.Value := ACharacter;
end;

procedure NXLSSetRange(ARange: TNXLSRange; const AStartLine,
  AStartCharacter, AEndLine, AEndCharacter: Integer);
begin
  NXLSSetPosition(ARange.start, AStartLine, AStartCharacter);
  NXLSSetPosition(ARange.&end, AEndLine, AEndCharacter);
end;

procedure NXLSAssertRange(AContext: TNXTestContext; const AMessage: string;
  ARange: TNXLSRange; const AStartLine, AStartCharacter, AEndLine,
  AEndCharacter: Integer);
begin
  AContext.AssertTrue(Assigned(ARange), AMessage + ': range should exist.');
  AContext.AssertTrue(Assigned(ARange.start), AMessage + ': start should exist.');
  AContext.AssertTrue(Assigned(ARange.&end), AMessage + ': end should exist.');
  AContext.AssertEquals(AStartLine, ARange.start.line.AsInteger,
    AMessage + ': start line.');
  AContext.AssertEquals(AStartCharacter, ARange.start.character.AsInteger,
    AMessage + ': start character.');
  AContext.AssertEquals(AEndLine, ARange.&end.line.AsInteger,
    AMessage + ': end line.');
  AContext.AssertEquals(AEndCharacter, ARange.&end.character.AsInteger,
    AMessage + ': end character.');
end;

procedure TestRangeAutoCreatesPositions(AContext: TNXTestContext);
var
  lRange: TNXLSRange;
begin
  lRange := TNXLSRange.Create;
  try
    AContext.AssertTrue(Assigned(lRange.start),
      'Range should auto-create the start position.');
    AContext.AssertTrue(Assigned(lRange.&end),
      'Range should auto-create the end position.');
    AContext.AssertTrue(Assigned(lRange.start.line),
      'Range start should auto-create line.');
    AContext.AssertTrue(Assigned(lRange.start.character),
      'Range start should auto-create character.');
    AContext.AssertTrue(Assigned(lRange.&end.line),
      'Range end should auto-create line.');
    AContext.AssertTrue(Assigned(lRange.&end.character),
      'Range end should auto-create character.');
  finally
    lRange.Free;
  end;
end;

procedure TestRangeAssign(AContext: TNXTestContext);
var
  lSource: TNXLSRange;
  lTarget: TNXLSRange;
begin
  lSource := TNXLSRange.Create;
  lTarget := TNXLSRange.Create;
  try
    NXLSSetRange(lSource, 12, 13, 14, 15);
    lTarget.Assign(lSource);
    NXLSAssertRange(AContext, 'Assign', lTarget, 12, 13, 14, 15);
  finally
    lTarget.Free;
    lSource.Free;
  end;
end;

procedure TestRangeFromJSONData(AContext: TNXTestContext);
var
  lRange: TNXLSRange;
  lJSON: TJSONData;
begin
  lRange := TNXLSRange.Create;
  lJSON := GetJSON('{"start":{"line":10,"character":11},"end":{"line":12,"character":13}}');
  try
    lRange.FromJSONData(lJSON);
    NXLSAssertRange(AContext, 'FromJSONData', lRange, 10, 11, 12, 13);
  finally
    lJSON.Free;
    lRange.Free;
  end;
end;

procedure TestRangeToJSONData(AContext: TNXTestContext);
var
  lRange: TNXLSRange;
  lJSON: TJSONData;
  lObject: TJSONObject;
begin
  lRange := TNXLSRange.Create;
  try
    NXLSSetRange(lRange, 10, 11, 12, 13);

    lJSON := lRange.ToJSONData;
    try
      AContext.AssertTrue(lJSON is TJSONObject,
        'Range should serialize to a JSON object.');
      lObject := TJSONObject(lJSON);
      AContext.AssertEquals(10, lObject.Objects['start'].Integers['line'],
        'Serialized start line.');
      AContext.AssertEquals(11, lObject.Objects['start'].Integers['character'],
        'Serialized start character.');
      AContext.AssertEquals(12, lObject.Objects['end'].Integers['line'],
        'Serialized end line.');
      AContext.AssertEquals(13, lObject.Objects['end'].Integers['character'],
        'Serialized end character.');
    finally
      lJSON.Free;
    end;
  finally
    lRange.Free;
  end;
end;

procedure TestInitializeParamsIgnoreUnknownProperties(AContext: TNXTestContext);
var
  lParams: TNXLSInitializeParams;
  lJSON: TJSONData;
begin
  lParams := TNXLSInitializeParams.Create;
  lJSON := GetJSON('{"processId":123,"symbolDatabase":"/tmp/symbols.db","nonExistentProperty":"test"}');
  try
    lParams.FromJSONData(lJSON);
    AContext.AssertEquals(123, lParams.processId.AsInteger,
      'Known properties should still deserialize when unknown properties are present.');
  finally
    lJSON.Free;
    lParams.Free;
  end;
end;

procedure TestOutboundApplyEditSerializesTypedRequest(AContext: TNXTestContext);
var
  lDispatcher: TNXLSOutboundDispatcher;
  lTransport: TNXLSProtocolTestTransport;
  lRequest: TNXLSWorkspaceApplyEditRequest;
  lRequestToSend: TNXLSWorkspaceApplyEditRequest;
  lEdit: TNXLSTextDocumentEdit;
  lTextEdit: TNXLSTextEdit;
  lJSON: TJSONData;
  lMessage: TJSONObject;
  lDocumentChanges: TJSONArray;
  lTextEdits: TJSONArray;
begin
  lDispatcher := TNXLSOutboundDispatcher.Create;
  lTransport := TNXLSProtocolTestTransport.Create;
  lRequest := TNXLSWorkspaceApplyEditRequest.Create;
  try
    lTransport.Open;
    lDispatcher.Transport := lTransport;

    lRequest.params.edit.documentChanges.Assigned := True;

    lEdit := TNXLSTextDocumentEdit(lRequest.params.edit.documentChanges.AddObject(TNXLSTextDocumentEdit));
    lEdit.textDocument.uri.Value := 'file:///tmp/unit.pas';
    lEdit.textDocument.version.SetNull;

    lTextEdit := TNXLSTextEdit(lEdit.edits.AddObject(TNXLSTextEdit));
    NXLSSetRange(lTextEdit.range, 1, 2, 3, 4);
    lTextEdit.newText.Value := 'replacement';

    lRequestToSend := lRequest;
    lRequest := nil;
    AContext.AssertEquals(1, lDispatcher.SendRequest(lRequestToSend),
      'First outbound request should receive ID 1.');

    lJSON := GetJSON(lTransport.LastPayload);
    try
      AContext.AssertTrue(lJSON is TJSONObject,
        'Outbound payload should be a JSON object.');
      lMessage := TJSONObject(lJSON);
      AContext.AssertEquals(TNXJSONRPC.Version, lMessage.Strings['jsonrpc'],
        'Outbound request should include JSON-RPC version.');
      AContext.AssertEquals(1, lMessage.Integers['id'],
        'Outbound request should include generated ID.');
      AContext.AssertEquals('workspace/applyEdit', lMessage.Strings['method'],
        'Outbound request should use request factory name.');

      lDocumentChanges := lMessage.Objects['params'].Objects['edit'].Arrays['documentChanges'];
      AContext.AssertEquals('file:///tmp/unit.pas',
        lDocumentChanges.Objects[0].Objects['textDocument'].Strings['uri'],
        'Text document edit should include document URI.');
      AContext.AssertTrue(lDocumentChanges.Objects[0].Objects['textDocument'].Find('version').JSONType = jtNull,
        'Text document edit should include a null optional version.');

      lTextEdits := lDocumentChanges.Objects[0].Arrays['edits'];
      AContext.AssertEquals('replacement', lTextEdits.Objects[0].Strings['newText'],
        'Text edit should include replacement text.');
      AContext.AssertEquals(1, lTextEdits.Objects[0].Objects['range'].Objects['start'].Integers['line'],
        'Text edit should include typed start position.');
    finally
      lJSON.Free;
    end;
  finally
    lRequest.Free;
    lTransport.Free;
    lDispatcher.Free;
  end;
end;

procedure TestOutboundApplyEditProcessesResponseOnOriginalRequest(AContext: TNXTestContext);
var
  lDispatcher: TNXLSOutboundDispatcher;
  lTransport: TNXLSProtocolTestTransport;
  lRequest: TNXLSTestApplyEditRequest;
  lRequestToSend: TNXLSTestApplyEditRequest;
  lEdit: TNXLSTextDocumentEdit;
  lResponse: TNXJSONRPCMessage;
begin
  lDispatcher := TNXLSOutboundDispatcher.Create;
  lTransport := TNXLSProtocolTestTransport.Create;
  lRequest := TNXLSTestApplyEditRequest.Create;
  lResponse := nil;
  try
    TNXLSTestApplyEditRequest.Processed := False;
    TNXLSTestApplyEditRequest.Applied := False;
    TNXLSTestApplyEditRequest.URI := '';

    lTransport.Open;
    lDispatcher.Transport := lTransport;

    lRequest.params.edit.documentChanges.Assigned := True;
    lEdit := TNXLSTextDocumentEdit(lRequest.params.edit.documentChanges.AddObject(TNXLSTextDocumentEdit));
    lEdit.textDocument.uri.Value := 'file:///tmp/original.pas';

    lRequestToSend := lRequest;
    lRequest := nil;
    AContext.AssertEquals(1, lDispatcher.SendRequest(lRequestToSend),
      'Outbound request should receive ID 1.');

    lResponse := TNXJSONRPC.ParseMessage(
      '{"jsonrpc":"2.0","id":1,"result":{"applied":true}}');
    AContext.AssertTrue(lDispatcher.ReceiveResponse(lResponse),
      'Dispatcher should consume the matching response.');
    AContext.AssertTrue(TNXLSTestApplyEditRequest.Processed,
      'Original request should process the outbound result.');
    AContext.AssertTrue(TNXLSTestApplyEditRequest.Applied,
      'Original request should receive the typed result.');
    AContext.AssertEquals('file:///tmp/original.pas',
      TNXLSTestApplyEditRequest.URI,
      'Original request should keep its local request context.');
  finally
    lResponse.Free;
    lRequest.Free;
    lTransport.Free;
    lDispatcher.Free;
  end;
end;

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
  lSuite := ARegistry.AddSuite('NexusLS.ProtocolObjects');
  lSuite.AddTest('RangeAutoCreatesPositions', @TestRangeAutoCreatesPositions);
  lSuite.AddTest('RangeAssign', @TestRangeAssign);
  lSuite.AddTest('RangeFromJSONData', @TestRangeFromJSONData);
  lSuite.AddTest('RangeToJSONData', @TestRangeToJSONData);
  lSuite.AddTest('InitializeParamsIgnoreUnknownProperties',
    @TestInitializeParamsIgnoreUnknownProperties);
  lSuite.AddTest('OutboundApplyEditSerializesTypedRequest',
    @TestOutboundApplyEditSerializesTypedRequest);
  lSuite.AddTest('OutboundApplyEditProcessesResponseOnOriginalRequest',
    @TestOutboundApplyEditProcessesResponseOnOriginalRequest);
  lSuite.AddTest('InitializeDispatchReturnsCapabilities',
    @TestInitializeDispatchReturnsCapabilities);
end;

end.
