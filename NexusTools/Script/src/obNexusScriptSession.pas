unit obNexusScriptSession;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptCompiler;

type
  TNexusScriptArtifactDocument = class
  private
    FSourceDocument: TNexusScriptSourceDocument;
    FCompiledDocument: TNexusScriptCompiledDocument;
  public
    constructor Create(ASourceDocument: TNexusScriptSourceDocument;
      ACompiledDocument: TNexusScriptCompiledDocument);
    property SourceDocument: TNexusScriptSourceDocument read FSourceDocument;
    property CompiledDocument: TNexusScriptCompiledDocument
      read FCompiledDocument;
  end;

  TNexusScriptArtifactDocumentList =
    TObjectList<TNexusScriptArtifactDocument>;

  TNexusScriptCompilationSession = class
  private
    FCompilers: TStringList;
    FActiveFiles: TStringList;
    FEntryCompiler: TNexusScriptCompiler;
    FArtifactDocuments: TNexusScriptArtifactDocumentList;
    FExternalSources: TNexusScriptExternalSourceList;
    FLastError: string;
    function CompileDocument(const AFileName: string): TNexusScriptCompiler;
    function ResolveDependencyPath(const ASourceName,
      ADeclaredPath: string): string;
    procedure AddArtifactDocument(ACompiler: TNexusScriptCompiler;
      ASeen: TStringList);
    procedure BuildArtifactDocuments;
    procedure AddExternalSources(ACompiler: TNexusScriptCompiler;
      ASeenDocuments, ASourceNames: TStringList);
    procedure BuildExternalSources;
    function ResolveExternalSourcePath(const ASourceName,
      ADeclaredPath: string): string;
    function SelectDefinition(ACompiler: TNexusScriptCompiler;
      const ASelector: string): TNexusScriptCompiledDefinition;
  public
    constructor Create;
    destructor Destroy; override;
    function CompileFile(const AFileName: string): Boolean;
    property EntryCompiler: TNexusScriptCompiler read FEntryCompiler;
    property ArtifactDocuments: TNexusScriptArtifactDocumentList
      read FArtifactDocuments;
    property ExternalSources: TNexusScriptExternalSourceList
      read FExternalSources;
    property LastError: string read FLastError;
  end;

implementation

constructor TNexusScriptArtifactDocument.Create(
  ASourceDocument: TNexusScriptSourceDocument;
  ACompiledDocument: TNexusScriptCompiledDocument);
begin
  inherited Create;
  FSourceDocument := ASourceDocument;
  FCompiledDocument := ACompiledDocument;
end;

constructor TNexusScriptCompilationSession.Create;
begin
  inherited Create;
  FCompilers := TStringList.Create;
  FCompilers.CaseSensitive := False;
  FCompilers.Sorted := True;
  FCompilers.Duplicates := dupError;
  FActiveFiles := TStringList.Create;
  FActiveFiles.CaseSensitive := False;
  FArtifactDocuments := TNexusScriptArtifactDocumentList.Create(True);
  FExternalSources := TNexusScriptExternalSourceList.Create(True);
end;

destructor TNexusScriptCompilationSession.Destroy;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FCompilers.Count - 1 do
    FCompilers.Objects[lIndex].Free;
  FExternalSources.Free;
  FArtifactDocuments.Free;
  FActiveFiles.Free;
  FCompilers.Free;
  inherited Destroy;
end;

function TNexusScriptCompilationSession.ResolveExternalSourcePath(
  const ASourceName, ADeclaredPath: string): string;
begin
  if (ExtractFileDrive(ADeclaredPath) <> '') or
    ((ADeclaredPath <> '') and IsPathDelimiter(ADeclaredPath, 1)) then
    Result := ExpandFileName(ADeclaredPath)
  else
    Result := ResolveDependencyPath(ASourceName, ADeclaredPath);
end;

function TNexusScriptCompilationSession.ResolveDependencyPath(
  const ASourceName, ADeclaredPath: string): string;
begin
  Result := ExpandFileName(IncludeTrailingPathDelimiter(
    ExtractFileDir(ASourceName)) + ADeclaredPath);
end;

procedure TNexusScriptCompilationSession.AddArtifactDocument(
  ACompiler: TNexusScriptCompiler; ASeen: TStringList);
var
  lCanonicalName: string;
  lInclude: TNexusScriptSourceInclude;
  lIncludedName: string;
  lIndex: Integer;
begin
  lCanonicalName := ExpandFileName(ACompiler.CompiledDocument.SourceName);
  if ASeen.IndexOf(lCanonicalName) >= 0 then
    Exit;
  ASeen.Add(lCanonicalName);
  FArtifactDocuments.Add(TNexusScriptArtifactDocument.Create(
    ACompiler.SourceDocument, ACompiler.CompiledDocument));
  for lInclude in ACompiler.SourceDocument.Includes do
  begin
    lIncludedName := ResolveDependencyPath(
      ACompiler.SourceDocument.SourceName, lInclude.Path);
    lIndex := FCompilers.IndexOf(lIncludedName);
    if lIndex < 0 then
      raise Exception.CreateFmt('Compiled include is unavailable: %s',
        [lIncludedName]);
    AddArtifactDocument(TNexusScriptCompiler(FCompilers.Objects[lIndex]),
      ASeen);
  end;
