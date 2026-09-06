unit obNXOpenAIProvider;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  SyncObjs,
  SysUtils,
  obNXBotHostConfig,
  obNXBotProvider,
  tpNXBotHost;

type
  TNXOpenAIHTTPResult = record
    Body: UTF8String;
    ErrorCode: Cardinal;
    ErrorText: UTF8String;
    Fatal: Boolean;
    Status: Cardinal;
  end;

  TNXOpenAIExecutor = class
  public
    function Execute(const AAPIKey, ACAFile, ABody: UTF8String;
      ATimeoutMS: Cardinal; out AResult: TNXOpenAIHTTPResult): Boolean;
      virtual; abstract;
  end;

  TNXOpenAISynapseExecutor = class(TNXOpenAIExecutor)
  public
    function Execute(const AAPIKey, ACAFile, ABody: UTF8String;
      ATimeoutMS: Cardinal; out AResult: TNXOpenAIHTTPResult): Boolean;
      override;
  end;

  TNXOpenAIProvider = class;

  TNXOpenAIProviderThread = class(TThread)
  private
    FOwner: TNXOpenAIProvider;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TNXOpenAIProvider);
  end;

  TNXOpenAIProvider = class(TNXBotProvider)
  private
    FAccepting: Boolean;
    FActiveCancelled: Boolean;
    FActiveCancellationReason: UTF8String;
    FActivePrompt: TNXBotPrompt;
    FAPIKey: UTF8String;
    FCriticalSection: TRTLCriticalSection;
    FExecutor: TNXOpenAIExecutor;
    FPreviousResponseID: UTF8String;
    FPrompts: TObjectList;
    FShuttingDown: Boolean;
    FStopRequested: Boolean;
    FWake: TEvent;
    FWorker: TNXOpenAIProviderThread;
    procedure CancelQueued(const ARoomJID, AReason: UTF8String;
      AMatchRoom: Boolean);
    function CompleteActive(APrompt: TNXBotPrompt; ASuccess: Boolean;
      const AResponseID: UTF8String; out ACancellationReason: UTF8String): Boolean;
    procedure FailAllQueued(const AReason: UTF8String);
    procedure FailFatally(APrompt: TNXBotPrompt; const AReason: UTF8String);
    procedure ReturnToReady;
    function TakePrompt: TNXBotPrompt;
    procedure ThreadExecute;
    procedure ThreadStopped;
    procedure ProcessPrompt(APrompt: TNXBotPrompt);
  public
    constructor Create; override;
    constructor CreateWithExecutor(AExecutor: TNXOpenAIExecutor);
    destructor Destroy; override;
    class function ProviderName: UTF8String; override;
    class procedure ValidateDeployment(ABinding: TNXBotDeploymentBinding;
      const ABotName: string; ADiagnostics: TStrings); override;
    function Start: Boolean; override;
    function Stop: Boolean; override;
    procedure Shutdown; override;
    function SubmitPrompt(APrompt: TNXBotPrompt): Boolean; override;
    function CancelPrompts(const AReason: UTF8String): Boolean; override;
    function CancelRoomPrompts(const ARoomJID,
      AReason: UTF8String): Boolean; override;
  end;

implementation

uses
  fpjson,
  httpsend,
  obNXOpenAIResponses,
  ssl_openssl3;

const
  cOpenAIResponseMaximumBytes = 1024 * 1024;

type
  ENXOpenAIResponseLimit = class(Exception);

  TNXOpenAIBoundedStream = class(TMemoryStream)
  public
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

function TNXOpenAIBoundedStream.Write(const ABuffer;
  ACount: LongInt): LongInt;
begin
  if (ACount < 0) or (Position > cOpenAIResponseMaximumBytes) or
    (ACount > cOpenAIResponseMaximumBytes - Position) then
    raise ENXOpenAIResponseLimit.Create(
      'OpenAI response exceeds the protocol limit.');
  Result := inherited Write(ABuffer, ACount);
end;

function BoundedDiagnostic(const AText: UTF8String): UTF8String;
const
  cMaximumDiagnosticBytes = 1024;
