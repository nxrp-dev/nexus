unit obCommandLine;

interface

uses Classes;

type
  TCommandLine = class(TObject)
  private
    FArguments : TStringList;
    function GetValue(const ASwitch: string): string;
    procedure SetValue(const ASwitch, Value: string);
    procedure GetCommandLineArguments(ACommandList: TStringList);
    procedure GetCommandNameValue(const ASource: string; var AName,
      AValue: string);
    function IsCommandLineSwitch(const ASource: string): boolean;
    function GetText: string;
  public
    constructor Create;
    destructor Destroy; override;

    property Value[const ASwitch : string] : string read GetValue write SetValue;
    property Text : string read GetText;
  published
  end;

implementation

{ TCommandLine }

function TCommandLine.IsCommandLineSwitch(const ASource : string) : boolean;
begin
  Result := (Length(ASource) > 0) and (ASource[1] in ['/', '-']);
end;

procedure TCommandLine.GetCommandNameValue(const ASource : string; var AName, AValue : string);
var
  lSourceLength : integer;
  lPos : integer;
begin
  AName := '';
  AValue := '';

  lSourceLength := Length(ASource);
  if (lSourceLength > 0) and (ASource[1] in ['/', '-']) then
  begin
    lPos := Pos('=', ASource);
    AName := Copy(ASource, 1, lPos-1);
    AValue := Copy(ASource, lPos+1, lSourceLength-lPos);
    Delete(AName, 1, 1);
  end;
end;

procedure TCommandLine.GetCommandLineArguments(ACommandList : TStringList);
var
  lIdx : integer;
  lName,
  lValue : string;
begin
  ACommandList.Clear;
  for lIdx := 1 to ParamCount do
  begin
    if IsCommandLineSwitch(ParamStr(lIdx)) then
    begin
      lName := '';
      lValue := '';
      GetCommandNameValue(ParamStr(lIdx), lName, lValue);
      ACommandList.Values[lName] := lValue;
    end;
  end;
end;

constructor TCommandLine.Create;
begin
  inherited Create;

  FArguments := TStringList.Create;
  GetCommandLineArguments(FArguments);
end;

destructor TCommandLine.Destroy;
begin
  FArguments.Free;

  inherited;
end;

function TCommandLine.GetValue(const ASwitch: string): string;
begin
  Result := FArguments.Values[ASwitch];
end;

procedure TCommandLine.SetValue(const ASwitch, Value: string);
begin
  FArguments.Values[ASwitch] := Value;
end;

function TCommandLine.GetText: string;
begin
  Result := FArguments.Text;
end;

end.
