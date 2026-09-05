program NexusBotHostTests;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  Classes,
  fpjson,
  SysUtils,
  obNXBotHostRouter,
  obNXBotHostState,
  obNXCodexAppServer,
  obNXCodexAppServerMessages,
  obNXJSONRPCMessages,
  tpNXBotHost,
  tpNXBotControl,
  tpNXXMPPMessageTypes;

type
  TRecorder = class
  private
    FAnswer: UTF8String;
    FCriticalSection: TRTLCriticalSection;
    FDiagnosticCount: Integer;
    FControlCount: Integer;
    FFailed: Boolean;
    FFinalCount: Integer;
    FReady: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure FinalAnswer(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    procedure Diagnostic(ASender: TObject; const AText: UTF8String);
    procedure StateChanged(ASender: TObject; AState: TNXCodexAppServerState;
      const ADetail: UTF8String);
    function BotControl(ASender: TObject;
      const AOperation: TNXBotControlOperation;
      const AAuthorization: TNXBotAuthorization;
      ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
    function Answer(out AText: UTF8String): Integer;
    function Ready: Boolean;
    function Failed: Boolean;
    function DiagnosticCount: Integer;
    function ControlCount: Integer;
  end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function TRecorder.BotControl(ASender: TObject;
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
  lResult.Bots[0].Available := True;
  lResult.Bots[0].Active := True;
  lResult.Bots[0].AppServerState := 'ready';
  lResult.Bots[0].XMPPState := 'online';
  ACompletion(AToken, lResult);
  Result := AAuthorization.VerifiedMUCIdentity;
end;

function TRecorder.ControlCount: Integer;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FControlCount;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

constructor TRecorder.Create;
begin
  inherited Create;
  InitCriticalSection(FCriticalSection);
end;

destructor TRecorder.Destroy;
begin
  DoneCriticalSection(FCriticalSection);
  inherited Destroy;
end;

procedure TRecorder.FinalAnswer(ASender: TObject; APrompt: TNXBotPrompt;
  const AText: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FAnswer := AText;
    Inc(FFinalCount);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TRecorder.Diagnostic(ASender: TObject; const AText: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    Inc(FDiagnosticCount);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TRecorder.StateChanged(ASender: TObject;
  AState: TNXCodexAppServerState; const ADetail: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FReady := AState = cassReady;
    if AState = cassFailed then
      FFailed := True;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TRecorder.Failed: Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FFailed;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TRecorder.DiagnosticCount: Integer;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FDiagnosticCount;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TRecorder.Answer(out AText: UTF8String): Integer;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FFinalCount;
    AText := FAnswer;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TRecorder.Ready: Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FReady;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TestRouter;
var
  lDecision: TNXBotRouteDecision;
  lPrompt: TNXBotPrompt;
  lReply: TNXXMPPReplyReference;
begin
  lReply.Present := False;
  lReply.ToJID := '';
  lReply.ID := '';
  lDecision := TNXBotHostRouter.Admit(1, 'room@nexus.local', 'Luna',
    'room@nexus.local/test1', 'm1', 'groupchat', '@Luna hello',
    '@Luna hello', lReply, xmdcLive, True, 100, lPrompt);
  Check(lDecision = brdAccepted, 'Exact mention was not accepted.');
  try
    Check(lPrompt.Body = 'hello', 'Mention prefix was not removed.');
  finally
    lPrompt.Free;
  end;
  lDecision := TNXBotHostRouter.Admit(2, 'room@nexus.local', 'Luna',
    'room@nexus.local/test1', 'm2', 'groupchat', '@luna hello', '@luna hello',
    lReply, xmdcLive, True, 100, lPrompt);
  Check(lDecision = brdAccepted,
    'Case-insensitive mention was not accepted.');
  try
    Check(lPrompt.Body = 'hello',
      'Case-insensitive mention prefix was not removed.');
  finally
    lPrompt.Free;
  end;
  lDecision := TNXBotHostRouter.Admit(3, 'room@nexus.local', 'Luna',
    'room@nexus.local/test1', 'm3', 'groupchat',
    'Could LUNA, explain this?', 'Could LUNA, explain this?', lReply,
    xmdcLive, True, 100, lPrompt);
  Check(lDecision = brdAccepted,
    'Nickname-comma address within the body was not accepted.');
  try
    Check(lPrompt.Body = 'Could explain this?',
      'Nickname-comma address was not removed.');
  finally
    lPrompt.Free;
  end;
  Check(TNXBotHostRouter.Admit(4, 'room@nexus.local', 'Luna',
    'room@nexus.local/test1', 'm4', 'groupchat', 'OldLuna, explain this?',
    'OldLuna, explain this?', lReply, xmdcLive, True, 100, lPrompt) =
    brdNotAddressed, 'Nickname matched inside a larger name.');
  Check(TNXBotHostRouter.Admit(5, 'room@nexus.local', 'Luna',
    'room@nexus.local/Luna', 'm3', 'groupchat', '@Luna hello', '@Luna hello',
    lReply, xmdcLive, True, 100, lPrompt) = brdSelf,
    'Self message was accepted.');
  Check(TNXBotHostRouter.Admit(6, 'room@nexus.local', 'Luna',
    'room@nexus.local/test1', 'm4', 'groupchat', '@Luna hello',
    '@Luna hello', lReply, xmdcMUCHistory, True, 100, lPrompt) = brdNotLive,
    'History message was accepted.');
  Check(TNXBotHostRouter.Admit(7, 'room@nexus.local', 'Luna',
    'room@nexus.local/test1', 'm5', 'groupchat', '@Luna ', '@Luna ', lReply,
    xmdcLive, True, 100, lPrompt) = brdEmpty,
    'Empty mention was accepted.');

  lReply.Present := True;
  lReply.ToJID := 'room@nexus.local/Luna';
  lReply.ID := 'reply1';
  Check(TNXBotHostRouter.Admit(8, 'room@nexus.local', 'Luna',
    'room@nexus.local/test1', 'm6', 'groupchat',
    '> previous answer' + #10 + 'follow up', 'follow up', lReply,
    xmdcLive, True, 100, lPrompt) = brdAccepted,
    'Reply to the bot occupant was not accepted.');
  try
    Check(lPrompt.Body = 'follow up',
      'Reply fallback text was not excluded from the prompt.');
  finally
    lPrompt.Free;
  end;
  lReply.ToJID := 'room@nexus.local/SomeoneElse';
  Check(TNXBotHostRouter.Admit(9, 'room@nexus.local', 'Luna',
    'room@nexus.local/test1', 'm7', 'groupchat',
    '> previous answer' + #10 + 'follow up', 'follow up', lReply,
    xmdcLive, True, 100, lPrompt) = brdNotAddressed,
    'Reply to another occupant addressed the bot.');
end;

procedure TestState;
var
  lSnapshot: TNXBotHostSnapshot;
  lState: TNXBotHostState;
begin
  lState := TNXBotHostState.Create(2);
  try
    lState.AddJournal('one');
    lState.AddJournal('two');
    lState.AddJournal('three');
    lSnapshot := lState.Snapshot;
    Check(Pos('one', string(lSnapshot.Journal)) = 0,
      'Journal did not evict its oldest entry.');
    Check((Pos('two', string(lSnapshot.Journal)) > 0) and
      (Pos('three', string(lSnapshot.Journal)) > 0),
      'Journal snapshot lost retained entries.');
  finally
    lState.Free;
  end;
end;

procedure TestTypedProtocol;
var
  lData: TJSONData;
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"method":"item/completed","params":{"threadId":"t",' +
    '"turnId":"u","item":{"type":"agentMessage","id":"i",' +
    '"text":"answer","phase":"final_answer"}}}', jepHeaderless);
  try
    Check(lMessage is TNXCodexItemCompletedNotification,
      'Completed item did not bind to its typed notification.');
  finally
    lMessage.Free;
  end;

  with TNXCodexInitializeCommand.Create do
  try
    id.IntegerValue := 7;
    method.Value := GetFactoryName;
    params.clientInfo.name.Value := 'test';
    lData := ToJSONData;
    try
      Check(TJSONObject(lData).Find('jsonrpc') = nil,
        'Headerless outbound object emitted jsonrpc.');
      Check(TJSONObject(lData).Find('params') <> nil,
        'Typed outbound object omitted params.');
    finally
      lData.Free;
    end;
  finally
    Free;
  end;
end;

procedure TestWorker(const AFakeExecutable: string);
const
  cExpectedAnswer: UTF8String = 'fake — “quoted” café 中文 😀' + #10 +
    '[answer truncated]';
var
  lAnswer: UTF8String;
  lAppServer: TNXCodexAppServer;
  lDeadline: QWord;
  lPrompt: TNXBotPrompt;
  lRecorder: TRecorder;
begin
  Check(FileExists(AFakeExecutable), 'Fake App Server executable not found.');
  lRecorder := TRecorder.Create;
  lAppServer := TNXCodexAppServer.Create;
  try
    lAppServer.AnswerMaximumBytes := 58;
    lAppServer.OnFinalAnswer := @lRecorder.FinalAnswer;
    lAppServer.OnBotControl := @lRecorder.BotControl;
    lAppServer.OnDiagnostic := @lRecorder.Diagnostic;
    lAppServer.OnState := @lRecorder.StateChanged;
    Check(lAppServer.StartServer(AFakeExecutable, GetCurrentDir,
      'gpt-5.6-luna', 'Test bot instructions.'),
      'Could not enqueue App Server start.');
    lDeadline := GetTickCount64 + 5000;
    while not lRecorder.Ready and (GetTickCount64 < lDeadline) do
      Sleep(5);
    Check(lRecorder.Ready, 'Fake App Server did not become ready.');
    lPrompt := TNXBotPrompt.Create(1, 'room@nexus.local',
      'room@nexus.local/test1', 'm1', 'hello');
    lPrompt.SetVerifiedCaller('test1@nexus.local', True);
    Check(lAppServer.SubmitPrompt(lPrompt), 'Could not submit prompt.');
    lDeadline := GetTickCount64 + 5000;
    while (lRecorder.Answer(lAnswer) = 0) and
      (GetTickCount64 < lDeadline) do
      Sleep(5);
    Check(lRecorder.Answer(lAnswer) = 1, 'Final answer event was not raised.');
    Check(lAnswer = cExpectedAnswer,
      'UTF-8 answer was corrupted or not bounded at a character boundary.');
    Check(lRecorder.DiagnosticCount >= 3,
      'Stderr, unknown notification, or authority decline was not reported.');
    Check(lRecorder.ControlCount = 1,
      'Typed bot_control request did not execute exactly once.');
    Check(lAppServer.StopServer, 'Could not enqueue App Server stop.');
  finally
    lAppServer.Free;
    lRecorder.Free;
  end;
end;

begin
  try
    TestRouter;
    TestState;
    TestTypedProtocol;
    if ParamCount > 0 then
      TestWorker(ParamStr(1));
    WriteLn('PASS NexusBotHostTests');
  except
    on E: Exception do
    begin
      WriteLn('FAIL ', E.Message);
      Halt(1);
    end;
  end;
end.
