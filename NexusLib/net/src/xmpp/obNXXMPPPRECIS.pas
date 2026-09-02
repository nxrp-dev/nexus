unit obNXXMPPPRECIS;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPICU, obNXXMPPError, tpNXXMPPTypes;

type
  TNXXMPPPRECIS = class
  public
    class function EnforceUsernameCaseMapped(
      const AValue: UTF8String): UTF8String; static;
    class function EnforceOpaqueString(const AValue: UTF8String): UTF8String; static;
  end;

implementation

const
  cUCharCanonicalCombiningClass = $1002;
  cUCharGeneralCategory = $1005;
  cUCharJoiningType = $1007;
  cUCharScript = $100A;
  cUSpaceSeparator = 12;
  cUJoiningNonJoining = 0;
  cUJoiningDual = 2;
  cUJoiningLeft = 3;
  cUJoiningRight = 4;
  cUJoiningTransparent = 5;
  cUScriptGreek = 14;
  cUScriptHan = 17;
  cUScriptHebrew = 19;
  cUScriptHiragana = 20;
  cUScriptKatakana = 22;
  cUScriptKatakanaOrHiragana = 54;
  cUBidiL = 0;
  cUBidiR = 1;
  cUBidiEN = 2;
  cUBidiES = 3;
  cUBidiET = 4;
  cUBidiAN = 5;
  cUBidiCS = 6;
  cUBidiON = 10;
  cUBidiAL = 13;
  cUBidiNSM = 17;
  cUBidiBN = 18;

type
  TNXXMPPPRECISProperty = (
    nppProtocolValid,
    nppContextJ,
    nppContextO,
    nppDisallowed,
    nppUnassigned,
    nppIdentifierDisallowedFreeformValid
  );

  TNXXMPPPRECISRange = record
    FirstCodePoint: Cardinal;
    LastCodePoint: Cardinal;
    PropertyValue: TNXXMPPPRECISProperty;
  end;

  TNXXMPPPRECISBaseClass = (pbcIdentifier, pbcFreeform);
  TNXXMPPCodePointArray = array of Cardinal;

{$I tpNXXMPPPRECISTableData.inc}

function DecodeCodePoints(const AValue: UTF8String): TNXXMPPCodePointArray;
var
  lCodePoint: Cardinal;
  lIndex: Integer;
  lLength: Integer;
  lSource: UnicodeString;
begin
  lSource := UTF8Decode(AValue);
  Result := nil;
  SetLength(Result, Length(lSource));
  lIndex := 1;
  lLength := 0;
  while lIndex <= Length(lSource) do
  begin
    lCodePoint := Ord(lSource[lIndex]);
    Inc(lIndex);
    if (lCodePoint >= $D800) and (lCodePoint <= $DBFF) then
    begin
      if (lIndex > Length(lSource)) or (Ord(lSource[lIndex]) < $DC00) or
        (Ord(lSource[lIndex]) > $DFFF) then
        raise ENXXMPPError.Create(xesConfiguration, 'invalid-utf8',
          'The value contains an invalid Unicode surrogate.');
      lCodePoint := $10000 + ((lCodePoint - $D800) shl 10) +
        (Ord(lSource[lIndex]) - $DC00);
      Inc(lIndex);
    end
    else if (lCodePoint >= $DC00) and (lCodePoint <= $DFFF) then
      raise ENXXMPPError.Create(xesConfiguration, 'invalid-utf8',
        'The value contains an invalid Unicode surrogate.');
    Result[lLength] := lCodePoint;
    Inc(lLength);
  end;
  SetLength(Result, lLength);
end;

function EncodeCodePoints(const ACodePoints: TNXXMPPCodePointArray): UTF8String;
var
  lCodePoint: Cardinal;
  lIndex: Integer;
  lValue: UnicodeString;
