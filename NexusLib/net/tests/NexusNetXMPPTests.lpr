program NexusNetXMPPTests;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, Contnrs, blcksock, ssl_openssl3, synsock,
  tpNXXMPPTypes,
  obNXXMPPICU,
  obNXXMPPError,
  obNXXMPPPRECIS,
  obNXXMPPJID,
  obNXXMPPStreamFramer,
  obNXXMPPStanza,
  obNXXMPPDispatcher,
  obNXXMPPRequestManager,
  obNXXMPPEndpointResolver,
  obNXXMPPOpenSSL,
  obNXXMPPSASL,
  obNXXMPPQueue,
  obNXXMPPConfig,
  obNXXMPPEvents,
  obNXXMPPTransport,
  obNXXMPPClient,
  obNXXMPPNegotiation,
  obNXXMPPStreamManagement,
  obNXXMPPDisco,
  obNXXMPPRoster;

type
  TDispatchRecorder = class
  public
    CompletionCount: Integer;
    HandlerCount: Integer;
    LastError: UTF8String;
    procedure Complete(AStanza: TNXXMPPStanza; const AError: UTF8String);
    procedure Handle(AStanza: TNXXMPPStanza);
    function IsIQ(AStanza: TNXXMPPStanza): Boolean;
  end;

  TModuleRecorder = class
  public
    ChangedCount: Integer;
    LastJID: UTF8String;
    LastSubscription: UTF8String;
    XML: UTF8String;
    procedure Changed(ASender: TObject;
      const AJID, ASubscription: UTF8String);
    procedure Send(const AXML: UTF8String);
  end;

  TClientRecorder = class
  public
    CallbackThreadID: TThreadID;
    ErrorCount: Integer;
    StateCount: Integer;
    procedure Error(ASender: TObject; AStage: TNXXMPPErrorStage;
      const ACondition, AMessage: UTF8String);
    procedure State(ASender: TObject; AState: TNXXMPPConnectionState);
  end;

  TTLSLoopbackServer = class(TThread)
  private
    FCertificateFile: string;
    FListener: TTCPBlockSocket;
    FPort: Word;
    FPrivateKeyFile: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const ACertificateFile, APrivateKeyFile: string);
    destructor Destroy; override;
    property Port: Word read FPort;
  end;

  TBlockingLoopbackServer = class(TThread)
  private
    FListener: TTCPBlockSocket;
    FPort: Word;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    property Port: Word read FPort;
  end;

  TTransportReader = class(TThread)
  private
    FTransport: TNXXMPPTransport;
  protected
    procedure Execute; override;
  public
    constructor Create(ATransport: TNXXMPPTransport);
  end;

constructor TBlockingLoopbackServer.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FListener := TTCPBlockSocket.Create;
  FListener.Bind('127.0.0.1', '0');
  FListener.Listen;
  if FListener.LastError <> 0 then
    raise Exception.Create('Could not create the blocking loopback server.');
  FPort := FListener.GetLocalSinPort;
end;

destructor TBlockingLoopbackServer.Destroy;
begin
  FListener.CloseSocket;
  if not Finished then
    WaitFor;
  FListener.Free;
  inherited Destroy;
end;

procedure TBlockingLoopbackServer.Execute;
var
  lClient: TTCPBlockSocket;
begin
  lClient := TTCPBlockSocket.Create;
  try
    lClient.Socket := FListener.Accept;
    if lClient.Socket <> INVALID_SOCKET then
      lClient.RecvBufferStr(1, 5000);
  finally
    lClient.Free;
  end;
end;

constructor TTransportReader.Create(ATransport: TNXXMPPTransport);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FTransport := ATransport;
end;

procedure TTransportReader.Execute;
begin
  try
    FTransport.Receive(10000);
  except
    on ENXXMPPError do ;
  end;
end;

