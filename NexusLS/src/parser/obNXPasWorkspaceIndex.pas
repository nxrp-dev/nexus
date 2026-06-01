unit obNXPasWorkspaceIndex;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  obNXPasDiagnostics,
  obNXPasMetadata,
  obNXPasProject,
  obNXPasSource,
  obNXPasSymbols;

type
  TNXPasIndexedFile = class;

  TNXPasUsesRelationship = class
  private
    FFromFile: TNXPasIndexedFile;
    FToFile: TNXPasIndexedFile;
    FUsesEntry: TNXPasUsesEntry;
  public
    property FromFile: TNXPasIndexedFile read FFromFile write FFromFile;
    property ToFile: TNXPasIndexedFile read FToFile write FToFile;
    property UsesEntry: TNXPasUsesEntry read FUsesEntry write FUsesEntry;
  end;

  TNXPasUsesRelationshipList = class(TObjectList)
  public
    function AddRelationship(AFromFile, AToFile: TNXPasIndexedFile;
      AUsesEntry: TNXPasUsesEntry): TNXPasUsesRelationship;
    function RelationshipAt(AIndex: Integer): TNXPasUsesRelationship;
  end;

  TNXPasUnresolvedUsesEntry = class
  private
    FFile: TNXPasIndexedFile;
    FUsesEntry: TNXPasUsesEntry;
  public
    property FileRef: TNXPasIndexedFile read FFile write FFile;
    property UsesEntry: TNXPasUsesEntry read FUsesEntry write FUsesEntry;
  end;

  TNXPasUnresolvedUsesList = class(TObjectList)
  public
    function AddUnresolved(AFile: TNXPasIndexedFile;
      AUsesEntry: TNXPasUsesEntry): TNXPasUnresolvedUsesEntry;
    function UnresolvedAt(AIndex: Integer): TNXPasUnresolvedUsesEntry;
  end;

  TNXPasWorkspaceSymbolMatch = class
  private
    FContainerName: string;
    FFile: TNXPasIndexedFile;
    FSymbol: TNXPasSymbol;
  public
    property ContainerName: string read FContainerName write FContainerName;
    property FileRef: TNXPasIndexedFile read FFile write FFile;
    property Symbol: TNXPasSymbol read FSymbol write FSymbol;
  end;

  TNXPasWorkspaceSymbolMatchList = class(TObjectList)
  public
    function AddMatch(AFile: TNXPasIndexedFile; ASymbol: TNXPasSymbol;
      const AContainerName: string): TNXPasWorkspaceSymbolMatch;
    function MatchAt(AIndex: Integer): TNXPasWorkspaceSymbolMatch;
  end;

  TNXPasIndexedFile = class
  private
    FDiagnostics: TNXPasDiagnosticList;
    FFileName: string;
    FMetadata: TNXPasUnitMetadata;
    FSymbols: TNXPasSymbolTable;
    FText: string;
    FURI: string;
  public
    constructor Create;
    destructor Destroy; override;

    property Diagnostics: TNXPasDiagnosticList read FDiagnostics;
    property FileName: string read FFileName write FFileName;
    property Metadata: TNXPasUnitMetadata read FMetadata;
    property Symbols: TNXPasSymbolTable read FSymbols;
    property Text: string read FText write FText;
    property URI: string read FURI write FURI;
  end;

  TNXPasWorkspaceIndex = class
  private
    FFiles: TObjectList;
    procedure AddSymbolMatches(AFile: TNXPasIndexedFile; ASymbol: TNXPasSymbol;
      const AQuery, AContainerName: string;
      AResults: TNXPasWorkspaceSymbolMatchList);
    procedure AddExactSymbolMatches(AFile: TNXPasIndexedFile;
      ASymbol: TNXPasSymbol; const AName, AContainerName: string;
      AResults: TNXPasWorkspaceSymbolMatchList);
    function FindFileIndexByURI(const AURI: string): Integer;
    function GetFile(AIndex: Integer): TNXPasIndexedFile;
    procedure AddUsesRelationshipsForList(AFile: TNXPasIndexedFile;
      AUsesList: TNXPasUsesEntryList; AResults: TNXPasUsesRelationshipList);
    procedure AddUnresolvedUsesForList(AFile: TNXPasIndexedFile;
      AUsesList: TNXPasUsesEntryList; AResults: TNXPasUnresolvedUsesList);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    function AddProject(AProject: TNXPasProject): Integer;
    function FileCount: Integer;
    procedure QuerySymbols(const AQuery: string;
      AResults: TNXPasWorkspaceSymbolMatchList);
    procedure FindSymbolsByName(const AName, APreferredURI: string;
      AResults: TNXPasWorkspaceSymbolMatchList);
    function FindFileByUnitName(const AUnitName: string): TNXPasIndexedFile;
    procedure ListKnownUnits(AUnits: TStrings);
    procedure ListUsesRelationships(AResults: TNXPasUsesRelationshipList);
    procedure ListUnresolvedUses(AResults: TNXPasUnresolvedUsesList);
    procedure BuildDependencyManifest(AManifest: TNXPasDependencyManifest);
    procedure RemoveFile(const AURI: string);
    function UpdateSourceFile(ASource: TNXPasSourceFile): TNXPasIndexedFile;
    property Files[AIndex: Integer]: TNXPasIndexedFile read GetFile;
  end;