begin
  lValue := '';
  for lIndex := 0 to High(ACodePoints) do
  begin
    lCodePoint := ACodePoints[lIndex];
    if lCodePoint <= $FFFF then
      lValue := lValue + UnicodeString(WideChar(lCodePoint))
    else
    begin
      Dec(lCodePoint, $10000);
      lValue := lValue + UnicodeString(WideChar($D800 + (lCodePoint shr 10))) +
        UnicodeString(WideChar($DC00 + (lCodePoint and $3FF)));
    end;
  end;
  Result := UTF8Encode(lValue);
end;

function PropertyFor(ACodePoint: Cardinal): TNXXMPPPRECISProperty;
var
  lFirst: Integer;
  lLast: Integer;
  lMiddle: Integer;
begin
  lFirst := Low(cNXXMPPPRECISRanges);
  lLast := High(cNXXMPPPRECISRanges);
  while lFirst <= lLast do
  begin
    lMiddle := lFirst + ((lLast - lFirst) div 2);
    if ACodePoint < cNXXMPPPRECISRanges[lMiddle].FirstCodePoint then
      lLast := lMiddle - 1
    else if ACodePoint > cNXXMPPPRECISRanges[lMiddle].LastCodePoint then
      lFirst := lMiddle + 1
    else
      Exit(cNXXMPPPRECISRanges[lMiddle].PropertyValue);
  end;
  Result := nppUnassigned;
end;

function PreviousJoiningType(const ACodePoints: TNXXMPPCodePointArray;
  AIndex: Integer): Integer;
begin
  Dec(AIndex);
  while AIndex >= 0 do
  begin
    Result := TNXXMPPICU.PropertyValue(ACodePoints[AIndex], cUCharJoiningType);
    if Result <> cUJoiningTransparent then
      Exit;
    Dec(AIndex);
  end;
  Result := cUJoiningNonJoining;
end;

function NextJoiningType(const ACodePoints: TNXXMPPCodePointArray;
  AIndex: Integer): Integer;
begin
  Inc(AIndex);
  while AIndex <= High(ACodePoints) do
  begin
    Result := TNXXMPPICU.PropertyValue(ACodePoints[AIndex], cUCharJoiningType);
    if Result <> cUJoiningTransparent then
      Exit;
    Inc(AIndex);
  end;
  Result := cUJoiningNonJoining;
end;

function HasJapaneseScript(const ACodePoints: TNXXMPPCodePointArray): Boolean;
var
  lIndex: Integer;
  lScript: Integer;
begin
  for lIndex := 0 to High(ACodePoints) do
  begin
    lScript := TNXXMPPICU.PropertyValue(ACodePoints[lIndex], cUCharScript);
    if (lScript = cUScriptHan) or (lScript = cUScriptHiragana) or
      (lScript = cUScriptKatakana) or
      (lScript = cUScriptKatakanaOrHiragana) then
      Exit(True);
  end;
  Result := False;
end;

procedure ValidateContext(const ACodePoints: TNXXMPPCodePointArray;
  AIndex: Integer; AProperty: TNXXMPPPRECISProperty);
var
  lCodePoint: Cardinal;
  lHasArabicIndic: Boolean;
  lHasExtendedArabicIndic: Boolean;
  lIndex: Integer;
  lNextJoining: Integer;
  lPreviousJoining: Integer;
