unit tsNXOpenAIProviderTests;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  obNXTestRegistry;

procedure RegisterNXOpenAIProviderTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  fpjson,
  SyncObjs,
  SysUtils,
  Windows,
  obNXBotHostConfig,
  obNXOpenAIProvider,
  obNXOpenAIResponses,
  obNXTestContext,
  obNXTestSuite,
  tpNXBotHost;

type
  TFakeOpenAIExecutor = class(TNXOpenAIExecutor)
  public
    Block: Boolean;
    DelayMS: Cardinal;
    Bodies: TStringList;
    Calls: Integer;
    Entered: TEvent;
    Key: UTF8String;
    ReleaseCall: TEvent;
    Results: array[0..9] of TNXOpenAIHTTPResult;
    constructor Create;
    destructor Destroy; override;
    function Execute(const AAPIKey, ABody: UTF8String;
      ATimeoutMS: Cardinal; out AResult: TNXOpenAIHTTPResult): Boolean;
      override;
  end;

  TOpenAIRecorder = class
  public
    Answer: UTF8String;
    Failed: UTF8String;
    FinalCount: Integer;
    FailureCount: Integer;
    FinalEvent: TEvent;
    FailureEvent: TEvent;
    ReadyEvent: TEvent;
    StateDetail: UTF8String;
    StateValue: TNXBotProviderState;
    StoppingSeen: Boolean;
    ReadyAfterStopping: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure FinalAnswer(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    procedure PromptFailed(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    procedure StateChanged(ASender: TObject; AState: TNXBotProviderState;
      const ADetail: UTF8String);
  end;

constructor TFakeOpenAIExecutor.Create;
begin
  inherited Create;
  Bodies := TStringList.Create;
  Entered := TEvent.Create(nil, False, False, '');
  ReleaseCall := TEvent.Create(nil, False, False, '');
end;

destructor TFakeOpenAIExecutor.Destroy;
begin
  ReleaseCall.Free;
  Entered.Free;
  Bodies.Free;
  inherited Destroy;
end;

function TFakeOpenAIExecutor.Execute(const AAPIKey,
  ABody: UTF8String; ATimeoutMS: Cardinal;
  out AResult: TNXOpenAIHTTPResult): Boolean;
begin
  Key := AAPIKey;
  Bodies.Add(string(ABody));
  Inc(Calls);
  Entered.SetEvent;
  if DelayMS > 0 then
    Sleep(DelayMS)
  else if Block and (ReleaseCall.WaitFor(5000) <> wrSignaled) then
    raise Exception.Create('Fake OpenAI executor release timed out.');
  AResult := Results[Calls - 1];
  Result := AResult.ErrorText = '';
end;

constructor TOpenAIRecorder.Create;
begin
  inherited Create;
  FinalEvent := TEvent.Create(nil, False, False, '');
  FailureEvent := TEvent.Create(nil, False, False, '');
  ReadyEvent := TEvent.Create(nil, False, False, '');
end;

destructor TOpenAIRecorder.Destroy;
begin
  ReadyEvent.Free;
  FailureEvent.Free;
  FinalEvent.Free;
  inherited Destroy;
end;

procedure TOpenAIRecorder.FinalAnswer(ASender: TObject;
  APrompt: TNXBotPrompt; const AText: UTF8String);
begin
  Inc(FinalCount);
  Answer := AText;
  FinalEvent.SetEvent;
end;

procedure TOpenAIRecorder.PromptFailed(ASender: TObject;
  APrompt: TNXBotPrompt; const AText: UTF8String);
begin
  Inc(FailureCount);
  Failed := AText;
  FailureEvent.SetEvent;
end;

procedure TOpenAIRecorder.StateChanged(ASender: TObject;
  AState: TNXBotProviderState; const ADetail: UTF8String);
begin
  StateValue := AState;
  StateDetail := ADetail;
  if AState = bpsStopping then
    StoppingSeen := True
  else if StoppingSeen and (AState = bpsReady) then
    ReadyAfterStopping := True;
  if AState = bpsReady then
    ReadyEvent.SetEvent;
end;

function CompletedResponse(const AID, AText: string): UTF8String;
begin
  Result := UTF8String('{"id":"' + AID + '","status":"completed",' +
    '"error":null,"incomplete_details":null,"output":[' +
    '{"type":"message","id":"message-1","status":"completed",' +
    '"role":"assistant","content":[' +
    '{"type":"output_text","text":"' + AText + '"}]}]}');
end;

function PaddedCompletedResponse(const AID, AText: string;
  APaddingBytes: Integer): UTF8String;
begin
  Result := UTF8String('{"padding":"' + StringOfChar('x', APaddingBytes) +
    '","id":"' + AID + '","status":"completed",' +
    '"error":null,"incomplete_details":null,"output":[' +
    '{"type":"message","id":"message-1","status":"completed",' +
    '"role":"assistant","content":[' +
    '{"type":"output_text","text":"' + AText + '"}]}]}');
end;

procedure ConfigureProvider(AProvider: TNXOpenAIProvider;
  AConfig: TNXBotHostConfig; ARecorder: TOpenAIRecorder);
begin
  AConfig.Provider := 'OpenAI';
  AConfig.Model := 'test-model';
  AConfig.OpenAIAPIKeyEnvironmentVariable := 'NEXUS_OPENAI_TEST_KEY';
  AProvider.Configure(AConfig, 'Test instructions.');
  AProvider.OnFinalAnswer := @ARecorder.FinalAnswer;
  AProvider.OnPromptFailed := @ARecorder.PromptFailed;
  AProvider.OnState := @ARecorder.StateChanged;
end;

procedure WaitProviderState(AProvider: TNXOpenAIProvider;
  AState: TNXBotProviderState; const ADescription: string);
var
  lDeadline: QWord;
begin
  lDeadline := GetTickCount64 + 5000;
  while (AProvider.State <> AState) and (GetTickCount64 < lDeadline) do
    Sleep(1);
  if AProvider.State <> AState then
    raise Exception.Create('Timed out waiting for OpenAI provider ' +
      ADescription + '.');
end;

procedure TestIndependentAnswerLimit(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
  Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', 'secret-test-key');
  lConfig := TNXBotHostConfig.Create;
  lConfig.AnswerMaximumBytes := 24;
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Results[0].Status := 200;
  lExecutor.Results[0].Body := PaddedCompletedResponse('response-large',
    '0123456789abcdefghijklmnopqrstuvwxyz', 4096);
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    AContext.AssertTrue(lRecorder.ReadyEvent.WaitFor(5000) = wrSignaled,
      'Answer-limit provider should become ready.');
    lProvider.SubmitPrompt(TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm1', 'bounded answer'));
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'A large protocol envelope should still yield its assistant answer.');
    AContext.AssertTrue(Length(lExecutor.Results[0].Body) > 4096,
      'The response fixture should be much larger than the answer limit.');
    AContext.AssertEquals(24, Length(lRecorder.Answer),
      'AnswerMaximumBytes should apply only to extracted assistant text.');
    AContext.AssertTrue(Pos('[answer truncated]',
      string(lRecorder.Answer)) > 0,
      'A bounded answer should carry the shared truncation marker.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
    Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', nil);
  end;
end;

procedure TestMissingAPIKey(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lDeadline: QWord;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
  Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', nil);
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    AContext.AssertTrue(lProvider.Start,
      'A valid deployment should start its credential check.');
    lDeadline := GetTickCount64 + 5000;
    while (lProvider.State <> bpsFailed) and
      (GetTickCount64 < lDeadline) do
      Sleep(1);
    AContext.AssertEquals(Integer(bpsFailed), Integer(lProvider.State),
      'An empty named API-key variable should fail provider startup.');
    AContext.AssertTrue(Pos('NEXUS_OPENAI_TEST_KEY',
      string(lRecorder.StateDetail)) > 0,
      'The failure should name the empty variable without exposing a value.');
    AContext.AssertEquals(0, lExecutor.Calls,
      'Missing credentials must fail before any HTTP request.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
  end;
end;

procedure TestTypedResponses(AContext: TNXTestContext);
var
  lData: TJSONData;
  lRefusal: UTF8String;
  lRequest: TNXOpenAIResponseRequest;
  lResponse: TNXOpenAIResponse;
  lText: UTF8String;
begin
  lRequest := TNXOpenAIResponseRequest.Create;
  lData := nil;
  try
    lRequest.model.Value := 'test-model';
    lRequest.instructions.Value := 'instructions';
    lRequest.input.Value := 'hello';
    lRequest.store.Value := True;
    lRequest.stream.Value := False;
    lData := lRequest.ToJSONData;
    AContext.AssertTrue(Pos('"store" : true', lData.AsJSON) > 0,
      'The typed request should explicitly store the response.');
    AContext.AssertTrue(Pos('"stream" : false', lData.AsJSON) > 0,
      'The typed request should explicitly disable streaming.');
    AContext.AssertTrue(Pos('previous_response_id', lData.AsJSON) = 0,
      'The initial typed request should omit conversation continuity.');
  finally
    lData.Free;
    lRequest.Free;
  end;

  lResponse := TNXOpenAIResponse.Create;
  lData := GetJSON('{"id":"response-1","status":"completed",' +
    '"error":null,"incomplete_details":null,"future":"ignored",' +
    '"output":[{"type":"reasoning","summary":[]},' +
    '{"type":"message","id":"message-1","status":"completed",' +
    '"role":"assistant","content":[{"type":"future_content"},' +
    '{"type":"output_text","text":"hello "},' +
    '{"type":"output_text","text":"world"}]}]}');
  try
    lResponse.FromJSONData(lData);
    AContext.AssertTrue(lResponse.ExtractCompletedText(lText, lRefusal),
      'Completed assistant output should be extracted.');
    AContext.AssertEquals('hello world', string(lText),
      'Text fragments should retain their source order.');
    AContext.AssertTrue(lResponse.output[0] is TNXOpenAIOutputItem,
      'Unknown output kinds should remain typed base objects.');
    AContext.AssertFalse(lResponse.output[0] is TNXOpenAIOutputMessage,
      'Unknown output kinds must not be misclassified as messages.');
  finally
    lData.Free;
    lResponse.Free;
  end;
end;

procedure TestProviderConversation(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
  Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', 'secret-test-key');
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Results[0].Status := 200;
  lExecutor.Results[0].Body := CompletedResponse('response-1', 'first');
  lExecutor.Results[1].Status := 200;
  lExecutor.Results[1].Body := CompletedResponse('response-2', 'second');
  lExecutor.Results[2].Status := 200;
  lExecutor.Results[2].Body := CompletedResponse('response-3', 'third');
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    AContext.AssertTrue(lProvider.Start, 'OpenAI provider should start.');
    AContext.AssertTrue(lRecorder.ReadyEvent.WaitFor(5000) = wrSignaled,
      'OpenAI provider should become ready.');
    AContext.AssertTrue(lProvider.SubmitPrompt(TNXBotPrompt.Create(1,
      'room@nexus.local', 'sender@nexus.local', 'm1', 'first prompt')),
      'The first prompt should be accepted.');
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'The first response should complete.');
    AContext.AssertTrue(lProvider.SubmitPrompt(TNXBotPrompt.Create(2,
      'room@nexus.local', 'sender@nexus.local', 'm2', 'second prompt')),
      'The second prompt should be accepted.');
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'The second response should complete.');
    AContext.AssertEquals(2, lExecutor.Calls,
      'The provider should serialize both requests through one executor.');
    AContext.AssertEquals('secret-test-key', string(lExecutor.Key),
      'The configured environment value should reach the HTTP boundary.');
    AContext.AssertTrue(Pos('secret-test-key', lExecutor.Bodies.Text) = 0,
      'The API key must not enter typed JSON request bodies.');
    AContext.AssertTrue(Pos('previous_response_id',
      lExecutor.Bodies[0]) = 0,
      'The first request should omit previous_response_id.');
    AContext.AssertTrue(Pos('"previous_response_id" : "response-1"',
      lExecutor.Bodies[1]) > 0,
      'The second request should chain the accepted response ID.');
    AContext.AssertTrue(Pos('"instructions" : "Test instructions."',
      lExecutor.Bodies[1]) > 0,
      'Instructions should be sent on every chained request.');
    AContext.AssertEquals('second', string(lRecorder.Answer),
      'The final callback should carry the second assistant answer.');
    lProvider.Stop;
    WaitProviderState(lProvider, bpsStopped, 'stop');
    AContext.AssertTrue(lProvider.Start,
      'A stopped provider should restart.');
    AContext.AssertTrue(lRecorder.ReadyEvent.WaitFor(5000) = wrSignaled,
      'A restarted provider should become ready.');
    AContext.AssertTrue(lProvider.SubmitPrompt(TNXBotPrompt.Create(3,
      'room@nexus.local', 'sender@nexus.local', 'm3', 'third prompt')),
      'The restarted provider should accept a prompt.');
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'The restarted provider should complete a response.');
    AContext.AssertTrue(Pos('previous_response_id',
      lExecutor.Bodies[2]) = 0,
      'Restart should begin a new response lineage.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
    Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', nil);
  end;
end;

procedure TestStopAndShutdownLifecycle(AContext: TNXTestContext);
var
  lCallbackCount: Integer;
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
  Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', 'secret-test-key');
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Block := True;
  lExecutor.Results[0].Status := 200;
  lExecutor.Results[0].Body := CompletedResponse('stopped-response', 'late');
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    lRecorder.ReadyEvent.WaitFor(5000);
    lProvider.SubmitPrompt(TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm1', 'stop active'));
    AContext.AssertTrue(lExecutor.Entered.WaitFor(5000) = wrSignaled,
      'The active-stop request should reach HTTP.');
    lProvider.Stop;
    AContext.AssertEquals(Integer(bpsStopping), Integer(lProvider.State),
      'Stop should report stopping while HTTP remains active.');
    lExecutor.ReleaseCall.SetEvent;
    WaitProviderState(lProvider, bpsStopped, 'active stop');
    AContext.AssertFalse(lRecorder.ReadyAfterStopping,
      'An active Stop must not publish ready after stopping.');
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'The stopped active prompt should fail exactly once.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
  end;

  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.DelayMS := 100;
  lExecutor.Results[0].Status := 200;
  lExecutor.Results[0].Body := CompletedResponse('shutdown-response', 'late');
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    lRecorder.ReadyEvent.WaitFor(5000);
    lProvider.SubmitPrompt(TNXBotPrompt.Create(2, 'room@nexus.local',
      'sender@nexus.local', 'm2', 'shutdown active'));
    AContext.AssertTrue(lExecutor.Entered.WaitFor(5000) = wrSignaled,
      'The active-shutdown request should reach HTTP.');
    lProvider.SubmitPrompt(TNXBotPrompt.Create(3, 'room@nexus.local',
      'sender@nexus.local', 'm3', 'shutdown queued'));
    lProvider.Shutdown;
    AContext.AssertEquals(Integer(bpsStopped), Integer(lProvider.State),
      'Shutdown should join the worker and finish stopped.');
    AContext.AssertEquals(2, lRecorder.FailureCount,
      'Shutdown should fail active and queued prompts exactly once.');
    lCallbackCount := lRecorder.FinalCount + lRecorder.FailureCount;
    Sleep(50);
    AContext.AssertEquals(lCallbackCount,
      lRecorder.FinalCount + lRecorder.FailureCount,
      'No provider callback may occur after Shutdown returns.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
    Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', nil);
  end;
end;

procedure TestResponseFailures(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lIndex: Integer;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
  Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', 'secret-test-key');
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Results[0].Status := 429;
  lExecutor.Results[0].Body := '{"error":{"message":"rate limited",' +
    '"type":"rate_limit_error","param":null,"code":null}}';
  lExecutor.Results[1].Status := 500;
  lExecutor.Results[1].Body := '{"error":{"message":"server error",' +
    '"type":"server_error","param":null,"code":null}}';
  lExecutor.Results[2].Status := 200;
  lExecutor.Results[2].Body := '{"id":"incomplete-1",' +
    '"status":"incomplete","error":null,' +
    '"incomplete_details":{"reason":"max_output_tokens"},"output":[]}';
  lExecutor.Results[3].Status := 200;
  lExecutor.Results[3].Body := '{"id":"refusal-1",' +
    '"status":"completed","error":null,"incomplete_details":null,' +
    '"output":[{"type":"message","id":"message-1",' +
    '"status":"completed","role":"assistant","content":[' +
    '{"type":"refusal","refusal":"declined"}]}]}';
  lExecutor.Results[4].Status := 200;
  lExecutor.Results[4].Body := '{not valid JSON';
  lExecutor.Results[5].Status := 200;
  lExecutor.Results[5].Body := CompletedResponse('recovered-1', 'recovered');
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    lRecorder.ReadyEvent.WaitFor(5000);
    for lIndex := 0 to 3 do
    begin
      lProvider.SubmitPrompt(TNXBotPrompt.Create(lIndex + 1,
        'room@nexus.local', 'sender@nexus.local', 'failure', 'fail locally'));
      AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
        'A prompt-local response failure should invoke its callback.');
      WaitProviderState(lProvider, bpsReady, 'prompt-local recovery');
    end;
    AContext.AssertEquals(4, lRecorder.FailureCount,
      'Transient, incomplete, and refusal results should each fail once.');
    lProvider.SubmitPrompt(TNXBotPrompt.Create(5, 'room@nexus.local',
      'sender@nexus.local', 'malformed', 'fail provider'));
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'Malformed successful JSON should fail its prompt.');
    WaitProviderState(lProvider, bpsFailed, 'malformed response failure');
    AContext.AssertTrue(lProvider.Start,
      'A failed provider should restart after its worker exits.');
    AContext.AssertTrue(lRecorder.ReadyEvent.WaitFor(5000) = wrSignaled,
      'A restarted failed provider should become ready.');
    lProvider.SubmitPrompt(TNXBotPrompt.Create(6, 'room@nexus.local',
      'sender@nexus.local', 'recovered', 'recover'));
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'A restarted provider should complete normal work.');
    AContext.AssertEquals('recovered', string(lRecorder.Answer),
      'Restart after failure should restore normal responses.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
    Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', nil);
  end;
end;

procedure TestCancellationAndFailure(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
  Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', 'secret-test-key');
  lConfig := TNXBotHostConfig.Create;
  lConfig.PromptCapacity := 1;
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Block := True;
  lExecutor.Results[0].Status := 200;
  lExecutor.Results[0].Body := CompletedResponse('late-response', 'too late');
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    AContext.AssertTrue(lRecorder.ReadyEvent.WaitFor(5000) = wrSignaled,
      'Cancellation test provider should become ready.');
    lProvider.SubmitPrompt(TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm1', 'block'));
    AContext.AssertTrue(lExecutor.Entered.WaitFor(5000) = wrSignaled,
      'The request should reach the blocking executor.');
    AContext.AssertTrue(lProvider.SubmitPrompt(TNXBotPrompt.Create(2,
      'second@nexus.local', 'sender@nexus.local', 'm2', 'queued')),
      'One queued prompt should fit behind the active request.');
    AContext.AssertFalse(lProvider.SubmitPrompt(TNXBotPrompt.Create(3,
      'third@nexus.local', 'sender@nexus.local', 'm3', 'over capacity')),
      'A prompt beyond configured queue capacity should be rejected.');
    lProvider.CancelRoomPrompts('second@nexus.local', 'room cancelled');
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'Room cancellation should fail its retained queued prompt.');
    AContext.AssertEquals(1, lRecorder.FailureCount,
      'Room cancellation should leave the active prompt untouched.');
    lProvider.CancelPrompts('cancelled by test');
    lExecutor.ReleaseCall.SetEvent;
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'Cancelled in-flight work should fail exactly once after HTTP returns.');
    AContext.AssertEquals(0, lRecorder.FinalCount,
      'A late cancelled response must not produce a final answer.');
    AContext.AssertEquals(2, lRecorder.FailureCount,
      'Each retained cancelled prompt should fail exactly once.');
    AContext.AssertEquals('cancelled by test', string(lRecorder.Failed),
      'Cancellation should preserve its operation-local reason.');
    WaitProviderState(lProvider, bpsReady, 'cancelled-request recovery');
    lExecutor.Block := False;
    lExecutor.Results[1].Status := 200;
    lExecutor.Results[1].Body := CompletedResponse('after-cancel', 'continued');
    AContext.AssertTrue(lProvider.SubmitPrompt(TNXBotPrompt.Create(4,
      'room@nexus.local', 'sender@nexus.local', 'm4', 'after cancellation')),
      'The provider should accept work after prompt cancellation.');
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'The provider should complete work after cancellation.');
    AContext.AssertTrue(Pos('previous_response_id',
      lExecutor.Bodies[1]) = 0,
      'A late cancelled response must not advance conversation continuity.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
    Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', nil);
  end;

  Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', 'secret-test-key');
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Results[0].Status := 401;
  lExecutor.Results[0].Body := '{"error":{"message":"bad key",' +
    '"type":"authentication_error","param":null,"code":"invalid_key"}}';
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    lRecorder.ReadyEvent.WaitFor(5000);
    lProvider.SubmitPrompt(TNXBotPrompt.Create(2, 'room@nexus.local',
      'sender@nexus.local', 'm2', 'fail'));
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'Authentication rejection should fail the prompt.');
    AContext.AssertEquals(Integer(bpsFailed), Integer(lProvider.State),
      'Authentication rejection should fail the provider.');
    AContext.AssertTrue(Pos('bad key', string(lRecorder.Failed)) > 0,
      'Typed API error text should reach the bounded failure diagnostic.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
    Windows.SetEnvironmentVariable('NEXUS_OPENAI_TEST_KEY', nil);
  end;
end;

procedure RegisterNXOpenAIProviderTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusBotHost.OpenAI');
  lSuite.AddTest('TypedResponses', @TestTypedResponses);
  lSuite.AddTest('ProviderConversation', @TestProviderConversation);
  lSuite.AddTest('IndependentAnswerLimit', @TestIndependentAnswerLimit);
  lSuite.AddTest('MissingAPIKey', @TestMissingAPIKey);
  lSuite.AddTest('CancellationAndFailure', @TestCancellationAndFailure);
  lSuite.AddTest('StopAndShutdownLifecycle', @TestStopAndShutdownLifecycle);
  lSuite.AddTest('ResponseFailures', @TestResponseFailures);
end;

end.
