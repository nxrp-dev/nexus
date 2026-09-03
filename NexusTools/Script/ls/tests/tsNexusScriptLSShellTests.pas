unit tsNexusScriptLSShellTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNexusScriptLSShellTests(ARegistry: TNXTestRegistry);

implementation

uses
  SysUtils,
  fpjson,
  jsonparser,
  obNXJSONRPCMessages,
  obNXLSDispatcher,
  obNexusScriptLSDocument,
  obNexusScriptLSModel,
  obNexusScriptLSAllRequests,
  obNXTestContext,
  obNXTestSuite;

function DispatchJSON(const AJSON: string): string;
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(AJSON);
  try
    TNXLSDispatcher.DispatchMessage(lMessage, Result);
  finally
    lMessage.Free;
  end;
end;

procedure TestModelDocumentLifecycle(AContext: TNXTestContext);
var
  lDocument: TNexusScriptLSDocument;
  lModel: TNexusScriptLSModel;
begin
  lModel := TNexusScriptLSModel.Create;
  try
    AContext.AssertFalse(lModel.InitializeReceived,
      'A fresh model should not have received initialize.');
    AContext.AssertFalse(lModel.Initialized,
      'A fresh model should not be initialized.');
    AContext.AssertFalse(lModel.ShutdownRequested,
      'A fresh model should not have received shutdown.');
    AContext.AssertFalse(lModel.ExitRequested,
      'A fresh model should not have received exit.');
    AContext.AssertEquals(0, lModel.DocumentCount,
      'A fresh model should have no open documents.');

    lModel.OpenDocument('file:///C:/work/example.nxscript', 'nexusscript', 1,
      'Definition First {}');
    AContext.AssertEquals(1, lModel.DocumentCount,
      'Opening a document should store it once.');
    lDocument := lModel.FindDocument('file:///C:/work/example.nxscript');
    AContext.AssertTrue(lDocument <> nil,
      'The opened document should be found by URI.');
    AContext.AssertEquals('file:///C:/work/example.nxscript', lDocument.URI,
      'Open should preserve the document URI.');
    AContext.AssertEquals('nexusscript', lDocument.LanguageID,
      'Open should preserve the language ID.');
    AContext.AssertEquals(1, lDocument.Version,
      'Open should preserve the document version.');
    AContext.AssertEquals('Definition First {}', lDocument.Text,
      'Open should preserve the full document text.');

    lModel.ChangeDocument('file:///C:/work/example.nxscript', 2,
      'Definition Second {}');
    AContext.AssertEquals(2, lDocument.Version,
      'A full change should replace the document version.');
    AContext.AssertEquals('Definition Second {}', lDocument.Text,
      'A full change should replace the complete document text.');

    lModel.SaveDocument('file:///C:/work/example.nxscript');
    AContext.AssertEquals(2, lDocument.Version,
      'Save should not change the stored document version.');
    AContext.AssertEquals('Definition Second {}', lDocument.Text,
      'Save should not change the stored document text.');

    lModel.CloseDocument('file:///C:/work/example.nxscript');
    AContext.AssertEquals(0, lModel.DocumentCount,
      'Close should remove the document.');
    AContext.AssertTrue(
      lModel.FindDocument('file:///C:/work/example.nxscript') = nil,
      'A closed document should no longer be found.');
  finally
    lModel.Free;
  end;
end;

procedure TestModelRejectsInvalidDocumentLifecycle(AContext: TNXTestContext);
var
  lModel: TNexusScriptLSModel;
  lRaised: Boolean;
begin
  lModel := TNexusScriptLSModel.Create;
  try
    lModel.OpenDocument('file:///C:/work/example.nxscript', 'nexusscript', 1,
      'Definition First {}');

    lRaised := False;
    try
      lModel.OpenDocument('file:///C:/work/example.nxscript', 'nexusscript', 1,
        'Definition Duplicate {}');
    except
      on E: Exception do
        lRaised := Pos('already open', E.Message) > 0;
    end;
    AContext.AssertTrue(lRaised,
      'Opening the same URI twice should fail.');

    lRaised := False;
    try
      lModel.ChangeDocument('file:///C:/work/missing.nxscript', 2, 'missing');
    except
      on E: Exception do
        lRaised := Pos('not open', E.Message) > 0;
    end;
    AContext.AssertTrue(lRaised,
      'Changing an unknown URI should fail.');

    lRaised := False;
    try
      lModel.SaveDocument('file:///C:/work/missing.nxscript');
    except
      on E: Exception do
        lRaised := Pos('not open', E.Message) > 0;
    end;
    AContext.AssertTrue(lRaised,
      'Saving an unknown URI should fail.');

    lRaised := False;
    try
      lModel.CloseDocument('file:///C:/work/missing.nxscript');
    except
      on E: Exception do
        lRaised := Pos('not open', E.Message) > 0;
    end;
    AContext.AssertTrue(lRaised,
      'Closing an unknown URI should fail.');
  finally
    lModel.Free;
  end;
end;

