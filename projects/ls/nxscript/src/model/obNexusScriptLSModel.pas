unit obNexusScriptLSModel;

{$mode delphi}{$H+}

interface

uses
  Generics.Collections,
  obNXJSONRPCMessages,
  obNXLSTransport,
  obNXLSOutboundDispatcher,
  obNXLSServer,
  obNexusScriptModel,
  obNexusScriptSession,
  obNexusScriptAnalysis,
  obNexusScriptLSOverlay,
  obNexusScriptLSDocument;

type
  TNexusScriptLSAnalysisEntry = class
  private
    FURI: string;
    FAnalysis: TNexusScriptAnalysis;
  public
    constructor Create(const AURI: string; AAnalysis: TNexusScriptAnalysis);
    destructor Destroy; override;
    property URI: string read FURI;
    property Analysis: TNexusScriptAnalysis read FAnalysis;
  end;

  TNexusScriptLSModel = class(TNXLSServerApplication)
  private
    FDocuments: TObjectList<TNexusScriptLSDocument>;
    FAnalyses: TObjectList<TNexusScriptLSAnalysisEntry>;
    FSourceProvider: TNexusScriptLSOverlayProvider;
    FAnalysisRevision: Integer;
    FSelectedTargets: TNexusScriptTargetSelection;
    FDialectRoot: string;
    FTransport: TNXLSTransport;
    FOutboundDispatcher: TNXLSOutboundDispatcher;
    FInitializeReceived: Boolean;
    FInitialized: Boolean;
    FShutdownRequested: Boolean;
    FExitRequested: Boolean;
    function FindDocumentIndex(const AURI: string): Integer;
    function SourceNameForURI(const AURI: string): string;
    procedure Reanalyze;
    procedure PublishDiagnostics;
  public
    constructor Create;
    destructor Destroy; override;
    class function Current: TNexusScriptLSModel;
    class procedure SetCurrent(AModel: TNexusScriptLSModel);
    function ServerName: string; override;
    procedure AttachTransport(ATransport: TNXLSTransport); override;
    function ReceiveClientResponse(AMessage: TNXJSONRPCMessage): Boolean; override;
    procedure BeginInitialize;
    procedure MarkInitialized;
    procedure RequestShutdown;
    procedure RequestExit;
    procedure OpenDocument(const AURI, ALanguageID: string; AVersion: Integer;
      const AText: string);
    procedure ChangeDocument(const AURI: string; AVersion: Integer;
      const AText: string);
    procedure SaveDocument(const AURI: string);
    procedure CloseDocument(const AURI: string);
    function DocumentCount: Integer;
    function FindDocument(const AURI: string): TNexusScriptLSDocument;
    function FindAnalysis(const AURI: string): TNexusScriptAnalysis;
    function URIForSourceName(const ASourceName: string): string;
    function AnalysisCount: Integer;
    function Analyses(AIndex: Integer): TNexusScriptAnalysis;
    procedure SetTargets(ASelection: TNexusScriptTargetSelection);
    property DialectRoot: string read FDialectRoot write FDialectRoot;
    property SourceProvider: TNexusScriptLSOverlayProvider read FSourceProvider;
    property InitializeReceived: Boolean read FInitializeReceived;
    property Initialized: Boolean read FInitialized;
    property ShutdownRequested: Boolean read FShutdownRequested;
    property ExitRequested: Boolean read FExitRequested;
  end;

implementation

uses
  Classes,
  SysUtils,
  URIParser,
  tpNexusScript,
  obNexusScriptCompiler,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNexusScriptLSDiagnostics;

var
  gCurrentModel: TNexusScriptLSModel;

constructor TNexusScriptLSAnalysisEntry.Create(const AURI: string;
  AAnalysis: TNexusScriptAnalysis);
begin
  inherited Create;
  FURI := AURI;
  FAnalysis := AAnalysis;
end;

destructor TNexusScriptLSAnalysisEntry.Destroy;
begin
  FAnalysis.Free;
  inherited Destroy;
end;