end;

procedure TNexusScriptCompilationSession.BuildArtifactDocuments;
var
  lSeen: TStringList;
begin
  FArtifactDocuments.Clear;
  if FEntryCompiler = nil then
    Exit;
  lSeen := TStringList.Create;
  try
    lSeen.CaseSensitive := False;
    lSeen.Sorted := True;
    lSeen.Duplicates := dupIgnore;
    AddArtifactDocument(FEntryCompiler, lSeen);
  finally
    lSeen.Free;
  end;
end;

procedure TNexusScriptCompilationSession.AddExternalSources(
  ACompiler: TNexusScriptCompiler; ASeenDocuments,
  ASourceNames: TStringList);
var
  lCanonicalDocument: string;
  lDataSource: TNexusScriptSourceData;
  lFileName: string;
  lExistingFileName: string;
  lSourceType: string;
  lExtension: string;
  lInclude: TNexusScriptSourceInclude;
  lModule: TNexusScriptSourceModule;
  lDependencyName: string;
  lIndex: Integer;
begin
  lCanonicalDocument := ExpandFileName(ACompiler.SourceDocument.SourceName);
  if ASeenDocuments.IndexOf(lCanonicalDocument) >= 0 then
    Exit;
  ASeenDocuments.Add(lCanonicalDocument);

  for lDataSource in ACompiler.SourceDocument.DataSources do
  begin
    lFileName := ResolveExternalSourcePath(lCanonicalDocument,
      lDataSource.Path);
    lIndex := ASourceNames.IndexOfName(lDataSource.Name);
    if lIndex >= 0 then
    begin
      lExistingFileName := ASourceNames.ValueFromIndex[lIndex];
      if SameFileName(lExistingFileName, lFileName) then
        Continue;
      raise Exception.CreateFmt(
        'External data source %s resolves to both %s and %s',
        [lDataSource.Name, lExistingFileName, lFileName]);
    end;
    ASourceNames.Add(lDataSource.Name + '=' + lFileName);
    lExtension := ExtractFileExt(lFileName);
    if lExtension <> '' then
      Delete(lExtension, 1, 1);
    lSourceType := LowerCase(lExtension);
    FExternalSources.Add(TNexusScriptExternalSource.Create(
      lDataSource.Name, lDataSource.Path, lFileName, lSourceType,
      lCanonicalDocument, lDataSource.SourceRange));
  end;

  for lInclude in ACompiler.SourceDocument.Includes do
  begin
    lDependencyName := ResolveDependencyPath(lCanonicalDocument,
      lInclude.Path);
    lIndex := FCompilers.IndexOf(lDependencyName);
    if lIndex < 0 then
      raise Exception.CreateFmt('Compiled include is unavailable: %s',
        [lDependencyName]);
    AddExternalSources(TNexusScriptCompiler(FCompilers.Objects[lIndex]),
      ASeenDocuments, ASourceNames);
  end;

  for lModule in ACompiler.SourceDocument.Modules do
  begin
    lDependencyName := ResolveDependencyPath(lCanonicalDocument,
      lModule.Path);
    lIndex := FCompilers.IndexOf(lDependencyName);
    if lIndex < 0 then
      raise Exception.CreateFmt('Compiled module is unavailable: %s',
        [lDependencyName]);
    AddExternalSources(TNexusScriptCompiler(FCompilers.Objects[lIndex]),
      ASeenDocuments, ASourceNames);
  end;
end;

procedure TNexusScriptCompilationSession.BuildExternalSources;
var
  lSeenDocuments: TStringList;
  lSourceNames: TStringList;
begin
  FExternalSources.Clear;
  if FEntryCompiler = nil then
    Exit;
  lSeenDocuments := TStringList.Create;
  lSourceNames := TStringList.Create;
  try
    lSeenDocuments.CaseSensitive := False;
    lSeenDocuments.Sorted := True;
    lSeenDocuments.Duplicates := dupIgnore;
    lSourceNames.CaseSensitive := False;
    lSourceNames.NameValueSeparator := '=';
    AddExternalSources(FEntryCompiler, lSeenDocuments, lSourceNames);
  finally
    lSourceNames.Free;
    lSeenDocuments.Free;
  end;
end;

function TNexusScriptCompilationSession.SelectDefinition(
  ACompiler: TNexusScriptCompiler;
  const ASelector: string): TNexusScriptCompiledDefinition;
begin
  Result := nil;
  if ACompiler.CompiledDocument = nil then
    Exit;
  Result := ACompiler.CompiledDocument.FindDefinition(ASelector);
