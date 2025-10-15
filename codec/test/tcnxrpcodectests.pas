unit tcNxrpCodecTests;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpcunit, testutils, testregistry,
  obNxTypes, obNxBin, utCodecIO;

type
  TCodecCoreTests = class(TTestCase)
  published
    procedure Int32_LE_Bytes_And_RoundTrip;
    procedure Int64_LE_Bytes_And_RoundTrip;
    procedure DefaultCount_Writes_FixedWidth;
    procedure EncodeDecode_Int32_And_Int64;
  end;

implementation

{$I ../src/tpPlatform.inc}

procedure TCodecCoreTests.Int32_LE_Bytes_And_RoundTrip;
var
  lMs: TMemoryStream;
  lV: LongInt;
  lBytes: array[0..3] of Byte;
begin
  lMs := TMemoryStream.Create;
  try
    lV := LongInt($12345678);
    WriteInt32(lMs, lV);
    AssertEquals(SizeInt(4), lMs.Size);
    lMs.Position := 0;
    lMs.ReadBuffer(lBytes, 4);
    AssertEquals(Byte($78), lBytes[0]);
    AssertEquals(Byte($56), lBytes[1]);
    AssertEquals(Byte($34), lBytes[2]);
    AssertEquals(Byte($12), lBytes[3]);
    lMs.Position := 0;
    AssertEquals(lV, ReadInt32(lMs));
  finally
    lMs.Free;
  end;
end;

procedure TCodecCoreTests.Int64_LE_Bytes_And_RoundTrip;
var
  lMs: TMemoryStream;
  lV: Int64;
  lBytes: array[0..7] of Byte;
begin
  lMs := TMemoryStream.Create;
  try
    lV := Int64($EFCDAB9078563412);
    WriteInt64(lMs, lV);
    AssertEquals(SizeInt(8), lMs.Size);
    lMs.Position := 0;
    lMs.ReadBuffer(lBytes, 8);
    AssertEquals(Byte($12), lBytes[0]);
    AssertEquals(Byte($34), lBytes[1]);
    AssertEquals(Byte($56), lBytes[2]);
    AssertEquals(Byte($78), lBytes[3]);
    AssertEquals(Byte($90), lBytes[4]);
    AssertEquals(Byte($AB), lBytes[5]);
    AssertEquals(Byte($CD), lBytes[6]);
    AssertEquals(Byte($EF), lBytes[7]);
    lMs.Position := 0;
    AssertEquals(lV, ReadInt64(lMs));
  finally
    lMs.Free;
  end;
end;

procedure TCodecCoreTests.DefaultCount_Writes_FixedWidth;
var
  lMs: TMemoryStream;
  lN: Int64;
begin
  lMs := TMemoryStream.Create;
  try
    lN := 1024;
    WriteCount(lMs, lN);
    lMs.Position := 0;
    AssertEquals(lN, ReadCount(lMs));
  finally
    lMs.Free;
  end;
end;

procedure TCodecCoreTests.EncodeDecode_Int32_And_Int64;
var
  lCodec: INxCodec;
  lV32, lV64: TNxVal;
  lBytes: TBytes;
  lBack: TNxVal;
begin
  lCodec := TNxCodec.Create;
  lV32 := TNxVal.Int(123456);    // 32-bit tag
  lBytes := lCodec.Encode(lV32);
  lBack := lCodec.Decode(lBytes);
  AssertEquals(Ord(nkInt), Ord(lBack.Kind));
  AssertEquals(Int64(123456), lBack.AsInt);

  lV64 := TNxVal.Int64(1234567890123); // 64-bit tag
  lBytes := lCodec.Encode(lV64);
  lBack := lCodec.Decode(lBytes);
  AssertEquals(Ord(nkInt64), Ord(lBack.Kind));
  AssertEquals(Int64(1234567890123), lBack.AsInt);
end;

initialization
  RegisterTest(TCodecCoreTests);
end.