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
    function Execute(const AAPIKey, ABody: UTF8String;
      ATimeoutMS: Cardinal; out AResult: TNXOpenAIHTTPResult): Boolean;
      virtual; abstract;
  end;

  TNXOpenAIWinHTTPExecutor = class(TNXOpenAIExecutor)
  public
    function Execute(const AAPIKey, ABody: UTF8String;
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
  obNXOpenAIResponses
  {$ifdef windows}
  , Windows,
  WinHttp
  {$endif}
  ;

const
  cOpenAIResponseMaximumBytes = 1024 * 1024;

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

{$ifdef windows}
function NXWinHttpSetTimeouts(AHandle: HINTERNET; AResolveTimeout,
  AConnectTimeout, ASendTimeout, AReceiveTimeout: Integer): WINBOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpSetTimeouts';

function SecureWinHTTPError(AError: Cardinal): Boolean;
begin
  case AError of
    ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED,
    ERROR_WINHTTP_SECURE_FAILURE,
    ERROR_WINHTTP_SECURE_CERT_DATE_INVALID,
    ERROR_WINHTTP_SECURE_CERT_CN_INVALID,
    ERROR_WINHTTP_SECURE_INVALID_CA,
    ERROR_WINHTTP_SECURE_CERT_REV_FAILED,
    ERROR_WINHTTP_SECURE_CHANNEL_ERROR,
    ERROR_WINHTTP_SECURE_INVALID_CERT,
    ERROR_WINHTTP_SECURE_CERT_REVOKED,
    ERROR_WINHTTP_SECURE_CERT_WRONG_USAGE:
      Result := True;
  else
    Result := False;
  end;
end;

function WinHTTPFailure(out AResult: TNXOpenAIHTTPResult): Boolean;
begin
  AResult.ErrorCode := GetLastError;
  AResult.ErrorText := UTF8String(SysErrorMessage(AResult.ErrorCode));
  AResult.Fatal := SecureWinHTTPError(AResult.ErrorCode);
  Result := False;
end;
{$endif}

function TNXOpenAIWinHTTPExecutor.Execute(const AAPIKey,
  ABody: UTF8String; ATimeoutMS: Cardinal;
  out AResult: TNXOpenAIHTTPResult): Boolean;
{$ifdef windows}
var
  lBody: RawByteString;
  lBytesRead: DWORD;
  lConnect: HINTERNET;
  lHeaders: UnicodeString;
  lOldLength: Integer;
  lRequest: HINTERNET;
  lSession: HINTERNET;
  lStatus: DWORD;
  lStatusSize: DWORD;
  lTimeout: Integer;
  lBuffer: array[0..8191] of Byte;
{$endif}
begin
  AResult := Default(TNXOpenAIHTTPResult);
  {$ifdef windows}
  lSession := WinHttpOpen('NexusBotHost/1.0',
    WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, WINHTTP_NO_PROXY_NAME,
    WINHTTP_NO_PROXY_BYPASS, 0);
  if lSession = nil then
    Exit(WinHTTPFailure(AResult));
  try
    lTimeout := Integer(ATimeoutMS);
    if not NXWinHttpSetTimeouts(lSession, lTimeout, lTimeout,
      lTimeout, lTimeout) then
      Exit(WinHTTPFailure(AResult));
    lConnect := WinHttpConnect(lSession, 'api.openai.com',
      INTERNET_DEFAULT_HTTPS_PORT, 0);
    if lConnect = nil then
      Exit(WinHTTPFailure(AResult));
    try
      lRequest := WinHttpOpenRequest(lConnect, 'POST', '/v1/responses', nil,
        WINHTTP_NO_REFERER, nil, WINHTTP_FLAG_SECURE);
      if lRequest = nil then
        Exit(WinHTTPFailure(AResult));
      try
        lHeaders := UnicodeString('Content-Type: application/json'#13#10 +
          'Authorization: Bearer ' + AAPIKey);
        if Length(ABody) > 0 then
          Result := WinHttpSendRequest(lRequest, PWideChar(lHeaders),
            Length(lHeaders), Pointer(ABody), Length(ABody), Length(ABody), 0)
        else
          Result := WinHttpSendRequest(lRequest, PWideChar(lHeaders),
            Length(lHeaders), nil, 0, 0, 0);
        if not Result then
          Exit(WinHTTPFailure(AResult));
        if not WinHttpReceiveResponse(lRequest, nil) then
          Exit(WinHTTPFailure(AResult));
        lStatus := 0;
        lStatusSize := SizeOf(lStatus);
        if not WinHttpQueryHeaders(lRequest,
          WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER, nil,
          @lStatus, @lStatusSize, WINHTTP_NO_HEADER_INDEX) then
          Exit(WinHTTPFailure(AResult));
        AResult.Status := lStatus;
        lBody := '';
        repeat
          lBytesRead := 0;
          if not WinHttpReadData(lRequest, @lBuffer[0], SizeOf(lBuffer),
            @lBytesRead) then
            Exit(WinHTTPFailure(AResult));
          if lBytesRead = 0 then
            Break;
          if Length(lBody) + Integer(lBytesRead) >
            cOpenAIResponseMaximumBytes then
          begin
            AResult.ErrorText := 'OpenAI response exceeds the protocol limit.';
            AResult.Fatal := True;
            Exit(False);
          end;
          lOldLength := Length(lBody);
          SetLength(lBody, lOldLength + lBytesRead);
          Move(lBuffer[0], lBody[lOldLength + 1], lBytesRead);
        until False;
        AResult.Body := UTF8String(lBody);
        Result := True;
      finally
        WinHttpCloseHandle(lRequest);
      end;
    finally
      WinHttpCloseHandle(lConnect);
    end;
  finally
    WinHttpCloseHandle(lSession);
  end;
  {$else}
  AResult.ErrorText := 'The OpenAI provider is not supported on this platform.';
  AResult.Fatal := True;
  Result := False;
  {$endif}
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
  CreateWithExecutor(TNXOpenAIWinHTTPExecutor.Create);
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
var
  lName: string;
begin
  if not Assigned(ABinding) then
    Exit;
  lName := Trim(ABinding.OpenAIAPIKeyEnvironmentVariable);
  if lName = '' then
    ADiagnostics.Add('Missing deployment field ' +
      'OpenAIAPIKeyEnvironmentVariable for bot ' + ABotName + '.')
  else if Pos('=', lName) > 0 then
    ADiagnostics.Add('Invalid deployment field ' +
      'OpenAIAPIKeyEnvironmentVariable for bot ' + ABotName + '.');
end;

function TNXOpenAIProvider.Start: Boolean;
var
  lFinishedWorker: TNXOpenAIProviderThread;
  lVariableName: string;
begin
  Result := False;
  if not (State in [bpsStopped, bpsFailed]) then
    Exit;
  {$ifndef windows}
  SetState(bpsFailed, 'The OpenAI provider is not supported on this platform.');
  Exit(True);
  {$endif}
  lVariableName := Trim(Configuration.OpenAIAPIKeyEnvironmentVariable);
  if (lVariableName = '') or (Pos('=', lVariableName) > 0) then
  begin
    SetState(bpsFailed,
      'OpenAI API key environment-variable name is invalid.');
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
    lRequest.input.Value := APrompt.Body;
    lRequest.store.Value := True;
    lRequest.stream.Value := False;
    if FPreviousResponseID <> '' then
      lRequest.previous_response_id.Value := FPreviousResponseID;
    lRequestData := lRequest.ToJSONData;
    try
      lSuccess := FExecutor.Execute(FAPIKey,
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
  FAPIKey := UTF8String(SysUtils.GetEnvironmentVariable(
    Configuration.OpenAIAPIKeyEnvironmentVariable));
  if FAPIKey = '' then
  begin
    EnterCriticalSection(FCriticalSection);
    try
      FAccepting := False;
      FStopRequested := True;
    finally
      LeaveCriticalSection(FCriticalSection);
    end;
    SetState(bpsFailed, 'OpenAI API key environment variable is empty: ' +
      UTF8String(Configuration.OpenAIAPIKeyEnvironmentVariable));
    FailAllQueued('OpenAI API key environment variable is empty.');
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