constructor TNexusScriptLSModel.Create;
begin
  inherited Create;
  FDocuments := TObjectList<TNexusScriptLSDocument>.Create(True);
  FAnalyses := TObjectList<TNexusScriptLSAnalysisEntry>.Create(True);
  FSourceProvider := TNexusScriptLSOverlayProvider.Create;
  FOutboundDispatcher := TNXLSOutboundDispatcher.Create;
  FSelectedTargets := TNexusScriptTargetSelection.Create;
end;

destructor TNexusScriptLSModel.Destroy;
begin
  if gCurrentModel = Self then
    gCurrentModel := nil;
  FAnalyses.Free;
  FSourceProvider.Free;
  FOutboundDispatcher.Free;
  FSelectedTargets.Free;
  FDocuments.Free;
  inherited Destroy;
end;

class function TNexusScriptLSModel.Current: TNexusScriptLSModel;
begin
  if gCurrentModel = nil then
    raise Exception.Create('NexusScriptLS model is not installed.');
  Result := gCurrentModel;
end;

class procedure TNexusScriptLSModel.SetCurrent(AModel: TNexusScriptLSModel);
begin
  gCurrentModel := AModel;
end;

function TNexusScriptLSModel.ServerName: string;
begin
  Result := 'NexusScriptLS';
end;

procedure TNexusScriptLSModel.AttachTransport(ATransport: TNXLSTransport);
begin
  FTransport := ATransport;
  FOutboundDispatcher.Transport := ATransport;
end;

function TNexusScriptLSModel.ReceiveClientResponse(
  AMessage: TNXJSONRPCMessage): Boolean;
begin
  Result := False;
end;

procedure TNexusScriptLSModel.BeginInitialize;
begin
  FInitializeReceived := True;
end;

procedure TNexusScriptLSModel.MarkInitialized;
begin
  FInitialized := True;
end;

procedure TNexusScriptLSModel.RequestShutdown;
begin
  FShutdownRequested := True;
end;

procedure TNexusScriptLSModel.RequestExit;
begin
  FExitRequested := True;
end;

function TNexusScriptLSModel.FindDocumentIndex(const AURI: string): Integer;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FDocuments.Count - 1 do
    if FDocuments[lIndex].URI = AURI then
      Exit(lIndex);
  Result := -1;
end;

function TNexusScriptLSModel.SourceNameForURI(const AURI: string): string;
begin
  Result := '';
  if URIToFilename(AURI, Result) then
    Exit;
  if Pos('untitled:', AURI) = 1 then
    Result := AURI;
end;

procedure TNexusScriptLSModel.Reanalyze;
var
  lDocument: TNexusScriptLSDocument;
  lSourceName: string;
  lAnalysis: TNexusScriptAnalysis;
begin
  Inc(FAnalysisRevision);
  FAnalyses.Clear;
  for lDocument in FDocuments do
  begin
    lSourceName := lDocument.SourceName;
    lAnalysis := TNexusScriptAnalysis.Create(lSourceName,
      FAnalysisRevision, FSourceProvider, FSelectedTargets);
    lAnalysis.Execute(FDialectRoot);
    FAnalyses.Add(TNexusScriptLSAnalysisEntry.Create(lDocument.URI,
      lAnalysis));
  end;
  PublishDiagnostics;
end;

procedure TNexusScriptLSModel.SetTargets(
  ASelection: TNexusScriptTargetSelection);
begin
  FSelectedTargets.Assign(ASelection);
  Reanalyze;
end;

procedure SetProtocolRange(ADestination: TNXLSRange;
  const ASource: TNexusScriptRange);
begin
  ADestination.start.line.Value := ASource.StartPosition.Line - 1;
  ADestination.start.character.Value := ASource.StartPosition.Column - 1;
  ADestination.&end.line.Value := ASource.EndPosition.Line - 1;
  ADestination.&end.character.Value := ASource.EndPosition.Column;
  ADestination.Assigned := True;
end;

procedure AddProtocolDiagnostic(AParams: TNXLSPublishDiagnosticsParams;
  ASeen: TStringList; const ACode, AMessageText: string;
  const ARange: TNexusScriptRange);
