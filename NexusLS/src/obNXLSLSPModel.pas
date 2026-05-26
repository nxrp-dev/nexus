unit obNXLSLSPModel;

{$mode objfpc}{$H+}

interface

uses
  Contnrs,
  CodeCache,
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams;

type
  TNXLSLSPModel = class;

  TNXLSDocument = class
  private
    FURI: string;
    FLocalPath: string;
    FLanguageID: string;
    FVersion: Int64;
    FText: string;
    FOpen: Boolean;
    FCodeBuffer: TCodeBuffer;
  public
    procedure OpenFrom(AItem: TNXLSTextDocumentItem);
    procedure ApplyFullChange(AVersion: Int64; const AText: string);
    procedure SaveText(const AText: string);
    procedure Close;

    property URI: string read FURI;
    property LocalPath: string read FLocalPath;
    property LanguageID: string read FLanguageID;
    property Version: Int64 read FVersion;
    property Text: string read FText;
    property Open: Boolean read FOpen;
    property CodeBuffer: TCodeBuffer read FCodeBuffer;
  end;

  TNXLSLSPService = class
  protected
    FModel: TNXLSLSPModel;
  public
    constructor Create(AModel: TNXLSLSPModel); virtual;
    property Model: TNXLSLSPModel read FModel;
  end;

  TNXLSLifecycleService = class(TNXLSLSPService)
  public
    function Initialize(AParams: TNXLSInitializeParams): TNXJSONValue; virtual;
    procedure Initialized(AParams: TNXLSInitializedParams); virtual;
    function Shutdown: TNXJSONValue; virtual;
    procedure ExitServer; virtual;
    procedure CancelRequest(AParams: TNXLSCancelParams); virtual;
  end;

  TNXLSDocumentService = class(TNXLSLSPService)
  public
    procedure DidOpen(AParams: TNXLSDidOpenTextDocumentParams); virtual;
    procedure DidChange(AParams: TNXLSDidChangeTextDocumentParams); virtual;
    procedure DidSave(AParams: TNXLSDidSaveTextDocumentParams); virtual;
    procedure DidClose(AParams: TNXLSDidCloseTextDocumentParams); virtual;
  end;

  TNXLSNavigationService = class(TNXLSLSPService)
  public
    function Declaration(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function Definition(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function ImplementationLocation(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function References(AParams: TNXLSReferenceParams): TNXJSONValue; virtual;
  end;

  TNXLSCompletionService = class(TNXLSLSPService)
  public
    function Completion(AParams: TNXLSCompletionParams): TNXJSONValue; virtual;
    function SignatureHelp(AParams: TNXLSSignatureHelpParams): TNXJSONValue; virtual;
  end;

  TNXLSRefactoringService = class(TNXLSLSPService)
  public
    function Rename(AParams: TNXLSRenameParams): TNXJSONValue; virtual;
    function PrepareRename(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
  end;

  TNXLSEditorService = class(TNXLSLSPService)
  public
    function CodeAction(AParams: TNXLSCodeActionParams): TNXJSONValue; virtual;
    function DocumentHighlight(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function Hover(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function InlayHint(AParams: TNXLSInlayHintParams): TNXJSONValue; virtual;
  end;

  TNXLSSymbolService = class(TNXLSLSPService)
  public
    function DocumentSymbol(AParams: TNXLSDocumentSymbolParams): TNXJSONValue; virtual;
    function WorkspaceSymbol(AParams: TNXLSWorkspaceSymbolParams): TNXJSONValue; virtual;
  end;

  TNXLSWorkspaceService = class(TNXLSLSPService)
  public
    procedure DidChangeConfiguration(AParams: TNXLSDidChangeConfigurationParams); virtual;
    procedure DidChangeWorkspaceFolders(AParams: TNXLSDidChangeWorkspaceFoldersParams); virtual;
  end;

  TNXLSCommandService = class(TNXLSLSPService)
  public
    function ExecuteCommand(AParams: TNXLSExecuteCommandParams): TNXJSONValue; virtual;
  end;

  TNXLSLSPModel = class
  private
    FDocumentsByURI: TObjectList;
    FInitializeReceived: Boolean;
    FInitialized: Boolean;
    FShutdownRequested: Boolean;
    FExitRequested: Boolean;

    FLifecycle: TNXLSLifecycleService;
    FDocuments: TNXLSDocumentService;
    FNavigation: TNXLSNavigationService;
    FCompletion: TNXLSCompletionService;
    FRefactoring: TNXLSRefactoringService;
    FEditor: TNXLSEditorService;
    FSymbols: TNXLSSymbolService;
    FWorkspace: TNXLSWorkspaceService;
    FCommands: TNXLSCommandService;

    function FindDocumentIndex(const AURI: string): Integer;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    class function Current: TNXLSLSPModel;
    class procedure SetCurrent(AModel: TNXLSLSPModel);

    function FindDocument(const AURI: string): TNXLSDocument;
    function RequireDocument(const AURI: string): TNXLSDocument;
    function OpenDocument(AItem: TNXLSTextDocumentItem): TNXLSDocument;
    procedure ChangeDocument(AIdentifier: TNXLSVersionedTextDocumentIdentifier; AChanges: TNXLSContentChangeArray);
    procedure SaveDocument(AParams: TNXLSDidSaveTextDocumentParams);
    procedure CloseDocument(AIdentifier: TNXLSTextDocumentIdentifier);

    property InitializeReceived: Boolean read FInitializeReceived;
    property Initialized: Boolean read FInitialized;
    property ShutdownRequested: Boolean read FShutdownRequested;
    property ExitRequested: Boolean read FExitRequested;

    property Lifecycle: TNXLSLifecycleService read FLifecycle;
    property Documents: TNXLSDocumentService read FDocuments;
    property Navigation: TNXLSNavigationService read FNavigation;
    property Completion: TNXLSCompletionService read FCompletion;
    property Refactoring: TNXLSRefactoringService read FRefactoring;
    property Editor: TNXLSEditorService read FEditor;
    property Symbols: TNXLSSymbolService read FSymbols;
    property Workspace: TNXLSWorkspaceService read FWorkspace;
    property Commands: TNXLSCommandService read FCommands;
  end;

implementation

uses
  SysUtils,
  CodeToolManager,
  obNXLSProtocolObjects;

var
  gCurrentLSPModel: TNXLSLSPModel;

function NXLSHexValue(AChar: Char): Integer;
begin
  case AChar of
    '0'..'9': Result := Ord(AChar) - Ord('0');
    'A'..'F': Result := Ord(AChar) - Ord('A') + 10;
    'a'..'f': Result := Ord(AChar) - Ord('a') + 10;
  else
    Result := -1;
  end;
end;

function NXLSDecodeURIPath(const AValue: string): string;
var
  lIdx: Integer;
  lHi: Integer;
  lLo: Integer;
begin
  Result := '';
  lIdx := 1;
  while lIdx <= Length(AValue) do
  begin
    if (AValue[lIdx] = '%') and (lIdx + 2 <= Length(AValue)) then
    begin
      lHi := NXLSHexValue(AValue[lIdx + 1]);
      lLo := NXLSHexValue(AValue[lIdx + 2]);
      if (lHi >= 0) and (lLo >= 0) then
      begin
        Result := Result + Chr((lHi shl 4) + lLo);
        Inc(lIdx, 3);
        Continue;
      end;
    end;

    Result := Result + AValue[lIdx];
    Inc(lIdx);
  end;
end;

function NXLSFileURIToPath(const AURI: string): string;
var
  lRest: string;
  lAuthority: string;
  lPath: string;
  lSlashPos: Integer;
begin
  if Copy(AURI, 1, 7) <> 'file://' then
    raise Exception.CreateFmt('Only file URIs are supported for text documents: %s', [AURI]);

  lRest := Copy(AURI, 8, MaxInt);
  lAuthority := '';
  lPath := lRest;

  if (lRest <> '') and (lRest[1] <> '/') then
  begin
    lSlashPos := Pos('/', lRest);
    if lSlashPos = 0 then
    begin
      lAuthority := lRest;
      lPath := '';
    end
    else
    begin
      lAuthority := Copy(lRest, 1, lSlashPos - 1);
      lPath := Copy(lRest, lSlashPos, MaxInt);
    end;
  end;

  lPath := NXLSDecodeURIPath(lPath);

  if (lAuthority <> '') and (not SameText(lAuthority, 'localhost')) then
    Result := '\\' + NXLSDecodeURIPath(lAuthority) + lPath
  else
  begin
    Result := lPath;
    if (Length(Result) >= 3) and (Result[1] = '/') and (Result[3] = ':') then
      Delete(Result, 1, 1);
  end;

  Result := StringReplace(Result, '/', DirectorySeparator, [rfReplaceAll]);
end;

function NXLSLoadCodeBuffer(const ALocalPath: string): TCodeBuffer;
begin
  if ALocalPath = '' then
    raise Exception.Create('Document local path is required.');

  Result := CodeToolBoss.FindFile(ALocalPath);
  if Result = nil then
    Result := CodeToolBoss.LoadFile(ALocalPath, False, False);
  if Result = nil then
    Result := CodeToolBoss.CreateFile(ALocalPath);
  if Result = nil then
    raise Exception.CreateFmt('Unable to create CodeTools buffer for %s', [ALocalPath]);
end;

constructor TNXLSLSPService.Create(AModel: TNXLSLSPModel);
begin
  inherited Create;
  FModel := AModel;
end;

procedure TNXLSDocument.OpenFrom(AItem: TNXLSTextDocumentItem);
begin
  if AItem = nil then
    raise Exception.Create('Text document item is required.');

  FURI := AItem.uri.Value;
  FLocalPath := NXLSFileURIToPath(FURI);
  FLanguageID := AItem.languageId.Value;
  FVersion := AItem.version.Value;
  FText := AItem.text.Value;
  FCodeBuffer := NXLSLoadCodeBuffer(FLocalPath);
  FCodeBuffer.Source := FText;
  FOpen := True;
end;

procedure TNXLSDocument.ApplyFullChange(AVersion: Int64; const AText: string);
begin
  FVersion := AVersion;
  FText := AText;
  if FCodeBuffer = nil then
    FCodeBuffer := NXLSLoadCodeBuffer(FLocalPath);
  FCodeBuffer.Source := FText;
  FOpen := True;
end;

procedure TNXLSDocument.SaveText(const AText: string);
begin
  FText := AText;
  if FCodeBuffer = nil then
    FCodeBuffer := NXLSLoadCodeBuffer(FLocalPath);
  FCodeBuffer.Source := FText;
end;

procedure TNXLSDocument.Close;
begin
  FOpen := False;
end;

function TNXLSLifecycleService.Initialize(AParams: TNXLSInitializeParams): TNXJSONValue;
begin
  Model.FInitializeReceived := True;
  Model.FInitialized := False;
  Model.FShutdownRequested := False;
  Model.FExitRequested := False;
  Result := TNXLSInitializeResult.CreateValue;
end;

procedure TNXLSLifecycleService.Initialized(AParams: TNXLSInitializedParams);
begin
  Model.FInitialized := True;
end;

function TNXLSLifecycleService.Shutdown: TNXJSONValue;
begin
  Model.FShutdownRequested := True;
  Result := TNXLSNullResult.CreateValue;
end;

procedure TNXLSLifecycleService.ExitServer;
begin
  Model.FExitRequested := True;
end;

procedure TNXLSLifecycleService.CancelRequest(AParams: TNXLSCancelParams);
begin
end;

procedure TNXLSDocumentService.DidOpen(AParams: TNXLSDidOpenTextDocumentParams);
begin
  if AParams = nil then
    raise Exception.Create('didOpen params are required.');

  Model.OpenDocument(AParams.textDocument);
end;

procedure TNXLSDocumentService.DidChange(AParams: TNXLSDidChangeTextDocumentParams);
begin
  if AParams = nil then
    raise Exception.Create('didChange params are required.');

  Model.ChangeDocument(AParams.textDocument, AParams.contentChanges);
end;

procedure TNXLSDocumentService.DidSave(AParams: TNXLSDidSaveTextDocumentParams);
begin
  if AParams = nil then
    raise Exception.Create('didSave params are required.');

  Model.SaveDocument(AParams);
end;

procedure TNXLSDocumentService.DidClose(AParams: TNXLSDidCloseTextDocumentParams);
begin
  if AParams = nil then
    raise Exception.Create('didClose params are required.');

  Model.CloseDocument(AParams.textDocument);
end;

function TNXLSNavigationService.Declaration(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSLocationResult.CreateValue;
end;

function TNXLSNavigationService.Definition(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSLocationResult.CreateValue;
end;

function TNXLSNavigationService.ImplementationLocation(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSLocationResult.CreateValue;
end;

function TNXLSNavigationService.References(AParams: TNXLSReferenceParams): TNXJSONValue;
begin
  Result := TNXLSLocationArrayResult.CreateValue;
end;

function TNXLSCompletionService.Completion(AParams: TNXLSCompletionParams): TNXJSONValue;
begin
  Result := TNXLSCompletionResult.CreateValue;
end;

function TNXLSCompletionService.SignatureHelp(AParams: TNXLSSignatureHelpParams): TNXJSONValue;
begin
  Result := TNXLSSignatureHelpResult.CreateValue;
end;

function TNXLSRefactoringService.Rename(AParams: TNXLSRenameParams): TNXJSONValue;
begin
  Result := TNXLSWorkspaceEditResult.CreateValue;
end;

function TNXLSRefactoringService.PrepareRename(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSPrepareRenameResult.CreateValue;
end;

function TNXLSEditorService.CodeAction(AParams: TNXLSCodeActionParams): TNXJSONValue;
begin
  Result := TNXLSCodeActionArrayResult.CreateValue;
end;

function TNXLSEditorService.DocumentHighlight(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSDocumentHighlightArrayResult.CreateValue;
end;

function TNXLSEditorService.Hover(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSHoverResult.CreateValue;
end;

function TNXLSEditorService.InlayHint(AParams: TNXLSInlayHintParams): TNXJSONValue;
begin
  Result := TNXLSInlayHintArrayResult.CreateValue;
end;

function TNXLSSymbolService.DocumentSymbol(AParams: TNXLSDocumentSymbolParams): TNXJSONValue;
begin
  Result := TNXLSDocumentSymbolArrayResult.CreateValue;
end;

function TNXLSSymbolService.WorkspaceSymbol(AParams: TNXLSWorkspaceSymbolParams): TNXJSONValue;
begin
  Result := TNXLSWorkspaceSymbolArrayResult.CreateValue;
end;

procedure TNXLSWorkspaceService.DidChangeConfiguration(AParams: TNXLSDidChangeConfigurationParams);
begin
end;

procedure TNXLSWorkspaceService.DidChangeWorkspaceFolders(AParams: TNXLSDidChangeWorkspaceFoldersParams);
begin
end;

function TNXLSCommandService.ExecuteCommand(AParams: TNXLSExecuteCommandParams): TNXJSONValue;
begin
  Result := TNXLSCommandResult.CreateValue;
end;

constructor TNXLSLSPModel.Create;
begin
  inherited Create;
  FDocumentsByURI := TObjectList.Create(True);
  FLifecycle := TNXLSLifecycleService.Create(Self);
  FDocuments := TNXLSDocumentService.Create(Self);
  FNavigation := TNXLSNavigationService.Create(Self);
  FCompletion := TNXLSCompletionService.Create(Self);
  FRefactoring := TNXLSRefactoringService.Create(Self);
  FEditor := TNXLSEditorService.Create(Self);
  FSymbols := TNXLSSymbolService.Create(Self);
  FWorkspace := TNXLSWorkspaceService.Create(Self);
  FCommands := TNXLSCommandService.Create(Self);
end;

destructor TNXLSLSPModel.Destroy;
begin
  FreeAndNil(FCommands);
  FreeAndNil(FWorkspace);
  FreeAndNil(FSymbols);
  FreeAndNil(FEditor);
  FreeAndNil(FRefactoring);
  FreeAndNil(FCompletion);
  FreeAndNil(FNavigation);
  FreeAndNil(FDocuments);
  FreeAndNil(FLifecycle);
  FreeAndNil(FDocumentsByURI);

  if gCurrentLSPModel = Self then
    gCurrentLSPModel := nil;

  inherited Destroy;
end;

function TNXLSLSPModel.FindDocumentIndex(const AURI: string): Integer;
var
  lIdx: Integer;
begin
  for lIdx := 0 to FDocumentsByURI.Count - 1 do
    if SameText(TNXLSDocument(FDocumentsByURI[lIdx]).URI, AURI) then
      Exit(lIdx);

  Result := -1;
end;

function TNXLSLSPModel.FindDocument(const AURI: string): TNXLSDocument;
var
  lIdx: Integer;
begin
  lIdx := FindDocumentIndex(AURI);
  if lIdx < 0 then
    Result := nil
  else
    Result := TNXLSDocument(FDocumentsByURI[lIdx]);
end;

function TNXLSLSPModel.RequireDocument(const AURI: string): TNXLSDocument;
begin
  Result := FindDocument(AURI);
  if Result = nil then
    raise Exception.CreateFmt('Document is not open: %s', [AURI]);
end;

function TNXLSLSPModel.OpenDocument(AItem: TNXLSTextDocumentItem): TNXLSDocument;
begin
  if AItem = nil then
    raise Exception.Create('Text document item is required.');

  Result := FindDocument(AItem.uri.Value);
  if Result = nil then
  begin
    Result := TNXLSDocument.Create;
    FDocumentsByURI.Add(Result);
  end;

  Result.OpenFrom(AItem);
end;

procedure TNXLSLSPModel.ChangeDocument(AIdentifier: TNXLSVersionedTextDocumentIdentifier; AChanges: TNXLSContentChangeArray);
var
  lDocument: TNXLSDocument;
  lIdx: Integer;
  lChange: TNXLSContentChange;
begin
  if AIdentifier = nil then
    raise Exception.Create('Versioned text document identifier is required.');

  if AChanges = nil then
    raise Exception.Create('Document change list is required.');

  lDocument := RequireDocument(AIdentifier.uri.Value);

  for lIdx := 0 to AChanges.Count - 1 do
  begin
    lChange := TNXLSContentChange(AChanges[lIdx]);
    if (lChange.range <> nil) and lChange.range.Assigned then
      raise Exception.Create('Incremental document changes are not supported while sync kind is Full.');

    lDocument.ApplyFullChange(AIdentifier.version.Value, lChange.text.Value);
  end;
end;

procedure TNXLSLSPModel.SaveDocument(AParams: TNXLSDidSaveTextDocumentParams);
var
  lDocument: TNXLSDocument;
begin
  if AParams = nil then
    raise Exception.Create('Save params are required.');

  if AParams.textDocument = nil then
    raise Exception.Create('Text document identifier is required.');

  lDocument := RequireDocument(AParams.textDocument.uri.Value);
  if (AParams.text <> nil) and AParams.text.Assigned then
    lDocument.SaveText(AParams.text.Value)
  else if lDocument.CodeBuffer = nil then
    lDocument.FCodeBuffer := NXLSLoadCodeBuffer(lDocument.LocalPath);
end;

procedure TNXLSLSPModel.CloseDocument(AIdentifier: TNXLSTextDocumentIdentifier);
var
  lDocument: TNXLSDocument;
begin
  if AIdentifier = nil then
    raise Exception.Create('Text document identifier is required.');

  lDocument := RequireDocument(AIdentifier.uri.Value);
  lDocument.Close;
end;

class function TNXLSLSPModel.Current: TNXLSLSPModel;
begin
  if gCurrentLSPModel = nil then
    gCurrentLSPModel := TNXLSLSPModel.Create;

  Result := gCurrentLSPModel;
end;

class procedure TNXLSLSPModel.SetCurrent(AModel: TNXLSLSPModel);
begin
  gCurrentLSPModel := AModel;
end;

finalization
  FreeAndNil(gCurrentLSPModel);

end.
