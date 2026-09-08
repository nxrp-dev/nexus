unit tsNXBotHostLiveTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXBotHostLiveTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SyncObjs,
  SysUtils,
  synacode,
  obNXTestContext,
  obNXTestSuite,
  obNXBotCatalog,
  obNXBotControlInterpreter,
  obNXBotController,
  obNXBotHost,
  obNXBotHostConfig,
  obNXBotFileExchange,
  obNXBotHostState,
  obNXXMPPClient,
  obNXXMPPBotControl,
  obNXXMPPDisco,
  obNXXMPPMessage,
  obNXXMPPMessageFeatures,
  obNXXMPPMUC,
  obNXXMPPFileSharing,
  obNXXMPPOpenSSL,
  tpNXBotControl,
  tpNXBotFileTypes,
  tpNXBotHost,
  tpNXXMPPMessageTypes,
  tpNXXMPPTypes;

const
  cLiveTestEnabled = 'NEXUS_BOTHOST_LIVE_OPENFIRE';
  cOpenAILiveTestEnabled = 'NEXUS_BOTHOST_LIVE_OPENAI';
  cInteropLiveTestEnabled = 'NEXUS_BOTHOST_LIVE_BOT_INTEROP';
  cFileExchangeLiveTestEnabled = 'NEXUS_BOTHOST_LIVE_FILE_EXCHANGE';

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
    FBotNick: UTF8String;
    FWatchDirect: Boolean;
    FError: UTF8String;
    FOnline: Boolean;
    FReply: UTF8String;
    FRoomJoined: Boolean;
  public
    constructor Create(const ABotNick: UTF8String = 'NexusBot');
    destructor Destroy; override;
    procedure RoomMessage(ASender: TObject; ARoom: TNXXMPPRoom;
      AMessage: TNXXMPPMessage);
    procedure DirectMessage(ASender: TObject; AMessage: TNXXMPPMessage);
    procedure ClearReply;
    procedure WatchBot(const ABotNick: UTF8String);
    procedure WatchDirect;
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

  TLiveFileExchangeRecorder = class
  private
    FExchange: TNXBotFileExchange;
    FSequence: Int64;
  public
    Prompt: TNXBotPrompt;
    ReceiveError: UTF8String;
    ReceivedEvent: TEvent;
    SendDetail: UTF8String;
    SendSuccess: Boolean;
    SentEvent: TEvent;
    constructor Create(AExchange: TNXBotFileExchange);
    destructor Destroy; override;
    procedure FileSent(ASuccess: Boolean; const ADetail: UTF8String);
    procedure MessageReceived(ASender: TObject; AMessage: TNXXMPPMessage);
    procedure PromptReady(ASender: TObject; APrompt: TNXBotPrompt;
      const AError: UTF8String);
  end;

constructor TObserver.Create(const ABotNick: UTF8String);
begin
  inherited Create;
  FBotNick := ABotNick;
  InitCriticalSection(FCriticalSection);
end;

constructor TLiveFileExchangeRecorder.Create(AExchange: TNXBotFileExchange);
begin
  inherited Create;
  FExchange := AExchange;
  ReceivedEvent := TEvent.Create(nil, False, False, '');
  SentEvent := TEvent.Create(nil, False, False, '');
end;

destructor TLiveFileExchangeRecorder.Destroy;
begin
  Prompt.Free;
  SentEvent.Free;
  ReceivedEvent.Free;
  inherited Destroy;
end;

procedure TLiveFileExchangeRecorder.FileSent(ASuccess: Boolean;
  const ADetail: UTF8String);
begin
  SendSuccess := ASuccess;
  SendDetail := ADetail;
  SentEvent.SetEvent;
end;

procedure TLiveFileExchangeRecorder.MessageReceived(ASender: TObject;
  AMessage: TNXXMPPMessage);
var
  lPrompt: TNXBotPrompt;
