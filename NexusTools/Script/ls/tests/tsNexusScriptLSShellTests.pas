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
  obNexusScriptAnalysis,
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

procedure TestOverlayAnalysisAndDependencyRefresh(AContext: TNXTestContext);
const
  cEntryURI = 'file:///C:/work/entry.nxscript';
  cDependencyURI = 'file:///C:/work/dependency.nxscript';
var
  lAnalysis: TNexusScriptAnalysis;
  lModel: TNexusScriptLSModel;
begin
  lModel := TNexusScriptLSModel.Create;
  try
    lModel.OpenDocument(cDependencyURI, 'nexusscript', 1,
      'Definition Dependency {}');
    lModel.OpenDocument(cEntryURI, 'nexusscript', 1,
      'module "dependency.nxscript";' + LineEnding +
      'Definition Entry {}');
    lAnalysis := lModel.FindAnalysis(cEntryURI);
    AContext.AssertTrue((lAnalysis <> nil) and lAnalysis.Succeeded,
      'An open overlay dependency should compile without a disk file.');
    AContext.AssertEquals(1,
      lAnalysis.Session.AttemptedVersions[1],
      'Analysis should retain the dependency overlay version.');

    lModel.ChangeDocument(cDependencyURI, 2, 'Definition Dependency {');
    lAnalysis := lModel.FindAnalysis(cEntryURI);
    AContext.AssertTrue((lAnalysis <> nil) and not lAnalysis.Succeeded,
      'Changing an open dependency should reanalyze the entry.');
    AContext.AssertTrue(lAnalysis.Session.AttemptedCompilerCount >= 2,
      'Failed analysis should retain its attempted dependency compiler.');
    AContext.AssertTrue(
      lAnalysis.Session.AttemptedCompilers[1].SourceDocument <> nil,
      'Failed analysis should retain the dependency source model.');
    AContext.AssertTrue(
      lAnalysis.Session.AttemptedCompilers[1].Diagnostics.Count > 0,
      'Failed analysis should retain dependency diagnostics.');
  finally
    lModel.Free;
  end;
end;

procedure TestOverlayRecursiveDiscoveryAndDependencyDiagnostics(
  AContext: TNXTestContext);
const
  cEntryURI = 'file:///C:/work/discovery.nxscript';
  cChildURI = 'file:///C:/work/sub/child.nxscript';
var
  lAnalysis: TNexusScriptAnalysis;
  lModel: TNexusScriptLSModel;
begin
  lModel := TNexusScriptLSModel.Create;
  try
    lModel.OpenDocument(cChildURI, 'nexusscript', 3,
      'Thing Child {}');
    lModel.OpenDocument(cEntryURI, 'nexusscript', 1,
      'module recursive "sub/*.nxscript";' + LineEnding +
      'Thing Entry {}');
    lAnalysis := lModel.FindAnalysis(cEntryURI);
    AContext.AssertTrue((lAnalysis <> nil) and lAnalysis.Succeeded,
      'Recursive discovery should find an overlay-only descendant folder.');

    lModel.ChangeDocument(cEntryURI, 2,
      'module "missing.nxscript";' + LineEnding + 'Thing Entry {}');
    lAnalysis := lModel.FindAnalysis(cEntryURI);
    AContext.AssertTrue(not lAnalysis.Succeeded,
      'A missing dependency should fail analysis.');
    AContext.AssertTrue(lAnalysis.Session.Diagnostics.Count > 0,
      'A missing dependency should retain a session diagnostic.');
    AContext.AssertEquals('module-load-failed',
      lAnalysis.Session.Diagnostics[0].Code,
      'The dependency diagnostic should identify module loading.');
    AContext.AssertEquals(1,
      lAnalysis.Session.Diagnostics[0].SourceRange.StartPosition.Line,
      'The dependency diagnostic should point at the declaring operation.');
  finally
    lModel.Free;
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

procedure TestUntitledDocumentAnalysis(AContext: TNXTestContext);
const
  cURI = 'untitled:Untitled-1';
var
  lAnalysis: TNexusScriptAnalysis;
  lJSON: TJSONData;
  lModel: TNexusScriptLSModel;
  lResponse: string;
