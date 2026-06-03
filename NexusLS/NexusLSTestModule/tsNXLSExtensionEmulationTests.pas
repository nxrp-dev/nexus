unit tsNXLSExtensionEmulationTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSExtensionEmulationTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  Windows,
  fpjson,
  jsonparser,
  obNXJSONRPCMessages,
  obNXLSAllRequests,
  obNXLSDispatcher,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXTestContext,
  obNXTestSuite;

type
  TNXLSEmulatedClient = class
  private
    FModel: TNXLSLSPModel;
    FNextID: Integer;
    function DispatchJSON(AJSON: TJSONObject; out AResponse: string): Boolean;
    function NextID: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function Initialize(const ARootURI: string): TJSONObject;
    procedure Initialized;
    procedure OpenDocument(const AURI, AText: string);
    function RequestDocumentHighlights(const AURI: string; ALine,
      ACharacter: Integer): TJSONObject;
    function RequestLocation(const AMethod, AURI: string; ALine,
      ACharacter: Integer): TJSONObject;
    function RoutinePairDiagnostics(const AMethod, AURI: string; ALine,
      ACharacter: Integer): string;
  end;

function NXLSLineOf(const AText, ANeedle: string): Integer;
var
  lIdx: Integer;
  lLines: TStringList;
begin
  Result := -1;
  lLines := TStringList.Create;
  try
    lLines.Text := AText;
    for lIdx := 0 to lLines.Count - 1 do
      if Pos(ANeedle, lLines[lIdx]) > 0 then
        Exit(lIdx);
  finally
    lLines.Free;
  end;
end;

function NXLSLineOfAfter(const AText, ANeedle: string;
  AAfterLine: Integer): Integer;
var
  lIdx: Integer;
  lLines: TStringList;
begin
  Result := -1;
  lLines := TStringList.Create;
  try
    lLines.Text := AText;
    for lIdx := AAfterLine + 1 to lLines.Count - 1 do
      if Pos(ANeedle, lLines[lIdx]) > 0 then
        Exit(lIdx);
  finally
    lLines.Free;
  end;
end;

function NXLSColumnOf(const AText, ALineNeedle,
  AColumnNeedle: string): Integer;
var
  lLine: Integer;
  lLines: TStringList;
begin
  Result := -1;
  lLine := NXLSLineOf(AText, ALineNeedle);
  if lLine < 0 then
    Exit;

  lLines := TStringList.Create;
  try
    lLines.Text := AText;
    Result := Pos(AColumnNeedle, lLines[lLine]) - 1;
  finally
    lLines.Free;
  end;
end;

function NXLSColumnOfAfter(const AText, ALineNeedle,
  AColumnNeedle: string; AAfterLine: Integer): Integer;
var
  lLine: Integer;
  lLines: TStringList;
begin
  Result := -1;
  lLine := NXLSLineOfAfter(AText, ALineNeedle, AAfterLine);
  if lLine < 0 then
    Exit;

  lLines := TStringList.Create;
  try
    lLines.Text := AText;
    Result := Pos(AColumnNeedle, lLines[lLine]) - 1;
  finally
    lLines.Free;
  end;
end;

function NXLSLocationStartLine(AResponse: TJSONObject): Integer;
begin
  Result := AResponse.Objects['result'].Objects['range'].Objects['start'].Integers['line'];
end;

function NXLSLocationStartCharacter(AResponse: TJSONObject): Integer;
begin
  Result := AResponse.Objects['result'].Objects['range'].Objects['start'].Integers['character'];
end;

function NXLSHighlightCount(AResponse: TJSONObject): Integer;
begin
  Result := AResponse.Arrays['result'].Count;
end;

function NXLSHighlightStartLine(AResponse: TJSONObject; AIndex: Integer): Integer;
begin
  Result := AResponse.Arrays['result'].Objects[AIndex].Objects['range'].
    Objects['start'].Integers['line'];
end;

function NXLSHighlightStartCharacter(AResponse: TJSONObject;
  AIndex: Integer): Integer;
begin
  Result := AResponse.Arrays['result'].Objects[AIndex].Objects['range'].
    Objects['start'].Integers['character'];
end;

function NXLSHighlightEndLine(AResponse: TJSONObject; AIndex: Integer): Integer;
begin
  Result := AResponse.Arrays['result'].Objects[AIndex].Objects['range'].
    Objects['end'].Integers['line'];
end;

function NXLSHighlightEndCharacter(AResponse: TJSONObject;
  AIndex: Integer): Integer;
begin
  Result := AResponse.Arrays['result'].Objects[AIndex].Objects['range'].
    Objects['end'].Integers['character'];
end;

function NXLSHasHighlightRange(AResponse: TJSONObject; ALine,
  AStartColumn, AEndColumn: Integer): Boolean;
var
  lIdx: Integer;
begin
  Result := False;
  if (AResponse = nil) or (AResponse.Find('result') = nil) or
    (AResponse.Find('result').JSONType <> jtArray) then
    Exit;

  for lIdx := 0 to NXLSHighlightCount(AResponse) - 1 do
    if (NXLSHighlightStartLine(AResponse, lIdx) = ALine) and
      (NXLSHighlightEndLine(AResponse, lIdx) = ALine) and
      (NXLSHighlightStartCharacter(AResponse, lIdx) = AStartColumn) and
      (NXLSHighlightEndCharacter(AResponse, lIdx) = AEndColumn) then
      Exit(True);
end;

procedure NXLSAssertHighlightSet(AContext: TNXTestContext;
  AResponse: TJSONObject; const AMessage: string; const ALines,
  AStartColumns, AEndColumns: array of Integer);
var
  lIdx: Integer;
begin
  AContext.AssertTrue(AResponse <> nil, AMessage + ' response should exist.');
  AContext.AssertTrue(AResponse.Find('error') = nil,
    AMessage + ' should not return an error.');
  AContext.AssertTrue(AResponse.Find('result') <> nil,
    AMessage + ' should contain a result.');
  AContext.AssertTrue(AResponse.Find('result').JSONType = jtArray,
    AMessage + ' result should be an array.');
  AContext.AssertEquals(Length(ALines), NXLSHighlightCount(AResponse),
    AMessage + ' should return the exact highlight count.');
  AContext.AssertEquals(Length(ALines), Length(AStartColumns),
    AMessage + ' expected line/start arrays should match.');
  AContext.AssertEquals(Length(ALines), Length(AEndColumns),
    AMessage + ' expected line/end arrays should match.');

  for lIdx := 0 to High(ALines) do
    AContext.AssertTrue(NXLSHasHighlightRange(AResponse, ALines[lIdx],
      AStartColumns[lIdx], AEndColumns[lIdx]),
      AMessage + ' missing expected highlight ' + IntToStr(lIdx) + '.');
