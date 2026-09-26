unit obNXTimeEdit;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  tpNXEvents,
  obNXControl,
  obNXEditBox;

type
  TNXTimeEdit = class(TNXEditBox)
  private
    FNormalizeOnExit: Boolean;
    FShowSeconds: Boolean;
    FTimeFormat: string;

    function GetHasTime: Boolean;
    function GetTime: TDateTime;
    procedure SetShowSeconds(AValue: Boolean);
    procedure SetTime(AValue: TDateTime);
    procedure SetTimeFormat(const AValue: string);
  protected
    function IsAllowedTimeText(const AText: string): Boolean; virtual;
    function NormalizeTimeValue(AValue: TDateTime): TDateTime; virtual;
    function TryParseTimeText(const AText: string; out ATime: TDateTime): Boolean; virtual;
    procedure NormalizeText; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    function TryGetTime(out ATime: TDateTime): Boolean;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoLoseFocus; override;
    procedure DoTextInput(const AText: string); override;

    property HasTime: Boolean read GetHasTime;
    property NormalizeOnExit: Boolean read FNormalizeOnExit write FNormalizeOnExit;
    property ShowSeconds: Boolean read FShowSeconds write SetShowSeconds;
    property Time: TDateTime read GetTime write SetTime;
    property TimeFormat: string read FTimeFormat write SetTimeFormat;
  end;

implementation

const
  cDefaultTimeFormat = 'hh:nn';
  cDefaultTimeFormatSeconds = 'hh:nn:ss';

constructor TNXTimeEdit.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FNormalizeOnExit := True;
  FShowSeconds := False;
  FTimeFormat := cDefaultTimeFormat;
  MaxLength := 8;
  Placeholder := cDefaultTimeFormat;
end;

function TNXTimeEdit.GetHasTime: Boolean;
var
  lTime: TDateTime;
begin
  Result := TryGetTime(lTime);
end;

function TNXTimeEdit.GetTime: TDateTime;
begin
  if not TryGetTime(Result) then
    Result := 0;
end;

procedure TNXTimeEdit.SetShowSeconds(AValue: Boolean);
begin
  if FShowSeconds = AValue then
    Exit;

  FShowSeconds := AValue;
  if FShowSeconds then
  begin
    FTimeFormat := cDefaultTimeFormatSeconds;
    MaxLength := 8;
    Placeholder := cDefaultTimeFormatSeconds;
  end
  else
  begin
    FTimeFormat := cDefaultTimeFormat;
    MaxLength := 5;
    Placeholder := cDefaultTimeFormat;
  end;
end;

procedure TNXTimeEdit.SetTime(AValue: TDateTime);
begin
  Text := FormatDateTime(FTimeFormat, NormalizeTimeValue(AValue));
end;

procedure TNXTimeEdit.SetTimeFormat(const AValue: string);
begin
  FTimeFormat := AValue;
  Placeholder := AValue;
end;

function TNXTimeEdit.IsAllowedTimeText(const AText: string): Boolean;
var
  lIndex: Integer;
begin
  Result := True;

  for lIndex := 1 to Length(AText) do
  begin
    if not (AText[lIndex] in ['0'..'9', ':', ' ', 'a', 'A', 'm', 'M', 'p', 'P']) then
      Exit(False);
  end;
end;

function TNXTimeEdit.NormalizeTimeValue(AValue: TDateTime): TDateTime;
begin
  Result := Frac(AValue);
  if Result < 0 then
    Result := Result + 1;
end;

function TNXTimeEdit.TryParseTimeText(const AText: string; out ATime: TDateTime): Boolean;
var
  lAMPM: string;
  lHour: Integer;
  lMinute: Integer;
  lParts: TStringList;
  lSecond: Integer;
  lText: string;
begin
  ATime := 0;
  Result := False;
  lText := UpperCase(Trim(AText));

  if lText = '' then
    Exit;

  lAMPM := '';
  if Pos('AM', lText) > 0 then
  begin
    lAMPM := 'AM';
    lText := Trim(StringReplace(lText, 'AM', '', []));
  end
  else if Pos('PM', lText) > 0 then
  begin
    lAMPM := 'PM';
    lText := Trim(StringReplace(lText, 'PM', '', []));
  end;

  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := ':';
    lParts.DelimitedText := lText;

    if (lParts.Count < 2) or (lParts.Count > 3) then
      Exit;

    if not TryStrToInt(lParts[0], lHour) then
      Exit;
    if not TryStrToInt(lParts[1], lMinute) then
      Exit;

    lSecond := 0;
    if (lParts.Count = 3) and not TryStrToInt(lParts[2], lSecond) then
      Exit;

    if lAMPM <> '' then
    begin
      if (lHour < 1) or (lHour > 12) then
        Exit;
      if lAMPM = 'AM' then
      begin
        if lHour = 12 then
          lHour := 0;
      end
      else if lHour < 12 then
        Inc(lHour, 12);
    end;

    if (lHour < 0) or (lHour > 23) or
      (lMinute < 0) or (lMinute > 59) or
      (lSecond < 0) or (lSecond > 59) then
      Exit;

    Result := TryEncodeTime(Word(lHour), Word(lMinute), Word(lSecond), 0, ATime);
  finally
    lParts.Free;
  end;
end;

procedure TNXTimeEdit.NormalizeText;
var
  lTime: TDateTime;
begin
  if TryGetTime(lTime) then
    Text := FormatDateTime(FTimeFormat, lTime);
end;

procedure TNXTimeEdit.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lDelta: TDateTime;
  lTime: TDateTime;
begin
  inherited DoKeyDown(AEvent);

  if ReadOnly or not TryGetTime(lTime) then
    Exit;

  if nmShift in AEvent.Modifiers then
    lDelta := 1 / 24
  else
    lDelta := 1 / 1440;

  case AEvent.Key of
    nkUp:
      Time := NormalizeTimeValue(lTime + lDelta);
    nkDown:
      Time := NormalizeTimeValue(lTime - lDelta);
  end;
end;

procedure TNXTimeEdit.DoLoseFocus;
begin
  if FNormalizeOnExit then
    NormalizeText;

  inherited DoLoseFocus;
end;

procedure TNXTimeEdit.DoTextInput(const AText: string);
begin
  if IsAllowedTimeText(AText) then
    inherited DoTextInput(AText);
end;

function TNXTimeEdit.TryGetTime(out ATime: TDateTime): Boolean;
begin
  Result := TryParseTimeText(Text, ATime);
end;

end.
