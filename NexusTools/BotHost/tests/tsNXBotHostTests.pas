unit tsNXBotHostTests;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  obNXTestRegistry;

procedure RegisterNXBotHostTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  fpjson,
  SyncObjs,
  SysUtils,
  obNXBotCatalog,
  obNXBotControlInterpreter,
  obNXBotController,
  obNXBotConversation,
  obNXBotHost,
  obNXBotHostConfig,
  obNXBotHostRuntime,
  obNXBotProvider,
  obNXBotHostRouter,
  obNXBotHostState,
  obNXCodexAppServer,
  obNXCodexAppServerMessages,
  obNXCodexAppServerTypes,
  obNXJSONRPCMessages,
  obNXOpenAIProvider,
  obNXXMPPCommand,
  obNXXMPPBotControl,
  obNXXMPPDispatcher,
  obNXXMPPModule,
  obNXXMPPRequestManager,
  obNXXMPPStanza,
  obNXTestContext,
  obNXTestSuite,
  tpNXBotHost,
  tpNXBotControl,
  tpNXXMPPMessageTypes,
  tpNXXMPPTypes;

type
  TTestConversationTracker = class(TNXBotConversationTracker)
  public
    Tick: QWord;
  protected
    function CurrentTick: QWord; override;
  end;

  TRuntimeActivityRecorder = class
  public
    Text: UTF8String;
    procedure Activity(const AText: UTF8String);
  end;

  TControllerProbeThread = class(TThread)
  private
    FController: TNXBotController;
    FEvent: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(AController: TNXBotController; AEvent: TEvent);
  end;

  TControllerExecuteThread = class(TThread)
  private
    FAuthorization: TNXBotAuthorization;
    FCompletion: TNXBotControlCompletion;
    FController: TNXBotController;
    FOperation: TNXBotControlOperation;
  protected
    procedure Execute; override;
  public
    Accepted: Boolean;
    Token: QWord;
    constructor Create(AController: TNXBotController;
      const AOperation: TNXBotControlOperation;
      const AAuthorization: TNXBotAuthorization;
      ACompletion: TNXBotControlCompletion);
  end;

  TControllerLockProbe = class
  private
    FEvent: TEvent;
    FThread: TControllerProbeThread;
  public
    destructor Destroy; override;
    procedure Finish;
    function Run(AController: TNXBotController): Boolean;
  end;

  TControlRecorder = class
  public
    Count: Integer;
    Controller: TNXBotController;
    LockProbe: TControllerLockProbe;
    LockProbeSucceeded: Boolean;
    ResultValue: TNXBotControlResult;
    Token: QWord;
    procedure Complete(const AToken: QWord;
      const AResult: TNXBotControlResult);
  end;

  TFakeHostShutdownRecorder = class
  public
    Count: Integer;
    LockProbeSucceeded: Boolean;
  end;

  TFakeBotHost = class(TNXBotHost)
  private
    procedure ProbeControllerLock;
    procedure SignalChanged;
  public
    Controller: TNXBotController;
    LockProbe: TControllerLockProbe;
    LockProbeCount: Integer;
    LockProbeOnLifecycle: Boolean;
    LockProbeSucceeded: Boolean;
    JoinEntered: TEvent;
    JoinRelease: TEvent;
    ProducerThread: TThread;
    ShutdownRecorder: TFakeHostShutdownRecorder;
    BlockJoins: Boolean;
    StallJoins: Boolean;
    function ConnectXMPP: Boolean; override;
    function JoinRoom(const ARoomJID: UTF8String): Boolean; override;
    function LeaveRoom(const ARoomJID: UTF8String): Boolean; override;
    function StartProvider: Boolean; override;
    procedure Shutdown; override;
  end;

  TAppServerStateRecorder = class
  public
    Count: Integer;
    procedure Changed(ASender: TObject; AState: TNXBotProviderState;
      const ADetail: UTF8String);
  end;

  TAppServerProcessRecorder = class
  private
    FAnswer: UTF8String;
    FControlCount: Integer;
    FCriticalSection: TRTLCriticalSection;
    FDiagnosticCount: Integer;
    FFailed: Boolean;
    FFinalCount: Integer;
    FReady: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Answer(out AText: UTF8String): Integer;
    function BotControl(ASender: TObject;
      const AOperation: TNXBotControlOperation;
      const AAuthorization: TNXBotAuthorization;
      ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
    function ControlCount: Integer;
    procedure Diagnostic(ASender: TObject; const AText: UTF8String);
    function DiagnosticCount: Integer;
    function Failed: Boolean;
    procedure FinalAnswer(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    function Ready: Boolean;
    procedure StateChanged(ASender: TObject;
      AState: TNXBotProviderState; const ADetail: UTF8String);
  end;

  TBotControlIQHarness = class
  public
    Authorization: TNXBotAuthorization;
    CancelCount: Integer;
    CompleteCancellationImmediately: Boolean;
    CompletionCount: Integer;
    DeferRequest: Boolean;
    DeferredCompletion: TNXBotControlCompletion;
    IncomingResult: TNXBotControlResult;
    LastOperation: TNXBotControlOperation;
    LoseTransportDuringRequest: Boolean;
    Module: TNXXMPPBotControlModule;
    OutboundResult: TNXBotControlResult;
    RejectRequest: Boolean;
    SentXML: UTF8String;
    function Cancel(AToken: QWord; const AReason: UTF8String): Boolean;
    procedure CallerComplete(const AResult: TNXBotControlResult);
    procedure FinishDeferredCancellation(const AReason: UTF8String);
    function IQSubmit(AType: TNXXMPPIQType; const AToJID,
      AExpectedFrom, APayload: UTF8String;
      AHandler: TNXXMPPIQCompletionHandler; ATimeoutMS: Cardinal): Boolean;
    function Request(const AOperation: TNXBotControlOperation;
      const AAuthorization: TNXBotAuthorization;
      ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
    procedure Send(const AXML: UTF8String; AReplayable: Boolean);
    function Submit(AModule: TObject;
      AOperation: TNXXMPPModuleOperation): Boolean;
  end;

function TTestConversationTracker.CurrentTick: QWord;
begin
  Result := Tick;
end;

procedure TRuntimeActivityRecorder.Activity(const AText: UTF8String);
begin
  Text := AText;
end;

constructor TControllerProbeThread.Create(AController: TNXBotController;
  AEvent: TEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FController := AController;
  FEvent := AEvent;
end;

procedure TControllerProbeThread.Execute;
begin
  FController.SetOperationCapacity(1);
  FEvent.SetEvent;
end;

constructor TAppServerProcessRecorder.Create;
begin
  inherited Create;
  InitCriticalSection(FCriticalSection);
end;

destructor TAppServerProcessRecorder.Destroy;
begin
  DoneCriticalSection(FCriticalSection);
  inherited Destroy;
end;

function TAppServerProcessRecorder.Answer(out AText: UTF8String): Integer;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FFinalCount;
    AText := FAnswer;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TAppServerProcessRecorder.BotControl(ASender: TObject;
  const AOperation: TNXBotControlOperation;
  const AAuthorization: TNXBotAuthorization;
  ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
var
  lResult: TNXBotControlResult;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Inc(FControlCount);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  AToken := 99;
  lResult.Error := bceNone;
  lResult.Detail := '';
  lResult.NoOp := False;
  SetLength(lResult.Bots, 1);
  lResult.Bots[0].Name := AOperation.BotName;
  lResult.Bots[0].Known := True;
  lResult.Bots[0].Active := True;
  lResult.Bots[0].ProviderState := 'ready';
  lResult.Bots[0].XMPPState := 'online';
  ACompletion(AToken, lResult);
  Result := AAuthorization.VerifiedMUCIdentity;
end;

function TAppServerProcessRecorder.ControlCount: Integer;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FControlCount;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TAppServerProcessRecorder.Diagnostic(ASender: TObject;
  const AText: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    Inc(FDiagnosticCount);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TAppServerProcessRecorder.DiagnosticCount: Integer;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FDiagnosticCount;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TAppServerProcessRecorder.Failed: Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FFailed;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TAppServerProcessRecorder.FinalAnswer(ASender: TObject;
  APrompt: TNXBotPrompt; const AText: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FAnswer := AText;
    Inc(FFinalCount);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TAppServerProcessRecorder.Ready: Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FReady;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TAppServerProcessRecorder.StateChanged(ASender: TObject;
  AState: TNXBotProviderState; const ADetail: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FReady := AState = bpsReady;
    if AState = bpsFailed then
      FFailed := True;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

constructor TControllerExecuteThread.Create(AController: TNXBotController;
  const AOperation: TNXBotControlOperation;
  const AAuthorization: TNXBotAuthorization;
  ACompletion: TNXBotControlCompletion);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FController := AController;
  FOperation := AOperation;
  FAuthorization := AAuthorization;
  FCompletion := ACompletion;
end;

procedure TControllerExecuteThread.Execute;
begin
  Accepted := FController.Execute(FOperation, FAuthorization, FCompletion,
    Token);
end;

destructor TControllerLockProbe.Destroy;
begin
  Finish;
  inherited Destroy;
end;

procedure TControllerLockProbe.Finish;
begin
  if Assigned(FThread) then
  begin
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  FreeAndNil(FEvent);
end;

function TControllerLockProbe.Run(AController: TNXBotController): Boolean;
begin
  Finish;
  FEvent := TEvent.Create(nil, True, False, '');
  FThread := TControllerProbeThread.Create(AController, FEvent);
  FThread.Start;
  Result := FEvent.WaitFor(1000) = wrSignaled;
end;

function TBotControlIQHarness.Cancel(AToken: QWord;
  const AReason: UTF8String): Boolean;
var
  lCompletion: TNXBotControlCompletion;
begin
  Inc(CancelCount);
  Result := AToken = 42;
  if Result and CompleteCancellationImmediately and
    Assigned(DeferredCompletion) then
  begin
    lCompletion := DeferredCompletion;
    DeferredCompletion := nil;
    lCompletion(AToken, NXBotControlFailure(bceCancelled, AReason));
  end;
end;

procedure TBotControlIQHarness.FinishDeferredCancellation(
  const AReason: UTF8String);
var
  lCompletion: TNXBotControlCompletion;
begin
  lCompletion := DeferredCompletion;
  DeferredCompletion := nil;
  if Assigned(lCompletion) then
    lCompletion(42, NXBotControlFailure(bceCancelled, AReason));
end;

procedure TControlRecorder.Complete(const AToken: QWord;
  const AResult: TNXBotControlResult);
begin
  if Assigned(Controller) and Assigned(LockProbe) then
    LockProbeSucceeded := LockProbe.Run(Controller);
  Inc(Count);
  Token := AToken;
  ResultValue := AResult;
end;

procedure TFakeBotHost.SignalChanged;
begin
  if Assigned(OnChanged) then
    OnChanged(Self);
end;

procedure TFakeBotHost.ProbeControllerLock;
begin
  if not LockProbeOnLifecycle or not Assigned(Controller) or
    not Assigned(LockProbe) then
    Exit;
  Inc(LockProbeCount);
  if LockProbeCount = 1 then
    LockProbeSucceeded := True;
  if not LockProbe.Run(Controller) then
    LockProbeSucceeded := False;
end;

function TFakeBotHost.StartProvider: Boolean;
begin
  ProbeControllerLock;
  State.SetProvider(bpsReady, 'fake');
  SignalChanged;
  Result := True;
end;

function TFakeBotHost.ConnectXMPP: Boolean;
begin
  ProbeControllerLock;
  State.SetXMPP('online');
  SignalChanged;
  Result := True;
end;

function TFakeBotHost.JoinRoom(const ARoomJID: UTF8String): Boolean;
begin
  ProbeControllerLock;
  if BlockJoins then
  begin
    JoinEntered.SetEvent;
    JoinRelease.WaitFor(5000);
  end;
  if StallJoins then
    State.SetRoom(ARoomJID, 'joining')
  else
    State.SetRoom(ARoomJID, 'joined');
  SignalChanged;
  Result := True;
end;

function TFakeBotHost.LeaveRoom(const ARoomJID: UTF8String): Boolean;
begin
  ProbeControllerLock;
  State.SetRoom(ARoomJID, 'left');
  SignalChanged;
  Result := True;
end;

procedure TFakeBotHost.Shutdown;
begin
  if Assigned(JoinRelease) then
    JoinRelease.SetEvent;
  if Assigned(ProducerThread) then
    ProducerThread.WaitFor;
  ProbeControllerLock;
  if Assigned(ShutdownRecorder) then
  begin
    ShutdownRecorder.Count := LockProbeCount;
    ShutdownRecorder.LockProbeSucceeded := LockProbeSucceeded;
  end;
end;

procedure TAppServerStateRecorder.Changed(ASender: TObject;
  AState: TNXBotProviderState; const ADetail: UTF8String);
begin
  Inc(Count);
end;

procedure TBotControlIQHarness.Send(const AXML: UTF8String;
  AReplayable: Boolean);
begin
  SentXML := AXML;
end;

function TBotControlIQHarness.Submit(AModule: TObject;
  AOperation: TNXXMPPModuleOperation): Boolean;
begin
  Result := AModule = Module;
  if Result then
    Module.ProcessCommand(AOperation);
  AOperation.Free;
end;

function TBotControlIQHarness.Request(
  const AOperation: TNXBotControlOperation;
  const AAuthorization: TNXBotAuthorization;
  ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
begin
  LastOperation := AOperation;
  Authorization := AAuthorization;
  AToken := 42;
  if DeferRequest then
    DeferredCompletion := ACompletion;
  if LoseTransportDuringRequest then
    Module.Lifecycle(xmlPermanentLoss);
  if not DeferRequest then
    ACompletion(AToken, IncomingResult);
  Result := not RejectRequest;
end;

procedure TBotControlIQHarness.CallerComplete(
  const AResult: TNXBotControlResult);
begin
  Inc(CompletionCount);
  OutboundResult := AResult;
end;

function TBotControlIQHarness.IQSubmit(AType: TNXXMPPIQType;
  const AToJID, AExpectedFrom, APayload: UTF8String;
  AHandler: TNXXMPPIQCompletionHandler; ATimeoutMS: Cardinal): Boolean;
var
  lStanza: TNXXMPPStanza;
begin
  LastOperation.Kind := bcokList;
  LastOperation.BotName := AToJID;
  LastOperation.RoomJID := APayload;
  lStanza := TNXXMPPStanza.Create('<iq type=''result'' id=''nx-1'' from=''' +
    AExpectedFrom + '''><bots xmlns=''' + cNXBotControlNamespace +
    ''' no-op=''false''><bot name=''NexusBot'' known=''true'' ' +
    'active=''false'' provider=''Codex'' ' +
    'model=''gpt-5.6-luna'' provider-state=''stopped'' ' +
    'xmpp=''disconnected''/></bots></iq>',
    ' xmlns=''jabber:client''');
  AHandler(lStanza, '');
  lStanza.Free;
  Result := True;
end;

procedure TestRouting(AContext: TNXTestContext);
var
  lPrompt: TNXBotPrompt;
  lReply: TNXXMPPReplyReference;
begin
  lReply.Present := False;
  lReply.ToJID := '';
  lReply.ID := '';
  AContext.AssertEquals(Integer(brdAccepted), Integer(TNXBotHostRouter.Admit(
    1, 'room@nexus.local', 'Luna', 'room@nexus.local/test1', 'm1',
    'groupchat', '@Luna hello', '@Luna hello', lReply, xmdcLive, True, 100,
    False, lPrompt)),
    'Exact leading mention should be accepted.');
  try
    AContext.AssertEquals('hello', string(lPrompt.Body),
      'Accepted prompt should exclude the mention.');
  finally
    lPrompt.Free;
  end;
  AContext.AssertEquals(Integer(brdAccepted),
    Integer(TNXBotHostRouter.Admit(2, 'room@nexus.local', 'Luna',
      'room@nexus.local/test1', 'm2', 'groupchat', '@luna hello',
      '@luna hello', lReply, xmdcLive, True, 100, False, lPrompt)),
    'Textual mention comparison should be case-insensitive.');
  try
    AContext.AssertEquals('hello', string(lPrompt.Body),
      'Case-insensitive mention should exclude the mention.');
  finally
    lPrompt.Free;
  end;
  AContext.AssertEquals(Integer(brdAccepted),
    Integer(TNXBotHostRouter.Admit(3, 'room@nexus.local', 'Luna',
      'room@nexus.local/test1', 'm3', 'groupchat',
      'Could LUNA, explain this?', 'Could LUNA, explain this?', lReply,
      xmdcLive, True, 100, False, lPrompt)),
    'Gajim nickname-comma addressing should work anywhere in the body.');
  try
    AContext.AssertEquals('Could explain this?', string(lPrompt.Body),
      'Gajim address token should be removed from the prompt.');
  finally
    lPrompt.Free;
  end;
  AContext.AssertEquals(Integer(brdNotAddressed),
    Integer(TNXBotHostRouter.Admit(4, 'room@nexus.local', 'Luna',
      'room@nexus.local/test1', 'm4', 'groupchat', '@Lunatic hello',
      '@Lunatic hello', lReply, xmdcLive, True, 100, False, lPrompt)),
    'Nickname prefix without a delimiter must fail.');
  AContext.AssertEquals(Integer(brdNotAddressed),
    Integer(TNXBotHostRouter.Admit(5, 'room@nexus.local', 'Luna',
      'room@nexus.local/test1', 'm5', 'groupchat',
      'OldLuna, explain this?', 'OldLuna, explain this?', lReply,
      xmdcLive, True, 100, False, lPrompt)),
    'Nickname-comma addressing must not match inside a larger name.');
  AContext.AssertEquals(Integer(brdNotAddressed),
    Integer(TNXBotHostRouter.Admit(6, 'room@nexus.local', 'Luna',
      'room@nexus.local/test1', 'm6', 'groupchat',
      'Ask Luna about this', 'Ask Luna about this', lReply, xmdcLive, True,
      100, False, lPrompt)),
    'A nickname without the addressing comma must not be accepted.');
  AContext.AssertEquals(Integer(brdSelf), Integer(TNXBotHostRouter.Admit(7,
    'room@nexus.local', 'Luna', 'room@nexus.local/Luna', 'm7', 'groupchat',
    '@Luna hello', '@Luna hello', lReply, xmdcLive, True, 100, False,
    lPrompt)),
    'Reflected self messages must be rejected.');
  AContext.AssertEquals(Integer(brdNotLive), Integer(TNXBotHostRouter.Admit(8,
    'room@nexus.local', 'Luna', 'room@nexus.local/test1', 'm8', 'groupchat',
    '@Luna hello', '@Luna hello', lReply, xmdcMUCHistory, True, 100,
    False, lPrompt)),
    'MUC history must not start a turn.');
  AContext.AssertEquals(Integer(brdEmpty), Integer(TNXBotHostRouter.Admit(9,
    'room@nexus.local', 'Luna', 'room@nexus.local/test1', 'm9', 'groupchat',
    '@Luna ', '@Luna ', lReply, xmdcLive, True, 100, False, lPrompt)),
    'An empty addressed prompt must be rejected.');
  AContext.AssertEquals(Integer(brdTooLarge), Integer(TNXBotHostRouter.Admit(10,
    'room@nexus.local', 'Luna', 'room@nexus.local/test1', 'm10', 'groupchat',
    '@Luna 12345', '@Luna 12345', lReply, xmdcLive, True, 4, False,
    lPrompt)),
    'Prompt limit must be measured before ownership transfer.');

  lReply.Present := True;
  lReply.ToJID := 'room@nexus.local/Luna';
  lReply.ID := 'reply1';
  AContext.AssertEquals(Integer(brdAccepted), Integer(TNXBotHostRouter.Admit(
    11, 'room@nexus.local', 'Luna', 'room@nexus.local/test1', 'm11',
    'groupchat', '> previous answer' + #10 + 'follow up', 'follow up',
    lReply, xmdcLive, True, 100, False, lPrompt)),
    'A reply to the bot occupant should be accepted.');
  try
    AContext.AssertEquals('follow up', string(lPrompt.Body),
      'Reply fallback text should be excluded from the prompt.');
  finally
    lPrompt.Free;
  end;
  lReply.ToJID := 'room@nexus.local/SomeoneElse';
  AContext.AssertEquals(Integer(brdNotAddressed),
    Integer(TNXBotHostRouter.Admit(12, 'room@nexus.local', 'Luna',
      'room@nexus.local/test1', 'm12', 'groupchat',
      '> previous answer' + #10 + 'follow up', 'follow up', lReply,
      xmdcLive, True, 100, False, lPrompt)),
    'A reply to another occupant must not address the bot.');

  lReply.Present := False;
  AContext.AssertEquals(Integer(brdAccepted),
    Integer(TNXBotHostRouter.Admit(13, 'room@nexus.local', 'Luna',
      'room@nexus.local/test1', 'm13', 'groupchat', 'continue',
      'continue', lReply, xmdcLive, True, 100, True, lPrompt)),
    'A shared conversation decision should admit an implied reply.');
  try
    AContext.AssertEquals('continue', string(lPrompt.Body),
      'An implied reply should preserve the displayed message body.');
  finally
    lPrompt.Free;
  end;
end;

procedure TestImpliedReplies(AContext: TNXTestContext);
const
  cRoom = 'room@nexus.local';
  cUser = 'room@nexus.local/test1';
var
  lReason: UTF8String;
  lReply: TNXXMPPReplyReference;
  lTarget: UTF8String;
  lTracker: TTestConversationTracker;
begin
  lReply.Present := False;
  lReply.ToJID := '';
  lReply.ID := '';
  lTracker := TTestConversationTracker.Create(1000);
  try
    lTracker.Tick := 100;
    lTracker.RegisterBot('Luna');
    lTracker.RegisterBot('OpenAIBot');

    lTracker.BeginAnswer(cRoom, 'Luna', cUser, 'test1@nexus.local',
      'First answer');
    lTarget := lTracker.Observe(cRoom, cRoom + '/Luna', '', 'b1',
      'groupchat', 'First answer', 'First answer', lReply, xmdcLive, True,
      lReason);
    AContext.AssertEquals('', string(lTarget),
      'A reflected bot answer must not itself be routed.');
    lTarget := lTracker.Observe(cRoom, cUser, 'test1@nexus.local', 'u1',
      'groupchat', 'yes, continue', 'yes, continue', lReply, xmdcLive, True,
      lReason);
    AContext.AssertEquals('Luna', string(lTarget),
      'The same participant should continue with the answering bot.');
    AContext.AssertTrue(lReason <> '',
      'An implied decision should provide an observable reason.');
    AContext.AssertEquals('Luna', string(lTracker.Observe(cRoom, cUser,
      'test1@nexus.local', 'u1', 'groupchat', 'yes, continue',
      'yes, continue', lReply, xmdcLive, True, lReason)),
      'Every bot copy of one stanza must receive the same decision.');

    AContext.AssertEquals('', string(lTracker.Observe(cRoom,
      cRoom + '/other', 'other@nexus.local', 'u2', 'groupchat', 'hello',
      'hello', lReply, xmdcLive, True, lReason)),
      'Another participant should not inherit the conversation.');
    AContext.AssertEquals('', string(lTracker.Observe(cRoom, cUser,
      'test1@nexus.local', 'u3', 'groupchat', 'continue', 'continue',
      lReply, xmdcLive, True, lReason)),
      'An intervening participant should clear the prior claim.');

    lTracker.BeginAnswer(cRoom, 'OpenAIBot', cUser,
      'test1@nexus.local', 'OpenAI answer');
    lTracker.Observe(cRoom, cRoom + '/OpenAIBot', '', 'b2', 'groupchat',
      'OpenAI answer', 'OpenAI answer', lReply, xmdcLive, True, lReason);
    AContext.AssertEquals('OpenAIBot', string(lTracker.Observe(cRoom,
      cUser, 'test1@nexus.local', 'u4', 'groupchat', 'why?', 'why?',
      lReply, xmdcLive, True, lReason)),
      'Only the most recent answering bot should own the continuation.');

    AContext.AssertEquals('', string(lTracker.Observe(cRoom, cUser,
      'test1@nexus.local', 'u5', 'groupchat', '@Luna new topic',
      '@Luna new topic', lReply, xmdcLive, True, lReason)),
      'An explicit address must bypass implied routing.');
    AContext.AssertEquals('', string(lTracker.Observe(cRoom, cUser,
      'test1@nexus.local', 'u6', 'groupchat', 'unaddressed',
      'unaddressed', lReply, xmdcLive, True, lReason)),
      'An explicit address should clear the previous bot claim.');

    lTracker.BeginAnswer(cRoom, 'Luna', cUser, 'test1@nexus.local',
      'Human address answer');
    lTracker.Observe(cRoom, cRoom + '/Luna', '', 'b-address', 'groupchat',
      'Human address answer', 'Human address answer', lReply, xmdcLive,
      True, lReason);
    AContext.AssertEquals('', string(lTracker.Observe(cRoom, cUser,
      'test1@nexus.local', 'u-address', 'groupchat', '@other hello',
      '@other hello', lReply, xmdcLive, True, lReason)),
      'Addressing any occupant must bypass an existing implied claim.');

    lTracker.BeginAnswer(cRoom, 'Luna', cUser, 'test1@nexus.local',
      'Expiring answer');
    lTracker.Observe(cRoom, cRoom + '/Luna', '', 'b3', 'groupchat',
      'Expiring answer', 'Expiring answer', lReply, xmdcLive, True,
      lReason);
    Inc(lTracker.Tick, 1000);
    AContext.AssertEquals('', string(lTracker.Observe(cRoom, cUser,
      'test1@nexus.local', 'u7', 'groupchat', 'too late', 'too late',
      lReply, xmdcLive, True, lReason)),
      'An expired claim must not route a message.');

    lTracker.BeginAnswer(cRoom, 'Luna', cUser, 'test1@nexus.local',
      'Delayed answer');
    lTracker.Observe(cRoom, cRoom + '/other', 'other@nexus.local', 'u8',
      'groupchat', 'interrupt', 'interrupt', lReply, xmdcLive, True,
      lReason);
    lTracker.Observe(cRoom, cRoom + '/Luna', '', 'b4', 'groupchat',
      'Delayed answer', 'Delayed answer', lReply, xmdcLive, True, lReason);
    AContext.AssertEquals('', string(lTracker.Observe(cRoom, cUser,
      'test1@nexus.local', 'u9', 'groupchat', 'continue', 'continue',
      lReply, xmdcLive, True, lReason)),
      'A message before answer reflection must invalidate the pending claim.');

    lTracker.BeginAnswer(cRoom, 'Luna', cUser, 'test1@nexus.local',
      'Identity answer');
    lTracker.Observe(cRoom, cRoom + '/Luna', '', 'b5', 'groupchat',
      'Identity answer', 'Identity answer', lReply, xmdcLive, True,
      lReason);
    AContext.AssertEquals('', string(lTracker.Observe(cRoom, cUser,
      'replacement@nexus.local', 'u10', 'groupchat', 'continue',
      'continue', lReply, xmdcLive, True, lReason)),
      'A reused occupant nickname must not inherit a verified claim.');

    lTracker.BeginAnswer(cRoom, 'Luna', cUser, 'test1@nexus.local',
      'Room cleanup answer');
    lTracker.Observe(cRoom, cRoom + '/Luna', '', 'b6', 'groupchat',
      'Room cleanup answer', 'Room cleanup answer', lReply, xmdcLive, True,
      lReason);
    lTracker.ClearBotRoom(cRoom, 'Luna');
    AContext.AssertEquals('', string(lTracker.Observe(cRoom, cUser,
      'test1@nexus.local', 'u11', 'groupchat', 'continue', 'continue',
      lReply, xmdcLive, True, lReason)),
      'Leaving a room must clear that bot''s claim.');
  finally
    lTracker.Free;
  end;
end;

procedure TestObservableState(AContext: TNXTestContext);
var
  lBefore: PtrUInt;
  lSnapshot: TNXBotHostSnapshot;
  lState: TNXBotHostState;
begin
  lState := TNXBotHostState.Create(2);
  try
    lBefore := lState.Revision;
    lState.SetIdentity('gpt-5.6-luna', 'Luna');
    lState.SetRoom('nexus-test@nexus.local', 'joined');
    lState.AddJournal('one');
    lState.AddJournal('two');
    lState.AddJournal('three');
    AContext.AssertTrue(lState.Revision <> lBefore,
      'Observable revision should change after state updates.');
    lSnapshot := lState.Snapshot;
    AContext.AssertEquals('gpt-5.6-luna', string(lSnapshot.Model),
      'Snapshot should copy compound state.');
    AContext.AssertTrue(Pos('one', string(lSnapshot.Journal)) = 0,
      'Bounded journal should evict the oldest entry.');
    AContext.AssertTrue((Pos('two', string(lSnapshot.Journal)) > 0) and
      (Pos('three', string(lSnapshot.Journal)) > 0),
      'Snapshot should retain the two newest diagnostics.');
  finally
    lState.Free;
  end;
end;

procedure TestTypedProtocol(AContext: TNXTestContext);
const
  cUnicodeText: UTF8String = '— “quoted” café 中文 😀';
var
  lAgent: TNXCodexAgentMessageItem;
  lCommand: TNXCodexInitializeCommand;
  lData: TJSONData;
  lMessage: TNXJSONRPCMessage;
  lToolRequest: TNXCodexDynamicToolCallRequest;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"method":"item/completed","params":{"threadId":"t",' +
    '"turnId":"u","item":{"type":"agentMessage","id":"i",' +
    '"text":"' + cUnicodeText + '","phase":"final_answer"}}}',
    jepHeaderless);
  try
    AContext.AssertTrue(lMessage is TNXCodexItemCompletedNotification,
      'Known notification should bind to its RTTI message class.');
    lAgent := TNXCodexAgentMessageItem(
      TNXCodexItemCompletedNotification(lMessage).params.item.Value);
    AContext.AssertTrue(lAgent.text.Value = cUnicodeText,
      'Typed JSON text must preserve UTF-8 exactly.');
  finally
    lMessage.Free;
  end;

  lMessage := TNXJSONRPC.ParseMessage(
    '{"id":2,"method":"item/tool/call","params":{"threadId":"t",' +
    '"turnId":"u","callId":"c","namespace":null,"tool":"bot_control",' +
    '"arguments":{"operation":"status","bot":"NexusBot",' +
    '"room":"room@conference.nexus.local"}}}',
    jepHeaderless);
  try
    AContext.AssertTrue(lMessage is TNXCodexDynamicToolCallRequest,
      'Dynamic tool request should bind before it is declined.');
    lToolRequest := TNXCodexDynamicToolCallRequest(lMessage);
    AContext.AssertTrue(lToolRequest.params.arguments.Value is
      TNXCodexBotControlArguments,
      'bot_control arguments should bind to their RTTI contract.');
    AContext.AssertEquals('NexusBot', string(TNXCodexBotControlArguments(
      lToolRequest.params.arguments.Value).bot.Value),
      'Typed bot_control arguments should preserve the bot name.');
    AContext.AssertEquals('room@conference.nexus.local',
      string(TNXCodexBotControlArguments(
      lToolRequest.params.arguments.Value).room.Value),
      'Typed bot_control arguments should preserve an explicit room.');
  finally
    lMessage.Free;
  end;

  lCommand := TNXCodexInitializeCommand.Create;
  try
    lCommand.id.IntegerValue := 7;
    lCommand.method.Value := lCommand.GetFactoryName;
    lCommand.params.clientInfo.name.Value := 'test';
    lData := lCommand.ToJSONData;
    try
      AContext.AssertTrue(TJSONObject(lData).Find('jsonrpc') = nil,
        'App Server outbound envelope should be headerless.');
      AContext.AssertTrue(TJSONObject(lData).Find('params') <> nil,
        'Published typed params should be serialized.');
    finally
      lData.Free;
    end;
  finally
    lCommand.Free;
  end;
end;

procedure TestControlContract(AContext: TNXTestContext);
var
  lOperation: TNXBotControlOperation;
  lResult: TNXBotControlResult;
begin
  lOperation := NXBotControlOperation(bcokInvite, 'Observer',
    'room@conference.nexus.local');
  AContext.AssertEquals('Observer', string(lOperation.BotName),
    'Typed control operation should retain the canonical bot name.');
  AContext.AssertEquals('invite',
    string(NXBotControlOperationName(lOperation.Kind)),
    'Operation name should be deterministic.');
  lResult := NXBotControlFailure(bceForbidden, 'denied');
  AContext.AssertEquals('forbidden', string(NXBotControlErrorName(
    lResult.Error)), 'Typed errors should retain their stable category.');
end;

procedure TestProviderRegistry(AContext: TNXTestContext);
var
  lProvider: TNXBotProvider;
  lRaised: Boolean;
begin
  AContext.AssertTrue(TNXBotProviderRegistry.Registered('Codex'),
    'The linked Codex provider should register itself.');
  AContext.AssertFalse(TNXBotProviderRegistry.Registered('codex'),
    'Provider names should remain case-sensitive.');
  lProvider := TNXBotProviderRegistry.CreateProvider('Codex');
  try
    AContext.AssertTrue(lProvider is TNXCodexAppServer,
      'Named provider creation should return the registered Codex class.');
  finally
    lProvider.Free;
  end;
  AContext.AssertTrue(TNXBotProviderRegistry.Registered('OpenAI'),
    'The linked OpenAI provider should register itself.');
  AContext.AssertFalse(TNXBotProviderRegistry.Registered('openai'),
    'OpenAI provider identity should remain case-sensitive.');
  lProvider := TNXBotProviderRegistry.CreateProvider('OpenAI');
  try
    AContext.AssertTrue(lProvider is TNXOpenAIProvider,
      'Named provider creation should return the registered OpenAI class.');
  finally
    lProvider.Free;
  end;

  lRaised := False;
  try
    TNXBotProviderRegistry.RegisterProvider(TNXCodexAppServer);
  except
    on E: ENXBotProviderRegistry do
      lRaised := True;
  end;
  AContext.AssertTrue(lRaised,
    'Duplicate provider registration should fail clearly.');

  lRaised := False;
  try
    TNXBotProviderRegistry.RegisterProvider(nil);
  except
    on E: ENXBotProviderRegistry do
      lRaised := True;
  end;
  AContext.AssertTrue(lRaised,
    'Nil provider registration should fail clearly.');

  lRaised := False;
  try
    TNXBotProviderRegistry.FindProvider('Missing');
  except
    on E: ENXBotProviderRegistry do
      lRaised := True;
  end;
  AContext.AssertTrue(lRaised,
    'Unknown provider lookup should fail clearly.');
end;

procedure AddOpenAITestBinding(AConfig: TNXBotControllerConfig);
var
  lBinding: TNXBotDeploymentBinding;
begin
  lBinding := TNXBotDeploymentBinding.Create;
  lBinding.BotName := 'OpenAIBot';
  lBinding.CAFile := 'ca.pem';
  lBinding.EndpointHost := '127.0.0.1';
  lBinding.EndpointPort := 5222;
  lBinding.Nick := 'OpenAIBot';
  lBinding.OpenAICAFile := 'public-ca.pem';
  lBinding.OpenAIAPIKey := 'secret-test-key';
  lBinding.Password := 'winston';
  lBinding.Resource := 'OpenAIBotHost';
  lBinding.XMPPJID := 'openai@nexus.local';
  AConfig.Bindings.Add(lBinding);
end;

procedure TestLaunchConfiguration(AContext: TNXTestContext);
var
  lBinding: TNXBotDeploymentBinding;
  lController: TNXBotControllerConfig;
  lControllerFile: string;
  lHost: TNXBotHostConfig;
  lLaunch: TNXBotHostLaunchConfig;
  lLaunchFile: string;
begin
  lLaunchFile := ExpandFileName('test-config' + PathDelim +
    'NexusBotHostLaunch.json');
  lLaunch := TNXBotHostLaunchConfig.Create;
  try
    lLaunch.JSON := '{"AutoStart":true,"BotName":"Observer",' +
      '"ControllerFile":"config\\controller.json",' +
      '"RoomJID":"room@conference.nexus.local"}';
    lLaunch.Validate;
    lLaunch.ResolvePaths(lLaunchFile);
    lControllerFile := ExpandFileName(ExtractFileDir(lLaunchFile) +
      PathDelim + 'config' + PathDelim + 'controller.json');
    AContext.AssertEquals(lControllerFile, lLaunch.ControllerFile,
      'Relative controller paths must resolve from the launch file.');
    AContext.AssertTrue(lLaunch.AutoStart,
      'The typed launch configuration must retain autostart policy.');
  finally
    lLaunch.Free;
  end;

  lController := TNXBotControllerConfig.Create;
  lHost := TNXBotHostConfig.Create;
  try
    AContext.AssertEquals(120000, lController.ImpliedReplyTimeoutMS,
      'Implied room ownership should expire after two minutes by default.');
    lController.CatalogFile := '..' + PathDelim + 'catalog' + PathDelim +
      'Bots.nxscript';
    lBinding := TNXBotDeploymentBinding.Create;
    lBinding.BotName := 'NexusBot';
    lBinding.CAFile := 'certs' + PathDelim + 'server.crt';
    lBinding.CodexExecutable := 'bin' + PathDelim + 'codex.exe';
    lBinding.OpenAICAFile := 'certs' + PathDelim + 'public-ca.pem';
    lBinding.OpenAIAPIKey := 'test-api-key';
    lBinding.Password := 'winston';
    lBinding.RuntimeDirectory := 'runtime';
    lController.Bindings.Add(lBinding);
    lController.ResolvePaths(lControllerFile);
    AContext.AssertEquals(ExpandFileName(ExtractFileDir(lControllerFile) +
      PathDelim + 'certs' + PathDelim + 'server.crt'), lBinding.CAFile,
      'Relative deployment paths must resolve from the controller file.');
    AContext.AssertEquals(ExpandFileName(ExtractFileDir(lControllerFile) +
      PathDelim + 'certs' + PathDelim + 'public-ca.pem'),
      lBinding.OpenAICAFile,
      'Relative OpenAI CA paths must resolve from the controller file.');
    lHost.ApplyDeployment(lBinding);
    AContext.AssertEquals('winston', lHost.Password,
      'The host must receive the persisted XMPP credential directly.');
    AContext.AssertEquals('test-api-key', lHost.OpenAIAPIKey,
      'The host must receive the persisted provider credential directly.');
    AContext.AssertEquals(lBinding.OpenAICAFile, lHost.OpenAICAFile,
      'The host must receive the OpenAI trust bundle path.');
    AContext.AssertTrue(Pos('"Password" : "winston"',
      lController.JSON) > 0,
      'RTTI persistence must own the direct deployment credential contract.');
  finally
    lHost.Free;
    lController.Free;
  end;
end;

procedure TestHeadlessRuntime(AContext: TNXTestContext);
var
  lBinding: TNXBotDeploymentBinding;
  lController: TNXBotControllerConfig;
  lControllerFile: string;
  lLaunch: TNXBotHostLaunchConfig;
  lLaunchFile: string;
  lRecorder: TRuntimeActivityRecorder;
  lRuntime: TNXBotHostRuntime;
  lSnapshot: TNXBotHostSnapshot;
  lTempDirectory: string;
begin
  lTempDirectory := GetTempFileName(GetTempDir(False), 'nxbot');
  DeleteFile(lTempDirectory);
  if not CreateDir(lTempDirectory) then
    raise Exception.Create('Could not create the BotHost runtime test directory.');
  lControllerFile := lTempDirectory + PathDelim + 'controller.json';
  lLaunchFile := lTempDirectory + PathDelim + 'launch.json';
  lController := TNXBotControllerConfig.Create;
  lLaunch := TNXBotHostLaunchConfig.Create;
  lRecorder := TRuntimeActivityRecorder.Create;
  lRuntime := nil;
  try
    lController.CatalogFile := ExpandFileName('NexusTools' + PathDelim +
      'BotHost' + PathDelim + 'catalog' + PathDelim + 'Bots.nxscript');
    lBinding := TNXBotDeploymentBinding.Create;
    lBinding.BotName := 'NexusBot';
    lBinding.CAFile := 'ca.pem';
    lBinding.CodexExecutable := 'codex.exe';
    lBinding.EndpointHost := '127.0.0.1';
    lBinding.EndpointPort := 5222;
    lBinding.Nick := 'NexusBot';
    lBinding.Password := 'winston';
    lBinding.Resource := 'NexusBotHost';
    lBinding.RuntimeDirectory := 'runtime';
    lBinding.XMPPJID := 'test1@nexus.local';
    lController.Bindings.Add(lBinding);
    AddOpenAITestBinding(lController);
    lController.SaveToJSONFile(lControllerFile);

    lLaunch.AutoStart := False;
    lLaunch.BotName := 'NexusBot';
    lLaunch.ControllerFile := 'controller.json';
    lLaunch.RoomJID := 'room@conference.nexus.local';
    lLaunch.SaveToJSONFile(lLaunchFile);

    lRuntime := TNXBotHostRuntime.Create(lLaunchFile);
    lRuntime.OnActivity := @lRecorder.Activity;
    AContext.AssertTrue(Assigned(lRuntime.Controller) and
      Assigned(lRuntime.Host),
      'The headless runtime must compose the controller and selected host.');
    AContext.AssertEquals('room@conference.nexus.local',
      lRuntime.Host.Config.RoomJID,
      'The launch room must be applied to the selected host.');
    lRuntime.Start;
    lSnapshot := lRuntime.Host.State.Snapshot;
    AContext.AssertTrue(lSnapshot.ProviderState = bpsStopped,
      'AutoStart false must not start external provider or XMPP work.');
    lRuntime.Host.State.AddJournal('headless runtime activity');
    AContext.AssertTrue(Pos('headless runtime activity',
      string(lRecorder.Text)) > 0,
      'Journal activity must be delivered directly through the runtime event.');
    lRuntime.Shutdown;
  finally
    lRuntime.Free;
    lRecorder.Free;
    lLaunch.Free;
    lController.Free;
    DeleteFile(lLaunchFile);
    DeleteFile(lControllerFile);
    RemoveDir(lTempDirectory);
  end;
end;

procedure TestUnregisteredProviderCatalog(AContext: TNXTestContext);
var
  lBinding: TNXBotDeploymentBinding;
  lCatalog: TNXBotCatalog;
  lConfig: TNXBotControllerConfig;
  lFileName: string;
begin
  lCatalog := TNXBotCatalog.Create;
  lConfig := TNXBotControllerConfig.Create;
  try
    lBinding := TNXBotDeploymentBinding.Create;
    lBinding.BotName := 'Unregistered';
    lBinding.CAFile := 'ca.pem';
    lBinding.EndpointHost := '127.0.0.1';
    lBinding.EndpointPort := 5222;
    lBinding.Nick := 'Unregistered';
    lBinding.Password := 'winston';
    lBinding.Resource := 'Unregistered';
    lBinding.XMPPJID := 'unregistered@nexus.local';
    lConfig.Bindings.Add(lBinding);
    lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
      PathDelim + 'catalog' + PathDelim +
      'BotsUnregistered.Bot.nxscript');
    AContext.AssertFalse(lCatalog.Load(lFileName, lConfig),
      'A dialect-valid provider without a linked class must fail loading.');
    AContext.AssertEquals(0, lCatalog.Entries.Count,
      'An unregistered provider must not publish a catalog entry.');
    AContext.AssertTrue((Pos('Unregistered', lCatalog.Diagnostics.Text) > 0)
      and (Pos('not registered', lCatalog.Diagnostics.Text) > 0),
      'The catalog diagnostic should name the unregistered provider.');
  finally
    lConfig.Free;
    lCatalog.Free;
  end;
end;

procedure TestBotCatalog(AContext: TNXTestContext);
var
  lBinding: TNXBotDeploymentBinding;
  lDiagnostic: string;
  lDuplicate: TNXBotDeploymentBinding;
  lFreshCatalog: TNXBotCatalog;
  lFreshConfig: TNXBotControllerConfig;
  lCatalog: TNXBotCatalog;
  lConfig: TNXBotControllerConfig;
  lFileName: string;
  lLoadedConfig: TNXBotControllerConfig;
begin
  lConfig := TNXBotControllerConfig.Create;
  lCatalog := TNXBotCatalog.Create;
  try
    lBinding := TNXBotDeploymentBinding.Create;
    lBinding.BotName := 'NexusBot';
    lBinding.CAFile := 'ca.pem';
    lBinding.CodexExecutable := 'codex.exe';
    lBinding.EndpointHost := '127.0.0.1';
    lBinding.EndpointPort := 5222;
    lBinding.Nick := 'NexusBot';
    lBinding.Password := 'winston';
    lBinding.Resource := 'NexusBotHost';
    lBinding.RuntimeDirectory := 'runtime';
    lBinding.XMPPJID := 'test1@nexus.local';
    lConfig.Bindings.Add(lBinding);
    AddOpenAITestBinding(lConfig);
    lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
      PathDelim + 'catalog' + PathDelim + 'Bots.nxscript');
    AContext.AssertTrue(lCatalog.Load(lFileName, lConfig),
      'Bot catalog should compile and validate: ' + lCatalog.Diagnostics.Text);
    AContext.AssertEquals(2, lCatalog.Entries.Count,
      'The fixture should expose both bot definitions.');
    AContext.AssertEquals('gpt-5.6-luna',
      string(lCatalog.Entries[0].Model),
      'Catalog extraction should use the compiled effective value.');
    AContext.AssertTrue(Pos('winston', LowerCase(lConfig.JSON)) > 0,
      'Persisted deployment configuration must contain its password value.');
    AContext.AssertTrue(Pos('secret-test-key', lConfig.JSON) > 0,
      'Persisted deployment configuration must contain its API key value.');
    AContext.AssertTrue(Pos('OperationTimeoutMS', lConfig.JSON) = 0,
      'Controller configuration must not emit the removed deadline setting.');

    lBinding := TNXBotDeploymentBinding(lConfig.Bindings[1]);
    lBinding.OpenAIAPIKey := '';
    AContext.AssertFalse(lCatalog.Load(lFileName, lConfig),
      'A blank OpenAI API key must fail catalog loading.');
    AContext.AssertEquals(2, lCatalog.Entries.Count,
      'OpenAI deployment failure must preserve the published catalog.');
    AContext.AssertTrue(Pos('OpenAIAPIKey',
      lCatalog.Diagnostics.Text) > 0,
      'The OpenAI deployment diagnostic should name the missing field.');
    lBinding.OpenAIAPIKey := 'secret-test-key';

    lLoadedConfig := TNXBotControllerConfig.Create;
    try
      lLoadedConfig.JSON := '{"OperationTimeoutMS":1,' +
        '"OperationCapacity":7}';
      AContext.AssertEquals(7, lLoadedConfig.OperationCapacity,
        'Obsolete deadline data must not prevent remaining values loading.');
      AContext.AssertTrue(Pos('OperationTimeoutMS', lLoadedConfig.JSON) = 0,
        'Obsolete deadline data must be omitted when configuration is saved.');
    finally
      lLoadedConfig.Free;
    end;

    lBinding := TNXBotDeploymentBinding.Create;
    lBinding.BotName := 'Broken';
    lBinding.CAFile := 'ca.pem';
    lBinding.CodexExecutable := 'codex.exe';
    lBinding.Nick := 'Broken';
    lBinding.Password := 'winston';
    lBinding.Resource := 'Broken';
    lBinding.RuntimeDirectory := 'runtime';
    lBinding.XMPPJID := 'broken@nexus.local';
    lConfig.Bindings.Add(lBinding);
    lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
      PathDelim + 'catalog' + PathDelim + 'BotsInvalid.Bot.nxscript');
    AContext.AssertFalse(lCatalog.Load(lFileName, lConfig),
      'A catalog with one invalid definition must fail as a whole.');
    AContext.AssertEquals(2, lCatalog.Entries.Count,
      'A failed candidate must preserve the previously published catalog.');
    AContext.AssertTrue(lCatalog.Find('NexusBot') <> nil,
      'The previously published entry should remain after candidate failure.');
    AContext.AssertTrue(lCatalog.Find('Broken') = nil,
      'No definition from a failed candidate may be published.');
    AContext.AssertTrue(Pos('required', LowerCase(lCatalog.Diagnostics.Text)) > 0,
      'Dialect validation failure should retain a useful diagnostic.');

    lDuplicate := TNXBotDeploymentBinding.Create;
    lDuplicate.BotName := 'NexusBot';
    lDuplicate.CAFile := 'ca.pem';
    lDuplicate.CodexExecutable := 'codex.exe';
    lDuplicate.Nick := 'Duplicate';
    lDuplicate.Password := 'winston';
    lDuplicate.Resource := 'Duplicate';
    lDuplicate.RuntimeDirectory := 'runtime';
    lDuplicate.XMPPJID := 'duplicate@nexus.local';
    lConfig.Bindings.Add(lDuplicate);
    lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
      PathDelim + 'catalog' + PathDelim + 'Bots.nxscript');
    AContext.AssertFalse(lCatalog.Load(lFileName, lConfig),
      'Duplicate deployment bindings must fail the catalog.');
    AContext.AssertTrue(Pos('Multiple deployment bindings',
      lCatalog.Diagnostics.Text) > 0,
      'Duplicate deployment bindings should identify the catalog error.');
    AContext.AssertEquals(2, lCatalog.Entries.Count,
      'A binding failure must preserve the previously published catalog.');

    lFreshConfig := TNXBotControllerConfig.Create;
    lFreshCatalog := TNXBotCatalog.Create;
    try
      AContext.AssertFalse(lFreshCatalog.Load(lFileName, lFreshConfig),
        'A missing deployment binding must fail a fresh catalog.');
      AContext.AssertEquals(0, lFreshCatalog.Entries.Count,
        'A fresh catalog must remain empty after failure.');
      AContext.AssertTrue(Pos('Missing deployment binding for bot NexusBot',
        lFreshCatalog.Diagnostics.Text) > 0,
        'Missing binding diagnostics should name the affected bot.');

      lBinding := TNXBotDeploymentBinding.Create;
      lBinding.BotName := 'NexusBot';
      lFreshConfig.Bindings.Add(lBinding);
      AddOpenAITestBinding(lFreshConfig);
      AContext.AssertFalse(lFreshCatalog.Load(lFileName, lFreshConfig),
        'Incomplete deployment configuration must fail the catalog.');
      lDiagnostic := lFreshCatalog.Diagnostics.Text;
      AContext.AssertTrue((Pos('XMPPJID', lDiagnostic) > 0) and
        (Pos('RuntimeDirectory', lDiagnostic) > 0) and
        (Pos('CAFile', lDiagnostic) > 0),
        'Incomplete binding diagnostics should identify missing fields.');

      lBinding.CAFile := 'ca.pem';
      lBinding.CodexExecutable := 'codex.exe';
      lBinding.EndpointHost := '127.0.0.1';
      lBinding.EndpointPort := 0;
      lBinding.Nick := 'NexusBot';
      lBinding.Password := 'winston';
      lBinding.Resource := 'NexusBotHost';
      lBinding.RuntimeDirectory := 'runtime';
      lBinding.XMPPJID := 'bad@@nexus.local';
      AContext.AssertFalse(lFreshCatalog.Load(lFileName, lFreshConfig),
        'Malformed static deployment values must fail the catalog.');
      lDiagnostic := lFreshCatalog.Diagnostics.Text;
      AContext.AssertTrue((Pos('Invalid deployment field XMPPJID',
        lDiagnostic) > 0) and (Pos('requires both host and port',
        lDiagnostic) > 0),
        'Static deployment diagnostics should identify malformed values.');

      lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
        PathDelim + 'catalog' + PathDelim +
        'BotsUnsupportedProvider.Bot.nxscript');
      AContext.AssertFalse(lFreshCatalog.Load(lFileName, lFreshConfig),
        'Unsupported providers must fail dialect validation.');
      AContext.AssertTrue((Pos('NSV2306', lFreshCatalog.Diagnostics.Text) > 0)
        and (Pos('UnsupportedProvider', lFreshCatalog.Diagnostics.Text) > 0),
        'Unsupported provider diagnostics should come from the dialect.');

      lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
        PathDelim + 'catalog' + PathDelim +
        'BotsDuplicate.Bot.nxscript');
      AContext.AssertFalse(lFreshCatalog.Load(lFileName, lFreshConfig),
        'Duplicate bot names must fail catalog loading.');
      AContext.AssertTrue(lFreshCatalog.Diagnostics.Text <> '',
        'Duplicate bot names should retain a useful compiler diagnostic.');

      lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
        PathDelim + 'catalog' + PathDelim +
        'BotsMissingDoctype.Bot.nxscript');
      AContext.AssertFalse(lFreshCatalog.Load(lFileName, lFreshConfig),
        'A missing doctype must fail catalog loading.');
      AContext.AssertTrue(Pos('declare its language definition',
        lFreshCatalog.Diagnostics.Text) > 0,
        'A missing doctype should produce the catalog diagnostic.');

      lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
        PathDelim + 'catalog' + PathDelim + 'Missing.Bot.nxscript');
      AContext.AssertFalse(lFreshCatalog.Load(lFileName, lFreshConfig),
        'NexusScript compilation failure must fail catalog loading.');
      AContext.AssertTrue(lFreshCatalog.Diagnostics.Text <> '',
        'Compilation failure should retain a useful diagnostic.');

      lBinding.EndpointPort := 5222;
      lBinding.XMPPJID := 'test1@nexus.local';
      lFileName := ExpandFileName('NexusTools' + PathDelim + 'BotHost' +
        PathDelim + 'catalog' + PathDelim + 'Bots.nxscript');
      AContext.AssertTrue(lFreshCatalog.Load(lFileName, lFreshConfig),
        'A valid load should succeed after earlier candidate failures.');
      AContext.AssertEquals(0, lFreshCatalog.Diagnostics.Count,
        'Successful loading should clear diagnostics from the failed attempt.');
    finally
      lFreshCatalog.Free;
      lFreshConfig.Free;
    end;
  finally
    lCatalog.Free;
    lConfig.Free;
  end;
end;

procedure TestControlInterpreter(AContext: TNXTestContext);
var
  lOperation: TNXBotControlOperation;
  lPrompt: TNXBotPrompt;
begin
  lPrompt := TNXBotPrompt.Create(1, 'room@conference.nexus.local',
    'room@conference.nexus.local/test1', 'm1', 'LiSt RoStEr');
  try
    AContext.AssertEquals(
      'XMPP context: group message in room room@conference.nexus.local.' +
      LineEnding + LineEnding + 'LiSt RoStEr', string(lPrompt.ModelInput),
      'A room prompt must identify its room to the provider.');
    AContext.AssertTrue(TNXBotControlInterpreter.Parse(lPrompt, lOperation),
      'LIST should be recognized case-insensitively after routing.');
    AContext.AssertEquals(Integer(bcokList), Integer(lOperation.Kind),
      'LIST should create the typed list operation.');
  finally
    lPrompt.Free;
  end;
  lPrompt := TNXBotPrompt.Create(2, 'room@conference.nexus.local',
    'room@conference.nexus.local/test1', 'm2', 'invite Observer');
  try
    AContext.AssertTrue(TNXBotControlInterpreter.Parse(lPrompt, lOperation),
      'INVITE should be recognized after address routing.');
    AContext.AssertEquals('room@conference.nexus.local',
      string(lOperation.RoomJID),
      'Human room must come from the admitted prompt.');
  finally
    lPrompt.Free;
  end;
  lPrompt := TNXBotPrompt.Create(3, 'room@conference.nexus.local',
    'room@conference.nexus.local/test1', 'm3', 'please invite Observer');
  try
    AContext.AssertTrue(not TNXBotControlInterpreter.Parse(lPrompt,
      lOperation), 'Semantic prose must not be parsed as a deterministic command.');
  finally
    lPrompt.Free;
  end;
  lPrompt := TNXBotPrompt.Create(4, '', 'operator@nexus.local/desktop',
    'm4', 'invite Observer other@conference.nexus.local');
  lPrompt.SetDirectResponse('origin-4');
  try
    AContext.AssertEquals(
      'XMPP context: direct message with no originating room.' + LineEnding +
      LineEnding + 'invite Observer other@conference.nexus.local',
      string(lPrompt.ModelInput),
      'A global direct message must explicitly have no room context.');
    AContext.AssertTrue(TNXBotControlInterpreter.Parse(lPrompt, lOperation),
      'A global DM should accept an explicit room for INVITE.');
    AContext.AssertEquals('other@conference.nexus.local',
      string(lOperation.RoomJID),
      'The explicit DM room must become the operation target.');
    AContext.AssertEquals(Integer(bpdDirect), Integer(lPrompt.Delivery),
      'The prompt must retain direct-response routing.');
    AContext.AssertEquals('origin-4', string(lPrompt.ReplyID),
      'A direct prompt must retain the incoming reply identifier.');
  finally
    lPrompt.Free;
  end;
  lPrompt := TNXBotPrompt.Create(5, '', 'operator@nexus.local/desktop',
    'm5', 'dismiss Observer');
  lPrompt.SetDirectResponse('origin-5');
  try
    AContext.AssertTrue(TNXBotControlInterpreter.Parse(lPrompt, lOperation),
      'A room command without context should still produce a typed request.');
    AContext.AssertEquals('', string(lOperation.RoomJID),
      'A global DM must not invent a room context.');
  finally
    lPrompt.Free;
  end;
  lPrompt := TNXBotPrompt.Create(6, 'room@conference.nexus.local',
    'room@conference.nexus.local/operator', 'm6', 'what room?');
  lPrompt.SetDirectResponse('origin-6');
  try
    AContext.AssertEquals(
      'XMPP context: private message from room ' +
      'room@conference.nexus.local.' + LineEnding + LineEnding + 'what room?',
      string(lPrompt.ModelInput),
      'A MUC private message must identify its originating room.');
  finally
    lPrompt.Free;
  end;
end;

function CreateTestController(out AHost: TFakeBotHost): TNXBotController;
var
  lBinding: TNXBotDeploymentBinding;
  lCatalog: TNXBotCatalog;
  lConfig: TNXBotControllerConfig;
  lHostConfig: TNXBotHostConfig;
begin
  lCatalog := TNXBotCatalog.Create;
  lConfig := TNXBotControllerConfig.Create;
  try
    lBinding := TNXBotDeploymentBinding.Create;
    lBinding.BotName := 'NexusBot';
    lBinding.CAFile := 'ca.pem';
    lBinding.CodexExecutable := 'codex.exe';
    lBinding.Nick := 'NexusBot';
    lBinding.Password := 'winston';
    lBinding.Resource := 'test';
    lBinding.RuntimeDirectory := 'runtime';
    lBinding.XMPPJID := 'bot@nexus.local';
    lConfig.Bindings.Add(lBinding);
    AddOpenAITestBinding(lConfig);
    lConfig.Operators.Add('operator@nexus.local');
    lConfig.Readers.Add('reader@nexus.local');
    if not lCatalog.Load(ExpandFileName('NexusTools' + PathDelim +
      'BotHost' + PathDelim + 'catalog' + PathDelim + 'Bots.nxscript'),
      lConfig) then
      raise Exception.Create(lCatalog.Diagnostics.Text);
    Result := TNXBotController.Create(lCatalog, lConfig);
    lCatalog := nil;
    lHostConfig := TNXBotHostConfig.Create;
    lHostConfig.RoomJID := 'room@conference.nexus.local';
    AHost := TFakeBotHost.Create(lHostConfig, 'test');
    if not Result.AdoptHost('NexusBot', AHost) then
      raise Exception.Create('Could not adopt fake test host.');
  finally
    lConfig.Free;
    lCatalog.Free;
  end;
end;

procedure TestRoomLocalAuthorization(AContext: TNXTestContext);
var
  lAuthorization: TNXBotAuthorization;
  lController: TNXBotController;
  lHost: TFakeBotHost;
  lOperation: TNXBotControlOperation;
  lRecorder: TControlRecorder;
  lToken: QWord;
begin
  lRecorder := TControlRecorder.Create;
  lController := CreateTestController(lHost);
  try
    lAuthorization := NXBotAuthorization(bcoHumanMUC, '',
      'room@conference.nexus.local', True);
    lOperation := NXBotControlOperation(bcokDismiss, 'OpenAIBot',
      'room@conference.nexus.local');
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken),
      'A verified room occupant should submit a room-local DISMISS.');
    AContext.AssertTrue((lRecorder.ResultValue.Error = bceNone) and
      lRecorder.ResultValue.NoOp,
      'A room-local command must not require a disclosed real JID.');

    lOperation.RoomJID := 'other@conference.nexus.local';
    lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken);
    AContext.AssertEquals(Integer(bceForbidden),
      Integer(lRecorder.ResultValue.Error),
      'Anonymous room authority must not cross room boundaries.');

    lAuthorization.VerifiedMUCIdentity := False;
    lOperation.RoomJID := 'room@conference.nexus.local';
    lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken);
    AContext.AssertEquals(Integer(bceForbidden),
      Integer(lRecorder.ResultValue.Error),
      'An unverified sender must not receive room-local authority.');

    lAuthorization := NXBotAuthorization(bcoModelTool, '',
      'room@conference.nexus.local', True);
    lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken);
    AContext.AssertEquals(Integer(bceNone),
      Integer(lRecorder.ResultValue.Error),
      'A model tool should receive the same room-local authority.');

    lOperation := NXBotControlOperation(bcokList, '', '');
    lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken);
    AContext.AssertEquals(Integer(bceForbidden),
      Integer(lRecorder.ResultValue.Error),
      'Room occupancy alone must not grant global LIST authority.');

    lAuthorization := NXBotAuthorization(bcoHumanDM,
      'reader@nexus.local', '', False);
    lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken);
    AContext.AssertEquals(Integer(bceNone),
      Integer(lRecorder.ResultValue.Error),
      'An allowlisted reader should retain read access through a global DM.');

    lAuthorization := NXBotAuthorization(bcoHumanDM,
      'operator@nexus.local', '', False);
    lOperation := NXBotControlOperation(bcokDismiss, 'OpenAIBot', '');
    lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken);
    AContext.AssertEquals(Integer(bceBadRequest),
      Integer(lRecorder.ResultValue.Error),
      'A global DM room operation must specify its target room.');
  finally
    lController.Free;
    lRecorder.Free;
  end;