end;

procedure NXLSAssertLocation(AContext: TNXTestContext; AResponse: TJSONObject;
  const AMessage: string);
begin
  AContext.AssertTrue(AResponse <> nil, AMessage + ' response should exist.');
  AContext.AssertTrue(AResponse.Find('error') = nil,
    AMessage + ' should not return an error.');
  AContext.AssertTrue(AResponse.Find('result') <> nil,
    AMessage + ' should contain a result.');
  AContext.AssertTrue(AResponse.Find('result').JSONType = jtObject,
    AMessage + ' result should be a location object.');
end;

procedure NXLSAssertNullResult(AContext: TNXTestContext; AResponse: TJSONObject;
  const AMessage: string);
begin
  AContext.AssertTrue(AResponse <> nil, AMessage + ' response should exist.');
  AContext.AssertTrue(AResponse.Find('error') = nil,
    AMessage + ' should not return an error.');
  AContext.AssertTrue(AResponse.Find('result') <> nil,
    AMessage + ' should contain a result.');
  AContext.AssertTrue(AResponse.Find('result').JSONType = jtNull,
    AMessage + ' result should be null.');
end;

procedure NXLSAssertRequestLocation(AContext: TNXTestContext;
  AClient: TNXLSEmulatedClient; const AMethod, AURI: string; ALine,
  ACharacter, AExpectedLine: Integer; const AMessage: string);
var
  lMessage: string;
  lResponse: TJSONObject;
begin
  lResponse := AClient.RequestLocation(AMethod, AURI, ALine, ACharacter);
  try
    lMessage := AMessage + AClient.RoutinePairDiagnostics(AMethod, AURI,
      ALine, ACharacter);
    NXLSAssertLocation(AContext, lResponse, lMessage);
    AContext.AssertEquals(AExpectedLine, NXLSLocationStartLine(lResponse),
      lMessage + ' should return the expected target line.');
  finally
    lResponse.Free;
  end;
end;

constructor TNXLSEmulatedClient.Create;
begin
  inherited Create;
  FModel := TNXLSLSPModel.Create;
  FNextID := 1;
  TNXLSLSPModel.SetCurrent(FModel);
end;

destructor TNXLSEmulatedClient.Destroy;
begin
  if TNXLSLSPModel.Current = FModel then
    TNXLSLSPModel.SetCurrent(nil);
  FreeAndNil(FModel);
  inherited Destroy;
end;

function TNXLSEmulatedClient.DispatchJSON(AJSON: TJSONObject;
  out AResponse: string): Boolean;
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(AJSON.AsJSON);
  try
    Result := TNXLSDispatcher.DispatchMessage(lMessage, AResponse);
  finally
    lMessage.Free;
  end;
end;

function TNXLSEmulatedClient.NextID: Integer;
begin
  Result := FNextID;
  Inc(FNextID);
end;

function TNXLSEmulatedClient.Initialize(const ARootURI: string): TJSONObject;
var
  lStorageRoot: string;
  lParams: TJSONObject;
  lRequest: TJSONObject;
  lResponse: string;
begin
  Result := nil;
  lStorageRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nexusls-extension-emulation';
  ForceDirectories(IncludeTrailingPathDelimiter(lStorageRoot) + 'search-paths');
  SetEnvironmentVariable(PChar('NEXUSLS_CACHE_DIR'), PChar(lStorageRoot));
  lParams := TJSONObject.Create;
  lRequest := TJSONObject.Create;
  try
    lParams.Add('processId', 1);
    lParams.Add('rootUri', ARootURI);
    lParams.Add('capabilities', TJSONObject.Create);

    lRequest.Add('jsonrpc', '2.0');
    lRequest.Add('id', NextID);
    lRequest.Add('method', 'initialize');
    lRequest.Add('params', lParams);
    lParams := nil;

    DispatchJSON(lRequest, lResponse);
    Result := TJSONObject(GetJSON(lResponse));
  finally
    lParams.Free;
    lRequest.Free;
  end;
end;

procedure TNXLSEmulatedClient.Initialized;
var
  lRequest: TJSONObject;
  lResponse: string;
begin
  lRequest := TJSONObject.Create;
  try
    lRequest.Add('jsonrpc', '2.0');
    lRequest.Add('method', 'initialized');
    lRequest.Add('params', TJSONObject.Create);
    DispatchJSON(lRequest, lResponse);
  finally
    lRequest.Free;
  end;
end;

procedure TNXLSEmulatedClient.OpenDocument(const AURI, AText: string);
var
  lParams: TJSONObject;
  lRequest: TJSONObject;
  lTextDocument: TJSONObject;
  lResponse: string;
begin
  lParams := TJSONObject.Create;
  lRequest := TJSONObject.Create;
  lTextDocument := TJSONObject.Create;
  try
    lTextDocument.Add('uri', AURI);
    lTextDocument.Add('languageId', 'objectpascal');
    lTextDocument.Add('version', 1);
    lTextDocument.Add('text', AText);
    lParams.Add('textDocument', lTextDocument);
    lTextDocument := nil;

    lRequest.Add('jsonrpc', '2.0');
    lRequest.Add('method', 'textDocument/didOpen');
    lRequest.Add('params', lParams);
    lParams := nil;

    DispatchJSON(lRequest, lResponse);
  finally
    lTextDocument.Free;
    lParams.Free;
    lRequest.Free;
  end;
end;

function TNXLSEmulatedClient.RequestDocumentHighlights(const AURI: string;
  ALine, ACharacter: Integer): TJSONObject;
var
  lParams: TJSONObject;
  lPosition: TJSONObject;
  lRequest: TJSONObject;
  lResponse: string;
  lTextDocument: TJSONObject;