begin
  lModel := TNexusScriptLSModel.Create;
  TNexusScriptLSModel.SetCurrent(lModel);
  lJSON := nil;
  try
    lModel.OpenDocument(cURI, 'nexusscript', 1, 'Thing Unsaved {}');
    lAnalysis := lModel.FindAnalysis(cURI);
    AContext.AssertTrue((lAnalysis <> nil) and lAnalysis.Succeeded,
      'An untitled buffer should receive local NexusScript analysis.');
    AContext.AssertEquals(1, lAnalysis.Session.AttemptedVersions[0],
      'Untitled analysis should retain the open-buffer version.');
    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":40,' +
      '"method":"nexusscript/documentModel","params":{' +
      '"textDocument":{"uri":"' + cURI + '"}}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertEquals(cURI,
      TJSONObject(TJSONObject(lJSON).Objects['result'].Arrays['nodes'][0]).
      Strings['sourceUri'],
      'Semantic nodes should retain the original untitled URI.');
  finally
    lJSON.Free;
    TNexusScriptLSModel.SetCurrent(nil);
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
    AContext.AssertEquals(8, lCapabilities.Count,
      'NexusScriptLS should advertise only implemented capabilities.');
    lSync := lCapabilities.Objects['textDocumentSync'];
    AContext.AssertEquals(3, lSync.Count,
      'Document synchronization should advertise only open/close, change, and save.');
    AContext.AssertTrue(lSync.Booleans['openClose'],
      'NexusScriptLS should advertise open and close synchronization.');
    AContext.AssertEquals(1, lSync.Integers['change'],
      'NexusScriptLS should advertise full-text document changes.');
    AContext.AssertTrue(lSync.Booleans['save'],
      'NexusScriptLS should advertise save notifications.');
    AContext.AssertTrue(lCapabilities.Booleans['documentSymbolProvider'],
      'NexusScriptLS should advertise document symbols.');
    AContext.AssertTrue(lCapabilities.Booleans['hoverProvider'],
      'NexusScriptLS should advertise hover.');
    AContext.AssertTrue(lCapabilities.Booleans['definitionProvider'],
      'NexusScriptLS should advertise definition navigation.');
    AContext.AssertTrue(lCapabilities.Find('completionProvider') is TJSONObject,
      'NexusScriptLS should advertise completion.');
    AContext.AssertTrue(lCapabilities.Booleans['referencesProvider'],
      'NexusScriptLS should advertise references.');
    AContext.AssertTrue(lCapabilities.Booleans['documentHighlightProvider'],
      'NexusScriptLS should advertise document highlights.');
    AContext.AssertTrue(lCapabilities.Find('renameProvider') is TJSONObject,
      'NexusScriptLS should advertise rename.');
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

procedure TestSemanticProtocolFeatures(AContext: TNXTestContext);
const
  cURI = 'file:///C:/work/semantic.nxscript';
  cText = 'Thing Root { Thing Target {} Link: @Target; }';
var
  lJSON: TJSONData;
  lModel: TNexusScriptLSModel;
  lResponse: string;
  lReferenceColumn: Integer;
  lRootID: string;
  lRevision: Integer;
  lAnalysis: TNexusScriptAnalysis;