begin
  if Length(AText) <= cMaximumDiagnosticBytes then
    Result := AText
  else
    Result := Copy(AText, 1, cMaximumDiagnosticBytes) + '...';
end;

function ErrorMessageFromBody(const ABody: UTF8String): UTF8String;
var
  lData: TJSONData;
  lEnvelope: TNXOpenAIErrorEnvelope;
begin
  Result := '';
  lData := nil;
  lEnvelope := TNXOpenAIErrorEnvelope.Create;
  try
    try
      lData := GetJSON(string(ABody));
      lEnvelope.FromJSONData(lData);
      if lEnvelope.error.Assigned and not lEnvelope.error.IsNull then
      begin
        if lEnvelope.error.&type.Value <> '' then
          Result := lEnvelope.error.&type.Value + ': ';
        Result := Result + lEnvelope.error.message.Value;
      end;
    except
      Result := '';
    end;
  finally
    lEnvelope.Free;
    lData.Free;
  end;
  Result := BoundedDiagnostic(Result);
end;

function TNXOpenAISynapseExecutor.Execute(const AAPIKey, ACAFile,
  ABody: UTF8String; ATimeoutMS: Cardinal;
  out AResult: TNXOpenAIHTTPResult): Boolean;
var
  lBody: RawByteString;
  lHTTP: THTTPSend;
  lResponse: TNXOpenAIBoundedStream;
  lTimeout: Integer;
begin
  AResult := Default(TNXOpenAIHTTPResult);
  if (Trim(string(ACAFile)) = '') or not FileExists(string(ACAFile)) then
  begin
    AResult.ErrorText := 'A readable OpenAI CA bundle is required.';
    AResult.Fatal := True;
    Exit(False);
  end;
  lHTTP := THTTPSend.Create;
  lResponse := TNXOpenAIBoundedStream.Create;
  try
    if ATimeoutMS > Cardinal(High(Integer)) then
      lTimeout := High(Integer)
    else
      lTimeout := Integer(ATimeoutMS);
    lHTTP.Timeout := lTimeout;
    lHTTP.Sock.ConnectionTimeout := lTimeout;
    lHTTP.Sock.SSL.VerifyCert := True;
    lHTTP.Sock.SSL.CertCAFile := string(ACAFile);
    lHTTP.UserAgent := 'NexusBotHost/1.0';
    lHTTP.MimeType := 'application/json';
    lHTTP.Headers.Add('Authorization: Bearer ' + string(AAPIKey));
    lHTTP.OutputStream := lResponse;
    if Length(ABody) > 0 then
      lHTTP.Document.WriteBuffer(ABody[1], Length(ABody));
    try
      Result := lHTTP.HTTPMethod('POST',
        'https://api.openai.com/v1/responses');
    except
      on E: ENXOpenAIResponseLimit do
      begin
        AResult.ErrorText := UTF8String(E.Message);
        AResult.Fatal := True;
        Exit(False);
      end;
    end;
    AResult.Status := Cardinal(lHTTP.ResultCode);
    if not Result then
    begin
      AResult.ErrorCode := Cardinal(lHTTP.Sock.LastError);
      AResult.ErrorText := UTF8String(lHTTP.Sock.GetErrorDescEx);
      if AResult.ErrorText = '' then
        AResult.ErrorText := 'OpenAI HTTPS request failed.';
      AResult.Fatal := lHTTP.Sock.SSL.LastError <> 0;
      Exit(False);
    end;
    lBody := '';
    SetLength(lBody, lResponse.Size);
    if Length(lBody) > 0 then
    begin
      lResponse.Position := 0;
      lResponse.ReadBuffer(lBody[1], Length(lBody));
    end;
    AResult.Body := UTF8String(lBody);
  finally
    lResponse.Free;
    lHTTP.Free;
  end;
end;

constructor TNXOpenAIProviderThread.Create(AOwner: TNXOpenAIProvider);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

procedure TNXOpenAIProviderThread.Execute;
begin
  FOwner.ThreadExecute;
end;