begin
  Result := nil;
  lParams := TJSONObject.Create;
  lPosition := TJSONObject.Create;
  lRequest := TJSONObject.Create;
  lTextDocument := TJSONObject.Create;
  try
    lTextDocument.Add('uri', AURI);
    lPosition.Add('line', ALine);
    lPosition.Add('character', ACharacter);
    lParams.Add('textDocument', lTextDocument);
    lTextDocument := nil;
    lParams.Add('position', lPosition);
    lPosition := nil;

    lRequest.Add('jsonrpc', '2.0');
    lRequest.Add('id', NextID);
    lRequest.Add('method', 'textDocument/documentHighlight');
    lRequest.Add('params', lParams);
    lParams := nil;

    DispatchJSON(lRequest, lResponse);
    Result := TJSONObject(GetJSON(lResponse));
  finally
    lTextDocument.Free;
    lPosition.Free;
    lParams.Free;
    lRequest.Free;
  end;
end;

function TNXLSEmulatedClient.RequestLocation(const AMethod, AURI: string;
  ALine, ACharacter: Integer): TJSONObject;
var
  lParams: TJSONObject;
  lPosition: TJSONObject;
  lRequest: TJSONObject;
  lResponse: string;
  lTextDocument: TJSONObject;
begin
  Result := nil;
  lParams := TJSONObject.Create;
  lPosition := TJSONObject.Create;
  lRequest := TJSONObject.Create;
  lTextDocument := TJSONObject.Create;
  try
    lTextDocument.Add('uri', AURI);
    lPosition.Add('line', ALine);
    lPosition.Add('character', ACharacter);
    lParams.Add('textDocument', lTextDocument);
    lTextDocument := nil;
    lParams.Add('position', lPosition);
    lPosition := nil;

    lRequest.Add('jsonrpc', '2.0');
    lRequest.Add('id', NextID);
    lRequest.Add('method', AMethod);
    lRequest.Add('params', lParams);
    lParams := nil;

    DispatchJSON(lRequest, lResponse);
    Result := TJSONObject(GetJSON(lResponse));
  finally
    lTextDocument.Free;
    lPosition.Free;
    lParams.Free;
    lRequest.Free;
  end;
end;

function TNXLSEmulatedClient.RoutinePairDiagnostics(const AMethod,
  AURI: string; ALine, ACharacter: Integer): string;
var
  lParams: TNXLSTextDocumentPositionParams;
  lReport: TStringList;
begin
  Result := '';
  if (AMethod <> 'nexusls.routine.gotoImplementation') and
    (AMethod <> 'nexusls.routine.gotoDeclaration') then
    Exit;

  lParams := TNXLSTextDocumentPositionParams.Create;
  lReport := TStringList.Create;
  try
    lParams.textDocument.uri.Value := AURI;
    lParams.position.line.Value := ALine;
    lParams.position.character.Value := ACharacter;
    FModel.Navigation.CollectRoutinePairDiagnostics(lParams,
      AMethod = 'nexusls.routine.gotoImplementation', lReport);
    Result := LineEnding + lReport.Text;
  finally
    lReport.Free;
    lParams.Free;
  end;
end;

procedure NXLSOpenEmulatedDocument(AContext: TNXTestContext;
  AClient: TNXLSEmulatedClient; const AURI, AText: string);
var
  lResponse: TJSONObject;
begin
  lResponse := AClient.Initialize('file:///C:/workspace');
  try
    AContext.AssertTrue(lResponse <> nil,
      'Initialize response should be available.');
    AContext.AssertTrue(lResponse.Find('error') = nil,
      'Initialize should not return an error: ' + lResponse.AsJSON);
    AContext.AssertTrue(lResponse.Find('result') <> nil,
      'Initialize should return a result.');
    AContext.AssertTrue(lResponse.Objects['result'].Find('capabilities') <> nil,
      'Initialize result should include capabilities.');
    AClient.Initialized;
    AClient.OpenDocument(AURI, AText);
  finally
    lResponse.Free;
  end;
end;

