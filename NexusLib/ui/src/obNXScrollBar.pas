unit obNXScrollBar;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Math,
  tpNXPlatform,
  obNXControl;

type
  TNXScrollBar = class(TNXControl)
  private
    FAutoAlign: Boolean;
    FAutoAlignBoth: Boolean;
    FDir: TDirection;
    FDragging: Boolean;
    FDragOffset: Integer;
    FMaxVal: Integer;
    FMinVal: Integer;
    FOnChange: TNotifyEvent;
    FPageSize: Integer;
    FValue: Integer;

    function GetThumbRect: TNXRect;
    function GetThumbSize: Integer;
    function GetTrackSize: Integer;
    function TrackPositionToValue(APosition: Integer): Integer;
  protected
    procedure SetAutoAlign(AValue: Boolean);
    procedure SetAutoAlignBoth(AValue: Boolean);
    procedure SetMax(AValue: Integer);
    procedure SetMin(AValue: Integer);
    procedure SetPageSize(AValue: Integer);
    procedure SetValue(AValue: Integer);
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    procedure Render; override;
    procedure ParentSizeCallback(NewW, NewH: Integer); override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(X, Y: Integer; Button: TNXMouseButton); override;
    procedure ctrl_ValueChanged(AValue: Integer); virtual;
    procedure ValueChanged(AValue: Integer); virtual;

    property Min: Integer read FMinVal write SetMin;
    property Max: Integer read FMaxVal write SetMax;
    property PageSize: Integer read FPageSize write SetPageSize;
    property Value: Integer read FValue write SetValue;
    property Dir: TDirection read FDir write FDir;
    property AutoAlign: Boolean read FAutoAlign write SetAutoAlign;
    property AutoAlignBoth: Boolean read FAutoAlignBoth write SetAutoAlignBoth;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

constructor TNXScrollBar.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FillStyle := FS_None;
  Min := 0;
  Max := 100;
end;

function TNXScrollBar.GetTrackSize: Integer;
begin
  case Dir of
    Dir_Horizontal:
      Result := Width;
    Dir_Vertical:
      Result := Height;
  end;
end;

function TNXScrollBar.GetThumbSize: Integer;
var
  lRange: Integer;
  lTrackSize: Integer;
begin
  lTrackSize := GetTrackSize;
  if lTrackSize <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  Result := Math.Min(GUI_ScrollbarSize, lTrackSize);
  lRange := Max - Min;
  if (PageSize > 0) and (lRange > 0) then
    Result := Math.Max(Result, (PageSize * lTrackSize) div
      Math.Max(1, PageSize + lRange));

  Result := EnsureRange(Result, 1, lTrackSize);
end;

function TNXScrollBar.GetThumbRect: TNXRect;
var
  lRange: Integer;
  lThumbSize: Integer;
  lTrackSize: Integer;
  lTravelSize: Integer;
  lPosition: Integer;
begin
  lRange := Max - Min;
  lTrackSize := GetTrackSize;
  lThumbSize := GetThumbSize;
  lTravelSize := Math.Max(0, lTrackSize - lThumbSize);

  if (lRange > 0) and (lTravelSize > 0) then
    lPosition := ((Value - Min) * lTravelSize) div lRange
  else
    lPosition := 0;

  case Dir of
    Dir_Horizontal:
      Result := MakeNXRect(lPosition, (Height - GUI_ScrollbarSize) div 2,
        lThumbSize, Math.Min(GUI_ScrollbarSize, Height));
    Dir_Vertical:
      Result := MakeNXRect((Width - GUI_ScrollbarSize) div 2, lPosition,
        Math.Min(GUI_ScrollbarSize, Width), lThumbSize);
  end;
end;

function TNXScrollBar.TrackPositionToValue(APosition: Integer): Integer;
var
  lRange: Integer;
  lThumbSize: Integer;
  lTrackSize: Integer;
  lTravelSize: Integer;
