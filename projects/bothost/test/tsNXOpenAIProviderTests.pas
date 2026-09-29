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
  obNXBotHostConfig,
  obNXBotWorkspace,
  obNXOpenAIProvider,
  obNXOpenAIResponses,
  obNXTestContext,
  obNXTestSuite,
  tpNXBotFileTypes,
  tpNXBotHost;

type
  TFakeOpenAIExecutor = class(TNXOpenAIExecutor)
  public
    Block: Boolean;
    DelayMS: Cardinal;
    Bodies: TStringList;
    Calls: Integer;
    CAFile: UTF8String;
    Entered: TEvent;
    Key: UTF8String;
    ReleaseCall: TEvent;
    Results: array[0..9] of TNXOpenAIHTTPResult;
    DeleteCalls: Integer;
    RaiseUploadOnce: Boolean;
    UploadBody: UTF8String;
    UploadCalls: Integer;
    constructor Create;
    destructor Destroy; override;
    function Execute(const AAPIKey, ACAFile, ABody: UTF8String;
      ATimeoutMS: Cardinal; out AResult: TNXOpenAIHTTPResult): Boolean;
      override;
    function UploadFile(const AAPIKey, ACAFile, AFileName,
      ADisplayName, AMediaType: UTF8String; ATimeoutMS: Cardinal;
      out AResult: TNXOpenAIHTTPResult): Boolean; override;
    function DeleteFile(const AAPIKey, ACAFile, AFileID: UTF8String;
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

function TFakeOpenAIExecutor.Execute(const AAPIKey, ACAFile,
  ABody: UTF8String; ATimeoutMS: Cardinal;
  out AResult: TNXOpenAIHTTPResult): Boolean;
begin
  Key := AAPIKey;
  CAFile := ACAFile;
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

function TFakeOpenAIExecutor.UploadFile(const AAPIKey, ACAFile, AFileName,
  ADisplayName, AMediaType: UTF8String; ATimeoutMS: Cardinal;
  out AResult: TNXOpenAIHTTPResult): Boolean;
var
  lSize: Int64;
begin
  Inc(UploadCalls);
  if RaiseUploadOnce then
  begin
    RaiseUploadOnce := False;
    raise Exception.Create('simulated upload exception');
  end;
  with TFileStream.Create(string(AFileName), fmOpenRead or fmShareDenyWrite) do
  try
    lSize := Size;
  finally
    Free;
  end;
  AResult := Default(TNXOpenAIHTTPResult);
  AResult.Status := 200;
  if UploadBody <> '' then
    AResult.Body := UploadBody
  else
    AResult.Body := UTF8String(Format(
      '{"id":"file-%d","bytes":%d,"filename":"%s",' +
      '"purpose":"user_data","status":"processed"}',
      [UploadCalls, lSize, string(ADisplayName)]));
  Result := True;
end;

function TFakeOpenAIExecutor.DeleteFile(const AAPIKey, ACAFile,
  AFileID: UTF8String; ATimeoutMS: Cardinal;
  out AResult: TNXOpenAIHTTPResult): Boolean;
begin
  Inc(DeleteCalls);
  AResult := Default(TNXOpenAIHTTPResult);
  AResult.Status := 200;
  AResult.Body := '{"deleted":true}';
  Result := True;
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
  AConfig.OpenAICAFile := 'openai-ca.pem';
  AConfig.OpenAIAPIKey := 'secret-test-key';
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
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lConfig.OpenAIAPIKey := '';
    AContext.AssertTrue(lProvider.Start,
      'A valid deployment should start its credential check.');
    lDeadline := GetTickCount64 + 5000;
    while (lProvider.State <> bpsFailed) and
      (GetTickCount64 < lDeadline) do
      Sleep(1);
    AContext.AssertEquals(Integer(bpsFailed), Integer(lProvider.State),
      'An empty API key should fail provider startup.');
    AContext.AssertTrue(Pos('API key is empty',
      string(lRecorder.StateDetail)) > 0,
      'The failure should identify the missing credential without a value.');
    AContext.AssertEquals(0, lExecutor.Calls,
      'Missing credentials must fail before any HTTP request.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
  end;
end;

procedure TestMissingCAFile(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lDeadline: QWord;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lConfig.OpenAICAFile := '';
    AContext.AssertTrue(lProvider.Start,
      'A valid deployment should start its CA-bundle check.');
    lDeadline := GetTickCount64 + 5000;
    while (lProvider.State <> bpsFailed) and
      (GetTickCount64 < lDeadline) do
      Sleep(1);
    AContext.AssertEquals(Integer(bpsFailed), Integer(lProvider.State),
      'An empty OpenAI CA file should fail provider startup.');
    AContext.AssertTrue(Pos('CA bundle is empty',
      string(lRecorder.StateDetail)) > 0,
      'The failure should identify the missing OpenAI trust bundle.');
    AContext.AssertEquals(0, lExecutor.Calls,
      'Missing trust configuration must fail before any HTTPS request.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
  end;
end;

procedure TestTypedResponses(AContext: TNXTestContext);
var
  lData: TJSONData;
  lInputMessage: TNXOpenAIInputMessage;
  lInputText: TNXOpenAIInputText;
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
    lInputMessage := TNXOpenAIInputMessage(lRequest.input.AddObject(
      TNXOpenAIInputMessage));
    lInputMessage.role.Value := 'user';
    lInputText := TNXOpenAIInputText(lInputMessage.content.AddObject(
      TNXOpenAIInputText));
    lInputText.&type.Value := 'input_text';
    lInputText.text.Value := 'hello';
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
      'The configured API key should reach the HTTP boundary.');
    AContext.AssertEquals('openai-ca.pem', string(lExecutor.CAFile),
      'The configured OpenAI CA file should reach the HTTPS boundary.');
    AContext.AssertTrue(Pos('secret-test-key', lExecutor.Bodies.Text) = 0,
      'The API key must not enter typed JSON request bodies.');
    AContext.AssertTrue(Pos('"type" : "shell"',
      lExecutor.Bodies[0]) = 0,
      'A bot without workspaces must not advertise local shell.');
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
  end;
end;

procedure TestAttachmentMappingAndCleanup(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lDocument: string;
  lExecutor: TFakeOpenAIExecutor;
  lImage: string;
  lPrompt: TNXBotPrompt;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
  lStream: TStringStream;
begin
  lDocument := GetTempFileName(GetTempDir(False), 'nxdoc');
  lImage := GetTempFileName(GetTempDir(False), 'nximg');
  lStream := TStringStream.Create('document');
  try lStream.SaveToFile(lDocument); finally lStream.Free; end;
  lStream := TStringStream.Create('image');
  try lStream.SaveToFile(lImage); finally lStream.Free; end;
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Results[0].Status := 200;
  lExecutor.Results[0].Body := CompletedResponse('attachment-response', 'ok');
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    lRecorder.ReadyEvent.WaitFor(5000);
    lPrompt := TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm-file', 'inspect both');
    lAttachment := TNXBotAttachment.Create;
    lAttachment.ID := 'document-artifact';
    lAttachment.ArtifactID := lAttachment.ID;
    lAttachment.Name := 'notes.txt';
    lAttachment.MediaType := 'text/plain';
    lAttachment.Path := lDocument;
    lAttachment.Size := 8;
    lPrompt.AddAttachment(lAttachment);
    lAttachment := TNXBotAttachment.Create;
    lAttachment.ID := 'image-artifact';
    lAttachment.ArtifactID := lAttachment.ID;
    lAttachment.Name := 'picture.png';
    lAttachment.MediaType := 'image/png';
    lAttachment.Path := lImage;
    lAttachment.Size := 5;
    lPrompt.AddAttachment(lAttachment);
    AContext.AssertTrue(lProvider.SubmitPrompt(lPrompt),
      'A prompt with supported attachments should be accepted.');
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'Supported attachments should complete through Responses.');
    AContext.AssertEquals(2, lExecutor.UploadCalls,
      'Each neutral artifact should be uploaded once to Files.');
    AContext.AssertTrue((Pos('"type" : "input_file"',
      lExecutor.Bodies[0]) > 0) and
      (Pos('"type" : "input_image"', lExecutor.Bodies[0]) > 0) and
      (Pos('file-1', lExecutor.Bodies[0]) > 0) and
      (Pos('file-2', lExecutor.Bodies[0]) > 0),
      'Responses input should use typed document and image variants.');
    lProvider.Stop;
    WaitProviderState(lProvider, bpsStopped, 'attachment cleanup');
    AContext.AssertEquals(2, lExecutor.DeleteCalls,
      'Provider stop should delete every session-owned OpenAI file.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
    DeleteFile(lDocument);
    DeleteFile(lImage);
  end;
end;

procedure TestAttachmentSetupFailures(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lFileName: string;
  lPrompt: TNXBotPrompt;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
  lStream: TStringStream;
begin
  lFileName := GetTempFileName(GetTempDir(False), 'nxfail');
  lStream := TStringStream.Create('failure-data');
  try
    lStream.SaveToFile(lFileName);
  finally
    lStream.Free;
  end;
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    lRecorder.ReadyEvent.WaitFor(5000);

    lExecutor.UploadBody := '{"id":"file-wrong","bytes":12,' +
      '"filename":"wrong.txt","purpose":"user_data"}';
    lPrompt := TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm-wrong', 'inspect');
    lAttachment := TNXBotAttachment.Create;
    lAttachment.ID := 'wrong-response';
    lAttachment.ArtifactID := lAttachment.ID;
    lAttachment.Name := 'expected.txt';
    lAttachment.MediaType := 'text/plain';
    lAttachment.Path := lFileName;
    lAttachment.Size := 12;
    lPrompt.AddAttachment(lAttachment);
    AContext.AssertTrue(lProvider.SubmitPrompt(lPrompt),
      'The mismatched upload response prompt should enter the worker.');
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'A mismatched upload response should fail the prompt.');
    AContext.AssertEquals(1, lExecutor.DeleteCalls,
      'A server file created during failed setup should be deleted.');
    AContext.AssertEquals(0, lExecutor.Calls,
      'Responses must not run after failed file validation.');

    lExecutor.UploadBody := '';
    lExecutor.RaiseUploadOnce := True;
    lPrompt := TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm-exception', 'inspect');
    lAttachment := TNXBotAttachment.Create;
    lAttachment.ID := 'upload-exception';
    lAttachment.ArtifactID := lAttachment.ID;
    lAttachment.Name := 'expected.txt';
    lAttachment.MediaType := 'text/plain';
    lAttachment.Path := lFileName;
    lAttachment.Size := 12;
    lPrompt.AddAttachment(lAttachment);
    AContext.AssertTrue(lProvider.SubmitPrompt(lPrompt),
      'The upload-exception prompt should enter the worker.');
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'An upload exception should fail the prompt without killing the worker.');

    lExecutor.Results[0].Status := 200;
    lExecutor.Results[0].Body := CompletedResponse('after-upload-failure', 'ok');
    lPrompt := TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm-after', 'continue');
    AContext.AssertTrue(lProvider.SubmitPrompt(lPrompt),
      'The provider should accept work after an upload exception.');
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'The provider worker should survive an upload exception.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
    DeleteFile(lFileName);
  end;
end;

procedure TestUnsupportedAudioAttachment(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lPrompt: TNXBotPrompt;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
  lConfig := TNXBotHostConfig.Create;
  lExecutor := TFakeOpenAIExecutor.Create;
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    lRecorder.ReadyEvent.WaitFor(5000);
    lPrompt := TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm-audio', 'listen');
    lAttachment := TNXBotAttachment.Create;
    lAttachment.ID := 'audio-artifact';
    lAttachment.ArtifactID := lAttachment.ID;
    lAttachment.Name := 'sound.wav';
    lAttachment.MediaType := 'audio/wav';
    lAttachment.Size := 4;
    lPrompt.AddAttachment(lAttachment);
    AContext.AssertTrue(lProvider.SubmitPrompt(lPrompt),
      'The audio prompt should enter provider validation.');
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'Unsupported audio should fail explicitly.');
    AContext.AssertEquals(0, lExecutor.UploadCalls,
      'Unsupported audio must fail before a Files upload.');
    AContext.AssertEquals(0, lExecutor.Calls,
      'Unsupported audio must fail before a Responses request.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
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
  end;
end;

procedure TestCancellationAndFailure(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
begin
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
  end;

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
    WaitProviderState(lProvider, bpsFailed, 'authentication rejection');
    AContext.AssertEquals(Integer(bpsFailed), Integer(lProvider.State),
      'Authentication rejection should fail the provider.');
    AContext.AssertTrue(Pos('bad key', string(lRecorder.Failed)) > 0,
      'Typed API error text should reach the bounded failure diagnostic.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
  end;
end;

procedure TestWorkspaceShellContinuation(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
  lWorkspace: TNXBotWorkspaceAccess;
begin
  lConfig := TNXBotHostConfig.Create;
  lConfig.RuntimeDirectory := GetTempDir(False);
  lConfig.ShellOutputMaximumBytes := 5;
  lWorkspace := TNXBotWorkspaceAccess.Create;
  lWorkspace.Name := 'Nexus';
  lWorkspace.Purpose := 'Reference source.';
  lWorkspace.RepositoryPath := ExpandFileName('.');
  lWorkspace.CachePath := GetTempDir(False);
  lWorkspace.ResolvedCommit := '0123456789abcdef';
  lConfig.Workspaces.Add(lWorkspace);
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Results[0].Status := 200;
  lExecutor.Results[0].Body :=
    '{"id":"response-shell","status":"completed","error":null,' +
    '"incomplete_details":null,"output":[{"type":"shell_call",' +
    '"id":"item-shell","call_id":"call-shell","status":"completed",' +
    '"action":{"type":"exec","commands":["echo shell-ok"],' +
    '"timeout_ms":5000,"max_output_length":4096}}]}';
  lExecutor.Results[1].Status := 200;
  lExecutor.Results[1].Body := CompletedResponse('response-final', 'done');
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    AContext.AssertTrue(lRecorder.ReadyEvent.WaitFor(5000) = wrSignaled,
      'Workspace provider should become ready.');
    lProvider.SubmitPrompt(TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm1', 'inspect the workspace'));
    AContext.AssertTrue(lRecorder.FinalEvent.WaitFor(5000) = wrSignaled,
      'Shell output should continue to a final assistant answer.');
    AContext.AssertEquals('done', string(lRecorder.Answer),
      'The continuation should publish only the final answer.');
    AContext.AssertEquals(2, lExecutor.Calls,
      'One shell call should require exactly one continuation request.');
    AContext.AssertTrue((Pos('"type" : "shell"',
      lExecutor.Bodies[0]) > 0) and (Pos('Reference workspaces:',
      lExecutor.Bodies[0]) > 0),
      'Assigned workspaces should advertise local shell and explicit paths.');
    AContext.AssertTrue((Pos('"type" : "shell_call_output"',
      lExecutor.Bodies[1]) > 0) and (Pos('"max_output_length" : 5',
      lExecutor.Bodies[1]) > 0) and (Pos('"stdout" : "shell"',
      lExecutor.Bodies[1]) > 0) and (Pos('response-shell',
      lExecutor.Bodies[1]) > 0),
      'The bounded typed shell result should continue the same response.');
    AContext.AssertTrue((Pos('"instructions"', lExecutor.Bodies[1]) > 0) and
      (Pos('Test instructions.', lExecutor.Bodies[1]) > 0) and
      (Pos('Reference workspaces:', lExecutor.Bodies[1]) > 0),
      'Shell continuations should retain bot and workspace instructions.');
    AContext.AssertEquals(1, lRecorder.FinalCount,
      'The prompt should complete exactly once.');
    AContext.AssertEquals(0, lRecorder.FailureCount,
      'A successful shell continuation should not fail the prompt.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
  end;
end;

procedure TestWorkspaceShellLimits(AContext: TNXTestContext);
var
  lCommand: string;
  lConfig: TNXBotHostConfig;
  lExecutor: TFakeOpenAIExecutor;
  lProvider: TNXOpenAIProvider;
  lRecorder: TOpenAIRecorder;
  lWorkspace: TNXBotWorkspaceAccess;
begin
  {$IFDEF Windows}
  lCommand := 'for /L %i in (1,1,2147483647) do @rem';
  {$ELSE}
  lCommand := 'while :; do :; done';
  {$ENDIF}
  lConfig := TNXBotHostConfig.Create;
  lConfig.RuntimeDirectory := GetTempDir(False);
  lConfig.ShellCallMaximum := 1;
  lConfig.ShellCommandTimeoutMS := 20;
  lConfig.ShellOutputMaximumBytes := 5;
  lWorkspace := TNXBotWorkspaceAccess.Create;
  lWorkspace.Name := 'Nexus';
  lWorkspace.RepositoryPath := ExpandFileName('.');
  lWorkspace.CachePath := GetTempDir(False);
  lWorkspace.ResolvedCommit := '0123456789abcdef';
  lConfig.Workspaces.Add(lWorkspace);
  lExecutor := TFakeOpenAIExecutor.Create;
  lExecutor.Results[0].Status := 200;
  lExecutor.Results[0].Body :=
    '{"id":"response-shell-1","status":"completed","error":null,' +
    '"incomplete_details":null,"output":[{"type":"shell_call",' +
    '"call_id":"call-shell-1","status":"completed","action":{' +
    '"commands":["' + lCommand + '"],"timeout_ms":10000,' +
    '"max_output_length":10000}}]}';
  lExecutor.Results[1].Status := 200;
  lExecutor.Results[1].Body :=
    '{"id":"response-shell-2","status":"completed","error":null,' +
    '"incomplete_details":null,"output":[{"type":"shell_call",' +
    '"call_id":"call-shell-2","status":"completed","action":{' +
    '"commands":["echo should-not-run"]}}]}';
  lProvider := TNXOpenAIProvider.CreateWithExecutor(lExecutor);
  lRecorder := TOpenAIRecorder.Create;
  try
    ConfigureProvider(lProvider, lConfig, lRecorder);
    lProvider.Start;
    AContext.AssertTrue(lRecorder.ReadyEvent.WaitFor(5000) = wrSignaled,
      'Workspace limit provider should become ready.');
    lProvider.SubmitPrompt(TNXBotPrompt.Create(1, 'room@nexus.local',
      'sender@nexus.local', 'm1', 'exercise shell limits'));
    AContext.AssertTrue(lRecorder.FailureEvent.WaitFor(5000) = wrSignaled,
      'A second shell call should exceed the configured prompt limit.');
    AContext.AssertTrue(Pos('shell call limit exceeded',
      LowerCase(string(lRecorder.Failed))) > 0,
      'The prompt should report the shell-call limit.');
    AContext.AssertEquals(2, lExecutor.Calls,
      'The rejected second shell call must not produce another request.');
    AContext.AssertTrue((Pos('"max_output_length" : 5',
      lExecutor.Bodies[1]) > 0) and (Pos('"type" : "timeout"',
      lExecutor.Bodies[1]) > 0),
      'Model limits should clamp to deployment limits and report timeout.');
  finally
    lProvider.Free;
    lRecorder.Free;
    lConfig.Free;
  end;
end;

procedure RegisterNXOpenAIProviderTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusBotHost.OpenAI');
  lSuite.AddTest('TypedResponses', @TestTypedResponses);
  lSuite.AddTest('ProviderConversation', @TestProviderConversation);
  lSuite.AddTest('AttachmentMappingAndCleanup',
    @TestAttachmentMappingAndCleanup);
  lSuite.AddTest('AttachmentSetupFailures', @TestAttachmentSetupFailures);
  lSuite.AddTest('UnsupportedAudioAttachment',
    @TestUnsupportedAudioAttachment);
  lSuite.AddTest('IndependentAnswerLimit', @TestIndependentAnswerLimit);
  lSuite.AddTest('MissingAPIKey', @TestMissingAPIKey);
  lSuite.AddTest('MissingCAFile', @TestMissingCAFile);
  lSuite.AddTest('CancellationAndFailure', @TestCancellationAndFailure);
  lSuite.AddTest('StopAndShutdownLifecycle', @TestStopAndShutdownLifecycle);
  lSuite.AddTest('ResponseFailures', @TestResponseFailures);
  lSuite.AddTest('WorkspaceShellContinuation',
    @TestWorkspaceShellContinuation);
  lSuite.AddTest('WorkspaceShellLimits', @TestWorkspaceShellLimits);
end;

end.