procedure TestInstanceMethodSwitchesBothDirections(AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleInstance.pas';
  cSource =
    'unit SampleInstance;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TFoo = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run(AValue: Integer);' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TFoo.Run(AValue: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lImplementationLine: Integer;
  lResponse: TJSONObject;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);

    lResponse := lClient.RequestLocation('nexusls.routine.gotoImplementation', cURI,
      NXLSLineOf(cSource, '    procedure Run(AValue: Integer);'),
      NXLSColumnOf(cSource, '    procedure Run(AValue: Integer);', 'Run'));
    NXLSAssertLocation(AContext, lResponse,
      'Instance method implementation lookup' +
      lClient.RoutinePairDiagnostics('nexusls.routine.gotoImplementation',
      cURI, NXLSLineOf(cSource, '    procedure Run(AValue: Integer);'),
      NXLSColumnOf(cSource, '    procedure Run(AValue: Integer);', 'Run')));
    AContext.AssertEquals(NXLSLineOf(cSource,
      'procedure TFoo.Run(AValue: Integer);'),
      NXLSLocationStartLine(lResponse),
      'Implementation should point to TFoo.Run.');
    AContext.AssertEquals(NXLSColumnOf(cSource,
      'procedure TFoo.Run(AValue: Integer);', 'Run'),
      NXLSLocationStartCharacter(lResponse),
      'Implementation should point to the simple method name.');
    FreeAndNil(lResponse);

    lImplementationLine := NXLSLineOf(cSource,
      'procedure TFoo.Run(AValue: Integer);');
    lResponse := lClient.RequestLocation('nexusls.routine.gotoImplementation',
      cURI, lImplementationLine, NXLSColumnOf(cSource,
      'procedure TFoo.Run(AValue: Integer);', 'Run'));
    NXLSAssertNullResult(AContext, lResponse,
      'Implementation request from implementation side');
    FreeAndNil(lResponse);

    lResponse := lClient.RequestLocation('nexusls.routine.gotoDeclaration', cURI,
      lImplementationLine,
      NXLSColumnOf(cSource, 'procedure TFoo.Run(AValue: Integer);', 'Run'));
    NXLSAssertLocation(AContext, lResponse,
      'Instance method declaration lookup' +
      lClient.RoutinePairDiagnostics('nexusls.routine.gotoDeclaration',
      cURI, lImplementationLine, NXLSColumnOf(cSource,
      'procedure TFoo.Run(AValue: Integer);', 'Run')));
    AContext.AssertEquals(NXLSLineOf(cSource,
      '    procedure Run(AValue: Integer);'),
      NXLSLocationStartLine(lResponse),
      'Declaration should point to the class-body method.');
    FreeAndNil(lResponse);

    lResponse := lClient.RequestLocation('nexusls.routine.gotoDeclaration',
      cURI, NXLSLineOf(cSource, '    procedure Run(AValue: Integer);'),
      NXLSColumnOf(cSource, '    procedure Run(AValue: Integer);', 'Run'));
    NXLSAssertNullResult(AContext, lResponse,
      'Declaration request from declaration side');
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestClassMethodSwitchesBothDirections(AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleLogger.pas';
  cSource =
    'unit SampleLogger;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TLogger = class' + LineEnding +
    '  public' + LineEnding +
    '    class procedure Info(const AMessage: string); static;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'class procedure TLogger.Info(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lImplementationLine: Integer;
  lResponse: TJSONObject;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);

    lResponse := lClient.RequestLocation('nexusls.routine.gotoImplementation', cURI,
      NXLSLineOf(cSource, '    class procedure Info(const AMessage: string);'),
      NXLSColumnOf(cSource, '    class procedure Info(const AMessage: string);',
      'Info'));
    NXLSAssertLocation(AContext, lResponse, 'Class method implementation lookup' +
      lClient.RoutinePairDiagnostics('nexusls.routine.gotoImplementation',
      cURI, NXLSLineOf(cSource,
      '    class procedure Info(const AMessage: string);'),
      NXLSColumnOf(cSource,
      '    class procedure Info(const AMessage: string);', 'Info')));
    AContext.AssertEquals(NXLSLineOf(cSource,
      'class procedure TLogger.Info(const AMessage: string);'),
      NXLSLocationStartLine(lResponse),
      'Implementation should point to TLogger.Info.');
    FreeAndNil(lResponse);

    lImplementationLine := NXLSLineOf(cSource,
      'class procedure TLogger.Info(const AMessage: string);');
    lResponse := lClient.RequestLocation('nexusls.routine.gotoDeclaration', cURI,
      lImplementationLine,
      NXLSColumnOf(cSource,
      'class procedure TLogger.Info(const AMessage: string);', 'Info'));
    NXLSAssertLocation(AContext, lResponse, 'Class method declaration lookup' +
      lClient.RoutinePairDiagnostics('nexusls.routine.gotoDeclaration',
      cURI, lImplementationLine, NXLSColumnOf(cSource,
      'class procedure TLogger.Info(const AMessage: string);', 'Info')));
    AContext.AssertEquals(NXLSLineOf(cSource,
      '    class procedure Info(const AMessage: string);'),
      NXLSLocationStartLine(lResponse),
      'Declaration should point to class-body Info.');
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestForwardClassMethodSwitchesBothDirections(
  AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleForwardClass.pas';
  cSource =
    'unit SampleForwardClass;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TFoo = class;' + LineEnding +
    '' + LineEnding +
    '  TFoo = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TFoo.Run;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lImplementationLine: Integer;
  lResponse: TJSONObject;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);

    lResponse := lClient.RequestLocation('nexusls.routine.gotoImplementation', cURI,
      NXLSLineOf(cSource, '    procedure Run;'),
      NXLSColumnOf(cSource, '    procedure Run;', 'Run'));
    NXLSAssertLocation(AContext, lResponse,
      'Forward class method implementation lookup');
    AContext.AssertEquals(NXLSLineOf(cSource, 'procedure TFoo.Run;'),
      NXLSLocationStartLine(lResponse),
      'Implementation should point to TFoo.Run.');
    FreeAndNil(lResponse);

    lImplementationLine := NXLSLineOf(cSource, 'procedure TFoo.Run;');
    lResponse := lClient.RequestLocation('nexusls.routine.gotoDeclaration', cURI,
      lImplementationLine,
      NXLSColumnOf(cSource, 'procedure TFoo.Run;', 'Run'));
    NXLSAssertLocation(AContext, lResponse,
      'Forward class method declaration lookup');
    AContext.AssertEquals(NXLSLineOf(cSource, '    procedure Run;'),
      NXLSLocationStartLine(lResponse),
      'Declaration should point to the real class declaration.');
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestLoggerStyleClassProceduresSwitchBothDirections(
  AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleLoggerStyle.pas';
  cSource =
    'unit SampleLoggerStyle;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TNXLSLogger = class' + LineEnding +
    '  public' + LineEnding +
    '    class procedure Info(const AMessage: string); static;' + LineEnding +
    '    class procedure Error(const AMessage: string); static;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'class procedure TNXLSLogger.Info(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'class procedure TNXLSLogger.Error(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lImplementationStart: Integer;
  lResponse: TJSONObject;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);
    lImplementationStart := NXLSLineOf(cSource, 'implementation');

    lResponse := lClient.RequestLocation('nexusls.routine.gotoImplementation', cURI,
      NXLSLineOf(cSource, '    class procedure Info(const AMessage: string);'),
      NXLSColumnOf(cSource, '    class procedure Info(const AMessage: string);',
      'Info'));
    NXLSAssertLocation(AContext, lResponse, 'Info implementation lookup');
    AContext.AssertEquals(NXLSLineOfAfter(cSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      lImplementationStart), NXLSLocationStartLine(lResponse),
      'Info implementation should be selected.');
    FreeAndNil(lResponse);

    lResponse := lClient.RequestLocation('nexusls.routine.gotoDeclaration', cURI,
      NXLSLineOfAfter(cSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      lImplementationStart),
      NXLSColumnOfAfter(cSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);', 'Info',
      lImplementationStart));
    NXLSAssertLocation(AContext, lResponse, 'Info declaration lookup');
    AContext.AssertEquals(NXLSLineOf(cSource,
      '    class procedure Info(const AMessage: string);'),
      NXLSLocationStartLine(lResponse),
      'Info declaration should be selected.');
    FreeAndNil(lResponse);

    lResponse := lClient.RequestLocation('nexusls.routine.gotoImplementation', cURI,
      NXLSLineOf(cSource, '    class procedure Error(const AMessage: string);'),
      NXLSColumnOf(cSource, '    class procedure Error(const AMessage: string);',
      'Error'));
    NXLSAssertLocation(AContext, lResponse, 'Error implementation lookup');
    AContext.AssertEquals(NXLSLineOfAfter(cSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      lImplementationStart), NXLSLocationStartLine(lResponse),
      'Error implementation should be selected.');
    FreeAndNil(lResponse);

    lResponse := lClient.RequestLocation('nexusls.routine.gotoDeclaration', cURI,
      NXLSLineOfAfter(cSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      lImplementationStart),
      NXLSColumnOfAfter(cSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);', 'Error',
      lImplementationStart));
    NXLSAssertLocation(AContext, lResponse, 'Error declaration lookup');
    AContext.AssertEquals(NXLSLineOf(cSource,
      '    class procedure Error(const AMessage: string);'),
      NXLSLocationStartLine(lResponse),
      'Error declaration should be selected.');
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestLoggerStyleDeclarationRangeImplementationLookup(
  AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleLoggerStyleDeclarationRange.pas';
  cSource =
    'unit SampleLoggerStyleDeclarationRange;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TNXLSLogger = class' + LineEnding +
    '  public' + LineEnding +
    '    class procedure Info(const AMessage: string); static;' + LineEnding +
    '    class procedure Error(const AMessage: string); static;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'class procedure TNXLSLogger.Info(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'class procedure TNXLSLogger.Error(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lImplementationStart: Integer;

  procedure AssertDeclPosition(const ADeclLine, AImplLine, ASimpleName,
    AColumnNeedle, AMessage: string; AColumnOffset: Integer = 0);
  begin
    NXLSAssertRequestLocation(AContext, lClient, 'nexusls.routine.gotoImplementation',
      cURI, NXLSLineOf(cSource, ADeclLine),
      NXLSColumnOf(cSource, ADeclLine, AColumnNeedle) + AColumnOffset,
      NXLSLineOfAfter(cSource, AImplLine, lImplementationStart),
      ASimpleName + ' declaration ' + AMessage);
  end;

  procedure AssertDeclarationCoverage(const ADeclLine, AImplLine,
    ASimpleName: string);
  begin
    AssertDeclPosition(ADeclLine, AImplLine, ASimpleName, 'class', 'class');
    AssertDeclPosition(ADeclLine, AImplLine, ASimpleName, 'procedure',
      'procedure');
    AssertDeclPosition(ADeclLine, AImplLine, ASimpleName, ASimpleName,
      'space-before-name', -1);
    AssertDeclPosition(ADeclLine, AImplLine, ASimpleName, ASimpleName, 'name');
    AssertDeclPosition(ADeclLine, AImplLine, ASimpleName, 'AMessage',
      'parameter-list');
    AssertDeclPosition(ADeclLine, AImplLine, ASimpleName, 'static',
      'static-modifier');
  end;
begin
  lClient := TNXLSEmulatedClient.Create;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);
    lImplementationStart := NXLSLineOf(cSource, 'implementation');

    AssertDeclarationCoverage(
      '    class procedure Info(const AMessage: string); static;',
      'class procedure TNXLSLogger.Info(const AMessage: string);', 'Info');
    AssertDeclarationCoverage(
      '    class procedure Error(const AMessage: string); static;',
      'class procedure TNXLSLogger.Error(const AMessage: string);', 'Error');
  finally
    lClient.Free;
  end;
end;

procedure TestLoggerStyleImplementationRangeDeclarationLookup(
  AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleLoggerStyleImplementationRange.pas';
  cSource =
    'unit SampleLoggerStyleImplementationRange;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TNXLSLogger = class' + LineEnding +
    '  public' + LineEnding +
    '    class procedure Info(const AMessage: string); static;' + LineEnding +
    '    class procedure Error(const AMessage: string); static;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'class procedure TNXLSLogger.Info(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'class procedure TNXLSLogger.Error(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lImplementationStart: Integer;

  procedure AssertImplPosition(const ADeclLine, AImplLine, ASimpleName,
    AColumnNeedle, AMessage: string; AColumnOffset: Integer = 0);
  begin
    NXLSAssertRequestLocation(AContext, lClient, 'nexusls.routine.gotoDeclaration',
      cURI, NXLSLineOfAfter(cSource, AImplLine, lImplementationStart),
      NXLSColumnOfAfter(cSource, AImplLine, AColumnNeedle,
      lImplementationStart) + AColumnOffset,
      NXLSLineOf(cSource, ADeclLine), ASimpleName + ' implementation ' +
      AMessage);
  end;

  procedure AssertImplementationBody(const ADeclLine, AImplLine, ASimpleName,
    ABodyNeedle: string);
  begin
    NXLSAssertRequestLocation(AContext, lClient, 'nexusls.routine.gotoDeclaration',
      cURI, NXLSLineOfAfter(cSource, ABodyNeedle, NXLSLineOfAfter(cSource,
      AImplLine, lImplementationStart)), 1, NXLSLineOf(cSource, ADeclLine),
      ASimpleName + ' implementation body');
  end;

  procedure AssertImplementationCoverage(const ADeclLine, AImplLine,
    ASimpleName: string);
  begin
    AssertImplPosition(ADeclLine, AImplLine, ASimpleName, 'class', 'class');
    AssertImplPosition(ADeclLine, AImplLine, ASimpleName, 'procedure',
      'procedure');
    AssertImplPosition(ADeclLine, AImplLine, ASimpleName, 'TNXLSLogger',
      'owner');
    AssertImplPosition(ADeclLine, AImplLine, ASimpleName, '.', 'dot');
    AssertImplPosition(ADeclLine, AImplLine, ASimpleName, ASimpleName, 'name');
    AssertImplPosition(ADeclLine, AImplLine, ASimpleName, 'AMessage',
      'parameter-list');
    AssertImplementationBody(ADeclLine, AImplLine, ASimpleName, 'begin');
  end;
begin
  lClient := TNXLSEmulatedClient.Create;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);
    lImplementationStart := NXLSLineOf(cSource, 'implementation');

    AssertImplementationCoverage(
      '    class procedure Info(const AMessage: string); static;',
      'class procedure TNXLSLogger.Info(const AMessage: string);', 'Info');
    AssertImplementationCoverage(
      '    class procedure Error(const AMessage: string); static;',
      'class procedure TNXLSLogger.Error(const AMessage: string);', 'Error');
  finally
    lClient.Free;
  end;
end;

const
  cDocumentHighlightLoggerURI =
    'file:///C:/workspace/SampleLoggerHighlights.pas';
  cDocumentHighlightLoggerSource =
    'unit SampleLoggerHighlights;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TNXLSLogger = class' + LineEnding +
    '  public' + LineEnding +
    '    class procedure Info(const AMessage: string); static;' + LineEnding +
    '    class procedure Error(const AMessage: string); static;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'class procedure TNXLSLogger.Info(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    '  WriteLn(StdErr, AMessage);' + LineEnding +
    'end;' + LineEnding +
    'class procedure TNXLSLogger.Error(const AMessage: string);' + LineEnding +
    'begin' + LineEnding +
    '  WriteLn(StdErr, AMessage);' + LineEnding +
    'end;' + LineEnding +
    'end.';

procedure NXLSOpenHighlightLogger(AContext: TNXTestContext;
  AClient: TNXLSEmulatedClient);
begin
  NXLSOpenEmulatedDocument(AContext, AClient, cDocumentHighlightLoggerURI,
    cDocumentHighlightLoggerSource);
end;

procedure TestDocumentHighlightOwnerClassNameIsTypeScoped(
  AContext: TNXTestContext);
var
  lClient: TNXLSEmulatedClient;
  lImplementationStart: Integer;
  lResponse: TJSONObject;
  lTokenLength: Integer;
  lTypeLine: Integer;
  lInfoOwnerLine: Integer;
  lErrorOwnerLine: Integer;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenHighlightLogger(AContext, lClient);
    lImplementationStart := NXLSLineOf(cDocumentHighlightLoggerSource,
      'implementation');
    lTokenLength := Length('TNXLSLogger');
    lTypeLine := NXLSLineOf(cDocumentHighlightLoggerSource,
      '  TNXLSLogger = class');
    lInfoOwnerLine := NXLSLineOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      lImplementationStart);
    lErrorOwnerLine := NXLSLineOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      lImplementationStart);

    lResponse := lClient.RequestDocumentHighlights(cDocumentHighlightLoggerURI,
      lInfoOwnerLine, NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      'TNXLSLogger', lImplementationStart));
    NXLSAssertHighlightSet(AContext, lResponse,
      'Owner class name highlight',
      [lTypeLine, lInfoOwnerLine, lErrorOwnerLine],
      [NXLSColumnOf(cDocumentHighlightLoggerSource, '  TNXLSLogger = class',
      'TNXLSLogger'), NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      'TNXLSLogger', lImplementationStart),
      NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      'TNXLSLogger', lImplementationStart)],
      [NXLSColumnOf(cDocumentHighlightLoggerSource, '  TNXLSLogger = class',
      'TNXLSLogger') + lTokenLength,
      NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      'TNXLSLogger', lImplementationStart) + lTokenLength,
      NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      'TNXLSLogger', lImplementationStart) + lTokenLength]);
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestDocumentHighlightInfoRoutineNameIsRoutineScoped(
  AContext: TNXTestContext);
