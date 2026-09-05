unit obNXCodexAppServer;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  fpjson,
  Pipes,
  Process,
  SysUtils,
  obNXJSONRPCMessages,
  tpNXBotControl,
  tpNXBotHost;

type
  TNXCodexAppServerStateEvent = procedure(ASender: TObject;
    AState: TNXCodexAppServerState; const ADetail: UTF8String) of object;
  TNXCodexAppServerTextEvent = procedure(ASender: TObject;
    const AText: UTF8String) of object;
  TNXCodexAppServerPromptEvent = procedure(ASender: TObject;
    APrompt: TNXBotPrompt; const AText: UTF8String) of object;
  TNXCodexBotControlEvent = function(ASender: TObject;
    const AOperation: TNXBotControlOperation;
    const AAuthorization: TNXBotAuthorization;
    ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean of object;

  TNXCodexAppServer = class;

  TNXCodexAppServerThread = class(TThread)
  private
    FOwner: TNXCodexAppServer;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TNXCodexAppServer);
  end;

  TNXCodexAppServer = class
  private type
    TNXCommandKind = (ckStart, ckStop, ckSubmit, ckInterrupt, ckCancel,
      ckCancelRoom, ckToolResult);
    TNXRequestKind = (rkInitialize, rkModelList, rkThreadStart, rkTurnStart,
      rkTurnInterrupt, rkThreadUnsubscribe);

    TNXCommand = class
    private
      FExecutable: string;
      FInstructions: UTF8String;
      FModel: UTF8String;
      FPrompt: TNXBotPrompt;
      FRuntimeDirectory: string;
      FKind: TNXCommandKind;
      FReason: UTF8String;
      FRoomJID: UTF8String;
      FToolID: TJSONData;
      FControlResult: TNXBotControlResult;
    public
      destructor Destroy; override;
    end;

    TNXPendingRequest = class
    private
      FCommand: TNXJSONRPCOutboundCommand;
      FDeadline: QWord;
      FID: Int64;
      FKind: TNXRequestKind;
    public
      constructor Create(const AID: Int64; AKind: TNXRequestKind;
        ACommand: TNXJSONRPCOutboundCommand; const ADeadline: QWord);
      destructor Destroy; override;
    end;

  private
    FActivePrompt: TNXBotPrompt;
    FAnswerMaximumBytes: Integer;
    FActiveTurnID: UTF8String;
    FAnyPhasedMessage: Boolean;
    FCommandCapacity: Integer;
    FCommands: TObjectList;
    FCommandLock: TRTLCriticalSection;
    FExecutable: string;
    FFinalAnswer: UTF8String;
    FFrameLimit: Integer;
    FInstructions: UTF8String;
    FModel: UTF8String;
    FOnDiagnostic: TNXCodexAppServerTextEvent;
    FOnBotControl: TNXCodexBotControlEvent;
    FOnFinalAnswer: TNXCodexAppServerPromptEvent;
    FOnPromptFailed: TNXCodexAppServerPromptEvent;
    FOnState: TNXCodexAppServerStateEvent;
    FPendingPrompts: TObjectList;
    FPendingRequests: TObjectList;
    FProcess: TProcess;
    FRequestTimeoutMS: Cardinal;
    FRuntimeDirectory: string;
    FSelectedModel: UTF8String;
    FState: TNXCodexAppServerState;
    FStderrBuffer: RawByteString;
    FStdoutBuffer: RawByteString;
    FShuttingDown: Boolean;
    FStopRequested: Boolean;
    FThread: TNXCodexAppServerThread;
    FThreadID: UTF8String;
    FUnphasedAnswer: UTF8String;
    FNextRequestID: Int64;
    FPromptCapacity: Integer;

    procedure AddDiagnostic(const AText: UTF8String);
    procedure BeginInitialization;
    procedure BeginModelList;
    procedure BeginThread;
    procedure CheckPendingTimeouts;
    procedure CloseProcess;
    function DequeueCommand: TNXCommand;
    procedure DrainProcess;
    procedure DrainStream(AStream: TInputPipeStream; var ABuffer: RawByteString;
      const AIsProtocol: Boolean);
    function EnqueueCommand(ACommand: TNXCommand): Boolean;
    procedure FailActivePrompt(const AReason: UTF8String);
    procedure FailQueuedPrompts(const AReason: UTF8String);
    procedure FailRoomPrompts(const ARoomJID, AReason: UTF8String);
    function FindPendingRequest(const AID: Int64): Integer;
    procedure HandleCommand(ACommand: TNXCommand);
    procedure HandleItemCompleted(AMessage: TNXJSONRPCMessage);
    procedure HandleLine(const ALine: RawByteString);
    procedure HandleMessage(AMessage: TNXJSONRPCMessage);
    procedure HandleNotification(AMessage: TNXJSONRPCMessage);
    procedure HandleResponse(AMessage: TNXJSONRPCMessage);
    procedure HandleServerRequest(AMessage: TNXJSONRPCMessage);
    procedure HandleTurnCompleted(AMessage: TNXJSONRPCMessage);
    function NextRequestID: Int64;
    procedure ProcessCommands;
    procedure ProcessLines(var ABuffer: RawByteString;
      const AIsProtocol: Boolean);
    procedure Run;
    procedure SendDecision(AMessage: TNXJSONRPCMessage;
      const ADecision: UTF8String);
    procedure SendDynamicToolDecline(AMessage: TNXJSONRPCMessage);
    procedure SendDynamicToolResult(AID: TJSONData;
      const AResult: TNXBotControlResult);
    procedure SendElicitationDecline(AMessage: TNXJSONRPCMessage);
    procedure SendInitialized;
    procedure SendJSON(AJSON: TJSONData);
    procedure SendPermissionsDecline(AMessage: TNXJSONRPCMessage);
    procedure SendRequest(AKind: TNXRequestKind;
      ACommand: TNXJSONRPCOutboundCommand);
    procedure SendUserInputDecline(AMessage: TNXJSONRPCMessage);
    procedure SetState(AState: TNXCodexAppServerState;
      const ADetail: UTF8String = '');
    procedure StartNextPrompt;
    procedure StartProcess;
    procedure StopProcess;
  public
    constructor Create;
    destructor Destroy; override;

    function StartServer(const AExecutable, ARuntimeDirectory: string;
      const AModel, AInstructions: UTF8String): Boolean;
    function StopServer: Boolean;
    procedure Shutdown;
    function SubmitPrompt(APrompt: TNXBotPrompt): Boolean;
    function Interrupt: Boolean;
    function CancelPrompts(const AReason: UTF8String): Boolean;
    function CancelRoomPrompts(const ARoomJID,
      AReason: UTF8String): Boolean;
    function CommandCount: Integer;
    function SubmitControlResult(AID: TJSONData;
      const AResult: TNXBotControlResult): Boolean;

    property CommandCapacity: Integer read FCommandCapacity
      write FCommandCapacity;
    property AnswerMaximumBytes: Integer read FAnswerMaximumBytes
      write FAnswerMaximumBytes;
    property FrameLimit: Integer read FFrameLimit write FFrameLimit;
    property PromptCapacity: Integer read FPromptCapacity write FPromptCapacity;
    property RequestTimeoutMS: Cardinal read FRequestTimeoutMS
      write FRequestTimeoutMS;
    property State: TNXCodexAppServerState read FState;
    property OnDiagnostic: TNXCodexAppServerTextEvent read FOnDiagnostic
      write FOnDiagnostic;
    property OnBotControl: TNXCodexBotControlEvent read FOnBotControl
      write FOnBotControl;
    property OnFinalAnswer: TNXCodexAppServerPromptEvent read FOnFinalAnswer
      write FOnFinalAnswer;
    property OnPromptFailed: TNXCodexAppServerPromptEvent read FOnPromptFailed
      write FOnPromptFailed;
    property OnState: TNXCodexAppServerStateEvent read FOnState write FOnState;
  end;