begin
  lModel := TNexusScriptLSModel.Create;
  TNexusScriptLSModel.SetCurrent(lModel);
  lJSON := nil;
  try
    lModel.OpenDocument(cURI, 'nexusscript', 7, cText);
    lAnalysis := lModel.FindAnalysis(cURI);
    AContext.AssertEquals(1,
      lAnalysis.EntrySourceCompiler.SourceDocument.Definitions[0].KindRange.
      StartPosition.Column,
      'Definition kind should retain its precise source range.');
    AContext.AssertEquals(7,
      lAnalysis.EntrySourceCompiler.SourceDocument.Definitions[0].NameRange.
      StartPosition.Column,
      'Definition name should retain its precise source range.');
    AContext.AssertTrue(
      lAnalysis.EntryCompiler.CompiledDocument.Definitions[0].
      FindProperty('Link').Value.ReferenceRanges.Count = 1,
      'A compiled reference should retain each parsed path segment range.');

    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":10,' +
      '"method":"textDocument/documentSymbol","params":{' +
      '"textDocument":{"uri":"' + cURI + '"}}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertEquals(1, TJSONObject(lJSON).Arrays['result'].Count,
      'Document symbols should expose the source root.');
    FreeAndNil(lJSON);

    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":11,' +
      '"method":"nexusscript/documentModel","params":{' +
      '"textDocument":{"uri":"' + cURI + '"}}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertEquals(7,
      TJSONObject(lJSON).Objects['result'].Integers['version'],
      'The semantic model should carry the source version.');
    AContext.AssertEquals(1,
      TJSONObject(lJSON).Objects['result'].Arrays['nodes'].Count,
      'The semantic model should expose typed source nodes.');
    lRootID := TJSONObject(TJSONObject(lJSON).Objects['result'].
      Arrays['nodes'][0]).Strings['id'];
    lRevision := TJSONObject(lJSON).Objects['result'].Integers['revision'];
    FreeAndNil(lJSON);

    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":14,' +
      '"method":"nexusscript/semanticEdit","params":{' +
      '"textDocument":{"uri":"' + cURI + '"},"version":7,' +
      '"revision":' + IntToStr(lRevision) + ',"nodeId":"' + lRootID + '",' +
      '"operation":"setProperty","name":"Added","value":"yes"}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertEquals(' Added: yes;',
      TJSONObject(TJSONObject(lJSON).Objects['result'].
      Arrays['documentChanges'][0]).Arrays['edits'][0].FindPath('newText').AsString,
      'Semantic property insertion should be a narrow text edit.');
    FreeAndNil(lJSON);

    lReferenceColumn := Pos('@Target', cText);
    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":12,' +
      '"method":"textDocument/references","params":{' +
      '"textDocument":{"uri":"' + cURI + '"},' +
      '"position":{"line":0,"character":' + IntToStr(lReferenceColumn) +
      '},"context":{"includeDeclaration":true}}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertEquals(2, TJSONObject(lJSON).Arrays['result'].Count,
      'References should include the resolved declaration and reference.');
    FreeAndNil(lJSON);

    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":13,' +
      '"method":"textDocument/rename","params":{' +
      '"textDocument":{"uri":"' + cURI + '"},' +
      '"position":{"line":0,"character":' + IntToStr(lReferenceColumn) +
      '},"newName":"Renamed"}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertEquals(1,
      TJSONObject(lJSON).Objects['result'].Arrays['documentChanges'].Count,
      'Rename should group edits for one source document.');
    AContext.AssertEquals(2,
      TJSONObject(TJSONObject(lJSON).Objects['result'].
      Arrays['documentChanges'][0]).Arrays['edits'].Count,
      'Rename should return precise edits for the declaration and reference.');
    FreeAndNil(lJSON);

    lModel.ChangeDocument(cURI, 8, cText);
    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":15,' +
      '"method":"nexusscript/semanticEdit","params":{' +
      '"textDocument":{"uri":"' + cURI + '"},"version":7,' +
      '"revision":' + IntToStr(lRevision) + ',"nodeId":"' + lRootID + '",' +
      '"operation":"setProperty","name":"Added","value":"yes"}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertTrue(TJSONObject(lJSON).Find('error') <> nil,
      'A stale semantic edit must be rejected.');
  finally
    lJSON.Free;
    TNexusScriptLSModel.SetCurrent(nil);
    lModel.Free;
  end;
end;

procedure TestDialectModelAndCompletion(AContext: TNXTestContext);
const
  cURI = 'file:///C:/work/language-subject.nxscript';
  cText = 'dialect "Language/Language.nxscript";' + LineEnding +
    'Language Subject { }';
var
  lJSON: TJSONData;
  lModel: TNexusScriptLSModel;
  lResponse: string;