var
  lClient: TNXLSEmulatedClient;
  lDeclarationLine: Integer;
  lImplementationLine: Integer;
  lImplementationStart: Integer;
  lResponse: TJSONObject;
  lTokenLength: Integer;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenHighlightLogger(AContext, lClient);
    lImplementationStart := NXLSLineOf(cDocumentHighlightLoggerSource,
      'implementation');
    lTokenLength := Length('Info');
    lDeclarationLine := NXLSLineOf(cDocumentHighlightLoggerSource,
      '    class procedure Info(const AMessage: string); static;');
    lImplementationLine := NXLSLineOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      lImplementationStart);

    lResponse := lClient.RequestDocumentHighlights(cDocumentHighlightLoggerURI,
      lImplementationLine, NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);', 'Info',
      lImplementationStart));
    NXLSAssertHighlightSet(AContext, lResponse,
      'Info routine name highlight',
      [lDeclarationLine, lImplementationLine],
      [NXLSColumnOf(cDocumentHighlightLoggerSource,
      '    class procedure Info(const AMessage: string); static;', 'Info'),
      NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);', 'Info',
      lImplementationStart)],
      [NXLSColumnOf(cDocumentHighlightLoggerSource,
      '    class procedure Info(const AMessage: string); static;', 'Info') +
      lTokenLength, NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);', 'Info',
      lImplementationStart) + lTokenLength]);
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestDocumentHighlightErrorRoutineNameIsRoutineScoped(
  AContext: TNXTestContext);
