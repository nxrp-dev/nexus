unit obNXTrackBar;

{$mode objfpc}{$H+}

interface

uses
  Math,
  tpNXEvents,
  tpNXPlatform,
  obNXControl;

type
  TNXTrackBarChangedEvent = procedure(Sender: TObject; AValue: Integer) of object;

  TNXTrackBar = class(TNXControl)
  private
    FDirection: TDirection;
    FInverted: Boolean;
    FLargeChange: Integer;
    FMax: Integer;
    FMin: Integer;
    FMoving: Boolean;
    FOnChange: TNXTrackBarChangedEvent;
    FShowTicks: Boolean;
    FSmallChange: Integer;
    FThumbSize: Integer;
    FTickFrequency: Integer;
    FValue: Integer;

    function GetRange: Integer;
    function GetTrackLength: Integer;
    function GetValueRatio: Double;
    procedure SetDirection(AValue: TDirection);
    procedure SetInverted(AValue: Boolean);
    procedure SetLargeChange(AValue: Integer);
    procedure SetMax(AValue: Integer);
    procedure SetMin(AValue: Integer);
    procedure SetShowTicks(AValue: Boolean);
    procedure SetSmallChange(AValue: Integer);
    procedure SetThumbSize(AValue: Integer);
    procedure SetTickFrequency(AValue: Integer);
    procedure SetValue(AValue: Integer);
  protected
    function ClampValue(AValue: Integer): Integer; virtual;
    function GetThumbRect: TNXRect; virtual;
    function GetTrackRect: TNXRect; virtual;
    function PositionRatioFromValue(AValue: Integer): Double; virtual;
    function ValueFromPoint(AX, AY: Integer): Integer; virtual;
    procedure ChangeValue(AValue: Integer); virtual;
    procedure DrawTickMarks; virtual;
    procedure DoChange; virtual;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure RenderClient; override;
  public
    constructor Create(const AParent: INXControlParent); override;

    procedure StepBy(ADelta: Integer); virtual;

    property Direction: TDirection read FDirection write SetDirection;
    property Inverted: Boolean read FInverted write SetInverted;
    property LargeChange: Integer read FLargeChange write SetLargeChange;
    property Max: Integer read FMax write SetMax;
    property Min: Integer read FMin write SetMin;
    property ShowTicks: Boolean read FShowTicks write SetShowTicks;
    property SmallChange: Integer read FSmallChange write SetSmallChange;
    property ThumbSize: Integer read FThumbSize write SetThumbSize;
    property TickFrequency: Integer read FTickFrequency write SetTickFrequency;
    property Value: Integer read FValue write SetValue;

    property OnChange: TNXTrackBarChangedEvent read FOnChange write FOnChange;
  end;

implementation

const
  cDefaultThumbSize = 14;
  cTrackThickness = 4;
  cTickSize = 4;

constructor TNXTrackBar.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  FDirection := Dir_Horizontal;
  FInverted := False;
  FMin := 0;
  FMax := 100;
  FValue := 0;
  FSmallChange := 1;
  FLargeChange := 10;
  FThumbSize := cDefaultThumbSize;
  FTickFrequency := 10;
  FShowTicks := True;

  Width := 160;
  Height := 28;
  FillStyle := FS_None;
  BorderStyle := BS_None;
  Selectable := True;
end;

function TNXTrackBar.ClampValue(AValue: Integer): Integer;
begin
  Result := Math.Max(FMin, AValue);
  Result := Math.Min(FMax, Result);
end;

procedure TNXTrackBar.ChangeValue(AValue: Integer);
var
  lValue: Integer;
begin
  lValue := ClampValue(AValue);
  if FValue = lValue then
    Exit;

  FValue := lValue;
  DoChange;
end;

procedure TNXTrackBar.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self, FValue);
end;

procedure TNXTrackBar.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  case AEvent.Key of
    nkLeft,
    nkDown:
      StepBy(-SmallChange);
    nkRight,
    nkUp:
      StepBy(SmallChange);
    nkHome:
      Value := Min;
    nkEnd:
      Value := Max;
  end;
end;

procedure TNXTrackBar.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited DoMouseDown(AX, AY, AButton);

  if (AButton <> mbLeft) or (not Enabled) then
    Exit;

  IsSelected := True;
  Value := ValueFromPoint(AX, AY);
  FMoving := True;
  CaptureMouse;
end;

