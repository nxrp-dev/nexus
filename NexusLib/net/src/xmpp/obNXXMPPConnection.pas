unit obNXXMPPConnection;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Contnrs, SyncObjs, synacode,
  obNXXMPPCommand, obNXXMPPConfig, obNXXMPPDispatcher,
  obNXXMPPEndpointResolver, obNXXMPPError, obNXXMPPEvents, obNXXMPPJID,
  obNXXMPPQueue, obNXXMPPRequestManager, obNXXMPPSASL,
  obNXXMPPStanza, obNXXMPPStreamFramer, obNXXMPPTransport,
  obNXXMPPNegotiation, obNXXMPPStreamManagement,
  tpNXXMPPTypes, utNXXMPPXML;

type
  TNXXMPPConnection = class(TThread)
  private
    FCommands: TNXXMPPObjectQueue;
    FConfig: TNXXMPPClientConfig;
    FCriticalSection: TCriticalSection;
    FDisconnectRequested: Boolean;
    FDispatcher: TNXXMPPDispatcher;
    FEvents: TNXXMPPObjectQueue;
    FFrames: TStringList;
    FFramer: TNXXMPPStreamFramer;
    FJID: TNXXMPPJID;
    FRequests: TNXXMPPRequestManager;
    FState: TNXXMPPConnectionState;
    FStreamManagement: TNXXMPPStreamManagement;
    FTransport: TNXXMPPTransport;
    function ConnectEndpoint: TNXXMPPEndpoint;
    procedure EnqueueCompletionEvents(AEvents: TObjectList);
    procedure EnqueueEvent(AEvent: TNXXMPPEvent);
    procedure HandleIncoming(AStanza: TNXXMPPStanza);
    function IsDisconnectRequested: Boolean;
    procedure OnlineLoop;
    procedure PerformAuthentication(AFeatures: TNXXMPPStanza);
    procedure PerformBinding(AFeatures: TNXXMPPStanza);
    procedure PerformNegotiation(const AEndpoint: TNXXMPPEndpoint);
    procedure ProcessCommands;
    function ReadElement: TNXXMPPStanza;
    function ReadFrame: UTF8String;
    procedure ResetStream;
    procedure SendOpen;
    procedure SendStanza(const AXML: UTF8String; AReplayable: Boolean);
    procedure SendUnhandledIQError(AStanza: TNXXMPPStanza);
    procedure Transition(AState: TNXXMPPConnectionState);
  protected
    procedure Execute; override;
  public
    constructor Create(AConfig: TNXXMPPClientConfig;
      ACommands, AEvents: TNXXMPPObjectQueue;
      ADispatcher: TNXXMPPDispatcher);
    destructor Destroy; override;
    procedure RequestDisconnect;
    procedure SendModuleXML(const AXML: UTF8String);
    function State: TNXXMPPConnectionState;
  end;

implementation

constructor TNXXMPPConnection.Create(AConfig: TNXXMPPClientConfig;
  ACommands, AEvents: TNXXMPPObjectQueue; ADispatcher: TNXXMPPDispatcher);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FConfig := AConfig;
  FCommands := ACommands;
  FEvents := AEvents;
  FDispatcher := ADispatcher;
  FCriticalSection := TCriticalSection.Create;
  FFrames := TStringList.Create;
  FFramer := TNXXMPPStreamFramer.Create;
  FRequests := TNXXMPPRequestManager.Create(FConfig.PendingIQCapacity);
  FStreamManagement := TNXXMPPStreamManagement.Create(FConfig.CommandCapacity);
  FTransport := TNXXMPPTransport.Create;
  FState := xcsDisconnected;
end;

destructor TNXXMPPConnection.Destroy;
begin
  if not Finished then
  begin
    RequestDisconnect;
    WaitFor;
  end;
  FTransport.Free;
  FStreamManagement.Free;
  FRequests.Free;
  FFramer.Free;
  FFrames.Free;
  FJID.Free;
  FCriticalSection.Free;
  FConfig.Free;
  inherited Destroy;
end;

function TNXXMPPConnection.State: TNXXMPPConnectionState;
begin
  FCriticalSection.Acquire;
  try
    Result := FState;
  finally
    FCriticalSection.Release;
  end;
end;