var
  lClient: TNXLSEmulatedClient;
  lDeclarationLine: Integer;
  lImplementationLine: Integer;
  lImplementationStart: Integer;
  lResponse: TJSONObject;
  lTokenLength: Integer;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenHighlightLogger(AContext, lClient);
    lImplementationStart := NXLSLineOf(cDocumentHighlightLoggerSource,
      'implementation');
    lTokenLength := Length('Error');
    lDeclarationLine := NXLSLineOf(cDocumentHighlightLoggerSource,
      '    class procedure Error(const AMessage: string); static;');
    lImplementationLine := NXLSLineOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      lImplementationStart);

    lResponse := lClient.RequestDocumentHighlights(cDocumentHighlightLoggerURI,
      lImplementationLine, NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);', 'Error',
      lImplementationStart));
    NXLSAssertHighlightSet(AContext, lResponse,
      'Error routine name highlight',
      [lDeclarationLine, lImplementationLine],
      [NXLSColumnOf(cDocumentHighlightLoggerSource,
      '    class procedure Error(const AMessage: string); static;', 'Error'),
      NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);', 'Error',
      lImplementationStart)],
      [NXLSColumnOf(cDocumentHighlightLoggerSource,
      '    class procedure Error(const AMessage: string); static;', 'Error') +
      lTokenLength, NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);', 'Error',
      lImplementationStart) + lTokenLength]);
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestDocumentHighlightInfoParameterIsRoutineScoped(
  AContext: TNXTestContext);