procedure TestProtocolLifecycleAndCapabilities(AContext: TNXTestContext);
var
  lCapabilities: TJSONObject;
  lDocument: TNexusScriptLSDocument;
  lJSON: TJSONData;
  lModel: TNexusScriptLSModel;
  lResponse: string;
  lResult: TJSONObject;
  lSync: TJSONObject;
begin
  lModel := TNexusScriptLSModel.Create;
  TNexusScriptLSModel.SetCurrent(lModel);
  lJSON := nil;
  try
    lResponse := DispatchJSON(
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}');
    AContext.AssertTrue(lModel.InitializeReceived,
      'Initialize dispatch should update the NexusScriptLS model.');
    lJSON := GetJSON(lResponse);
    lResult := TJSONObject(lJSON).Objects['result'];
    lCapabilities := lResult.Objects['capabilities'];
    AContext.AssertEquals(1, lCapabilities.Count,
      'NexusScriptLS should advertise only document synchronization.');
    lSync := lCapabilities.Objects['textDocumentSync'];
    AContext.AssertEquals(3, lSync.Count,
      'Document synchronization should advertise only open/close, change, and save.');
    AContext.AssertTrue(lSync.Booleans['openClose'],
      'NexusScriptLS should advertise open and close synchronization.');
    AContext.AssertEquals(1, lSync.Integers['change'],
      'NexusScriptLS should advertise full-text document changes.');
    AContext.AssertTrue(lSync.Booleans['save'],
      'NexusScriptLS should advertise save notifications.');
    AContext.AssertEquals('NexusScriptLS',
      lResult.Objects['serverInfo'].Strings['name'],
      'Initialize should identify the dedicated server.');
    FreeAndNil(lJSON);

    DispatchJSON(
      '{"jsonrpc":"2.0","method":"initialized","params":{}}');
    AContext.AssertTrue(lModel.Initialized,
      'Initialized dispatch should update the NexusScriptLS model.');

    DispatchJSON(
      '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{' +
      '"textDocument":{"uri":"file:///C:/work/protocol.nxscript",' +
      '"languageId":"nexusscript","version":1,' +
      '"text":"Definition First {}"}}}');
    lDocument := lModel.FindDocument('file:///C:/work/protocol.nxscript');
    AContext.AssertTrue(lDocument <> nil,
      'DidOpen dispatch should store the document.');
    AContext.AssertEquals('nexusscript', lDocument.LanguageID,
      'DidOpen dispatch should preserve the language ID.');
    AContext.AssertEquals(1, lDocument.Version,
      'DidOpen dispatch should preserve the version.');
    AContext.AssertEquals('Definition First {}', lDocument.Text,
      'DidOpen dispatch should preserve the full text.');

    DispatchJSON(
      '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{' +
      '"textDocument":{"uri":"file:///C:/work/protocol.nxscript",' +
      '"version":2},"contentChanges":[' +
      '{"text":"Definition Second {}"}]}}');
    AContext.AssertEquals(2, lDocument.Version,
      'DidChange dispatch should replace the version.');
    AContext.AssertEquals('Definition Second {}', lDocument.Text,
      'DidChange dispatch should replace the complete text.');

    DispatchJSON(
      '{"jsonrpc":"2.0","method":"textDocument/didSave","params":{' +
      '"textDocument":{"uri":"file:///C:/work/protocol.nxscript"}}}');
    AContext.AssertEquals(2, lDocument.Version,
      'DidSave dispatch should not change the version.');
    AContext.AssertEquals('Definition Second {}', lDocument.Text,
      'DidSave dispatch should not change the text.');

    DispatchJSON(
      '{"jsonrpc":"2.0","method":"textDocument/didClose","params":{' +
      '"textDocument":{"uri":"file:///C:/work/protocol.nxscript"}}}');
    AContext.AssertEquals(0, lModel.DocumentCount,
      'DidClose dispatch should remove the document.');

    lResponse := DispatchJSON(
      '{"jsonrpc":"2.0","id":2,"method":"shutdown"}');
    AContext.AssertTrue(lModel.ShutdownRequested,
      'Shutdown dispatch should update the NexusScriptLS model.');
    lJSON := GetJSON(lResponse);
    AContext.AssertTrue(TJSONObject(lJSON).Find('result').JSONType = jtNull,
      'Shutdown should return a null JSON-RPC result.');
    FreeAndNil(lJSON);

    DispatchJSON('{"jsonrpc":"2.0","method":"exit"}');
    AContext.AssertTrue(lModel.ExitRequested,
      'Exit dispatch should update the NexusScriptLS model.');
  finally
    lJSON.Free;
    TNexusScriptLSModel.SetCurrent(nil);
    lModel.Free;
  end;
end;

procedure RegisterNexusScriptLSShellTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusScriptLS.Shell');
  lSuite.AddTest('ModelDocumentLifecycle', @TestModelDocumentLifecycle);
  lSuite.AddTest('ModelRejectsInvalidDocumentLifecycle',
    @TestModelRejectsInvalidDocumentLifecycle);
  lSuite.AddTest('ProtocolLifecycleAndCapabilities',
    @TestProtocolLifecycleAndCapabilities);
end;

end.
