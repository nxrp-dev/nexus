unit obNXRenderAppearance;

{$mode objfpc}{$H+}

interface

uses obNXRender, obNXSkinPalette, tpNXSkin;

type
  // Scalar snapshots for Lua. Borrows the skin palette; owns no font resource.
  TNXRenderAppearance = class(TNXRenderResources)
  private
    FPalette: TNXSkinPalette;
    FIntent: TNXSkinIntent;
    FColor: LongWord;
    FFontDesc: string;
  public
    constructor Create(APalette: TNXSkinPalette; AIntent: TNXSkinIntent);
    procedure Prepare(const ARenderName: string;
      AState: TNexusControlState); override;
  published
    property Color: LongWord read FColor;
    property FontDesc: string read FFontDesc;
  end;

implementation

constructor TNXRenderAppearance.Create(APalette: TNXSkinPalette;
  AIntent: TNXSkinIntent);
begin
  inherited Create;
  FPalette := APalette;
  FIntent := AIntent;
end;

procedure TNXRenderAppearance.Prepare(const ARenderName: string;
  AState: TNexusControlState);
var
  lValue: TNXSkinAppearance;
begin
  lValue := FPalette.Resolve(ARenderName, FIntent, AState.States);
  FColor := LongWord(lValue.Color);
  FFontDesc := lValue.FontDesc;
end;

end.
