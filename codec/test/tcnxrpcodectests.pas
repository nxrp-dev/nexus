unit tcNxrpCodecTests;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpcunit, testutils, testregistry,
  obNxTypes, obNxBin, obNxRpcCore;

type
  // Simple RTTI-backed object for round-trip tests
  TMyObj = class(TNXRPObject)
  private
    FFoo: Integer;
    FBar: UnicodeString;
    FBaz: Boolean;
  published
    property Foo: Integer read FFoo write FFoo;
    property Bar: UnicodeString read FBar write FBar;
    property Baz: Boolean read FBaz write FBaz;
  end;

  { TCodecCoreTests }

  TCodecCoreTests = class(TTestCase)
  private
    procedure EnsureTypeRegistered;
    function BytesEqual(const A, B: TBytes): Boolean;
    procedure AssertCanonicalRoundTrip(const C: INxCodec; V: TNxVal; const Msg: UnicodeString);
    procedure AppendBytes(var A: TBytes; const More: array of Byte);
  published
    // TNxVal kinds
    procedure Test_Null_Canonical;
    procedure Test_Bool_TrueFalse_Canonical;
    procedure Test_Int_Boundaries_Canonical;
    procedure Test_Bytes_Canonical;
    procedure Test_Text_Variants_Canonical;
    procedure Test_List_Mixed_Canonical;
    procedure Test_Map_Canonical;

    // RTTI object + list
    procedure Test_Object_RoundTrip;
    procedure Test_List_NameIndex_FindFirst_FindAll;

    // Decoder hard-failures
    procedure Test_InvalidUtf8_Rejected;
    procedure Test_TrailingBytes_Rejected;
    procedure Test_UnknownType_DecodeError;
  end;

implementation

{ TCodecCoreTests }

procedure TCodecCoreTests.EnsureTypeRegistered;
var
  C: TNXRPClass;
begin
  if not TNXRPRegistry.TryGetClass('TMyObj', C) then
    TNXRPRegistry.RegisterType('TMyObj', TMyObj);
end;

function TCodecCoreTests.BytesEqual(const A, B: TBytes): Boolean;
var
  i, n: Integer;
begin
  n := Length(A);
  if Length(B) <> n then Exit(False);
  for i := 0 to n - 1 do
    if A[i] <> B[i] then Exit(False);
  Result := True;
end;

procedure TCodecCoreTests.AppendBytes(var A: TBytes; const More: array of Byte);
var
  i, ofs, add: Integer;
begin
  ofs := Length(A);
  add := Length(More);
  SetLength(A, ofs + add);
  for i := 0 to add - 1 do
    A[ofs + i] := More[i];
end;

procedure TCodecCoreTests.AssertCanonicalRoundTrip(const C: INxCodec; V: TNxVal; const Msg: UnicodeString);
var
  B1, B2: TBytes;
  V2: TNxVal;
begin
  B1 := C.EncodeCanonical(V);    // value -> bytes
  V2 := C.Decode(B1);            // bytes -> value
  try
    B2 := C.EncodeCanonical(V2); // value -> bytes again (canonical)
    AssertTrue(Msg + ' (canonical re-encode mismatch)', BytesEqual(B1, B2));
  finally
    V2.Free;
  end;
end;

procedure TCodecCoreTests.Test_Null_Canonical;
var
  C: INxCodec;
  V: TNxVal;
begin
  C := TNxCodec.Create;
  V := TNxVal.Null;
  try
    AssertCanonicalRoundTrip(C, V, 'Null');
    AssertEquals('Kind must be nkNull', Ord(nkNull), Ord(V.Kind));
  finally
    V.Free;
  end;
end;

procedure TCodecCoreTests.Test_Bool_TrueFalse_Canonical;
var
  C: INxCodec;
  V, V2: TNxVal;
  B: TBytes;
begin
  C := TNxCodec.Create;

  V := TNxVal.Bool(True);
  try
    AssertCanonicalRoundTrip(C, V, 'Bool True');
  finally
    V.Free;
  end;

  V := TNxVal.Bool(False);
  try
    AssertCanonicalRoundTrip(C, V, 'Bool False');

    // decode -> encode sanity from bytes path
    B := C.EncodeCanonical(V);
    V2 := C.Decode(B);
    try
      AssertTrue('Bool False value', not V2.AsBool);
    finally
      V2.Free;
    end;
  finally
    V.Free;
  end;
end;

procedure TCodecCoreTests.Test_Int_Boundaries_Canonical;
const
  NVALS = 8;
var
  C: INxCodec;
  V: TNxVal;
  Cases: array[0..NVALS-1] of Int64;
  i: Integer;