begin
  if not Assigned(AMessage) or (AMessage.Context <> xmdcLive) or
    (AMessage.TypeValue <> 'chat') or
    (Length(AMessage.Attachments) = 0) then
    Exit;
  Inc(FSequence);
  lPrompt := TNXBotPrompt.Create(FSequence, '', AMessage.FromJID,
    AMessage.ID, AMessage.DisplayBody);
  if not FExchange.AcceptInbound(lPrompt, AMessage.Attachments) then
  begin
    lPrompt.Free;
    ReceiveError := 'The inbound live transfer was rejected.';
    ReceivedEvent.SetEvent;
  end;
end;

procedure TLiveFileExchangeRecorder.PromptReady(ASender: TObject;
  APrompt: TNXBotPrompt; const AError: UTF8String);
begin
  Prompt := APrompt;
  ReceiveError := AError;
  ReceivedEvent.SetEvent;
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

procedure TObserver.WatchBot(const ABotNick: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FBotNick := ABotNick;
    FWatchDirect := False;
    FReply := '';
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TObserver.WatchDirect;
begin
  EnterCriticalSection(FCriticalSection);
  try
    FWatchDirect := True;
    FReply := '';
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TObserver.DirectMessage(ASender: TObject;
  AMessage: TNXXMPPMessage);
begin
  if (AMessage.Context <> xmdcLive) or
    (AMessage.TypeValue <> 'chat') then
    Exit;
  EnterCriticalSection(FCriticalSection);
  try
    if FWatchDirect then
      FReply := AMessage.Body;
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
  if AMessage.Context <> xmdcLive then
    Exit;
  EnterCriticalSection(FCriticalSection);
  try
    if AMessage.FromJID = ARoom.JID + '/' + FBotNick then
      FReply := AMessage.Body;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure WaitHost(AHost: TNXBotHost; const AWhat: string;
  AReady: Boolean; ATimeoutMS: Cardinal); forward;
procedure WaitObserver(AObserver: TObserver; ARequireRoom: Boolean;
  ATimeoutMS: Cardinal); forward;
function WaitReply(AObserver: TObserver; AHost: TNXBotHost;
  ATimeoutMS: Cardinal): UTF8String; forward;

procedure TestOpenfireOpenAI(AContext: TNXTestContext);
var
  lAPIKey: string;
  lBotPassword: string;
  lConfig: TNXBotHostConfig;
  lHost: TNXBotHost;
  lMUC: TNXXMPPMUCModule;
  lObserver: TObserver;
  lObserverClient: TNXXMPPClient;
  lReply: UTF8String;
  lRoomJID: string;
begin
  if GetEnvironmentVariable(cOpenAILiveTestEnabled) <> '1' then
    AContext.Skip('Set ' + cOpenAILiveTestEnabled + '=1 to run the ' +
      'Openfire/OpenAI integration test.');
  lAPIKey := RequiredEnvironment(AContext, RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OPENAI_API_KEY_ENVIRONMENT_VARIABLE'));
  lBotPassword := RequiredEnvironment(AContext,
    RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OPENAI_BOT_PASSWORD_ENVIRONMENT_VARIABLE'));
  lRoomJID := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_ROOM_JID');

  lConfig := TNXBotHostConfig.Create;
  lConfig.Provider := 'OpenAI';
  lConfig.Model := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OPENAI_MODEL');
  lConfig.OpenAICAFile := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OPENAI_CA_FILE');
  lConfig.OpenAIAPIKey := lAPIKey;
  lConfig.XMPPJID := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OPENAI_BOT_JID');
  lConfig.Password := lBotPassword;
  lConfig.Resource := 'NexusOpenAIBotHost-' + IntToStr(GetTickCount64);
  lConfig.CAFile := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_CA_FILE');
  lConfig.EndpointHost := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_ENDPOINT_HOST');
  lConfig.EndpointPort := StrToInt(RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_ENDPOINT_PORT'));
  lConfig.RoomJID := lRoomJID;
  lConfig.Nick := 'OpenAIBot';

  lHost := TNXBotHost.Create(lConfig,
    'Reply directly and concisely to the addressed user.');
  lObserver := TObserver.Create('OpenAIBot');
  lObserverClient := TNXXMPPClient.Create;
  lMUC := TNXXMPPMUCModule.Create;
  try
    lObserverClient.Config.JID := UTF8String(RequiredEnvironment(AContext,
      'NEXUS_BOTHOST_OBSERVER_JID'));
    lObserverClient.Config.Password := UTF8String(RequiredEnvironment(AContext,
      'NEXUS_BOTHOST_OBSERVER_PASSWORD'));
    lObserverClient.Config.Resource := 'NexusOpenAIObserver-' +
      IntToStr(GetTickCount64);
    lObserverClient.Config.CAFile := lConfig.CAFile;
    lObserverClient.Config.EndpointHost := lConfig.EndpointHost;
    lObserverClient.Config.EndpointPort := lConfig.EndpointPort;
    lObserverClient.Config.AllowPlain := True;
    lObserverClient.OnError := @lObserver.Error;
    lObserverClient.OnState := @lObserver.State;
    lMUC.OnRoomMessage := @lObserver.RoomMessage;
    lMUC.OnRoomState := @lObserver.RoomState;
    lObserverClient.AddModule(lMUC);
    if not lHost.StartProvider then
      raise Exception.Create('OpenAI provider command was rejected.');
    WaitHost(lHost, 'appserver', True, 15000);
    if not lHost.ConnectXMPP then
      raise Exception.Create('OpenAI bot XMPP connect failed.');
    WaitHost(lHost, 'xmpp', True, 15000);
    if not lHost.JoinRoom(UTF8String(lRoomJID)) then
      raise Exception.Create('OpenAI bot room join command was rejected.');
    WaitHost(lHost, lRoomJID, True, 15000);

    lObserverClient.Connect;
    WaitObserver(lObserver, False, 15000);
    if not lMUC.Join(UTF8String(lRoomJID), 'OpenAIObserver', '') then
      raise Exception.Create('Observer room join command was rejected.');
    WaitObserver(lObserver, True, 15000);
    if not lMUC.SendGroupMessage(UTF8String(lRoomJID),
      '@OpenAIBot Reply with exactly: OpenAI BotHost live test passed') then
      raise Exception.Create('Observer group message command was rejected.');

    lReply := WaitReply(lObserver, lHost, 120000);
    AContext.AssertEquals('OpenAI BotHost live test passed', string(lReply),
      'The live OpenAI bot should return the requested exact reply.');
  finally
    lMUC.Leave(UTF8String(lRoomJID));
    lObserverClient.Disconnect;
    lObserverClient.Free;
    lObserver.Free;
    lHost.Free;
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
      lSatisfied := lSnapshot.ProviderState = bpsReady
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
    if (lSnapshot.ProviderState = bpsFailed) or
      (lSnapshot.XMPPState = 'failed') or (lRoomState = 'failed') then
      raise Exception.Create('Host failed while waiting for ' + AWhat +
        LineEnding + string(lSnapshot.Journal));
    Sleep(10);
  until GetTickCount64 >= lDeadline;
  raise Exception.Create('Timed out waiting for host ' + AWhat + '.' +
    LineEnding + string(lSnapshot.Journal));
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

function WaitReply(AObserver: TObserver; AHost: TNXBotHost;
  ATimeoutMS: Cardinal): UTF8String;
var
  lDeadline: QWord;
  lOnline: Boolean;
  lRoomJoined: Boolean;
begin
  lDeadline := GetTickCount64 + ATimeoutMS;
  repeat
    AObserver.Snapshot(lOnline, lRoomJoined, Result);
    if Result <> '' then
      Exit;
    Sleep(10);
  until GetTickCount64 >= lDeadline;
  raise Exception.Create('The addressed room message received no answer.' +
    LineEnding + string(AHost.State.Snapshot.Journal));
end;

procedure RunLiveCodex(AContext: TNXTestContext; AInterop: Boolean);
var
  lBinding: TNXBotDeploymentBinding;
  lBotJID: string;
  lBotPassword: string;
  lCAFile: string;
  lCatalog: TNXBotCatalog;
  lCatalogFile: string;
  lCodexExecutable: string;
  lConfig: TNXBotHostConfig;
  lControl: TNXXMPPBotControlModule;
  lControlResult: TNXBotControlResult;
  lController: TNXBotController;
  lControllerConfig: TNXBotControllerConfig;
  lEndpointHost: string;
  lHost: TNXBotHost;
  lInterpreter: TNXBotControlInterpreter;
  lMUC: TNXXMPPMUCModule;
  lMessages: TNXXMPPMessageModule;
  lModel: string;
  lObserver: TObserver;
  lObserverClient: TNXXMPPClient;
  lObserverJID: string;
  lObserverPassword: string;
  lOpenAIAPIKey: string;
  lOpenAICAFile: string;
  lOpenAIBotJID: string;
  lOpenAIPassword: string;
  lOperation: TNXBotControlOperation;
  lPort: Integer;
  lReply: UTF8String;
  lRoomJID: string;
  lRuntimeDirectory: string;
begin
  if AInterop and (GetEnvironmentVariable(cInteropLiveTestEnabled) <> '1') then
    AContext.Skip('Set ' + cInteropLiveTestEnabled + '=1 to run the ' +
      'NexusBot/OpenAIBot integration test.');
  if (not AInterop) and (GetEnvironmentVariable(cLiveTestEnabled) <> '1') then
    AContext.Skip('Set ' + cLiveTestEnabled + '=1 to run the Openfire/Codex ' +
      'integration test.');
  lCodexExecutable := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_CODEX_EXECUTABLE');
  lRuntimeDirectory := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_RUNTIME_DIRECTORY');
  lModel := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_MODEL');
  lBotJID := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_BOT_JID');
  lBotPassword := RequiredEnvironment(AContext,
    RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_BOT_PASSWORD_ENVIRONMENT_VARIABLE'));
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
  if AInterop then
  begin
    lOpenAIAPIKey := RequiredEnvironment(AContext,
      RequiredEnvironment(AContext,
      'NEXUS_BOTHOST_OPENAI_API_KEY_ENVIRONMENT_VARIABLE'));
    lOpenAICAFile := RequiredEnvironment(AContext,
      'NEXUS_BOTHOST_OPENAI_CA_FILE');
    lOpenAIBotJID := RequiredEnvironment(AContext,
      'NEXUS_BOTHOST_OPENAI_BOT_JID');
    lOpenAIPassword := RequiredEnvironment(AContext,
      RequiredEnvironment(AContext,
      'NEXUS_BOTHOST_OPENAI_BOT_PASSWORD_ENVIRONMENT_VARIABLE'));
  end
  else
  begin
    lOpenAIAPIKey := 'unused';
    lOpenAICAFile := '';
    lOpenAIBotJID := 'test2@nexus.local';
    lOpenAIPassword := 'unused';
  end;

  lConfig := TNXBotHostConfig.Create;
  lConfig.CodexExecutable := lCodexExecutable;
  lConfig.RuntimeDirectory := lRuntimeDirectory;
  lConfig.Model := lModel;
  lConfig.XMPPJID := lBotJID;
  lConfig.Password := lBotPassword;
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
  lBinding.Password := lBotPassword;
  lBinding.Resource := lConfig.Resource;
  lBinding.RuntimeDirectory := lRuntimeDirectory;
  lBinding.XMPPJID := lBotJID;
  lControllerConfig.Bindings.Add(lBinding);
  lBinding := TNXBotDeploymentBinding.Create;
  lBinding.BotName := 'OpenAIBot';
  lBinding.AllowPlain := True;
  lBinding.CAFile := lCAFile;
  lBinding.EndpointHost := lEndpointHost;
  lBinding.EndpointPort := lPort;
  lBinding.Nick := 'OpenAIBot';
  lBinding.OpenAICAFile := lOpenAICAFile;
  lBinding.OpenAIAPIKey := lOpenAIAPIKey;
  lBinding.Password := lOpenAIPassword;
  lBinding.Resource := 'NexusOpenAIBotHost-' + IntToStr(GetTickCount64);
  lBinding.XMPPJID := lOpenAIBotJID;
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
  lHost.OnBotControl := @lController.HandleModelControl;
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
    lMessages := TNXXMPPMessageModule.Create;
    lMessages.OnMessage := @lObserver.DirectMessage;
    lObserverClient.AddModule(lMessages);
    lControl := TNXXMPPBotControlModule.Create;
    lObserverClient.AddModule(lControl);
    lObserverClient.AddModule(TNXXMPPDiscoModule.Create('client', 'bot',
      'NexusBot observer'));

    if not lHost.StartProvider then
      raise Exception.Create('Bot provider command was rejected.');
    WaitHost(lHost, 'appserver', True, 30000);
    if not lHost.ConnectXMPP then
      raise Exception.Create('Bot XMPP connect failed.');
    WaitHost(lHost, 'xmpp', True, 30000);
    if not lHost.JoinRoom(UTF8String(lRoomJID)) then
      raise Exception.Create('Bot room join command was rejected.');
    WaitHost(lHost, lRoomJID, True, 30000);

    lObserverClient.Connect;
    WaitObserver(lObserver, False, 30000);
    if not lMUC.Join(UTF8String(lRoomJID), 'Observer', '') then
      raise Exception.Create('Observer room join command was rejected.');
    WaitObserver(lObserver, True, 30000);

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

    lReply := WaitReply(lObserver, lHost, 120000);
    AContext.AssertEquals('Nexus BotHost XMPP live test passed',
      string(lReply), 'The live bot should return the requested exact reply.');

    if AInterop then
    begin
      lObserver.WatchDirect;
      if not lMUC.SendPrivateMessage(UTF8String(lRoomJID + '/NexusBot'),
        'What XMPP room did this private conversation originate from? ' +
        'Reply with exactly the room JID.') then
        raise Exception.Create('The MUC private bot message was rejected locally.');
      lReply := WaitReply(lObserver, lHost, 120000);
      AContext.AssertEquals(lRoomJID, string(lReply),
        'NexusBot should receive and report the originating room context.');

      lObserver.WatchBot('NexusBot');
      if not lMUC.SendGroupMessage(UTF8String(lRoomJID),
        '@NexusBot invite OpenAIBot') then
        raise Exception.Create('The OpenAIBot room summon was rejected locally.');
      lReply := WaitReply(lObserver, lHost, 120000);
      AContext.AssertTrue(Pos('OpenAIBot: ready, XMPP online',
        string(lReply)) > 0,
        'A verified occupant of a temporary room should be able to summon ' +
        'OpenAIBot. Actual response: ' + string(lReply));

      lObserver.WatchBot('OpenAIBot');
      if not lHost.SendRoomMessage(UTF8String(lRoomJID),
        'OpenAIBot, Reply with exactly: Nexus bot interop passed') then
        raise Exception.Create('NexusBot could not address OpenAIBot.');
      lReply := WaitReply(lObserver, lHost, 120000);
      AContext.AssertEquals('Nexus bot interop passed', string(lReply),
        'OpenAIBot should answer the message sent by NexusBot.');
    end;
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

procedure TestFileExchange(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lBody: RawByteString;
  lCAFile: string;
  lEndpointHost: string;
  lEndpointPort: Integer;
  lExpectedHash: UTF8String;
  lFile: TFileStream;
  lMessages: TNXXMPPMessageModule;
  lOriginList: string;
  lPath: string;
  lReceiverClient: TNXXMPPClient;
  lReceiverConfig: TNXBotHostConfig;
  lReceiverExchange: TNXBotFileExchange;
  lReceiverFiles: TNXXMPPFileSharingModule;
  lReceiverJID: string;
  lReceiverObserver: TObserver;
  lReceiverPassword: string;
  lReceiverResource: string;
  lReceived: RawByteString;
  lRecorder: TLiveFileExchangeRecorder;
  lSenderClient: TNXXMPPClient;
  lSenderConfig: TNXBotHostConfig;
  lSenderDirectory: string;
  lSenderExchange: TNXBotFileExchange;
  lSenderFiles: TNXXMPPFileSharingModule;
  lSenderJID: string;
  lSenderObserver: TObserver;
  lSenderPassword: string;
  lSenderResource: string;
  lReceiverDirectory: string;
begin
  if GetEnvironmentVariable(cFileExchangeLiveTestEnabled) <> '1' then
    AContext.Skip('Set ' + cFileExchangeLiveTestEnabled + '=1 to run the ' +
      'live XEP-0363 file-exchange test.');
  lSenderJID := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_BOT_JID');
  lSenderPassword := RequiredEnvironment(AContext,
    RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_BOT_PASSWORD_ENVIRONMENT_VARIABLE'));
  lReceiverJID := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OBSERVER_JID');
  lReceiverPassword := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_OBSERVER_PASSWORD');
  lCAFile := RequiredEnvironment(AContext, 'NEXUS_BOTHOST_CA_FILE');
  lEndpointHost := RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_ENDPOINT_HOST');
  lEndpointPort := StrToInt(RequiredEnvironment(AContext,
    'NEXUS_BOTHOST_ENDPOINT_PORT'));
  lOriginList := GetEnvironmentVariable(
    'NEXUS_BOTHOST_TRUSTED_FILE_ORIGINS');
  lSenderResource := 'NexusFileSender-' + IntToStr(GetTickCount64);
  lReceiverResource := 'NexusFileReceiver-' + IntToStr(GetTickCount64);
  lReceived := '';
  lSenderDirectory := GetTempFileName(GetTempDir(False), 'nxfs');
  DeleteFile(lSenderDirectory);
  CreateDir(lSenderDirectory);
  lReceiverDirectory := GetTempFileName(GetTempDir(False), 'nxfr');
  DeleteFile(lReceiverDirectory);
  CreateDir(lReceiverDirectory);

  lSenderConfig := TNXBotHostConfig.Create;
  lSenderConfig.CAFile := lCAFile;
  lSenderConfig.ExchangeDirectory := lSenderDirectory;
  lSenderConfig.TrustedFileOrigins.CommaText := lOriginList;
  lReceiverConfig := TNXBotHostConfig.Create;
  lReceiverConfig.CAFile := lCAFile;
  lReceiverConfig.ExchangeDirectory := lReceiverDirectory;
  lReceiverConfig.TrustedFileOrigins.CommaText := lOriginList;
  lSenderExchange := TNXBotFileExchange.Create(lSenderConfig);
  lReceiverExchange := TNXBotFileExchange.Create(lReceiverConfig);
  lRecorder := TLiveFileExchangeRecorder.Create(lReceiverExchange);
  lReceiverExchange.OnPromptReady := @lRecorder.PromptReady;
  lSenderObserver := TObserver.Create;
  lReceiverObserver := TObserver.Create;
  lSenderClient := TNXXMPPClient.Create;
  lReceiverClient := TNXXMPPClient.Create;
  lSenderFiles := TNXXMPPFileSharingModule.Create;
  lReceiverFiles := TNXXMPPFileSharingModule.Create;
  lMessages := TNXXMPPMessageModule.Create;
  lPath := IncludeTrailingPathDelimiter(lSenderDirectory) + 'live.txt';
  lBody := 'Nexus XEP-0363 live file exchange ' +
    RawByteString(IntToStr(GetTickCount64));
  lFile := TFileStream.Create(lPath, fmCreate);
  try
    lFile.WriteBuffer(lBody[1], Length(lBody));
  finally
    lFile.Free;
  end;
  lAttachment := TNXBotAttachment.Create;
  lAttachment.ID := 'live-' + UTF8String(IntToStr(GetTickCount64));
  lAttachment.SFSID := lAttachment.ID;
  lAttachment.Name := 'live.txt';
  lAttachment.MediaType := 'text/plain';
  lAttachment.Size := Length(lBody);
  lExpectedHash := UTF8String(EncodeBase64(TNXXMPPOpenSSL.SHA256(lBody)));
  lAttachment.HashSHA256 := lExpectedHash;
  lAttachment.Path := lPath;
  try
    lSenderClient.Config.JID := UTF8String(lSenderJID);
    lSenderClient.Config.Password := UTF8String(lSenderPassword);
    lSenderClient.Config.Resource := UTF8String(lSenderResource);
    lSenderClient.Config.CAFile := lCAFile;
    lSenderClient.Config.EndpointHost := lEndpointHost;
    lSenderClient.Config.EndpointPort := lEndpointPort;
    lSenderClient.Config.AllowPlain := True;
    lSenderClient.OnError := @lSenderObserver.Error;
    lSenderClient.OnState := @lSenderObserver.State;
    lSenderClient.AddModule(lSenderFiles);

    lReceiverClient.Config.JID := UTF8String(lReceiverJID);
    lReceiverClient.Config.Password := UTF8String(lReceiverPassword);
    lReceiverClient.Config.Resource := UTF8String(lReceiverResource);
    lReceiverClient.Config.CAFile := lCAFile;
    lReceiverClient.Config.EndpointHost := lEndpointHost;
    lReceiverClient.Config.EndpointPort := lEndpointPort;
    lReceiverClient.Config.AllowPlain := True;
    lReceiverClient.OnError := @lReceiverObserver.Error;
    lReceiverClient.OnState := @lReceiverObserver.State;
    lReceiverClient.AddModule(lReceiverFiles);
    lMessages.OnMessage := @lRecorder.MessageReceived;
    lReceiverClient.AddModule(lMessages);

    lReceiverClient.Connect;
    WaitObserver(lReceiverObserver, False, 30000);
    lSenderClient.Connect;
    WaitObserver(lSenderObserver, False, 30000);
    AContext.AssertTrue(lSenderExchange.AcceptOutbound(lAttachment,
      lSenderFiles, UTF8String(lReceiverJID + '/' + lReceiverResource),
      'chat', '', '', '', @lRecorder.FileSent),
      'The live outbound transfer should be accepted.');
    lAttachment := nil;
    AContext.AssertTrue(lRecorder.SentEvent.WaitFor(120000) = wrSignaled,
      'The live upload should complete within the transfer timeout.');
    AContext.AssertTrue(lRecorder.SendSuccess,
      'The live upload failed: ' + string(lRecorder.SendDetail));
    AContext.AssertTrue(lRecorder.ReceivedEvent.WaitFor(120000) = wrSignaled,
      'The live file-share message and download should complete.');
    AContext.AssertEquals('', string(lRecorder.ReceiveError),
      'The live inbound transfer should not report an error.');
    AContext.AssertTrue(Assigned(lRecorder.Prompt) and
      (lRecorder.Prompt.Attachments.Count = 1),
      'The receiver should obtain exactly one staged attachment.');
    lFile := TFileStream.Create(lRecorder.Prompt.Attachments[0].Path,
      fmOpenRead or fmShareDenyWrite);
    try
      SetLength(lReceived, lFile.Size);
      if Length(lReceived) > 0 then
        lFile.ReadBuffer(lReceived[1], Length(lReceived));
    finally
      lFile.Free;
    end;
    AContext.AssertTrue(lReceived = lBody,
      'The downloaded bytes must exactly match the uploaded file.');
    AContext.AssertEquals(string(lExpectedHash),
      string(lRecorder.Prompt.Attachments[0].HashSHA256),
      'The staged attachment should retain the verified SHA-256 hash.');
  finally
    lAttachment.Free;
    lSenderClient.Disconnect;
    lReceiverClient.Disconnect;
    lSenderExchange.Free;
    lReceiverExchange.Free;
    lSenderClient.Free;
    lReceiverClient.Free;
    lRecorder.Free;
    lSenderObserver.Free;
    lReceiverObserver.Free;
    lSenderConfig.Free;
    lReceiverConfig.Free;
    if FileExists(lPath) then DeleteFile(lPath);
    RemoveDir(lSenderDirectory);
    RemoveDir(lReceiverDirectory);
  end;
end;

procedure TestOpenfireCodex(AContext: TNXTestContext);
begin
  RunLiveCodex(AContext, False);
end;

procedure TestBotInterop(AContext: TNXTestContext);
begin
  RunLiveCodex(AContext, True);
end;

procedure RegisterNXBotHostLiveTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusBotHostLive');
  lSuite.AddTest('OpenfireCodex', @TestOpenfireCodex, 'integration');
  lSuite.AddTest('OpenfireOpenAI', @TestOpenfireOpenAI, 'integration');
  lSuite.AddTest('BotInterop', @TestBotInterop, 'integration');
  lSuite.AddTest('FileExchange', @TestFileExchange, 'integration');
end;

end.