procedure TNXTrackBar.DoMouseMotion(AX, AY: Integer;
  AButtonState: TNXMouseButtons);
begin
  inherited DoMouseMotion(AX, AY, AButtonState);

  if not FMoving then
    Exit;

  if not (mbLeft in AButtonState) then
  begin
    FMoving := False;
    ReleaseMouseCapture;
    Exit;
  end;

  Value := ValueFromPoint(AX, AY);
end;

procedure TNXTrackBar.DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited DoMouseUp(AX, AY, AButton);

  if AButton <> mbLeft then
    Exit;

  FMoving := False;
  ReleaseMouseCapture;
end;

procedure TNXTrackBar.DrawTickMarks;
var
  lIndex: Integer;
  lRange: Integer;
  lTickValue: Integer;
  lTrackLength: Integer;
  lX: Integer;
  lY: Integer;
  lPositionRatio: Double;
begin
  if (not ShowTicks) or (TickFrequency <= 0) then
    Exit;

  lRange := GetRange;
  if lRange <= 0 then
    Exit;

  lTrackLength := GetTrackLength;
  if lTrackLength <= 0 then
    Exit;

  lIndex := 0;
  while True do
  begin
    lTickValue := Min + (lIndex * TickFrequency);
    if lTickValue > Max then
      Break;

    lPositionRatio := PositionRatioFromValue(lTickValue);

    case Direction of
      Dir_Horizontal:
      begin
        lX := AbsLeft + (ThumbSize div 2) + Round(lTrackLength * lPositionRatio);
        lY := AbsTop + ((Height + cTrackThickness) div 2) + 3;
        RenderLine(lX, lY, lX, lY + cTickSize, BorderColor);
      end;
      Dir_Vertical:
      begin
        lX := AbsLeft + ((Width + cTrackThickness) div 2) + 3;
        lY := AbsTop + (ThumbSize div 2) + Round(lTrackLength * lPositionRatio);
        RenderLine(lX, lY, lX + cTickSize, lY, BorderColor);
      end;
    end;

    Inc(lIndex);
  end;

  if ((Max - Min) mod TickFrequency) <> 0 then
  begin
    lPositionRatio := PositionRatioFromValue(Max);
    case Direction of
      Dir_Horizontal:
      begin
        lX := AbsLeft + (ThumbSize div 2) + Round(lTrackLength * lPositionRatio);
        lY := AbsTop + ((Height + cTrackThickness) div 2) + 3;
        RenderLine(lX, lY, lX, lY + cTickSize, BorderColor);
      end;
      Dir_Vertical:
      begin
        lX := AbsLeft + ((Width + cTrackThickness) div 2) + 3;
        lY := AbsTop + (ThumbSize div 2) + Round(lTrackLength * lPositionRatio);
        RenderLine(lX, lY, lX + cTickSize, lY, BorderColor);
      end;
    end;
  end;
end;

function TNXTrackBar.GetRange: Integer;
begin
  Result := FMax - FMin;
end;

function TNXTrackBar.GetThumbRect: TNXRect;
var
  lPosition: Integer;
  lRatio: Double;
  lTrackLength: Integer;
begin
  lTrackLength := GetTrackLength;
  lRatio := PositionRatioFromValue(Value);
  lPosition := Round(lTrackLength * lRatio);

  case Direction of
    Dir_Horizontal:
      Result := MakeNXRect(AbsLeft + lPosition,
        AbsTop + ((Height - ThumbSize) div 2), ThumbSize, ThumbSize);
    Dir_Vertical:
      Result := MakeNXRect(AbsLeft + ((Width - ThumbSize) div 2),
        AbsTop + lPosition, ThumbSize, ThumbSize);
  end;
end;

function TNXTrackBar.GetTrackLength: Integer;
begin
  case Direction of
    Dir_Horizontal:
      Result := Math.Max(0, Width - ThumbSize);
    Dir_Vertical:
      Result := Math.Max(0, Height - ThumbSize);
  end;
end;

function TNXTrackBar.GetTrackRect: TNXRect;
begin
  case Direction of
    Dir_Horizontal:
      Result := MakeNXRect(AbsLeft + (ThumbSize div 2),
        AbsTop + ((Height - cTrackThickness) div 2), GetTrackLength,
        cTrackThickness);
    Dir_Vertical:
      Result := MakeNXRect(AbsLeft + ((Width - cTrackThickness) div 2),
        AbsTop + (ThumbSize div 2), cTrackThickness, GetTrackLength);
  end;
