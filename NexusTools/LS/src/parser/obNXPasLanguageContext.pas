unit obNXPasLanguageContext;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXPasDocumentAnalysis,
  obNXPasMetadata,
  obNXPasProject,
  obNXPasSearchPaths,
  obNXPasSource,
  obNXPasUnitResolver,
  obNXPasWorkspaceIndex;

type
  TNXPasLanguageContext = class
  private
    FAnalyzer: TNXPasAnalyzer;
    FSearchPaths: TNXPasSearchPathContext;
    FUnitResolver: TNXPasSearchPathUnitResolver;
    FWorkspaceIndex: TNXPasWorkspaceIndex;
  public
    constructor Create;
    destructor Destroy; override;

    function AnalyzeSource(ASource: TNXPasSourceFile): TNXPasDocumentAnalysis;
    procedure ClearWorkspaceIndex;
    function ReindexAnalysis(AAnalysis: TNXPasDocumentAnalysis):
      TNXPasIndexedFile;
    function ReindexProject(AProject: TNXPasProject): Integer;
    function ReindexSource(ASource: TNXPasSourceFile): TNXPasIndexedFile;
    function EnsureUsedUnitsIndexedForFile(AFile: TNXPasIndexedFile): Integer;
    function EnsureUsedUnitsIndexedForURI(const AURI: string): Integer;
    function ResolveUnitReference(const AUnitName: string): TNXPasIndexedFile;

    property Analyzer: TNXPasAnalyzer read FAnalyzer;
    property SearchPaths: TNXPasSearchPathContext read FSearchPaths;
    property UnitResolver: TNXPasSearchPathUnitResolver read FUnitResolver;
    property WorkspaceIndex: TNXPasWorkspaceIndex read FWorkspaceIndex;
  end;

implementation

uses
  SysUtils,
  obNXPasUnitLocator;

constructor TNXPasLanguageContext.Create;
begin
  inherited Create;
  FAnalyzer := TNXPasAnalyzer.Create;
  FSearchPaths := TNXPasSearchPathContext.Create;
  FUnitResolver := TNXPasSearchPathUnitResolver.Create(FSearchPaths);
  FWorkspaceIndex := TNXPasWorkspaceIndex.Create;
end;

destructor TNXPasLanguageContext.Destroy;
begin
  FreeAndNil(FWorkspaceIndex);
  FreeAndNil(FUnitResolver);
  FreeAndNil(FSearchPaths);
  FreeAndNil(FAnalyzer);
  inherited Destroy;
end;

function TNXPasLanguageContext.AnalyzeSource(
  ASource: TNXPasSourceFile): TNXPasDocumentAnalysis;
begin
  Result := FAnalyzer.Analyze(ASource);
end;

procedure TNXPasLanguageContext.ClearWorkspaceIndex;
begin
  FWorkspaceIndex.Clear;
end;

function TNXPasLanguageContext.ReindexAnalysis(
  AAnalysis: TNXPasDocumentAnalysis): TNXPasIndexedFile;
begin
  Result := FWorkspaceIndex.UpdateAnalyzedFile(AAnalysis);
end;

function TNXPasLanguageContext.ReindexProject(AProject: TNXPasProject):
  Integer;
var
  lIdx: Integer;
begin
  Result := 0;
  if AProject = nil then
    Exit;

  for lIdx := 0 to AProject.SourceFileCount - 1 do
  begin
    ReindexSource(AProject.SourceFiles[lIdx]);
    Inc(Result);
  end;
end;

function TNXPasLanguageContext.ReindexSource(
  ASource: TNXPasSourceFile): TNXPasIndexedFile;
var
  lAnalysis: TNXPasDocumentAnalysis;
begin
  Result := nil;
  if ASource = nil then
    Exit;

  lAnalysis := nil;
  try
    lAnalysis := AnalyzeSource(TNXPasSourceFile.Create(ASource.FileName,
      ASource.URI, ASource.Text));
    Result := ReindexAnalysis(lAnalysis);
  finally
    lAnalysis.Free;
  end;
end;

function TNXPasLanguageContext.EnsureUsedUnitsIndexedForFile(
  AFile: TNXPasIndexedFile): Integer;

  procedure EnsureUsesList(AUsesList: TNXPasUsesEntryList);
  var
    lIdx: Integer;
    lUsesEntry: TNXPasUsesEntry;
  begin
    if AUsesList = nil then
      Exit;

    for lIdx := 0 to AUsesList.Count - 1 do
    begin
      lUsesEntry := AUsesList.EntryAt(lIdx);
      if (lUsesEntry = nil) or (not lUsesEntry.Active) then
        Continue;
      if ResolveUnitReference(lUsesEntry.UnitName) <> nil then
        Inc(Result);
    end;
  end;

begin
  Result := 0;
  if (AFile = nil) or (AFile.Metadata = nil) then
    Exit;

  EnsureUsesList(AFile.Metadata.InterfaceUses);
  EnsureUsesList(AFile.Metadata.ImplementationUses);
end;

function TNXPasLanguageContext.EnsureUsedUnitsIndexedForURI(
  const AURI: string): Integer;
begin
  Result := EnsureUsedUnitsIndexedForFile(FWorkspaceIndex.FindFileByURI(AURI));
end;

function TNXPasLanguageContext.ResolveUnitReference(
  const AUnitName: string): TNXPasIndexedFile;
var
  lFileName: string;
  lSource: TNXPasSourceFile;
  lText: TStringList;
  lURI: string;
begin
  Result := FWorkspaceIndex.FindFileByUnitName(AUnitName);
  if Result <> nil then
    Exit;

  if (FUnitResolver = nil) or
    (not FUnitResolver.LocateUnitFile(AUnitName,
    FWorkspaceIndex.LocalSourceDirs, lFileName)) then
    Exit(nil);

  lText := TStringList.Create;
  lSource := nil;
  try
    lText.LoadFromFile(lFileName);
    lURI := TNXPasUnitLocator.PathToFileURI(lFileName);
    lSource := TNXPasSourceFile.Create(lFileName, lURI, lText.Text);
    Result := ReindexSource(lSource);
    FWorkspaceIndex.Log.Add('resolved uses unit: ' + AUnitName + ' -> ' +
      lFileName);
  finally
    lSource.Free;
    lText.Free;
  end;
end;

end.
