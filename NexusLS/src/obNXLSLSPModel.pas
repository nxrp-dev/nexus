unit obNXLSLSPModel;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  obNXJSONRPCMessages,
  obNXLSTransport,
  obNXLSOutboundDispatcher,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSServiceContext,
  obNXLSSettings,
  obNXLSLifecycleService,
  obNXLSDocumentService,
  obNXLSNavigationService,
  obNXLSCompletionService,
  obNXLSRefactoringService,
  obNXLSEditorService,
  obNXLSSymbolService,
  obNXLSWorkspaceService,
  obNXLSCommandService,
  obNXLSDiagnosticsService,
  obNXLSInactiveRegionService,
  obNXPasSearchPaths,
  obNXPasUnitResolver;

type
  TNXLSLSPModel = class(TNXLSLSPContext)
  private
    FDocumentsByURI: TObjectList;
    FTransport: TNXLSTransport;
    FInitializeReceived: Boolean;
    FInitialized: Boolean;
    FShutdownRequested: Boolean;
    FExitRequested: Boolean;
    FProjectDir: string;
    FExplicitLPIFile: string;
    FEffectiveFPCOptions: TStringList;
    FSettings: TNXLSSettings;
    FOutboundDispatcher: TNXLSOutboundDispatcher;
    FPascalSearchPaths: TNXPasSearchPathContext;
    FPascalUnitResolver: TNXPasSearchPathUnitResolver;

    FLifecycle: TNXLSLifecycleService;
    FDocuments: TNXLSDocumentService;
    FNavigation: TNXLSNavigationService;
    FCompletion: TNXLSCompletionService;
    FRefactoring: TNXLSRefactoringService;
    FEditor: TNXLSEditorService;
    FSymbols: TNXLSSymbolService;
    FWorkspace: TNXLSWorkspaceService;
    FCommands: TNXLSCommandService;
    FDiagnostics: TNXLSDiagnosticsService;
    FInactiveRegions: TNXLSInactiveRegionService;

    function FindDocumentIndex(const AURI: string): Integer;
    function DiscoverLPIFile(const ARootPath: string): string;
    function ExplicitLPIFileFromSettings: string;
    function RootPathFromInitializeParams(AParams: TNXLSInitializeParams): string;
    procedure ConfigurePascalSearchPaths;
    procedure ConfigureParserSettings(AParams: TNXLSInitializeParams);
  public
    constructor Create; virtual;
    destructor Destroy; override;

    class function Current: TNXLSLSPModel;
    class procedure SetCurrent(AModel: TNXLSLSPModel);

    procedure BeginInitialize(AParams: TNXLSInitializeParams); override;
    procedure MarkInitialized; override;
    procedure RequestShutdown; override;
    procedure RequestExit; override;

    function FindDocument(const AURI: string): TNXLSDocument; override;
    function RequireDocument(const AURI: string): TNXLSDocument; override;
    function OpenDocument(AItem: TNXLSTextDocumentItem): TNXLSDocument; override;
    procedure ChangeDocument(AIdentifier: TNXLSVersionedTextDocumentIdentifier; AChanges: TNXLSContentChangeArray); override;
    procedure SaveDocument(AParams: TNXLSDidSaveTextDocumentParams); override;
    procedure CloseDocument(AIdentifier: TNXLSTextDocumentIdentifier); override;
    function DocumentCount: Integer; override;
    function DocumentByIndex(AIndex: Integer): TNXLSDocument; override;

    function CheckSyntaxEnabled: Boolean; override;
    function PublishDiagnosticsEnabled: Boolean; override;
    function ShowSyntaxErrorsEnabled: Boolean; override;
    function EffectiveFPCOptionList: TStrings; override;
    procedure CheckDocument(ADocument: TNXLSDocument); override;
    procedure CheckInactiveRegions(ADocument: TNXLSDocument); override;
    procedure ReindexDocument(ADocument: TNXLSDocument); override;
    procedure AddWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray); override;
    procedure RemoveWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray); override;
    procedure RebuildWorkspaceIndex; override;
    function PascalSearchPathContext: TNXPasSearchPathContext; override;
    function PascalUnitResolver: TNXPasUnitResolver; override;
    procedure SendClientNotification(ANotification: TNXJSONRPCOutboundNotification); override;
    function SendClientRequest(ARequest: TNXJSONRPCOutboundCommand): Int64; override;
    function ReceiveClientResponse(AMessage: TNXJSONRPCMessage): Boolean; virtual;

    property InitializeReceived: Boolean read FInitializeReceived;
    property Initialized: Boolean read FInitialized;
    property ShutdownRequested: Boolean read FShutdownRequested;
    property ExitRequested: Boolean read FExitRequested;
    property ProjectDir: string read FProjectDir;
    property EffectiveFPCOptions: TStringList read FEffectiveFPCOptions;
    property Settings: TNXLSSettings read FSettings;
    property Transport: TNXLSTransport read FTransport write FTransport;

    property Lifecycle: TNXLSLifecycleService read FLifecycle;
    property Documents: TNXLSDocumentService read FDocuments;
    property Navigation: TNXLSNavigationService read FNavigation;
    property Completion: TNXLSCompletionService read FCompletion;
    property Refactoring: TNXLSRefactoringService read FRefactoring;
    property Editor: TNXLSEditorService read FEditor;
    property Symbols: TNXLSSymbolService read FSymbols;
    property Workspace: TNXLSWorkspaceService read FWorkspace;
    property Commands: TNXLSCommandService read FCommands;
    property Diagnostics: TNXLSDiagnosticsService read FDiagnostics;
    property InactiveRegions: TNXLSInactiveRegionService read FInactiveRegions;
  end;