var
  lDiagnostic: TNXLSDiagnostic;
  lKey: string;
begin
  lKey := ACode + #0 + AMessageText + #0 + IntToStr(ARange.StartPosition.Line) +
    ':' + IntToStr(ARange.StartPosition.Column) + ':' +
    IntToStr(ARange.EndPosition.Line) + ':' +
    IntToStr(ARange.EndPosition.Column);
  if ASeen.IndexOf(lKey) >= 0 then
    Exit;
  ASeen.Add(lKey);
  lDiagnostic := TNXLSDiagnostic(AParams.diagnostics.AddObject(
    TNXLSDiagnostic));
  SetProtocolRange(lDiagnostic.range, ARange);
  lDiagnostic.severity.Value := 1;
  lDiagnostic.source.Value := 'NexusScript';
  lDiagnostic.code.StringValue := ACode;
  lDiagnostic.message.Value := AMessageText;
end;

procedure TNexusScriptLSModel.PublishDiagnostics;
var
  lDocument: TNexusScriptLSDocument;
  lEntry: TNexusScriptLSAnalysisEntry;
  lCompilerIndex: Integer;
  lDiagnosticIndex: Integer;
  lCompiler: TNexusScriptCompiler;
  lSourceName: string;
  lParams: TNXLSPublishDiagnosticsParams;
  lNotification: TNexusScriptLSPublishDiagnostics;
  lSeen: TStringList;
begin
  if FTransport = nil then
    Exit;
  for lDocument in FDocuments do
  begin
    lSourceName := lDocument.SourceName;
    lParams := TNXLSPublishDiagnosticsParams.Create;
    lParams.uri.Value := lDocument.URI;
    lParams.version.Value := lDocument.Version;
    lParams.diagnostics.Assigned := True;
    lSeen := TStringList.Create;
    try
      lSeen.Sorted := True;
      lSeen.Duplicates := dupIgnore;
      for lEntry in FAnalyses do
      begin
      for lCompilerIndex := 0 to
        lEntry.Analysis.Session.AttemptedCompilerCount - 1 do
      begin
        lCompiler := lEntry.Analysis.Session.AttemptedCompilers[lCompilerIndex];
        if (lCompiler.SourceDocument = nil) or
          not FSourceProvider.SameIdentity(lCompiler.SourceDocument.SourceName,
          lSourceName) then
          Continue;
        for lDiagnosticIndex := 0 to lCompiler.Diagnostics.Count - 1 do
          AddProtocolDiagnostic(lParams, lSeen,
            lCompiler.Diagnostics[lDiagnosticIndex].Code,
            lCompiler.Diagnostics[lDiagnosticIndex].MessageText,
            lCompiler.Diagnostics[lDiagnosticIndex].SourceRange);
      end;
      for lDiagnosticIndex := 0 to
        lEntry.Analysis.Language.DiagnosticCount - 1 do
        if FSourceProvider.SameIdentity(
          lEntry.Analysis.Language.Diagnostics[lDiagnosticIndex].SourceRange.SourceName,
          lSourceName) then
          AddProtocolDiagnostic(lParams, lSeen,
            lEntry.Analysis.Language.Diagnostics[lDiagnosticIndex].Code,
            lEntry.Analysis.Language.Diagnostics[lDiagnosticIndex].MessageText,
            lEntry.Analysis.Language.Diagnostics[lDiagnosticIndex].SourceRange);
      for lDiagnosticIndex := 0 to
        lEntry.Analysis.Validator.Diagnostics.Count - 1 do
        if FSourceProvider.SameIdentity(
          lEntry.Analysis.Validator.Diagnostics[lDiagnosticIndex].SourceRange.SourceName,
          lSourceName) then
          AddProtocolDiagnostic(lParams, lSeen,
            lEntry.Analysis.Validator.Diagnostics[lDiagnosticIndex].Code,
            lEntry.Analysis.Validator.Diagnostics[lDiagnosticIndex].MessageText,
            lEntry.Analysis.Validator.Diagnostics[lDiagnosticIndex].SourceRange);
        for lDiagnosticIndex := 0 to
          lEntry.Analysis.Session.Diagnostics.Count - 1 do
          if FSourceProvider.SameIdentity(
            lEntry.Analysis.Session.Diagnostics[lDiagnosticIndex].SourceRange.SourceName,
            lSourceName) then
            AddProtocolDiagnostic(lParams, lSeen,
              lEntry.Analysis.Session.Diagnostics[lDiagnosticIndex].Code,
              lEntry.Analysis.Session.Diagnostics[lDiagnosticIndex].MessageText,
              lEntry.Analysis.Session.Diagnostics[lDiagnosticIndex].SourceRange);
      end;
    finally
      lSeen.Free;
    end;
    lNotification := TNexusScriptLSPublishDiagnostics.Create;
    lNotification.params := lParams;
    FOutboundDispatcher.SendNotification(lNotification);
  end;
