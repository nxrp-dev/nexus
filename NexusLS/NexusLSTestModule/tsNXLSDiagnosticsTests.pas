unit tsNXLSDiagnosticsTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSDiagnosticsTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  obNXLSTransport,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSServiceContext,
  obNXTestContext,
  obNXTestSuite;

type
  TNXLSTestTransport = class(TNXLSTransport)
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
    procedure Clear;
    function LastPayload: string;
  end;

const
  cValidUnit =
    'unit DiagnosticsUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'end.';

  cInvalidUnit =
    'unit DiagnosticsUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'procedure Broken' + LineEnding +
    'implementation' + LineEnding +
    'end.';

function TNXLSTestTransport.ReadLine(out ALine: string): Boolean;
begin
  ALine := '';
  Result := False;
end;

function TNXLSTestTransport.ReadContent(const ALength: Integer;
  out AContent: string): Boolean;
begin
  AContent := '';
  Result := False;
end;

procedure TNXLSTestTransport.WriteContent(const AContent: string);
begin
  FOutput := FOutput + AContent;
end;

procedure TNXLSTestTransport.Open;
begin
  FOpen := True;
end;

procedure TNXLSTestTransport.Close;
begin
  FOpen := False;
end;

function TNXLSTestTransport.IsOpen: Boolean;
begin
  Result := FOpen;
end;

procedure TNXLSTestTransport.Clear;
begin
  FOutput := '';
end;

function TNXLSTestTransport.LastPayload: string;
var
  lPos: Integer;