implementation

uses
  SysUtils,
  obNXPasAST,
  obNXPasParser;

function TNXPasUsesRelationshipList.AddRelationship(AFromFile,
  AToFile: TNXPasIndexedFile; AUsesEntry: TNXPasUsesEntry):
  TNXPasUsesRelationship;
begin
  Result := TNXPasUsesRelationship.Create;
  Result.FromFile := AFromFile;
  Result.ToFile := AToFile;
  Result.UsesEntry := AUsesEntry;
  Add(Result);
end;

function TNXPasUsesRelationshipList.RelationshipAt(
  AIndex: Integer): TNXPasUsesRelationship;
begin
  Result := TNXPasUsesRelationship(Items[AIndex]);
end;

function TNXPasUnresolvedUsesList.AddUnresolved(AFile: TNXPasIndexedFile;
  AUsesEntry: TNXPasUsesEntry): TNXPasUnresolvedUsesEntry;
begin
  Result := TNXPasUnresolvedUsesEntry.Create;
  Result.FileRef := AFile;
  Result.UsesEntry := AUsesEntry;
  Add(Result);
end;

function TNXPasUnresolvedUsesList.UnresolvedAt(
  AIndex: Integer): TNXPasUnresolvedUsesEntry;
begin
  Result := TNXPasUnresolvedUsesEntry(Items[AIndex]);
end;

function TNXPasWorkspaceSymbolMatchList.AddMatch(AFile: TNXPasIndexedFile;
  ASymbol: TNXPasSymbol; const AContainerName: string): TNXPasWorkspaceSymbolMatch;
begin
  Result := TNXPasWorkspaceSymbolMatch.Create;
  Result.FileRef := AFile;
  Result.Symbol := ASymbol;
  Result.ContainerName := AContainerName;
  Add(Result);
end;

function TNXPasWorkspaceSymbolMatchList.MatchAt(
  AIndex: Integer): TNXPasWorkspaceSymbolMatch;
begin
  Result := TNXPasWorkspaceSymbolMatch(Items[AIndex]);
end;

constructor TNXPasIndexedFile.Create;
begin
  inherited Create;
  FDiagnostics := TNXPasDiagnosticList.Create(True);
  FMetadata := TNXPasUnitMetadata.Create;
  FSymbols := TNXPasSymbolTable.Create(True);
end;

destructor TNXPasIndexedFile.Destroy;
begin
  FreeAndNil(FSymbols);
  FreeAndNil(FMetadata);
  FreeAndNil(FDiagnostics);
  inherited Destroy;
end;

constructor TNXPasWorkspaceIndex.Create;
begin
  inherited Create;
  FFiles := TObjectList.Create(True);
end;

destructor TNXPasWorkspaceIndex.Destroy;
begin
  FreeAndNil(FFiles);
  inherited Destroy;
end;

function TNXPasWorkspaceIndex.GetFile(AIndex: Integer): TNXPasIndexedFile;
begin
  Result := TNXPasIndexedFile(FFiles[AIndex]);
end;

function TNXPasWorkspaceIndex.FindFileIndexByURI(const AURI: string): Integer;
begin
  Result := FFiles.Count - 1;
  while Result >= 0 do
  begin
    if SameText(TNXPasIndexedFile(FFiles[Result]).URI, AURI) then
      Exit;
    Dec(Result);
  end;
end;

procedure TNXPasWorkspaceIndex.Clear;
begin
  FFiles.Clear;
end;

function TNXPasWorkspaceIndex.AddProject(AProject: TNXPasProject): Integer;
var
  lIdx: Integer;
begin
  Result := 0;
  if AProject = nil then
    Exit;

  for lIdx := 0 to AProject.SourceFileCount - 1 do
  begin
    UpdateSourceFile(AProject.SourceFiles[lIdx]);
    Inc(Result);
  end;
end;

function TNXPasWorkspaceIndex.FileCount: Integer;
begin
  Result := FFiles.Count;
end;

function TNXPasWorkspaceIndex.FindFileByUnitName(
  const AUnitName: string): TNXPasIndexedFile;
var
  lIdx: Integer;
