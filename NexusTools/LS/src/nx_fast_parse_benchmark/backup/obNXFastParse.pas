unit obNXFastParse;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TNXFastStringSet = class
  private type
    TNXFastStringEntry = record
      Text: string;
      Data: PChar;
    end;

    TNXFastStringBucket = record
      Start: LongInt;
      Count: LongInt;
    end;

  private
    FEntries: array of TNXFastStringEntry;
    FBuckets: array of TNXFastStringBucket;
    FLengthIndex: array of LongInt;

    class function BucketKey(const AFirst: Byte; const ALast: Byte): SizeInt; static; inline;

    function GetBucketIndex(const ALength: SizeInt; const AFirst: Byte; const ALast: Byte): SizeInt; inline;

  public
    constructor Create(const AWords: array of string);

    function Contains(const AText: string): Boolean; inline;
  end;

  TNXPascalKeywordSet = class sealed
  private
    class var FKeywordSet: TNXFastStringSet;

  public
    class constructor Create;
    class destructor Destroy;

    class function Contains(const AText: string): Boolean; static; inline;
  end;

implementation

const
  cPascalKeywords: array[0..78] of string = (
    'absolute', 'and', 'array', 'as', 'asm', 'begin', 'bitpacked',
    'case', 'class', 'const', 'constructor', 'destructor', 'dispinterface',
    'div', 'do', 'downto', 'else', 'end', 'except', 'exports', 'file',
    'false', 'finalization', 'finally', 'for', 'function', 'generic', 'goto',
    'helper', 'if', 'implementation', 'in', 'inherited', 'initialization',
    'inline', 'interface', 'is', 'label', 'library', 'mod', 'nil', 'not',
    'object', 'of', 'on', 'operator', 'or', 'out', 'package', 'packed',
    'private', 'procedure', 'program', 'property', 'protected', 'public',
    'published', 'raise', 'record', 'repeat', 'resourcestring', 'set',
    'shl', 'shr', 'specialize', 'string', 'then', 'threadvar', 'to', 'try',
    'true', 'type', 'unit', 'until', 'uses', 'var', 'while', 'with', 'xor'
  );

class function TNXFastStringSet.BucketKey(const AFirst: Byte; const ALast: Byte): SizeInt;
begin
  Result := (SizeInt(AFirst) shl 8) or SizeInt(ALast);
end;

function TNXFastStringSet.GetBucketIndex(const ALength: SizeInt; const AFirst: Byte; const ALast: Byte): SizeInt;
var
  lLengthSlot: LongInt;
begin
  lLengthSlot := FLengthIndex[ALength];

  if lLengthSlot < 0 then
    Result := -1
  else
    Result := (SizeInt(lLengthSlot) shl 16) or BucketKey(AFirst, ALast);
end;

constructor TNXFastStringSet.Create(const AWords: array of string);
var
  lIndex: LongInt;
  lEntryIndex: LongInt;
  lWordLength: SizeInt;
  lMaxLength: SizeInt;
  lDistinctLengthCount: LongInt;
  lBucketIndex: SizeInt;
  lFirst: Byte;
  lLast: Byte;
  lStart: LongInt;
  lCount: LongInt;
  lPositions: array of LongInt;
begin
  inherited Create;

  lMaxLength := 0;

  for lIndex := Low(AWords) to High(AWords) do
  begin
    lWordLength := System.Length(AWords[lIndex]);

    if lWordLength > lMaxLength then
      lMaxLength := lWordLength;
  end;

  SetLength(FLengthIndex, lMaxLength + 1);

  for lIndex := Low(FLengthIndex) to High(FLengthIndex) do
    FLengthIndex[lIndex] := -1;

  lDistinctLengthCount := 0;

  for lIndex := Low(AWords) to High(AWords) do
  begin
    lWordLength := System.Length(AWords[lIndex]);

    if FLengthIndex[lWordLength] < 0 then
    begin
      FLengthIndex[lWordLength] := lDistinctLengthCount;
      Inc(lDistinctLengthCount);
    end;
  end;

  SetLength(FBuckets, SizeInt(lDistinctLengthCount) shl 16);
  SetLength(FEntries, System.Length(AWords));

  for lIndex := Low(AWords) to High(AWords) do
  begin
    lWordLength := System.Length(AWords[lIndex]);

    if lWordLength = 0 then
    begin
      lFirst := 0;
      lLast := 0;
    end
    else
    begin
      lFirst := Ord(AWords[lIndex][1]);
      lLast := Ord(AWords[lIndex][lWordLength]);
    end;

    lBucketIndex := GetBucketIndex(lWordLength, lFirst, lLast);
    Inc(FBuckets[lBucketIndex].Count);
  end;

  lStart := 0;

  for lIndex := Low(FBuckets) to High(FBuckets) do
  begin
    lCount := FBuckets[lIndex].Count;
    FBuckets[lIndex].Start := lStart;
    Inc(lStart, lCount);
  end;

  SetLength(lPositions, System.Length(FBuckets));

  for lIndex := Low(FBuckets) to High(FBuckets) do
    lPositions[lIndex] := FBuckets[lIndex].Start;

  for lIndex := Low(AWords) to High(AWords) do
  begin
    lWordLength := System.Length(AWords[lIndex]);

    if lWordLength = 0 then
    begin
      lFirst := 0;
      lLast := 0;
    end
    else
    begin
      lFirst := Ord(AWords[lIndex][1]);
      lLast := Ord(AWords[lIndex][lWordLength]);
    end;

    lBucketIndex := GetBucketIndex(lWordLength, lFirst, lLast);
    lEntryIndex := lPositions[lBucketIndex];
    Inc(lPositions[lBucketIndex]);

    FEntries[lEntryIndex].Text := AWords[lIndex];
    FEntries[lEntryIndex].Data := PChar(FEntries[lEntryIndex].Text);
  end;
end;

function TNXFastStringSet.Contains(const AText: string): Boolean;
var
  lLength: SizeInt;
  lFirst: Byte;
  lLast: Byte;
  lBucketIndex: SizeInt;
  lBucketStart: LongInt;
  lBucketCount: LongInt;
  lIndex: LongInt;
  lData: PChar;
begin
  Result := False;

  lLength := System.Length(AText);

  if lLength > High(FLengthIndex) then
    Exit;

  if lLength = 0 then
  begin
    lFirst := 0;
    lLast := 0;
  end
  else
  begin
    lFirst := Ord(AText[1]);
    lLast := Ord(AText[lLength]);
  end;

  lBucketIndex := GetBucketIndex(lLength, lFirst, lLast);

  if lBucketIndex < 0 then
    Exit;

  lBucketStart := FBuckets[lBucketIndex].Start;
  lBucketCount := FBuckets[lBucketIndex].Count;

  if lBucketCount = 0 then
    Exit;

  if lLength = 0 then
  begin
    Result := True;
    Exit;
  end;

  lData := PChar(AText);

  if lBucketCount = 1 then
  begin
    Result := CompareMem(FEntries[lBucketStart].Data, lData, lLength);
    Exit;
  end;

  for lIndex := lBucketStart to lBucketStart + lBucketCount - 1 do
  begin
    if CompareMem(FEntries[lIndex].Data, lData, lLength) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

class constructor TNXPascalKeywordSet.Create;
begin
  FKeywordSet := TNXFastStringSet.Create(cPascalKeywords);
end;

class destructor TNXPascalKeywordSet.Destroy;
begin
  FreeAndNil(FKeywordSet);
end;

class function TNXPascalKeywordSet.Contains(const AText: string): Boolean;
begin
  Result := FKeywordSet.Contains(AText);
end;

end.
