unit obNXLSDocumentParse;

{$mode objfpc}{$H+}

interface

uses
  obNXLSServiceContext,
  obNXPasSource;

function NXLSCreatePascalSource(ADocument: TNXLSDocument): TNXPasSourceFile;

implementation

uses
  SysUtils;

function NXLSCreatePascalSource(ADocument: TNXLSDocument): TNXPasSourceFile;
begin
  if ADocument = nil then
    raise Exception.Create('Document is required.');

  Result := TNXPasSourceFile.Create(ADocument.LocalPath, ADocument.URI,
    ADocument.Text);
end;

end.
