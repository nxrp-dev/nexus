unit obNXXMPPConfig;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPError, obNXXMPPJID, obNXXMPPPRECIS,
  tpNXXMPPTypes;

type
  TNXXMPPClientConfig = class
  private
    FAllowPlain: Boolean;
    FCAFile: string;
    FCommandCapacity: Integer;
    FConnectionTimeoutMS: Integer;
    FDirectTLS: Boolean;
    FEndpointHost: string;
    FEndpointPort: Word;
    FEventCapacity: Integer;
    FJID: UTF8String;
    FPassword: UTF8String;
    FPendingIQCapacity: Integer;
    FResource: UTF8String;
  public
    constructor Create;
    function Clone: TNXXMPPClientConfig;
    procedure Validate;
    property AllowPlain: Boolean read FAllowPlain write FAllowPlain;
    property CAFile: string read FCAFile write FCAFile;
    property CommandCapacity: Integer read FCommandCapacity
      write FCommandCapacity;
    property ConnectionTimeoutMS: Integer read FConnectionTimeoutMS
      write FConnectionTimeoutMS;
    property DirectTLS: Boolean read FDirectTLS write FDirectTLS;
    property EndpointHost: string read FEndpointHost write FEndpointHost;
    property EndpointPort: Word read FEndpointPort write FEndpointPort;
    property EventCapacity: Integer read FEventCapacity write FEventCapacity;
    property JID: UTF8String read FJID write FJID;
    property Password: UTF8String read FPassword write FPassword;
    property PendingIQCapacity: Integer read FPendingIQCapacity
      write FPendingIQCapacity;
    property Resource: UTF8String read FResource write FResource;
  end;

implementation

constructor TNXXMPPClientConfig.Create;
begin
  inherited Create;
  FCommandCapacity := cNXXMPPDefaultCommandCapacity;
  FEventCapacity := cNXXMPPDefaultEventCapacity;
  FPendingIQCapacity := cNXXMPPDefaultPendingIQCapacity;
  FConnectionTimeoutMS := cNXXMPPDefaultTimeoutMS;
end;

function TNXXMPPClientConfig.Clone: TNXXMPPClientConfig;
begin
  Result := TNXXMPPClientConfig.Create;
  Result.FAllowPlain := FAllowPlain;
  Result.FCAFile := FCAFile;
  Result.FCommandCapacity := FCommandCapacity;
  Result.FConnectionTimeoutMS := FConnectionTimeoutMS;
  Result.FDirectTLS := FDirectTLS;
  Result.FEndpointHost := FEndpointHost;
  Result.FEndpointPort := FEndpointPort;
  Result.FEventCapacity := FEventCapacity;
  Result.FJID := FJID;
  Result.FPassword := FPassword;
  Result.FPendingIQCapacity := FPendingIQCapacity;
  Result.FResource := FResource;
end;

procedure TNXXMPPClientConfig.Validate;
var
  lJID: TNXXMPPJID;
begin
  lJID := TNXXMPPJID.Create(FJID);
  lJID.Free;
  if FResource <> '' then
    FResource := TNXXMPPPRECIS.EnforceOpaqueString(FResource);
  if FPassword = '' then
    raise ENXXMPPError.Create(xesConfiguration, 'missing-password',
      'An XMPP account password is required.');
  if (FCAFile = '') or not FileExists(FCAFile) then
    raise ENXXMPPError.Create(xesConfiguration, 'missing-ca-file',
      'A readable OpenSSL CA bundle is required.');
  if (FEndpointHost = '') <> (FEndpointPort = 0) then
    raise ENXXMPPError.Create(xesConfiguration, 'incomplete-endpoint',
      'An endpoint override requires both host and port.');
  if (FCommandCapacity < 1) or (FEventCapacity < 1) or
    (FPendingIQCapacity < 1) or (FConnectionTimeoutMS < 1) then
    raise ENXXMPPError.Create(xesConfiguration, 'invalid-client-limit',
      'XMPP capacities and timeouts must be positive.');
end;

end.
