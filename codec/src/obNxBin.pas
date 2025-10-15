unit obNxBin;

{$mode objfpc}{$H+}
{$I tpPlatform.inc}

interface

uses
  Classes, SysUtils, obNxTypes, utCodecIO;

type
  ENxCodecError = class(Exception);

  INxCodec = interface
    ['{B9B3C7A4-6C3B-4E6A-8C89-7C3C5F6E4421}']
    function  Encode(const AValue: TNxVal): TBytes;
    function  EncodeCanonical(const AValue: TNxVal): TBytes;
    function  Decode(const ABytes: TBytes): TNxVal;
    function  Name: string;
  end;

  TNxCodec = class(TInterfacedObject, INxCodec)
  private
    FMaxDepth: Integer;
    FMaxListLen: Integer;
    FMaxMapLen: Integer;
    procedure WriteText(AStream: TStream; const AText: UnicodeString);
    function  ReadText(AStream: TStream): UnicodeString;
    procedure WriteBytes(AStream: TStream; const ABytes: TBytes);
    function  ReadBytes(AStream: TStream): TBytes;
    function  ValidateUTF8(const A: TBytes): Boolean;
    procedure EncodeValue(AStream: TStream; const AVal: TNxVal; const ACanonicalMap: Boolean; const ADepth: Integer);
    function  DecodeValue(AStream: TStream; const ADepth: Integer): TNxVal;
  public
    constructor Create;
    function  Encode(const AValue: TNxVal): TBytes;
    function  EncodeCanonical(const AValue: TNxVal): TBytes;
    function  Decode(const ABytes: TBytes): TNxVal;
    function  Name: string;
    property MaxDepth: Integer read FMaxDepth write FMaxDepth;
    property MaxListLen: Integer read FMaxListLen write FMaxListLen;
    property MaxMapLen: Integer read FMaxMapLen write FMaxMapLen;
  end;

const
  // Type tags
  C_TAG_NULL      = $00;
  C_TAG_FALSE     = $01;
  C_TAG_TRUE      = $02;
  C_TAG_INT       = $03;
  C_TAG_INT64     = $0A;
  C_TAG_BYTES     = $04;
  C_TAG_TEXT      = $05;
  C_TAG_LIST      = $06;
  C_TAG_MAP       = $07;
  C_TAG_DECIMAL   = $08;
  C_TAG_TIMESTAMP = $09;

implementation

function BytesCompare(const A, B: TBytes): Integer;
var
  lLen, lI: Integer;
begin
  lLen := Length(A);
  if Length(B) < lLen then lLen := Length(B);
  for lI := 0 to lLen-1 do
  begin
    if A[lI] <> B[lI] then Exit(Ord(A[lI]) - Ord(B[lI]));
  end;
  Result := Length(A) - Length(B);
end;

function UTF8Of(const S: UnicodeString): TBytes;
var
  lUtf8: UTF8String;
begin
  lUtf8 := UTF8Encode(S);
  SetLength(Result, Length(lUtf8));
  if Length(Result) > 0 then
    Move(lUtf8[1], Result[0], Length(lUtf8));
end;

{ TNxCodec }

constructor TNxCodec.Create;
begin
  inherited Create;
  FMaxDepth := 64;
  FMaxListLen := 1000;
  FMaxMapLen  := 1000;
end;

function TNxCodec.Name: string;
begin
  Result := 'NXBIN/1';
end;

function TNxCodec.ValidateUTF8(const A: TBytes): Boolean;
var
  lI, lLen, lNeed: Integer;
  lB: Byte;
begin
  lLen := Length(A);
  lI := 0;
  while lI < lLen do
  begin
    lB := A[lI];
    if lB < $80 then
      Inc(lI)
    else if (lB and $E0) = $C0 then
    begin
      lNeed := 1;
      if (lB and $FE) = $C0 then Exit(False); // overlong 2-byte
      if lI + lNeed >= lLen then Exit(False);
      if (A[lI+1] and $C0) <> $80 then Exit(False);
      Inc(lI, 2);
    end
    else if (lB and $F0) = $E0 then
    begin
      lNeed := 2;
      if lI + lNeed >= lLen then Exit(False);
      if (A[lI+1] and $C0) <> $80 then Exit(False);
      if (A[lI+2] and $C0) <> $80 then Exit(False);
      // disallow U+D800..U+DFFF surrogates (encoded as E0..ED ranges with specific next byte)
      if (lB = $ED) and ((A[lI+1] and $A0) = $A0) then Exit(False);
      Inc(lI, 3);
    end
    else if (lB and $F8) = $F0 then
    begin
      lNeed := 3;
      if lI + lNeed >= lLen then Exit(False);
      if (A[lI+1] and $C0) <> $80 then Exit(False);
      if (A[lI+2] and $C0) <> $80 then Exit(False);
      if (A[lI+3] and $C0) <> $80 then Exit(False);
      // overlong 4-byte (value < 0x10000)
      if (lB = $F0) and (A[lI+1] < $90) then Exit(False);
      // > U+10FFFF
      if (lB = $F4) and (A[lI+1] >= $90) then Exit(False);
      if lB > $F4 then Exit(False);
      Inc(lI, 4);
    end
    else
      Exit(False);
  end;
  Result := True;
