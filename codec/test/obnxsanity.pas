{$mode objfpc}{$H+}
unit obNxSanity;

interface

procedure RunNxrpSanityChecks;

implementation

uses
  SysUtils, Classes,
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  obNxTypes, obNxBin, obNxRpcCore;

type
  // Simple object to test published-property streaming
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

procedure Log(const S: UnicodeString);
begin
  {$IFDEF MSWINDOWS}
  OutputDebugStringW(PWideChar(S));
  OutputDebugStringW(PWideChar(#13#10));
  {$ELSE}
  // No-op by default in non-Windows GUI apps.
  // To route to Lazarus Messages window, add LazLoggerBase to uses and call:
  // DebugLn(UTF8Encode(S));
  {$ENDIF}
end;

procedure AssertTrue(const ACond: Boolean; const AMsg: UnicodeString);
begin
  if not ACond then
    raise Exception.Create('AssertTrue failed: ' + AMsg);
end;

procedure AssertEqualInt(const A, B: Int64; const AMsg: UnicodeString);
begin
  if A <> B then
    raise Exception.Create(Format('AssertEqualInt failed: %s (got %d, expected %d)',
      [AMsg, A, B]));
end;

procedure AssertEqualStr(const A, B, AMsg: UnicodeString);
begin
  if A <> B then
    raise Exception.Create(Format('AssertEqualStr failed: %s (got "%s", expected "%s")',
      [AMsg, A, B]));
end;

function BytesEqual(const A, B: TBytes): Boolean;
var
  i, n: Integer;
begin
  n := Length(A);
  if Length(B) <> n then
    Exit(False);
  for i := 0 to n-1 do
    if A[i] <> B[i] then
      Exit(False);
  Result := True;
end;

procedure CheckIdempotentCanonical(const Val: TNxVal; const Codec: INxCodec; const LabelName: UnicodeString);
var
  b1, b2: TBytes;
  v2: TNxVal;
begin
  b1 := Codec.EncodeCanonical(Val);
  v2 := Codec.Decode(b1);
  try
    b2 := Codec.EncodeCanonical(v2);
    AssertTrue(BytesEqual(b1, b2), 'Canonical re-encode mismatch: ' + LabelName);
  finally
    v2.Free;
  end;
end;

procedure TestScalarsAndContainers;
var
  c: INxCodec;
  v, m, l: TNxVal;
begin
  Log('> Scalars & containers…');
  c := TNxCodec.Create;

  v := TNxVal.Int(42);
  try
    CheckIdempotentCanonical(v, c, 'int');
  finally
    v.Free;
  end;

  v := TNxVal.Bool(True);
  try
    CheckIdempotentCanonical(v, c, 'bool');
  finally
    v.Free;
  end;

  v := TNxVal.Text('Hello ☕');
  try
    CheckIdempotentCanonical(v, c, 'text');
  finally
    v.Free;
  end;

  l := TNxVal.List;
  l.AsList.Add(TNxVal.Int(1));
  l.AsList.Add(TNxVal.Text('two'));
  l.AsList.Add(TNxVal.Bool(False));
  try
    CheckIdempotentCanonical(l, c, 'list');
  finally
    l.Free;
  end;

  m := TNxVal.Map;
  m.AsMap.SetKey('alpha', TNxVal.Int(1));
  m.AsMap.SetKey('bravo', TNxVal.Text('B'));
  m.AsMap.SetKey('charlie', TNxVal.Bool(True));
  try
    CheckIdempotentCanonical(m, c, 'map');
  finally
    m.Free;
  end;

  Log('  ok');
end;

procedure TestObjectRoundTrip;
var
  c: INxCodec;
  o1, o2: TMyObj;
  v, v2, tVal: TNxVal;
  tId: UnicodeString;
  bytes: TBytes;
  Cls: TNXRPClass;
begin
  Log('> TNXRPObject round-trip…');

  // Register class by its TypeId (default is ClassName) only once
  if not TNXRPRegistry.TryGetClass('TMyObj', Cls) then
    TNXRPRegistry.RegisterType('TMyObj', TMyObj);

  o1 := TMyObj.Create;
  try
    o1.Foo := 123;
    o1.Bar := 'béta';
    o1.Baz := True;

    v := o1.ToNxVal; // Map with 't' and 'f'
    try
      c := TNxCodec.Create;
      bytes := c.EncodeCanonical(v);
      v2 := c.Decode(bytes);
      try
        // Instantiate by type id and populate
        AssertTrue(v2.Kind = nkMap, 'decoded object must be a map');
        if not v2.AsMap.TryGet('t', tVal) then
          raise Exception.Create('missing t in object map');
        tId := tVal.AsText;

        o2 := TMyObj(TNXRPRegistry.CreateByTypeId(tId));
        try
          o2.FromNxVal(v2);

          // Validate properties
          AssertEqualInt(o2.Foo, 123, 'Foo');
          AssertEqualStr(o2.Bar, 'béta', 'Bar');
          AssertTrue(o2.Baz = True, 'Baz');

          // And ensure canonical NXBIN is stable
          CheckIdempotentCanonical(v2, c, 'object map');
        finally
          o2.Free;
        end;
      finally
        v2.Free;
      end;
    finally
      v.Free;
    end;
  finally
    o1.Free;
  end;

  Log('  ok');
end;

procedure TestListAndNameIndex;
var
  l1, l2: TNXRPList;
  o: TMyObj;
  c: INxCodec;
  v, v2: TNxVal;
  found: TNXRPObject;
  results: TNXRPList;
  Cls: TNXRPClass;
begin
  Log('> TNXRPList + name index + encode/decode…');

  if not TNXRPRegistry.TryGetClass('TMyObj', Cls) then
    TNXRPRegistry.RegisterType('TMyObj', TMyObj);

  l1 := TNXRPList.Create;
  try
    l1.EnableNameIndex(nil, False); // case-insensitive
    // Add a couple of objects
    o := TMyObj.Create; o.Foo := 1; o.Bar := 'alpha'; o.Baz := False; l1.Add(o); l1.Names[l1.Count-1] := 'A';
    o := TMyObj.Create; o.Foo := 2; o.Bar := 'bravo'; o.Baz := True;  l1.Add(o); l1.Names[l1.Count-1] := 'a'; // duplicate name on purpose
    o := TMyObj.Create; o.Foo := 3; o.Bar := 'charlie'; o.Baz := False; l1.Add(o); l1.Names[l1.Count-1] := 'C';

    // Index lookups
    found := l1.FindFirst('a');
    AssertTrue(found <> nil, 'FindFirst("a") should find something');
    AssertEqualInt(TMyObj(found).Foo, 1, 'FindFirst returns first insertion');

    results := TNXRPList.Create;
    try
      l1.FindAll('a', results);
      AssertEqualInt(results.Count, 2, 'FindAll("a") count');
      AssertEqualInt(TMyObj(results.Items[0]).Foo, 1, 'FindAll[0].Foo');
      AssertEqualInt(TMyObj(results.Items[1]).Foo, 2, 'FindAll[1].Foo');
    finally
      results.Free;
    end;

    // Serialize & deserialize the list
    v := l1.ToNxVal;
    try
      c := TNxCodec.Create;
      v2 := c.Decode(c.EncodeCanonical(v));
      try
        // Rehydrate into a new list
        l2 := TNXRPList.Create;
        try
          l2.FromNxVal(v2);
          AssertEqualInt(l2.Count, 3, 'rehydrated list count');
          AssertEqualStr(TMyObj(l2.Items[0]).Bar, 'alpha', 'rehydrated[0].Bar');
          AssertEqualInt(TMyObj(l2.Items[1]).Foo, 2, 'rehydrated[1].Foo');

          // canonical stability on the list's object map
          CheckIdempotentCanonical(v2, c, 'list object map');
        finally
          l2.Free;
        end;
      finally
        v2.Free;
      end;
    finally
      v.Free;
    end;
  finally
    l1.Free;
  end;

  Log('  ok');
end;

procedure RunNxrpSanityChecks;
begin
  Log('NXRP-X sanity checks starting…');
  TestScalarsAndContainers;
  TestObjectRoundTrip;
  TestListAndNameIndex;
  Log('All sanity checks passed.');
end;

end.