begin
  Result := '';
  lPos := Pos(#13#10#13#10, FOutput);
  if lPos > 0 then
    Result := Copy(FOutput, lPos + 4, MaxInt);
end;

function NXLSCreateUniqueTempDir(const APrefix: string): string;
var
  lTempFile: string;
begin
  lTempFile := GetTempFileName('', APrefix);
  if FileExists(lTempFile) then
    DeleteFile(lTempFile);

  Result := lTempFile + '_dir';
  ForceDirectories(Result);
end;

procedure NXLSWriteTextFile(const AFileName, AText: string);
var
  lFile: TextFile;
begin
  AssignFile(lFile, AFileName);
  Rewrite(lFile);
  try
    Write(lFile, AText);
  finally
    CloseFile(lFile);
  end;
end;

procedure NXLSConfigureDiagnostics(AModel: TNXLSLSPModel; ARootPath: string;
  ACheckSyntax, APublishDiagnostics, AShowSyntaxErrors: Boolean;
  ACheckInactiveRegions: Boolean = False);
var
  lParams: TNXLSInitializeParams;
  lOptions: TJSONObject;
  lData: TJSONData;
begin
  lParams := TNXLSInitializeParams.Create;
  try
    lData := TJSONString.Create(ARootPath);
    try
      lParams.rootPath.FromJSONData(lData);
    finally
      lData.Free;
    end;

    lOptions := TJSONObject.Create;
    try
      lOptions.Add('checkSyntax', ACheckSyntax);
      lOptions.Add('publishDiagnostics', APublishDiagnostics);
      lOptions.Add('showSyntaxErrors', AShowSyntaxErrors);
      lOptions.Add('checkInactiveRegions', ACheckInactiveRegions);
      lParams.initializationOptions.FromJSONData(lOptions);
    finally
      lOptions.Free;
    end;

    AModel.BeginInitialize(lParams);
  finally
    lParams.Free;
  end;
end;

procedure NXLSOpenDocument(AModel: TNXLSLSPModel; const AFileName,
  AText: string);
var
  lParams: TNXLSDidOpenTextDocumentParams;
begin
  lParams := TNXLSDidOpenTextDocumentParams.Create;
  try
    lParams.textDocument.uri.Value := NXLSPathToFileURI(AFileName);
    lParams.textDocument.languageId.Value := 'pascal';
    lParams.textDocument.version.Value := 1;
    lParams.textDocument.text.Value := AText;
    AModel.Documents.DidOpen(lParams);
  finally
    lParams.Free;
  end;
end;

function NXLSLastNotification(AContext: TNXTestContext;
  ATransport: TNXLSTestTransport): TJSONObject;
var
  lPayload: string;
  lJSON: TJSONData;
begin
  Result := nil;
  lPayload := ATransport.LastPayload;
  AContext.AssertTrue(lPayload <> '', 'Transport should contain a notification payload.');
  lJSON := GetJSON(lPayload);
  if lJSON is TJSONObject then
    Result := TJSONObject(lJSON)
  else
    lJSON.Free;
end;

procedure TestDiagnosticsSettingsParse(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lRoot: string;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lModel := TNXLSLSPModel.Create;
  try
    NXLSConfigureDiagnostics(lModel, lRoot, True, True, True);

    AContext.AssertTrue(lModel.Settings.CheckSyntax,
      'checkSyntax should be read from initialization options.');
    AContext.AssertTrue(lModel.Settings.PublishDiagnostics,
      'publishDiagnostics should be read from initialization options.');
    AContext.AssertTrue(lModel.Settings.ShowSyntaxErrors,
      'showSyntaxErrors should be read from initialization options.');
  finally
    lModel.Free;
    RemoveDir(lRoot);
  end;
end;

procedure TestDiagnosticsDisabledDoesNotPublish(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  NXLSWriteTextFile(lFileName, cInvalidUnit);
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, False, True, False);
    NXLSOpenDocument(lModel, lFileName, cInvalidUnit);

    AContext.AssertEquals('', lTransport.LastPayload,
      'checkSyntax=false should suppress diagnostic publication.');
  finally
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestInvalidDocumentPublishesDiagnostic(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
  lNotification: TJSONObject;
  lParams: TJSONObject;
  lDiagnostics: TJSONArray;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  NXLSWriteTextFile(lFileName, cInvalidUnit);
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, True, True, False);
    NXLSOpenDocument(lModel, lFileName, cInvalidUnit);

    lNotification := NXLSLastNotification(AContext, lTransport);
    try
      AContext.AssertEquals('textDocument/publishDiagnostics',
        lNotification.Strings['method'], 'Diagnostics should use LSP publish notification.');
      lParams := lNotification.Objects['params'];
      AContext.AssertEquals(NXLSPathToFileURI(lFileName), lParams.Strings['uri'],
        'Diagnostics should be published for the opened document.');
      lDiagnostics := lParams.Arrays['diagnostics'];
      AContext.AssertTrue(lDiagnostics.Count > 0,
        'Invalid Pascal should produce at least one diagnostic.');
      AContext.AssertEquals('NexusPas',
        lDiagnostics.Objects[0].Strings['source'],
        'Parser diagnostics should identify NexusPas as the source.');
    finally
      lNotification.Free;
    end;
  finally
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestFixedDocumentClearsDiagnostics(AContext: TNXTestContext);
var
  lChange: TNXLSContentChange;
  lParams: TNXLSDidChangeTextDocumentParams;
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
  lNotification: TJSONObject;
  lDiagnostics: TJSONArray;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  NXLSWriteTextFile(lFileName, cInvalidUnit);
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  lParams := TNXLSDidChangeTextDocumentParams.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, True, True, False);
    NXLSOpenDocument(lModel, lFileName, cInvalidUnit);
    lTransport.Clear;

    lParams.textDocument.uri.Value := NXLSPathToFileURI(lFileName);
    lParams.textDocument.version.Value := 2;
    lChange := TNXLSContentChange(lParams.contentChanges.AddObject(TNXLSContentChange));
    lChange.text.Value := cValidUnit;
    lModel.Documents.DidChange(lParams);

    lNotification := NXLSLastNotification(AContext, lTransport);
    try
      lDiagnostics := lNotification.Objects['params'].Arrays['diagnostics'];
      AContext.AssertEquals(0, lDiagnostics.Count,
        'Fixed Pascal should publish an empty diagnostics array.');
    finally
      lNotification.Free;
    end;
  finally
    lParams.Free;
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestInactiveMalformedDoesNotPublishSyntaxDiagnostic(
  AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
  lNotification: TJSONObject;
  lDiagnostics: TJSONArray;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, True, True, False);
    NXLSOpenDocument(lModel, lFileName,
      'unit DiagnosticsUnit;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type' + LineEnding +
      '  TBroken = class' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.');

    lNotification := NXLSLastNotification(AContext, lTransport);
    try
      lDiagnostics := lNotification.Objects['params'].Arrays['diagnostics'];
      AContext.AssertEquals(0, lDiagnostics.Count,
        'Inactive malformed source should not publish active syntax diagnostics.');
    finally
      lNotification.Free;
    end;
  finally
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestMissingEndIfPublishesDirectiveDiagnostic(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
  lNotification: TJSONObject;
  lDiagnostics: TJSONArray;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, True, True, False);
    NXLSOpenDocument(lModel, lFileName,
      'unit DiagnosticsUnit;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type' + LineEnding +
      '  THidden = class end;' + LineEnding +
      'implementation' + LineEnding +
      'end.');

    lNotification := NXLSLastNotification(AContext, lTransport);
    try
      lDiagnostics := lNotification.Objects['params'].Arrays['diagnostics'];
      AContext.AssertTrue(lDiagnostics.Count > 0,
        'Missing ENDIF should publish a directive diagnostic.');
      AContext.AssertEquals('nxpas.directive.missingEndIf',
        lDiagnostics.Objects[0].Strings['code'],
        'Missing ENDIF diagnostic should preserve the stable code.');
    finally
      lNotification.Free;
    end;
  finally
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestValidDocumentClearsDiagnostics(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
  lNotification: TJSONObject;
  lDiagnostics: TJSONArray;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  NXLSWriteTextFile(lFileName, cValidUnit);
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, True, True, False);
    NXLSOpenDocument(lModel, lFileName, cValidUnit);

    lNotification := NXLSLastNotification(AContext, lTransport);
    try
      lDiagnostics := lNotification.Objects['params'].Arrays['diagnostics'];
      AContext.AssertEquals(0, lDiagnostics.Count,
        'Valid Pascal should publish an empty diagnostics array.');
    finally
      lNotification.Free;
    end;
  finally
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestUndefinedIfdefPublishesInactiveRegion(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
  lNotification: TJSONObject;
  lRegions: TJSONArray;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, True, False, False, True);
    NXLSOpenDocument(lModel, lFileName,
      'unit DiagnosticsUnit;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type THidden = class end;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.');

    lNotification := NXLSLastNotification(AContext, lTransport);
    try
      AContext.AssertEquals('pasls.inactiveRegions',
        lNotification.Strings['method'],
        'Inactive regions should use the inactive-region notification.');
      lRegions := lNotification.Objects['params'].Arrays['regions'];
      AContext.AssertEquals(1, lRegions.Count,
        'Undefined IFDEF branch should publish one inactive region.');
    finally
      lNotification.Free;
    end;
  finally
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestDefinedIfdefDoesNotPublishInactiveRegion(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
  lNotification: TJSONObject;
  lRegions: TJSONArray;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, True, False, False, True);
    NXLSOpenDocument(lModel, lFileName,
      '{$DEFINE KNOWN}' + LineEnding +
      'unit DiagnosticsUnit;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF KNOWN}' + LineEnding +
      'type TVisible = class end;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.');

    lNotification := NXLSLastNotification(AContext, lTransport);
    try
      lRegions := lNotification.Objects['params'].Arrays['regions'];
      AContext.AssertEquals(0, lRegions.Count,
        'Defined IFDEF branch should not publish inactive regions.');
    finally
      lNotification.Free;
    end;
  finally
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestElsePublishesInactiveBranchRegion(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lTransport: TNXLSTestTransport;
  lRoot: string;
  lFileName: string;
  lNotification: TJSONObject;
  lRegions: TJSONArray;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsdiag');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'DiagnosticsUnit.pas';
  lModel := TNXLSLSPModel.Create;
  lTransport := TNXLSTestTransport.Create;
  try
    lTransport.Open;
    lModel.Transport := lTransport;
    NXLSConfigureDiagnostics(lModel, lRoot, True, False, False, True);
    NXLSOpenDocument(lModel, lFileName,
      'unit DiagnosticsUnit;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type THidden = class end;' + LineEnding +
      '{$ELSE}' + LineEnding +
      'type TVisible = class end;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.');

    lNotification := NXLSLastNotification(AContext, lTransport);
    try
      lRegions := lNotification.Objects['params'].Arrays['regions'];
      AContext.AssertEquals(1, lRegions.Count,
        'ELSE should flip branch activity and publish the inactive branch.');
    finally
      lNotification.Free;
    end;
  finally
    lModel.Transport := nil;
    lTransport.Free;
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure RegisterNXLSDiagnosticsTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.Diagnostics');
  lSuite.AddTest('DiagnosticsSettingsParse', @TestDiagnosticsSettingsParse);
  lSuite.AddTest('DiagnosticsDisabledDoesNotPublish',
    @TestDiagnosticsDisabledDoesNotPublish);
  lSuite.AddTest('InvalidDocumentPublishesDiagnostic',
    @TestInvalidDocumentPublishesDiagnostic);
  lSuite.AddTest('ValidDocumentClearsDiagnostics',
    @TestValidDocumentClearsDiagnostics);
  lSuite.AddTest('FixedDocumentClearsDiagnostics',
    @TestFixedDocumentClearsDiagnostics);
  lSuite.AddTest('InactiveMalformedDoesNotPublishSyntaxDiagnostic',
    @TestInactiveMalformedDoesNotPublishSyntaxDiagnostic);
  lSuite.AddTest('MissingEndIfPublishesDirectiveDiagnostic',
    @TestMissingEndIfPublishesDirectiveDiagnostic);
  lSuite.AddTest('UndefinedIfdefPublishesInactiveRegion',
    @TestUndefinedIfdefPublishesInactiveRegion);
  lSuite.AddTest('DefinedIfdefDoesNotPublishInactiveRegion',
    @TestDefinedIfdefDoesNotPublishInactiveRegion);
  lSuite.AddTest('ElsePublishesInactiveBranchRegion',
    @TestElsePublishesInactiveBranchRegion);
end;

end.
