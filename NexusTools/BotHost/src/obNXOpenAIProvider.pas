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
  obNXOpenAIResponses,
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
    function UploadFile(const AAPIKey, ACAFile, AFileName,
      ADisplayName, AMediaType: UTF8String; ATimeoutMS: Cardinal;
      out AResult: TNXOpenAIHTTPResult): Boolean; virtual; abstract;
    function DeleteFile(const AAPIKey, ACAFile, AFileID: UTF8String;
      ATimeoutMS: Cardinal; out AResult: TNXOpenAIHTTPResult): Boolean;
      virtual; abstract;
  end;

  TNXOpenAISynapseExecutor = class(TNXOpenAIExecutor)
  public
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
    FUploadedFiles: TStringList;
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
    function CancellationRequested(out AReason: UTF8String): Boolean;
    procedure ExecuteShellCommand(const ACommand: UTF8String;
      ATimeoutMS, AOutputMaximum: Integer; out AStdOut, AStdErr: UTF8String;
      out AExitCode: Integer; out ATimedOut: Boolean);
    function WorkspaceInstructions: UTF8String;
    procedure ContinueShell(APrompt: TNXBotPrompt;
      AInitialResponse: TNXOpenAIResponse; AUploadedStart: Integer);
    function AddPromptAttachments(APrompt: TNXBotPrompt;
      AInputMessage: TNXOpenAIInputMessage;
      out ADiagnostic: UTF8String): Boolean;
    procedure DeleteUploadedFilesFrom(AIndex: Integer);
    procedure DeleteUploadedFiles;
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
  obNXJSONValues,
  obNXOpenAIFiles,
  obNXBotWorkspace,
  Process,
  Pipes,
  ssl_openssl3,
  tpNXBotFileTypes;

const
  cOpenAIResponseMaximumBytes = 1024 * 1024;

type
  ENXOpenAIResponseLimit = class(Exception);

  TNXOpenAIBoundedStream = class(TMemoryStream)
  public
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

  TNXOpenAIMultipartStream = class(TStream)
  private
    FFile: TFileStream;
    FPrefix: RawByteString;
    FPosition: Int64;
    FSuffix: RawByteString;
  public
    constructor Create(const AFileName: string; const APrefix,
      ASuffix: RawByteString);
    destructor Destroy; override;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

constructor TNXOpenAIMultipartStream.Create(const AFileName: string;
  const APrefix, ASuffix: RawByteString);
begin
  inherited Create;
  FPrefix := APrefix;
  FSuffix := ASuffix;
  FFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
end;

destructor TNXOpenAIMultipartStream.Destroy;
begin
  FFile.Free;
  inherited Destroy;
end;

function TNXOpenAIMultipartStream.Read(var ABuffer;
  ACount: LongInt): LongInt;
var
  lAvailable: Int64;
  lCount: LongInt;
  lOffset: Int64;
begin
  Result := 0;
  if ACount <= 0 then Exit;
  if FPosition < Length(FPrefix) then
  begin
    lAvailable := Length(FPrefix) - FPosition;
    lCount := ACount;
    if lCount > lAvailable then lCount := lAvailable;
    Move(FPrefix[FPosition + 1], ABuffer, lCount);
  end
  else if FPosition < Length(FPrefix) + FFile.Size then
  begin
    lOffset := FPosition - Length(FPrefix);
    FFile.Position := lOffset;
    Result := FFile.Read(ABuffer, ACount);
    Inc(FPosition, Result);
    Exit;
  end
  else
  begin
    lOffset := FPosition - Length(FPrefix) - FFile.Size;
    lAvailable := Length(FSuffix) - lOffset;
    if lAvailable <= 0 then Exit;
    lCount := ACount;
    if lCount > lAvailable then lCount := lAvailable;
    Move(FSuffix[lOffset + 1], ABuffer, lCount);
  end;
  Result := lCount;
  Inc(FPosition, Result);
end;

function TNXOpenAIMultipartStream.Seek(const AOffset: Int64;
  AOrigin: TSeekOrigin): Int64;
var
  lSize: Int64;
begin
  lSize := Length(FPrefix) + FFile.Size + Length(FSuffix);
  case AOrigin of
    soBeginning: FPosition := AOffset;
    soCurrent: Inc(FPosition, AOffset);
    soEnd: FPosition := lSize + AOffset;
  end;
  if FPosition < 0 then FPosition := 0;
  if FPosition > lSize then FPosition := lSize;
  Result := FPosition;
