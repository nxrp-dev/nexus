unit obNXDateEdit;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  tpNXEvents,
  obNXControl,
  obNXEditBox;

type
  TNXDateEdit = class(TNXEditBox)
  private
    FDateFormat: string;
    FNormalizeOnExit: Boolean;

    function GetDate: TDateTime;
    function GetHasDate: Boolean;
    procedure SetDate(AValue: TDateTime);
  protected
    function IsAllowedDateText(const AText: string): Boolean; virtual;
    function TryParseDateText(const AText: string; out ADate: TDateTime): Boolean; virtual;
    procedure NormalizeText; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    function TryGetDate(out ADate: TDateTime): Boolean;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoLoseFocus; override;
    procedure DoTextInput(const AText: string); override;

    property Date: TDateTime read GetDate write SetDate;
    property DateFormat: string read FDateFormat write FDateFormat;
    property HasDate: Boolean read GetHasDate;
    property NormalizeOnExit: Boolean read FNormalizeOnExit write FNormalizeOnExit;
  end;

implementation

const
  cDefaultDateFormat = 'yyyy-mm-dd';

constructor TNXDateEdit.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FDateFormat := cDefaultDateFormat;
  FNormalizeOnExit := True;
  MaxLength := 10;
  Placeholder := cDefaultDateFormat;
end;

function TNXDateEdit.GetDate: TDateTime;
begin
  if not TryGetDate(Result) then
    Result := 0;
end;

function TNXDateEdit.GetHasDate: Boolean;
var
  lDate: TDateTime;
begin
  Result := TryGetDate(lDate);
end;

procedure TNXDateEdit.SetDate(AValue: TDateTime);
begin
  Text := FormatDateTime(FDateFormat, AValue);
end;

function TNXDateEdit.IsAllowedDateText(const AText: string): Boolean;
var
  lIndex: Integer;
begin
  Result := True;

  for lIndex := 1 to Length(AText) do
  begin
    if not (AText[lIndex] in ['0'..'9', '/', '-']) then
      Exit(False);
  end;
end;

function TNXDateEdit.TryParseDateText(const AText: string; out ADate: TDateTime): Boolean;
var
  lDay: Integer;
  lFirst: Integer;
  lFirstDash: SizeInt;
  lFirstSlash: SizeInt;
  lMonth: Integer;
  lParts: TStringList;
  lSecond: Integer;
  lSeparator: Char;
  lText: string;
  lThird: Integer;
  lYear: Integer;
begin
  ADate := 0;
  Result := False;
  lText := Trim(AText);

  if lText = '' then
    Exit;

  lFirstDash := Pos('-', lText);
  lFirstSlash := Pos('/', lText);
  if lFirstDash > 0 then
    lSeparator := '-'
  else if lFirstSlash > 0 then
    lSeparator := '/'
  else
    Exit;

  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := lSeparator;
    lParts.DelimitedText := lText;

    if lParts.Count <> 3 then
      Exit;

    if not TryStrToInt(lParts[0], lFirst) then
      Exit;
    if not TryStrToInt(lParts[1], lSecond) then
      Exit;
    if not TryStrToInt(lParts[2], lThird) then
      Exit;

    if Length(lParts[0]) = 4 then
    begin
      lYear := lFirst;
      lMonth := lSecond;
      lDay := lThird;
    end
    else
    begin
      lMonth := lFirst;
      lDay := lSecond;
      lYear := lThird;
      if lYear < 100 then
      begin
        if lYear >= 70 then
          Inc(lYear, 1900)
        else
          Inc(lYear, 2000);
      end;
    end;

    if (lYear < 1) or (lYear > 9999) or
      (lMonth < 1) or (lMonth > 12) or
      (lDay < 1) or (lDay > 31) then
      Exit;

    Result := TryEncodeDate(Word(lYear), Word(lMonth), Word(lDay), ADate);
  finally
    lParts.Free;
  end;
end;

procedure TNXDateEdit.NormalizeText;
var
  lDate: TDateTime;
begin
  if TryGetDate(lDate) then
    Text := FormatDateTime(FDateFormat, lDate);
end;

procedure TNXDateEdit.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lDate: TDateTime;
begin
  inherited DoKeyDown(AEvent);

  if ReadOnly or not TryGetDate(lDate) then
    Exit;

  case AEvent.Key of
    nkUp:
      Date := lDate + 1;
    nkDown:
      Date := lDate - 1;
  end;
end;

procedure TNXDateEdit.DoLoseFocus;
begin
  if FNormalizeOnExit then
    NormalizeText;

  inherited DoLoseFocus;
end;

procedure TNXDateEdit.DoTextInput(const AText: string);
begin
  if IsAllowedDateText(AText) then
    inherited DoTextInput(AText);
end;

function TNXDateEdit.TryGetDate(out ADate: TDateTime): Boolean;
begin
  Result := TryParseDateText(Text, ADate);
end;

end.
