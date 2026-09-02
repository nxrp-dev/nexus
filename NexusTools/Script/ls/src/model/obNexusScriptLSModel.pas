unit obNexusScriptLSModel;

{$mode delphi}{$H+}

interface

uses
  Generics.Collections,
  obNXJSONRPCMessages,
  obNXLSTransport,
  obNXLSServer,
  obNexusScriptSession,
  obNexusScriptLSDocument;

type
  TNexusScriptCompilationSessionClass = class of TNexusScriptCompilationSession;

  TNexusScriptLSModel = class(TNXLSServerApplication)
  private
    FDocuments: TObjectList<TNexusScriptLSDocument>;
    FTransport: TNXLSTransport;
    FCompilationSessionClass: TNexusScriptCompilationSessionClass;
    FInitializeReceived: Boolean;
    FInitialized: Boolean;
    FShutdownRequested: Boolean;
    FExitRequested: Boolean;
    function FindDocumentIndex(const AURI: string): Integer;
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
    property CompilationSessionClass: TNexusScriptCompilationSessionClass
      read FCompilationSessionClass;
    property InitializeReceived: Boolean read FInitializeReceived;
    property Initialized: Boolean read FInitialized;
    property ShutdownRequested: Boolean read FShutdownRequested;
    property ExitRequested: Boolean read FExitRequested;
  end;

implementation

uses
  SysUtils;

var
  gCurrentModel: TNexusScriptLSModel;

constructor TNexusScriptLSModel.Create;
begin
  inherited Create;
  FDocuments := TObjectList<TNexusScriptLSDocument>.Create(True);
  FCompilationSessionClass := TNexusScriptCompilationSession;
end;

destructor TNexusScriptLSModel.Destroy;
begin
  if gCurrentModel = Self then
    gCurrentModel := nil;
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
    if SameText(FDocuments[lIndex].URI, AURI) then
      Exit(lIndex);
  Result := -1;
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
begin
  if FindDocumentIndex(AURI) >= 0 then
    raise Exception.Create('Document is already open: ' + AURI);
  FDocuments.Add(TNexusScriptLSDocument.Create(AURI, ALanguageID,
    AVersion, AText));
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
end;

procedure TNexusScriptLSModel.SaveDocument(const AURI: string);
begin
  if FindDocument(AURI) = nil then
    raise Exception.Create('Document is not open: ' + AURI);
end;

procedure TNexusScriptLSModel.CloseDocument(const AURI: string);
var
  lIndex: Integer;
begin
  lIndex := FindDocumentIndex(AURI);
  if lIndex < 0 then
    raise Exception.Create('Document is not open: ' + AURI);
  FDocuments.Delete(lIndex);
end;

function TNexusScriptLSModel.DocumentCount: Integer;
begin
  Result := FDocuments.Count;
end;

end.
