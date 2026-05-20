unit obNXCheckBox;

{$mode objfpc}{$H+}

interface

uses
  tpNXEvents,
  tpNXPlatform,
  obNXControl;

type
  TNXCheckBox = class(TNXControl)
  private
    FValue: Boolean;
  protected
    function GetBoxRect: TNXRect; virtual;
    function GetBoxStateColor: TNXColor; virtual;
    function GetMarkColor: TNXColor; virtual;
    function GetTextLeft: Integer; virtual;
    function GetTextTop: Integer; virtual;
    procedure SetValue(AValue: Boolean); virtual;
    procedure ToggleValue; virtual;
    procedure ValueChanged; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    procedure Render; override;
    procedure DoMouseClick(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure BoxChecked; virtual;
    procedure BoxUnchecked; virtual;

    property Value: Boolean read FValue write SetValue;
  end;

implementation

const
  cDefaultCheckBoxWidth = 150;
  cDefaultCheckBoxHeight = 24;
  cBoxPadding = 4;
  cBoxTextSpacing = 8;
  cMinBoxSize = 12;
  cMaxBoxSize = 18;

constructor TNXCheckBox.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  Width := cDefaultCheckBoxWidth;
  Height := cDefaultCheckBoxHeight;
  FillStyle := FS_None;
  BorderStyle := BS_None;
  Selectable := True;
  SkinClass := 'CheckBox';
end;

function TNXCheckBox.GetBoxRect: TNXRect;
var
  lSize: Integer;
begin
  lSize := Height - (cBoxPadding * 2);

  if lSize < cMinBoxSize then
    lSize := cMinBoxSize
  else if lSize > cMaxBoxSize then
    lSize := cMaxBoxSize;

  Result := MakeNXRect(cBoxPadding, (Height - lSize) div 2, lSize, lSize);
end;

function TNXCheckBox.GetBoxStateColor: TNXColor;
begin
  Result := BackColor;

  if not Enabled then
    Result := Skin.TextBackColor
  else if mbLeft in ButtonStates then
    Result := ActiveColor
  else if MouseEntered or IsSelected then
    Result := Skin.SelectedColor;
end;

function TNXCheckBox.GetMarkColor: TNXColor;
begin
  if Enabled then
    Result := ForeColor
  else
    Result := BorderColor;
end;

function TNXCheckBox.GetTextLeft: Integer;
var
  lBoxRect: TNXRect;
begin
  lBoxRect := GetBoxRect;
  Result := lBoxRect.x + lBoxRect.w + cBoxTextSpacing;
end;

function TNXCheckBox.GetTextTop: Integer;
begin
  Result := (Height - FontHeight) div 2;
  if Result < 0 then
    Result := 0;
end;

procedure TNXCheckBox.SetValue(AValue: Boolean);
begin
  if FValue = AValue then
    Exit;

  FValue := AValue;
  ValueChanged;
end;

procedure TNXCheckBox.ToggleValue;
begin
  Value := not FValue;
end;

procedure TNXCheckBox.ValueChanged;
begin
  if FValue then
    BoxChecked
  else
    BoxUnchecked;
end;

procedure TNXCheckBox.Render;
var
  lBoxRect: TNXRect;
  lMarkColor: TNXColor;
begin
  lBoxRect := GetBoxRect;

  RenderFilledRect(lBoxRect, GetBoxStateColor);
  RenderRect(lBoxRect, CurBorderColor);

  if Value then
  begin
    lMarkColor := GetMarkColor;
    RenderLine(lBoxRect.x + 3, lBoxRect.y + (lBoxRect.h div 2),
      lBoxRect.x + (lBoxRect.w div 2) - 1, lBoxRect.y + lBoxRect.h - 4,
      lMarkColor);
    RenderLine(lBoxRect.x + (lBoxRect.w div 2) - 1,
      lBoxRect.y + lBoxRect.h - 4, lBoxRect.x + lBoxRect.w - 3,
      lBoxRect.y + 3, lMarkColor);
    RenderLine(lBoxRect.x + 3, lBoxRect.y + (lBoxRect.h div 2) + 1,
      lBoxRect.x + (lBoxRect.w div 2) - 1, lBoxRect.y + lBoxRect.h - 3,
      lMarkColor);
    RenderLine(lBoxRect.x + (lBoxRect.w div 2),
      lBoxRect.y + lBoxRect.h - 4, lBoxRect.x + lBoxRect.w - 2,
      lBoxRect.y + 3, lMarkColor);
  end;

  if IsSelected then
    RenderRect(MakeNXRect(0, 0, Width, Height), ForeColor);

  RenderText(Caption, GetTextLeft, GetTextTop, Align_Left);
end;

procedure TNXCheckBox.DoMouseClick(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited DoMouseClick(AX, AY, AButton);

  if Enabled and (AButton = mbLeft) then
    ToggleValue;
end;

procedure TNXCheckBox.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  if Enabled and (not AEvent.Repeat_) and (AEvent.Key = nkEnter) then
    ToggleValue;
end;

procedure TNXCheckBox.BoxChecked;
begin
end;

procedure TNXCheckBox.BoxUnchecked;
begin
end;

end.
