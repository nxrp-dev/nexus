unit tcNxrpCodecTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpcunit, testutils, testregistry,
  obNxTypes, obNxBin, utCodecIO;

type
  TCodecAllTypesTests = class(TTestCase)
  private
    function BytesOfStream(const AStream: TMemoryStream): TBytes;
    function DecodeThenReencode(const AIn: TBytes): TBytes;
    procedure AssertRoundTrip(const AIn: TBytes; const ACase: string);

    // Wire helpers (mirror codec tags & fixed-width LE encoding)
    procedure W_Null(AStream: TStream);
    procedure W_Bool(AStream: TStream; const AValue: Boolean);
    procedure W_Int32(AStream: TStream; const AValue: LongInt);
    procedure W_Int64(AStream: TStream; const AValue: Int64);
    procedure W_Text(AStream: TStream; const AText: UnicodeString);
    procedure W_Bytes(AStream: TStream; const AData: TBytes);
    procedure W_TimestampMs(AStream: TStream; const AMs: Int64);
    procedure W_Decimal(AStream: TStream; const AMantissa: Int64; const AScale: Byte);
    procedure W_List_Begin(AStream: TStream; const ACount: Int64);
    procedure W_Map_Begin(AStream: TStream; const ACount: Int64);

  published
    procedure RoundTrip_Null;
    procedure RoundTrip_Bool_True;
    procedure RoundTrip_Bool_False;
    procedure RoundTrip_Int32_PosNeg;
    procedure RoundTrip_Int64_Big;
    procedure RoundTrip_Text_UTF8;
    procedure RoundTrip_Bytes_Blob;
    procedure RoundTrip_TimestampMs;
    procedure RoundTrip_Decimal;
    procedure RoundTrip_List_Mixed;
    procedure RoundTrip_Map_Mixed;
  end;

implementation

{$I ../src/tpPlatform.inc}

const
  // Must match encoder tags in obNxBin
  C_TAG_NULL      = $00;
  C_TAG_FALSE     = $01;
  C_TAG_TRUE      = $02;
  C_TAG_INT       = $03; // 32-bit LE integer
  C_TAG_BYTES     = $04;
  C_TAG_TEXT      = $05;
  C_TAG_LIST      = $06;
  C_TAG_MAP       = $07;
  C_TAG_DECIMAL   = $08; // mantissa:int64 LE, scale:byte
  C_TAG_TIMESTAMP = $09; // int64 ms since epoch LE
  C_TAG_INT64     = $0A; // 64-bit LE integer

{ TCodecAllTypesTests }

function TCodecAllTypesTests.BytesOfStream(const AStream: TMemoryStream): TBytes;
begin
  SetLength(Result, AStream.Size);
  if AStream.Size > 0 then
  begin
    AStream.Position := 0;
    AStream.ReadBuffer(Result[0], AStream.Size);
  end;
end;

function TCodecAllTypesTests.DecodeThenReencode(const AIn: TBytes): TBytes;
var
  lCodec: INxCodec;
  lVal: TNxVal;
begin
  lCodec := TNxCodec.Create;
  lVal := lCodec.Decode(AIn);
  Result := lCodec.Encode(lVal);
end;

procedure TCodecAllTypesTests.AssertRoundTrip(const AIn: TBytes; const ACase: string);
var
  lOut: TBytes;
  lI: SizeInt;
begin
  lOut := DecodeThenReencode(AIn);
  AssertEquals(Format('%s: length mismatch', [ACase]), Length(AIn), Length(lOut));
  for lI := 0 to High(AIn) do
    AssertEquals(Format('%s: byte[%d] mismatch', [ACase, lI]), AIn[lI], lOut[lI]);
end;

procedure TCodecAllTypesTests.W_Null(AStream: TStream);
begin
  AStream.WriteByte(C_TAG_NULL);
end;

procedure TCodecAllTypesTests.W_Bool(AStream: TStream; const AValue: Boolean);
begin
  if AValue then
    AStream.WriteByte(C_TAG_TRUE)
  else
    AStream.WriteByte(C_TAG_FALSE);
end;

procedure TCodecAllTypesTests.W_Int32(AStream: TStream; const AValue: LongInt);
begin
  AStream.WriteByte(C_TAG_INT);
  WriteInt32(AStream, AValue);
end;

procedure TCodecAllTypesTests.W_Int64(AStream: TStream; const AValue: Int64);
begin
  AStream.WriteByte(C_TAG_INT64);
  WriteInt64(AStream, AValue);
end;

procedure TCodecAllTypesTests.W_Text(AStream: TStream; const AText: UnicodeString);
var
  lUtf8: UTF8String;
begin
  AStream.WriteByte(C_TAG_TEXT);
  lUtf8 := UTF8Encode(AText);
  WriteCount(AStream, Length(lUtf8));
  if Length(lUtf8) > 0 then
    AStream.WriteBuffer(lUtf8[1], Length(lUtf8));