end;

procedure TestController(AContext: TNXTestContext);
var
  lAuthorization: TNXBotAuthorization;
  lController: TNXBotController;
  lCompletionProbe: TControllerLockProbe;
  lHost: TFakeBotHost;
  lHostProbe: TControllerLockProbe;
  lShutdownRecorder: TFakeHostShutdownRecorder;
  lOperation: TNXBotControlOperation;
  lRecorder: TControlRecorder;
  lPendingToken: QWord;
  lToken: QWord;
begin
  lRecorder := TControlRecorder.Create;
  lCompletionProbe := TControllerLockProbe.Create;
  lHostProbe := TControllerLockProbe.Create;
  lShutdownRecorder := TFakeHostShutdownRecorder.Create;
  lController := CreateTestController(lHost);
  try
    AContext.AssertTrue(Assigned(lHost.Conversation),
      'Every controller-managed host must share conversation routing state.');
    lHost.ShutdownRecorder := lShutdownRecorder;
    lRecorder.Controller := lController;
    lRecorder.LockProbe := lCompletionProbe;
    lAuthorization := NXBotAuthorization(bcoRemoteIQ,
      'reader@nexus.local/resource', '', True);
    lOperation := NXBotControlOperation(bcokList, '', '');
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken), 'Controller should accept LIST.');
    AContext.AssertEquals(1, lRecorder.Count,
      'LIST should complete exactly once.');
    AContext.AssertEquals(Integer(bceNone),
      Integer(lRecorder.ResultValue.Error), 'Authorized LIST should succeed.');
    AContext.AssertTrue(lRecorder.LockProbeSucceeded,
      'Immediate completion must run without the controller lock held.');
    lCompletionProbe.Finish;
    lRecorder.Controller := nil;
    lRecorder.LockProbe := nil;

    lAuthorization := NXBotAuthorization(bcoHumanMUC,
      'reader@nexus.local/resource', 'reader@nexus.local', True);
    lOperation := NXBotControlOperation(bcokStatus, 'nexusbot', '');
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken),
      'Natural-language bot names should resolve case-insensitively.');
    AContext.AssertEquals(Integer(bceNone),
      Integer(lRecorder.ResultValue.Error),
      'The uniquely matched human bot name should resolve.');
    AContext.AssertEquals('NexusBot',
      string(lRecorder.ResultValue.Bots[0].Name),
      'Human name resolution should return the canonical catalog identity.');

    lAuthorization := NXBotAuthorization(bcoRemoteIQ,
      'reader@nexus.local/resource', '', True);
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken),
      'An exact-identity IQ miss should still receive a typed completion.');
    AContext.AssertEquals(Integer(bceNotFound),
      Integer(lRecorder.ResultValue.Error),
      'Remote IQ bot identity must remain case-sensitive.');

    lOperation := NXBotControlOperation(bcokInvite, 'NexusBot',
      'room@conference.nexus.local');
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken), 'Denied INVITE should still complete.');
    AContext.AssertEquals(Integer(bceForbidden),
      Integer(lRecorder.ResultValue.Error),
      'A reader must not be permitted to invite a bot.');

    lAuthorization := NXBotAuthorization(bcoRemoteIQ,
      'operator@nexus.local/desktop', '', True);
    lHost.Controller := lController;
    lHost.LockProbe := lHostProbe;
    lHost.LockProbeOnLifecycle := True;
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken), 'Controller should accept INVITE.');
    AContext.AssertTrue(lHost.LockProbeSucceeded,
      'Host lifecycle methods must run without the controller lock held.');
    AContext.AssertEquals(3, lHost.LockProbeCount,
      'INVITE should probe start, connect, and join outside the lock.');
    lHostProbe.Finish;
    AContext.AssertEquals(Integer(bceNone),
      Integer(lRecorder.ResultValue.Error), 'Operator INVITE should succeed.');
    AContext.AssertEquals('joined',
      string(lRecorder.ResultValue.Bots[0].Rooms[0].State),
      'INVITE should complete only after the room is joined.');
    AContext.AssertEquals('fake',
      string(lRecorder.ResultValue.Bots[0].Diagnostic),
      'Runtime App Server detail should remain in bot status.');
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken), 'Idempotent INVITE should be accepted.');
    AContext.AssertTrue(lRecorder.ResultValue.NoOp,
      'A repeated INVITE should be a successful no-op.');

    lOperation := NXBotControlOperation(bcokDismiss, 'NexusBot',
      'room@conference.nexus.local');
    lHost.LockProbeCount := 0;
    lHost.LockProbeSucceeded := False;
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken), 'Controller should accept DISMISS.');
    AContext.AssertTrue(lHost.LockProbeSucceeded,
      'Room leave must run without the controller lock held.');
    AContext.AssertEquals(1, lHost.LockProbeCount,
      'DISMISS should probe one leave outside the lock.');
    AContext.AssertEquals(Integer(bceNone),
      Integer(lRecorder.ResultValue.Error), 'DISMISS should succeed.');
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken), 'Repeated DISMISS should be accepted.');
    AContext.AssertTrue(lRecorder.ResultValue.NoOp,
      'A repeated DISMISS should be a successful no-op.');
    AContext.AssertEquals(8, lRecorder.Count,
      'Every submitted operation should complete exactly once.');

    lController.SetOperationCapacity(1);
    lHost.StallJoins := True;
    lOperation := NXBotControlOperation(bcokInvite, 'NexusBot',
      'second@conference.nexus.local');
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lPendingToken),
      'A stalled INVITE should remain pending.');
    AContext.AssertEquals(8, lRecorder.Count,
      'A pending INVITE must not complete before joined state.');
    lOperation.RoomJID := 'third@conference.nexus.local';
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lToken),
      'Capacity failure should be returned as a typed completion.');
    AContext.AssertEquals(Integer(bceCapacity),
      Integer(lRecorder.ResultValue.Error),
      'A second pending operation should hit configured capacity.');
    AContext.AssertTrue(lController.Cancel(lPendingToken, 'transport lost'),
      'The controller should own cancellation by operation token.');
    AContext.AssertEquals(Integer(bceCancelled),
      Integer(lRecorder.ResultValue.Error),
      'Cancellation should complete with the typed cancelled result.');
    AContext.AssertEquals(10, lRecorder.Count,
      'Capacity and cancellation should each complete exactly once.');

    lOperation.RoomJID := 'shutdown@conference.nexus.local';
    AContext.AssertTrue(lController.Execute(lOperation, lAuthorization,
      @lRecorder.Complete, lPendingToken),
      'A stalled operation should be accepted for shutdown testing.');
    lHost.LockProbeCount := 0;
    lHost.LockProbeSucceeded := False;
    lController.Shutdown;
    lHost := nil;
    AContext.AssertTrue(lShutdownRecorder.LockProbeSucceeded,
      'Host shutdown must run without the controller lock held.');
    AContext.AssertEquals(2, lShutdownRecorder.Count,
      'Controller shutdown and host destruction should both run outside ' +
      'the lock.');
    AContext.AssertEquals(Integer(bceCancelled),
      Integer(lRecorder.ResultValue.Error),
      'Shutdown should cancel pending controller work.');
    AContext.AssertEquals(11, lRecorder.Count,
      'Shutdown cancellation should complete exactly once.');
  finally
    lCompletionProbe.Finish;
    lHostProbe.Finish;
    if Assigned(lHost) then
      lHost.LockProbe := nil;
    lController.Free;
    lShutdownRecorder.Free;
    lHostProbe.Free;
    lCompletionProbe.Free;
    lRecorder.Free;
  end;
