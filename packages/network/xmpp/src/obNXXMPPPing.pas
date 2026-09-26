unit obNXXMPPPing;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPDispatcher, obNXXMPPModule, obNXXMPPStanza,
  tpNXXMPPTypes, utNXXMPPXML;

type
  TNXXMPPPingEvent = procedure(ASender: TObject; AStanza: TNXXMPPStanza;
    const AError: UTF8String) of object;

  TNXXMPPPingModule = class(TNXXMPPModule)
  private
    FOnComplete: TNXXMPPPingEvent;
    procedure Complete(AStanza: TNXXMPPStanza; const AError: UTF8String);
    procedure Handle(AStanza: TNXXMPPStanza);
  public
    procedure AddFeatures(AFeatures: TStrings); override;
    function Ping(const AJID: UTF8String;
      ATimeoutMS: Cardinal = cNXXMPPDefaultTimeoutMS): Boolean;
    procedure RegisterHandlers(ADispatcher: TNXXMPPDispatcher); override;
    property OnComplete: TNXXMPPPingEvent read FOnComplete write FOnComplete;
  end;

implementation

procedure TNXXMPPPingModule.AddFeatures(AFeatures: TStrings);
begin
  AFeatures.Add('urn:xmpp:ping');
end;

procedure TNXXMPPPingModule.RegisterHandlers(ADispatcher: TNXXMPPDispatcher);
begin
  ADispatcher.RegisterIQResponder(xitGet, 'urn:xmpp:ping', 'ping', @Handle);
end;

procedure TNXXMPPPingModule.Handle(AStanza: TNXXMPPStanza);
var
  lXML: UTF8String;
begin
  lXML := '<iq type=''result'' id=''' + NXXMPPEscapeAttribute(AStanza.ID) +
    '''';
  if AStanza.FromJID <> '' then
    lXML := lXML + ' to=''' + NXXMPPEscapeAttribute(AStanza.FromJID) + '''';
  Send(lXML + '/>');
end;

function TNXXMPPPingModule.Ping(const AJID: UTF8String;
  ATimeoutMS: Cardinal): Boolean;
begin
  Result := AJID <> '';
  if Result then
    Result := SubmitIQ(xitGet, AJID, AJID,
      '<ping xmlns=''urn:xmpp:ping''/>', @Complete, ATimeoutMS);
end;

procedure TNXXMPPPingModule.Complete(AStanza: TNXXMPPStanza;
  const AError: UTF8String);
begin
  if Assigned(FOnComplete) then
    FOnComplete(Self, AStanza, AError);
end;

end.
