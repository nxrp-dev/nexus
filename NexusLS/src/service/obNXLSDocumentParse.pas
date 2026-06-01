unit obNXLSDocumentParse;

{$mode objfpc}{$H+}

interface

uses
  obNXLSServiceContext,
  obNXPasAST,
  obNXPasDiagnostics,
  obNXPasSource;

type
  TNXLSDocumentParseResult = class
  private
    FDiagnostics: TNXPasDiagnosticList;
    FSource: TNXPasSourceFile;
    FTree: TNXPasSyntaxTree;
  public
    constructor Create(ADocument: TNXLSDocument);
    destructor Destroy; override;

    property Diagnostics: TNXPasDiagnosticList read FDiagnostics;
    property Source: TNXPasSourceFile read FSource;
    property Tree: TNXPasSyntaxTree read FTree;
  end;

implementation

uses
  SysUtils,
  obNXPasParser;

constructor TNXLSDocumentParseResult.Create(ADocument: TNXLSDocument);
var
  lParser: TNXPasParser;
begin
  inherited Create;
  if ADocument = nil then
    raise Exception.Create('Document is required.');

  FSource := TNXPasSourceFile.Create(ADocument.LocalPath, ADocument.URI,
    ADocument.Text);
  FDiagnostics := TNXPasDiagnosticList.Create(True);

  lParser := TNXPasParser.Create(FDiagnostics);
  try
    FTree := lParser.Parse(FSource);
  finally
    lParser.Free;
  end;
end;

destructor TNXLSDocumentParseResult.Destroy;
begin
  FreeAndNil(FTree);
  FreeAndNil(FDiagnostics);
  FreeAndNil(FSource);
  inherited Destroy;
end;

end.
