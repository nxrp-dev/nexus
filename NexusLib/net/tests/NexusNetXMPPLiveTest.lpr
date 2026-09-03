program NexusNetXMPPLiveTest;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  Classes, SysUtils,
  obNXXMPPClient, obNXXMPPStanza, tpNXXMPPTypes;

type
  TLiveRecorder = class
  private
    FExpectedBody: UTF8String;
    FExpectedFrom: UTF8String;
  public
    Failed: Boolean;
    LastError: UTF8String;
    LastStanza: UTF8String;
    Online: Boolean;
    ReceivedExpectedMessage: Boolean;
    procedure Error(ASender: TObject; AStage: TNXXMPPErrorStage;
      const ACondition, AMessage: UTF8String);
    procedure Stanza(ASender: TObject; AStanza: TNXXMPPStanza);
    procedure State(ASender: TObject; AState: TNXXMPPConnectionState);
    property ExpectedBody: UTF8String read FExpectedBody write FExpectedBody;
    property ExpectedFrom: UTF8String read FExpectedFrom write FExpectedFrom;
  end;

procedure TLiveRecorder.Error(ASender: TObject; AStage: TNXXMPPErrorStage;
  const ACondition, AMessage: UTF8String);
begin
  LastError := ACondition + ': ' + AMessage;
end;

procedure TLiveRecorder.Stanza(ASender: TObject; AStanza: TNXXMPPStanza);
begin
  LastStanza := AStanza.RawXML;
  if (AStanza.Kind = xskMessage) and
    (Pos(string(FExpectedFrom), string(AStanza.FromJID)) = 1) and
    (AStanza.TextContent = FExpectedBody) then
    ReceivedExpectedMessage := True;
end;

procedure TLiveRecorder.State(ASender: TObject;
  AState: TNXXMPPConnectionState);
begin
  if AState = xcsOnline then
    Online := True
  else if AState = xcsFailed then
    Failed := True;
end;

procedure ConfigureClient(AClient: TNXXMPPClient; const AJID,
  APassword, AResource: UTF8String);
begin
  AClient.Config.JID := AJID;
  AClient.Config.Password := APassword;
  AClient.Config.AllowPlain := True;
  AClient.Config.CAFile := GetEnvironmentVariable('NEXUS_XMPP_CA_FILE');
  AClient.Config.EndpointHost := GetEnvironmentVariable('NEXUS_XMPP_HOST');
  AClient.Config.EndpointPort := StrToIntDef(
    GetEnvironmentVariable('NEXUS_XMPP_PORT'), 5222);
  AClient.Config.Resource := AResource;
  AClient.Config.ConnectionTimeoutMS := 5000;
  AClient.Config.ReconnectAttempts := 0;
end;

var
  lBody: UTF8String;
  lClient1: TNXXMPPClient;
  lClient2: TNXXMPPClient;
  lDeadline: QWord;
  lExitCode: Integer;
  lExpectTLSFailure: Boolean;
  lPassword1: UTF8String;
  lPassword2: UTF8String;
  lRecorder1: TLiveRecorder;
  lRecorder2: TLiveRecorder;
  lRunID: UTF8String;
  lUser1: UTF8String;
  lUser2: UTF8String;