end;

function TNexusScriptLSModel.FindAnalysis(
  const AURI: string): TNexusScriptAnalysis;
var
  lEntry: TNexusScriptLSAnalysisEntry;
begin
  Result := nil;
  for lEntry in FAnalyses do
    if lEntry.URI = AURI then
      Exit(lEntry.Analysis);
end;

function TNexusScriptLSModel.URIForSourceName(
  const ASourceName: string): string;
var
  lDocument: TNexusScriptLSDocument;
begin
  for lDocument in FDocuments do
    if FSourceProvider.SameIdentity(lDocument.SourceName, ASourceName) then
      Exit(lDocument.URI);
  Result := FilenameToURI(ASourceName);
end;

function TNexusScriptLSModel.AnalysisCount: Integer;
begin
  Result := FAnalyses.Count;
end;

function TNexusScriptLSModel.Analyses(AIndex: Integer): TNexusScriptAnalysis;
begin
  Result := FAnalyses[AIndex].Analysis;
end;

function TNexusScriptLSModel.FindDocument(
  const AURI: string): TNexusScriptLSDocument;
var
  lIndex: Integer;
begin
  lIndex := FindDocumentIndex(AURI);
  if lIndex < 0 then
    Result := nil
  else
    Result := FDocuments[lIndex];
end;

procedure TNexusScriptLSModel.OpenDocument(const AURI, ALanguageID: string;
  AVersion: Integer; const AText: string);
var
  lSourceName: string;
begin
  if FindDocumentIndex(AURI) >= 0 then
    raise Exception.Create('Document is already open: ' + AURI);
  lSourceName := SourceNameForURI(AURI);
  FDocuments.Add(TNexusScriptLSDocument.Create(AURI, lSourceName,
    ALanguageID, AVersion, AText));
  if lSourceName <> '' then
    FSourceProvider.Put(lSourceName, AText, AVersion);
  Reanalyze;
end;

procedure TNexusScriptLSModel.ChangeDocument(const AURI: string;
  AVersion: Integer; const AText: string);
var
  lDocument: TNexusScriptLSDocument;
begin
  lDocument := FindDocument(AURI);
  if lDocument = nil then
    raise Exception.Create('Document is not open: ' + AURI);
  lDocument.Version := AVersion;
  lDocument.Text := AText;
  if lDocument.SourceName <> '' then
    FSourceProvider.Put(lDocument.SourceName, AText, AVersion);
  Reanalyze;
end;

procedure TNexusScriptLSModel.SaveDocument(const AURI: string);
begin
  if FindDocument(AURI) = nil then
    raise Exception.Create('Document is not open: ' + AURI);
  Reanalyze;
end;

procedure TNexusScriptLSModel.CloseDocument(const AURI: string);
var
  lIndex: Integer;
begin
  lIndex := FindDocumentIndex(AURI);
  if lIndex < 0 then
    raise Exception.Create('Document is not open: ' + AURI);
  if FDocuments[lIndex].SourceName <> '' then
    FSourceProvider.Remove(FDocuments[lIndex].SourceName);
  FDocuments.Delete(lIndex);
  Reanalyze;
end;

function TNexusScriptLSModel.DocumentCount: Integer;
begin
  Result := FDocuments.Count;
end;

end.