begin
  lCodePoint := ACodePoints[AIndex];
  if AProperty = nppContextJ then
  begin
    if lCodePoint = $200D then
    begin
      if (AIndex = 0) or
        (TNXXMPPICU.PropertyValue(ACodePoints[AIndex - 1],
          cUCharCanonicalCombiningClass) <> 9) then
        raise ENXXMPPError.Create(xesConfiguration, 'precis-contextj',
          'ZERO WIDTH JOINER is not in a valid PRECIS context.');
      Exit;
    end;
    if lCodePoint = $200C then
    begin
      if (AIndex > 0) and
        (TNXXMPPICU.PropertyValue(ACodePoints[AIndex - 1],
          cUCharCanonicalCombiningClass) = 9) then
        Exit;
      lPreviousJoining := PreviousJoiningType(ACodePoints, AIndex);
      lNextJoining := NextJoiningType(ACodePoints, AIndex);
      if ((lPreviousJoining = cUJoiningLeft) or
          (lPreviousJoining = cUJoiningDual)) and
        ((lNextJoining = cUJoiningRight) or
          (lNextJoining = cUJoiningDual)) then
        Exit;
      raise ENXXMPPError.Create(xesConfiguration, 'precis-contextj',
        'ZERO WIDTH NON-JOINER is not in a valid PRECIS context.');
    end;
  end;

  case lCodePoint of
    $00B7:
      if (AIndex = 0) or (AIndex = High(ACodePoints)) or
        (ACodePoints[AIndex - 1] <> Ord('l')) or
        (ACodePoints[AIndex + 1] <> Ord('l')) then
        raise ENXXMPPError.Create(xesConfiguration, 'precis-contexto',
          'MIDDLE DOT is not between lowercase Latin l characters.');
    $0375:
      if (AIndex = High(ACodePoints)) or
        (TNXXMPPICU.PropertyValue(ACodePoints[AIndex + 1], cUCharScript) <>
          cUScriptGreek) then
        raise ENXXMPPError.Create(xesConfiguration, 'precis-contexto',
          'GREEK LOWER NUMERAL SIGN is not followed by Greek text.');
    $05F3, $05F4:
      if (AIndex = 0) or
        (TNXXMPPICU.PropertyValue(ACodePoints[AIndex - 1], cUCharScript) <>
          cUScriptHebrew) then
        raise ENXXMPPError.Create(xesConfiguration, 'precis-contexto',
          'Hebrew punctuation is not preceded by Hebrew text.');
    $30FB:
      if not HasJapaneseScript(ACodePoints) then
        raise ENXXMPPError.Create(xesConfiguration, 'precis-contexto',
          'KATAKANA MIDDLE DOT requires Japanese-script text.');
    $0660..$0669, $06F0..$06F9:
      begin
        lHasArabicIndic := False;
        lHasExtendedArabicIndic := False;
        for lIndex := 0 to High(ACodePoints) do
        begin
          if (ACodePoints[lIndex] >= $0660) and
            (ACodePoints[lIndex] <= $0669) then
            lHasArabicIndic := True;
          if (ACodePoints[lIndex] >= $06F0) and
            (ACodePoints[lIndex] <= $06F9) then
            lHasExtendedArabicIndic := True;
        end;
        if lHasArabicIndic and lHasExtendedArabicIndic then
          raise ENXXMPPError.Create(xesConfiguration, 'precis-contexto',
            'Arabic-Indic digit sets must not be mixed.');
      end;
  end;
end;

procedure ValidateBidi(const ACodePoints: TNXXMPPCodePointArray);
var
  lDirection: Integer;
  lHasAN: Boolean;
  lHasEN: Boolean;
  lHasRTL: Boolean;
  lIndex: Integer;
  lLastDirection: Integer;
