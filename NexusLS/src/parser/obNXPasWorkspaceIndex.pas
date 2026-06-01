unit obNXPasWorkspaceIndex;

{$mode objfpc}{$H+}

interface

uses
  Contnrs,
  obNXPasDiagnostics,
  obNXPasProject,
  obNXPasSource,
  obNXPasSymbols;

type
  TNXPasIndexedFile = class;

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
    FSymbols: TNXPasSymbolTable;
    FText: string;
    FURI: string;
  public
    constructor Create;
    destructor Destroy; override;

    property Diagnostics: TNXPasDiagnosticList read FDiagnostics;
    property FileName: string read FFileName write FFileName;
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
    procedure RemoveFile(const AURI: string);
    function UpdateSourceFile(ASource: TNXPasSourceFile): TNXPasIndexedFile;
    property Files[AIndex: Integer]: TNXPasIndexedFile read GetFile;
  end;

implementation

uses
  SysUtils,
  obNXPasAST,
  obNXPasParser;

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
  FSymbols := TNXPasSymbolTable.Create(True);
end;

destructor TNXPasIndexedFile.Destroy;
begin
  FreeAndNil(FSymbols);
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
  Result.Symbols.Clear;

  lParser := TNXPasParser.Create(Result.Diagnostics);
  lExtractor := TNXPasSymbolExtractor.Create;
  lTree := nil;
  try
    lTree := lParser.Parse(ASource);
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
