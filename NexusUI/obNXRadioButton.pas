unit obNXRadioButton;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  tpNXPlatform,
  obNXControl,
  obNXCheckBox;

type
  TNXRadioButton = class(TNXCheckBox)
  private
    FGroupName: string;
    procedure ClearGroupSiblings;
    procedure DrawRadioRing(const ARect: TNXRect; const AColor: TNXColor);
    procedure DrawRadioDot(const ARect: TNXRect; const AColor: TNXColor);
  protected
    procedure SetValue(AValue: Boolean); override;
    procedure ToggleValue; override;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    procedure Render; override;

    property GroupName: string read FGroupName write FGroupName;
  end;

implementation

constructor TNXRadioButton.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  SkinClass := 'RadioButton';
end;

procedure TNXRadioButton.ClearGroupSiblings;
var
  lControl: TNXControl;
  lIndex: Integer;
  lSibling: TNXRadioButton;
begin
  if (FGroupName = '') or (Parent = nil) then
    Exit;

  for lIndex := 0 to Parent.Children.Count - 1 do
  begin
    lControl := Parent.Children[lIndex];
    if (lControl <> Self) and (lControl is TNXRadioButton) then
    begin
      lSibling := TNXRadioButton(lControl);
      if SameText(lSibling.GroupName, FGroupName) then
        lSibling.Value := False;
    end;
  end;
end;

procedure TNXRadioButton.DrawRadioRing(const ARect: TNXRect;
  const AColor: TNXColor);
var
  lLeft: Integer;
  lTop: Integer;
  lRight: Integer;
  lBottom: Integer;
  lInset: Integer;
begin
  lLeft := ARect.x;
  lTop := ARect.y;
  lRight := ARect.x + ARect.w - 1;
  lBottom := ARect.y + ARect.h - 1;
  lInset := ARect.w div 4;
  if lInset < 3 then
    lInset := 3;

  RenderLine(lLeft + lInset, lTop, lRight - lInset, lTop, AColor);
  RenderLine(lRight - lInset, lTop, lRight, lTop + lInset, AColor);
  RenderLine(lRight, lTop + lInset, lRight, lBottom - lInset, AColor);
  RenderLine(lRight, lBottom - lInset, lRight - lInset, lBottom, AColor);
  RenderLine(lRight - lInset, lBottom, lLeft + lInset, lBottom, AColor);
  RenderLine(lLeft + lInset, lBottom, lLeft, lBottom - lInset, AColor);
  RenderLine(lLeft, lBottom - lInset, lLeft, lTop + lInset, AColor);
  RenderLine(lLeft, lTop + lInset, lLeft + lInset, lTop, AColor);
end;

procedure TNXRadioButton.DrawRadioDot(const ARect: TNXRect;
  const AColor: TNXColor);
var
  lSize: Integer;
  lRect: TNXRect;
begin
  lSize := ARect.w div 3;
  if lSize < 4 then
    lSize := 4;

  lRect := MakeNXRect(ARect.x + ((ARect.w - lSize) div 2),
    ARect.y + ((ARect.h - lSize) div 2), lSize, lSize);
  RenderFilledRect(lRect, AColor);
end;

procedure TNXRadioButton.SetValue(AValue: Boolean);
begin
  if AValue then
    ClearGroupSiblings;

  inherited SetValue(AValue);
end;

procedure TNXRadioButton.ToggleValue;
begin
  if Value then
    Exit;

  Value := True;
end;

procedure TNXRadioButton.Render;
var
  lBoxRect: TNXRect;
begin
  lBoxRect := GetBoxRect;

  RenderFilledRect(lBoxRect, GetBoxStateColor);
  DrawRadioRing(lBoxRect, CurBorderColor);

  if Value then
    DrawRadioDot(lBoxRect, GetMarkColor);

  if IsSelected then
    RenderRect(MakeNXRect(AbsLeft, AbsTop, Width, Height), ForeColor);

  RenderText(Caption, GetTextLeft, GetTextTop, Align_Left);
end;

end.