begin
  lExitCode := 1;
  lExpectTLSFailure := GetEnvironmentVariable(
    'NEXUS_XMPP_EXPECT_TLS_FAILURE') = '1';
  lUser1 := UTF8String(GetEnvironmentVariable('NEXUS_XMPP_USER1'));
  lUser2 := UTF8String(GetEnvironmentVariable('NEXUS_XMPP_USER2'));
  lPassword1 := UTF8String(GetEnvironmentVariable('NEXUS_XMPP_PASSWORD1'));
  lPassword2 := UTF8String(GetEnvironmentVariable('NEXUS_XMPP_PASSWORD2'));
  lRunID := UTF8String(UIntToStr(GetTickCount64));
  if (lUser1 = '') or (lPassword1 = '') or
    (GetEnvironmentVariable('NEXUS_XMPP_CA_FILE') = '') or
    (GetEnvironmentVariable('NEXUS_XMPP_HOST') = '') then
  begin
    WriteLn('Missing required NEXUS_XMPP_* live-test environment.');
    Halt(2);
  end;

  lClient1 := TNXXMPPClient.Create;
  lRecorder1 := TLiveRecorder.Create;
  lClient2 := nil;
  lRecorder2 := nil;
  try
    ConfigureClient(lClient1, lUser1, lPassword1,
      'NexusXMPPLiveTest-' + lRunID + '-1');
    lClient1.OnError := @lRecorder1.Error;
    lClient1.OnState := @lRecorder1.State;
    if not lExpectTLSFailure then
    begin
      if (lUser2 = '') or (lPassword2 = '') then
      begin
        WriteLn('The positive live test requires USER2 and PASSWORD2.');
        lExitCode := 2;
      end
      else
      begin
        lClient2 := TNXXMPPClient.Create;
        lRecorder2 := TLiveRecorder.Create;
        ConfigureClient(lClient2, lUser2, lPassword2,
          'NexusXMPPLiveTest-' + lRunID + '-2');
        lClient2.OnError := @lRecorder2.Error;
        lClient2.OnStanza := @lRecorder2.Stanza;
        lClient2.OnState := @lRecorder2.State;
      end;
    end;

    if (lExitCode <> 2) then
    begin
      lClient1.Connect;
      if Assigned(lClient2) then
        lClient2.Connect;
      lDeadline := GetTickCount64 + 15000;
      repeat
        lClient1.PumpEvents;
        if Assigned(lClient2) then
          lClient2.PumpEvents;
        if lRecorder1.Failed or
          (Assigned(lRecorder2) and lRecorder2.Failed) then
          Break;
        if lRecorder1.Online and
          (not Assigned(lRecorder2) or lRecorder2.Online) then
          Break;
        Sleep(10);
      until GetTickCount64 >= lDeadline;

      if lExpectTLSFailure then
      begin
        if lRecorder1.Failed then
        begin
          WriteLn('Expected TLS rejection observed: ', lRecorder1.LastError);
          lExitCode := 0;
        end
        else
          WriteLn('Expected TLS rejection was not observed.');
      end
      else if not lRecorder1.Online or not lRecorder2.Online then
      begin
        WriteLn('Client 1 failure: ', lRecorder1.LastError);
        WriteLn('Client 2 failure: ', lRecorder2.LastError);
      end
      else
      begin
        lClient1.SendPresence;
        lClient2.SendPresence;
        lDeadline := GetTickCount64 + 1000;
        repeat
          lClient1.PumpEvents;
          lClient2.PumpEvents;
          Sleep(10);
        until GetTickCount64 >= lDeadline;
        lBody := 'NexusXMPP Openfire live test ' +
          UTF8String(UIntToStr(GetTickCount64));
        lRecorder2.ExpectedFrom := lUser1;
        lRecorder2.ExpectedBody := lBody;
        if not lClient1.SendMessage(lUser2, lBody) then
          WriteLn('Client 1 rejected the message command.')
        else
        begin
          lDeadline := GetTickCount64 + 15000;
          repeat
            lClient1.PumpEvents;
            lClient2.PumpEvents;
            if lRecorder2.ReceivedExpectedMessage or lRecorder1.Failed or
              lRecorder2.Failed then
              Break;
            Sleep(10);
          until GetTickCount64 >= lDeadline;
          if lRecorder2.ReceivedExpectedMessage then
          begin
            WriteLn('Authenticated Openfire message exchange passed.');
            lExitCode := 0;
          end
          else
          begin
            WriteLn('The expected message was not received.');
            WriteLn('Client 1 failure: ', lRecorder1.LastError);
            WriteLn('Client 2 failure: ', lRecorder2.LastError);
            WriteLn('Client 2 last stanza: ', lRecorder2.LastStanza);
          end;
        end;
      end;
    end;
  finally
    lClient2.Free;
    lClient1.Free;
    lRecorder2.Free;
    lRecorder1.Free;
  end;
  Halt(lExitCode);
end.