constructor TNXOpenAIProvider.Create;
begin
  CreateWithExecutor(TNXOpenAISynapseExecutor.Create);
end;

constructor TNXOpenAIProvider.CreateWithExecutor(AExecutor: TNXOpenAIExecutor);
begin
  inherited Create;
  if not Assigned(AExecutor) then
    raise Exception.Create('OpenAI executor is required.');
  FExecutor := AExecutor;
  InitCriticalSection(FCriticalSection);
  FPrompts := TObjectList.Create(True);
  FWake := TEvent.Create(nil, False, False, '');
end;

destructor TNXOpenAIProvider.Destroy;
begin
  Shutdown;
  FWake.Free;
  FPrompts.Free;
  DoneCriticalSection(FCriticalSection);
  FExecutor.Free;
  inherited Destroy;
end;

class function TNXOpenAIProvider.ProviderName: UTF8String;
begin
  Result := 'OpenAI';
end;

class procedure TNXOpenAIProvider.ValidateDeployment(
  ABinding: TNXBotDeploymentBinding; const ABotName: string;
  ADiagnostics: TStrings);
begin
  if not Assigned(ABinding) then
    Exit;
  if Trim(ABinding.OpenAIAPIKey) = '' then
    ADiagnostics.Add('Missing deployment field OpenAIAPIKey for bot ' +
      ABotName + '.');
  if Trim(ABinding.OpenAICAFile) = '' then
    ADiagnostics.Add('Missing deployment field OpenAICAFile for bot ' +
      ABotName + '.');
end;

function TNXOpenAIProvider.Start: Boolean;
var
  lFinishedWorker: TNXOpenAIProviderThread;
begin
  Result := False;
  if not (State in [bpsStopped, bpsFailed]) then
    Exit;
  if Trim(Configuration.OpenAIAPIKey) = '' then
  begin
    SetState(bpsFailed, 'OpenAI API key is empty.');
    Exit(True);
  end;
  if Trim(Configuration.OpenAICAFile) = '' then
  begin
    SetState(bpsFailed, 'OpenAI CA bundle is empty.');
    Exit(True);
  end;
  lFinishedWorker := nil;
  EnterCriticalSection(FCriticalSection);
  try
    if Assigned(FWorker) then
    begin
      lFinishedWorker := FWorker;
      FWorker := nil;
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  if Assigned(lFinishedWorker) then
  begin
    lFinishedWorker.WaitFor;
    lFinishedWorker.Free;
  end;
  EnterCriticalSection(FCriticalSection);
  try
    if Assigned(FWorker) or FShuttingDown then
      Exit;
    FAccepting := True;
    FStopRequested := False;
    FPreviousResponseID := '';
    FWorker := TNXOpenAIProviderThread.Create(Self);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  SetState(bpsStarting);
  FWorker.Start;
  Result := True;
end;

function TNXOpenAIProvider.Stop: Boolean;
var
  lFinished: Boolean;
  lHasWorker: Boolean;
  lWorker: TNXOpenAIProviderThread;
begin
  Result := True;
  lWorker := nil;
  EnterCriticalSection(FCriticalSection);
  try
    lHasWorker := Assigned(FWorker);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  if lHasWorker and (State <> bpsFailed) then
    SetState(bpsStopping);
  EnterCriticalSection(FCriticalSection);
  try
    FAccepting := False;
    FStopRequested := True;
    if Assigned(FActivePrompt) then
    begin
      FActiveCancelled := True;
      FActiveCancellationReason := 'OpenAI provider stopped.';
    end;
    lFinished := Assigned(FWorker) and FWorker.Finished;
    if lFinished then
    begin
      lWorker := FWorker;
      FWorker := nil;
    end
    else if Assigned(FWorker) then
      FWorker.Terminate;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  FailAllQueued('OpenAI provider stopped.');
  FWake.SetEvent;
  if Assigned(lWorker) then
  begin
    lWorker.WaitFor;
    lWorker.Free;
    ThreadStopped;
  end
  else if not lHasWorker then
    ThreadStopped;
end;

