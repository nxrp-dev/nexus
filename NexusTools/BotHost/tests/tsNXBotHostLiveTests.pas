unit tsNXBotHostLiveTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXBotHostLiveTests(ARegistry: TNXTestRegistry);

implementation

uses
  SysUtils,
  obNXTestContext,
  obNXTestSuite,
  obNXBotCatalog,
  obNXBotControlInterpreter,
  obNXBotController,
  obNXBotHost,
  obNXBotHostConfig,
  obNXBotHostState,
  obNXXMPPClient,
  obNXXMPPBotControl,
  obNXXMPPDisco,
  obNXXMPPMessage,
  obNXXMPPMUC,
  tpNXBotControl,
  tpNXBotHost,
  tpNXXMPPMessageTypes,
  tpNXXMPPTypes;

const
  cLiveTestEnabled = 'NEXUS_BOTHOST_LIVE_OPENFIRE';

function RequiredEnvironment(AContext: TNXTestContext;
  const AName: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result = '' then
    AContext.Fail('Live test environment variable is empty: ' + AName);
end;

type
  TObserver = class
  private
    FCriticalSection: TRTLCriticalSection;
    FControlCount: Integer;
    FControlResult: TNXBotControlResult;
    FError: UTF8String;
    FOnline: Boolean;
    FReply: UTF8String;
    FRoomJoined: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RoomMessage(ASender: TObject; ARoom: TNXXMPPRoom;
      AMessage: TNXXMPPMessage);
    procedure ClearReply;
    procedure ControlComplete(const AResult: TNXBotControlResult);
    procedure Error(ASender: TObject; AStage: TNXXMPPErrorStage;
      const ACondition, AMessage: UTF8String);
    function ErrorText: UTF8String;
    procedure RoomState(ASender: TObject; ARoom: TNXXMPPRoom);
    procedure State(ASender: TObject; AState: TNXXMPPConnectionState);
    procedure Snapshot(out AOnline, ARoomJoined: Boolean;
      out AReply: UTF8String);
    procedure ControlSnapshot(out ACount: Integer;
      out AResult: TNXBotControlResult);
  end;

constructor TObserver.Create;
begin
  inherited Create;
  InitCriticalSection(FCriticalSection);
end;

procedure TObserver.ControlComplete(const AResult: TNXBotControlResult);
begin
  EnterCriticalSection(FCriticalSection);
  try
    Inc(FControlCount);
    FControlResult := AResult;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TObserver.ClearReply;
begin
  EnterCriticalSection(FCriticalSection);
  try
    FReply := '';
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TObserver.ControlSnapshot(out ACount: Integer;
  out AResult: TNXBotControlResult);
begin
  EnterCriticalSection(FCriticalSection);
  try
    ACount := FControlCount;
    AResult := FControlResult;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TObserver.Error(ASender: TObject; AStage: TNXXMPPErrorStage;
  const ACondition, AMessage: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FError := ACondition + ': ' + AMessage;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TObserver.ErrorText: UTF8String;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FError;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

destructor TObserver.Destroy;
begin
  DoneCriticalSection(FCriticalSection);
  inherited Destroy;
end;

procedure TObserver.RoomMessage(ASender: TObject; ARoom: TNXXMPPRoom;
  AMessage: TNXXMPPMessage);
begin
  if (AMessage.Context <> xmdcLive) or
    (AMessage.FromJID <> ARoom.JID + '/NexusBot') then
    Exit;
  EnterCriticalSection(FCriticalSection);
  try
    FReply := AMessage.Body;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TObserver.RoomState(ASender: TObject; ARoom: TNXXMPPRoom);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FRoomJoined := ARoom.State = xrsJoined;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TObserver.State(ASender: TObject; AState: TNXXMPPConnectionState);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FOnline := AState = xcsOnline;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TObserver.Snapshot(out AOnline, ARoomJoined: Boolean;
  out AReply: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    AOnline := FOnline;
    ARoomJoined := FRoomJoined;
    AReply := FReply;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure WaitHost(AHost: TNXBotHost; const AWhat: string;
  AReady: Boolean; ATimeoutMS: Cardinal);
var
  lDeadline: QWord;
  lSnapshot: TNXBotHostSnapshot;
  lSatisfied: Boolean;
  lIndex: Integer;
  lRoomState: UTF8String;
begin
  lDeadline := GetTickCount64 + ATimeoutMS;
  repeat
    lSnapshot := AHost.State.Snapshot;
    lRoomState := 'left';
    if AWhat = 'appserver' then
      lSatisfied := lSnapshot.AppServerState = cassReady
    else if AWhat = 'xmpp' then
      lSatisfied := lSnapshot.XMPPState = 'online'
    else
    begin
      lRoomState := 'left';
      for lIndex := 0 to High(lSnapshot.Rooms) do
        if lSnapshot.Rooms[lIndex].RoomJID = UTF8String(AWhat) then
          lRoomState := lSnapshot.Rooms[lIndex].State;
      lSatisfied := lRoomState = 'joined';
    end;
    if lSatisfied = AReady then
      Exit;
    if (lSnapshot.AppServerState = cassFailed) or
      (lSnapshot.XMPPState = 'failed') or (lRoomState = 'failed') then
      raise Exception.Create('Host failed while waiting for ' + AWhat +
        LineEnding + string(lSnapshot.Journal));
    Sleep(10);
  until GetTickCount64 >= lDeadline;
  raise Exception.Create('Timed out waiting for host ' + AWhat + '.');
end;

procedure WaitControl(AObserver: TObserver; AHost: TNXBotHost;
  ACount: Integer; out AResult: TNXBotControlResult);
var
  lCurrent: Integer;
  lDeadline: QWord;
begin
  lDeadline := GetTickCount64 + 30000;
  repeat
    AObserver.ControlSnapshot(lCurrent, AResult);
    if lCurrent >= ACount then
      Exit;
    Sleep(10);
  until GetTickCount64 >= lDeadline;
  raise Exception.Create('Timed out waiting for bot-control IQ result.' +
    LineEnding + string(AHost.State.Snapshot.Journal));
end;

procedure WaitObserver(AObserver: TObserver; ARequireRoom: Boolean;
  ATimeoutMS: Cardinal);
var
  lDeadline: QWord;
  lOnline: Boolean;
  lReply: UTF8String;
  lRoom: Boolean;
begin
  lDeadline := GetTickCount64 + ATimeoutMS;
  repeat
    AObserver.Snapshot(lOnline, lRoom, lReply);
    if lOnline and ((not ARequireRoom) or lRoom) then
      Exit;
    if AObserver.ErrorText <> '' then
      raise Exception.Create('Observer XMPP failed: ' +
        string(AObserver.ErrorText));
    Sleep(10);
  until GetTickCount64 >= lDeadline;
  raise Exception.Create('Timed out waiting for observer XMPP state.');
end;

procedure TestOpenfireCodex(AContext: TNXTestContext);
var
  lBinding: TNXBotDeploymentBinding;
  lBotJID: string;
  lBotPasswordEnvironment: string;
  lCAFile: string;
  lCatalog: TNXBotCatalog;
  lCatalogFile: string;
  lCodexExecutable: string;
  lConfig: TNXBotHostConfig;
  lControl: TNXXMPPBotControlModule;
  lControlResult: TNXBotControlResult;
  lController: TNXBotController;
  lControllerConfig: TNXBotControllerConfig;
  lDeadline: QWord;
  lEndpointHost: string;
  lHost: TNXBotHost;
  lInterpreter: TNXBotControlInterpreter;
  lMUC: TNXXMPPMUCModule;
  lModel: string;
  lObserver: TObserver;
  lObserverClient: TNXXMPPClient;
  lObserverJID: string;
  lObserverPassword: string;
  lOperation: TNXBotControlOperation;
  lOnline: Boolean;
  lPort: Integer;
  lReply: UTF8String;
  lRoomJID: string;
  lRoomJoined: Boolean;
  lRuntimeDirectory: string;
begin
  if GetEnvironmentVariable(cLiveTestEnabled) <> '1' then
    AContext.Skip('Set ' + cLiveTestEnabled + '=1 to run the Openfire/Codex ' +
      'integration test.');
  lCodexExecutable := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_CODEX_EXECUTABLE');
  lRuntimeDirectory := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_RUNTIME_DIRECTORY');
  lModel := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_MODEL');
  lBotJID := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_BOT_JID');
  lBotPasswordEnvironment := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_BOT_PASSWORD_ENVIRONMENT_VARIABLE');
  RequiredEnvironment(AContext, lBotPasswordEnvironment);
  lObserverJID := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OBSERVER_JID');
  lObserverPassword := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OBSERVER_PASSWORD');
  lCAFile := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_CA_FILE');
  lEndpointHost := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_ENDPOINT_HOST');
  lPort := StrToInt(RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_ENDPOINT_PORT'));
  lRoomJID := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_ROOM_JID');
  lCatalogFile := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_CATALOG_FILE');

  lConfig := TNXBotHostConfig.Create;
  lConfig.CodexExecutable := lCodexExecutable;
  lConfig.RuntimeDirectory := lRuntimeDirectory;
  lConfig.CodexModel := lModel;
  lConfig.XMPPJID := lBotJID;
  lConfig.PasswordEnvironmentVariable := lBotPasswordEnvironment;
  lConfig.Resource := 'NexusBotHost-' + IntToStr(GetTickCount64);
  lConfig.CAFile := lCAFile;
  lConfig.EndpointHost := lEndpointHost;
  lConfig.EndpointPort := lPort;
  lConfig.RoomJID := lRoomJID;
  lConfig.Nick := 'NexusBot';

  lControllerConfig := TNXBotControllerConfig.Create;
  lControllerConfig.Operators.Add(lObserverJID);
  lBinding := TNXBotDeploymentBinding.Create;
  lBinding.BotName := 'NexusBot';
  lBinding.AllowPlain := True;
  lBinding.CAFile := lCAFile;
  lBinding.CodexExecutable := lCodexExecutable;
  lBinding.EndpointHost := lEndpointHost;
  lBinding.EndpointPort := lPort;
  lBinding.Nick := 'NexusBot';
  lBinding.PasswordEnvironmentVariable := lBotPasswordEnvironment;
  lBinding.Resource := lConfig.Resource;
  lBinding.RuntimeDirectory := lRuntimeDirectory;
  lBinding.XMPPJID := lBotJID;
  lControllerConfig.Bindings.Add(lBinding);
  lCatalog := TNXBotCatalog.Create;
  if not lCatalog.Load(lCatalogFile, lControllerConfig) then
    raise Exception.Create(lCatalog.Diagnostics.Text);
  lController := TNXBotController.Create(lCatalog, lControllerConfig);
  lControllerConfig.Free;
  lControllerConfig := nil;
  lHost := TNXBotHost.Create(lConfig,
    lCatalog.Find('NexusBot').Instructions);
  if not lController.AdoptHost('NexusBot', lHost) then
    raise Exception.Create('Could not adopt the live NexusBot host.');
  lInterpreter := TNXBotControlInterpreter.Create(lController, lHost);
  lHost.OnPrompt := @lInterpreter.HandlePrompt;
  lHost.AppServer.OnBotControl := @lController.HandleModelControl;
  lControl := TNXXMPPBotControlModule.Create;
  lControl.OnRequest := @lController.Execute;
  lControl.OnCancel := @lController.Cancel;
  lHost.AddXMPPModule(lControl);
  lHost.AddXMPPModule(TNXXMPPDiscoModule.Create('client', 'bot', 'NexusBot'));
  lObserver := TObserver.Create;
  lObserverClient := TNXXMPPClient.Create;
  lMUC := TNXXMPPMUCModule.Create;
  try
    lObserverClient.Config.JID := UTF8String(lObserverJID);
    lObserverClient.Config.Password := UTF8String(lObserverPassword);
    lObserverClient.Config.Resource := 'NexusBotObserver-' +
      IntToStr(GetTickCount64);
    lObserverClient.Config.CAFile := lCAFile;
    lObserverClient.Config.EndpointHost := lEndpointHost;
    lObserverClient.Config.EndpointPort := lPort;
    lObserverClient.Config.AllowPlain := True;
    lObserverClient.OnError := @lObserver.Error;
    lObserverClient.OnState := @lObserver.State;
    lMUC.OnRoomMessage := @lObserver.RoomMessage;
    lMUC.OnRoomState := @lObserver.RoomState;
    lObserverClient.AddModule(lMUC);
    lControl := TNXXMPPBotControlModule.Create;
    lObserverClient.AddModule(lControl);
    lObserverClient.AddModule(TNXXMPPDiscoModule.Create('client', 'bot',
      'NexusBot observer'));

    if not lHost.StartAppServer then
      raise Exception.Create('Bot App Server command was rejected.');
    WaitHost(lHost, 'appserver', True, 30000);
    if not lHost.ConnectXMPP then
      raise Exception.Create('Bot XMPP connect failed.');
    WaitHost(lHost, 'xmpp', True, 15000);
    if not lHost.JoinRoom(UTF8String(lRoomJID)) then
      raise Exception.Create('Bot room join command was rejected.');
    WaitHost(lHost, lRoomJID, True, 15000);

    lObserverClient.Connect;
    WaitObserver(lObserver, False, 15000);
    if not lMUC.Join(UTF8String(lRoomJID), 'Observer', '') then
      raise Exception.Create('Observer room join command was rejected.');
    WaitObserver(lObserver, True, 15000);

    lOperation := NXBotControlOperation(bcokList, '', '');
    if not lControl.Call(UTF8String(lBotJID + '/' + lConfig.Resource),
      lOperation, @lObserver.ControlComplete) then
      raise Exception.Create('LIST IQ was rejected locally.');
    WaitControl(lObserver, lHost, 1, lControlResult);
    if lControlResult.Error <> bceNone then
      raise Exception.Create('LIST IQ failed: ' + string(lControlResult.Detail));

    lOperation := NXBotControlOperation(bcokStatus, 'NexusBot', '');
    if not lControl.Call(UTF8String(lBotJID + '/' + lConfig.Resource),
      lOperation, @lObserver.ControlComplete) then
      raise Exception.Create('STATUS IQ was rejected locally.');
    WaitControl(lObserver, lHost, 2, lControlResult);
    if lControlResult.Error <> bceNone then
      raise Exception.Create('STATUS IQ failed: ' + string(lControlResult.Detail));

    lOperation := NXBotControlOperation(bcokDismiss, 'NexusBot',
      UTF8String(lRoomJID));
    if not lControl.Call(UTF8String(lBotJID + '/' + lConfig.Resource),
      lOperation, @lObserver.ControlComplete) then
      raise Exception.Create('DISMISS IQ was rejected locally.');
    WaitControl(lObserver, lHost, 3, lControlResult);
    WaitHost(lHost, lRoomJID, False, 15000);
    if not lControl.Call(UTF8String(lBotJID + '/' + lConfig.Resource),
      lOperation, @lObserver.ControlComplete) then
      raise Exception.Create('Idempotent DISMISS IQ was rejected locally.');
    WaitControl(lObserver, lHost, 4, lControlResult);
    if not lControlResult.NoOp then
      raise Exception.Create('Repeated DISMISS was not a no-op.');

    lOperation := NXBotControlOperation(bcokInvite, 'NexusBot',
      UTF8String(lRoomJID));
    if not lControl.Call(UTF8String(lBotJID + '/' + lConfig.Resource),
      lOperation, @lObserver.ControlComplete) then
      raise Exception.Create('INVITE IQ was rejected locally.');
    WaitControl(lObserver, lHost, 5, lControlResult);
    WaitHost(lHost, lRoomJID, True, 15000);
    if not lControl.Call(UTF8String(lBotJID + '/' + lConfig.Resource),
      lOperation, @lObserver.ControlComplete) then
      raise Exception.Create('Idempotent INVITE IQ was rejected locally.');
    WaitControl(lObserver, lHost, 6, lControlResult);
    if not lControlResult.NoOp then
      raise Exception.Create('Repeated INVITE was not a no-op.');

    lObserver.ClearReply;
    if not lMUC.SendGroupMessage(UTF8String(lRoomJID),
      '@NexusBot Reply with exactly: Nexus BotHost XMPP live test passed') then
      raise Exception.Create('Observer group message command was rejected.');

    lDeadline := GetTickCount64 + 120000;
    repeat
      lObserver.Snapshot(lOnline, lRoomJoined, lReply);
      if lReply <> '' then
        Break;
      Sleep(10);
    until GetTickCount64 >= lDeadline;
    if lReply = '' then
      raise Exception.Create('The addressed room message received no answer.' +
        LineEnding + string(lHost.State.Snapshot.Journal));
    AContext.AssertEquals('Nexus BotHost XMPP live test passed',
      string(lReply), 'The live bot should return the requested exact reply.');
  finally
    if Assigned(lMUC) then
      lMUC.Leave(UTF8String(lRoomJID));
    lObserverClient.Disconnect;
    lObserverClient.Free;
    lObserver.Free;
    if Assigned(lHost) then
      lHost.OnPrompt := nil;
    lInterpreter.Free;
    lController.Free;
  end;
end;

procedure RegisterNXBotHostLiveTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusBotHostLive');
  lSuite.AddTest('OpenfireCodex', @TestOpenfireCodex, 'integration');
end;

end.
