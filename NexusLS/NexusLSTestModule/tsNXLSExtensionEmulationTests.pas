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
    function RequestLocation(const AMethod, AURI: string; ALine,
      ACharacter: Integer): TJSONObject;
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

procedure NXLSAssertRequestLocation(AContext: TNXTestContext;
  AClient: TNXLSEmulatedClient; const AMethod, AURI: string; ALine,
  ACharacter, AExpectedLine: Integer; const AMessage: string);
var
  lResponse: TJSONObject;
begin
  lResponse := AClient.RequestLocation(AMethod, AURI, ALine, ACharacter);
  try
    NXLSAssertLocation(AContext, lResponse, AMessage);
    AContext.AssertEquals(AExpectedLine, NXLSLocationStartLine(lResponse),
      AMessage + ' should return the expected target line.');
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

    lResponse := lClient.RequestLocation('textDocument/implementation', cURI,
      NXLSLineOf(cSource, '    procedure Run(AValue: Integer);'),
      NXLSColumnOf(cSource, '    procedure Run(AValue: Integer);', 'Run'));
    NXLSAssertLocation(AContext, lResponse,
      'Instance method implementation lookup');
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
    lResponse := lClient.RequestLocation('textDocument/declaration', cURI,
      lImplementationLine,
      NXLSColumnOf(cSource, 'procedure TFoo.Run(AValue: Integer);', 'Run'));
    NXLSAssertLocation(AContext, lResponse,
      'Instance method declaration lookup');
    AContext.AssertEquals(NXLSLineOf(cSource,
      '    procedure Run(AValue: Integer);'),
      NXLSLocationStartLine(lResponse),
      'Declaration should point to the class-body method.');
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

    lResponse := lClient.RequestLocation('textDocument/implementation', cURI,
      NXLSLineOf(cSource, '    class procedure Info(const AMessage: string);'),
      NXLSColumnOf(cSource, '    class procedure Info(const AMessage: string);',
      'Info'));
    NXLSAssertLocation(AContext, lResponse, 'Class method implementation lookup');
    AContext.AssertEquals(NXLSLineOf(cSource,
      'class procedure TLogger.Info(const AMessage: string);'),
      NXLSLocationStartLine(lResponse),
      'Implementation should point to TLogger.Info.');
    FreeAndNil(lResponse);

    lImplementationLine := NXLSLineOf(cSource,
      'class procedure TLogger.Info(const AMessage: string);');
    lResponse := lClient.RequestLocation('textDocument/declaration', cURI,
      lImplementationLine,
      NXLSColumnOf(cSource,
      'class procedure TLogger.Info(const AMessage: string);', 'Info'));
    NXLSAssertLocation(AContext, lResponse, 'Class method declaration lookup');
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

    lResponse := lClient.RequestLocation('textDocument/implementation', cURI,
      NXLSLineOf(cSource, '    procedure Run;'),
      NXLSColumnOf(cSource, '    procedure Run;', 'Run'));
    NXLSAssertLocation(AContext, lResponse,
      'Forward class method implementation lookup');
    AContext.AssertEquals(NXLSLineOf(cSource, 'procedure TFoo.Run;'),
      NXLSLocationStartLine(lResponse),
      'Implementation should point to TFoo.Run.');
    FreeAndNil(lResponse);

    lImplementationLine := NXLSLineOf(cSource, 'procedure TFoo.Run;');
    lResponse := lClient.RequestLocation('textDocument/declaration', cURI,
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

    lResponse := lClient.RequestLocation('textDocument/implementation', cURI,
      NXLSLineOf(cSource, '    class procedure Info(const AMessage: string);'),
      NXLSColumnOf(cSource, '    class procedure Info(const AMessage: string);',
      'Info'));
    NXLSAssertLocation(AContext, lResponse, 'Info implementation lookup');
    AContext.AssertEquals(NXLSLineOfAfter(cSource,
      'class procedure TNXLSLogger.Info(const AMessage: string);',
      lImplementationStart), NXLSLocationStartLine(lResponse),
      'Info implementation should be selected.');
    FreeAndNil(lResponse);

    lResponse := lClient.RequestLocation('textDocument/declaration', cURI,
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

    lResponse := lClient.RequestLocation('textDocument/implementation', cURI,
      NXLSLineOf(cSource, '    class procedure Error(const AMessage: string);'),
      NXLSColumnOf(cSource, '    class procedure Error(const AMessage: string);',
      'Error'));
    NXLSAssertLocation(AContext, lResponse, 'Error implementation lookup');
    AContext.AssertEquals(NXLSLineOfAfter(cSource,
      'class procedure TNXLSLogger.Error(const AMessage: string);',
      lImplementationStart), NXLSLocationStartLine(lResponse),
      'Error implementation should be selected.');
    FreeAndNil(lResponse);

    lResponse := lClient.RequestLocation('textDocument/declaration', cURI,
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
    NXLSAssertRequestLocation(AContext, lClient, 'textDocument/implementation',
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
    NXLSAssertRequestLocation(AContext, lClient, 'textDocument/declaration',
      cURI, NXLSLineOfAfter(cSource, AImplLine, lImplementationStart),
      NXLSColumnOfAfter(cSource, AImplLine, AColumnNeedle,
      lImplementationStart) + AColumnOffset,
      NXLSLineOf(cSource, ADeclLine), ASimpleName + ' implementation ' +
      AMessage);
  end;

  procedure AssertImplementationBody(const ADeclLine, AImplLine, ASimpleName,
    ABodyNeedle: string);
  begin
    NXLSAssertRequestLocation(AContext, lClient, 'textDocument/declaration',
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

procedure TestRoutineContextOutsideRoutineKeepsExistingNoResult(
  AContext: TNXTestContext);
const
  cURI = 'file:///C:/workspace/SampleRoutineContextGuard.pas';
  cSource =
    'unit SampleRoutineContextGuard;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TFoo = class' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lClient: TNXLSEmulatedClient;
  lResponse: TJSONObject;
begin
  lClient := TNXLSEmulatedClient.Create;
  lResponse := nil;
  try
    NXLSOpenEmulatedDocument(AContext, lClient, cURI, cSource);
    lResponse := lClient.RequestLocation('textDocument/implementation', cURI,
      NXLSLineOf(cSource, '  TFoo = class'), NXLSColumnOf(cSource,
      '  TFoo = class', 'TFoo'));
    AContext.AssertTrue(lResponse <> nil,
      'Outside-routine implementation response should exist.');
    AContext.AssertTrue(lResponse.Find('error') = nil,
      'Outside-routine implementation should not error.');
    AContext.AssertTrue((lResponse.Find('result') = nil) or
      (lResponse.Find('result').JSONType = jtNull),
      'Outside-routine implementation should not return a routine pair.');
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
  lSuite.AddTest('RoutineContextOutsideRoutineKeepsExistingNoResult',
    @TestRoutineContextOutsideRoutineKeepsExistingNoResult);
end;

end.