implementation

uses
  obNXCodexAppServerMessages,
  obNXCodexAppServerTypes,
  obNXJSONValues;

const
  cAppServerEnvelopePolicy = jepHeaderless;
  cLoopDelayMS = 5;
  cReadBufferSize = 8192;
  cTruncationMarker = #10'[answer truncated]';

type
  TNXCodexControlRequest = class
  private
    FID: TJSONData;
    FServer: TNXCodexAppServer;
  public
    constructor Create(AServer: TNXCodexAppServer; AID: TJSONData);
    destructor Destroy; override;
    procedure Complete(const AToken: QWord;
      const AResult: TNXBotControlResult);
  end;

constructor TNXCodexControlRequest.Create(AServer: TNXCodexAppServer;
  AID: TJSONData);
begin
  inherited Create;
  FServer := AServer;
  FID := AID;
end;

destructor TNXCodexControlRequest.Destroy;
begin
  FID.Free;
  inherited Destroy;
end;

procedure TNXCodexControlRequest.Complete(const AToken: QWord;
  const AResult: TNXBotControlResult);
var
  lID: TJSONData;
begin
  try
    lID := FID;
    FID := nil;
    if not FServer.SubmitControlResult(lID, AResult) then
      lID.Free;
  finally
    Free;
  end;
end;

procedure NXApplyEnvelopePolicy(AMessage: TNXJSONRPCMessage;
  APolicy: TNXJSONRPCEnvelopePolicy);
begin
  if APolicy = jepStandard then
    AMessage.jsonrpc.Value := TNXJSONRPC.Version
  else
    AMessage.jsonrpc.Assigned := False;
end;

function NXBoundUTF8(const AValue: UTF8String;
  AMaximumBytes: Integer): UTF8String;
var
  lAvailable: Integer;
begin
  if (AMaximumBytes < 1) or (Length(AValue) <= AMaximumBytes) then
    Exit(AValue);
  if AMaximumBytes <= Length(cTruncationMarker) then
    Exit(Copy(UTF8String(cTruncationMarker), 1, AMaximumBytes));
  lAvailable := AMaximumBytes - Length(cTruncationMarker);
  while (lAvailable > 0) and (lAvailable < Length(AValue)) and
    ((Byte(AValue[lAvailable + 1]) and $C0) = $80) do
    Dec(lAvailable);
  Result := Copy(AValue, 1, lAvailable) + cTruncationMarker;
end;

function NXValidUTF8(const AValue: RawByteString): Boolean;
var
  lByte: Byte;
  lContinuation: Integer;
  lIndex: Integer;
begin
  lIndex := 1;
  while lIndex <= Length(AValue) do
  begin
    lByte := Byte(AValue[lIndex]);
    if lByte < $80 then
      lContinuation := 0
    else if (lByte >= $C2) and (lByte <= $DF) then
      lContinuation := 1
    else if (lByte >= $E0) and (lByte <= $EF) then
      lContinuation := 2
    else if (lByte >= $F0) and (lByte <= $F4) then
      lContinuation := 3
    else
      Exit(False);
    if lIndex + lContinuation > Length(AValue) then
      Exit(False);
    if (lContinuation >= 1) and
      ((Byte(AValue[lIndex + 1]) and $C0) <> $80) then
      Exit(False);
    if (lContinuation >= 2) and
      ((Byte(AValue[lIndex + 2]) and $C0) <> $80) then
      Exit(False);
    if (lContinuation = 3) and
      ((Byte(AValue[lIndex + 3]) and $C0) <> $80) then
      Exit(False);
    if (lByte = $E0) and (Byte(AValue[lIndex + 1]) < $A0) then
      Exit(False);
    if (lByte = $ED) and (Byte(AValue[lIndex + 1]) >= $A0) then
      Exit(False);
    if (lByte = $F0) and (Byte(AValue[lIndex + 1]) < $90) then
      Exit(False);
    if (lByte = $F4) and (Byte(AValue[lIndex + 1]) >= $90) then
      Exit(False);
    Inc(lIndex, lContinuation + 1);
  end;
  Result := True;
end;

