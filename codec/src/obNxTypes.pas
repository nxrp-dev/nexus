{$mode objfpc}{$H+}
unit obNxTypes;

interface

uses
  Classes, SysUtils, fgl;

type
  TStringArray = array of UnicodeString;
  TNxKind = (nkNull, nkBool, nkInt, nkInt64, nkBytes, nkText, nkList, nkMap, nkDecimal, nkTimestamp);

  TNxDecimal = record
    Mantissa: Int64;   // e.g. 123456
    Scale:    ShortInt; // e.g. 3 => 123.456
  end;

  TNxVal = class;
  TNxList = class(specialize TFPGObjectList<TNxVal>);

  TNxValArray = array of TNxVal;

  { Lightweight map with canonical key ordering at encode-time.
    Internally we store pairs; we sort on-demand for encode. }
  TNxMapItem = record
    Key: UnicodeString; // UTF-8 on wire; UnicodeString in memory
    Val: TNxVal;
  end;

  TNxMap = class
  private
    FItems: array of TNxMapItem;
    function  FindIndex(const AKey: UnicodeString): Integer; // linear; small maps are typical
  public
    destructor Destroy; override;
    function  Count: Integer;
    function  Keys: TStringArray;
    function  Values: TNxValArray;
    function  TryGet(const AKey: UnicodeString; out AVal: TNxVal): Boolean;
    procedure SetKey(const AKey: UnicodeString; AVal: TNxVal); // add/replace (takes ownership)
    procedure Remove(const AKey: UnicodeString);
    function  GetItem(AIndex: Integer): TNxMapItem;
  end;

  TNxVal = class
  private
    FKind: TNxKind;
    FBool: Boolean;
    FInt: Int64;          // also timestamp (ms since epoch)
    FBytes: TBytes;
    FText: UnicodeString;
    FList: TNxList;
    FMap:  TNxMap;
    FDec:  TNxDecimal;
  public
    constructor CreateNull;
    constructor CreateBool(const AValue: Boolean);
    constructor CreateInt(const AValue: Int64);
    constructor CreateInt64(const AValue: Int64);
    constructor CreateBytes(const ABytes: TBytes);
    constructor CreateText(const AText: UnicodeString);
    constructor CreateList;
    constructor CreateMap;
    constructor CreateDecimal(const ADec: TNxDecimal);
    constructor CreateTimestampMs(const AUnixMs: Int64);
    destructor Destroy; override;

    property Kind: TNxKind read FKind;

    // Strong getters (raise on mismatch)
    function  AsBool: Boolean;
    function  AsInt: Int64;
    function  AsBytes: TBytes;
    function  AsText: UnicodeString;
    function  AsList: TNxList;
    function  AsMap: TNxMap;
    function  AsDecimal: TNxDecimal;
    function  AsTimestampMs: Int64;

    // Try getters
    function  TryAsBool(out AOut: Boolean): Boolean;
    function  TryAsInt(out AOut: Int64): Boolean;
    function  TryAsBytes(out AOut: TBytes): Boolean;
    function  TryAsText(out AOut: UnicodeString): Boolean;
    function  TryAsList(out AOut: TNxList): Boolean;
    function  TryAsMap(out AOut: TNxMap): Boolean;
    function  TryAsDecimal(out AOut: TNxDecimal): Boolean;
    function  TryAsTimestampMs(out AOut: Int64): Boolean;

    // Convenience factories
    class function Null: TNxVal; static;
    class function Bool(const AValue: Boolean): TNxVal; static;
    class function Int(const AValue: Int64): TNxVal; static;
    class function Int64(const AValue: Int64): TNxVal; static;
    class function Bytes(const ABytes: TBytes): TNxVal; static;
    class function Text(const AText: UnicodeString): TNxVal; static;
    class function List: TNxVal; static;
    class function Map: TNxVal; static;
    class function Decimal(const AMantissa: Int64; const AScale: ShortInt): TNxVal; static;
    class function TimestampMs(const AUnixMs: Int64): TNxVal; static;
  end;