procedure TNXOpenAIProvider.Shutdown;
var
  lWorker: TNXOpenAIProviderThread;
begin
  EnterCriticalSection(FCriticalSection);
  try
    if FShuttingDown then
      Exit;
    FShuttingDown := True;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  Stop;
  EnterCriticalSection(FCriticalSection);
  try
    lWorker := FWorker;
    FWorker := nil;
    if Assigned(lWorker) then
      lWorker.Terminate;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  FWake.SetEvent;
  if Assigned(lWorker) then
  begin
    lWorker.WaitFor;
    lWorker.Free;
  end;
  FailAllQueued('OpenAI provider is shutting down.');
  ThreadStopped;
end;

function TNXOpenAIProvider.SubmitPrompt(APrompt: TNXBotPrompt): Boolean;
begin
  Result := False;
  if not Assigned(APrompt) then
    Exit;
  EnterCriticalSection(FCriticalSection);
  try
    if FAccepting and (FPrompts.Count < Configuration.PromptCapacity) then
    begin
      FPrompts.Add(APrompt);
      Result := True;
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  if Result then
    FWake.SetEvent
  else
    APrompt.Free;
end;

procedure TNXOpenAIProvider.CancelQueued(const ARoomJID,
  AReason: UTF8String; AMatchRoom: Boolean);
var
  lCancelled: TObjectList;
  lIndex: Integer;
  lPrompt: TNXBotPrompt;
begin
  lCancelled := TObjectList.Create(True);
  try
    EnterCriticalSection(FCriticalSection);
    try
      for lIndex := FPrompts.Count - 1 downto 0 do
      begin
        lPrompt := TNXBotPrompt(FPrompts[lIndex]);
        if (not AMatchRoom) or (lPrompt.RoomJID = ARoomJID) then
          lCancelled.Add(FPrompts.Extract(lPrompt));
      end;
      if Assigned(FActivePrompt) and
        ((not AMatchRoom) or (FActivePrompt.RoomJID = ARoomJID)) then
      begin
        FActiveCancelled := True;
        FActiveCancellationReason := AReason;
      end;
    finally
      LeaveCriticalSection(FCriticalSection);
    end;
    for lIndex := 0 to lCancelled.Count - 1 do
      PromptFailed(TNXBotPrompt(lCancelled[lIndex]), AReason);
  finally
    lCancelled.Free;
  end;
end;

function TNXOpenAIProvider.CancelPrompts(const AReason: UTF8String): Boolean;
begin
  CancelQueued('', AReason, False);
  Result := True;
end;

function TNXOpenAIProvider.CancelRoomPrompts(const ARoomJID,
  AReason: UTF8String): Boolean;
begin
  if ARoomJID = '' then
    Exit(False);
  CancelQueued(ARoomJID, AReason, True);
  Result := True;
end;

function TNXOpenAIProvider.TakePrompt: TNXBotPrompt;
begin
  Result := nil;
  EnterCriticalSection(FCriticalSection);
  try
    if FPrompts.Count > 0 then
    begin
      Result := TNXBotPrompt(FPrompts.Extract(FPrompts[0]));
      FActivePrompt := Result;
      FActiveCancelled := False;
      FActiveCancellationReason := '';
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TNXOpenAIProvider.CompleteActive(APrompt: TNXBotPrompt;
  ASuccess: Boolean; const AResponseID: UTF8String;
  out ACancellationReason: UTF8String): Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := (FActivePrompt = APrompt) and not FActiveCancelled;
    ACancellationReason := FActiveCancellationReason;
    if Result and ASuccess then
      FPreviousResponseID := AResponseID;
    if FActivePrompt = APrompt then
    begin
      FActivePrompt := nil;
      FActiveCancelled := False;
      FActiveCancellationReason := '';
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXOpenAIProvider.FailAllQueued(const AReason: UTF8String);
begin
  CancelQueued('', AReason, False);
end;

procedure TNXOpenAIProvider.FailFatally(APrompt: TNXBotPrompt;
  const AReason: UTF8String);
var
  lCancellationReason: UTF8String;
  lReason: UTF8String;