end;

procedure TestShutdownOwnership(AContext: TNXTestContext);
var
  lAuthorization: TNXBotAuthorization;
  lController: TNXBotController;
  lHost: TFakeBotHost;
  lJoinEntered: TEvent;
  lJoinRelease: TEvent;
  lOperation: TNXBotControlOperation;
  lRecorder: TControlRecorder;
  lThread: TControllerExecuteThread;
begin
  lRecorder := TControlRecorder.Create;
  lJoinEntered := TEvent.Create(nil, True, False, '');
  lJoinRelease := TEvent.Create(nil, True, False, '');
  lThread := nil;
  lController := CreateTestController(lHost);
  try
    lHost.State.SetProvider(bpsReady, 'fake');
    lHost.State.SetXMPP('online');
    lHost.BlockJoins := True;
    lHost.StallJoins := True;
    lHost.JoinEntered := lJoinEntered;
    lHost.JoinRelease := lJoinRelease;
    lAuthorization := NXBotAuthorization(bcoRemoteIQ,
      'operator@nexus.local/resource', '', True);
    lOperation := NXBotControlOperation(bcokInvite, 'NexusBot',
      'shutdown@conference.nexus.local');
    lThread := TControllerExecuteThread.Create(lController, lOperation,
      lAuthorization, @lRecorder.Complete);
    lHost.ProducerThread := lThread;
    lThread.Start;
    AContext.AssertTrue(lJoinEntered.WaitFor(1000) = wrSignaled,
      'The producer should claim the pending room operation.');

    lController.Shutdown;
    lHost := nil;
    AContext.AssertTrue(lThread.Accepted,
      'The claimed controller operation should return during host quiescence.');
    AContext.AssertEquals(1, lRecorder.Count,
      'Shutdown should cancel the claimed operation exactly once.');
    AContext.AssertEquals(Integer(bceCancelled),
      Integer(lRecorder.ResultValue.Error),
      'The operation retained after producer quiescence should be cancelled.');
  finally
    lJoinRelease.SetEvent;
    lController.Free;
    lThread.Free;
    lJoinRelease.Free;
    lJoinEntered.Free;
    lRecorder.Free;
  end;