implementation

{ TNxMap }

destructor TNxMap.Destroy;
var
  lI: Integer;
begin
  for lI := Low(FItems) to High(FItems) do
    FItems[lI].Val.Free;
  inherited;
end;

function TNxMap.Count: Integer;
begin
  Result := Length(FItems);
end;

function TNxMap.FindIndex(const AKey: UnicodeString): Integer;
var
  lI: Integer;
begin
  for lI := Low(FItems) to High(FItems) do
    if FItems[lI].Key = AKey then
      Exit(lI);
  Result := -1;
end;

function TNxMap.Keys: TStringArray;
var
  lI: Integer;
begin
  SetLength(Result, Length(FItems));
  for lI := 0 to High(FItems) do
    Result[lI] := FItems[lI].Key;
end;

function TNxMap.Values: TNxValArray;
var
  lI: Integer;
begin
  SetLength(Result, Length(FItems));
  for lI := 0 to High(FItems) do
    Result[lI] := FItems[lI].Val;
end;

function TNxMap.TryGet(const AKey: UnicodeString; out AVal: TNxVal): Boolean;
var
  lIdx: Integer;
begin
  lIdx := FindIndex(AKey);
  Result := lIdx >= 0;
  if Result then
    AVal := FItems[lIdx].Val;
end;

procedure TNxMap.SetKey(const AKey: UnicodeString; AVal: TNxVal);
var
  lIdx: Integer;
begin
  lIdx := FindIndex(AKey);
  if lIdx >= 0 then
  begin
    FreeAndNil(FItems[lIdx].Val);
    FItems[lIdx].Val := AVal;
    Exit;
  end;
  lIdx := Length(FItems);
  SetLength(FItems, lIdx + 1);
  FItems[lIdx].Key := AKey;
  FItems[lIdx].Val := AVal;
end;

procedure TNxMap.Remove(const AKey: UnicodeString);
var
  lIdx, lLast: Integer;
begin
  lIdx := FindIndex(AKey);
  if lIdx < 0 then Exit;
  FItems[lIdx].Val.Free;
  lLast := High(FItems);
  if lIdx < lLast then
    FItems[lIdx] := FItems[lLast];
  SetLength(FItems, lLast);
end;

function TNxMap.GetItem(AIndex: Integer): TNxMapItem;
begin
  Result := FItems[AIndex];
end;

{ TNxVal }

constructor TNxVal.CreateNull; begin FKind := nkNull; end;
constructor TNxVal.CreateBool(const AValue: Boolean); begin FKind := nkBool; FBool := AValue; end;
constructor TNxVal.CreateInt(const AValue: Int64); begin FKind := nkInt; FInt := AValue; end;
constructor TNxVal.CreateBytes(const ABytes: TBytes); begin FKind := nkBytes; FBytes := ABytes; end;
constructor TNxVal.CreateText(const AText: UnicodeString); begin FKind := nkText; FText := AText; end;
constructor TNxVal.CreateList; begin FKind := nkList; FList := TNxList.Create(True); end;
constructor TNxVal.CreateMap; begin FKind := nkMap; FMap := TNxMap.Create; end;
constructor TNxVal.CreateDecimal(const ADec: TNxDecimal); begin FKind := nkDecimal; FDec := ADec; end;
constructor TNxVal.CreateTimestampMs(const AUnixMs: Int64); begin FKind := nkTimestamp; FInt := AUnixMs; end;

destructor TNxVal.Destroy;
begin
  case FKind of
    nkList: FList.Free;
    nkMap:  FMap.Free;
  end;
  inherited;
end;

