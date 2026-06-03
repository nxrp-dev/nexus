unit obNXPasLanguageContext;

{$mode objfpc}{$H+}

interface

uses
  obNXPasDocumentAnalysis,
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
    function ReindexSource(ASource: TNXPasSourceFile): TNXPasIndexedFile;

    property Analyzer: TNXPasAnalyzer read FAnalyzer;
    property SearchPaths: TNXPasSearchPathContext read FSearchPaths;
    property UnitResolver: TNXPasSearchPathUnitResolver read FUnitResolver;
    property WorkspaceIndex: TNXPasWorkspaceIndex read FWorkspaceIndex;
  end;

implementation

uses
  SysUtils;

constructor TNXPasLanguageContext.Create;
begin
  inherited Create;
  FAnalyzer := TNXPasAnalyzer.Create;
  FSearchPaths := TNXPasSearchPathContext.Create;
  FUnitResolver := TNXPasSearchPathUnitResolver.Create(FSearchPaths);
  FWorkspaceIndex := TNXPasWorkspaceIndex.Create;
  FWorkspaceIndex.UnitResolver := FUnitResolver;
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

function TNXPasLanguageContext.ReindexSource(
  ASource: TNXPasSourceFile): TNXPasIndexedFile;
var
  lAnalysis: TNXPasDocumentAnalysis;
begin
  lAnalysis := nil;
  try
    lAnalysis := AnalyzeSource(ASource);
    Result := ReindexAnalysis(lAnalysis);
  finally
    lAnalysis.Free;
  end;
end;

end.