end;

procedure TestAppServerShutdown(AContext: TNXTestContext);
var
  lCallbackCount: Integer;
  lRecorder: TAppServerStateRecorder;
  lServer: TNXCodexAppServer;
begin
  lRecorder := TAppServerStateRecorder.Create;
  lServer := TNXCodexAppServer.Create;
  try
    lServer.OnState := @lRecorder.Changed;
    lServer.Shutdown;
    lCallbackCount := lRecorder.Count;
    AContext.AssertEquals(Integer(bpsStopped), Integer(lServer.State),
      'Final App Server shutdown should leave stopped state.');
    AContext.AssertFalse(lServer.StartServer('codex.exe', 'runtime',
      'model', 'instructions'),
      'Final App Server shutdown should reject later work.');
    lServer.Shutdown;
    Sleep(25);
    AContext.AssertEquals(lCallbackCount, lRecorder.Count,
      'No App Server callback should occur after final shutdown returns.');
  finally
    lServer.Free;
    lRecorder.Free;
  end;
end;

procedure TestAppServerProcess(AContext: TNXTestContext);
const
  cExpectedAnswer: UTF8String = 'fake — “quoted” café 中文 😀' + #10 +
    '[answer truncated]';
var
  lAnswer: UTF8String;
  lAppServer: TNXCodexAppServer;
  lDeadline: QWord;
  lExecutable: string;
  lPrompt: TNXBotPrompt;
  lRecorder: TAppServerProcessRecorder;
