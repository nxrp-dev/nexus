unit obNXProgressBar;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Math,
  tpNXPlatform,
  obNXControl;

type
  TNXProgressChangedEvent = procedure(Sender: TObject; AValue: Integer) of object;

  TNXProgressTextMode = (
    ptNone,
    ptPercent,
    ptValue,
    ptCaption,
    ptFormat
  );

  TNXProgressBar = class(TNXControl)
  private
    FMin: Integer;
    FMax: Integer;
    FValue: Integer;
    FDirection: TDirection;
    FProgressColor: TNXColor;
    FTextMode: TNXProgressTextMode;
    FTextFormat: string;
    FInverted: Boolean;
    FOnChange: TNXProgressChangedEvent;

    function GetPercent: Integer;
    function GetProgressRatio: Double;
    function GetProgressText: string;
    procedure SetDirection(AValue: TDirection);
    procedure SetInverted(AValue: Boolean);
    procedure SetMax(AValue: Integer);
    procedure SetMin(AValue: Integer);
    procedure SetProgressColor(AValue: TNXColor);
    procedure SetTextFormat(const AValue: string);
    procedure SetTextMode(AValue: TNXProgressTextMode);
    procedure SetValue(AValue: Integer);
  protected
    function ClampValue(AValue: Integer): Integer; virtual;
    function MakeProgressRect(const ARect: TNXRect): TNXRect; virtual;
    procedure ChangeValue(AValue: Integer); virtual;
    procedure DoChange; virtual;
    procedure RenderClient; override;
  public
    constructor Create(const AParent: INXControlParent); override;

    procedure StepBy(ADelta: Integer); virtual;
    procedure Reset; virtual;

    property Percent: Integer read GetPercent;

    property Direction: TDirection read FDirection write SetDirection;
    property Inverted: Boolean read FInverted write SetInverted;
    property Max: Integer read FMax write SetMax;
    property Min: Integer read FMin write SetMin;
    property ProgressColor: TNXColor read FProgressColor write SetProgressColor;
    property TextFormat: string read FTextFormat write SetTextFormat;
    property TextMode: TNXProgressTextMode read FTextMode write SetTextMode;
    property Value: Integer read FValue write SetValue;

    property OnChange: TNXProgressChangedEvent read FOnChange write FOnChange;
  end;

implementation

constructor TNXProgressBar.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FMin := 0;
  FMax := 100;
  FValue := 0;
  FDirection := Dir_Horizontal;
  FProgressColor := Skin.ActiveColor;
  FTextMode := ptPercent;
  FTextFormat := '%d%%';
  FInverted := False;
  BorderStyle := BS_Single;
  BackColor := Skin.TextBackColor;
  Width := 160;
  Height := 20;
  CanFocus := False;
end;

function TNXProgressBar.ClampValue(AValue: Integer): Integer;
begin
  Result := Math.Max(Min, AValue);
  Result := Math.Min(Max, Result);
end;

procedure TNXProgressBar.ChangeValue(AValue: Integer);
var
  lValue: Integer;
begin
  lValue := ClampValue(AValue);
  if FValue = lValue then
    Exit;

  FValue := lValue;
  DoChange;
end;

procedure TNXProgressBar.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self, FValue);
end;

function TNXProgressBar.GetPercent: Integer;
var
  lRange: Int64;
  lOffset: Int64;
begin
  lRange := Int64(Max) - Int64(Min);
  if lRange <= 0 then
    Exit(0);

  lOffset := Int64(Value) - Int64(Min);
  Result := Round((lOffset * 100) / lRange);
  Result := Math.Max(0, Math.Min(100, Result));
end;

function TNXProgressBar.GetProgressRatio: Double;
var
  lRange: Int64;
begin
  lRange := Int64(Max) - Int64(Min);
  if lRange <= 0 then
    Exit(0.0);

  Result := (Int64(Value) - Int64(Min)) / lRange;
  if Result < 0.0 then
    Result := 0.0;
  if Result > 1.0 then
    Result := 1.0;
end;

function TNXProgressBar.GetProgressText: string;
begin
  case FTextMode of
    ptPercent:
      Result := IntToStr(Percent) + '%';
    ptValue:
      Result := IntToStr(Value);
    ptCaption:
      Result := Caption;
    ptFormat:
      Result := Format(FTextFormat, [Percent, Value, Min, Max]);
  else
    Result := '';
  end;
end;

function TNXProgressBar.MakeProgressRect(const ARect: TNXRect): TNXRect;
var
  lRatio: Double;
  lSize: Integer;
begin
  Result := ARect;
  lRatio := GetProgressRatio;

  case FDirection of
    Dir_Horizontal:
    begin
      lSize := Floor(ARect.w * lRatio);
      Result.w := lSize;
      if Inverted then
        Result.x := ARect.x + ARect.w - lSize;
    end;
    Dir_Vertical:
    begin
      lSize := Floor(ARect.h * lRatio);
      Result.h := lSize;
      if not Inverted then
        Result.y := ARect.y + ARect.h - lSize;
    end;
  end;
end;

procedure TNXProgressBar.RenderClient;
var
  lRect: TNXRect;
  lProgressRect: TNXRect;
  lText: string;
begin
  inherited RenderClient;

  lRect := ContentRect;
  if (lRect.w <= 0) or (lRect.h <= 0) then
    Exit;

  lProgressRect := MakeProgressRect(lRect);
  if (lProgressRect.w > 0) and (lProgressRect.h > 0) then
    RenderFilledRect(lProgressRect, FProgressColor);

  lText := GetProgressText;
  if lText <> '' then
    RenderText(lText, Width div 2, (Height - FontHeight) div 2, Align_Center);
end;

procedure TNXProgressBar.Reset;
begin
  Value := Min;
end;

procedure TNXProgressBar.SetDirection(AValue: TDirection);
begin
  if FDirection = AValue then
    Exit;

  FDirection := AValue;
end;

procedure TNXProgressBar.SetInverted(AValue: Boolean);
begin
  if FInverted = AValue then
    Exit;

  FInverted := AValue;
end;

procedure TNXProgressBar.SetMax(AValue: Integer);
begin
  if FMax = AValue then
    Exit;

  FMax := AValue;
  if FMax < FMin then
    FMin := FMax;
  ChangeValue(FValue);
end;

procedure TNXProgressBar.SetMin(AValue: Integer);
begin
  if FMin = AValue then
    Exit;

  FMin := AValue;
  if FMin > FMax then
    FMax := FMin;
  ChangeValue(FValue);
end;

procedure TNXProgressBar.SetProgressColor(AValue: TNXColor);
begin
  FProgressColor := AValue;
end;

procedure TNXProgressBar.SetTextFormat(const AValue: string);
begin
  FTextFormat := AValue;
end;

procedure TNXProgressBar.SetTextMode(AValue: TNXProgressTextMode);
begin
  FTextMode := AValue;
end;

procedure TNXProgressBar.SetValue(AValue: Integer);
begin
  ChangeValue(AValue);
end;

procedure TNXProgressBar.StepBy(ADelta: Integer);
begin
  Value := Value + ADelta;
end;

end.