begin
  lHasRTL := False;
  for lIndex := 0 to High(ACodePoints) do
  begin
    lDirection := TNXXMPPICU.CharacterDirection(ACodePoints[lIndex]);
    if (lDirection = cUBidiR) or (lDirection = cUBidiAL) then
      lHasRTL := True;
  end;
  if not lHasRTL then
    Exit;
  if Length(ACodePoints) = 0 then
    Exit;
  lDirection := TNXXMPPICU.CharacterDirection(ACodePoints[0]);
  if (lDirection <> cUBidiR) and (lDirection <> cUBidiAL) then
    raise ENXXMPPError.Create(xesConfiguration, 'precis-bidi',
      'Right-to-left text must start with an R or AL character.');
  lHasAN := False;
  lHasEN := False;
  lLastDirection := lDirection;
  for lIndex := 0 to High(ACodePoints) do
  begin
    lDirection := TNXXMPPICU.CharacterDirection(ACodePoints[lIndex]);
    if not (lDirection in [cUBidiR, cUBidiAL, cUBidiAN, cUBidiEN,
      cUBidiES, cUBidiCS, cUBidiET, cUBidiON, cUBidiBN, cUBidiNSM]) then
      raise ENXXMPPError.Create(xesConfiguration, 'precis-bidi',
        'Right-to-left text contains a prohibited direction class.');
    if lDirection = cUBidiAN then
      lHasAN := True;
    if lDirection = cUBidiEN then
      lHasEN := True;
    if lDirection <> cUBidiNSM then
      lLastDirection := lDirection;
  end;
  if not (lLastDirection in [cUBidiR, cUBidiAL, cUBidiEN, cUBidiAN]) then
    raise ENXXMPPError.Create(xesConfiguration, 'precis-bidi',
      'Right-to-left text has an invalid ending direction class.');
  if lHasAN and lHasEN then
    raise ENXXMPPError.Create(xesConfiguration, 'precis-bidi',
      'European and Arabic numbers must not be mixed in right-to-left text.');
end;

procedure ValidateClass(const AValue: UTF8String;
  ABaseClass: TNXXMPPPRECISBaseClass);
var
  lCodePoints: TNXXMPPCodePointArray;
  lIndex: Integer;
  lProperty: TNXXMPPPRECISProperty;
begin
  lCodePoints := DecodeCodePoints(AValue);
  for lIndex := 0 to High(lCodePoints) do
  begin
    lProperty := PropertyFor(lCodePoints[lIndex]);
    if (lProperty = nppDisallowed) or (lProperty = nppUnassigned) or
      ((lProperty = nppIdentifierDisallowedFreeformValid) and
       (ABaseClass = pbcIdentifier)) then
      raise ENXXMPPError.Create(xesConfiguration, 'precis-disallowed',
        Format('U+%.4X is not permitted by the selected PRECIS class.',
          [lCodePoints[lIndex]]));
    if lProperty in [nppContextJ, nppContextO] then
      ValidateContext(lCodePoints, lIndex, lProperty);
  end;
  if ABaseClass = pbcIdentifier then
    ValidateBidi(lCodePoints);
end;

function MapFreeformSpaces(const AValue: UTF8String): UTF8String;
var
  lCodePoints: TNXXMPPCodePointArray;
  lIndex: Integer;
begin
  lCodePoints := DecodeCodePoints(AValue);
  for lIndex := 0 to High(lCodePoints) do
    if (lCodePoints[lIndex] <> $20) and
      (TNXXMPPICU.PropertyValue(lCodePoints[lIndex], cUCharGeneralCategory) =
        cUSpaceSeparator) then
      lCodePoints[lIndex] := $20;
  Result := EncodeCodePoints(lCodePoints);
end;

class function TNXXMPPPRECIS.EnforceUsernameCaseMapped(
  const AValue: UTF8String): UTF8String;
begin
  Result := TNXXMPPICU.WidthMap(AValue);
  Result := TNXXMPPICU.Lowercase(Result);
  Result := TNXXMPPICU.NFCNormalize(Result);
  if Result = '' then
    raise ENXXMPPError.Create(xesConfiguration, 'empty-username',
      'A PRECIS username must not be empty.');
  ValidateClass(Result, pbcIdentifier);
end;

class function TNXXMPPPRECIS.EnforceOpaqueString(
  const AValue: UTF8String): UTF8String;
begin
  Result := MapFreeformSpaces(AValue);
  Result := TNXXMPPICU.NFCNormalize(Result);
  if Result = '' then
    raise ENXXMPPError.Create(xesConfiguration, 'empty-opaque-string',
      'A PRECIS opaque string must not be empty.');
  ValidateClass(Result, pbcFreeform);
end;

end.