implementation

uses
  SysUtils,
  obNXPasLPIProject;

var
  gCurrentLSPModel: TNXLSLSPModel;

constructor TNXLSLSPModel.Create;
begin
  inherited Create;
  FDocumentsByURI := TObjectList.Create(True);
  FSettings := TNXLSSettings.Create;
  FEffectiveFPCOptions := TStringList.Create;
  FPascalSearchPaths := TNXPasSearchPathContext.Create;
  FPascalUnitResolver := TNXPasSearchPathUnitResolver.Create(FPascalSearchPaths);
  FOutboundDispatcher := TNXLSOutboundDispatcher.Create;
  FLifecycle := TNXLSLifecycleService.Create(Self);
  FDocuments := TNXLSDocumentService.Create(Self);
  FNavigation := TNXLSNavigationService.Create(Self);
  FCompletion := TNXLSCompletionService.Create(Self);
  FRefactoring := TNXLSRefactoringService.Create(Self);
  FEditor := TNXLSEditorService.Create(Self);
  FSymbols := TNXLSSymbolService.Create(Self);
  FWorkspace := TNXLSWorkspaceService.Create(Self);
  FCommands := TNXLSCommandService.Create(Self);
  FDiagnostics := TNXLSDiagnosticsService.Create(Self);
  FInactiveRegions := TNXLSInactiveRegionService.Create(Self);
end;

destructor TNXLSLSPModel.Destroy;
begin
  FreeAndNil(FInactiveRegions);
  FreeAndNil(FDiagnostics);
  FreeAndNil(FCommands);
  FreeAndNil(FWorkspace);
  FreeAndNil(FSymbols);
  FreeAndNil(FEditor);
  FreeAndNil(FRefactoring);
  FreeAndNil(FCompletion);
  FreeAndNil(FNavigation);
  FreeAndNil(FDocuments);
  FreeAndNil(FLifecycle);
  FreeAndNil(FOutboundDispatcher);
  FreeAndNil(FPascalUnitResolver);
  FreeAndNil(FPascalSearchPaths);
  FreeAndNil(FEffectiveFPCOptions);
  FreeAndNil(FSettings);
  FreeAndNil(FDocumentsByURI);

  if gCurrentLSPModel = Self then
    gCurrentLSPModel := nil;

  inherited Destroy;
end;

procedure TNXLSLSPModel.BeginInitialize(AParams: TNXLSInitializeParams);
begin
  FInitializeReceived := True;
  FInitialized := False;
  FShutdownRequested := False;
  FExitRequested := False;
  ConfigureParserSettings(AParams);
  ConfigurePascalSearchPaths;
  FSymbols.SetWorkspaceFolders(AParams);
end;

function TNXLSLSPModel.DiscoverLPIFile(const ARootPath: string): string;
var
  lInfo: TSearchRec;
  lRoot: string;
begin
  Result := '';
  lRoot := IncludeTrailingPathDelimiter(ARootPath);
  if (ARootPath = '') or (not DirectoryExists(ARootPath)) then
    Exit;

  if FindFirst(lRoot + '*.lpi', faAnyFile, lInfo) <> 0 then
    Exit;
  try
    repeat
      if (lInfo.Attr and faDirectory) = 0 then
      begin
        Result := lRoot + lInfo.Name;
        Exit;
      end;
    until FindNext(lInfo) <> 0;
  finally
    FindClose(lInfo);
  end;
end;

function TNXLSLSPModel.ExplicitLPIFileFromSettings: string;
var
  lProgramFile: string;
begin
  Result := '';
  lProgramFile := Trim(FSettings.ProgramFile);
  if lProgramFile = '' then
    Exit;

  if (not SameText(ExtractFileExt(lProgramFile), '.lpi')) or
    (not FileExists(lProgramFile)) then
    Exit;

  Result := ExpandFileName(lProgramFile);
