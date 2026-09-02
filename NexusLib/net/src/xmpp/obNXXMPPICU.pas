unit obNXXMPPICU;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Dynlibs, obNXXMPPError, tpNXXMPPTypes;

type
  TNXXMPPICU = class
  private
    class var FLibraryHandle: TLibHandle;
    class var FLoaded: Boolean;
    class procedure Load; static;
    class function NormalizeUnicode(const AValue: UnicodeString): UnicodeString; static;
    class function LowercaseUnicode(const AValue: UnicodeString): UnicodeString; static;
  public
    class procedure RequireAvailable; static;
    class function NFCNormalize(const AValue: UTF8String): UTF8String; static;
    class function Lowercase(const AValue: UTF8String): UTF8String; static;
    class function WidthMap(const AValue: UTF8String): UTF8String; static;
    class function IDNAToASCII(const AValue: UTF8String): UTF8String; static;
    class function PropertyValue(ACodePoint: Cardinal; AProperty: Integer): Integer; static;
    class function CharacterDirection(ACodePoint: Cardinal): Integer; static;
  end;

implementation

const
  cUZeroError = 0;
  cUBufferOverflowError = 15;
  cUCharDecompositionType = $1003;
  cUDecompositionNarrow = 10;
  cUDecompositionWide = 17;
  cUIDNAOptions = $02 or $04 or $08 or $10 or $20 or $40;

type
  PUErrorCode = ^Integer;
  PUNormalizer2 = Pointer;
  PUIDNA = Pointer;

  TUIDNAInfo = record
    Size: SmallInt;
    IsTransitionalDifferent: Byte;
    ReservedB3: Byte;
    Errors: Cardinal;
    ReservedI2: LongInt;
    ReservedI3: LongInt;
  end;

  TUErrorName = function(AErrorCode: Integer): PAnsiChar; cdecl;
  TUGetIntPropertyValue = function(ACodePoint: LongInt;
    AProperty: Integer): Integer; cdecl;
  TUCharDirection = function(ACodePoint: LongInt): Integer; cdecl;
  TUStrToLower = function(ADestination: PWideChar; ADestinationCapacity: LongInt;
    ASource: PWideChar; ASourceLength: LongInt; ALocale: PAnsiChar;
    AErrorCode: PUErrorCode): LongInt; cdecl;
  TUNormGetInstance = function(AErrorCode: PUErrorCode): PUNormalizer2; cdecl;
  TUNormNormalize = function(ANormalizer: PUNormalizer2; ASource: PWideChar;
    ASourceLength: LongInt; ADestination: PWideChar; ADestinationCapacity: LongInt;
    AErrorCode: PUErrorCode): LongInt; cdecl;
  TUNormRawDecomposition = function(ANormalizer: PUNormalizer2;
    ACodePoint: LongInt; ADestination: PWideChar; ADestinationCapacity: LongInt;
    AErrorCode: PUErrorCode): LongInt; cdecl;
  TUIDNAOpen = function(AOptions: Cardinal; AErrorCode: PUErrorCode): PUIDNA; cdecl;
  TUIDNAClose = procedure(AIDNA: PUIDNA); cdecl;
  TUIDNAToASCIIUTF8 = function(AIDNA: PUIDNA; ASource: PAnsiChar;
    ASourceLength: LongInt; ADestination: PAnsiChar; ADestinationCapacity: LongInt;
    AInfo: Pointer; AErrorCode: PUErrorCode): LongInt; cdecl;

var
  lUErrorName: TUErrorName;
  lUGetIntPropertyValue: TUGetIntPropertyValue;
  lUCharDirection: TUCharDirection;
  lUStrToLower: TUStrToLower;
  lUNormGetNFCInstance: TUNormGetInstance;
  lUNormGetNFKCInstance: TUNormGetInstance;
  lUNormNormalize: TUNormNormalize;
  lUNormRawDecomposition: TUNormRawDecomposition;
  lUIDNAOpen: TUIDNAOpen;
  lUIDNAClose: TUIDNAClose;
  lUIDNAToASCIIUTF8: TUIDNAToASCIIUTF8;

procedure RequireSymbol(var ADestination; const AName: AnsiString);
var
  lAddress: Pointer;
begin
  lAddress := GetProcedureAddress(TNXXMPPICU.FLibraryHandle, AName);
  if not Assigned(lAddress) then
    raise ENXXMPPError.Create(xesConfiguration, 'icu-symbol-missing',
      'Required ICU C API symbol is unavailable: ' + string(AName));
  Pointer(ADestination) := lAddress;