procedure TNXXMPPConnection.Transition(AState: TNXXMPPConnectionState);
var
  lPrevious: TNXXMPPConnectionState;
begin
  FCriticalSection.Acquire;
  try
    lPrevious := FState;
    if not NXXMPPStateTransitionAllowed(lPrevious, AState) then
      raise ENXXMPPError.Create(xesProtocol, 'illegal-state-transition',
        'Illegal XMPP state transition from ' +
        NXXMPPConnectionStateName(lPrevious) + ' to ' +
        NXXMPPConnectionStateName(AState) + '.');
    FState := AState;
  finally
    FCriticalSection.Release;
  end;
  EnqueueEvent(TNXXMPPEvent.CreateState(AState));
end;

procedure TNXXMPPConnection.EnqueueEvent(AEvent: TNXXMPPEvent);
begin
  if not FEvents.Enqueue(AEvent) then
  begin
    AEvent.Free;
    FCriticalSection.Acquire;
    try
      FDisconnectRequested := True;
      FState := xcsFailed;
    finally
      FCriticalSection.Release;
    end;
    FTransport.Interrupt;
    raise ENXXMPPError.Create(xesProtocol, 'event-queue-full',
      'The application event queue is full.');
  end;
end;

procedure TNXXMPPConnection.RequestDisconnect;
begin
  FCriticalSection.Acquire;
  try
    FDisconnectRequested := True;
  finally
    FCriticalSection.Release;
  end;
  FTransport.Interrupt;
end;

procedure TNXXMPPConnection.SendModuleXML(const AXML: UTF8String);
begin
  if GetCurrentThreadID <> ThreadID then
    raise ENXXMPPError.Create(xesProtocol, 'wrong-module-thread',
      'XMPP modules may send only while handling the connection thread.');
  SendStanza(AXML, False);
end;

procedure TNXXMPPConnection.SendStanza(const AXML: UTF8String;
  AReplayable: Boolean);
begin
  FTransport.Send(RawByteString(AXML));
  FStreamManagement.OutgoingSent(AXML, AReplayable);
end;

function TNXXMPPConnection.IsDisconnectRequested: Boolean;
begin
  FCriticalSection.Acquire;
  try
    Result := FDisconnectRequested;
  finally
    FCriticalSection.Release;
  end;
end;

function TNXXMPPConnection.ConnectEndpoint: TNXXMPPEndpoint;
var
  lEndpoints: TNXXMPPEndpointArray;
  lErrorMessage: string;
  lIndex: Integer;
  lResolver: TNXXMPPEndpointResolver;
begin
  Result.Host := '';
  if FConfig.EndpointHost <> '' then
  begin
    SetLength(lEndpoints, 1);
    lEndpoints[0].Host := FConfig.EndpointHost;
    lEndpoints[0].Port := FConfig.EndpointPort;
    if FConfig.DirectTLS then
      lEndpoints[0].Security := xtsDirectTLS
    else
      lEndpoints[0].Security := xtsStartTLS;
  end
  else
  begin
    Transition(xcsResolving);
    lResolver := TNXXMPPEndpointResolver.Create;
    try
      lEndpoints := lResolver.Resolve(FJID.DomainPart);
    finally
      lResolver.Free;
    end;
    if Length(lEndpoints) = 0 then
      raise ENXXMPPError.Create(xesResolution, 'service-unavailable',
        'The XMPP service explicitly reports that it is unavailable.');
  end;
  lErrorMessage := '';
  for lIndex := 0 to High(lEndpoints) do
  begin
    if IsDisconnectRequested then
      raise ENXXMPPError.Create(xesShutdown, 'connection-cancelled',
        'The XMPP connection was cancelled.');
    try
      Transition(xcsConnecting);
      FTransport.Connect(lEndpoints[lIndex].Host, lEndpoints[lIndex].Port,
        FConfig.ConnectionTimeoutMS);
      if lEndpoints[lIndex].Security = xtsDirectTLS then
      begin
        Transition(xcsSecuring);
        FTransport.Secure(FJID.DomainPart, FConfig.CAFile);
      end;
      Exit(lEndpoints[lIndex]);
    except
      on E: Exception do
      begin
        lErrorMessage := E.Message;
        FTransport.Close;
      end;
    end;
  end;
  raise ENXXMPPError.Create(xesConnection, 'all-endpoints-failed',
    'All XMPP endpoints failed. Last failure: ' + lErrorMessage, True);