end;

function TNXLSLSPModel.RootPathFromInitializeParams(AParams: TNXLSInitializeParams): string;
begin
  Result := '';
  if AParams = nil then
    Exit;

  if (AParams.rootUri <> nil) and AParams.rootUri.Assigned then
    Result := NXLSFileURIToPath(AParams.rootUri.AsString);

  if (Result = '') and (AParams.rootPath <> nil) and AParams.rootPath.Assigned then
    Result := AParams.rootPath.AsString;

  if (Result <> '') and DirectoryExists(Result) then
    Result := IncludeTrailingPathDelimiter(ExpandFileName(Result))
  else
    Result := '';
end;

procedure TNXLSLSPModel.ConfigureParserSettings(AParams: TNXLSInitializeParams);
begin
  if AParams = nil then
    Exit;

  FSettings.LoadFromInitializationOptions(AParams.initializationOptions);
  FProjectDir := RootPathFromInitializeParams(AParams);
  FSettings.ExpandMacros(FProjectDir, GetTempDir(True));
  FExplicitLPIFile := ExplicitLPIFileFromSettings;
  if FExplicitLPIFile <> '' then
    FProjectDir := IncludeTrailingPathDelimiter(ExtractFileDir(FExplicitLPIFile))
  else if (FSettings.CWD <> '') and DirectoryExists(FSettings.CWD) then
    FProjectDir := IncludeTrailingPathDelimiter(ExpandFileName(FSettings.CWD));

  FEffectiveFPCOptions.Clear;
  FEffectiveFPCOptions.Assign(FSettings.FPCOptions);
end;

procedure TNXLSLSPModel.ConfigurePascalSearchPaths;
var
  lIdx: Integer;
  lLPI: TNXPasLPIProject;
  lLPIFile: string;
  lTemplateFileName: string;
  lTemplates: TNXPasSearchPathTemplateList;
begin
  FPascalSearchPaths.Clear;
  FPascalSearchPaths.WorkspaceDir := FProjectDir;
  FPascalSearchPaths.ProjectDir := FProjectDir;
  FPascalSearchPaths.LazarusDir := FSettings.LazarusDir;
  FPascalSearchPaths.FPCDir := FSettings.FPCDir;
  FPascalSearchPaths.Log.Add('lazarus dir: ' + FPascalSearchPaths.LazarusDir);
  FPascalSearchPaths.Log.Add('lazarus source dir: ' +
    FPascalSearchPaths.LazarusSrcDir);
  FPascalSearchPaths.Log.Add('fpc dir: ' + FPascalSearchPaths.FPCDir);
  FPascalSearchPaths.Log.Add('fpc source dir: ' +
    FPascalSearchPaths.FPCSrcDir);

  if FProjectDir <> '' then
    FPascalSearchPaths.AddRawPath(FProjectDir, 'workspaceRoot', pspkUnitPath);

  if FExplicitLPIFile <> '' then
    lLPIFile := FExplicitLPIFile
  else
    lLPIFile := DiscoverLPIFile(FProjectDir);
  if lLPIFile <> '' then
  begin
    lLPI := TNXPasLPIProject.Create;
    try
      if lLPI.LoadFromFile(lLPIFile) then
      begin
        FPascalSearchPaths.LPIFileName := lLPI.FileName;
        FPascalSearchPaths.ProjectDir := lLPI.ProjectDir;
        if lLPI.TargetCPU <> '' then
          FPascalSearchPaths.TargetCPU := lLPI.TargetCPU;
        if lLPI.TargetOS <> '' then
          FPascalSearchPaths.TargetOS := lLPI.TargetOS;

        FPascalSearchPaths.Log.Add('lpi: ' + lLPI.FileName);
        FPascalSearchPaths.AddRawPaths(lLPI.UnitPaths, 'lpi:OtherUnitFiles',
          pspkUnitPath, lLPI.ProjectDir);
        FPascalSearchPaths.AddRawPaths(lLPI.IncludePaths, 'lpi:IncludeFiles',
          pspkIncludePath, lLPI.ProjectDir);
        FPascalSearchPaths.AddRawPaths(lLPI.SourcePaths, 'lpi:SourcePath',
          pspkSourcePath, lLPI.ProjectDir);
        if lLPI.UnitOutputDirectory <> '' then
          FPascalSearchPaths.AddRawPath(lLPI.UnitOutputDirectory,
            'lpi:UnitOutputDirectory', pspkOutputPath, lLPI.ProjectDir);

        for lIdx := 0 to lLPI.ProjectFiles.Count - 1 do
          if ExtractFileDir(lLPI.ProjectFiles[lIdx]) <> '' then
            FPascalSearchPaths.AddRawPath(ExtractFileDir(lLPI.ProjectFiles[lIdx]),
              'lpi:ProjectUnit', pspkUnitPath, lLPI.ProjectDir);
      end;
    finally
      lLPI.Free;
    end;
  end
  else
    FPascalSearchPaths.Log.Add('lpi: none found');

  FPascalSearchPaths.AddFPCOptionPaths(FEffectiveFPCOptions);

  lTemplates := TNXPasSearchPathTemplateList.Create;
  try
    lTemplateFileName := TNXPasSearchPathTemplateStore.DefaultFileName;
    TNXPasSearchPathTemplateStore.LoadOrCreate(lTemplateFileName, lTemplates);
    FPascalSearchPaths.Log.Add('search path templates: ' + lTemplateFileName);
    FPascalSearchPaths.AddTemplates(lTemplates);
  finally
    lTemplates.Free;
  end;