end;

function ICUErrorName(AErrorCode: Integer): string;
begin
  if Assigned(lUErrorName) then
    Result := string(lUErrorName(AErrorCode))
  else
    Result := IntToStr(AErrorCode);
end;

procedure CheckICU(AErrorCode: Integer; const AOperation: string);
begin
  if (AErrorCode > cUZeroError) and (AErrorCode <> cUBufferOverflowError) then
    raise ENXXMPPError.Create(xesConfiguration, 'icu-failure',
      AOperation + ' failed: ' + ICUErrorName(AErrorCode));
end;

class procedure TNXXMPPICU.Load;
begin
  if FLoaded then
    Exit;
  FLoaded := True;
  {$IFDEF WINDOWS}
  FLibraryHandle := LoadLibrary('icu.dll');
  {$ELSE}
  FLibraryHandle := LoadLibrary('libicuuc.so');
  {$ENDIF}
  if FLibraryHandle = NilHandle then
    raise ENXXMPPError.Create(xesConfiguration, 'icu-unavailable',
      'ICU C API runtime is unavailable.');
  RequireSymbol(lUErrorName, 'u_errorName');
  RequireSymbol(lUGetIntPropertyValue, 'u_getIntPropertyValue');
  RequireSymbol(lUCharDirection, 'u_charDirection');
  RequireSymbol(lUStrToLower, 'u_strToLower');
  RequireSymbol(lUNormGetNFCInstance, 'unorm2_getNFCInstance');
  RequireSymbol(lUNormGetNFKCInstance, 'unorm2_getNFKCInstance');
  RequireSymbol(lUNormNormalize, 'unorm2_normalize');
  RequireSymbol(lUNormRawDecomposition, 'unorm2_getRawDecomposition');
  RequireSymbol(lUIDNAOpen, 'uidna_openUTS46');
  RequireSymbol(lUIDNAClose, 'uidna_close');
  RequireSymbol(lUIDNAToASCIIUTF8, 'uidna_nameToASCII_UTF8');
end;

class procedure TNXXMPPICU.RequireAvailable;
begin
  Load;
end;

class function TNXXMPPICU.NormalizeUnicode(
  const AValue: UnicodeString): UnicodeString;
var
  lError: Integer;
  lLength: LongInt;
  lNormalizer: PUNormalizer2;
begin
  Load;
  lError := cUZeroError;
  lNormalizer := lUNormGetNFCInstance(@lError);
  CheckICU(lError, 'ICU NFC initialization');
  lLength := lUNormNormalize(lNormalizer, PWideChar(AValue), Length(AValue),
    nil, 0, @lError);
  CheckICU(lError, 'ICU NFC sizing');
  lError := cUZeroError;
  SetLength(Result, lLength);
  if lLength > 0 then
    lUNormNormalize(lNormalizer, PWideChar(AValue), Length(AValue),
      PWideChar(Result), lLength, @lError);
  CheckICU(lError, 'ICU NFC normalization');
end;

class function TNXXMPPICU.LowercaseUnicode(
  const AValue: UnicodeString): UnicodeString;
var
  lError: Integer;
  lLength: LongInt;
begin
  Load;
  lError := cUZeroError;
  lLength := lUStrToLower(nil, 0, PWideChar(AValue), Length(AValue), nil, @lError);
  CheckICU(lError, 'ICU lowercase sizing');
  lError := cUZeroError;
  SetLength(Result, lLength);
  if lLength > 0 then
    lUStrToLower(PWideChar(Result), lLength, PWideChar(AValue), Length(AValue),
      nil, @lError);
  CheckICU(lError, 'ICU lowercase mapping');
end;

class function TNXXMPPICU.NFCNormalize(const AValue: UTF8String): UTF8String;
begin
  Result := UTF8Encode(NormalizeUnicode(UTF8Decode(AValue)));
end;

class function TNXXMPPICU.Lowercase(const AValue: UTF8String): UTF8String;
begin
  Result := UTF8Encode(LowercaseUnicode(UTF8Decode(AValue)));
end;

class function TNXXMPPICU.WidthMap(const AValue: UTF8String): UTF8String;
var
  lCodePoint: Cardinal;
  lDecomposition: array[0..15] of WideChar;
  lDecompositionLength: LongInt;
  lError: Integer;
  lIndex: Integer;
  lMapped: UnicodeString;
  lNormalizer: PUNormalizer2;
  lSource: UnicodeString;
  lValue: Integer;