end;

procedure TNXXMPPConnection.SendOpen;
begin
  FTransport.Send('<stream:stream to=''' +
    RawByteString(NXXMPPEscapeAttribute(FJID.DomainPart)) +
    ''' version=''1.0'' xml:lang=''en'' xmlns=''jabber:client'' ' +
    'xmlns:stream=''http://etherx.jabber.org/streams''>');
end;

procedure TNXXMPPConnection.ResetStream;
begin
  FFramer.Reset;
  FFrames.Clear;
end;

function TNXXMPPConnection.ReadFrame: UTF8String;
var
  lData: RawByteString;
  lDeadline: QWord;
begin
  lDeadline := GetTickCount64 + Cardinal(FConfig.ConnectionTimeoutMS);
  while FFrames.Count = 0 do
  begin
    if IsDisconnectRequested then
      raise ENXXMPPError.Create(xesShutdown, 'connection-cancelled',
        'The XMPP connection was cancelled.');
    lData := FTransport.Receive(250);
    if lData <> '' then
      FFramer.Feed(lData, FFrames);
    if GetTickCount64 >= lDeadline then
      raise ENXXMPPError.Create(xesStream, 'stream-timeout',
        'Timed out while waiting for the next XMPP stream element.', True);
  end;
  Result := UTF8String(FFrames[0]);
  FFrames.Delete(0);
end;

function TNXXMPPConnection.ReadElement: TNXXMPPStanza;
var
  lFrame: UTF8String;
begin
  repeat
    lFrame := ReadFrame;
    if Copy(lFrame, 1, 14) = '<stream:stream' then
      Continue;
    if Copy(lFrame, 1, 15) = '</stream:stream' then
      raise ENXXMPPError.Create(xesStream, 'stream-closed',
        'The server closed the XMPP stream.');
    Result := TNXXMPPStanza.Create(lFrame,
      FFramer.StreamNamespaceAttributes);
    Exit;
  until False;
end;

procedure TNXXMPPConnection.PerformAuthentication(AFeatures: TNXXMPPStanza);
var
  lAuthentication: TNXXMPPAuthenticationMechanism;
  lChallenge: TNXXMPPStanza;
  lClientMessage: RawByteString;
  lFinal: TNXXMPPStanza;
  lPlain: RawByteString;
  lSCRAM: TNXXMPPSCRAMSHA256;
begin
  Transition(xcsAuthenticating);
  lAuthentication := TNXXMPPNegotiation.SelectAuthentication(
    AFeatures.RawXML, FConfig.AllowPlain, True);
  if lAuthentication = xamSCRAMSHA256 then
  begin
    lSCRAM := TNXXMPPSCRAMSHA256.Create;
    try
      lClientMessage := lSCRAM.Start(FJID.LocalPart);
      FTransport.Send('<auth xmlns=''urn:ietf:params:xml:ns:xmpp-sasl'' ' +
        'mechanism=''SCRAM-SHA-256''>' + EncodeBase64(lClientMessage) +
        '</auth>');
      lChallenge := ReadElement;
      try
        if (lChallenge.LocalName <> 'challenge') or
          (lChallenge.NamespaceURI <> 'urn:ietf:params:xml:ns:xmpp-sasl') then
          raise ENXXMPPError.Create(xesAuthentication,
            'unexpected-sasl-response',
            'Expected a SCRAM challenge from the server.');
        lClientMessage := lSCRAM.Continue(
          DecodeBase64(AnsiString(lChallenge.TextContent)), FConfig.Password);
      finally
        lChallenge.Free;
      end;
      FTransport.Send('<response xmlns=''urn:ietf:params:xml:ns:xmpp-sasl''>' +
        EncodeBase64(lClientMessage) + '</response>');
      lFinal := ReadElement;
      try
        if (lFinal.LocalName <> 'success') or
          (lFinal.NamespaceURI <> 'urn:ietf:params:xml:ns:xmpp-sasl') then
          raise ENXXMPPError.Create(xesAuthentication,
            'authentication-failed', 'SCRAM authentication failed.');
        lSCRAM.VerifyServerFinal(
          DecodeBase64(AnsiString(lFinal.TextContent)));
      finally
        lFinal.Free;
      end;
    finally
      lSCRAM.Free;
    end;
  end
  else if lAuthentication = xamPlain then
  begin
    lPlain := #0 + RawByteString(FJID.LocalPart) + #0 +
      RawByteString(FConfig.Password);
    FTransport.Send('<auth xmlns=''urn:ietf:params:xml:ns:xmpp-sasl'' ' +
      'mechanism=''PLAIN''>' + EncodeBase64(lPlain) + '</auth>');
    lFinal := ReadElement;
    try
      if (lFinal.LocalName <> 'success') or
        (lFinal.NamespaceURI <> 'urn:ietf:params:xml:ns:xmpp-sasl') then
        raise ENXXMPPError.Create(xesAuthentication, 'authentication-failed',
          'PLAIN authentication failed.');
    finally
      lFinal.Free;
    end;
    FillChar(Pointer(lPlain)^, Length(lPlain), 0);
  end
  else
    raise ENXXMPPError.Create(xesAuthentication, 'no-supported-mechanism',
      'The server did not offer an allowed SASL mechanism.');
end;

procedure TNXXMPPConnection.PerformBinding(AFeatures: TNXXMPPStanza);
var
  lBindXML: RawByteString;
  lResult: TNXXMPPStanza;
begin
  if not TNXXMPPNegotiation.OffersBinding(AFeatures.RawXML) then
    raise ENXXMPPError.Create(xesBinding, 'binding-unavailable',
      'The server did not offer resource binding.');
  Transition(xcsBinding);
  lBindXML := '<iq type=''set'' id=''nx-bind''><bind ' +
    'xmlns=''urn:ietf:params:xml:ns:xmpp-bind''>';
  if FConfig.Resource <> '' then
    lBindXML := lBindXML + '<resource>' +
      RawByteString(NXXMPPEscapeText(FConfig.Resource)) + '</resource>';
  lBindXML := lBindXML + '</bind></iq>';
  FTransport.Send(lBindXML);
  repeat
    lResult := ReadElement;
    if (lResult.Kind = xskIQ) and (lResult.ID = 'nx-bind') then
      Break;
    lResult.Free;
  until False;
  try
    if lResult.IQType <> xitResult then
      raise ENXXMPPError.Create(xesBinding, 'binding-failed',
        'The server rejected resource binding.');
  finally
    lResult.Free;
  end;
end;

procedure TNXXMPPConnection.PerformNegotiation(
  const AEndpoint: TNXXMPPEndpoint);
var
  lFeatures: TNXXMPPStanza;
  lProceed: TNXXMPPStanza;
begin
  SendOpen;
  lFeatures := ReadElement;
  try
    if lFeatures.LocalName <> 'features' then
      raise ENXXMPPError.Create(xesStream, 'missing-stream-features',
        'The server did not provide stream features.');
    if AEndpoint.Security = xtsStartTLS then
    begin
      if not TNXXMPPNegotiation.OffersStartTLS(lFeatures.RawXML) then
        raise ENXXMPPError.Create(xesTLS, 'starttls-unavailable',
          'The server did not offer STARTTLS.');
      FTransport.Send('<starttls xmlns=' +
        '''urn:ietf:params:xml:ns:xmpp-tls''/>');
      lProceed := ReadElement;
      try
        if (lProceed.LocalName <> 'proceed') or
          (lProceed.NamespaceURI <> 'urn:ietf:params:xml:ns:xmpp-tls') then
          raise ENXXMPPError.Create(xesTLS, 'starttls-rejected',
            'The server rejected STARTTLS.');
      finally
        lProceed.Free;
      end;
      Transition(xcsSecuring);
      FTransport.Secure(FJID.DomainPart, FConfig.CAFile);
      lFeatures.Free;
      lFeatures := nil;
      ResetStream;
      SendOpen;
      lFeatures := ReadElement;
      if lFeatures.LocalName <> 'features' then
        raise ENXXMPPError.Create(xesStream, 'missing-stream-features',
          'The secured stream did not provide features.');
    end;
    PerformAuthentication(lFeatures);
  finally
    lFeatures.Free;
  end;
  ResetStream;
  SendOpen;
  lFeatures := ReadElement;
  try
    if lFeatures.LocalName <> 'features' then
      raise ENXXMPPError.Create(xesStream, 'missing-stream-features',
        'The authenticated stream did not provide features.');
    PerformBinding(lFeatures);
    if TNXXMPPNegotiation.OffersStreamManagement(lFeatures.RawXML) then
    begin
      FTransport.Send('<enable xmlns=''urn:xmpp:sm:3'' resume=''true''/>');
      lProceed := ReadElement;
      try
        if (lProceed.LocalName = 'enabled') and
          (lProceed.NamespaceURI = 'urn:xmpp:sm:3') then
          FStreamManagement.Enable(lProceed.Attribute('id'));
      finally
        lProceed.Free;
      end;
    end;
  finally
    lFeatures.Free;
  end;
end;

procedure TNXXMPPConnection.SendUnhandledIQError(AStanza: TNXXMPPStanza);
var
  lTo: RawByteString;
begin
  lTo := '';
  if AStanza.FromJID <> '' then
    lTo := ' to=''' + RawByteString(NXXMPPEscapeAttribute(AStanza.FromJID)) +
      '''';
  FTransport.Send('<iq type=''error'' id=''' +
    RawByteString(NXXMPPEscapeAttribute(AStanza.ID)) + '''' + lTo +
    '>' + RawByteString(AStanza.ChildXML) +
    '<error type=''cancel''><service-unavailable ' +
    'xmlns=''urn:ietf:params:xml:ns:xmpp-stanzas''/></error></iq>');
end;

procedure TNXXMPPConnection.HandleIncoming(AStanza: TNXXMPPStanza);
var
  lCompletion: TNXXMPPIQCompletionEvent;
  lHandled: QWord;
begin
  if (AStanza.NamespaceURI = 'urn:xmpp:sm:3') and
    (AStanza.LocalName = 'r') then
  begin
    FTransport.Send(RawByteString(FStreamManagement.AcknowledgementXML));
    AStanza.Free;
    Exit;
  end;
  if (AStanza.NamespaceURI = 'urn:xmpp:sm:3') and
    (AStanza.LocalName = 'a') then
  begin
    if not TryStrToQWord(string(AStanza.Attribute('h')), lHandled) or
      (lHandled > High(Cardinal)) then
      raise ENXXMPPError.Create(xesProtocol, 'invalid-sm-acknowledgement',
        'The stream-management acknowledgement counter is invalid.');
    FStreamManagement.Acknowledge(Cardinal(lHandled));
    AStanza.Free;
    Exit;
  end;
  lCompletion := FRequests.Complete(AStanza);
  if Assigned(lCompletion) then
  begin
    EnqueueEvent(TNXXMPPEvent.CreateCompletion(lCompletion));
    FStreamManagement.IncomingHandled;
    Exit;
  end;
  if (AStanza.Kind = xskIQ) and (AStanza.IQType in [xitGet, xitSet]) and
    not FDispatcher.DispatchStanza(AStanza) then
    SendUnhandledIQError(AStanza)
  else if not ((AStanza.Kind = xskIQ) and
    (AStanza.IQType in [xitGet, xitSet])) then
    FDispatcher.DispatchStanza(AStanza);
  EnqueueEvent(TNXXMPPEvent.CreateStanza(AStanza));
  FStreamManagement.IncomingHandled;
end;

procedure TNXXMPPConnection.ProcessCommands;
var
  lCommand: TNXXMPPCommand;
  lID: UTF8String;
  lXML: UTF8String;
begin
  repeat
    lCommand := TNXXMPPCommand(FCommands.Dequeue);
    if not Assigned(lCommand) then
      Exit;
    try
      case lCommand.Kind of
        xckRawXML:
          SendStanza(lCommand.XML,
            (Copy(lCommand.XML, 1, 8) = '<message') or
            (Copy(lCommand.XML, 1, 9) = '<presence'));
        xckIQ:
          begin
            lID := FRequests.BeginRequest(lCommand.ExpectedFrom,
              lCommand.TimeoutMS, lCommand.Handler);
            lXML := '<iq type=''' +
              UTF8String(NXXMPPIQTypeName(lCommand.IQType)) + ''' id=''' +
              NXXMPPEscapeAttribute(lID) + '''';
            if lCommand.ToJID <> '' then
              lXML := lXML + ' to=''' +
                NXXMPPEscapeAttribute(lCommand.ToJID) + '''';
            lXML := lXML + '>' + lCommand.Payload + '</iq>';
            SendStanza(lXML, False);
          end;
        xckDisconnect:
          RequestDisconnect;
      end;
    finally
      lCommand.Free;
    end;
  until False;
end;

procedure TNXXMPPConnection.EnqueueCompletionEvents(AEvents: TObjectList);
var
  lCompletion: TNXXMPPIQCompletionEvent;
begin
  while AEvents.Count > 0 do
  begin
    lCompletion := TNXXMPPIQCompletionEvent(AEvents.Extract(AEvents[0]));
    EnqueueEvent(TNXXMPPEvent.CreateCompletion(lCompletion));
  end;
end;

procedure TNXXMPPConnection.OnlineLoop;
var
  lCompletions: TObjectList;
  lData: RawByteString;
  lFrame: UTF8String;
  lStanza: TNXXMPPStanza;
begin
  lCompletions := TObjectList.Create(True);
  try
    while not IsDisconnectRequested do
    begin
      ProcessCommands;
      lData := FTransport.Receive(100);
      if lData <> '' then
        FFramer.Feed(lData, FFrames);
      while FFrames.Count > 0 do
      begin
        lFrame := UTF8String(FFrames[0]);
        FFrames.Delete(0);
        if Copy(lFrame, 1, 15) = '</stream:stream' then
          raise ENXXMPPError.Create(xesStream, 'stream-closed',
            'The server closed the XMPP stream.', True);
        if Copy(lFrame, 1, 14) = '<stream:stream' then
          Continue;
        lStanza := TNXXMPPStanza.Create(lFrame,
          FFramer.StreamNamespaceAttributes);
        try
          HandleIncoming(lStanza);
          lStanza := nil;
        finally
          lStanza.Free;
        end;
      end;
      FRequests.CollectTimeouts(GetTickCount64, lCompletions);
      EnqueueCompletionEvents(lCompletions);
    end;
  finally
    lCompletions.Free;
  end;
end;

procedure TNXXMPPConnection.Execute;
var
  lCompletions: TObjectList;
  lEndpoint: TNXXMPPEndpoint;
begin
  lCompletions := TObjectList.Create(True);
  try
    try
      FJID := TNXXMPPJID.Create(FConfig.JID);
      lEndpoint := ConnectEndpoint;
      PerformNegotiation(lEndpoint);
      Transition(xcsOnline);
      OnlineLoop;
      Transition(xcsClosing);
      try
        FTransport.Send('</stream:stream>');
      except
        on Exception do ;
      end;
    except
      on E: ENXXMPPError do
      begin
        if IsDisconnectRequested then
        begin
          if State <> xcsClosing then
            Transition(xcsClosing);
          Exit;
        end;
        FCriticalSection.Acquire;
        try
          FState := xcsFailed;
        finally
          FCriticalSection.Release;
        end;
        if FEvents.Count < FConfig.EventCapacity then
          EnqueueEvent(TNXXMPPEvent.CreateState(xcsFailed));
        if FEvents.Count < FConfig.EventCapacity then
          EnqueueEvent(TNXXMPPEvent.CreateError(E.Stage,
            UTF8String(E.Condition), UTF8String(E.Message)));
      end;
      on E: Exception do
      begin
        if IsDisconnectRequested then
        begin
          if State <> xcsClosing then
            Transition(xcsClosing);
          Exit;
        end;
        FCriticalSection.Acquire;
        try
          FState := xcsFailed;
        finally
          FCriticalSection.Release;
        end;
        if FEvents.Count < FConfig.EventCapacity then
          EnqueueEvent(TNXXMPPEvent.CreateState(xcsFailed));
        if FEvents.Count < FConfig.EventCapacity then
          EnqueueEvent(TNXXMPPEvent.CreateError(xesProtocol,
            'unexpected-failure', UTF8String(E.Message)));
      end;
    end;
  finally
    FRequests.CancelAll('The XMPP connection closed.', lCompletions);
    try
      EnqueueCompletionEvents(lCompletions);
    except
      on Exception do ;
    end;
    FTransport.Close;
    if State <> xcsFailed then
      try
        Transition(xcsDisconnected);
      except
        on Exception do ;
      end;
    lCompletions.Free;
  end;
end;

end.