end;

procedure TNxCodec.WriteText(AStream: TStream; const AText: UnicodeString);
var
  lBytes: TBytes;
begin
  lBytes := UTF8Of(AText);
  if not ValidateUTF8(lBytes) then
    raise ENxCodecError.Create('Invalid UTF-8 text');
  AStream.WriteByte(C_TAG_TEXT);
  WriteCount(AStream, Length(lBytes));
  if Length(lBytes) > 0 then
    AStream.WriteBuffer(lBytes[0], Length(lBytes));
end;

function TNxCodec.ReadText(AStream: TStream): UnicodeString;
var
  lLen: Int64;
  lBytes: TBytes;
  lUtf8: UTF8String;
begin
  lLen := ReadCount(AStream);
  if lLen > High(SizeInt) then
    raise ENxCodecError.Create('Text too big');

  SetLength(lBytes, lLen);
  if lLen > 0 then
    AStream.ReadBuffer(lBytes[0], lLen);

  if Length(lBytes) > 0 then
    SetString(lUtf8, PAnsiChar(@lBytes[0]), Length(lBytes))
  else
    lUtf8 := '';

  Result := UTF8Decode(lUtf8); // or use LazUTF8.UTF8ToUnicodeString(lUtf8)
end;

procedure TNxCodec.WriteBytes(AStream: TStream; const ABytes: TBytes);
begin
  AStream.WriteByte(C_TAG_BYTES);
  WriteCount(AStream, Length(ABytes));
  if Length(ABytes) > 0 then
    AStream.WriteBuffer(ABytes[0], Length(ABytes));
end;

function TNxCodec.ReadBytes(AStream: TStream): TBytes;
var
  lLen: Int64;
begin
  lLen := ReadCount(AStream);
  if lLen > High(SizeInt) then
    raise ENxCodecError.Create('Bytes too big');

  SetLength(Result, lLen);
  if lLen > 0 then
    AStream.ReadBuffer(Result[0], lLen);
end;

procedure TNxCodec.EncodeValue(AStream: TStream; const AVal: TNxVal; const ACanonicalMap: Boolean; const ADepth: Integer);
var
  lI: Integer;
  lKeys: array of record K: TBytes; V: TNxVal; end;
  lTmp: TBytes;

  procedure SortKeys;
  var i,j: Integer; t: TNxVal; tb: TBytes;
  begin
    for i := 1 to High(lKeys) do
    begin
      j := i;
      while (j>0) and (BytesCompare(lKeys[j-1].K, lKeys[j].K) > 0) do
      begin
        tb := lKeys[j-1].K; lKeys[j-1].K := lKeys[j].K; lKeys[j].K := tb;
        t := lKeys[j-1].V;  lKeys[j-1].V := lKeys[j].V; lKeys[j].V := t;
        Dec(j);
      end;
    end;
  end;

begin
  if ADepth > FMaxDepth then raise ENxCodecError.Create('Depth limit');

  case AVal.Kind of
    nkNull:      AStream.WriteByte(C_TAG_NULL);
    nkBool:      if AVal.AsBool then AStream.WriteByte(C_TAG_TRUE) else AStream.WriteByte(C_TAG_FALSE);
    nkInt:       begin AStream.WriteByte(C_TAG_INT); WriteInt32(AStream, LongInt(AVal.AsInt)); end;
    nkInt64:     begin AStream.WriteByte(C_TAG_INT64); WriteInt64(AStream, AVal.AsInt); end;
    nkBytes:     WriteBytes(AStream, AVal.AsBytes);
    nkText:      WriteText(AStream, AVal.AsText);
    nkList:
      begin
        AStream.WriteByte(C_TAG_LIST);
        if AVal.AsList.Count > FMaxListLen then raise ENxCodecError.Create('List too long');
        WriteCount(AStream, AVal.AsList.Count);
        for lI := 0 to AVal.AsList.Count-1 do
          EncodeValue(AStream, AVal.AsList[lI], ACanonicalMap, ADepth+1);
      end;
    nkMap:
      begin
        AStream.WriteByte(C_TAG_MAP);
        if AVal.AsMap.Count > FMaxMapLen then raise ENxCodecError.Create('Map too big');
        WriteCount(AStream, AVal.AsMap.Count);

        SetLength(lKeys, AVal.AsMap.Count);
        for lI := 0 to AVal.AsMap.Count-1 do
        begin
          lTmp := UTF8Of(AVal.AsMap.GetItem(lI).Key);
          lKeys[lI].K := lTmp;
          lKeys[lI].V := AVal.AsMap.GetItem(lI).Val;
        end;
        // canonical sorting removed

        for lI := 0 to High(lKeys) do
        begin
          AStream.WriteByte(C_TAG_TEXT);
          WriteCount(AStream, Length(lKeys[lI].K));
          if Length(lKeys[lI].K) > 0 then
            AStream.WriteBuffer(lKeys[lI].K[0], Length(lKeys[lI].K));
          EncodeValue(AStream, lKeys[lI].V, ACanonicalMap, ADepth+1);
        end;
      end;
    nkDecimal:
      begin
        AStream.WriteByte(C_TAG_DECIMAL);
        WriteInt64(AStream, AVal.AsDecimal.Mantissa);
        AStream.WriteByte(Byte(AVal.AsDecimal.Scale));
        AStream.WriteByte(0);
      end;
    nkTimestamp:
      begin
        AStream.WriteByte(C_TAG_TIMESTAMP);
        WriteInt64(AStream, AVal.AsTimestampMs);
      end;
  end;