begin
  lReason := AReason;
  if lReason = '' then
    lReason := 'OpenAI provider failed.';
  if CompleteActive(APrompt, False, '', lCancellationReason) then
    PromptFailed(APrompt, lReason)
  else
    PromptFailed(APrompt, lCancellationReason);
  APrompt.Free;
  EnterCriticalSection(FCriticalSection);
  try
    FAccepting := False;
    FStopRequested := True;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  FailAllQueued(lReason);
  SetState(bpsFailed, lReason);
end;

procedure TNXOpenAIProvider.ReturnToReady;
var
  lStopped: Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    lStopped := FStopRequested;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  if not lStopped and (State = bpsWorking) then
    SetState(bpsReady);
end;

procedure TNXOpenAIProvider.ProcessPrompt(APrompt: TNXBotPrompt);
var
  lAnswer: UTF8String;
  lCancellationReason: UTF8String;
  lData: TJSONData;
  lDiagnostic: UTF8String;
  lHTTP: TNXOpenAIHTTPResult;
  lRequest: TNXOpenAIResponseRequest;
  lRequestData: TJSONData;
  lResponse: TNXOpenAIResponse;
  lRefusal: UTF8String;
  lSuccess: Boolean;
begin
  SetState(bpsWorking);
  lRequest := TNXOpenAIResponseRequest.Create;
  lRequestData := nil;
  try
    lRequest.model.Value := UTF8String(Configuration.Model);
    lRequest.instructions.Value := Instructions;
    lRequest.input.Value := APrompt.ModelInput;
    lRequest.store.Value := True;
    lRequest.stream.Value := False;
    if FPreviousResponseID <> '' then
      lRequest.previous_response_id.Value := FPreviousResponseID;
    lRequestData := lRequest.ToJSONData;
    try
      lSuccess := FExecutor.Execute(FAPIKey,
        UTF8String(Configuration.OpenAICAFile),
        UTF8String(lRequestData.AsJSON), Configuration.RequestTimeoutMS,
        lHTTP);
    except
      on E: Exception do
      begin
        lHTTP := Default(TNXOpenAIHTTPResult);
        lHTTP.ErrorText := 'OpenAI request failed: ' + UTF8String(E.Message);
        lHTTP.Fatal := True;
        lSuccess := False;
      end;
    end;
  finally
    lRequestData.Free;
    lRequest.Free;
  end;
  if not lSuccess then
  begin
    lDiagnostic := BoundedDiagnostic(lHTTP.ErrorText);
    if lHTTP.Fatal then
      FailFatally(APrompt, lDiagnostic)
    else
    begin
      if CompleteActive(APrompt, False, '', lCancellationReason) then
        PromptFailed(APrompt, lDiagnostic)
      else
        PromptFailed(APrompt, lCancellationReason);
      APrompt.Free;
      ReturnToReady;
    end;
    Exit;
  end;
  if (lHTTP.Status < 200) or (lHTTP.Status >= 300) then
  begin
    lDiagnostic := ErrorMessageFromBody(lHTTP.Body);
    if lDiagnostic = '' then
      lDiagnostic := 'OpenAI HTTP status ' +
        UTF8String(IntToStr(lHTTP.Status)) + '.';
    if (lHTTP.Status = 400) or (lHTTP.Status = 401) or
      (lHTTP.Status = 403) or (lHTTP.Status = 404) then
      FailFatally(APrompt, lDiagnostic)
    else
    begin
      if CompleteActive(APrompt, False, '', lCancellationReason) then
        PromptFailed(APrompt, lDiagnostic)
      else
        PromptFailed(APrompt, lCancellationReason);
      APrompt.Free;
      ReturnToReady;
    end;
    Exit;
  end;
  lData := nil;
  lResponse := TNXOpenAIResponse.Create;
  try
    try
      lData := GetJSON(string(lHTTP.Body));
      lResponse.FromJSONData(lData);
    except
      on E: Exception do
      begin
        FailFatally(APrompt, 'Invalid OpenAI response: ' +
          BoundedDiagnostic(UTF8String(E.Message)));
        Exit;
      end;
    end;
    if lResponse.error.Assigned and not lResponse.error.IsNull then
    begin
      lDiagnostic := lResponse.error.message.Value;
      if lDiagnostic = '' then
        lDiagnostic := 'OpenAI returned an error response.';
      if CompleteActive(APrompt, False, '', lCancellationReason) then
        PromptFailed(APrompt, BoundedDiagnostic(lDiagnostic))
      else
        PromptFailed(APrompt, lCancellationReason);
      APrompt.Free;
      ReturnToReady;
      Exit;
    end;
    if lResponse.status.Value <> 'completed' then
    begin
      if lResponse.error.Assigned and not lResponse.error.IsNull then
        lDiagnostic := lResponse.error.message.Value
      else if lResponse.incomplete_details.Assigned and
        not lResponse.incomplete_details.IsNull then
        lDiagnostic := 'OpenAI response incomplete: ' +
          lResponse.incomplete_details.reason.Value
      else
        lDiagnostic := 'OpenAI response status: ' + lResponse.status.Value;
      if CompleteActive(APrompt, False, '', lCancellationReason) then
        PromptFailed(APrompt, BoundedDiagnostic(lDiagnostic))
      else
        PromptFailed(APrompt, lCancellationReason);
      APrompt.Free;
      ReturnToReady;
      Exit;
    end;
    if (lResponse.id.Value = '') or
      not lResponse.ExtractCompletedText(lAnswer, lRefusal) then
    begin
      if lRefusal <> '' then
        lDiagnostic := 'OpenAI refusal: ' + lRefusal
      else if lResponse.id.Value = '' then
        lDiagnostic := 'OpenAI completed response has no ID.'
      else
        lDiagnostic := 'OpenAI completed response has no assistant text.';
      if CompleteActive(APrompt, False, '', lCancellationReason) then
        PromptFailed(APrompt, BoundedDiagnostic(lDiagnostic))
      else
        PromptFailed(APrompt, lCancellationReason);
      APrompt.Free;
      ReturnToReady;
      Exit;
    end;
    lAnswer := BoundAnswer(lAnswer, Configuration.AnswerMaximumBytes);
    if CompleteActive(APrompt, True, lResponse.id.Value,
      lCancellationReason) then
      FinalAnswer(APrompt, lAnswer)
    else
      PromptFailed(APrompt, lCancellationReason);
    APrompt.Free;
    ReturnToReady;
  finally
    lResponse.Free;
    lData.Free;
  end;
