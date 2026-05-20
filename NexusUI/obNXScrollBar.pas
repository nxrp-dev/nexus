unit obNXScrollBar;

{$mode objfpc}{$H+}

interface

uses
  Math,
  tpNXPlatform,
  obNXControl;

type
  TNXScrollBar = class(TNXControl)
  private
    FMinVal, FMaxVal, FValue: Integer;
    FDir: TDirection;
    Moving: Boolean;
    FAutoAlign, FAutoAlignBoth: Boolean;
  protected
    procedure SetValue(NewValue: Integer);
    procedure SetAutoAlign(NewValue: Boolean);
    procedure SetAutoAlignBoth(NewValue: Boolean);
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    procedure Render; override;
    procedure ParentSizeCallback(NewW, NewH: Integer); override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(X, Y: Integer; Button: TNXMouseButton); override;
    procedure ctrl_ValueChanged(NewValue: Integer); virtual;
    procedure ValueChanged(NewValue: Integer); virtual;

    property Min: Integer read FMinVal write FMinVal;
    property Max: Integer read FMaxVal write FMaxVal;
    property Value: Integer read FValue write SetValue;
    property Dir: TDirection read FDir write FDir;
    property AutoAlign: Boolean read FAutoAlign write SetAutoAlign;
    property AutoAlignBoth: Boolean read FAutoAlignBoth write SetAutoAlignBoth;
  end;

implementation

constructor TNXScrollBar.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FillStyle := FS_None;
  Min := 0;
  Max := 100;
end;

procedure TNXScrollBar.Render;
var
  r: TNXRect;
  lRange: Integer;
  lTrackSize: Integer;
begin
  lRange := Max - Min;

  case Dir of
    Dir_Horizontal:
    begin
      RenderLine(0, Height div 2, Width - 1, Height div 2, BorderColor);
      r.w := GUI_ScrollbarSize;
      r.h := GUI_ScrollbarSize;
      lTrackSize := Width - r.w - 2;
      if (lRange > 0) and (lTrackSize > 0) then
        r.x := Floor(((Value - Min) * lTrackSize) / lRange)
      else
        r.x := 0;
      r.y := (Height - r.h) div 2;
    end;
    Dir_Vertical:
    begin
      RenderLine(Width div 2, 0, Width div 2, Height, BorderColor);
      r.w := GUI_ScrollbarSize;
      r.h := GUI_ScrollbarSize;
      lTrackSize := Height - r.h - 1;
      if (lRange > 0) and (lTrackSize > 0) then
        r.y := Floor(((Value - Min) * lTrackSize) / lRange)
      else
        r.y := 0;
      r.x := (Width - r.w) div 2;
    end;
  end;

  if MouseEntered or Moving then
    RenderFilledRect(r, Skin.SelectedColor)
  else
    RenderFilledRect(r, BackColor);
  RenderRect(r, CurBorderColor);
end;

procedure TNXScrollBar.SetValue(NewValue: Integer);
begin
  FValue := Math.Max(Min, NewValue);
  FValue := Math.Min(Max, FValue);
  ctrl_ValueChanged(FValue);
end;

procedure TNXScrollBar.SetAutoAlign(NewValue: Boolean);
begin
  FAutoAlign := NewValue;
  if AutoAlign then
    if Parent <> nil then
      ParentSizeCallback(Parent.Width, Parent.Height);
end;

procedure TNXScrollBar.SetAutoAlignBoth(NewValue: Boolean);
begin
  FAutoAlignBoth := NewValue;
  if AutoAlignBoth then
    if Parent <> nil then
      ParentSizeCallback(Parent.Width, Parent.Height);
end;

procedure TNXScrollBar.ParentSizeCallback(NewW, NewH: Integer);
begin
  if AutoAlign then
  begin
    case Dir of
      Dir_Horizontal:
      begin
        Left := 2;
        Width := NewW - IfThen(AutoAlignBoth, GUI_ScrollbarSize) - 4;
        Top := NewH - GUI_ScrollBarSize - 4;
        Height := GUI_ScrollBarSize + 1;
      end;
      Dir_Vertical:
      begin
        Top := 2;
        Height := NewH - IfThen(AutoAlignBoth, GUI_ScrollbarSize) - 4;
        Left := NewW - GUI_ScrollBarSize - 4;
        Width := GUI_ScrollBarSize + 1;
      end;
    end;
  end;
end;

procedure TNXScrollBar.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  NewVal: Integer;
  lRange: Integer;
begin
  inherited;
  if Button = mbLeft then
  begin
    lRange := Max - Min;
    if lRange <= 0 then
      Exit;

    case Dir of
      Dir_Horizontal:
      begin
        if Width <= 0 then
          Exit;
        NewVal := Min + (X * lRange) div Width;
      end;
      Dir_Vertical:
      begin
        if Height <= 0 then
          Exit;
        NewVal := Min + (Y * lRange) div Height;
      end;
    end;
    NewVal := Math.Max(Min, NewVal);
    NewVal := Math.Min(Max, NewVal);
    Value := NewVal;
    Moving := True;
    CaptureMouse;
  end;
end;

procedure TNXScrollBar.DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons);
var
  NewVal: Integer;
  lRange: Integer;
begin
  inherited;

  if not Moving then
    Exit;

  if not (mbLeft in ButtonState) then
  begin
    Moving := False;
    ReleaseMouseCapture;
    Exit;
  end;

  lRange := Max - Min;
  if lRange <= 0 then
    Exit;

  case Dir of
    Dir_Horizontal:
    begin
      if Width <= 6 then
        Exit;
      NewVal := Min + (X * lRange) div (Width - 6);
    end;
    Dir_Vertical:
    begin
      if Height <= 6 then
        Exit;
      NewVal := Min + (Y * lRange) div (Height - 6);
    end;
  end;

  NewVal := Math.Max(Min, NewVal);
  NewVal := Math.Min(Max, NewVal);
  Value := NewVal;
end;

procedure TNXScrollBar.DoMouseUp(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited;
  if Button = mbLeft then
  begin
    Moving := False;
    ReleaseMouseCapture;
  end;
end;

procedure TNXScrollBar.ctrl_ValueChanged(NewValue: Integer);
begin
  ValueChanged(NewValue);
end;

procedure TNXScrollBar.ValueChanged(NewValue: Integer);
begin

end;

end.
