unit obNXButton;

{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform,
  tpNXSkin,
  obNXControl;

type
  TNXButton = class(TNXControl)
  protected
    function GetSkinState: TNXSkinState; virtual;
    function TryRenderSkinnedBackground: Boolean; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    procedure Render; override;
    procedure DoMouseEnter; override;
    procedure DoMouseExit; override;
  end;

implementation

const
  cButtonBackgroundPart = 'Background';

constructor TNXButton.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  BorderStyle := BS_Single;
  SkinClass := 'Button';
end;

function TNXButton.GetSkinState: TNXSkinState;
begin
  if not Enabled then
    Result := ssDisabled
  else if mbLeft in ButtonStates then
    Result := ssPressed
  else if MouseEntered then
    Result := ssHot
  else if IsSelected then
    Result := ssFocused
  else
    Result := ssNormal;
end;

function TNXButton.TryRenderSkinnedBackground: Boolean;
var
  lRect: TNXRect;
  lSlice: TNXNineSlice;
begin
  Result := False;

  if (SkinClass = '') or (Skin = nil) or (Canvas = nil) then
    Exit;

  Result := Skin.GetNineSlice(SkinClass, cButtonBackgroundPart,
    GetSkinState, lSlice);
  if (not Result) or (lSlice.Image = nil) then
  begin
    Result := False;
    Exit;
  end;

  lRect := MakeNXRect(AbsLeft, AbsTop, Width, Height);
  Canvas.DrawNineSlice(lSlice.Image, lSlice.SourceRect, lSlice.Left,
    lSlice.Top, lSlice.Right, lSlice.Bottom, lRect);
end;

procedure TNXButton.Render;
begin
  if not TryRenderSkinnedBackground then
  begin
    if mbLeft in ButtonStates then
      CurFillColor := ActiveColor
    else
      CurFillColor := BackColor;
    inherited Render;
  end;

  RenderText(Caption, Width div 2, (Height - FontHeight) div 2,
    Align_Center);
end;

procedure TNXButton.DoMouseEnter;
begin
  inherited;
  CurBorderColor := ForeColor;
end;

procedure TNXButton.DoMouseExit;
begin
  inherited;
  CurBorderColor := BorderColor;
end;

end.