end;

procedure TNXLSLSPModel.MarkInitialized;
begin
  FInitialized := True;
end;

procedure TNXLSLSPModel.RequestShutdown;
begin
  FShutdownRequested := True;
  FOutboundDispatcher.ClearPendingRequests;
end;

procedure TNXLSLSPModel.RequestExit;
begin
  FExitRequested := True;
  FOutboundDispatcher.ClearPendingRequests;
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
  else
    lDocument.SaveText(lDocument.Text);
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

function TNXLSLSPModel.DocumentCount: Integer;
begin
  Result := FDocumentsByURI.Count;
end;

function TNXLSLSPModel.DocumentByIndex(AIndex: Integer): TNXLSDocument;
begin
  Result := TNXLSDocument(FDocumentsByURI[AIndex]);
end;

function TNXLSLSPModel.CheckSyntaxEnabled: Boolean;
begin
  Result := FSettings.CheckSyntax;
end;

function TNXLSLSPModel.PublishDiagnosticsEnabled: Boolean;
begin
  Result := FSettings.PublishDiagnostics;
end;

function TNXLSLSPModel.ShowSyntaxErrorsEnabled: Boolean;
begin
  Result := FSettings.ShowSyntaxErrors;
end;

function TNXLSLSPModel.EffectiveFPCOptionList: TStrings;
begin
  Result := FEffectiveFPCOptions;
end;

procedure TNXLSLSPModel.CheckDocument(ADocument: TNXLSDocument);
begin
  FDiagnostics.CheckDocument(ADocument);
end;

procedure TNXLSLSPModel.CheckInactiveRegions(ADocument: TNXLSDocument);
begin
  if FSettings.CheckInactiveRegions then
    FInactiveRegions.CheckDocument(ADocument);
end;

procedure TNXLSLSPModel.ReindexDocument(ADocument: TNXLSDocument);
begin
  FSymbols.ReindexDocument(ADocument);
  FNavigation.ReindexDocument(ADocument);
  FCompletion.ReindexDocument(ADocument);
  FEditor.ReindexDocument(ADocument);
end;

procedure TNXLSLSPModel.AddWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
begin
  FSymbols.AddWorkspaceFolders(AFolders);
  ConfigurePascalSearchPaths;
end;

procedure TNXLSLSPModel.RemoveWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
begin
  FSymbols.RemoveWorkspaceFolders(AFolders);
  ConfigurePascalSearchPaths;
end;

procedure TNXLSLSPModel.RebuildWorkspaceIndex;
begin
  ConfigurePascalSearchPaths;
  FSymbols.RebuildWorkspaceIndex;
  FNavigation.RebuildWorkspaceIndex;
  FCompletion.RebuildWorkspaceIndex;
  FEditor.RebuildWorkspaceIndex;
end;

function TNXLSLSPModel.PascalSearchPathContext: TNXPasSearchPathContext;
begin
  Result := FPascalSearchPaths;
end;

function TNXLSLSPModel.PascalUnitResolver: TNXPasUnitResolver;
begin
  Result := FPascalUnitResolver;
end;

procedure TNXLSLSPModel.SendClientNotification(
  ANotification: TNXJSONRPCOutboundNotification);
begin
  FOutboundDispatcher.Transport := FTransport;
  FOutboundDispatcher.SendNotification(ANotification);
end;

function TNXLSLSPModel.SendClientRequest(ARequest: TNXJSONRPCOutboundCommand): Int64;
begin
  FOutboundDispatcher.Transport := FTransport;
  Result := FOutboundDispatcher.SendRequest(ARequest);
end;

function TNXLSLSPModel.ReceiveClientResponse(AMessage: TNXJSONRPCMessage): Boolean;
begin
  Result := FOutboundDispatcher.ReceiveResponse(AMessage);
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