end;

procedure TCodecAllTypesTests.W_Bytes(AStream: TStream; const AData: TBytes);
var
  lLen: SizeInt;
begin
  AStream.WriteByte(C_TAG_BYTES);
  lLen := Length(AData);
  WriteCount(AStream, lLen);
  if lLen > 0 then
    AStream.WriteBuffer(AData[0], lLen);
end;

procedure TCodecAllTypesTests.W_TimestampMs(AStream: TStream; const AMs: Int64);
begin
  AStream.WriteByte(C_TAG_TIMESTAMP);
  WriteInt64(AStream, AMs);
end;

procedure TCodecAllTypesTests.W_Decimal(AStream: TStream; const AMantissa: Int64; const AScale: Byte);
begin
  AStream.WriteByte(C_TAG_DECIMAL);
  WriteInt64(AStream, AMantissa);
  AStream.WriteByte(AScale);
end;

procedure TCodecAllTypesTests.W_List_Begin(AStream: TStream; const ACount: Int64);
begin
  AStream.WriteByte(C_TAG_LIST);
  WriteCount(AStream, ACount);
end;

procedure TCodecAllTypesTests.W_Map_Begin(AStream: TStream; const ACount: Int64);
begin
  AStream.WriteByte(C_TAG_MAP);
  WriteCount(AStream, ACount);
end;

procedure TCodecAllTypesTests.RoundTrip_Null;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    W_Null(lMS);
    AssertRoundTrip(BytesOfStream(lMS), 'null');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_Bool_True;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    W_Bool(lMS, True);
    AssertRoundTrip(BytesOfStream(lMS), 'bool true');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_Bool_False;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    W_Bool(lMS, False);
    AssertRoundTrip(BytesOfStream(lMS), 'bool false');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_Int32_PosNeg;
var
  lMS: TMemoryStream;
begin
  // Positive
  lMS := TMemoryStream.Create;
  try
    W_Int32(lMS, 123456789);
    AssertRoundTrip(BytesOfStream(lMS), 'int32 +');
  finally
    lMS.Free;
  end;
  // Negative
  lMS := TMemoryStream.Create;
  try
    W_Int32(lMS, -123456789);
    AssertRoundTrip(BytesOfStream(lMS), 'int32 -');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_Int64_Big;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    W_Int64(lMS, 1234567890123456789);
    AssertRoundTrip(BytesOfStream(lMS), 'int64 big');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_Text_UTF8;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    W_Text(lMS, 'Hello ξΔ漢字');
    AssertRoundTrip(BytesOfStream(lMS), 'text utf8');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_Bytes_Blob;
var
  lMS: TMemoryStream;
  lBlob: TBytes;
begin
  SetLength(lBlob, 8);
  lBlob[0] := $00; lBlob[1] := $FF; lBlob[2] := $10; lBlob[3] := $20;
  lBlob[4] := $33; lBlob[5] := $44; lBlob[6] := $55; lBlob[7] := $66;
  lMS := TMemoryStream.Create;
  try
    W_Bytes(lMS, lBlob);
    AssertRoundTrip(BytesOfStream(lMS), 'bytes blob');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_TimestampMs;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    W_TimestampMs(lMS, 1730000000123); // arbitrary
    AssertRoundTrip(BytesOfStream(lMS), 'timestamp ms');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_Decimal;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    // 12345 * 10^-2  => 123.45
    W_Decimal(lMS, 12345, 2);
    AssertRoundTrip(BytesOfStream(lMS), 'decimal 123.45');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_List_Mixed;
var
  lMS: TMemoryStream;
begin
  lMS := TMemoryStream.Create;
  try
    // list of 3: [Int32(42), Text('x'), Int64(2^40)]
    W_List_Begin(lMS, 3);
    W_Int32(lMS, 42);
    W_Text(lMS, 'x');
    W_Int64(lMS, 1 shl 40);
    AssertRoundTrip(BytesOfStream(lMS), 'list mixed');
  finally
    lMS.Free;
  end;
end;

procedure TCodecAllTypesTests.RoundTrip_Map_Mixed;
var
  lMS: TMemoryStream;
  lBytes: TBytes;
begin
  lMS := TMemoryStream.Create;
  try
    // map of 2: {'a': Int32(1), 'b': Bytes(3)}
    W_Map_Begin(lMS, 2);
    W_Text(lMS, 'a');
    W_Int32(lMS, 1);
    W_Text(lMS, 'b');
    SetLength(lBytes, 3);
    lBytes[0] := 1; lBytes[1] := 2; lBytes[2] := 3;
    W_Bytes(lMS, lBytes);
    AssertRoundTrip(BytesOfStream(lMS), 'map mixed');
  finally
    lMS.Free;
  end;
end;

initialization
  RegisterTest(TCodecAllTypesTests);
end.