begin
  // representative zigzag/varint edges (avoid literal Low(Int64) issues)
  Cases[0] := 0;
  Cases[1] := 1;
  Cases[2] := -1;
  Cases[3] := 127;
  Cases[4] := -128;
  Cases[5] := High(Longint);       //  2147483647
  Cases[6] := -2147483648;         // -2147483648
  Cases[7] := (Int64(1) shl 40);   //  1,099,511,627,776

  C := TNxCodec.Create;
  for i := 0 to NVALS-1 do
  begin
    V := TNxVal.Int(Cases[i]);
    try
      AssertCanonicalRoundTrip(C, V, 'Int case ' + IntToStr(i));
    finally
      V.Free;
    end;
  end;
end;

procedure TCodecCoreTests.Test_Bytes_Canonical;
var
  C: INxCodec;
  V, V2: TNxVal;
  B1, B2: TBytes;
begin
  C := TNxCodec.Create;

  SetLength(B1, 6);
  B1[0] := 0;
  B1[1] := $FF;
  B1[2] := $7F;
  B1[3] := $80;
  B1[4] := $00;
  B1[5] := $AA;

  V := TNxVal.Bytes(B1);
  try
    B2 := C.EncodeCanonical(V);
    V2 := C.Decode(B2);
    try
      AssertTrue('Bytes equal after round-trip', BytesEqual(B1, V2.AsBytes));
      // and canonical re-encode stable
      AssertTrue('Bytes canonical mismatch', BytesEqual(B2, C.EncodeCanonical(V2)));
    finally
      V2.Free;
    end;
  finally
    V.Free;
  end;
end;

procedure TCodecCoreTests.Test_Text_Variants_Canonical;
var
  C: INxCodec;
  V: TNxVal;
begin
  C := TNxCodec.Create;

  V := TNxVal.Text('ASCII');
  try
    AssertCanonicalRoundTrip(C, V, 'Text ASCII');
  finally
    V.Free;
  end;

  V := TNxVal.Text('béta');
  try
    AssertCanonicalRoundTrip(C, V, 'Text Latin-1-ish');
  finally
    V.Free;
  end;

  V := TNxVal.Text('Hello ☕');
  try
    AssertCanonicalRoundTrip(C, V, 'Text BMP emoji');
  finally
    V.Free;
  end;

  // U+1D11E MUSICAL SYMBOL G CLEF (non-BMP, 4-byte UTF-8)
  V := TNxVal.Text('𝄞');
  try
    AssertCanonicalRoundTrip(C, V, 'Text non-BMP 4-byte');
  finally
    V.Free;
  end;
end;

procedure TCodecCoreTests.Test_List_Mixed_Canonical;
var
  C: INxCodec;
  L, V2: TNxVal;
  B1, B2: TBytes;
begin
  C := TNxCodec.Create;

  L := TNxVal.List;
  try
    L.AsList.Add(TNxVal.Int(-5));
    L.AsList.Add(TNxVal.Text('two'));
    L.AsList.Add(TNxVal.Bool(True));

    B1 := C.EncodeCanonical(L);
    V2 := C.Decode(B1);
    try
      B2 := C.EncodeCanonical(V2);
      AssertTrue('List canonical mismatch', BytesEqual(B1, B2));
    finally
      V2.Free;
    end;
  finally
    L.Free;
  end;
end;

procedure TCodecCoreTests.Test_Map_Canonical;
var
  C: INxCodec;
  M, V2: TNxVal;
  B1, B2: TBytes;
begin
  C := TNxCodec.Create;

  M := TNxVal.Map;
  try
    // Intentional unsorted insertion order
    M.AsMap.SetKey('charlie', TNxVal.Bool(True));
    M.AsMap.SetKey('alpha',   TNxVal.Int(1));
    M.AsMap.SetKey('bravo',   TNxVal.Text('B'));

    B1 := C.EncodeCanonical(M);
    V2 := C.Decode(B1);
    try
      B2 := C.EncodeCanonical(V2);
      AssertTrue('Map canonical mismatch (UTF-8 key order)', BytesEqual(B1, B2));
    finally
      V2.Free;
    end;
  finally
    M.Free;
  end;
end;

procedure TCodecCoreTests.Test_Object_RoundTrip;
var
  C: INxCodec;
  O1, O2: TMyObj;
  V, V2, TVal: TNxVal;
  Bytes: TBytes;
  TypeId: UnicodeString;
begin
  EnsureTypeRegistered;
  C := TNxCodec.Create;

  O1 := TMyObj.Create;
  try
    O1.Foo := 123;
    O1.Bar := 'béta';
    O1.Baz := True;

    V := O1.ToNxVal;
    try
      Bytes := C.EncodeCanonical(V);
      V2 := C.Decode(Bytes);
      try
        if not V2.AsMap.TryGet('t', TVal) then
          Fail('Missing "t" in object map');
        TypeId := TVal.AsText;

        O2 := TMyObj(TNXRPRegistry.CreateByTypeId(TypeId));
        try
          O2.FromNxVal(V2);
          AssertEquals('Foo', 123, O2.Foo);
          AssertTrue('Bar', O2.Bar = 'béta');
          AssertTrue('Baz', O2.Baz);

          AssertTrue('Object map canonical mismatch',
            BytesEqual(Bytes, C.EncodeCanonical(V2)));
        finally
          O2.Free;
        end;
      finally
        V2.Free;
      end;
    finally
      V.Free;
    end;
  finally
    O1.Free;
  end;