end;

function TNXTrackBar.GetValueRatio: Double;
var
  lRange: Integer;
begin
  lRange := GetRange;
  if lRange <= 0 then
    Exit(0.0);

  Result := (Value - Min) / lRange;
  if Result < 0.0 then
    Result := 0.0;
  if Result > 1.0 then
    Result := 1.0;
end;

function TNXTrackBar.PositionRatioFromValue(AValue: Integer): Double;
var
  lRange: Integer;
begin
  lRange := GetRange;
  if lRange <= 0 then
    Exit(0.0);

  Result := (ClampValue(AValue) - Min) / lRange;

  case Direction of
    Dir_Horizontal:
    begin
      if Inverted then
        Result := 1.0 - Result;
    end;
    Dir_Vertical:
    begin
      if not Inverted then
        Result := 1.0 - Result;
    end;
  end;
end;

procedure TNXTrackBar.RenderClient;
var
  lThumbRect: TNXRect;
  lTrackRect: TNXRect;
begin
  inherited RenderClient;

  lTrackRect := GetTrackRect;
  RenderFilledRect(lTrackRect, BorderColor);

  DrawTickMarks;

  lThumbRect := GetThumbRect;
  if (FMoving or MouseEntered or IsSelected) and Enabled then
    RenderFilledRect(lThumbRect, Skin.SelectedColor)
  else
    RenderFilledRect(lThumbRect, BackColor);

  if IsSelected then
    RenderRect(lThumbRect, ForeColor)
  else
    RenderRect(lThumbRect, BorderColor);
end;

procedure TNXTrackBar.SetDirection(AValue: TDirection);
begin
  if FDirection = AValue then
    Exit;

  FDirection := AValue;
end;

procedure TNXTrackBar.SetInverted(AValue: Boolean);
begin
  if FInverted = AValue then
    Exit;

  FInverted := AValue;
end;

procedure TNXTrackBar.SetLargeChange(AValue: Integer);
begin
  FLargeChange := Math.Max(1, AValue);
end;

procedure TNXTrackBar.SetMax(AValue: Integer);
begin
  if FMax = AValue then
    Exit;

  FMax := AValue;
  if FMax < FMin then
    FMin := FMax;
  ChangeValue(FValue);
end;

procedure TNXTrackBar.SetMin(AValue: Integer);
begin
  if FMin = AValue then
    Exit;

  FMin := AValue;
  if FMin > FMax then
    FMax := FMin;
  ChangeValue(FValue);
end;

procedure TNXTrackBar.SetShowTicks(AValue: Boolean);
begin
  FShowTicks := AValue;
end;

procedure TNXTrackBar.SetSmallChange(AValue: Integer);
begin
  FSmallChange := Math.Max(1, AValue);
end;

procedure TNXTrackBar.SetThumbSize(AValue: Integer);
begin
  FThumbSize := Math.Max(4, AValue);
end;

procedure TNXTrackBar.SetTickFrequency(AValue: Integer);
begin
  FTickFrequency := Math.Max(0, AValue);
end;

procedure TNXTrackBar.SetValue(AValue: Integer);
begin
  ChangeValue(AValue);
end;

procedure TNXTrackBar.StepBy(ADelta: Integer);
begin
  Value := Value + ADelta;
end;

function TNXTrackBar.ValueFromPoint(AX, AY: Integer): Integer;
var
  lPosition: Integer;
  lRatio: Double;
  lRange: Integer;
  lTrackLength: Integer;
begin
  lRange := GetRange;
  lTrackLength := GetTrackLength;
  if (lRange <= 0) or (lTrackLength <= 0) then
    Exit(Min);

  case Direction of
    Dir_Horizontal:
      lPosition := AX - (ThumbSize div 2);
    Dir_Vertical:
      lPosition := AY - (ThumbSize div 2);
  end;

  lPosition := EnsureRange(lPosition, 0, lTrackLength);
  lRatio := lPosition / lTrackLength;

  case Direction of
    Dir_Horizontal:
    begin
      if Inverted then
        lRatio := 1.0 - lRatio;
    end;
    Dir_Vertical:
    begin
      if not Inverted then
        lRatio := 1.0 - lRatio;
    end;
  end;

  Result := ClampValue(Min + Round(lRange * lRatio));
end;

end.
