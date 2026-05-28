unit obNXLSLSPModel;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  fpjson,
  CodeToolsConfig,
  obNXLSTransport,
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
  obNXLSDiagnosticsService;

type
  TNXLSLSPModel = class(TNXLSLSPContext)
  private
    FDocumentsByURI: TObjectList;
    FTransport: TNXLSTransport;
    FInitializeReceived: Boolean;
    FInitialized: Boolean;
    FShutdownRequested: Boolean;
    FExitRequested: Boolean;
    FCodeToolsInitialized: Boolean;
    FProjectDir: string;
    FEffectiveFPCOptions: TStringList;
    FEffectiveWorkspacePaths: TStringList;
    FSettings: TNXLSSettings;

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

    function FindDocumentIndex(const AURI: string): Integer;
    function RootPathFromInitializeParams(AParams: TNXLSInitializeParams): string;
    function IsWorkspacePathExcluded(const APath: string): Boolean;
    procedure AddWorkspacePath(const APath: string);
    procedure FindPascalSourceDirectories(const ARootPath: string);
    procedure CollectWorkspacePaths(AParams: TNXLSInitializeParams);
    procedure ConfigureCodeTools(AParams: TNXLSInitializeParams);
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

    procedure CheckDocument(ADocument: TNXLSDocument); override;
    procedure ReindexDocument(ADocument: TNXLSDocument); override;
    procedure AddWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray); override;
    procedure RemoveWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray); override;
    procedure RebuildWorkspaceIndex; override;
    procedure SendNotification(const AMethod: string; AParams: TJSONData); override;

    property InitializeReceived: Boolean read FInitializeReceived;
    property Initialized: Boolean read FInitialized;
    property ShutdownRequested: Boolean read FShutdownRequested;
    property ExitRequested: Boolean read FExitRequested;
    property CodeToolsInitialized: Boolean read FCodeToolsInitialized;
    property ProjectDir: string read FProjectDir;
    property EffectiveFPCOptions: TStringList read FEffectiveFPCOptions;
    property EffectiveWorkspacePaths: TStringList read FEffectiveWorkspacePaths;
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
  end;

implementation

uses
  SysUtils,
  CodeToolManager,
  IdentCompletionTool;

var
  gCurrentLSPModel: TNXLSLSPModel;

constructor TNXLSLSPModel.Create;
begin
  inherited Create;
  FDocumentsByURI := TObjectList.Create(True);
  FSettings := TNXLSSettings.Create;
  FEffectiveFPCOptions := TStringList.Create;
  FEffectiveWorkspacePaths := TStringList.Create;
  FEffectiveWorkspacePaths.Sorted := True;
  FEffectiveWorkspacePaths.Duplicates := dupIgnore;
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
end;

destructor TNXLSLSPModel.Destroy;
begin
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
  FreeAndNil(FEffectiveWorkspacePaths);
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
  ConfigureCodeTools(AParams);
  FSymbols.SetWorkspaceFolders(AParams);
  FSymbols.RebuildWorkspaceIndex;
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

function TNXLSLSPModel.IsWorkspacePathExcluded(const APath: string): Boolean;
var
  lIdx: Integer;
  lPath: string;
  lExcludePath: string;
begin
  Result := False;
  lPath := IncludeTrailingPathDelimiter(ExpandFileName(APath));

  for lIdx := 0 to FSettings.ExcludeWorkspaceFolders.Count - 1 do
  begin
    lExcludePath := IncludeTrailingPathDelimiter(ExpandFileName(
      FSettings.ExcludeWorkspaceFolders[lIdx]));
    if (lExcludePath <> '') and (Pos(lExcludePath, lPath) = 1) then
      Exit(True);
  end;
end;

procedure TNXLSLSPModel.AddWorkspacePath(const APath: string);
var
  lPath: string;
begin
  lPath := Trim(APath);
  if lPath = '' then
    Exit;

  lPath := IncludeTrailingPathDelimiter(ExpandFileName(lPath));
  if DirectoryExists(lPath) and not IsWorkspacePathExcluded(lPath) then
    FEffectiveWorkspacePaths.Add(lPath);
end;

procedure TNXLSLSPModel.FindPascalSourceDirectories(const ARootPath: string);
var
  lSearch: TSearchRec;
  lPath: string;
  lHasPascalSource: Boolean;
begin
  if (Trim(ARootPath) = '') or (not DirectoryExists(ARootPath)) or
    IsWorkspacePathExcluded(ARootPath) then
    Exit;

  lHasPascalSource := False;

  if FindFirst(IncludeTrailingPathDelimiter(ARootPath) + '*', faAnyFile, lSearch) <> 0 then
    Exit;
  try
    repeat
      if (lSearch.Name = '.') or (lSearch.Name = '..') then
        Continue;

      lPath := IncludeTrailingPathDelimiter(ARootPath) + lSearch.Name;
      if (lSearch.Attr and faDirectory) <> 0 then
        FindPascalSourceDirectories(lPath)
      else if NXLSIsPascalSourceFile(lPath) then
        lHasPascalSource := True;
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;

  if lHasPascalSource then
    AddWorkspacePath(ARootPath);
