unit obNXPasUnitResolver;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXPasSearchPaths;

type
  TNXPasUnitResolver = class
  public
    function LocateUnitFile(const AUnitName: string; ALocalPaths: TStrings;
      out AFileName: string): Boolean; virtual; abstract;
  end;

  TNXPasSearchPathUnitResolver = class(TNXPasUnitResolver)
  private
    FSearchPathContext: TNXPasSearchPathContext;
  public
    constructor Create(ASearchPathContext: TNXPasSearchPathContext);
    function LocateUnitFile(const AUnitName: string; ALocalPaths: TStrings;
      out AFileName: string): Boolean; override;

    property SearchPathContext: TNXPasSearchPathContext
      read FSearchPathContext;
  end;

implementation

uses
  obNXPasUnitLocator;

constructor TNXPasSearchPathUnitResolver.Create(
  ASearchPathContext: TNXPasSearchPathContext);
begin
  inherited Create;
  FSearchPathContext := ASearchPathContext;
end;

function TNXPasSearchPathUnitResolver.LocateUnitFile(const AUnitName: string;
  ALocalPaths: TStrings; out AFileName: string): Boolean;
begin
  Result := TNXPasUnitLocator.FindUnitFile(AUnitName, ALocalPaths, AFileName);
  if Result then
    Exit;

  if FSearchPathContext = nil then
    Exit(False);

  Result := TNXPasUnitLocator.FindUnitFile(AUnitName,
    FSearchPathContext.UnitPaths, AFileName);
end;

end.