begin
  lRange := Max - Min;
  lTrackSize := GetTrackSize;
  lThumbSize := GetThumbSize;
  lTravelSize := Math.Max(0, lTrackSize - lThumbSize);

  if (lRange <= 0) or (lTravelSize <= 0) then
    Result := Min
  else
    Result := Min + (EnsureRange(APosition, 0, lTravelSize) * lRange) div
      lTravelSize;
end;

procedure TNXScrollBar.Render;
var
  lThumbRect: TNXRect;
begin
  case Dir of
    Dir_Horizontal:
      RenderLine(0, Height div 2, Width - 1, Height div 2, BorderColor);
    Dir_Vertical:
      RenderLine(Width div 2, 0, Width div 2, Height - 1, BorderColor);
  end;

  lThumbRect := GetThumbRect;
  if MouseEntered or FDragging then
    RenderFilledRect(lThumbRect, Skin.SelectedColor)
  else
    RenderFilledRect(lThumbRect, BackColor);
  RenderRect(lThumbRect, CurBorderColor);
end;

procedure TNXScrollBar.SetAutoAlign(AValue: Boolean);
begin
  FAutoAlign := AValue;
  if AutoAlign then
    if Parent <> nil then
      ParentSizeCallback(Parent.Width, Parent.Height);
end;

procedure TNXScrollBar.SetAutoAlignBoth(AValue: Boolean);
begin
  FAutoAlignBoth := AValue;
  if AutoAlignBoth then
    if Parent <> nil then
      ParentSizeCallback(Parent.Width, Parent.Height);
end;

procedure TNXScrollBar.SetMin(AValue: Integer);
begin
  if FMinVal = AValue then
    Exit;

  FMinVal := AValue;
  if FMaxVal < FMinVal then
    FMaxVal := FMinVal;
  SetValue(FValue);
end;

procedure TNXScrollBar.SetMax(AValue: Integer);
begin
  AValue := Math.Max(Min, AValue);
  if FMaxVal = AValue then
    Exit;

  FMaxVal := AValue;
  SetValue(FValue);
end;

procedure TNXScrollBar.SetPageSize(AValue: Integer);
begin
  FPageSize := Math.Max(0, AValue);
end;

procedure TNXScrollBar.SetValue(AValue: Integer);
var
  lValue: Integer;
begin
  lValue := EnsureRange(AValue, Min, Max);
  if FValue = lValue then
    Exit;

  FValue := lValue;
  ctrl_ValueChanged(FValue);
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
  lPosition: Integer;
  lRange: Integer;
  lThumbRect: TNXRect;
begin
  inherited;
  if Button = mbLeft then
  begin
    lRange := Max - Min;
    if lRange <= 0 then
      Exit;

    lThumbRect := GetThumbRect;
    case Dir of
      Dir_Horizontal:
        lPosition := X;
      Dir_Vertical:
        lPosition := Y;
    end;

    if NXRectContainsPoint(lThumbRect, X, Y) then
      case Dir of
        Dir_Horizontal:
          FDragOffset := lPosition - lThumbRect.x;
        Dir_Vertical:
          FDragOffset := lPosition - lThumbRect.y;
      end
    else
    begin
      FDragOffset := GetThumbSize div 2;
      Value := TrackPositionToValue(lPosition - FDragOffset);
    end;

    FDragging := True;
    CaptureMouse;
  end;
end;

procedure TNXScrollBar.DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons);
var
  lPosition: Integer;
begin
  inherited;

  if not FDragging then
    Exit;

  if not (mbLeft in ButtonState) then
  begin
    FDragging := False;
    ReleaseMouseCapture;
    Exit;
  end;

  case Dir of
    Dir_Horizontal:
      lPosition := X;
    Dir_Vertical:
      lPosition := Y;
  end;

  Value := TrackPositionToValue(lPosition - FDragOffset);
end;

procedure TNXScrollBar.DoMouseUp(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited;
  if Button = mbLeft then
  begin
    FDragging := False;
    ReleaseMouseCapture;
  end;
end;

procedure TNXScrollBar.ctrl_ValueChanged(AValue: Integer);
begin
  ValueChanged(AValue);
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TNXScrollBar.ValueChanged(AValue: Integer);
begin

end;

end.