begin
  lExecutable := GetEnvironmentVariable('NEXUS_BOTHOST_FAKE_APP_SERVER');
  if lExecutable = '' then
    AContext.Skip('Set NEXUS_BOTHOST_FAKE_APP_SERVER to the compiled fake ' +
      'App Server fixture.');
  AContext.AssertTrue(FileExists(lExecutable),
    'The configured fake App Server executable does not exist.');
  lRecorder := TAppServerProcessRecorder.Create;
  lAppServer := TNXCodexAppServer.Create;
  try
    lAppServer.AnswerMaximumBytes := 58;
    lAppServer.OnFinalAnswer := @lRecorder.FinalAnswer;
    lAppServer.OnBotControl := @lRecorder.BotControl;
    lAppServer.OnDiagnostic := @lRecorder.Diagnostic;
    lAppServer.OnState := @lRecorder.StateChanged;
    AContext.AssertTrue(lAppServer.StartServer(lExecutable, GetCurrentDir,
      'gpt-5.6-luna', 'Test bot instructions.'),
      'Could not enqueue App Server start.');
    lDeadline := GetTickCount64 + 5000;
    while not lRecorder.Ready and not lRecorder.Failed and
      (GetTickCount64 < lDeadline) do
      Sleep(5);
    AContext.AssertTrue(lRecorder.Ready,
      'Fake App Server did not become ready.');
    lPrompt := TNXBotPrompt.Create(1, 'room@nexus.local',
      'room@nexus.local/test1', 'm1', 'hello');
    lPrompt.SetVerifiedCaller('test1@nexus.local', True);
    AContext.AssertTrue(lAppServer.SubmitPrompt(lPrompt),
      'Could not submit prompt.');
    lDeadline := GetTickCount64 + 5000;
    while (lRecorder.Answer(lAnswer) = 0) and
      (GetTickCount64 < lDeadline) do
      Sleep(5);
    AContext.AssertEquals(1, lRecorder.Answer(lAnswer),
      'Final answer event was not raised.');
    AContext.AssertEquals(string(cExpectedAnswer), string(lAnswer),
      'UTF-8 answer was corrupted or not bounded at a character boundary.');
    AContext.AssertTrue(lRecorder.DiagnosticCount >= 3,
      'Stderr, unknown notification, or authority decline was not reported.');
    AContext.AssertEquals(1, lRecorder.ControlCount,
      'Typed bot_control request did not execute exactly once.');
    AContext.AssertTrue(lAppServer.StopServer,
      'Could not enqueue App Server stop.');
  finally
    lAppServer.Free;
    lRecorder.Free;
  end;
