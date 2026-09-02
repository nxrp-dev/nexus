program NexusXMPPConsole;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, Crt,
  obNXXMPPClient, obNXXMPPDisco, obNXXMPPRoster, obNXXMPPStanza,
  tpNXXMPPTypes;

type
  TConsoleEvents = class
  public
    procedure Error(ASender: TObject; AStage: TNXXMPPErrorStage;
      const ACondition, AMessage: UTF8String);
    procedure Stanza(ASender: TObject; AStanza: TNXXMPPStanza);
    procedure State(ASender: TObject; AState: TNXXMPPConnectionState);
  end;

procedure TConsoleEvents.Error(ASender: TObject; AStage: TNXXMPPErrorStage;
  const ACondition, AMessage: UTF8String);
begin
  WriteLn('Error [', ACondition, ']: ', AMessage);
end;

procedure TConsoleEvents.Stanza(ASender: TObject; AStanza: TNXXMPPStanza);
begin
  WriteLn('Stanza: ', AStanza.RawXML);
end;

procedure TConsoleEvents.State(ASender: TObject;
  AState: TNXXMPPConnectionState);
begin
  WriteLn('State: ', NXXMPPConnectionStateName(AState));
end;

var
  lClient: TNXXMPPClient;
  lDisco: TNXXMPPDiscoModule;
  lEvents: TConsoleEvents;
  lKey: Char;
begin
  if (GetEnvironmentVariable('NEXUS_XMPP_JID') = '') or
    (GetEnvironmentVariable('NEXUS_XMPP_PASSWORD') = '') or
    (GetEnvironmentVariable('NEXUS_XMPP_CA_FILE') = '') then
  begin
    WriteLn('Set NEXUS_XMPP_JID, NEXUS_XMPP_PASSWORD, and ',
      'NEXUS_XMPP_CA_FILE.');
    Halt(2);
  end;
  lClient := TNXXMPPClient.Create;
  lEvents := TConsoleEvents.Create;
  try
    lClient.Config.JID := UTF8String(GetEnvironmentVariable('NEXUS_XMPP_JID'));
    lClient.Config.Password := UTF8String(
      GetEnvironmentVariable('NEXUS_XMPP_PASSWORD'));
    lClient.Config.CAFile := GetEnvironmentVariable('NEXUS_XMPP_CA_FILE');
    lClient.Config.Resource := 'NexusXMPP';
    if GetEnvironmentVariable('NEXUS_XMPP_HOST') <> '' then
    begin
      lClient.Config.EndpointHost := GetEnvironmentVariable('NEXUS_XMPP_HOST');
      lClient.Config.EndpointPort := StrToIntDef(
        GetEnvironmentVariable('NEXUS_XMPP_PORT'), 5222);
      lClient.Config.DirectTLS := SameText(
        GetEnvironmentVariable('NEXUS_XMPP_DIRECT_TLS'), 'true');
    end;
    lDisco := TNXXMPPDiscoModule.Create('client', 'pc', 'NexusXMPP');
    lDisco.AddFeature('http://jabber.org/protocol/disco#info');
    lDisco.AddFeature('urn:xmpp:sm:3');
    lClient.AddModule(lDisco);
    lClient.AddModule(TNXXMPPRosterModule.Create);
    lClient.OnError := @lEvents.Error;
    lClient.OnStanza := @lEvents.Stanza;
    lClient.OnState := @lEvents.State;
    lClient.Connect;
    WriteLn('Press P to send presence or Q to disconnect.');
    lKey := #0;
    repeat
      lClient.PumpEvents;
      if KeyPressed then
      begin
        lKey := UpCase(ReadKey);
        if lKey = 'P' then
          lClient.SendPresence;
      end
      else
        Sleep(20);
    until lKey = 'Q';
    lClient.Disconnect;
    lClient.PumpEvents;
  finally
    lEvents.Free;
    lClient.Free;
  end;
end.