end;

procedure TCodecCoreTests.Test_List_NameIndex_FindFirst_FindAll;
var
  L, OutList: TNXRPList;
  O: TMyObj;
begin
  EnsureTypeRegistered;

  L := TNXRPList.Create;
  try
    L.EnableNameIndex(nil, False); // case-insensitive

    O := TMyObj.Create; O.Foo := 1; O.Bar := 'alpha'; O.Baz := False; L.Add(O); L.Names[L.Count-1] := 'A';
    O := TMyObj.Create; O.Foo := 2; O.Bar := 'bravo'; O.Baz := True;  L.Add(O); L.Names[L.Count-1] := 'a'; // duplicate
    O := TMyObj.Create; O.Foo := 3; O.Bar := 'charlie'; O.Baz := False; L.Add(O); L.Names[L.Count-1] := 'C';

    // FindFirst
    O := TMyObj(L.FindFirst('a'));
    AssertNotNull('FindFirst("a") result', O);
    AssertEquals('First is Foo=1', 1, O.Foo);

    // FindAll
    OutList := TNXRPList.Create;
    try
      L.FindAll('a', OutList);
      AssertEquals('FindAll count', 2, OutList.Count);
      AssertEquals('First match Foo', 1, TMyObj(OutList.Items[0]).Foo);
      AssertEquals('Second match Foo', 2, TMyObj(OutList.Items[1]).Foo);
    finally
      OutList.Free;
    end;
  finally
    L.Free;
  end;
end;

procedure TCodecCoreTests.Test_InvalidUtf8_Rejected;
var
  C: INxCodec;
  Bad: TBytes;
  RaisedErr: Boolean;
  V: TNxVal;
begin
  C := TNxCodec.Create;
  SetLength(Bad, 0);
  RaisedErr := False;

  // Craft NXBIN: MAP tag(0x07), count=1, key=TEXT(len=1, byte=0xC0 invalid), value=NULL(0x00)
  AppendBytes(Bad, [$07]); // map
  AppendBytes(Bad, [$01]); // count=1
  AppendBytes(Bad, [$05]); // text
  AppendBytes(Bad, [$01]); // length=1
  AppendBytes(Bad, [$C0]); // invalid overlong starter
  AppendBytes(Bad, [$00]); // null

  try
    V := C.Decode(Bad);
    try
      V.Free;
    finally
    end;
  except
    on E: ENxCodecError do RaisedErr := True;
  end;

  AssertTrue('Decoder must reject invalid UTF-8', RaisedErr);
end;

procedure TCodecCoreTests.Test_TrailingBytes_Rejected;
var
  C: INxCodec;
  V, V2: TNxVal;
  B: TBytes;
  RaisedErr: Boolean;
begin
  C := TNxCodec.Create;
  V := TNxVal.Int(7);
  RaisedErr := False;
  try
    B := C.EncodeCanonical(V);
    // append a trailing garbage byte
    SetLength(B, Length(B)+1);
    B[Length(B)-1] := $FF;

    try
      V2 := C.Decode(B);
      try
        V2.Free;
      finally
      end;
    except
      on E: ENxCodecError do RaisedErr := True;
    end;

    AssertTrue('Decoder must reject trailing bytes', RaisedErr);
  finally
    V.Free;
  end;
end;

procedure TCodecCoreTests.Test_UnknownType_DecodeError;
var
  C: INxCodec;
  ObjMap, Fields, Root, TVal: TNxVal;
  Bytes: TBytes;
  RaisedErr: Boolean;
begin
  C := TNxCodec.Create;
  RaisedErr := False;

  // Build { t: "Nope", f: {} } and decode
  ObjMap := TNxVal.Map;
  try
    Fields := TNxVal.Map;
    ObjMap.AsMap.SetKey('t', TNxVal.Text('Nope'));
    ObjMap.AsMap.SetKey('f', Fields);

    Bytes := C.EncodeCanonical(ObjMap);

    Root := C.Decode(Bytes);
    try
      if not Root.AsMap.TryGet('t', TVal) then
        Fail('missing t');

      try
        TNXRPRegistry.CreateByTypeId(TVal.AsText); // should raise
      except
        on E: Exception do RaisedErr := True;
      end;

      AssertTrue('Unknown TypeId must raise', RaisedErr);
    finally
      Root.Free;
    end;
  finally
    ObjMap.Free;
  end;
end;

initialization
  RegisterTest(TCodecCoreTests);
end.