end;

procedure TestBotControlIQ(AContext: TNXTestContext);
var
  lDispatcher: TNXXMPPDispatcher;
  lFeatures: TStringList;
  lHarness: TBotControlIQHarness;
  lOperation: TNXBotControlOperation;
  lStanza: TNXXMPPStanza;
begin
  lHarness := TBotControlIQHarness.Create;
  lDispatcher := TNXXMPPDispatcher.Create;
  lFeatures := TStringList.Create;
  try
    lHarness.CompleteCancellationImmediately := True;
    lHarness.Module := TNXXMPPBotControlModule.Create;
    lHarness.Module.Sender := @lHarness.Send;
    lHarness.Module.Submitter := @lHarness.Submit;
    lHarness.Module.IQSubmitter := @lHarness.IQSubmit;
    lHarness.Module.OnCancel := @lHarness.Cancel;
    lHarness.Module.OnRequest := @lHarness.Request;
    lHarness.IncomingResult.Error := bceNone;
    lHarness.IncomingResult.NoOp := False;
    SetLength(lHarness.IncomingResult.Bots, 1);
    lHarness.IncomingResult.Bots[0].Name := 'NexusBot';
    lHarness.IncomingResult.Bots[0].Known := True;
    lHarness.IncomingResult.Bots[0].Active := False;
    lHarness.IncomingResult.Bots[0].Provider := 'Codex';
    lHarness.IncomingResult.Bots[0].Model := 'gpt-5.6-luna';
    lHarness.IncomingResult.Bots[0].ProviderState := 'failed';
    lHarness.IncomingResult.Bots[0].XMPPState := 'disconnected';
    lHarness.IncomingResult.Bots[0].Diagnostic := 'runtime failure';
    lHarness.Module.RegisterHandlers(lDispatcher);
    lHarness.Module.AddFeatures(lFeatures);
    AContext.AssertTrue(lFeatures.IndexOf(cNXBotControlNamespace) >= 0,
      'The control namespace should be advertised through discovery.');

    lStanza := TNXXMPPStanza.Create(
      '<iq from=''reader@nexus.local/resource'' type=''get'' id=''q1''>' +
      '<bots xmlns=''' + cNXBotControlNamespace + '''/></iq>',
      ' xmlns=''jabber:client''');
    try
      AContext.AssertTrue(lDispatcher.DispatchStanza(lStanza),
        'The exact LIST QName should dispatch to the control module.');
    finally
      lStanza.Free;
    end;
    AContext.AssertEquals(Integer(bcokList),
      Integer(lHarness.LastOperation.Kind),
      'LIST IQ should produce the typed LIST operation.');
    AContext.AssertEquals('reader@nexus.local',
      string(lHarness.Authorization.CallerBareJID),
      'Remote authorization should use the verified bare sender JID.');
    AContext.AssertTrue(Pos('<iq type=''result'' id=''q1''',
      string(lHarness.SentXML)) = 1,
      'A successful controller result should produce one IQ result.');
    AContext.AssertTrue(Pos(' available=', string(lHarness.SentXML)) = 0,
      'Bot status IQ results must not serialize catalog availability.');
    AContext.AssertTrue(Pos('diagnostic=''runtime failure''',
      string(lHarness.SentXML)) > 0,
      'Bot status IQ results should preserve runtime diagnostic detail.');

    lStanza := TNXXMPPStanza.Create(
      '<iq from=''reader@nexus.local/resource'' type=''get'' id=''q2''>' +
      '<status xmlns=''' + cNXBotControlNamespace + '''/></iq>',
      ' xmlns=''jabber:client''');
    try
      lDispatcher.DispatchStanza(lStanza);
    finally
      lStanza.Free;
    end;
    AContext.AssertTrue(Pos('<bad-request ', string(lHarness.SentXML)) > 0,
      'Malformed STATUS should return modify/bad-request.');

    lHarness.IncomingResult := NXBotControlFailure(bceForbidden, 'denied');
    lStanza := TNXXMPPStanza.Create(
      '<iq from=''reader@nexus.local/resource'' type=''set'' id=''q3''>' +
      '<invite xmlns=''' + cNXBotControlNamespace +
      ''' bot=''NexusBot'' room=''room@conference.nexus.local''/></iq>',
      ' xmlns=''jabber:client''');
    try
      lDispatcher.DispatchStanza(lStanza);
    finally
      lStanza.Free;
    end;
    AContext.AssertTrue((Pos('<error type=''auth''>',
      string(lHarness.SentXML)) > 0) and
      (Pos('<forbidden ', string(lHarness.SentXML)) > 0),
      'Forbidden controller results should map to auth/forbidden.');

    lOperation := NXBotControlOperation(bcokList, '', '');
    AContext.AssertTrue(lHarness.Module.Call(
      'controller@nexus.local/NexusBotHost', lOperation,
      @lHarness.CallerComplete), 'Typed outbound LIST should be submitted.');
    AContext.AssertEquals(1, lHarness.CompletionCount,
      'Typed outbound IQ should complete exactly once.');
    AContext.AssertEquals(1, Length(lHarness.OutboundResult.Bots),
      'Typed outbound IQ should parse bot status results.');
    AContext.AssertFalse(lHarness.OutboundResult.Bots[0].Active,
      'Typed outbound IQ should parse runtime active state without availability.');

    lHarness.DeferRequest := True;
    lStanza := TNXXMPPStanza.Create(
      '<iq from=''reader@nexus.local/resource'' type=''get'' id=''q4''>' +
      '<bots xmlns=''' + cNXBotControlNamespace + '''/></iq>',
      ' xmlns=''jabber:client''');
    try
      AContext.AssertTrue(lDispatcher.DispatchStanza(lStanza),
        'A deferred LIST request should dispatch to the control module.');
    finally
      lStanza.Free;
    end;
    lHarness.CompleteCancellationImmediately := False;
    lHarness.Module.Lifecycle(xmlPermanentLoss);
    lHarness.Module.Lifecycle(xmlFinalDisconnect);
    AContext.AssertEquals(1, lHarness.CancelCount,
      'Transport loss and repeated final lifecycle notification should cancel ' +
      'one deferred controller operation exactly once.');
    lHarness.FinishDeferredCancellation('transport lost');

    lHarness.Module.Lifecycle(xmlNewSession);
    lHarness.CompleteCancellationImmediately := True;
    lHarness.LoseTransportDuringRequest := True;
    lStanza := TNXXMPPStanza.Create(
      '<iq from=''reader@nexus.local/resource'' type=''get'' id=''q5''>' +
      '<bots xmlns=''' + cNXBotControlNamespace + '''/></iq>',
      ' xmlns=''jabber:client''');
    try
      AContext.AssertTrue(lDispatcher.DispatchStanza(lStanza),
        'A request racing transport loss should still dispatch.');
    finally
      lStanza.Free;
    end;
    AContext.AssertEquals(2, lHarness.CancelCount,
      'Transport loss during token publication must cancel the accepted ' +
      'controller operation exactly once.');
    lHarness.Module.Lifecycle(xmlFinalDisconnect);
    AContext.AssertEquals(2, lHarness.CancelCount,
      'A repeated final lifecycle notification must not cancel it again.');

    lHarness.Module.Lifecycle(xmlNewSession);
    lHarness.LoseTransportDuringRequest := False;
    lHarness.RejectRequest := True;
    lStanza := TNXXMPPStanza.Create(
      '<iq from=''reader@nexus.local/resource'' type=''get'' id=''q6''>' +
      '<bots xmlns=''' + cNXBotControlNamespace + '''/></iq>',
      ' xmlns=''jabber:client''');
    try
      AContext.AssertTrue(lDispatcher.DispatchStanza(lStanza),
        'A controller-rejected request should still dispatch.');
    finally
      lStanza.Free;
    end;
    AContext.AssertTrue(Pos('<service-unavailable ',
      string(lHarness.SentXML)) > 0,
      'Controller rejection should return service-unavailable without ' +
      'retaining an IQ correlation record.');
    lHarness.Module.Lifecycle(xmlFinalDisconnect);
    AContext.AssertEquals(2, lHarness.CancelCount,
      'Rejected work must not be cancelled later during transport loss.');
  finally
    lHarness.Module.Free;
    lFeatures.Free;
    lDispatcher.Free;
    lHarness.Free;
  end;