var
  lClient: TNXLSEmulatedClient;
  lBodyLine: Integer;
  lDeclarationLine: Integer;
  lImplementationLine: Integer;
  lImplementationStart: Integer;
  lResponse: TJSONObject;
  lTokenLength: Integer;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenHighlightLogger(AContext, lClient);
    lImplementationStart := NXLSLineOf(cDocumentHighlightLoggerSource,
      'implementation');
    lTokenLength := Length('AMessage');
    lImplementationLine := NXLSLineOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      lImplementationStart);
    lDeclarationLine := lImplementationLine;
    lBodyLine := NXLSLineOfAfter(cDocumentHighlightLoggerSource,
      '  WriteLn(StdErr, AMessage);', lImplementationLine);

    lResponse := lClient.RequestDocumentHighlights(cDocumentHighlightLoggerURI,
      lBodyLine, NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      '  WriteLn(StdErr, AMessage);', 'AMessage', lImplementationLine));
    NXLSAssertHighlightSet(AContext, lResponse,
      'Info parameter highlight',
      [lDeclarationLine, lBodyLine],
      [NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);', 'AMessage',
      lImplementationStart), NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      '  WriteLn(StdErr, AMessage);', 'AMessage', lImplementationLine)],
      [NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);', 'AMessage',
      lImplementationStart) + lTokenLength,
      NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      '  WriteLn(StdErr, AMessage);', 'AMessage', lImplementationLine) +
      lTokenLength]);
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestDocumentHighlightErrorParameterIsRoutineScoped(
  AContext: TNXTestContext);
var
  lClient: TNXLSEmulatedClient;
  lBodyLine: Integer;
  lDeclarationLine: Integer;
  lImplementationLine: Integer;
  lImplementationStart: Integer;
  lResponse: TJSONObject;
  lTokenLength: Integer;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenHighlightLogger(AContext, lClient);
    lImplementationStart := NXLSLineOf(cDocumentHighlightLoggerSource,
      'implementation');
    lTokenLength := Length('AMessage');
    lImplementationLine := NXLSLineOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      lImplementationStart);
    lDeclarationLine := lImplementationLine;
    lBodyLine := NXLSLineOfAfter(cDocumentHighlightLoggerSource,
      '  WriteLn(StdErr, AMessage);', lImplementationLine);

    lResponse := lClient.RequestDocumentHighlights(cDocumentHighlightLoggerURI,
      lBodyLine, NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      '  WriteLn(StdErr, AMessage);', 'AMessage', lImplementationLine));
    NXLSAssertHighlightSet(AContext, lResponse,
      'Error parameter highlight',
      [lDeclarationLine, lBodyLine],
      [NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      'AMessage', lImplementationStart),
      NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      '  WriteLn(StdErr, AMessage);', 'AMessage', lImplementationLine)],
      [NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      'AMessage', lImplementationStart) + lTokenLength,
      NXLSColumnOfAfter(cDocumentHighlightLoggerSource,
      '  WriteLn(StdErr, AMessage);', 'AMessage', lImplementationLine) +
      lTokenLength]);
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestDocumentHighlightOverloadedRoutineNamesUseIdentity(
  AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleOverloadHighlights.pas';
  cSource =
    'unit SampleOverloadHighlights;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TFoo = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run(AValue: Integer); overload;' + LineEnding +
    '    procedure Run(AValue: string); overload;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TFoo.Run(AValue: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TFoo.Run(AValue: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lImplementationStart: Integer;
  lIntegerDeclLine: Integer;
  lIntegerImplLine: Integer;
  lResponse: TJSONObject;
  lStringDeclLine: Integer;
  lStringImplLine: Integer;
  lTokenLength: Integer;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);
    lImplementationStart := NXLSLineOf(cSource, 'implementation');
    lTokenLength := Length('Run');
    lIntegerDeclLine := NXLSLineOf(cSource,
      '    procedure Run(AValue: Integer); overload;');
    lStringDeclLine := NXLSLineOf(cSource,
      '    procedure Run(AValue: string); overload;');
    lIntegerImplLine := NXLSLineOfAfter(cSource,
      'procedure TFoo.Run(AValue: Integer);', lImplementationStart);
    lStringImplLine := NXLSLineOfAfter(cSource,
      'procedure TFoo.Run(AValue: string);', lImplementationStart);

    lResponse := lClient.RequestDocumentHighlights(cURI, lIntegerImplLine,
      NXLSColumnOfAfter(cSource, 'procedure TFoo.Run(AValue: Integer);',
      'Run', lImplementationStart));
    NXLSAssertHighlightSet(AContext, lResponse,
      'Integer overload routine highlight',
      [lIntegerDeclLine, lIntegerImplLine],
      [NXLSColumnOf(cSource, '    procedure Run(AValue: Integer); overload;',
      'Run'), NXLSColumnOfAfter(cSource,
      'procedure TFoo.Run(AValue: Integer);', 'Run', lImplementationStart)],
      [NXLSColumnOf(cSource, '    procedure Run(AValue: Integer); overload;',
      'Run') + lTokenLength, NXLSColumnOfAfter(cSource,
      'procedure TFoo.Run(AValue: Integer);', 'Run', lImplementationStart) +
      lTokenLength]);
    FreeAndNil(lResponse);

    lResponse := lClient.RequestDocumentHighlights(cURI, lStringImplLine,
      NXLSColumnOfAfter(cSource, 'procedure TFoo.Run(AValue: string);',
      'Run', lImplementationStart));
    NXLSAssertHighlightSet(AContext, lResponse,
      'String overload routine highlight',
      [lStringDeclLine, lStringImplLine],
      [NXLSColumnOf(cSource, '    procedure Run(AValue: string); overload;',
      'Run'), NXLSColumnOfAfter(cSource,
      'procedure TFoo.Run(AValue: string);', 'Run', lImplementationStart)],
      [NXLSColumnOf(cSource, '    procedure Run(AValue: string); overload;',
      'Run') + lTokenLength, NXLSColumnOfAfter(cSource,
      'procedure TFoo.Run(AValue: string);', 'Run', lImplementationStart) +
      lTokenLength]);
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestDocumentHighlightLocalVariablesStayInRoutine(
  AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleLocalHighlights.pas';
  cSource =
    'unit SampleLocalHighlights;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure First;' + LineEnding +
    'var' + LineEnding +
    '  Value: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Value := 1;' + LineEnding +
    'end;' + LineEnding +
    'procedure Second;' + LineEnding +
    'var' + LineEnding +
    '  Value: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Value := 2;' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lFirstBodyLine: Integer;
  lFirstDeclLine: Integer;
  lResponse: TJSONObject;
  lSecondBodyLine: Integer;
  lSecondDeclLine: Integer;
  lTokenLength: Integer;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);
    lTokenLength := Length('Value');
    lFirstDeclLine := NXLSLineOf(cSource, '  Value: Integer;');
    lFirstBodyLine := NXLSLineOf(cSource, '  Value := 1;');
    lSecondDeclLine := NXLSLineOfAfter(cSource, '  Value: Integer;',
      lFirstBodyLine);
    lSecondBodyLine := NXLSLineOf(cSource, '  Value := 2;');

    lResponse := lClient.RequestDocumentHighlights(cURI, lFirstBodyLine,
      NXLSColumnOf(cSource, '  Value := 1;', 'Value'));
    NXLSAssertHighlightSet(AContext, lResponse,
      'First local Value highlight',
      [lFirstDeclLine, lFirstBodyLine],
      [NXLSColumnOf(cSource, '  Value: Integer;', 'Value'),
      NXLSColumnOf(cSource, '  Value := 1;', 'Value')],
      [NXLSColumnOf(cSource, '  Value: Integer;', 'Value') + lTokenLength,
      NXLSColumnOf(cSource, '  Value := 1;', 'Value') + lTokenLength]);
    FreeAndNil(lResponse);

    lResponse := lClient.RequestDocumentHighlights(cURI, lSecondBodyLine,
      NXLSColumnOf(cSource, '  Value := 2;', 'Value'));
    NXLSAssertHighlightSet(AContext, lResponse,
      'Second local Value highlight',
      [lSecondDeclLine, lSecondBodyLine],
      [NXLSColumnOfAfter(cSource, '  Value: Integer;', 'Value', lFirstBodyLine),
      NXLSColumnOf(cSource, '  Value := 2;', 'Value')],
      [NXLSColumnOfAfter(cSource, '  Value: Integer;', 'Value', lFirstBodyLine) +
      lTokenLength, NXLSColumnOf(cSource, '  Value := 2;', 'Value') +
      lTokenLength]);
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure TestRoutineContextOutsideRoutineKeepsExistingNoResult(
  AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleRoutineContextGuard.pas';
  cSource =
    'unit SampleRoutineContextGuard;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TFoo = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TFoo.Run;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    '' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lResponse: TJSONObject;

  procedure AssertNoRoutinePair(const AMethod, ALineNeedle,
    AColumnNeedle, AMessage: string);
  begin
    FreeAndNil(lResponse);
    lResponse := lClient.RequestLocation(AMethod, cURI,
      NXLSLineOf(cSource, ALineNeedle),
      NXLSColumnOf(cSource, ALineNeedle, AColumnNeedle));
    AContext.AssertTrue(lResponse <> nil, AMessage + ' response should exist.');
    AContext.AssertTrue(lResponse.Find('error') = nil,
      AMessage + ' should not error.');
    AContext.AssertTrue((lResponse.Find('result') = nil) or
      (lResponse.Find('result').JSONType = jtNull),
      AMessage + ' should not return a routine pair.');
  end;

  procedure AssertNoRoutinePairAt(const AMethod: string; ALine,
    AColumn: Integer; const AMessage: string);
  begin
    FreeAndNil(lResponse);
    lResponse := lClient.RequestLocation(AMethod, cURI, ALine, AColumn);
    AContext.AssertTrue(lResponse <> nil, AMessage + ' response should exist.');
    AContext.AssertTrue(lResponse.Find('error') = nil,
      AMessage + ' should not error.');
    AContext.AssertTrue((lResponse.Find('result') = nil) or
      (lResponse.Find('result').JSONType = jtNull),
      AMessage + ' should not return a routine pair.');
  end;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);
    AssertNoRoutinePair('nexusls.routine.gotoImplementation',
      '  TFoo = class', 'TFoo', 'Class line implementation');
    AssertNoRoutinePair('nexusls.routine.gotoImplementation',
      '  public', 'public', 'Visibility line implementation');
    AssertNoRoutinePairAt('nexusls.routine.gotoDeclaration',
      NXLSLineOf(cSource, 'procedure TFoo.Run;') + 3, 0,
      'Blank line declaration');
  finally
    lResponse.Free;
    lClient.Free;
  end;