begin
  Result := nil;
  if Trim(AUnitName) = '' then
    Exit;

  for lIdx := 0 to FFiles.Count - 1 do
    if SameText(TNXPasIndexedFile(FFiles[lIdx]).Metadata.Name, AUnitName) then
      Exit(TNXPasIndexedFile(FFiles[lIdx]));
end;

procedure TNXPasWorkspaceIndex.ListKnownUnits(AUnits: TStrings);
var
  lFile: TNXPasIndexedFile;
  lIdx: Integer;
begin
  if AUnits = nil then
    Exit;

  for lIdx := 0 to FFiles.Count - 1 do
  begin
    lFile := TNXPasIndexedFile(FFiles[lIdx]);
    if lFile.Metadata.Name <> '' then
      AUnits.Add(lFile.Metadata.Name);
  end;
end;

procedure TNXPasWorkspaceIndex.AddUsesRelationshipsForList(
  AFile: TNXPasIndexedFile; AUsesList: TNXPasUsesEntryList;
  AResults: TNXPasUsesRelationshipList);
var
  lIdx: Integer;
  lTarget: TNXPasIndexedFile;
  lUsesEntry: TNXPasUsesEntry;
begin
  if (AFile = nil) or (AUsesList = nil) or (AResults = nil) then
    Exit;

  for lIdx := 0 to AUsesList.Count - 1 do
  begin
    lUsesEntry := AUsesList.EntryAt(lIdx);
    if not lUsesEntry.Active then
      Continue;
    lTarget := FindFileByUnitName(lUsesEntry.UnitName);
    if lTarget <> nil then
      AResults.AddRelationship(AFile, lTarget, lUsesEntry);
  end;
end;

procedure TNXPasWorkspaceIndex.ListUsesRelationships(
  AResults: TNXPasUsesRelationshipList);
var
  lFile: TNXPasIndexedFile;
  lIdx: Integer;
begin
  if AResults = nil then
    Exit;

  for lIdx := 0 to FFiles.Count - 1 do
  begin
    lFile := TNXPasIndexedFile(FFiles[lIdx]);
    AddUsesRelationshipsForList(lFile, lFile.Metadata.InterfaceUses, AResults);
    AddUsesRelationshipsForList(lFile, lFile.Metadata.ImplementationUses,
      AResults);
  end;
end;

procedure TNXPasWorkspaceIndex.AddUnresolvedUsesForList(
  AFile: TNXPasIndexedFile; AUsesList: TNXPasUsesEntryList;
  AResults: TNXPasUnresolvedUsesList);
var
  lIdx: Integer;
  lUsesEntry: TNXPasUsesEntry;
begin
  if (AFile = nil) or (AUsesList = nil) or (AResults = nil) then
    Exit;

  for lIdx := 0 to AUsesList.Count - 1 do
  begin
    lUsesEntry := AUsesList.EntryAt(lIdx);
    if lUsesEntry.Active and (FindFileByUnitName(lUsesEntry.UnitName) = nil) then
      AResults.AddUnresolved(AFile, lUsesEntry);
  end;
end;

procedure TNXPasWorkspaceIndex.ListUnresolvedUses(
  AResults: TNXPasUnresolvedUsesList);
var
  lFile: TNXPasIndexedFile;
  lIdx: Integer;
begin
  if AResults = nil then
    Exit;

  for lIdx := 0 to FFiles.Count - 1 do
  begin
    lFile := TNXPasIndexedFile(FFiles[lIdx]);
    AddUnresolvedUsesForList(lFile, lFile.Metadata.InterfaceUses, AResults);
    AddUnresolvedUsesForList(lFile, lFile.Metadata.ImplementationUses,
      AResults);
  end;
end;

procedure TNXPasWorkspaceIndex.BuildDependencyManifest(
  AManifest: TNXPasDependencyManifest);
var
  lDependency: TNXPasDeploymentDependency;
  lDependencyIdx: Integer;
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
begin
  if AManifest = nil then
    Exit;

  for lFileIdx := 0 to FFiles.Count - 1 do
  begin
    lFile := TNXPasIndexedFile(FFiles[lFileIdx]);
    for lDependencyIdx := 0 to lFile.Metadata.Dependencies.Count - 1 do
    begin
      lDependency := lFile.Metadata.Dependencies.DependencyAt(lDependencyIdx);
      if lDependency.Active then
        AManifest.AddEntry(lDependency.Value, lFile.Metadata.Name,
          lFile.Metadata.SourcePath, lFile.Metadata.SourceURI,
          lDependency.Range);
    end;
  end;
end;

procedure TNXPasWorkspaceIndex.RemoveFile(const AURI: string);
var
  lIdx: Integer;
begin
  lIdx := FindFileIndexByURI(AURI);
  if lIdx >= 0 then
    FFiles.Delete(lIdx);
