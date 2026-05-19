unit obNXCheckBox;

{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform,
  obNXControl;

type
  TNXCheckBox = class(TNXControl)
  private
    FValue: Boolean;
    FExcGroup: Integer;
  protected
    procedure SetValue(NewValue: Boolean); virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    procedure Render; override;
    procedure DoMouseClick(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure BoxChecked; virtual;
    procedure BoxUnchecked; virtual;

    property Value: Boolean read FValue write SetValue;
    property ExcGroup: Integer read FExcGroup write FExcGroup;
  end;

implementation

constructor TNXCheckBox.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FillStyle := FS_None;
  ExcGroup := 0;
end;

procedure TNXCheckBox.SetValue(NewValue: Boolean);
begin
  if FValue <> NewValue then
  begin
    FValue := NewValue;
    if NewValue then
      BoxChecked
    else
      BoxUnchecked;
  end;
end;

procedure TNXCheckBox.Render;
var
  r: TNXRect;
begin
  r.w := 20;
  r.h := 20;
  r.x := AbsLeft + 3;
  r.y := AbsTop + 3;

  if MouseEntered then
    RenderFilledRect(r, Skin.SelectedColor)
  else
    RenderFilledRect(r, BackColor);
  RenderRect(r, CurBorderColor);

  r.w := 11;
  r.h := 11;
  r.x := AbsLeft + 8;
  r.y := AbsTop + 8;

  if Value then
    RenderFilledRect(r, ForeColor);
  RenderText(Caption, 30, 5, Align_Left);
end;

procedure TNXCheckBox.DoMouseClick(AX, AY: Integer; AButton: TNXMouseButton);
var
  lIndex: Integer;
  lData: TNXCheckBox;
begin
  inherited;

  if ExcGroup = 0 then
  begin
    SetValue(not Value);
  end
  else if not Value then
  begin
    SetValue(True);

    for lIndex := 0 to Parent.Children.Count - 1 do
    begin
      if Parent.Children[lIndex] is TNXCheckBox then
      begin
        lData := Parent.Children[lIndex] as TNXCheckBox;
        if Parent.Children[lIndex] <> Self then
          if lData.ExcGroup = ExcGroup then
            lData.Value := False;
      end;
    end;
  end;
end;

procedure TNXCheckBox.BoxChecked;
begin

end;

procedure TNXCheckBox.BoxUnchecked;
begin

end;

end.
