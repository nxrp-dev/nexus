unit obNXPasDocumentAnalysis;

{$mode objfpc}{$H+}

interface

uses
  obNXPasAST,
  obNXPasDiagnostics,
  obNXPasMetadata,
  obNXPasSymbols,
  obNXPasSource;

type
  TNXPasAnalyzer = class;

  TNXPasDocumentAnalysis = class
  private
    FDiagnostics: TNXPasDiagnosticList;
    FSource: TNXPasSourceFile;
    FSymbols: TNXPasSymbolTable;
    FTree: TNXPasSyntaxTree;
    function GetInactiveRegions: TNXPasInactiveRegionList;
    function GetMetadata: TNXPasUnitMetadata;
  public
    constructor Create(ASource: TNXPasSourceFile);
    destructor Destroy; override;

    property Diagnostics: TNXPasDiagnosticList read FDiagnostics;
    property InactiveRegions: TNXPasInactiveRegionList read GetInactiveRegions;
    property Metadata: TNXPasUnitMetadata read GetMetadata;
    property Source: TNXPasSourceFile read FSource;
    property Symbols: TNXPasSymbolTable read FSymbols;
    property SyntaxTree: TNXPasSyntaxTree read FTree;
    property Tree: TNXPasSyntaxTree read FTree;
  end;

  TNXPasAnalyzer = class
  public
    procedure AnalyzeInto(AAnalysis: TNXPasDocumentAnalysis);
    function Analyze(ASource: TNXPasSourceFile): TNXPasDocumentAnalysis;
  end;

implementation

uses
  SysUtils,
  obNXPasParser;

constructor TNXPasDocumentAnalysis.Create(ASource: TNXPasSourceFile);
begin
  inherited Create;
  if ASource = nil then
    raise Exception.Create('Source is required.');

  FSource := ASource;
  FDiagnostics := TNXPasDiagnosticList.Create(True);
  FSymbols := TNXPasSymbolTable.Create(True);
end;

destructor TNXPasDocumentAnalysis.Destroy;
begin
  FreeAndNil(FTree);
  FreeAndNil(FSymbols);
  FreeAndNil(FDiagnostics);
  FreeAndNil(FSource);
  inherited Destroy;
end;

function TNXPasDocumentAnalysis.GetInactiveRegions: TNXPasInactiveRegionList;
begin
  if FTree = nil then
    Result := nil
  else
    Result := FTree.InactiveRegions;
end;

function TNXPasDocumentAnalysis.GetMetadata: TNXPasUnitMetadata;
begin
  if FTree = nil then
    Result := nil
  else
    Result := FTree.Metadata;
end;

procedure TNXPasAnalyzer.AnalyzeInto(AAnalysis: TNXPasDocumentAnalysis);
var
  lExtractor: TNXPasSymbolExtractor;
  lParser: TNXPasParser;
begin
  if AAnalysis = nil then
    Exit;

  AAnalysis.Diagnostics.Clear;
  AAnalysis.Symbols.Clear;
  FreeAndNil(AAnalysis.FTree);

  lParser := TNXPasParser.Create(AAnalysis.Diagnostics);
  try
    AAnalysis.FTree := lParser.Parse(AAnalysis.Source);
  finally
    lParser.Free;
  end;

  lExtractor := TNXPasSymbolExtractor.Create;
  try
    lExtractor.Extract(AAnalysis.SyntaxTree, AAnalysis.Symbols);
  finally
    lExtractor.Free;
  end;
end;

function TNXPasAnalyzer.Analyze(
  ASource: TNXPasSourceFile): TNXPasDocumentAnalysis;
begin
  Result := TNXPasDocumentAnalysis.Create(ASource);
  try
    AnalyzeInto(Result);
  except
    Result.Free;
    raise;
  end;
end;

end.
