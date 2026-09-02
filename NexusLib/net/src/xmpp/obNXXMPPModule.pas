unit obNXXMPPModule;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPDispatcher, obNXXMPPError, obNXXMPPStanza,
  tpNXXMPPTypes;

type
  TNXXMPPModuleSender = procedure(const AXML: UTF8String) of object;

  TNXXMPPModule = class
  private
    FSender: TNXXMPPModuleSender;
  protected
    procedure Send(const AXML: UTF8String);
  public
    procedure PumpStanza(AStanza: TNXXMPPStanza); virtual;
    procedure RegisterHandlers(ADispatcher: TNXXMPPDispatcher); virtual; abstract;
    property Sender: TNXXMPPModuleSender read FSender write FSender;
  end;

implementation

procedure TNXXMPPModule.PumpStanza(AStanza: TNXXMPPStanza);
begin
end;

procedure TNXXMPPModule.Send(const AXML: UTF8String);
begin
  if not Assigned(FSender) then
    raise ENXXMPPError.Create(xesProtocol, 'module-not-connected',
      'The XMPP module is not connected to a stanza sender.');
  FSender(AXML);
end;

end.