end;

procedure RegisterNXLSExtensionEmulationTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.ExtensionEmulation');
  lSuite.AddTest('InstanceMethodSwitchesBothDirections',
    @TestInstanceMethodSwitchesBothDirections);
  lSuite.AddTest('ClassMethodSwitchesBothDirections',
    @TestClassMethodSwitchesBothDirections);
  lSuite.AddTest('ForwardClassMethodSwitchesBothDirections',
    @TestForwardClassMethodSwitchesBothDirections);
  lSuite.AddTest('LoggerStyleClassProceduresSwitchBothDirections',
    @TestLoggerStyleClassProceduresSwitchBothDirections);
  lSuite.AddTest('LoggerStyleDeclarationRangeImplementationLookup',
    @TestLoggerStyleDeclarationRangeImplementationLookup);
  lSuite.AddTest('LoggerStyleImplementationRangeDeclarationLookup',
    @TestLoggerStyleImplementationRangeDeclarationLookup);
  lSuite.AddTest('DocumentHighlightOwnerClassNameIsTypeScoped',
    @TestDocumentHighlightOwnerClassNameIsTypeScoped);
  lSuite.AddTest('DocumentHighlightInfoRoutineNameIsRoutineScoped',
    @TestDocumentHighlightInfoRoutineNameIsRoutineScoped);
  lSuite.AddTest('DocumentHighlightErrorRoutineNameIsRoutineScoped',
    @TestDocumentHighlightErrorRoutineNameIsRoutineScoped);
  lSuite.AddTest('DocumentHighlightInfoParameterIsRoutineScoped',
    @TestDocumentHighlightInfoParameterIsRoutineScoped);
  lSuite.AddTest('DocumentHighlightErrorParameterIsRoutineScoped',
    @TestDocumentHighlightErrorParameterIsRoutineScoped);
  lSuite.AddTest('DocumentHighlightOverloadedRoutineNamesUseIdentity',
    @TestDocumentHighlightOverloadedRoutineNamesUseIdentity);
  lSuite.AddTest('DocumentHighlightLocalVariablesStayInRoutine',
    @TestDocumentHighlightLocalVariablesStayInRoutine);
  lSuite.AddTest('RoutineContextOutsideRoutineKeepsExistingNoResult',
    @TestRoutineContextOutsideRoutineKeepsExistingNoResult);
end;

end.