end;

function TNexusScriptCompilationSession.CompileDocument(
  const AFileName: string): TNexusScriptCompiler;
var
  lCanonicalName: string;
  lIndex: Integer;
  lCompiler: TNexusScriptCompiler;
  lModule: TNexusScriptSourceModule;
  lImportedCompiler: TNexusScriptCompiler;
  lImportedDefinition: TNexusScriptCompiledDefinition;
  lImportedName: string;
  lDoctype: TNexusScriptSourceDoctype;
  lDoctypeCompiler: TNexusScriptCompiler;
  lDoctypeSourceName: string;
  lDeclaredDoctypePath: string;
  lDoctypeRange: TNexusScriptRange;
  lInclude: TNexusScriptSourceInclude;
  lIncludedCompiler: TNexusScriptCompiler;
  lIncludedName: string;
begin
  Result := nil;
  lCanonicalName := ExpandFileName(AFileName);
  lIndex := FCompilers.IndexOf(lCanonicalName);
  if lIndex >= 0 then
    Exit(TNexusScriptCompiler(FCompilers.Objects[lIndex]));
  if FActiveFiles.IndexOf(lCanonicalName) >= 0 then
  begin
    FLastError := 'Document dependency cycle at ' + lCanonicalName;
    Exit;
  end;
  if not FileExists(lCanonicalName) then
  begin
    FLastError := 'Document file not found: ' + lCanonicalName;
    Exit;
  end;
  FActiveFiles.Add(lCanonicalName);
  lCompiler := TNexusScriptCompiler.Create;
  try
    lCompiler.CompileFile(lCanonicalName);
    lCompiler.ClearImports;
    lDoctype := lCompiler.SourceDocument.Doctype;
    lDoctypeCompiler := nil;
    lDoctypeSourceName := '';
    lDeclaredDoctypePath := '';
    if lDoctype <> nil then
    begin
      lDeclaredDoctypePath := lDoctype.Path;
      lDoctypeRange := lDoctype.SourceRange;
      lDoctypeSourceName := ResolveDependencyPath(lCanonicalName,
        lDeclaredDoctypePath);
      lDoctypeCompiler := CompileDocument(lDoctypeSourceName);
      if lDoctypeCompiler = nil then
      begin
        FLastError := 'Unable to load doctype for ' + lCanonicalName +
          ': ' + FLastError;
        Exit;
      end;
    end;
    for lModule in lCompiler.SourceDocument.Modules do
    begin
      lImportedName := ResolveDependencyPath(lCanonicalName, lModule.Path);
      lImportedCompiler := CompileDocument(lImportedName);
      if lImportedCompiler = nil then
        Exit;
      if lModule.RootSelector = '' then
        lCompiler.AddImportedDocument(lImportedCompiler.CompiledDocument)
      else
      begin
        lImportedDefinition := SelectDefinition(lImportedCompiler,
          lModule.RootSelector);
        if lImportedDefinition = nil then
        begin
          FLastError := 'Module root selector not found: ' +
            lModule.RootSelector + ' in ' + lImportedName;
          Exit;
        end;
        lCompiler.AddImportedDefinition(lImportedDefinition);
      end;
    end;
    for lInclude in lCompiler.SourceDocument.Includes do
    begin
      lIncludedName := ResolveDependencyPath(lCanonicalName, lInclude.Path);
      lIncludedCompiler := CompileDocument(lIncludedName);
      if lIncludedCompiler = nil then
      begin
        FLastError := 'Unable to load include ' + lInclude.Path + ' for ' +
          lCanonicalName + ': ' + FLastError;
        Exit;
      end;
    end;
    if not lCompiler.CompileFile(lCanonicalName) then
    begin
      FLastError := 'Compilation failed: ' + lCanonicalName;
      if lCompiler.Diagnostics.Count > 0 then
        FLastError := FLastError + ': ' +
          lCompiler.Diagnostics[0].MessageText;
      Exit;
    end;
    if lDeclaredDoctypePath <> '' then
      lCompiler.CompiledDocument.SetDoctype(lDeclaredDoctypePath,
        lDoctypeSourceName, lDoctypeRange,
        lDoctypeCompiler.CompiledDocument);
    FCompilers.AddObject(lCanonicalName, lCompiler);
    Result := lCompiler;
    lCompiler := nil;
  finally
    FActiveFiles.Delete(FActiveFiles.IndexOf(lCanonicalName));
    lCompiler.Free;
  end;
end;

function TNexusScriptCompilationSession.CompileFile(
  const AFileName: string): Boolean;
begin
  FLastError := '';
  FEntryCompiler := nil;
  FArtifactDocuments.Clear;
  FExternalSources.Clear;
  FEntryCompiler := CompileDocument(AFileName);
  Result := FEntryCompiler <> nil;
  if Result then
    try
      BuildArtifactDocuments;
      BuildExternalSources;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
      end;
    end;
end;

end.
