unit obNXJSONRPCObjects;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpjson,
  obNXJSONValues;

type
  TNXJSONRPCVariant = class(TNXJSONValue)
  private
    FIntegerValue: Int64;
    FStringValue: string;
    FIsInteger: Boolean;
  public
    procedure Clear; override;
    function ToJSONData: TJSONData; override;
    procedure FromJSONData(AData: TJSONData); override;
    function AsString: string; override;
    function AsInteger: Integer; override;
    function AsInt64: Int64; override;
    procedure SetIntegerValue(const AValue: Int64);
    procedure SetStringValue(const AValue: string);
    property IntegerValue: Int64 read FIntegerValue write SetIntegerValue;
    property IsInteger: Boolean read FIsInteger;
    property StringValue: string read FStringValue write SetStringValue;
  end;

implementation

procedure TNXJSONRPCVariant.Clear;
begin
  inherited Clear;
  FIntegerValue := 0;
  FStringValue := '';
  FIsInteger := False;
end;

function TNXJSONRPCVariant.ToJSONData: TJSONData;
begin
  if FIsInteger then
    Result := TJSONIntegerNumber.Create(FIntegerValue)
  else
    Result := TJSONString.Create(FStringValue);
end;

procedure TNXJSONRPCVariant.FromJSONData(AData: TJSONData);
begin
  if AData = nil then
    raise ENXJSON.Create('Expected JSON string or integer.');

  case AData.JSONType of
    jtString:
      SetStringValue(AData.AsString);
    jtNumber:
      begin
        if Pos('.', AData.AsJSON) > 0 then
          raise ENXJSON.Create('Expected JSON integer.');
        SetIntegerValue(AData.AsInteger);
      end;
  else
    raise ENXJSON.Create('Expected JSON string or integer.');
  end;
end;

function TNXJSONRPCVariant.AsString: string;
begin
  if FIsInteger then
    Result := IntToStr(FIntegerValue)
  else
    Result := FStringValue;
end;

function TNXJSONRPCVariant.AsInteger: Integer;
begin
  Result := Integer(AsInt64);
end;

function TNXJSONRPCVariant.AsInt64: Int64;
begin
  if not FIsInteger then
    raise ENXJSON.Create('JSON value is not an integer.');

  Result := FIntegerValue;
end;

procedure TNXJSONRPCVariant.SetIntegerValue(const AValue: Int64);
begin
  FIntegerValue := AValue;
  FStringValue := '';
  FIsInteger := True;
  SetJSONType(nxjtInteger);
  Assigned := True;
end;

procedure TNXJSONRPCVariant.SetStringValue(const AValue: string);
begin
  FIntegerValue := 0;
  FStringValue := AValue;
  FIsInteger := False;
  SetJSONType(nxjtString);
  Assigned := True;
end;

end.