end;

procedure RegisterNXBotHostTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusBotHost');
  lSuite.AddTest('Routing', @TestRouting);
  lSuite.AddTest('ImpliedReplies', @TestImpliedReplies);
  lSuite.AddTest('ObservableState', @TestObservableState);
  lSuite.AddTest('TypedProtocol', @TestTypedProtocol);
  lSuite.AddTest('ControlContract', @TestControlContract);
  lSuite.AddTest('ProviderRegistry', @TestProviderRegistry);
  lSuite.AddTest('LaunchConfiguration', @TestLaunchConfiguration);
  lSuite.AddTest('HeadlessRuntime', @TestHeadlessRuntime);
  lSuite.AddTest('UnregisteredProviderCatalog',
    @TestUnregisteredProviderCatalog);
  lSuite.AddTest('BotCatalog', @TestBotCatalog);
  lSuite.AddTest('ControlInterpreter', @TestControlInterpreter);
  lSuite.AddTest('RoomLocalAuthorization', @TestRoomLocalAuthorization);
  lSuite.AddTest('Controller', @TestController);
  lSuite.AddTest('ShutdownOwnership', @TestShutdownOwnership);
  lSuite.AddTest('AppServerShutdown', @TestAppServerShutdown);
  lSuite.AddTest('AppServerProcess', @TestAppServerProcess, 'integration');
  lSuite.AddTest('BotControlIQ', @TestBotControlIQ);
end;

end.