constructor TNXCodexAppServerThread.Create(AOwner: TNXCodexAppServer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

procedure TNXCodexAppServerThread.Execute;
begin
  FOwner.Run;
end;

destructor TNXCodexAppServer.TNXCommand.Destroy;
begin
  FreeAndNil(FPrompt);
  FreeAndNil(FToolID);
  inherited Destroy;
end;

constructor TNXCodexAppServer.TNXPendingRequest.Create(const AID: Int64;
  AKind: TNXRequestKind; ACommand: TNXJSONRPCOutboundCommand;
  const ADeadline: QWord);
begin
  inherited Create;
  FID := AID;
  FKind := AKind;
  FCommand := ACommand;
  FDeadline := ADeadline;
end;

destructor TNXCodexAppServer.TNXPendingRequest.Destroy;
begin
  FreeAndNil(FCommand);
  inherited Destroy;
end;

constructor TNXCodexAppServer.Create;
begin
  inherited Create;
  FCommandCapacity := 64;
  FAnswerMaximumBytes := 16 * 1024;
  FPromptCapacity := 16;
  FFrameLimit := 1024 * 1024;
  FRequestTimeoutMS := 30000;
  FNextRequestID := 1;
  FState := cassStopped;
  FCommands := TObjectList.Create(True);
  FPendingPrompts := TObjectList.Create(True);
  FPendingRequests := TObjectList.Create(True);
  InitCriticalSection(FCommandLock);
  FThread := TNXCodexAppServerThread.Create(Self);
  FThread.Start;
end;

destructor TNXCodexAppServer.Destroy;
begin
  Shutdown;
  CloseProcess;
  FreeAndNil(FPendingRequests);
  FreeAndNil(FPendingPrompts);
  FreeAndNil(FActivePrompt);
  DoneCriticalSection(FCommandLock);
  FreeAndNil(FCommands);
  inherited Destroy;
end;

procedure TNXCodexAppServer.AddDiagnostic(const AText: UTF8String);
begin
  if Assigned(FOnDiagnostic) then
    FOnDiagnostic(Self, AText);
end;

function TNXCodexAppServer.CommandCount: Integer;
begin
  EnterCriticalSection(FCommandLock);
  try
    Result := FCommands.Count;
  finally
    LeaveCriticalSection(FCommandLock);
  end;
end;

function TNXCodexAppServer.EnqueueCommand(ACommand: TNXCommand): Boolean;
begin
  Result := False;
  if ACommand = nil then
    Exit;
  EnterCriticalSection(FCommandLock);
  try
    if not FShuttingDown and (FCommands.Count < FCommandCapacity) then
    begin
      FCommands.Add(ACommand);
      Result := True;
    end;
  finally
    LeaveCriticalSection(FCommandLock);
  end;
  if not Result then
    ACommand.Free;
end;

procedure TNXCodexAppServer.Shutdown;
var
  lThread: TNXCodexAppServerThread;
begin
  EnterCriticalSection(FCommandLock);
  try
    if FShuttingDown then
      Exit;
    FShuttingDown := True;
    lThread := FThread;
  finally
    LeaveCriticalSection(FCommandLock);
  end;
  if Assigned(lThread) then
  begin
    lThread.Terminate;
    lThread.WaitFor;
    FreeAndNil(FThread);
  end;
end;

function TNXCodexAppServer.DequeueCommand: TNXCommand;
begin
  Result := nil;
  EnterCriticalSection(FCommandLock);
  try
    if FCommands.Count > 0 then
      Result := TNXCommand(FCommands.Extract(FCommands[0]));
  finally
    LeaveCriticalSection(FCommandLock);
  end;
end;

function TNXCodexAppServer.StartServer(const AExecutable,
  ARuntimeDirectory: string; const AModel,
  AInstructions: UTF8String): Boolean;
var
  lCommand: TNXCommand;
begin
  lCommand := TNXCommand.Create;
  lCommand.FKind := ckStart;
  lCommand.FExecutable := AExecutable;
  lCommand.FRuntimeDirectory := ARuntimeDirectory;
  lCommand.FModel := AModel;
  lCommand.FInstructions := AInstructions;
  Result := EnqueueCommand(lCommand);
end;

function TNXCodexAppServer.StopServer: Boolean;
var
  lCommand: TNXCommand;
begin
  lCommand := TNXCommand.Create;
  lCommand.FKind := ckStop;
  Result := EnqueueCommand(lCommand);
end;

function TNXCodexAppServer.SubmitPrompt(APrompt: TNXBotPrompt): Boolean;
var
  lCommand: TNXCommand;
begin
  Result := False;
  if APrompt = nil then
    Exit;
  lCommand := TNXCommand.Create;
  lCommand.FKind := ckSubmit;
  lCommand.FPrompt := APrompt;
  Result := EnqueueCommand(lCommand);
end;

function TNXCodexAppServer.Interrupt: Boolean;
var
  lCommand: TNXCommand;
begin
  lCommand := TNXCommand.Create;
  lCommand.FKind := ckInterrupt;
  Result := EnqueueCommand(lCommand);
end;

function TNXCodexAppServer.CancelPrompts(const AReason: UTF8String): Boolean;
var
  lCommand: TNXCommand;
begin
  lCommand := TNXCommand.Create;
  lCommand.FKind := ckCancel;
  lCommand.FReason := AReason;
  Result := EnqueueCommand(lCommand);
end;

function TNXCodexAppServer.CancelRoomPrompts(const ARoomJID,
  AReason: UTF8String): Boolean;
var
  lCommand: TNXCommand;
begin
  if ARoomJID = '' then
    Exit(False);
  lCommand := TNXCommand.Create;
  lCommand.FKind := ckCancelRoom;
  lCommand.FRoomJID := ARoomJID;
  lCommand.FReason := AReason;
  Result := EnqueueCommand(lCommand);
end;

function TNXCodexAppServer.SubmitControlResult(AID: TJSONData;
  const AResult: TNXBotControlResult): Boolean;
var
  lCommand: TNXCommand;
begin
  if not Assigned(AID) then
    Exit(False);
  lCommand := TNXCommand.Create;
  lCommand.FKind := ckToolResult;
  lCommand.FToolID := AID;
  lCommand.FControlResult := AResult;
  Result := EnqueueCommand(lCommand);
end;

procedure TNXCodexAppServer.SetState(AState: TNXCodexAppServerState;
  const ADetail: UTF8String);
begin
  FState := AState;
  if Assigned(FOnState) then
    FOnState(Self, AState, ADetail);
end;

procedure TNXCodexAppServer.Run;
begin
  try
    while not FThread.Terminated do
    begin
      try
        ProcessCommands;
        if Assigned(FProcess) then
        begin
          DrainProcess;
          CheckPendingTimeouts;
          if (not FProcess.Running) and
            (FProcess.Output.NumBytesAvailable = 0) and
            (FProcess.Stderr.NumBytesAvailable = 0) then
          begin
            if not FStopRequested then
            begin
              SetState(cassFailed, 'Codex App Server exited unexpectedly.');
              FailActivePrompt('Codex App Server exited unexpectedly.');
              FailQueuedPrompts('Codex App Server exited unexpectedly.');
            end;
            CloseProcess;
            if FStopRequested then
              SetState(cassStopped);
          end;
        end;
      except
        on E: Exception do
        begin
          SetState(cassFailed, E.Message);
          AddDiagnostic(E.Message);
          FailActivePrompt(E.Message);
          FailQueuedPrompts(E.Message);
          CloseProcess;
        end;
      end;
      Sleep(cLoopDelayMS);
    end;
  finally
    StopProcess;
  end;
end;

procedure TNXCodexAppServer.ProcessCommands;
var
  lCommand: TNXCommand;
begin
  repeat
    lCommand := DequeueCommand;
    if lCommand = nil then
      Exit;
    try
      HandleCommand(lCommand);
    finally
      lCommand.Free;
    end;
  until False;
end;

procedure TNXCodexAppServer.HandleCommand(ACommand: TNXCommand);
var
  lInterrupt: TNXCodexTurnInterruptCommand;
  lPrompt: TNXBotPrompt;
begin
  case ACommand.FKind of
    ckStart:
      begin
        if Assigned(FProcess) then
          raise Exception.Create('Codex App Server is already running.');
        FExecutable := ACommand.FExecutable;
        FRuntimeDirectory := ACommand.FRuntimeDirectory;
        FModel := ACommand.FModel;
        FInstructions := ACommand.FInstructions;
        StartProcess;
      end;
    ckStop:
      StopProcess;
    ckSubmit:
      begin
        lPrompt := ACommand.FPrompt;
        ACommand.FPrompt := nil;
        if not Assigned(FProcess) or
          (FState in [cassStopped, cassStopping, cassFailed]) then
        begin
          if Assigned(FOnPromptFailed) then
            FOnPromptFailed(Self, lPrompt, 'Codex App Server is not available.');
          lPrompt.Free;
        end
        else if FPendingPrompts.Count >= FPromptCapacity then
        begin
          if Assigned(FOnPromptFailed) then
            FOnPromptFailed(Self, lPrompt, 'Pending prompt queue is full.');
          lPrompt.Free;
        end
        else
        begin
          FPendingPrompts.Add(lPrompt);
          StartNextPrompt;
        end;
      end;
    ckInterrupt:
      if (FActiveTurnID <> '') and (FThreadID <> '') then
      begin
        lInterrupt := TNXCodexTurnInterruptCommand.Create;
        lInterrupt.params.threadId.Value := FThreadID;
        lInterrupt.params.turnId.Value := FActiveTurnID;
        SendRequest(rkTurnInterrupt, lInterrupt);
      end;
    ckCancel:
      begin
        if (FActiveTurnID <> '') and (FThreadID <> '') then
        begin
          lInterrupt := TNXCodexTurnInterruptCommand.Create;
          lInterrupt.params.threadId.Value := FThreadID;
          lInterrupt.params.turnId.Value := FActiveTurnID;
          SendRequest(rkTurnInterrupt, lInterrupt);
        end;
        FailActivePrompt(ACommand.FReason);
        FailQueuedPrompts(ACommand.FReason);
        if Assigned(FProcess) and FProcess.Running then
          SetState(cassReady, FSelectedModel);
      end;
    ckCancelRoom:
      begin
        if Assigned(FActivePrompt) and
          (FActivePrompt.RoomJID = ACommand.FRoomJID) and
          (FActiveTurnID <> '') and (FThreadID <> '') then
        begin
          lInterrupt := TNXCodexTurnInterruptCommand.Create;
          lInterrupt.params.threadId.Value := FThreadID;
          lInterrupt.params.turnId.Value := FActiveTurnID;
          SendRequest(rkTurnInterrupt, lInterrupt);
        end;
        FailRoomPrompts(ACommand.FRoomJID, ACommand.FReason);
        if Assigned(FProcess) and FProcess.Running and
          not Assigned(FActivePrompt) then
        begin
          SetState(cassReady, FSelectedModel);
          StartNextPrompt;
        end;
      end;
    ckToolResult:
      begin
        SendDynamicToolResult(ACommand.FToolID, ACommand.FControlResult);
        ACommand.FToolID := nil;
      end;
  end;
end;

procedure TNXCodexAppServer.StartProcess;
begin
  if FExecutable = '' then
    raise Exception.Create('Codex executable is required.');
  if not FileExists(FExecutable) then
    raise Exception.CreateFmt('Codex executable not found: %s', [FExecutable]);
  if (FRuntimeDirectory = '') or (not DirectoryExists(FRuntimeDirectory)) then
    raise Exception.CreateFmt('Codex runtime directory not found: %s',
      [FRuntimeDirectory]);

  FStopRequested := False;
  FStdoutBuffer := '';
  FStderrBuffer := '';
  FThreadID := '';
  FActiveTurnID := '';
  FSelectedModel := '';
  FPendingRequests.Clear;
  SetState(cassStarting);
  FProcess := TProcess.Create(nil);
  try
    FProcess.Executable := FExecutable;
    FProcess.CurrentDirectory := FRuntimeDirectory;
    FProcess.Parameters.Add('app-server');
    FProcess.Parameters.Add('--stdio');
    FProcess.Options := [poUsePipes, poNoConsole];
    FProcess.Execute;
  except
    CloseProcess;
    raise;
  end;
  BeginInitialization;
end;

procedure TNXCodexAppServer.BeginInitialization;
var
  lCommand: TNXCodexInitializeCommand;
begin
  SetState(cassInitializing);
  lCommand := TNXCodexInitializeCommand.Create;
  lCommand.params.clientInfo.name.Value := 'NexusBotHost';
  lCommand.params.clientInfo.title.Value := 'Nexus Codex XMPP Bot';
  lCommand.params.clientInfo.version.Value := '1.0';
  lCommand.params.capabilities.experimentalApi.Value := True;
  lCommand.params.capabilities.requestAttestation.Value := False;
  SendRequest(rkInitialize, lCommand);
end;

procedure TNXCodexAppServer.SendInitialized;
var
  lNotification: TNXCodexInitializedNotification;
  lJSON: TJSONData;
begin
  lNotification := TNXCodexInitializedNotification.Create;
  try
    lNotification.method.Value := lNotification.GetFactoryName;
    NXApplyEnvelopePolicy(lNotification, cAppServerEnvelopePolicy);
    lJSON := lNotification.ToJSONData;
    try
      SendJSON(lJSON);
    finally
      lJSON.Free;
    end;
  finally
    lNotification.Free;
  end;
end;

procedure TNXCodexAppServer.BeginModelList;
var
  lCommand: TNXCodexModelListCommand;
begin
  SetState(cassResolvingModel);
  lCommand := TNXCodexModelListCommand.Create;
  lCommand.params.includeHidden.Value := True;
  SendRequest(rkModelList, lCommand);
end;

procedure TNXCodexAppServer.BeginThread;
var
  lCommand: TNXCodexThreadStartCommand;
  lTool: TNXCodexDynamicToolSpec;
begin
  SetState(cassCreatingThread);
  lCommand := TNXCodexThreadStartCommand.Create;
  lCommand.params.model.Value := FSelectedModel;
  lCommand.params.cwd.Value := FRuntimeDirectory;
  lCommand.params.approvalPolicy.Value := 'never';
  lCommand.params.approvalsReviewer.Value := 'user';
  lCommand.params.sandbox.Value := 'read-only';
  lCommand.params.ephemeral.Value := True;
  lCommand.params.developerInstructions.Value := FInstructions + ' ' +
    'You are an XMPP room bot. Answer the user message directly. Do not run ' +
    'commands, read or modify files, use network tools, invoke MCP tools, ask ' +
    'for approvals, or request additional user input.';
  lCommand.params.dynamicTools.Assigned := True;
  lTool := TNXCodexDynamicToolSpec(lCommand.params.dynamicTools.AddObject(
    TNXCodexDynamicToolSpec));
  lTool.&type.Value := 'function';
  lTool.name.Value := 'bot_control';
  lTool.description.Value := 'List bots, inspect bot status, or invite or ' +
    'dismiss a bot from the current XMPP room.';
  lTool.inputSchema.&type.Value := 'object';
  lTool.inputSchema.additionalProperties.Value := False;
  lTool.inputSchema.properties.operation.&type.Value := 'string';
  lTool.inputSchema.properties.operation.&enum.AddString('list');
  lTool.inputSchema.properties.operation.&enum.AddString('status');
  lTool.inputSchema.properties.operation.&enum.AddString('invite');
  lTool.inputSchema.properties.operation.&enum.AddString('dismiss');
  lTool.inputSchema.properties.bot.&type.Value := 'string';
  lTool.inputSchema.required.AddString('operation');
  SendRequest(rkThreadStart, lCommand);
end;

function TNXCodexAppServer.NextRequestID: Int64;
begin
  Result := FNextRequestID;
  if FNextRequestID = High(Int64) then
    FNextRequestID := 1
  else
    Inc(FNextRequestID);
end;

procedure TNXCodexAppServer.SendRequest(AKind: TNXRequestKind;
  ACommand: TNXJSONRPCOutboundCommand);
var
  lID: Int64;
  lJSON: TJSONData;
begin
  try
    lID := NextRequestID;
    ACommand.id.IntegerValue := lID;
    ACommand.method.Value := ACommand.GetFactoryName;
    NXApplyEnvelopePolicy(ACommand, cAppServerEnvelopePolicy);
    lJSON := ACommand.ToJSONData;
    try
      SendJSON(lJSON);
    finally
      lJSON.Free;
    end;
    FPendingRequests.Add(TNXPendingRequest.Create(lID, AKind, ACommand,
      GetTickCount64 + FRequestTimeoutMS));
  except
    ACommand.Free;
    raise;
  end;
end;

procedure TNXCodexAppServer.SendJSON(AJSON: TJSONData);
var
  lLine: UTF8String;
begin
  if not Assigned(FProcess) or not FProcess.Running then
    raise Exception.Create('Codex App Server process is not running.');
  lLine := UTF8String(AJSON.AsJSON) + #10;
  if Length(lLine) > FFrameLimit then
    raise Exception.Create('Codex App Server outbound frame exceeds limit.');
  if lLine <> '' then
    FProcess.Input.WriteBuffer(lLine[1], Length(lLine));
end;

procedure TNXCodexAppServer.DrainProcess;
begin
  DrainStream(FProcess.Output, FStdoutBuffer, True);
  DrainStream(FProcess.Stderr, FStderrBuffer, False);
end;

procedure TNXCodexAppServer.DrainStream(AStream: TInputPipeStream;
  var ABuffer: RawByteString; const AIsProtocol: Boolean);
var
  lAvailable: DWord;
  lBuffer: array[0..cReadBufferSize - 1] of Byte;
  lCount: LongInt;
  lRead: LongInt;
begin
  repeat
    lAvailable := AStream.NumBytesAvailable;
    if lAvailable = 0 then
      Break;
    lCount := lAvailable;
    if lCount > SizeOf(lBuffer) then
      lCount := SizeOf(lBuffer);
    lRead := AStream.Read(lBuffer, lCount);
    if lRead <= 0 then
      Break;
    SetLength(ABuffer, Length(ABuffer) + lRead);
    Move(lBuffer[0], ABuffer[Length(ABuffer) - lRead + 1], lRead);
    if Length(ABuffer) > FFrameLimit then
      raise Exception.Create('Codex App Server stream frame exceeds limit.');
    ProcessLines(ABuffer, AIsProtocol);
  until False;
end;

procedure TNXCodexAppServer.ProcessLines(var ABuffer: RawByteString;
  const AIsProtocol: Boolean);
var
  lIndex: SizeInt;
  lLine: RawByteString;
begin
  repeat
    lIndex := Pos(#10, ABuffer);
    if lIndex = 0 then
      Exit;
    lLine := Copy(ABuffer, 1, lIndex - 1);
    Delete(ABuffer, 1, lIndex);
    if (lLine <> '') and (lLine[Length(lLine)] = #13) then
      Delete(lLine, Length(lLine), 1);
    if AIsProtocol then
      HandleLine(lLine)
    else if lLine <> '' then
      AddDiagnostic(UTF8String(lLine));
  until False;
end;

procedure TNXCodexAppServer.HandleLine(const ALine: RawByteString);
var
  lMessage: TNXJSONRPCMessage;
begin
  if ALine = '' then
    Exit;
  if not NXValidUTF8(ALine) then
    raise Exception.Create('Codex App Server emitted malformed UTF-8.');
  lMessage := TNXJSONRPC.ParseMessage(UTF8String(ALine),
    cAppServerEnvelopePolicy);
  try
    HandleMessage(lMessage);
  finally
    lMessage.Free;
  end;
end;

procedure TNXCodexAppServer.HandleMessage(AMessage: TNXJSONRPCMessage);
begin
  case AMessage.Kind of
    rpcSuccessResponse, rpcErrorResponse:
      HandleResponse(AMessage);
    rpcNotification:
      HandleNotification(AMessage);
    rpcRequest:
      HandleServerRequest(AMessage);
  else
    raise Exception.Create('Unsupported App Server message shape.');
  end;
end;

function TNXCodexAppServer.FindPendingRequest(const AID: Int64): Integer;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FPendingRequests.Count - 1 do
    if TNXPendingRequest(FPendingRequests[lIndex]).FID = AID then
      Exit(lIndex);
  Result := -1;
end;

procedure TNXCodexAppServer.HandleResponse(AMessage: TNXJSONRPCMessage);
var
  lIDJSON: TJSONData;
  lID: Int64;
  lIndex: Integer;
  lModel: TNXCodexModel;
  lPending: TNXPendingRequest;
  lResponse: TNXJSONRPCResponse;
  lSelected: Boolean;
  lIdx: Integer;
  lErrorMessage: UTF8String;
  lRequestKind: TNXRequestKind;
begin
  lIDJSON := AMessage.IDJSON;
  try
    if lIDJSON.JSONType <> jtNumber then
      raise Exception.Create('App Server response ID is not numeric.');
    lID := lIDJSON.AsInt64;
  finally
    lIDJSON.Free;
  end;
  lIndex := FindPendingRequest(lID);
  if lIndex < 0 then
    raise Exception.CreateFmt('Unknown App Server response ID %d.', [lID]);
  lPending := TNXPendingRequest(FPendingRequests[lIndex]);
  lResponse := TNXJSONRPCResponse(AMessage);
  lPending.FCommand.LoadOutboundResponse(lResponse);
  if AMessage.Kind = rpcErrorResponse then
  begin
    lErrorMessage := lPending.FCommand.CommandError.message.Value;
    lRequestKind := lPending.FKind;
    FPendingRequests.Delete(lIndex);
    case lRequestKind of
      rkTurnStart:
        begin
          FailActivePrompt(lErrorMessage);
          SetState(cassReady, FSelectedModel);
          StartNextPrompt;
          Exit;
        end;
      rkTurnInterrupt, rkThreadUnsubscribe:
        begin
          AddDiagnostic(lErrorMessage);
          Exit;
        end;
    else
      raise Exception.Create(lErrorMessage);
    end;
  end;

  case lPending.FKind of
    rkInitialize:
      begin
        SendInitialized;
        BeginModelList;
      end;
    rkModelList:
      begin
        lSelected := False;
        with TNXCodexModelListCommand(lPending.FCommand).result do
          for lIdx := 0 to data.Count - 1 do
          begin
            lModel := TNXCodexModel(data[lIdx]);
            if ((lModel.id.Assigned) and (lModel.id.Value = FModel)) or
              ((lModel.model.Assigned) and (lModel.model.Value = FModel)) or
              ((lModel.displayName.Assigned) and
               (lModel.displayName.Value = FModel)) then
            begin
              if lModel.model.Assigned then
                FSelectedModel := lModel.model.Value
              else
                FSelectedModel := lModel.id.Value;
              lSelected := True;
              Break;
            end;
          end;
        if not lSelected then
          raise Exception.CreateFmt('Configured Codex model not found: %s',
            [FModel]);
        BeginThread;
      end;
    rkThreadStart:
      begin
        FThreadID := TNXCodexThreadStartCommand(lPending.FCommand).
          result.thread.id.Value;
        if FThreadID = '' then
          raise Exception.Create('App Server returned an empty thread ID.');
        SetState(cassReady, FSelectedModel);
        StartNextPrompt;
      end;
    rkTurnStart:
      begin
        FActiveTurnID := TNXCodexTurnStartCommand(lPending.FCommand).
          result.turn.id.Value;
        if FActiveTurnID = '' then
          raise Exception.Create('App Server returned an empty turn ID.');
        SetState(cassBusy, FActiveTurnID);
      end;
    rkTurnInterrupt:
      AddDiagnostic('Active Codex turn interruption acknowledged.');
    rkThreadUnsubscribe:
      AddDiagnostic('Codex thread released.');
  end;
  FPendingRequests.Delete(lIndex);
end;

procedure TNXCodexAppServer.HandleNotification(AMessage: TNXJSONRPCMessage);
begin
  if AMessage is TNXCodexItemCompletedNotification then
    HandleItemCompleted(AMessage)
  else if AMessage is TNXCodexTurnCompletedNotification then
    HandleTurnCompleted(AMessage)
  else if AMessage is TNXCodexErrorNotification then
    AddDiagnostic(TNXCodexErrorNotification(AMessage).params.error.message.Value)
  else if not ((AMessage is TNXCodexItemStartedNotification) or
    (AMessage is TNXCodexTurnStartedNotification)) then
    AddDiagnostic('Ignored App Server notification: ' +
      TNXJSONRPCCommandMessage(AMessage).method.Value);
end;

procedure TNXCodexAppServer.HandleItemCompleted(AMessage: TNXJSONRPCMessage);
var
  lItem: TNXCodexThreadItemObject;
  lAgent: TNXCodexAgentMessageItem;
  lParams: TNXCodexItemNotificationParams;
begin
  lParams := TNXCodexItemCompletedNotification(AMessage).params;
  if (FActiveTurnID = '') or (lParams.turnId.Value <> FActiveTurnID) then
    Exit;
  if not (lParams.item.Value is TNXCodexThreadItemObject) then
    Exit;
  lItem := TNXCodexThreadItemObject(lParams.item.Value);
  if not (lItem is TNXCodexAgentMessageItem) then
    Exit;
  lAgent := TNXCodexAgentMessageItem(lItem);
  if lAgent.phase.Assigned and (not lAgent.phase.IsNull) then
  begin
    FAnyPhasedMessage := True;
    if lAgent.phase.Value = 'final_answer' then
      FFinalAnswer := lAgent.text.Value;
  end
  else
    FUnphasedAnswer := lAgent.text.Value;
end;

procedure TNXCodexAppServer.HandleTurnCompleted(AMessage: TNXJSONRPCMessage);
var
  lAnswer: UTF8String;
  lParams: TNXCodexTurnNotificationParams;
begin
  lParams := TNXCodexTurnCompletedNotification(AMessage).params;
  if (FActiveTurnID = '') or (lParams.turn.id.Value <> FActiveTurnID) then
    Exit;
  if lParams.turn.status.Value <> 'completed' then
  begin
    FailActivePrompt('Codex turn ended with status ' +
      lParams.turn.status.Value + '.');
  end
  else
  begin
    lAnswer := FFinalAnswer;
    if (lAnswer = '') and (not FAnyPhasedMessage) then
      lAnswer := FUnphasedAnswer;
    if lAnswer = '' then
      FailActivePrompt('Codex turn completed without an eligible final answer.')
    else
    begin
      lAnswer := NXBoundUTF8(lAnswer, FAnswerMaximumBytes);
      if Assigned(FOnFinalAnswer) then
        FOnFinalAnswer(Self, FActivePrompt, lAnswer);
      FreeAndNil(FActivePrompt);
    end;
  end;
  FActiveTurnID := '';
  FFinalAnswer := '';
  FUnphasedAnswer := '';
  FAnyPhasedMessage := False;
  SetState(cassReady, FSelectedModel);
  StartNextPrompt;
end;

procedure TNXCodexAppServer.HandleServerRequest(AMessage: TNXJSONRPCMessage);
var
  lArguments: TNXCodexBotControlArguments;
  lAuthorization: TNXBotAuthorization;
  lControlRequest: TNXCodexControlRequest;
  lID: TJSONData;
  lOperation: TNXBotControlOperation;
  lResponse: TJSONObject;
  lToken: QWord;
begin
  if (AMessage is TNXCodexCommandApprovalRequest) or
    (AMessage is TNXCodexFileChangeApprovalRequest) then
    SendDecision(AMessage, 'decline')
  else if (AMessage is TNXCodexLegacyApplyPatchApprovalRequest) or
    (AMessage is TNXCodexLegacyExecCommandApprovalRequest) then
    SendDecision(AMessage, 'abort')
  else if AMessage is TNXCodexPermissionsApprovalRequest then
    SendPermissionsDecline(AMessage)
  else if AMessage is TNXCodexUserInputRequest then
    SendUserInputDecline(AMessage)
  else if AMessage is TNXCodexMCPElicitationRequest then
    SendElicitationDecline(AMessage)
  else if AMessage is TNXCodexDynamicToolCallRequest then
  begin
    if (TNXCodexDynamicToolCallRequest(AMessage).params.tool.Value <>
      'bot_control') or not Assigned(FOnBotControl) or
      not Assigned(FActivePrompt) or
      (TNXCodexDynamicToolCallRequest(AMessage).params.turnId.Value <>
      FActiveTurnID) or not
      (TNXCodexDynamicToolCallRequest(AMessage).params.arguments.Value is
      TNXCodexBotControlArguments) then
      SendDynamicToolDecline(AMessage)
    else
    begin
      lArguments := TNXCodexBotControlArguments(
        TNXCodexDynamicToolCallRequest(AMessage).params.arguments.Value);
      if SameText(lArguments.operation.Value, 'list') then
        lOperation := NXBotControlOperation(bcokList, '', '')
      else if SameText(lArguments.operation.Value, 'status') then
        lOperation := NXBotControlOperation(bcokStatus,
          lArguments.bot.Value, '')
      else if SameText(lArguments.operation.Value, 'invite') then
        lOperation := NXBotControlOperation(bcokInvite,
          lArguments.bot.Value, FActivePrompt.RoomJID)
      else if SameText(lArguments.operation.Value, 'dismiss') then
        lOperation := NXBotControlOperation(bcokDismiss,
          lArguments.bot.Value, FActivePrompt.RoomJID)
      else
      begin
        SendDynamicToolResult(AMessage.IDJSON, NXBotControlFailure(
          bceBadRequest, 'Unknown bot control operation.'));
        Exit;
      end;
      lAuthorization := NXBotAuthorization(bcoModelTool,
        FActivePrompt.VerifiedCallerBareJID, FActivePrompt.RoomJID,
        FActivePrompt.VerifiedMUCIdentity);
      lControlRequest := TNXCodexControlRequest.Create(Self, AMessage.IDJSON);
      if not FOnBotControl(Self, lOperation, lAuthorization,
        @lControlRequest.Complete, lToken) then
      begin
        lControlRequest.Free;
        SendDynamicToolResult(AMessage.IDJSON, NXBotControlFailure(
          bceCapacity, 'The control request could not be accepted.'));
      end;
    end;
  end
  else
  begin
    lID := AMessage.IDJSON;
    try
      lResponse := TNXJSONRPC.CreateErrorResponse(lID,
        TNXJSONRPC.MethodNotFound, 'Unsupported App Server request.', nil,
        jepHeaderless);
      try
        SendJSON(lResponse);
      finally
        lResponse.Free;
      end;
    finally
      lID.Free;
    end;
  end;
  AddDiagnostic('Declined App Server request: ' +
    TNXJSONRPCCommandMessage(AMessage).method.Value);
end;

procedure TNXCodexAppServer.SendDynamicToolResult(AID: TJSONData;
  const AResult: TNXBotControlResult);
var
  lContent: TNXCodexDynamicToolTextContent;
  lIndex: Integer;
  lResponse: TJSONObject;
  lResult: TNXCodexDynamicToolCallResult;
  lText: UTF8String;
begin
  lResult := TNXCodexDynamicToolCallResult.Create;
  try
    lResult.success.Value := AResult.Error = bceNone;
    lResult.contentItems.Assigned := True;
    lText := 'error=' + NXBotControlErrorName(AResult.Error);
    if AResult.Detail <> '' then
      lText := lText + '; detail=' + AResult.Detail;
    for lIndex := 0 to High(AResult.Bots) do
      lText := lText + #10 + AResult.Bots[lIndex].Name +
        ': available=' + UTF8String(BoolToStr(AResult.Bots[lIndex].Available,
        True)) + '; active=' + UTF8String(BoolToStr(
        AResult.Bots[lIndex].Active, True)) + '; appServer=' +
        AResult.Bots[lIndex].AppServerState + '; xmpp=' +
        AResult.Bots[lIndex].XMPPState;
    lContent := TNXCodexDynamicToolTextContent(
      lResult.contentItems.AddObject(TNXCodexDynamicToolTextContent));
    lContent.&type.Value := 'inputText';
    lContent.text.Value := lText;
    lResponse := TNXJSONRPC.CreateSuccessResponse(AID, lResult,
      jepHeaderless);
    try
      SendJSON(lResponse);
    finally
      lResponse.Free;
    end;
  finally
    lResult.Free;
    AID.Free;
  end;
end;

procedure TNXCodexAppServer.SendDynamicToolDecline(
  AMessage: TNXJSONRPCMessage);
var
  lID: TJSONData;
  lResponse: TJSONObject;
  lResult: TNXCodexDynamicToolCallResult;
begin
  lID := AMessage.IDJSON;
  lResult := TNXCodexDynamicToolCallResult.Create;
  try
    lResult.contentItems.Assigned := True;
    lResult.success.Value := False;
    lResponse := TNXJSONRPC.CreateSuccessResponse(lID, lResult, jepHeaderless);
    try
      SendJSON(lResponse);
    finally
      lResponse.Free;
    end;
  finally
    lResult.Free;
    lID.Free;
  end;
end;

procedure TNXCodexAppServer.SendDecision(AMessage: TNXJSONRPCMessage;
  const ADecision: UTF8String);
var
  lID: TJSONData;
  lResponse: TJSONObject;
  lResult: TNXCodexDecisionResult;
begin
  lID := AMessage.IDJSON;
  lResult := TNXCodexDecisionResult.Create;
  try
    lResult.decision.Value := ADecision;
    lResponse := TNXJSONRPC.CreateSuccessResponse(lID, lResult, jepHeaderless);
    try
      SendJSON(lResponse);
    finally
      lResponse.Free;
    end;
  finally
    lResult.Free;
    lID.Free;
  end;
end;

procedure TNXCodexAppServer.SendElicitationDecline(
  AMessage: TNXJSONRPCMessage);
var
  lID: TJSONData;
  lResponse: TJSONObject;
  lResult: TNXCodexElicitationResult;
begin
  lID := AMessage.IDJSON;
  lResult := TNXCodexElicitationResult.Create;
  try
    lResult.action.Value := 'decline';
    lResponse := TNXJSONRPC.CreateSuccessResponse(lID, lResult, jepHeaderless);
    try
      SendJSON(lResponse);
    finally
      lResponse.Free;
    end;
  finally
    lResult.Free;
    lID.Free;
  end;
end;

procedure TNXCodexAppServer.SendUserInputDecline(
  AMessage: TNXJSONRPCMessage);
var
  lID: TJSONData;
  lResponse: TJSONObject;
  lResult: TNXCodexUserInputResult;
begin
  lID := AMessage.IDJSON;
  lResult := TNXCodexUserInputResult.Create;
  try
    lResult.answers.Assigned := True;
    lResponse := TNXJSONRPC.CreateSuccessResponse(lID, lResult, jepHeaderless);
    try
      SendJSON(lResponse);
    finally
      lResponse.Free;
    end;
  finally
    lResult.Free;
    lID.Free;
  end;
end;

procedure TNXCodexAppServer.SendPermissionsDecline(
  AMessage: TNXJSONRPCMessage);
var
  lID: TJSONData;
  lResponse: TJSONObject;
  lResult: TNXCodexPermissionsResult;
begin
  lID := AMessage.IDJSON;
  lResult := TNXCodexPermissionsResult.Create;
  try
    lResult.permissions.Assigned := True;
    lResult.scope.Value := 'turn';
    lResult.strictAutoReview.Value := True;
    lResponse := TNXJSONRPC.CreateSuccessResponse(lID, lResult, jepHeaderless);
    try
      SendJSON(lResponse);
    finally
      lResponse.Free;
    end;
  finally
    lResult.Free;
    lID.Free;
  end;
end;

procedure TNXCodexAppServer.StartNextPrompt;
var
  lCommand: TNXCodexTurnStartCommand;
  lInput: TNXCodexTextInput;
begin
  if (FState <> cassReady) or Assigned(FActivePrompt) or
    (FPendingPrompts.Count = 0) then
    Exit;
  FActivePrompt := TNXBotPrompt(FPendingPrompts.Extract(FPendingPrompts[0]));
  FFinalAnswer := '';
  FUnphasedAnswer := '';
  FAnyPhasedMessage := False;
  lCommand := TNXCodexTurnStartCommand.Create;
  lCommand.params.threadId.Value := FThreadID;
  lCommand.params.clientUserMessageId.Value := IntToStr(FActivePrompt.Sequence);
  lInput := TNXCodexTextInput(lCommand.params.input.AddObject(
    TNXCodexTextInput));
  lInput.&type.Value := 'text';
  lInput.text.Value := FActivePrompt.Body;
  lInput.text_elements.Assigned := True;
  SendRequest(rkTurnStart, lCommand);
  SetState(cassBusy, 'Starting Codex turn.');
end;

procedure TNXCodexAppServer.FailActivePrompt(const AReason: UTF8String);
begin
  if not Assigned(FActivePrompt) then
    Exit;
  if Assigned(FOnPromptFailed) then
    FOnPromptFailed(Self, FActivePrompt, AReason);
  FreeAndNil(FActivePrompt);
  FActiveTurnID := '';
end;

procedure TNXCodexAppServer.FailQueuedPrompts(const AReason: UTF8String);
var
  lPrompt: TNXBotPrompt;
begin
  while FPendingPrompts.Count > 0 do
  begin
    lPrompt := TNXBotPrompt(FPendingPrompts[0]);
    if Assigned(FOnPromptFailed) then
      FOnPromptFailed(Self, lPrompt, AReason);
    FPendingPrompts.Delete(0);
  end;
end;

procedure TNXCodexAppServer.FailRoomPrompts(const ARoomJID,
  AReason: UTF8String);
var
  lIndex: Integer;
  lPrompt: TNXBotPrompt;
begin
  if Assigned(FActivePrompt) and (FActivePrompt.RoomJID = ARoomJID) then
    FailActivePrompt(AReason);
  for lIndex := FPendingPrompts.Count - 1 downto 0 do
  begin
    lPrompt := TNXBotPrompt(FPendingPrompts[lIndex]);
    if lPrompt.RoomJID <> ARoomJID then
      Continue;
    if Assigned(FOnPromptFailed) then
      FOnPromptFailed(Self, lPrompt, AReason);
    FPendingPrompts.Delete(lIndex);
  end;
end;

procedure TNXCodexAppServer.CheckPendingTimeouts;
var
  lIndex: Integer;
begin
  for lIndex := FPendingRequests.Count - 1 downto 0 do
    if GetTickCount64 >= TNXPendingRequest(FPendingRequests[lIndex]).FDeadline then
      raise Exception.Create('Codex App Server request timed out.');
end;

procedure TNXCodexAppServer.StopProcess;
var
  lInterrupt: TNXCodexTurnInterruptCommand;
  lCommand: TNXCodexThreadUnsubscribeCommand;
  lUntil: QWord;
begin
  if not Assigned(FProcess) then
  begin
    SetState(cassStopped);
    Exit;
  end;
  FStopRequested := True;
  SetState(cassStopping);
  if (FThreadID <> '') and FProcess.Running then
  begin
    if FActiveTurnID <> '' then
    begin
      lInterrupt := TNXCodexTurnInterruptCommand.Create;
      lInterrupt.params.threadId.Value := FThreadID;
      lInterrupt.params.turnId.Value := FActiveTurnID;
      SendRequest(rkTurnInterrupt, lInterrupt);
    end;
    lCommand := TNXCodexThreadUnsubscribeCommand.Create;
    lCommand.params.threadId.Value := FThreadID;
    SendRequest(rkThreadUnsubscribe, lCommand);
    lUntil := GetTickCount64 + 250;
    while FProcess.Running and (GetTickCount64 < lUntil) do
    begin
      DrainProcess;
      Sleep(cLoopDelayMS);
    end;
  end;
  FailActivePrompt('Codex App Server stopped.');
  FailQueuedPrompts('Codex App Server stopped.');
  CloseProcess;
  SetState(cassStopped);
end;

procedure TNXCodexAppServer.CloseProcess;
begin
  if Assigned(FProcess) then
  begin
    if FProcess.Running then
      FProcess.Terminate(0);
    FreeAndNil(FProcess);
  end;
  FPendingRequests.Clear;
  FStdoutBuffer := '';
  FStderrBuffer := '';
  FThreadID := '';
  FActiveTurnID := '';
end;

end.
