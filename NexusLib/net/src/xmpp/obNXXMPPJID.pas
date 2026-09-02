unit obNXXMPPJID;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPICU, obNXXMPPPRECIS, obNXXMPPError,
  tpNXXMPPTypes;

type
  TNXXMPPJID = class
  private
    FDomainPart: UTF8String;
    FLocalPart: UTF8String;
    FResourcePart: UTF8String;
    FHasLocalPart: Boolean;
    FHasResourcePart: Boolean;
    procedure Parse(const AValue: UTF8String);
  public
    constructor Create(const AValue: UTF8String);
    function Bare: UTF8String;
    function Equals(AOther: TNXXMPPJID): Boolean; reintroduce;
    function ToString: UTF8String; reintroduce;
    property DomainPart: UTF8String read FDomainPart;
    property HasLocalPart: Boolean read FHasLocalPart;
    property HasResourcePart: Boolean read FHasResourcePart;
    property LocalPart: UTF8String read FLocalPart;
    property ResourcePart: UTF8String read FResourcePart;
  end;

implementation

const
  cMaximumPartBytes = 1023;

procedure CheckPartLength(const AName: string; const AValue: UTF8String);
begin
  if Length(UTF8String(AValue)) > cMaximumPartBytes then
    raise ENXXMPPError.Create(xesConfiguration, 'jid-part-too-long',
      'The JID ' + AName + ' exceeds 1023 UTF-8 bytes.');
end;

function IsIPLiteral(const AValue: UTF8String): Boolean;
var
  lIndex: Integer;
begin
  Result := (Length(AValue) >= 4) and (AValue[1] = '[') and
    (AValue[Length(AValue)] = ']');
  if not Result then
    Exit;
  for lIndex := 2 to Length(AValue) - 1 do
    if not (AValue[lIndex] in ['0'..'9', 'a'..'f', 'A'..'F', ':', '.']) then
      Exit(False);
end;

procedure ValidateLocalPart(const AValue: UTF8String);
const
  cProhibited = ['"', '&', '''', '/', ':', '<', '>', '@'];
var
  lIndex: Integer;
begin
  for lIndex := 1 to Length(AValue) do
    if AValue[lIndex] in cProhibited then
      raise ENXXMPPError.Create(xesConfiguration, 'invalid-localpart',
        'The JID localpart contains an XMPP-prohibited character.');
end;

constructor TNXXMPPJID.Create(const AValue: UTF8String);
begin
  inherited Create;
  Parse(AValue);
end;

procedure TNXXMPPJID.Parse(const AValue: UTF8String);
var
  lAtPosition: Integer;
  lDomainSource: UTF8String;
  lPreResource: UTF8String;
  lSlashPosition: Integer;
begin
  if AValue = '' then
    raise ENXXMPPError.Create(xesConfiguration, 'empty-jid',
      'A JID must not be empty.');
  lSlashPosition := Pos('/', AValue);
  if lSlashPosition > 0 then
  begin
    FHasResourcePart := True;
    lPreResource := Copy(AValue, 1, lSlashPosition - 1);
    FResourcePart := Copy(AValue, lSlashPosition + 1, MaxInt);
    FResourcePart := TNXXMPPPRECIS.EnforceOpaqueString(FResourcePart);
    CheckPartLength('resourcepart', FResourcePart);
  end
  else
    lPreResource := AValue;

  lAtPosition := Pos('@', lPreResource);
  if lAtPosition > 0 then
  begin
    if Pos('@', Copy(lPreResource, lAtPosition + 1, MaxInt)) > 0 then
      raise ENXXMPPError.Create(xesConfiguration, 'invalid-jid',
        'A JID contains more than one localpart separator.');
    FHasLocalPart := True;
    FLocalPart := Copy(lPreResource, 1, lAtPosition - 1);
    lDomainSource := Copy(lPreResource, lAtPosition + 1, MaxInt);
    FLocalPart := TNXXMPPPRECIS.EnforceUsernameCaseMapped(FLocalPart);
    ValidateLocalPart(FLocalPart);
    CheckPartLength('localpart', FLocalPart);
  end
  else
    lDomainSource := lPreResource;

  if lDomainSource = '' then
    raise ENXXMPPError.Create(xesConfiguration, 'empty-domainpart',
      'A JID domainpart must not be empty.');
  if IsIPLiteral(lDomainSource) then
    FDomainPart := LowerCase(lDomainSource)
  else
    FDomainPart := LowerCase(TNXXMPPICU.IDNAToASCII(lDomainSource));
  CheckPartLength('domainpart', FDomainPart);
end;

function TNXXMPPJID.Bare: UTF8String;
begin
  if FHasLocalPart then
    Result := FLocalPart + '@' + FDomainPart
  else
    Result := FDomainPart;
end;

function TNXXMPPJID.Equals(AOther: TNXXMPPJID): Boolean;
begin
  Result := Assigned(AOther) and (ToString = AOther.ToString);
end;

function TNXXMPPJID.ToString: UTF8String;
begin
  Result := Bare;
  if FHasResourcePart then
    Result := Result + '/' + FResourcePart;
end;

end.