end;

procedure TNXOpenAIProvider.ThreadExecute;
var
  lPrompt: TNXBotPrompt;
  lStop: Boolean;
begin
  FAPIKey := UTF8String(Configuration.OpenAIAPIKey);
  if FAPIKey = '' then
  begin
    EnterCriticalSection(FCriticalSection);
    try
      FAccepting := False;
      FStopRequested := True;
    finally
      LeaveCriticalSection(FCriticalSection);
    end;
    SetState(bpsFailed, 'OpenAI API key is empty.');
    FailAllQueued('OpenAI API key is empty.');
    Exit;
  end;
  SetState(bpsReady);
  repeat
    lPrompt := TakePrompt;
    if Assigned(lPrompt) then
      ProcessPrompt(lPrompt)
    else
      FWake.WaitFor(INFINITE);
    EnterCriticalSection(FCriticalSection);
    try
      lStop := FStopRequested or FWorker.Terminated;
    finally
      LeaveCriticalSection(FCriticalSection);
    end;
  until lStop;
  FAPIKey := '';
  FPreviousResponseID := '';
  if State <> bpsFailed then
    SetState(bpsStopped);
end;

procedure TNXOpenAIProvider.ThreadStopped;
begin
  EnterCriticalSection(FCriticalSection);
  try
    FAPIKey := '';
    FPreviousResponseID := '';
    FAccepting := False;
    FStopRequested := True;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  SetState(bpsStopped);
end;

initialization
  TNXBotProviderRegistry.RegisterProvider(TNXOpenAIProvider);

end.