end;

function TNxCodec.DecodeValue(AStream: TStream; const ADepth: Integer): TNxVal;
var
  lTag: Byte;
  lCount, lI: Int64;
  lKey: UnicodeString;
  lN: Int64;
  lDec: TNxDecimal;
  lBytes: TBytes;
  lStr: UnicodeString;
  lChild: TNxVal;
begin
  if ADepth > FMaxDepth then raise ENxCodecError.Create('Depth limit');

  if AStream.Read(lTag, 1) <> 1 then raise ENxCodecError.Create('Unexpected EOF');
  case lTag of
    C_TAG_NULL:      Exit(TNxVal.Null);
    C_TAG_FALSE:     Exit(TNxVal.Bool(False));
    C_TAG_TRUE:      Exit(TNxVal.Bool(True));
    C_TAG_INT:
      begin
        lN := ReadInt32(AStream);
        Exit(TNxVal.Int(lN));
      end;
    C_TAG_INT64:
      begin
        lN := ReadInt64(AStream);
        Exit(TNxVal.Int64(lN));
      end;
    C_TAG_BYTES:
      begin
        lBytes := ReadBytes(AStream);
        Result := TNxVal.Bytes(lBytes);
        Exit;
      end;
    C_TAG_TEXT:
      begin
        lStr := ReadText(AStream);
        Result := TNxVal.Text(lStr);
        Exit;
      end;
    C_TAG_LIST:
      begin
        lCount := ReadCount(AStream);
        if lCount > QWord(FMaxListLen) then raise ENxCodecError.Create('List too long');
        Result := TNxVal.List;
        for lI := 1 to Integer(lCount) do
        begin
          lChild := DecodeValue(AStream, ADepth+1);
          Result.AsList.Add(lChild);
        end;
        Exit;
      end;
    C_TAG_MAP:
      begin
        lCount := ReadCount(AStream);
        if lCount > QWord(FMaxMapLen) then raise ENxCodecError.Create('Map too big');
        Result := TNxVal.Map;
        for lI := 1 to Integer(lCount) do
        begin
          // keys are encoded as Text values
          if AStream.Read(lTag,1)<>1 then raise ENxCodecError.Create('EOF map key tag');
          if lTag<>C_TAG_TEXT then raise ENxCodecError.Create('Map key must be Text');
          lKey := ReadText(AStream);
          lChild := DecodeValue(AStream, ADepth+1);
          Result.AsMap.SetKey(lKey, lChild);
        end;
        Exit;
      end;
    C_TAG_DECIMAL:
      begin
        if AStream.Read(lDec.Mantissa, SizeOf(Int64)) <> SizeOf(Int64) then raise ENxCodecError.Create('EOF decimal mantissa');
        if AStream.Read(lTag, 1) <> 1 then raise ENxCodecError.Create('EOF decimal scale');
        lDec.Scale := ShortInt(lTag);
        if AStream.Read(lTag, 1) <> 1 then raise ENxCodecError.Create('EOF decimal reserved');
        if lTag<>0 then raise ENxCodecError.Create('Decimal reserved <> 0');
        Result := TNxVal.Decimal(lDec.Mantissa, lDec.Scale);
        Exit;
      end;
    C_TAG_TIMESTAMP:
      begin
        if AStream.Read(lN, SizeOf(Int64)) <> SizeOf(Int64) then raise ENxCodecError.Create('EOF timestamp');
        Result := TNxVal.TimestampMs(lN);
        Exit;
      end;
  else
    raise ENxCodecError.CreateFmt('Unknown tag %d', [lTag]);
  end;
end;


function TNxCodec.Encode(const AValue: TNxVal): TBytes;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    EncodeValue(lMS, AValue, False, 0);
    SetLength(Result, lMS.Size);
    if lMS.Size > 0 then
    begin
      lMS.Position := 0;
      lMS.ReadBuffer(Result[0], lMS.Size);
    end;
  finally
    lMS.Free;
  end;
end;

function TNxCodec.EncodeCanonical(const AValue: TNxVal): TBytes;
begin
  Result := Encode(AValue);
end;

function TNxCodec.Decode(const ABytes: TBytes): TNxVal;
var lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    if Length(ABytes)>0 then
      lMS.WriteBuffer(ABytes[0], Length(ABytes));
    lMS.Position := 0;
    Result := DecodeValue(lMS, 0);
    if lMS.Position <> lMS.Size then
      raise ENxCodecError.Create('Trailing data');
  finally
    lMS.Free;
  end;
end;

end.