constructor TTLSLoopbackServer.Create(const ACertificateFile,
  APrivateKeyFile: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FCertificateFile := ACertificateFile;
  FPrivateKeyFile := APrivateKeyFile;
  FListener := TTCPBlockSocket.Create;
  FListener.Bind('127.0.0.1', '0');
  if FListener.LastError <> 0 then
    raise Exception.Create('Could not bind the TLS loopback listener.');
  FListener.Listen;
  if FListener.LastError <> 0 then
    raise Exception.Create('Could not listen on the TLS loopback socket.');
  FPort := FListener.GetLocalSinPort;
end;

destructor TTLSLoopbackServer.Destroy;
begin
  FListener.CloseSocket;
  if not Finished then
    WaitFor;
  FListener.Free;
  inherited Destroy;
end;

procedure TTLSLoopbackServer.Execute;
var
  lClient: TTCPBlockSocket;
begin
  lClient := TTCPBlockSocket.Create;
  try
    lClient.Socket := FListener.Accept;
    if lClient.Socket = INVALID_SOCKET then
      Exit;
    lClient.ConnectionTimeout := 2000;
    lClient.SSL.CertificateFile := FCertificateFile;
    lClient.SSL.PrivateKeyFile := FPrivateKeyFile;
    lClient.SSL.SSLType := LT_TLSv1_2;
    lClient.SSLAcceptConnection;
  finally
    lClient.Free;
  end;
end;

procedure TClientRecorder.Error(ASender: TObject; AStage: TNXXMPPErrorStage;
  const ACondition, AMessage: UTF8String);
begin
  CallbackThreadID := GetCurrentThreadID;
  Inc(ErrorCount);
end;

procedure TClientRecorder.State(ASender: TObject;
  AState: TNXXMPPConnectionState);
begin
  CallbackThreadID := GetCurrentThreadID;
  Inc(StateCount);
end;

procedure TModuleRecorder.Send(const AXML: UTF8String);
begin
  XML := AXML;
end;

procedure TModuleRecorder.Changed(ASender: TObject;
  const AJID, ASubscription: UTF8String);
begin
  Inc(ChangedCount);
  LastJID := AJID;
  LastSubscription := ASubscription;
end;

procedure TDispatchRecorder.Complete(AStanza: TNXXMPPStanza;
  const AError: UTF8String);
begin
  Inc(CompletionCount);
  LastError := AError;
end;

procedure TDispatchRecorder.Handle(AStanza: TNXXMPPStanza);
begin
  Inc(HandlerCount);
end;

function TDispatchRecorder.IsIQ(AStanza: TNXXMPPStanza): Boolean;
begin
  Result := Assigned(AStanza) and (AStanza.Kind = xskIQ);
end;

procedure AssertTrue(AValue: Boolean; const AMessage: string);
begin
  if not AValue then
    raise Exception.Create(AMessage);
end;

procedure AssertEquals(const AExpected, AActual: UTF8String;
  const AMessage: string);
begin
  if AExpected <> AActual then
    raise Exception.CreateFmt('%s Expected "%s", received "%s".',
      [AMessage, AExpected, AActual]);
end;

function HexValue(const AValue: RawByteString): string;
const
  cHex = '0123456789abcdef';
var
  lIndex: Integer;
begin
  SetLength(Result, Length(AValue) * 2);
  for lIndex := 1 to Length(AValue) do
  begin
    Result[(lIndex * 2) - 1] := cHex[(Ord(AValue[lIndex]) shr 4) + 1];
    Result[lIndex * 2] := cHex[(Ord(AValue[lIndex]) and $0F) + 1];
  end;
end;

procedure AssertRaises(const ACondition, AMessage: string;
  AProcedure: TProcedure);
begin
  try
    AProcedure;
  except
    on E: Exception do
    begin
      if (ACondition <> '') and (Pos(ACondition, E.Message) = 0) then
        raise Exception.CreateFmt('%s Wrong failure: %s', [AMessage, E.Message]);
      Exit;
    end;
  end;
  raise Exception.Create(AMessage + ' Expected an exception.');
end;

procedure TestICU;
begin
  TNXXMPPICU.RequireAvailable;
  AssertEquals(UTF8Encode(UnicodeString(#$00E9)),
    TNXXMPPICU.NFCNormalize(UTF8String('e') +
      UTF8Encode(UnicodeString(#$0301))),
    'ICU should normalize to NFC.');
  AssertEquals('example.com', TNXXMPPICU.IDNAToASCII('example.com'),
    'ICU should preserve an ASCII domain.');
  AssertEquals('xn--bcher-kva.example',
    TNXXMPPICU.IDNAToASCII(UTF8String('b') +
      UTF8Encode(UnicodeString(#$00FC)) +
      'cher.example'), 'ICU should apply non-transitional IDNA.');
end;

procedure TestPRECIS;
begin
  AssertEquals('kevin', TNXXMPPPRECIS.EnforceUsernameCaseMapped('KEVIN'),
    'UsernameCaseMapped should lowercase.');
  AssertEquals('abc', TNXXMPPPRECIS.EnforceUsernameCaseMapped(
    UTF8Encode(UnicodeString(#$FF21#$FF22#$FF23))),
    'UsernameCaseMapped should width-map fullwidth letters.');
  AssertEquals('l' + UTF8Encode(UnicodeString(#$00B7)) + 'l',
    TNXXMPPPRECIS.EnforceUsernameCaseMapped(
      UTF8String('L') + UTF8Encode(UnicodeString(#$00B7)) + 'L'),
    'MIDDLE DOT should be valid between lowercase l characters.');
end;

procedure TestJID;
var
  lJID: TNXXMPPJID;
begin
  lJID := TNXXMPPJID.Create(UTF8String('KEVIN@b') +
    UTF8Encode(UnicodeString(#$00FC)) + 'cher.example/Desk');
  try
    AssertEquals('kevin@xn--bcher-kva.example/Desk', lJID.ToString,
      'JID should prepare each part according to its profile.');
    AssertEquals('kevin@xn--bcher-kva.example', lJID.Bare,
      'Bare JID should omit the resourcepart.');
  finally
    lJID.Free;
  end;
end;

procedure TestStreamFramerAndStanza;
var
  lFrames: TStringList;
  lFramer: TNXXMPPStreamFramer;
  lInput: RawByteString;
  lStanza: TNXXMPPStanza;
  lSplit: Integer;
begin
  lFramer := TNXXMPPStreamFramer.Create;
  lFrames := TStringList.Create;
  try
    lInput := '<stream:stream xmlns=''jabber:client'' ' +
      'xmlns:stream=''http://etherx.jabber.org/streams''>' +
      '<iq type=''get'' id=''one''><query xmlns=''urn:test''/></iq>' +
      '<message id=''two''><body>Hello</body></message>' +
      '</stream:stream>';
    lFramer.Feed(Copy(lInput, 1, 17), lFrames);
    AssertTrue(lFrames.Count = 0,
      'A partial stream opening must not emit a frame.');
    lFramer.Feed(Copy(lInput, 18, 31), lFrames);
    lFramer.Feed(Copy(lInput, 49, MaxInt), lFrames);
    AssertTrue(lFrames.Count = 4,
      'The framer should emit opening, two stanzas, and closing.');
    lStanza := TNXXMPPStanza.Create(UTF8String(lFrames[1]),
      lFramer.StreamNamespaceAttributes);
    try
      AssertTrue(lStanza.Kind = xskIQ, 'The IQ stanza kind should be retained.');
      AssertTrue(lStanza.IQType = xitGet, 'The IQ type should be retained.');
      AssertEquals('jabber:client', lStanza.NamespaceURI,
        'The inherited stream namespace should apply to the stanza.');
      AssertEquals('urn:test', lStanza.ChildNamespaceURI,
        'The child QName namespace should be retained.');
      AssertEquals('query', lStanza.ChildLocalName,
        'The child QName local name should be retained.');
    finally
      lStanza.Free;
    end;
  finally
    lFrames.Free;
    lFramer.Free;
  end;
  for lSplit := 1 to Length(lInput) - 1 do
  begin
    lFramer := TNXXMPPStreamFramer.Create;
    lFrames := TStringList.Create;
    try
      lFramer.Feed(Copy(lInput, 1, lSplit), lFrames);
      lFramer.Feed(Copy(lInput, lSplit + 1, MaxInt), lFrames);
      AssertTrue(lFrames.Count = 4,
        'Every byte boundary should preserve all stream frames.');
    finally
      lFrames.Free;
      lFramer.Free;
    end;
  end;
end;

procedure TestDispatcherAndRequests;
var
  lCapacity: TNXXMPPIQCapacity;
  lCompletion: TNXXMPPIQCompletionEvent;
  lDispatcher: TNXXMPPDispatcher;
  lEvents: TObjectList;
  lID: UTF8String;
  lManager: TNXXMPPRequestManager;
  lRecorder: TDispatchRecorder;
  lStanza: TNXXMPPStanza;
begin
  lRecorder := TDispatchRecorder.Create;
  lDispatcher := TNXXMPPDispatcher.Create;
  lManager := TNXXMPPRequestManager.Create(2);
  lEvents := TObjectList.Create(True);
  lCapacity := TNXXMPPIQCapacity.Create(1);
  try
    AssertTrue(lCapacity.TryReserve,
      'The public IQ capacity should reserve available capacity.');
    AssertTrue(not lCapacity.TryReserve,
      'The public IQ capacity should reject synchronous overflow.');
    lCapacity.Release;
    AssertTrue(lCapacity.TryReserve,
      'Released IQ capacity should become synchronously available.');
    lCapacity.Release;
    lDispatcher.RegisterIQResponder(xitGet, 'urn:test', 'query',
      @lRecorder.Handle);
    try
      lDispatcher.RegisterIQResponder(xitGet, 'urn:test', 'query',
        @lRecorder.Handle);
      raise Exception.Create('A duplicate IQ responder should fail.');
    except
      on E: ENXXMPPError do
        AssertTrue(E.Condition = 'duplicate-iq-responder',
          'Duplicate ownership should report its exact condition.');
    end;
    lDispatcher.RegisterObserver(@lRecorder.IsIQ, @lRecorder.Handle);
    lStanza := TNXXMPPStanza.Create(
      '<iq xmlns=''jabber:client'' type=''get'' id=''one''>' +
      '<query xmlns=''urn:test''/></iq>', '');
    try
      AssertTrue(lDispatcher.DispatchStanza(lStanza),
        'The exact IQ responder should handle its registered QName.');
      AssertTrue(lRecorder.HandlerCount = 2,
        'The exclusive responder and matching observer should both run.');
    finally
      lStanza.Free;
    end;

    lID := lManager.BeginRequest('server.example', 1000, @lRecorder.Complete);
    lStanza := TNXXMPPStanza.Create(
      '<iq xmlns=''jabber:client'' type=''result'' from=''server.example'' id=''' +
      lID + '''/>', '');
    lCompletion := lManager.Complete(lStanza);
    AssertTrue(Assigned(lCompletion),
      'A matching IQ result should produce a queued completion event.');
    AssertTrue(lManager.Count = 0,
      'A completed IQ request should leave the pending set.');
    lCompletion.Invoke;
    lCompletion.Free;
    AssertTrue(lRecorder.CompletionCount = 1,
      'IQ completion should invoke only when the caller pumps the event.');

    lManager.BeginRequest('', 0, @lRecorder.Complete);
    lManager.CollectTimeouts(GetTickCount64, lEvents);
    AssertTrue(lEvents.Count = 1,
      'An expired IQ request should become a queued timeout event.');
    TNXXMPPIQCompletionEvent(lEvents[0]).Invoke;
    AssertTrue(lRecorder.LastError <> '',
      'A timeout completion should carry an error.');
  finally
    lCapacity.Free;
    lEvents.Free;
    lManager.Free;
    lDispatcher.Free;
    lRecorder.Free;
  end;
end;

procedure TestEndpointOrderingAndCrypto;
var
  lCombined: TNXXMPPEndpointArray;
  lEndpoints: TNXXMPPEndpointArray;
  lRecords: TStringList;
begin
  lRecords := TStringList.Create;
  try
    lRecords.Add('20,0,5222,late.example');
    lRecords.Add('10,1,5222,first.example');
    lRecords.Add('10,5,5222,weighted.example');
    lEndpoints := TNXXMPPEndpointResolver.OrderSRVRecords(lRecords,
      xtsStartTLS, 1234);
    AssertTrue(Length(lEndpoints) = 3,
      'All valid SRV endpoints should be retained.');
    AssertTrue((lEndpoints[0].Priority = 10) and
      (lEndpoints[1].Priority = 10) and (lEndpoints[2].Priority = 20),
      'SRV priority groups should be ordered before weight selection.');
  finally
    lRecords.Free;
  end;
  SetLength(lCombined, 2);
  lCombined[0].Host := 'direct.example';
  lCombined[0].Priority := 20;
  lCombined[0].Weight := 1;
  lCombined[0].Security := xtsDirectTLS;
  lCombined[1].Host := 'starttls.example';
  lCombined[1].Priority := 10;
  lCombined[1].Weight := 1;
  lCombined[1].Security := xtsStartTLS;
  lCombined := TNXXMPPEndpointResolver.OrderEndpoints(lCombined, 1);
  AssertTrue((lCombined[0].Host = 'starttls.example') and
    (lCombined[0].Security = xtsStartTLS),
    'Direct TLS and STARTTLS endpoints should share one priority order.');
  TNXXMPPOpenSSL.RequireAvailable;
  AssertEquals('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    HexValue(TNXXMPPOpenSSL.SHA256('abc')),
    'OpenSSL should provide SHA-256.');
  AssertTrue(Length(TNXXMPPOpenSSL.RandomBytes(32)) = 32,
    'OpenSSL should provide secure random bytes.');
end;

procedure TestTLSVerification;
var
  lCAFile: string;
  lFixturePath: string;
  lServer: TTLSLoopbackServer;
  lTransport: TNXXMPPTransport;
begin
  lFixturePath := IncludeTrailingPathDelimiter(GetCurrentDir) +
    'NexusLib\net\tests\fixtures\xmpp\';
  lCAFile := lFixturePath + 'ca.crt';
  AssertTrue(FileExists(lCAFile) and
    FileExists(lFixturePath + 'server.crt') and
    FileExists(lFixturePath + 'server.key'),
    'The synthetic TLS fixtures should be available.');

  lServer := TTLSLoopbackServer.Create(lFixturePath + 'server.crt',
    lFixturePath + 'server.key');
  lTransport := TNXXMPPTransport.Create;
  try
    lServer.Start;
    lTransport.Connect('127.0.0.1', lServer.Port, 2000);
    lTransport.Secure('localhost', lCAFile);
    AssertTrue(lTransport.Socket.SSL.SSLEnabled,
      'A trusted loopback certificate with the right identity should pass.');
  finally
    lTransport.Free;
    lServer.Free;
  end;

  lServer := TTLSLoopbackServer.Create(lFixturePath + 'server.crt',
    lFixturePath + 'server.key');
  lTransport := TNXXMPPTransport.Create;
  try
    lServer.Start;
    lTransport.Connect('127.0.0.1', lServer.Port, 2000);
    try
      lTransport.Secure('wrong.example', lCAFile);
      raise Exception.Create('A wrong TLS service identity should fail.');
    except
      on E: ENXXMPPError do
        AssertTrue(E.Condition = 'tls-failed',
          'A wrong TLS identity should fail in the TLS owner.');
    end;
  finally
    lTransport.Free;
    lServer.Free;
  end;

  lServer := TTLSLoopbackServer.Create(lFixturePath + 'server.crt',
    lFixturePath + 'server.key');
  lTransport := TNXXMPPTransport.Create;
  try
    lServer.Start;
    lTransport.Connect('127.0.0.1', lServer.Port, 2000);
    try
      lTransport.Secure('localhost', lFixturePath + 'untrusted-ca.crt');
      raise Exception.Create('An untrusted TLS issuer should fail.');
    except
      on E: ENXXMPPError do
        AssertTrue(E.Condition = 'tls-failed',
          'An untrusted TLS issuer should fail in the TLS owner.');
    end;
  finally
    lTransport.Free;
    lServer.Free;
  end;
end;

procedure TestBlockedReadInterruption;
var
  lElapsed: QWord;
  lReader: TTransportReader;
  lServer: TBlockingLoopbackServer;
  lStarted: QWord;
  lTransport: TNXXMPPTransport;
begin
  lServer := TBlockingLoopbackServer.Create;
  lTransport := TNXXMPPTransport.Create;
  lReader := nil;
  try
    lServer.Start;
    lTransport.Connect('127.0.0.1', lServer.Port, 2000);
    lReader := TTransportReader.Create(lTransport);
    lReader.Start;
    Sleep(100);
    lStarted := GetTickCount64;
    lTransport.Interrupt;
    lReader.WaitFor;
    lElapsed := GetTickCount64 - lStarted;
    AssertTrue(lElapsed < 2000,
      'The independent shutdown path should wake a blocked socket read.');
  finally
    lReader.Free;
    lTransport.Free;
    lServer.Free;
  end;
end;

procedure TestSCRAMSHA256;
var
  lSCRAM: TNXXMPPSCRAMSHA256;
begin
  lSCRAM := TNXXMPPSCRAMSHA256.Create;
  try
    AssertEquals('n,,n=user,r=rOprNGfwEbeRWgbNEkqO',
      lSCRAM.Start('user', 'rOprNGfwEbeRWgbNEkqO'),
      'SCRAM should produce the RFC 7677 client-first message.');
    AssertEquals(
      'c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,' +
      'p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=',
      lSCRAM.Continue(
        'r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,' +
        's=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096', 'pencil'),
      'SCRAM should reproduce the RFC 7677 client proof.');
    lSCRAM.VerifyServerFinal(
      'v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=');
    lSCRAM.Start('user', 'clientnonce');
    try
      lSCRAM.Continue('r=wrongnonce,s=QSXCR+Q6sek8bf92,i=4096',
        'pencil');
      raise Exception.Create('A mismatched SCRAM nonce should fail.');
    except
      on E: ENXXMPPError do
        AssertTrue(E.Condition = 'invalid-scram-nonce',
          'A mismatched SCRAM nonce should have an exact condition.');
    end;
    lSCRAM.Start('user', 'clientnonce');
    try
      lSCRAM.Continue(
        'r=clientnonceserver,s=QSXCR+Q6sek8bf92,i=1', 'pencil');
      raise Exception.Create('A weak SCRAM iteration count should fail.');
    except
      on E: ENXXMPPError do
        AssertTrue(E.Condition = 'scram-iteration-policy',
          'Weak SCRAM iteration counts should be rejected by policy.');
    end;
    lSCRAM.Start('user', 'rOprNGfwEbeRWgbNEkqO');
    lSCRAM.Continue(
      'r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,' +
      's=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096', 'pencil');
    try
      lSCRAM.VerifyServerFinal('v=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' +
        'AAAAAAAAAAA=');
      raise Exception.Create('A mismatched SCRAM signature should fail.');
    except
      on E: ENXXMPPError do
        AssertTrue(E.Condition = 'scram-signature-mismatch',
          'A mismatched SCRAM signature should be rejected.');
    end;
  finally
    lSCRAM.Free;
  end;
end;

procedure TestBoundedQueue;
var
  lFirst: TObject;
  lQueue: TNXXMPPObjectQueue;
  lRejected: TObject;
begin
  lQueue := TNXXMPPObjectQueue.Create(1);
  try
    lFirst := TObject.Create;
    AssertTrue(lQueue.Enqueue(lFirst),
      'The queue should accept an item below capacity.');
    lRejected := TObject.Create;
    AssertTrue(not lQueue.Enqueue(lRejected),
      'The queue should reject an item at capacity.');
    lRejected.Free;
    AssertTrue(lQueue.Dequeue = lFirst,
      'The queue should transfer the enqueued object in order.');
    lFirst.Free;
  finally
    lQueue.Free;
  end;
end;

procedure TestNegotiationAndStates;
begin
  AssertTrue(TNXXMPPNegotiation.OffersStartTLS(
    '<starttls xmlns=''urn:ietf:params:xml:ns:xmpp-tls''/>'),
    'STARTTLS should be detected from stream features.');
  AssertTrue(TNXXMPPNegotiation.SelectAuthentication(
    '<mechanism>SCRAM-SHA-256</mechanism>', False, True) =
    xamSCRAMSHA256, 'SCRAM-SHA-256 should be preferred.');
  AssertTrue(TNXXMPPNegotiation.SelectAuthentication(
    '<mechanism>PLAIN</mechanism>', False, True) = xamNone,
    'PLAIN should require explicit policy permission.');
  AssertTrue(NXXMPPStateTransitionAllowed(xcsDisconnected, xcsResolving),
    'Resolution should be a legal initial transition.');
  AssertTrue(NXXMPPStateTransitionAllowed(xcsOnline, xcsClosing),
    'Online sessions should close explicitly.');
  AssertTrue(not NXXMPPStateTransitionAllowed(xcsOnline, xcsAuthenticating),
    'Online sessions must not jump back to authentication.');
end;

procedure TestStreamManagement;
var
  lResponse: TNXXMPPStanza;
  lSM: TNXXMPPStreamManagement;
begin
  lSM := TNXXMPPStreamManagement.Create(2);
  try
    lSM.Enable('resume-token');
    lSM.IncomingHandled;
    lSM.OutgoingSent('<message id=''one''/>', True);
    lSM.OutgoingSent('<iq id=''unsafe''/>', False);
    lSM.OutgoingSent('<presence/>', True);
    AssertTrue(lSM.ReplayCount = 2,
      'Replayable unacknowledged stanzas should be retained.');
    lResponse := TNXXMPPStanza.Create(
      '<resumed xmlns=''urn:xmpp:sm:3'' h=''2'' previd=''resume-token''/>',
      '');
    try
      AssertTrue(lSM.ProcessResumeResponse(lResponse),
        'An accepted resumption response should continue the managed stream.');
    finally
      lResponse.Free;
    end;
    AssertTrue(lSM.ReplayCount = 1,
      'An acknowledgement should release the acknowledged prefix.');
    AssertEquals('<presence/>', lSM.ReplayXML(0),
      'Only the eligible unacknowledged suffix should be replayed.');
    AssertEquals('<a xmlns=''urn:xmpp:sm:3'' h=''1''/>',
      lSM.AcknowledgementXML,
      'The acknowledgement should report handled inbound stanzas.');
    AssertTrue(Pos('previd=''resume-token''',
      string(lSM.ResumeRequestXML)) > 0,
      'A resumable stream should build a resume request with its token.');
    lResponse := TNXXMPPStanza.Create(
      '<failed xmlns=''urn:xmpp:sm:3''/>', '');
    try
      AssertTrue(not lSM.ProcessResumeResponse(lResponse),
        'A failed resumption response should reject the prior stream.');
    finally
      lResponse.Free;
    end;
    AssertTrue(not lSM.Enabled and (lSM.ReplayCount = 0),
      'Rejected resumption should discard the obsolete replay state.');
  finally
    lSM.Free;
  end;
end;

procedure TestDiscoModule;
var
  lDisco: TNXXMPPDiscoModule;
  lDispatcher: TNXXMPPDispatcher;
  lRecorder: TModuleRecorder;
  lStanza: TNXXMPPStanza;
begin
  lDisco := TNXXMPPDiscoModule.Create('client', 'pc', 'NexusXMPP');
  lDispatcher := TNXXMPPDispatcher.Create;
  lRecorder := TModuleRecorder.Create;
  try
    lDisco.AddFeature('urn:xmpp:ping');
    lDisco.Sender := @lRecorder.Send;
    lDisco.RegisterHandlers(lDispatcher);
    lStanza := TNXXMPPStanza.Create(
      '<iq xmlns=''jabber:client'' type=''get'' id=''d1'' from=''peer''>' +
      '<query xmlns=''http://jabber.org/protocol/disco#info''/></iq>', '');
    try
      AssertTrue(lDispatcher.DispatchStanza(lStanza),
        'Disco info should own its exact IQ key.');
      AssertTrue(Pos('urn:xmpp:ping', string(lRecorder.XML)) > 0,
        'Disco info should advertise configured features.');
    finally
      lStanza.Free;
    end;
  finally
    lRecorder.Free;
    lDispatcher.Free;
    lDisco.Free;
  end;
end;

procedure TestRosterModule;
var
  lDispatcher: TNXXMPPDispatcher;
  lRecorder: TModuleRecorder;
  lRoster: TNXXMPPRosterModule;
  lStanza: TNXXMPPStanza;
begin
  lDispatcher := TNXXMPPDispatcher.Create;
  lRecorder := TModuleRecorder.Create;
  lRoster := TNXXMPPRosterModule.Create;
  try
    lRoster.Sender := @lRecorder.Send;
    lRoster.OnChanged := @lRecorder.Changed;
    lRoster.RegisterHandlers(lDispatcher);
    lStanza := TNXXMPPStanza.Create(
      '<iq xmlns=''jabber:client'' type=''set'' id=''r1''>' +
      '<query xmlns=''jabber:iq:roster''><item jid=''peer@example.com'' ' +
      'name=''Peer'' subscription=''both''/></query></iq>', '');
    try
      AssertTrue(lDispatcher.DispatchStanza(lStanza),
        'Roster pushes should own their exact IQ key.');
      AssertEquals('Peer', lRoster.Item('peer@example.com'),
        'A roster push should update the in-memory roster.');
      AssertTrue(Pos('type=''result''', string(lRecorder.XML)) > 0,
        'A roster push should receive the required acknowledgement.');
      lRoster.PumpStanza(lStanza);
      AssertTrue((lRecorder.ChangedCount = 1) and
        (lRecorder.LastJID = 'peer@example.com') and
        (lRecorder.LastSubscription = 'both'),
        'A pumped roster push should publish its subscription state.');
    finally
      lStanza.Free;
    end;
    lStanza := TNXXMPPStanza.Create(
      '<iq xmlns=''jabber:client'' type=''result'' id=''initial''>' +
      '<query xmlns=''jabber:iq:roster''><item jid=''two@example.com'' ' +
      'name=''Two'' subscription=''from''/></query></iq>', '');
    try
      lRoster.CompleteRequest(lStanza, '');
      AssertEquals('Two', lRoster.Item('two@example.com'),
        'Initial roster retrieval should populate roster items.');
      AssertEquals('from', lRoster.ItemSubscription('two@example.com'),
        'Roster retrieval should retain subscription state.');
    finally
      lStanza.Free;
    end;
  finally
    lRoster.Free;
    lRecorder.Free;
    lDispatcher.Free;
  end;
end;

procedure TestClientLifecycleAndCapacity;
var
  lClient: TNXXMPPClient;
  lCycle: Integer;
  lDeadline: QWord;
  lMainThreadID: TThreadID;
  lRecorder: TClientRecorder;
begin
  lClient := TNXXMPPClient.Create;
  lRecorder := TClientRecorder.Create;
  try
    lClient.Config.JID := 'user@example.com';
    lClient.Config.Password := 'password';
    lClient.Config.CAFile := ParamStr(0);
    lClient.Config.EndpointHost := '127.0.0.1';
    lClient.Config.EndpointPort := 1;
    lClient.Config.ConnectionTimeoutMS := 100;
    lClient.Config.PendingIQCapacity := 1;
    lClient.Config.ReconnectAttempts := 0;
    lClient.OnError := @lRecorder.Error;
    lClient.OnState := @lRecorder.State;
    lMainThreadID := GetCurrentThreadID;
    for lCycle := 1 to 2 do
    begin
      lClient.Connect;
      AssertTrue(lClient.SendIQ(xitGet, '', '', '<query xmlns=''urn:test''/>',
        nil), 'The first public IQ request should reserve capacity.');
      AssertTrue(not lClient.SendIQ(xitGet, '', '',
        '<query xmlns=''urn:test''/>', nil),
        'The second public IQ request should reject capacity synchronously.');
      lDeadline := GetTickCount64 + 5000;
      while (lClient.State <> xcsFailed) and
        (GetTickCount64 < lDeadline) do
        Sleep(10);
      AssertTrue(lClient.State = xcsFailed,
        'A refused loopback endpoint should produce a terminal failure.');
      lClient.Disconnect;
      lClient.PumpEvents;
    end;
    AssertTrue((lRecorder.ErrorCount = 2) and (lRecorder.StateCount > 0),
      'Repeated failed connection cycles should deliver pumped events.');
    AssertTrue(lRecorder.CallbackThreadID = lMainThreadID,
      'Client callbacks should execute on the PumpEvents caller thread.');
  finally
    lRecorder.Free;
    lClient.Free;
  end;
end;

begin
  TestICU;
  TestPRECIS;
  TestJID;
  TestStreamFramerAndStanza;
  TestDispatcherAndRequests;
  TestEndpointOrderingAndCrypto;
  TestTLSVerification;
  TestBlockedReadInterruption;
  TestSCRAMSHA256;
  TestBoundedQueue;
  TestNegotiationAndStates;
  TestStreamManagement;
  TestDiscoModule;
  TestRosterModule;
  TestClientLifecycleAndCapacity;
  WriteLn('NexusNet XMPP tests passed.');
end.