begin
  lModel := TNexusScriptLSModel.Create;
  TNexusScriptLSModel.SetCurrent(lModel);
  lJSON := nil;
  try
    lModel.DialectRoot := ExpandFileName('NexusLib\script\dialects');
    lModel.OpenDocument(cURI, 'nexusscript', 1, cText);
    AContext.AssertTrue(lModel.FindAnalysis(cURI).Succeeded,
      'The LS should resolve dialects from its configured catalog root.');

    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":20,' +
      '"method":"nexusscript/dialectModel","params":{' +
      '"textDocument":{"uri":"' + cURI + '"}}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertTrue(TJSONObject(lJSON).Objects['result'].
      Arrays['rules'].Count > 0,
      'The typed dialect model should contain normalized rules.');
    FreeAndNil(lJSON);

    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":21,' +
      '"method":"textDocument/completion","params":{' +
      '"textDocument":{"uri":"' + cURI + '"},' +
      '"position":{"line":1,"character":18}}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertTrue(TJSONObject(lJSON).Arrays['result'].Count > 0,
      'Completion should be driven by the normalized dialect.');
  finally
    lJSON.Free;
    TNexusScriptLSModel.SetCurrent(nil);
    lModel.Free;
  end;
end;

procedure TestNavigationAndTargetContext(AContext: TNXTestContext);
const
  cDependencyURI = 'file:///C:/work/nav-dependency.nxscript';
  cEntryURI = 'file:///C:/work/nav-entry.nxscript';
  cTargetURI = 'file:///C:/work/targets.nxscript';
  cEntryText = 'module "nav-dependency.nxscript";' + LineEnding +
    'Thing Base {} Thing Child (Base) {}';
  cTargetText = 'Thing Choice Target[Dev] { Value: dev; } ' +
    'Thing Choice Target[Prod] { Value: prod; }';
var
  lJSON: TJSONData;
  lModel: TNexusScriptLSModel;
  lResponse: string;
begin
  lModel := TNexusScriptLSModel.Create;
  TNexusScriptLSModel.SetCurrent(lModel);
  lJSON := nil;
  try
    lModel.OpenDocument(cDependencyURI, 'nexusscript', 1,
      'Thing Imported {}');
    lModel.OpenDocument(cEntryURI, 'nexusscript', 1, cEntryText);
    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":30,' +
      '"method":"textDocument/definition","params":{' +
      '"textDocument":{"uri":"' + cEntryURI + '"},' +
      '"position":{"line":0,"character":10}}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertEquals(cDependencyURI,
      TJSONObject(lJSON).Objects['result'].Strings['uri'],
      'Dependency path navigation should reach the dependency source.');
    FreeAndNil(lJSON);

    lResponse := DispatchJSON('{"jsonrpc":"2.0","id":31,' +
      '"method":"textDocument/definition","params":{' +
      '"textDocument":{"uri":"' + cEntryURI + '"},' +
      '"position":{"line":1,"character":27}}}');
    lJSON := GetJSON(lResponse);
    AContext.AssertEquals(cEntryURI,
      TJSONObject(lJSON).Objects['result'].Strings['uri'],
      'Composition navigation should use compiler-recorded provenance.');
    FreeAndNil(lJSON);

    lModel.OpenDocument(cTargetURI, 'nexusscript', 1, cTargetText);
    AContext.AssertTrue(not lModel.FindAnalysis(cTargetURI).Succeeded,
      'Untargeted analysis should retain duplicate Target alternatives.');
    DispatchJSON('{"jsonrpc":"2.0","id":32,' +
      '"method":"nexusscript/setTargets","params":{' +
      '"targets":[{"kind":"Target","value":"Dev"}]}}');
    AContext.AssertTrue(lModel.FindAnalysis(cTargetURI).Succeeded,
      'Changing workspace Targets should rebuild analysis with that selection.');
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
  lSuite.AddTest('UntitledDocumentAnalysis', @TestUntitledDocumentAnalysis);
  lSuite.AddTest('OverlayAnalysisAndDependencyRefresh',
    @TestOverlayAnalysisAndDependencyRefresh);
  lSuite.AddTest('OverlayRecursiveDiscoveryAndDependencyDiagnostics',
    @TestOverlayRecursiveDiscoveryAndDependencyDiagnostics);
  lSuite.AddTest('ProtocolLifecycleAndCapabilities',
    @TestProtocolLifecycleAndCapabilities);
  lSuite.AddTest('SemanticProtocolFeatures', @TestSemanticProtocolFeatures);
  lSuite.AddTest('DialectModelAndCompletion', @TestDialectModelAndCompletion);
  lSuite.AddTest('NavigationAndTargetContext', @TestNavigationAndTargetContext);
end;

end.
