program NexusXMPPConsole;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, Crt,
  obNXXMPPClient, obNXXMPPDisco, obNXXMPPRoster, obNXXMPPStanza,
  tpNXXMPPTypes;

type
  TConsoleEvents = class
  private
    FOnlineInitialized: Boolean;
    FRoster: TNXXMPPRosterModule;
  public
    procedure Error(ASender: TObject; AStage: TNXXMPPErrorStage;
      const ACondition, AMessage: UTF8String);
    procedure RosterChanged(ASender: TObject;
      const AJID, ASubscription: UTF8String);
    procedure Stanza(ASender: TObject; AStanza: TNXXMPPStanza);
    procedure State(ASender: TObject; AState: TNXXMPPConnectionState);
    procedure UnrecoverableStanzas(ASender: TObject;
      const AReason: UTF8String; AStanzas: TStrings);
    property Roster: TNXXMPPRosterModule read FRoster write FRoster;
  end;

procedure TConsoleEvents.Error(ASender: TObject; AStage: TNXXMPPErrorStage;
  const ACondition, AMessage: UTF8String);
begin
  WriteLn('Error [', ACondition, ']: ', AMessage);
end;

procedure TConsoleEvents.RosterChanged(ASender: TObject;
  const AJID, ASubscription: UTF8String);
begin
  WriteLn('Roster: ', AJID, ' [', ASubscription, ']');
end;

procedure TConsoleEvents.Stanza(ASender: TObject; AStanza: TNXXMPPStanza);
begin
  WriteLn('Stanza: ', AStanza.RawXML);
end;

procedure TConsoleEvents.State(ASender: TObject;
  AState: TNXXMPPConnectionState);
begin
  WriteLn('State: ', NXXMPPConnectionStateName(AState));
  if (AState = xcsOnline) and Assigned(FRoster) and
    not FOnlineInitialized then
  begin
    FOnlineInitialized := True;
    TNXXMPPClient(ASender).RequestRoster(FRoster);
    TNXXMPPClient(ASender).SendPresence;
  end;
end;

procedure TConsoleEvents.UnrecoverableStanzas(ASender: TObject;
  const AReason: UTF8String; AStanzas: TStrings);
var
  lIndex: Integer;
begin
  WriteLn('Unrecoverable transmitted stanzas: ', AReason);
  for lIndex := 0 to AStanzas.Count - 1 do
    WriteLn('  ', AStanzas[lIndex]);
end;

var
  lClient: TNXXMPPClient;
  lDisco: TNXXMPPDiscoModule;
  lEvents: TConsoleEvents;
  lKey: Char;
  lRoster: TNXXMPPRosterModule;
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
    lRoster := TNXXMPPRosterModule.Create;
    lRoster.OnChanged := @lEvents.RosterChanged;
    lEvents.Roster := lRoster;
    lClient.AddModule(lRoster);
    lClient.OnError := @lEvents.Error;
    lClient.OnStanza := @lEvents.Stanza;
    lClient.OnState := @lEvents.State;
    lClient.OnUnrecoverableStanzas := @lEvents.UnrecoverableStanzas;
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