end;

procedure TNXLSLSPModel.CollectWorkspacePaths(AParams: TNXLSInitializeParams);
var
  lIdx: Integer;
  lFolder: TNXLSWorkspaceFolder;
begin
  FEffectiveWorkspacePaths.Clear;
  FProjectDir := RootPathFromInitializeParams(AParams);

  if AParams = nil then
    Exit;

  if (AParams.workspaceFolders <> nil) and AParams.workspaceFolders.Assigned and
    (AParams.workspaceFolders.Count > 0) then
  begin
    for lIdx := 0 to AParams.workspaceFolders.Count - 1 do
    begin
      lFolder := TNXLSWorkspaceFolder(AParams.workspaceFolders[lIdx]);
      if (lFolder <> nil) and (lFolder.uri <> nil) and lFolder.uri.Assigned then
        FindPascalSourceDirectories(NXLSFileURIToPath(lFolder.uri.Value));
    end;
  end
  else if FProjectDir <> '' then
    FindPascalSourceDirectories(FProjectDir);
end;

procedure TNXLSLSPModel.ConfigureCodeTools(AParams: TNXLSInitializeParams);
var
  lOptions: TCodeToolsOptions;
  lIdx: Integer;
begin
  if AParams = nil then
    Exit;

  FSettings.LoadFromInitializationOptions(AParams.initializationOptions);
  FProjectDir := RootPathFromInitializeParams(AParams);
  FSettings.ExpandMacros(FProjectDir, GetTempDir(True));
  CollectWorkspacePaths(AParams);

  FEffectiveFPCOptions.Clear;
  FEffectiveFPCOptions.Assign(FSettings.FPCOptions);

  for lIdx := 0 to FEffectiveWorkspacePaths.Count - 1 do
  begin
    if FSettings.IncludeWorkspaceFoldersAsUnitPaths then
      FEffectiveFPCOptions.Add('-Fu' + FEffectiveWorkspacePaths[lIdx]);
    if FSettings.IncludeWorkspaceFoldersAsIncludePaths then
      FEffectiveFPCOptions.Add('-Fi' + FEffectiveWorkspacePaths[lIdx]);
  end;

  lOptions := TCodeToolsOptions.Create;
  try
    lOptions.ProjectDir := FProjectDir;
    lOptions.TargetOS := {$i %FPCTARGETOS%};
    lOptions.TargetProcessor := {$i %FPCTARGETCPU%};
    lOptions.InitWithEnvironmentVariables;

    if (FSettings.CodeToolsConfig <> '') and FileExists(FSettings.CodeToolsConfig) then
      lOptions.LoadFromFile(FSettings.CodeToolsConfig);

    lOptions.FPCOptions := Trim(StringReplace(FEffectiveFPCOptions.Text, LineEnding, ' ', [rfReplaceAll]));
    CodeToolBoss.Init(lOptions);
    CodeToolBoss.IdentifierList.SortForHistory := True;
    CodeToolBoss.IdentifierList.SortMethodForCompletion := icsScopedAlphabetic;
    FCodeToolsInitialized := True;
  finally
    lOptions.Free;
  end;
end;

procedure TNXLSLSPModel.MarkInitialized;
begin
  FInitialized := True;
end;

procedure TNXLSLSPModel.RequestShutdown;
begin
  FShutdownRequested := True;
end;

procedure TNXLSLSPModel.RequestExit;
begin
  FExitRequested := True;
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

procedure TNXLSLSPModel.CheckDocument(ADocument: TNXLSDocument);
begin
  FDiagnostics.CheckDocument(ADocument);
end;

procedure TNXLSLSPModel.ReindexDocument(ADocument: TNXLSDocument);
begin
  FSymbols.ReindexDocument(ADocument);
end;

procedure TNXLSLSPModel.AddWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
begin
  FSymbols.AddWorkspaceFolders(AFolders);
end;

procedure TNXLSLSPModel.RemoveWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
begin
  FSymbols.RemoveWorkspaceFolders(AFolders);
end;

procedure TNXLSLSPModel.RebuildWorkspaceIndex;
begin
  FSymbols.RebuildWorkspaceIndex;
end;

procedure TNXLSLSPModel.SendNotification(const AMethod: string; AParams: TJSONData);
var
  lNotification: TJSONObject;
begin
  if FTransport = nil then
    Exit;

  lNotification := TJSONObject.Create;
  try
    lNotification.Add('jsonrpc', '2.0');
    lNotification.Add('method', AMethod);
    if AParams = nil then
      lNotification.Add('params', TJSONObject.Create)
    else
      lNotification.Add('params', AParams.Clone);

    FTransport.WriteMessage(lNotification.AsJSON);
  finally
    lNotification.Free;
  end;
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
