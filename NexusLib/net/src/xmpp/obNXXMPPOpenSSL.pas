unit obNXXMPPOpenSSL;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Dynlibs, obNXXMPPError, tpNXXMPPTypes;

type
  TNXXMPPOpenSSL = class
  private
    class var FLibraryHandle: TLibHandle;
    class var FLoaded: Boolean;
    class procedure Load; static;
  public
    class procedure RequireAvailable; static;
    class function SHA256(const AValue: RawByteString): RawByteString; static;
    class function HMACSHA256(const AKey,
      AValue: RawByteString): RawByteString; static;
    class function PBKDF2SHA256(const APassword, ASalt: RawByteString;
      AIterations, ALength: Integer): RawByteString; static;
    class function RandomBytes(ACount: Integer): RawByteString; static;
    class function ConstantTimeEquals(const ALeft,
      ARight: RawByteString): Boolean; static;
  end;

implementation

type
  PEVPMD = Pointer;
  TEvPSHA256 = function: PEVPMD; cdecl;
  TEvPDigest = function(AData: Pointer; ACount: NativeUInt;
    ADigest: PByte; ADigestLength: PCardinal; AType: PEVPMD;
    AImplementation: Pointer): Integer; cdecl;
  THMAC = function(AType: PEVPMD; AKey: Pointer; AKeyLength: Integer;
    AData: PByte; ADataLength: NativeUInt; ADigest: PByte;
    ADigestLength: PCardinal): PByte; cdecl;
  TPBKDF2 = function(APassword: PAnsiChar; APasswordLength: Integer;
    ASalt: PByte; ASaltLength, AIterations: Integer; AType: PEVPMD;
    AKeyLength: Integer; AKey: PByte): Integer; cdecl;
  TRandomBytes = function(ABuffer: PByte; ACount: Integer): Integer; cdecl;
  TMemoryCompare = function(ALeft, ARight: Pointer;
    ACount: NativeUInt): Integer; cdecl;

var
  lEVPSHA256: TEvPSHA256;
  lEVPDigest: TEvPDigest;
  lHMAC: THMAC;
  lPBKDF2: TPBKDF2;
  lRandomBytes: TRandomBytes;
  lMemoryCompare: TMemoryCompare;

procedure RequireSymbol(var ADestination; const AName: AnsiString);
var
  lAddress: Pointer;
begin
  lAddress := GetProcedureAddress(TNXXMPPOpenSSL.FLibraryHandle, AName);
  if not Assigned(lAddress) then
    raise ENXXMPPError.Create(xesConfiguration, 'openssl-symbol-missing',
      'Required OpenSSL 3 symbol is unavailable: ' + string(AName));
  Pointer(ADestination) := lAddress;
end;

class procedure TNXXMPPOpenSSL.Load;
begin
  if FLoaded then
    Exit;
  FLoaded := True;
  {$IFDEF WINDOWS}
  FLibraryHandle := LoadLibrary('libcrypto-3-x64.dll');
  {$ELSE}
  FLibraryHandle := LoadLibrary('libcrypto.so.3');
  {$ENDIF}
  if FLibraryHandle = NilHandle then
    raise ENXXMPPError.Create(xesConfiguration, 'openssl-unavailable',
      'The OpenSSL 3 cryptography runtime is unavailable.');
  RequireSymbol(lEVPSHA256, 'EVP_sha256');
  RequireSymbol(lEVPDigest, 'EVP_Digest');
  RequireSymbol(lHMAC, 'HMAC');
  RequireSymbol(lPBKDF2, 'PKCS5_PBKDF2_HMAC');
  RequireSymbol(lRandomBytes, 'RAND_bytes');
  RequireSymbol(lMemoryCompare, 'CRYPTO_memcmp');
end;

class procedure TNXXMPPOpenSSL.RequireAvailable;
begin
  Load;
end;

class function TNXXMPPOpenSSL.SHA256(
  const AValue: RawByteString): RawByteString;
var
  lLength: Cardinal;
begin
  Load;
  SetLength(Result, 32);
  lLength := 0;
  if lEVPDigest(Pointer(AValue), Length(AValue), @Result[1], @lLength,
    lEVPSHA256(), nil) <> 1 then
    raise ENXXMPPError.Create(xesAuthentication, 'sha256-failure',
      'OpenSSL failed to calculate SHA-256.');
  SetLength(Result, lLength);
end;

class function TNXXMPPOpenSSL.HMACSHA256(const AKey,
  AValue: RawByteString): RawByteString;
var
  lLength: Cardinal;
begin
  Load;
  SetLength(Result, 32);
  lLength := 0;
  if not Assigned(lHMAC(lEVPSHA256(), Pointer(AKey), Length(AKey),
    PByte(Pointer(AValue)), Length(AValue), @Result[1], @lLength)) then
    raise ENXXMPPError.Create(xesAuthentication, 'hmac-failure',
      'OpenSSL failed to calculate HMAC-SHA-256.');
  SetLength(Result, lLength);
end;

class function TNXXMPPOpenSSL.PBKDF2SHA256(const APassword,
  ASalt: RawByteString; AIterations, ALength: Integer): RawByteString;
begin
  Load;
  if (AIterations < 1) or (ALength < 1) then
    raise ENXXMPPError.Create(xesAuthentication, 'invalid-pbkdf2-parameters',
      'PBKDF2 requires positive iteration and output lengths.');
  SetLength(Result, ALength);
  if lPBKDF2(PAnsiChar(APassword), Length(APassword), PByte(Pointer(ASalt)),
    Length(ASalt), AIterations, lEVPSHA256(), ALength, @Result[1]) <> 1 then
    raise ENXXMPPError.Create(xesAuthentication, 'pbkdf2-failure',
      'OpenSSL failed to calculate PBKDF2-HMAC-SHA-256.');
end;

class function TNXXMPPOpenSSL.RandomBytes(ACount: Integer): RawByteString;
begin
  Load;
  if ACount < 1 then
    raise ENXXMPPError.Create(xesAuthentication, 'invalid-random-length',
      'A positive random-byte length is required.');
  SetLength(Result, ACount);
  if lRandomBytes(@Result[1], ACount) <> 1 then
    raise ENXXMPPError.Create(xesAuthentication, 'random-failure',
      'OpenSSL failed to obtain cryptographically secure random bytes.');
end;

class function TNXXMPPOpenSSL.ConstantTimeEquals(const ALeft,
  ARight: RawByteString): Boolean;
begin
  Load;
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  if Length(ALeft) = 0 then
    Exit(True);
  Result := lMemoryCompare(Pointer(ALeft), Pointer(ARight), Length(ALeft)) = 0;
end;

finalization
  if TNXXMPPOpenSSL.FLibraryHandle <> NilHandle then
    UnloadLibrary(TNXXMPPOpenSSL.FLibraryHandle);

end.