end;

function TNXPasWorkspaceIndex.UpdateSourceFile(
  ASource: TNXPasSourceFile): TNXPasIndexedFile;
var
  lExtractor: TNXPasSymbolExtractor;
  lIdx: Integer;
  lParser: TNXPasParser;
  lTree: TNXPasSyntaxTree;
begin
  if ASource = nil then
    Exit(nil);

  lIdx := FindFileIndexByURI(ASource.URI);
  if lIdx >= 0 then
    Result := TNXPasIndexedFile(FFiles[lIdx])
  else
  begin
    Result := TNXPasIndexedFile.Create;
    FFiles.Add(Result);
  end;

  Result.FileName := ASource.FileName;
  Result.URI := ASource.URI;
  Result.Text := ASource.Text;
  Result.Diagnostics.Clear;
  Result.Metadata.Clear;
  Result.Symbols.Clear;

  lParser := TNXPasParser.Create(Result.Diagnostics);
  lExtractor := TNXPasSymbolExtractor.Create;
  lTree := nil;
  try
    lTree := lParser.Parse(ASource);
    Result.Metadata.AssignFrom(lTree.Metadata);
    lExtractor.Extract(lTree, Result.Symbols);
  finally
    lTree.Free;
    lExtractor.Free;
    lParser.Free;
  end;
end;

procedure TNXPasWorkspaceIndex.AddExactSymbolMatches(AFile: TNXPasIndexedFile;
  ASymbol: TNXPasSymbol; const AName, AContainerName: string;
  AResults: TNXPasWorkspaceSymbolMatchList);
var
  lChildIdx: Integer;
begin
  if (AFile = nil) or (ASymbol = nil) or (AResults = nil) then
    Exit;

  if not (ASymbol.Kind in [pskUnknown, pskUsesUnit, pskVisibility]) and
    SameText(ASymbol.Name, AName) then
    AResults.AddMatch(AFile, ASymbol, AContainerName);

  for lChildIdx := 0 to ASymbol.ChildCount - 1 do
    AddExactSymbolMatches(AFile, ASymbol.Children[lChildIdx], AName,
      ASymbol.Name, AResults);
end;

procedure TNXPasWorkspaceIndex.AddSymbolMatches(AFile: TNXPasIndexedFile;
  ASymbol: TNXPasSymbol; const AQuery, AContainerName: string;
  AResults: TNXPasWorkspaceSymbolMatchList);
var
  lChildIdx: Integer;
  lQuery: string;
begin
  if (AFile = nil) or (ASymbol = nil) or (AResults = nil) then
    Exit;

  if not (ASymbol.Kind in [pskUnknown, pskUsesUnit, pskVisibility]) then
  begin
    lQuery := UpperCase(Trim(AQuery));
    if (lQuery = '') or (Pos(lQuery, UpperCase(ASymbol.Name)) > 0) then
      AResults.AddMatch(AFile, ASymbol, AContainerName);
  end;

  for lChildIdx := 0 to ASymbol.ChildCount - 1 do
    AddSymbolMatches(AFile, ASymbol.Children[lChildIdx], AQuery,
      ASymbol.Name, AResults);
end;

procedure TNXPasWorkspaceIndex.FindSymbolsByName(const AName,
  APreferredURI: string; AResults: TNXPasWorkspaceSymbolMatchList);
var
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
  lPass: Integer;
  lSymbolIdx: Integer;
begin
  if (Trim(AName) = '') or (AResults = nil) then
    Exit;

  for lPass := 0 to 1 do
    for lFileIdx := 0 to FFiles.Count - 1 do
    begin
      lFile := TNXPasIndexedFile(FFiles[lFileIdx]);
      if lPass = 0 then
      begin
        if not SameText(lFile.URI, APreferredURI) then
          Continue;
      end
      else if SameText(lFile.URI, APreferredURI) then
        Continue;

      for lSymbolIdx := 0 to lFile.Symbols.Count - 1 do
        AddExactSymbolMatches(lFile, lFile.Symbols.SymbolAt(lSymbolIdx), AName,
          '', AResults);
    end;
end;

procedure TNXPasWorkspaceIndex.QuerySymbols(const AQuery: string;
  AResults: TNXPasWorkspaceSymbolMatchList);
var
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
  lSymbolIdx: Integer;
begin
  if AResults = nil then
    Exit;

  for lFileIdx := 0 to FFiles.Count - 1 do
  begin
    lFile := TNXPasIndexedFile(FFiles[lFileIdx]);
    for lSymbolIdx := 0 to lFile.Symbols.Count - 1 do
      AddSymbolMatches(lFile, lFile.Symbols.SymbolAt(lSymbolIdx), AQuery, '',
        AResults);
  end;
end;

end.