begin
  Load;
  lSource := UTF8Decode(AValue);
  Result := '';
  lError := cUZeroError;
  lNormalizer := lUNormGetNFKCInstance(@lError);
  CheckICU(lError, 'ICU width mapping initialization');
  lIndex := 1;
  while lIndex <= Length(lSource) do
  begin
    lCodePoint := Ord(lSource[lIndex]);
    Inc(lIndex);
    if (lCodePoint >= $D800) and (lCodePoint <= $DBFF) and
      (lIndex <= Length(lSource)) then
    begin
      lCodePoint := $10000 + ((lCodePoint - $D800) shl 10) +
        (Ord(lSource[lIndex]) - $DC00);
      Inc(lIndex);
    end;
    lValue := lUGetIntPropertyValue(lCodePoint, cUCharDecompositionType);
    if (lValue = cUDecompositionNarrow) or (lValue = cUDecompositionWide) then
    begin
      lError := cUZeroError;
      lDecompositionLength := lUNormRawDecomposition(lNormalizer, lCodePoint,
        @lDecomposition[0], Length(lDecomposition), @lError);
      CheckICU(lError, 'ICU width decomposition');
      if lDecompositionLength <= 0 then
        raise ENXXMPPError.Create(xesConfiguration, 'icu-width-mapping',
          'ICU did not provide the required width decomposition.');
      SetString(lMapped, @lDecomposition[0], lDecompositionLength);
      Result := Result + UTF8Encode(lMapped);
    end
    else
    begin
      if lCodePoint <= $FFFF then
        Result := Result + UTF8Encode(UnicodeString(WideChar(lCodePoint)))
      else
      begin
        lCodePoint := lCodePoint - $10000;
        lMapped := UnicodeString(WideChar($D800 + (lCodePoint shr 10))) +
          UnicodeString(WideChar($DC00 + (lCodePoint and $3FF)));
        Result := Result + UTF8Encode(lMapped);
      end;
    end;
  end;
end;

class function TNXXMPPICU.IDNAToASCII(const AValue: UTF8String): UTF8String;
var
  lError: Integer;
  lIDNA: PUIDNA;
  lInfo: TUIDNAInfo;
  lLength: LongInt;
  lSource: UTF8String;
begin
  Load;
  lError := cUZeroError;
  lIDNA := lUIDNAOpen(cUIDNAOptions, @lError);
  CheckICU(lError, 'ICU IDNA initialization');
  if not Assigned(lIDNA) then
    raise ENXXMPPError.Create(xesConfiguration, 'icu-idna',
      'ICU did not create an IDNA processor.');
  try
    FillChar(lInfo, SizeOf(lInfo), 0);
    lInfo.Size := SizeOf(lInfo);
    lSource := UTF8String(AValue);
    lError := cUZeroError;
    lLength := lUIDNAToASCIIUTF8(lIDNA, PAnsiChar(lSource), Length(lSource),
      nil, 0, @lInfo, @lError);
    CheckICU(lError, 'ICU IDNA sizing');
    lError := cUZeroError;
    SetLength(Result, lLength);
    FillChar(lInfo, SizeOf(lInfo), 0);
    lInfo.Size := SizeOf(lInfo);
    if lLength > 0 then
      lUIDNAToASCIIUTF8(lIDNA, PAnsiChar(lSource), Length(lSource),
        PAnsiChar(Result), lLength, @lInfo, @lError);
    CheckICU(lError, 'ICU IDNA conversion');
    if lInfo.Errors <> 0 then
      raise ENXXMPPError.Create(xesConfiguration, 'invalid-domainpart',
        'The JID domainpart is not valid under IDNA2008.');
  finally
    lUIDNAClose(lIDNA);
  end;
end;

class function TNXXMPPICU.PropertyValue(ACodePoint: Cardinal;
  AProperty: Integer): Integer;
begin
  Load;
  Result := lUGetIntPropertyValue(ACodePoint, AProperty);
end;

class function TNXXMPPICU.CharacterDirection(ACodePoint: Cardinal): Integer;
begin
  Load;
  Result := lUCharDirection(ACodePoint);
end;

finalization
  if TNXXMPPICU.FLibraryHandle <> NilHandle then
    UnloadLibrary(TNXXMPPICU.FLibraryHandle);

end.