function TNxVal.AsBool: Boolean; begin if FKind<>nkBool then raise Exception.Create('Kind!=Bool'); Result := FBool; end;
function TNxVal.AsInt: Int64; begin if FKind<>nkInt then raise Exception.Create('Kind!=Int'); Result := FInt; end;
function TNxVal.AsBytes: TBytes; begin if FKind<>nkBytes then raise Exception.Create('Kind!=Bytes'); Result := FBytes; end;
function TNxVal.AsText: UnicodeString; begin if FKind<>nkText then raise Exception.Create('Kind!=Text'); Result := FText; end;
function TNxVal.AsList: TNxList; begin if FKind<>nkList then raise Exception.Create('Kind!=List'); Result := FList; end;
function TNxVal.AsMap: TNxMap; begin if FKind<>nkMap then raise Exception.Create('Kind!=Map'); Result := FMap; end;
function TNxVal.AsDecimal: TNxDecimal; begin if FKind<>nkDecimal then raise Exception.Create('Kind!=Decimal'); Result := FDec; end;
function TNxVal.AsTimestampMs: Int64; begin if FKind<>nkTimestamp then raise Exception.Create('Kind!=Timestamp'); Result := FInt; end;

function TNxVal.TryAsBool(out AOut: Boolean): Boolean; begin Result := FKind=nkBool; if Result then AOut:=FBool; end;
function TNxVal.TryAsInt(out AOut: Int64): Boolean; begin Result := (FKind=nkInt) or (FKind=nkInt64); if Result then AOut:=FInt; end;
function TNxVal.TryAsBytes(out AOut: TBytes): Boolean; begin Result := FKind=nkBytes; if Result then AOut:=FBytes; end;
function TNxVal.TryAsText(out AOut: UnicodeString): Boolean; begin Result := FKind=nkText; if Result then AOut:=FText; end;
function TNxVal.TryAsList(out AOut: TNxList): Boolean; begin Result := FKind=nkList; if Result then AOut:=FList; end;
function TNxVal.TryAsMap(out AOut: TNxMap): Boolean; begin Result := FKind=nkMap; if Result then AOut:=FMap; end;
function TNxVal.TryAsDecimal(out AOut: TNxDecimal): Boolean; begin Result := FKind=nkDecimal; if Result then AOut:=FDec; end;
function TNxVal.TryAsTimestampMs(out AOut: Int64): Boolean; begin Result := FKind=nkTimestamp; if Result then AOut:=FInt; end;

class function TNxVal.Null: TNxVal; begin Result := TNxVal.CreateNull; end;
class function TNxVal.Bool(const AValue: Boolean): TNxVal; begin Result := TNxVal.CreateBool(AValue); end;
class function TNxVal.Int(const AValue: Int64): TNxVal; begin Result := TNxVal.CreateInt(AValue); end;
class function TNxVal.Bytes(const ABytes: TBytes): TNxVal; begin Result := TNxVal.CreateBytes(ABytes); end;
class function TNxVal.Text(const AText: UnicodeString): TNxVal; begin Result := TNxVal.CreateText(AText); end;
class function TNxVal.List: TNxVal; begin Result := TNxVal.CreateList; end;
class function TNxVal.Map: TNxVal; begin Result := TNxVal.CreateMap; end;
class function TNxVal.Decimal(const AMantissa: Int64; const AScale: ShortInt): TNxVal; var lD: TNxDecimal; begin lD.Mantissa:=AMantissa; lD.Scale:=AScale; Result := TNxVal.CreateDecimal(lD); end;
class function TNxVal.TimestampMs(const AUnixMs: Int64): TNxVal; begin Result := TNxVal.CreateTimestampMs(AUnixMs); end;

// New Int64 constructor/factory
constructor TNxVal.CreateInt64(const AValue: Int64);
begin
  inherited Create;
  FKind := nkInt64;
  FInt := AValue;
end;

class function TNxVal.Int64(const AValue: Int64): TNxVal;
begin
  Result := TNxVal.CreateInt64(AValue);
end;

end.
