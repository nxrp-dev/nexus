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
    FLastError: string;
    function CompileDocument(const AFileName: string): TNexusScriptCompiler;
    function ResolveDependencyPath(const ASourceName,
      ADeclaredPath: string): string;
    procedure AddArtifactDocument(ACompiler: TNexusScriptCompiler;
      ASeen: TStringList);
    procedure BuildArtifactDocuments;
    function SelectDefinition(ACompiler: TNexusScriptCompiler;
      const ASelector: string): TNexusScriptCompiledDefinition;
  public
    constructor Create;
    destructor Destroy; override;
    function CompileFile(const AFileName: string): Boolean;
    property EntryCompiler: TNexusScriptCompiler read FEntryCompiler;
    property ArtifactDocuments: TNexusScriptArtifactDocumentList
      read FArtifactDocuments;
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
end;

destructor TNexusScriptCompilationSession.Destroy;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FCompilers.Count - 1 do
    FCompilers.Objects[lIndex].Free;
  FArtifactDocuments.Free;
  FActiveFiles.Free;
  FCompilers.Free;
  inherited Destroy;
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

function TNexusScriptCompilationSession.SelectDefinition(
  ACompiler: TNexusScriptCompiler;
  const ASelector: string): TNexusScriptCompiledDefinition;
var
  lParts: TStringList;
  lIndex: Integer;
begin
  Result := nil;
  if ACompiler.CompiledDocument = nil then
    Exit;
  if ASelector = '' then
  begin
    if ACompiler.CompiledDocument.Definitions.Count = 1 then
      Result := ACompiler.CompiledDocument.Definitions[0];
    Exit;
  end;
  lParts := TStringList.Create;
  try
    lParts.Delimiter := '.';
    lParts.StrictDelimiter := True;
    lParts.DelimitedText := ASelector;
    if lParts.Count = 0 then
      Exit;
    Result := ACompiler.CompiledDocument.FindDefinition(lParts[0]);
    for lIndex := 1 to lParts.Count - 1 do
    begin
      if Result = nil then
        Exit;
      Result := Result.FindChild(lParts[lIndex]);
    end;
  finally
    lParts.Free;
  end;
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
        lCompiler.AddImportedDocument(lModule.AliasName,
          lImportedCompiler.CompiledDocument)
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
        lCompiler.AddImportedDefinition(lModule.AliasName, lImportedDefinition);
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
  FEntryCompiler := CompileDocument(AFileName);
  Result := FEntryCompiler <> nil;
  if Result then
    BuildArtifactDocuments;
end;

end.