end;

function TNXOpenAIMultipartStream.Write(const ABuffer;
  ACount: LongInt): LongInt;
begin
  Result := 0;
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

function TNXOpenAISynapseExecutor.UploadFile(const AAPIKey, ACAFile,
  AFileName, ADisplayName, AMediaType: UTF8String; ATimeoutMS: Cardinal;
  out AResult: TNXOpenAIHTTPResult): Boolean;
var
  lBody: RawByteString;
  lBoundary: RawByteString;
  lDisplayName: UTF8String;
  lHTTP: THTTPSend;
  lInput: TNXOpenAIMultipartStream;
  lMediaType: UTF8String;
  lPrefix: RawByteString;
  lResponse: TNXOpenAIBoundedStream;
  lSuffix: RawByteString;
  lTimeout: Integer;
begin
  AResult := Default(TNXOpenAIHTTPResult);
  if not FileExists(string(AFileName)) then
  begin
    AResult.ErrorText := 'The staged OpenAI input file is unavailable.';
    Exit(False);
  end;
  lDisplayName := StringReplace(ADisplayName, '"', '', [rfReplaceAll]);
  lDisplayName := StringReplace(lDisplayName, #13, '', [rfReplaceAll]);
  lDisplayName := StringReplace(lDisplayName, #10, '', [rfReplaceAll]);
  lMediaType := AMediaType;
  if lMediaType = '' then
    lMediaType := 'application/octet-stream';
  lBoundary := '----NexusBotHost' + RawByteString(IntToHex(GetTickCount64, 16));
  lPrefix := '--' + lBoundary + #13#10 +
    'Content-Disposition: form-data; name="purpose"' + #13#10#13#10 +
    'user_data' + #13#10 + '--' + lBoundary + #13#10 +
    'Content-Disposition: form-data; name="expires_after[anchor]"' +
    #13#10#13#10 + 'created_at' + #13#10 + '--' + lBoundary + #13#10 +
    'Content-Disposition: form-data; name="expires_after[seconds]"' +
    #13#10#13#10 + '86400' + #13#10 + '--' + lBoundary + #13#10 +
    'Content-Disposition: form-data; name="file"; filename="' +
    RawByteString(lDisplayName) + '"' + #13#10 + 'Content-Type: ' +
    RawByteString(lMediaType) + #13#10#13#10;
  lSuffix := #13#10 + '--' + lBoundary + '--' + #13#10;
  lInput := TNXOpenAIMultipartStream.Create(string(AFileName), lPrefix,
    lSuffix);
  lHTTP := THTTPSend.Create;
  lResponse := TNXOpenAIBoundedStream.Create;
  try
    if ATimeoutMS > Cardinal(High(Integer)) then lTimeout := High(Integer)
    else lTimeout := ATimeoutMS;
    lHTTP.Timeout := lTimeout;
    lHTTP.Sock.ConnectionTimeout := lTimeout;
    lHTTP.Sock.SSL.VerifyCert := True;
    lHTTP.Sock.SSL.CertCAFile := string(ACAFile);
    lHTTP.UserAgent := 'NexusBotHost/1.0';
    lHTTP.MimeType := 'multipart/form-data; boundary=' + string(lBoundary);
    lHTTP.Headers.Add('Authorization: Bearer ' + string(AAPIKey));
    lHTTP.InputStream := lInput;
    lHTTP.OutputStream := lResponse;
    Result := lHTTP.HTTPMethod('POST', 'https://api.openai.com/v1/files');
    AResult.Status := Cardinal(lHTTP.ResultCode);
    if not Result then
    begin
      AResult.ErrorCode := Cardinal(lHTTP.Sock.LastError);
      AResult.ErrorText := UTF8String(lHTTP.Sock.GetErrorDescEx);
      Exit(False);
    end;
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
    lInput.Free;
  end;
end;

function TNXOpenAISynapseExecutor.DeleteFile(const AAPIKey, ACAFile,
  AFileID: UTF8String; ATimeoutMS: Cardinal;
  out AResult: TNXOpenAIHTTPResult): Boolean;
var
  lHTTP: THTTPSend;
  lResponse: TNXOpenAIBoundedStream;
  lTimeout: Integer;
begin
  AResult := Default(TNXOpenAIHTTPResult);
  lHTTP := THTTPSend.Create;
  lResponse := TNXOpenAIBoundedStream.Create;
  try
    if ATimeoutMS > Cardinal(High(Integer)) then lTimeout := High(Integer)
    else lTimeout := ATimeoutMS;
    lHTTP.Timeout := lTimeout;
    lHTTP.Sock.ConnectionTimeout := lTimeout;
    lHTTP.Sock.SSL.VerifyCert := True;
    lHTTP.Sock.SSL.CertCAFile := string(ACAFile);
    lHTTP.Headers.Add('Authorization: Bearer ' + string(AAPIKey));
    lHTTP.OutputStream := lResponse;
    Result := lHTTP.HTTPMethod('DELETE',
      'https://api.openai.com/v1/files/' + string(AFileID));
    AResult.Status := Cardinal(lHTTP.ResultCode);
    if not Result then
      AResult.ErrorText := UTF8String(lHTTP.Sock.GetErrorDescEx);
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
  FUploadedFiles := TStringList.Create;
  FUploadedFiles.CaseSensitive := True;
  FUploadedFiles.NameValueSeparator := '=';
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
  FUploadedFiles.Free;
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

function TNXOpenAIProvider.CancellationRequested(
  out AReason: UTF8String): Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FStopRequested or FActiveCancelled;
    AReason := FActiveCancellationReason;
    if FStopRequested and (AReason = '') then
      AReason := 'OpenAI provider stopped.';
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TNXOpenAIProvider.WorkspaceInstructions: UTF8String;
var
  lIndex: Integer;
  lWorkspace: TNXBotWorkspaceAccess;
begin
  Result := '';
  if Configuration.Workspaces.Count = 0 then
    Exit;
  Result := LineEnding + LineEnding + 'Reference workspaces:';
  for lIndex := 0 to Configuration.Workspaces.Count - 1 do
  begin
    lWorkspace := Configuration.Workspaces[lIndex];
    Result := Result + LineEnding + '- ' + lWorkspace.Name;
    if lWorkspace.Purpose <> '' then
      Result := Result + ': ' + lWorkspace.Purpose;
    Result := Result + LineEnding + '  Repository: ' +
      UTF8String(lWorkspace.RepositoryPath) + LineEnding + '  Cache: ' +
      UTF8String(lWorkspace.CachePath) + LineEnding + '  Commit: ' +
      lWorkspace.ResolvedCommit;
  end;
  Result := Result + LineEnding +
    'Treat repositories as read-only references and write task-local files ' +
    'only beneath the corresponding cache path.';
end;

procedure TNXOpenAIProvider.ExecuteShellCommand(const ACommand: UTF8String;
  ATimeoutMS, AOutputMaximum: Integer; out AStdOut, AStdErr: UTF8String;
  out AExitCode: Integer; out ATimedOut: Boolean);
var
  lBuffer: array[0..4095] of Byte;
  lChunk: RawByteString;
  lCount: LongInt;
  lDeadline: QWord;
  lProcess: TProcess;
  lRemaining: Integer;

  procedure Drain(AStream: TInputPipeStream; var AText: UTF8String);
  begin
    while AStream.NumBytesAvailable > 0 do
    begin
      lCount := AStream.Read(lBuffer, SizeOf(lBuffer));
      if lCount <= 0 then
        Exit;
      if lRemaining > 0 then
      begin
        if lCount > lRemaining then
          lCount := lRemaining;
        SetLength(lChunk, lCount);
        Move(lBuffer[0], lChunk[1], lCount);
        AText := AText + UTF8String(lChunk);
        Dec(lRemaining, lCount);
      end;
    end;
  end;

begin
  AStdOut := '';
  AStdErr := '';
  AExitCode := -1;
  ATimedOut := False;
  lRemaining := AOutputMaximum;
  lProcess := TProcess.Create(nil);
  try
    {$IFDEF Windows}
    lProcess.Executable := GetEnvironmentVariable('COMSPEC');
    if lProcess.Executable = '' then
      lProcess.Executable := 'cmd.exe';
    lProcess.Parameters.Add('/D');
    lProcess.Parameters.Add('/S');
    lProcess.Parameters.Add('/C');
    {$ELSE}
    lProcess.Executable := '/bin/sh';
    lProcess.Parameters.Add('-c');
    {$ENDIF}
    lProcess.Parameters.Add(string(ACommand));
    lProcess.CurrentDirectory := Configuration.RuntimeDirectory;
    lProcess.Options := [poUsePipes, poNoConsole];
    lProcess.Execute;
    lDeadline := GetTickCount64 + QWord(ATimeoutMS);
    while lProcess.Running do
    begin
      Drain(lProcess.Output, AStdOut);
      Drain(lProcess.Stderr, AStdErr);
      if GetTickCount64 >= lDeadline then
      begin
        ATimedOut := True;
        lProcess.Terminate(1);
        Break;
      end;
      TThread.Yield;
    end;
    lProcess.WaitOnExit;
    Drain(lProcess.Output, AStdOut);
    Drain(lProcess.Stderr, AStdErr);
    AExitCode := lProcess.ExitStatus;
  finally
    lProcess.Free;
  end;
end;

procedure TNXOpenAIProvider.ProcessPrompt(APrompt: TNXBotPrompt);
var
  lAnswer: UTF8String;
  lCancellationReason: UTF8String;
  lData: TJSONData;
  lDiagnostic: UTF8String;
  lHTTP: TNXOpenAIHTTPResult;
  lInputMessage: TNXOpenAIInputMessage;
  lInputText: TNXOpenAIInputText;
  lUploadedStart: Integer;
  lRequest: TNXOpenAIResponseRequest;
  lRequestData: TJSONData;
  lResponse: TNXOpenAIResponse;
  lShellCall: TNXOpenAIShellCall;
  lOutputIndex: Integer;
  lShellTool: TNXOpenAIShellTool;
  lRefusal: UTF8String;
  lSuccess: Boolean;
begin
  SetState(bpsWorking);
  lUploadedStart := FUploadedFiles.Count;
  lRequest := TNXOpenAIResponseRequest.Create;
  lRequestData := nil;
  try
    lRequest.model.Value := UTF8String(Configuration.Model);
    lRequest.instructions.Value := Instructions + WorkspaceInstructions;
    lInputMessage := TNXOpenAIInputMessage(lRequest.input.AddObject(
      TNXOpenAIInputMessage));
    lInputMessage.&type.Value := 'message';
    lInputMessage.role.Value := 'user';
    lInputText := TNXOpenAIInputText(lInputMessage.content.AddObject(
      TNXOpenAIInputText));
    lInputText.&type.Value := 'input_text';
    lInputText.text.Value := APrompt.ModelInput;
    if not AddPromptAttachments(APrompt, lInputMessage, lDiagnostic) then
    begin
      DeleteUploadedFilesFrom(lUploadedStart);
      if CompleteActive(APrompt, False, '', lCancellationReason) then
        PromptFailed(APrompt, BoundedDiagnostic(lDiagnostic))
      else
        PromptFailed(APrompt, lCancellationReason);
      APrompt.Free;
      ReturnToReady;
      Exit;
    end;
    lRequest.store.Value := True;
    lRequest.stream.Value := False;
    if Configuration.Workspaces.Count > 0 then
    begin
      lRequest.parallel_tool_calls.Value := False;
      lShellTool := TNXOpenAIShellTool(lRequest.tools.AddObject(
        TNXOpenAIShellTool));
      lShellTool.&type.Value := 'shell';
      lShellTool.environment.&type.Value := 'local';
    end;
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
    DeleteUploadedFilesFrom(lUploadedStart);
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
    DeleteUploadedFilesFrom(lUploadedStart);
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
        DeleteUploadedFilesFrom(lUploadedStart);
        FailFatally(APrompt, 'Invalid OpenAI response: ' +
          BoundedDiagnostic(UTF8String(E.Message)));
        Exit;
      end;
    end;
    if lResponse.error.Assigned and not lResponse.error.IsNull then
    begin
      DeleteUploadedFilesFrom(lUploadedStart);
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
      DeleteUploadedFilesFrom(lUploadedStart);
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
    lShellCall := nil;
    for lOutputIndex := 0 to lResponse.output.Count - 1 do
      if lResponse.output[lOutputIndex] is TNXOpenAIShellCall then
      begin
        lShellCall := TNXOpenAIShellCall(lResponse.output[lOutputIndex]);
        Break;
      end;
    if Assigned(lShellCall) then
    begin
      ContinueShell(APrompt, lResponse, lUploadedStart);
      Exit;
    end;
    if (lResponse.id.Value = '') or
      not lResponse.ExtractCompletedText(lAnswer, lRefusal) then
    begin
      DeleteUploadedFilesFrom(lUploadedStart);
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

procedure TNXOpenAIProvider.ContinueShell(APrompt: TNXBotPrompt;
  AInitialResponse: TNXOpenAIResponse; AUploadedStart: Integer);
var
  lAnswer: UTF8String;
  lCallCount: Integer;
  lCancellationReason: UTF8String;
  lCommand: UTF8String;
  lCommandIndex: Integer;
  lData: TJSONData;
  lDiagnostic: UTF8String;
  lExitCode: Integer;
  lHTTP: TNXOpenAIHTTPResult;
  lInput: TNXOpenAIShellCallOutput;
  lMaximumOutput: Integer;
  lOutput: TNXOpenAIShellOutput;
  lOutputIndex: Integer;
  lOwnedResponse: TNXOpenAIResponse;
  lRefusal: UTF8String;
  lRequest: TNXOpenAIResponseRequest;
  lRequestData: TJSONData;
  lResponse: TNXOpenAIResponse;
  lShellCall: TNXOpenAIShellCall;
  lShellTool: TNXOpenAIShellTool;
  lStdErr: UTF8String;
  lStdOut: UTF8String;
  lSuccess: Boolean;
  lTimedOut: Boolean;
  lTimeoutMS: Integer;

  procedure Fail(const AReason: UTF8String);
  begin
    DeleteUploadedFilesFrom(AUploadedStart);
    if CompleteActive(APrompt, False, '', lCancellationReason) then
      PromptFailed(APrompt, BoundedDiagnostic(AReason))
    else
      PromptFailed(APrompt, lCancellationReason);
    APrompt.Free;
    ReturnToReady;
  end;

begin
  lCallCount := 0;
  lOwnedResponse := nil;
  lResponse := AInitialResponse;
  try
    while True do
    begin
      if CancellationRequested(lCancellationReason) then
      begin
        Fail(lCancellationReason);
        Exit;
      end;
      lShellCall := nil;
      for lOutputIndex := 0 to lResponse.output.Count - 1 do
        if lResponse.output[lOutputIndex] is TNXOpenAIShellCall then
        begin
          if Assigned(lShellCall) then
          begin
            Fail('OpenAI returned parallel shell calls.');
            Exit;
          end;
          lShellCall := TNXOpenAIShellCall(
            lResponse.output[lOutputIndex]);
        end;
      if not Assigned(lShellCall) then
      begin
        if (lResponse.id.Value = '') or
          not lResponse.ExtractCompletedText(lAnswer, lRefusal) then
        begin
          if lRefusal <> '' then
            lDiagnostic := 'OpenAI refusal: ' + lRefusal
          else
            lDiagnostic := 'OpenAI completed response has no assistant text.';
          Fail(lDiagnostic);
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
        Exit;
      end;

      Inc(lCallCount);
      if lCallCount > Configuration.ShellCallMaximum then
      begin
        Fail('OpenAI shell call limit exceeded.');
        Exit;
      end;
      if (Configuration.Workspaces.Count = 0) or
        (lResponse.id.Value = '') or (lShellCall.call_id.Value = '') or
        (lShellCall.action.commands.Count = 0) then
      begin
        Fail('OpenAI returned an invalid shell call.');
        Exit;
      end;
      lTimeoutMS := Configuration.ShellCommandTimeoutMS;
      if lShellCall.action.timeout_ms.Assigned and
        (lShellCall.action.timeout_ms.Value > 0) and
        (lShellCall.action.timeout_ms.Value < lTimeoutMS) then
        lTimeoutMS := lShellCall.action.timeout_ms.Value;
      lMaximumOutput := Configuration.ShellOutputMaximumBytes;
      if lShellCall.action.max_output_length.Assigned and
        (lShellCall.action.max_output_length.Value > 0) and
        (lShellCall.action.max_output_length.Value < lMaximumOutput) then
        lMaximumOutput := lShellCall.action.max_output_length.Value;

      lRequest := TNXOpenAIResponseRequest.Create;
      lRequestData := nil;
      try
        lRequest.model.Value := UTF8String(Configuration.Model);
        lRequest.instructions.Value := Instructions + WorkspaceInstructions;
        lRequest.previous_response_id.Value := lResponse.id.Value;
        lRequest.store.Value := True;
        lRequest.stream.Value := False;
        lRequest.parallel_tool_calls.Value := False;
        lShellTool := TNXOpenAIShellTool(lRequest.tools.AddObject(
          TNXOpenAIShellTool));
        lShellTool.&type.Value := 'shell';
        lShellTool.environment.&type.Value := 'local';
        lInput := TNXOpenAIShellCallOutput(lRequest.input.AddObject(
          TNXOpenAIShellCallOutput));
        lInput.&type.Value := 'shell_call_output';
        lInput.call_id.Value := lShellCall.call_id.Value;
        lInput.max_output_length.Value := lMaximumOutput;
        for lCommandIndex := 0 to lShellCall.action.commands.Count - 1 do
        begin
          if CancellationRequested(lCancellationReason) then
          begin
            Fail(lCancellationReason);
            Exit;
          end;
          lCommand := TNXJSONString(
            lShellCall.action.commands[lCommandIndex]).Value;
          try
            ExecuteShellCommand(lCommand, lTimeoutMS, lMaximumOutput,
              lStdOut, lStdErr, lExitCode, lTimedOut);
          except
            on E: Exception do
            begin
              Fail('Local shell execution failed: ' + UTF8String(E.Message));
              Exit;
            end;
          end;
          lOutput := TNXOpenAIShellOutput(lInput.output.AddObject(
            TNXOpenAIShellOutput));
          lOutput.stdout.Value := lStdOut;
          lOutput.stderr.Value := lStdErr;
          if lTimedOut then
            lOutput.outcome.&type.Value := 'timeout'
          else
          begin
            lOutput.outcome.&type.Value := 'exit';
            lOutput.outcome.exit_code.Value := lExitCode;
          end;
        end;
        lRequestData := lRequest.ToJSONData;
        try
          lSuccess := FExecutor.Execute(FAPIKey,
            UTF8String(Configuration.OpenAICAFile),
            UTF8String(lRequestData.AsJSON), Configuration.RequestTimeoutMS,
            lHTTP);
        except
          on E: Exception do
          begin
            lSuccess := False;
            lHTTP := Default(TNXOpenAIHTTPResult);
            lHTTP.ErrorText := UTF8String(E.Message);
          end;
        end;
      finally
        lRequestData.Free;
        lRequest.Free;
      end;
      if not lSuccess or (lHTTP.Status < 200) or (lHTTP.Status >= 300) then
      begin
        lDiagnostic := lHTTP.ErrorText;
        if lDiagnostic = '' then
          lDiagnostic := ErrorMessageFromBody(lHTTP.Body);
        if lDiagnostic = '' then
          lDiagnostic := 'OpenAI shell continuation failed.';
        Fail(lDiagnostic);
        Exit;
      end;
      lData := nil;
      try
        try
          lData := GetJSON(string(lHTTP.Body));
          FreeAndNil(lOwnedResponse);
          lOwnedResponse := TNXOpenAIResponse.Create;
          lOwnedResponse.FromJSONData(lData);
        except
          on E: Exception do
          begin
            Fail('Invalid OpenAI shell continuation response: ' +
              UTF8String(E.Message));
            Exit;
          end;
        end;
      finally
        lData.Free;
      end;
      lResponse := lOwnedResponse;
      if lResponse.status.Value <> 'completed' then
      begin
        Fail('OpenAI shell continuation did not complete.');
        Exit;
      end;
    end;
  finally
    lOwnedResponse.Free;
  end;
end;

function TNXOpenAIProvider.AddPromptAttachments(APrompt: TNXBotPrompt;
  AInputMessage: TNXOpenAIInputMessage;
  out ADiagnostic: UTF8String): Boolean;
var
  lAttachment: TNXBotAttachment;
  lData: TJSONData;
  lFile: TNXOpenAIFileObject;
  lFileID: UTF8String;
  lFileIndex: Integer;
  lHTTP: TNXOpenAIHTTPResult;
  lInputFile: TNXOpenAIInputFile;
  lInputImage: TNXOpenAIInputImage;
  lIndex: Integer;
  lSuccess: Boolean;
begin
  Result := False;
  ADiagnostic := '';
  for lIndex := 0 to APrompt.Attachments.Count - 1 do
  begin
    lAttachment := APrompt.Attachments[lIndex];
    if Pos('audio/', LowerCase(string(lAttachment.MediaType))) = 1 then
    begin
      ADiagnostic := 'OpenAI does not support this audio input.';
      Exit;
    end;
    lFileIndex := FUploadedFiles.IndexOfName(string(lAttachment.ArtifactID));
    if lFileIndex >= 0 then
      lFileID := UTF8String(FUploadedFiles.ValueFromIndex[lFileIndex])
    else
    begin
      lHTTP := Default(TNXOpenAIHTTPResult);
      try
        lSuccess := FExecutor.UploadFile(FAPIKey,
          UTF8String(Configuration.OpenAICAFile),
          UTF8String(lAttachment.Path), lAttachment.Name,
          lAttachment.MediaType, Configuration.RequestTimeoutMS, lHTTP);
      except
        on E: Exception do
        begin
          ADiagnostic := 'OpenAI file upload failed: ' + UTF8String(E.Message);
          Exit;
        end;
      end;
      if not lSuccess or (lHTTP.Status < 200) or (lHTTP.Status >= 300) then
      begin
        ADiagnostic := lHTTP.ErrorText;
        if ADiagnostic = '' then
          ADiagnostic := 'OpenAI file upload failed.';
        Exit;
      end;
      lData := nil;
      lFile := TNXOpenAIFileObject.Create;
      try
        try
          lData := GetJSON(string(lHTTP.Body));
          lFile.FromJSONData(lData);
        except
          on E: Exception do
          begin
            ADiagnostic := 'Invalid OpenAI file response: ' +
              UTF8String(E.Message);
            Exit;
          end;
        end;
        lFileID := lFile.id.Value;
        if lFileID = '' then
        begin
          ADiagnostic := 'OpenAI file upload returned no file ID.';
          Exit;
        end;
        FUploadedFiles.Add(string(lAttachment.ArtifactID + '=' + lFileID));
        if lFile.filename.Assigned and
          (lFile.filename.Value <> lAttachment.Name) then
        begin
          ADiagnostic := 'OpenAI file upload returned a different filename.';
          Exit;
        end;
        if lFile.bytes.Assigned and (lFile.bytes.Value <> lAttachment.Size) then
        begin
          ADiagnostic := 'OpenAI file upload returned a different byte count.';
          Exit;
        end;
      finally
        lFile.Free;
        lData.Free;
      end;
    end;
    if Pos('image/', LowerCase(string(lAttachment.MediaType))) = 1 then
    begin
      lInputImage := TNXOpenAIInputImage(AInputMessage.content.AddObject(
        TNXOpenAIInputImage));
      lInputImage.&type.Value := 'input_image';
      lInputImage.file_id.Value := lFileID;
    end
    else
    begin
      lInputFile := TNXOpenAIInputFile(AInputMessage.content.AddObject(
        TNXOpenAIInputFile));
      lInputFile.&type.Value := 'input_file';
      lInputFile.file_id.Value := lFileID;
    end;
  end;
  Result := True;
end;

procedure TNXOpenAIProvider.DeleteUploadedFilesFrom(AIndex: Integer);
var
  lHTTP: TNXOpenAIHTTPResult;
  lIndex: Integer;
begin
  for lIndex := FUploadedFiles.Count - 1 downto AIndex do
  begin
    try
      FExecutor.DeleteFile(FAPIKey, UTF8String(Configuration.OpenAICAFile),
        UTF8String(FUploadedFiles.ValueFromIndex[lIndex]),
        Configuration.RequestTimeoutMS, lHTTP);
    except
      on E: Exception do
        Diagnostic('OpenAI file cleanup failed: ' + UTF8String(E.Message));
    end;
    FUploadedFiles.Delete(lIndex);
  end;
end;

procedure TNXOpenAIProvider.DeleteUploadedFiles;
begin
  DeleteUploadedFilesFrom(0);
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
  DeleteUploadedFiles;
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
