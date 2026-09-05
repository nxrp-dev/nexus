unit obNXBotHost;

{$mode objfpc}{$H+}

interface

uses
  obNXBotHostConfig,
  obNXBotHostState,
  obNXCodexAppServer,
  obNXXMPPClient,
  obNXXMPPMessage,
  obNXXMPPModule,
  obNXXMPPMUC,
  tpNXBotHost,
  tpNXXMPPTypes;

type
  TNXBotHostChangedEvent = procedure(ASender: TObject) of object;
  TNXBotHostPromptEvent = function(ASender: TObject;
    APrompt: TNXBotPrompt): Boolean of object;

  TNXBotHost = class
  private
    FAppServer: TNXCodexAppServer;
    FConfig: TNXBotHostConfig;
    FInstructions: UTF8String;
    FMUC: TNXXMPPMUCModule;
    FSequence: QWord;
    FState: TNXBotHostState;
    FXMPP: TNXXMPPClient;
    FOnChanged: TNXBotHostChangedEvent;
    FOnPrompt: TNXBotHostPromptEvent;
    procedure Changed;
    procedure AppServerDiagnostic(ASender: TObject; const AText: UTF8String);
    procedure AppServerFinalAnswer(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    procedure AppServerPromptFailed(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    procedure AppServerState(ASender: TObject;
      AState: TNXCodexAppServerState; const ADetail: UTF8String);
    procedure XMPPError(ASender: TObject; AStage: TNXXMPPErrorStage;
      const ACondition, AMessage: UTF8String);
    procedure XMPPRoomMessage(ASender: TObject; ARoom: TNXXMPPRoom;
      AMessage: TNXXMPPMessage);
    procedure XMPPRoomState(ASender: TObject; ARoom: TNXXMPPRoom);
    procedure XMPPState(ASender: TObject; AState: TNXXMPPConnectionState);
  public
    constructor Create(AConfig: TNXBotHostConfig;
      const AInstructions: UTF8String);
    destructor Destroy; override;

    function ConnectXMPP: Boolean; virtual;
    procedure DisconnectXMPP; virtual;
    function JoinRoom(const ARoomJID: UTF8String): Boolean; virtual;
    function LeaveRoom(const ARoomJID: UTF8String): Boolean; virtual;
    function StartAppServer: Boolean; virtual;
    function StopAppServer: Boolean; virtual;
    procedure RefreshIdentity;
    procedure ClearView;
    procedure Shutdown; virtual;
    procedure AddXMPPModule(AModule: TNXXMPPModule);
    function SendRoomMessage(const ARoomJID,
      AText: UTF8String): Boolean;

    property Config: TNXBotHostConfig read FConfig;
    property State: TNXBotHostState read FState;
    property AppServer: TNXCodexAppServer read FAppServer;
    property MUC: TNXXMPPMUCModule read FMUC;
    property XMPP: TNXXMPPClient read FXMPP;
    property OnChanged: TNXBotHostChangedEvent read FOnChanged write FOnChanged;
    property OnPrompt: TNXBotHostPromptEvent read FOnPrompt write FOnPrompt;
  end;

implementation

uses
  SysUtils,
  obNXBotHostRouter,
  tpNXXMPPMessageTypes;

function NXRoomStateName(AState: TNXXMPPRoomState): UTF8String;
begin
  case AState of
    xrsJoining: Result := 'joining';
    xrsCreating: Result := 'creating';
    xrsConfiguring: Result := 'configuring';
    xrsJoined: Result := 'joined';
    xrsLeaving: Result := 'leaving';
    xrsStale: Result := 'stale';
    xrsRejoining: Result := 'rejoining';
    xrsFailed: Result := 'failed';
    xrsLeft: Result := 'left';
  end;
end;

constructor TNXBotHost.Create(AConfig: TNXBotHostConfig;
  const AInstructions: UTF8String);
begin
  inherited Create;
  if not Assigned(AConfig) then
    raise Exception.Create('BotHost configuration is required.');
  FConfig := AConfig;
  FInstructions := AInstructions;
  FState := TNXBotHostState.Create(FConfig.JournalCapacity);
  FState.SetIdentity(UTF8String(FConfig.CodexModel), UTF8String(FConfig.Nick));
  FState.SetRoom(UTF8String(FConfig.RoomJID), 'left');

  FAppServer := TNXCodexAppServer.Create;
  FAppServer.AnswerMaximumBytes := FConfig.AnswerMaximumBytes;
  FAppServer.CommandCapacity := FConfig.CommandCapacity;
  FAppServer.PromptCapacity := FConfig.PromptCapacity;
  FAppServer.RequestTimeoutMS := FConfig.RequestTimeoutMS;
  FAppServer.OnDiagnostic := @AppServerDiagnostic;
  FAppServer.OnFinalAnswer := @AppServerFinalAnswer;
  FAppServer.OnPromptFailed := @AppServerPromptFailed;
  FAppServer.OnState := @AppServerState;

  FXMPP := TNXXMPPClient.Create;
  FXMPP.OnError := @XMPPError;
  FXMPP.OnState := @XMPPState;
  FMUC := TNXXMPPMUCModule.Create;
  FMUC.OnRoomMessage := @XMPPRoomMessage;
  FMUC.OnRoomState := @XMPPRoomState;
  FXMPP.AddModule(FMUC);
end;

destructor TNXBotHost.Destroy;
begin
  Shutdown;
  FreeAndNil(FAppServer);
  FreeAndNil(FXMPP);
  FMUC := nil;
  FreeAndNil(FState);
  FreeAndNil(FConfig);
  inherited Destroy;
end;

function TNXBotHost.StartAppServer: Boolean;
begin
  FConfig.ValidateAppServer;
  Result := FAppServer.StartServer(FConfig.CodexExecutable,
    FConfig.RuntimeDirectory, UTF8String(FConfig.CodexModel), FInstructions);
  if not Result then
    FState.AddJournal('App Server start command rejected: command queue full.');
end;

function TNXBotHost.StopAppServer: Boolean;
begin
  Result := FAppServer.StopServer;
  if not Result then
    FState.AddJournal('App Server stop command rejected: command queue full.');
end;

procedure TNXBotHost.RefreshIdentity;
begin
  FState.SetIdentity(UTF8String(FConfig.CodexModel), UTF8String(FConfig.Nick));
  FState.SetRoom(UTF8String(FConfig.RoomJID), 'left');
  Changed;
end;

procedure TNXBotHost.Changed;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TNXBotHost.AddXMPPModule(AModule: TNXXMPPModule);
begin
  FXMPP.AddModule(AModule);
end;

function TNXBotHost.SendRoomMessage(const ARoomJID,
  AText: UTF8String): Boolean;
begin
  Result := FMUC.SendGroupMessage(ARoomJID, AText);
end;

function TNXBotHost.ConnectXMPP: Boolean;
begin
  Result := False;
  try
    FConfig.ValidateXMPP;
    FXMPP.Config.JID := UTF8String(FConfig.XMPPJID);
    FXMPP.Config.Password := FConfig.Password;
    FXMPP.Config.Resource := UTF8String(FConfig.Resource);
    FXMPP.Config.CAFile := FConfig.CAFile;
    FXMPP.Config.EndpointHost := FConfig.EndpointHost;
    FXMPP.Config.EndpointPort := FConfig.EndpointPort;
    FXMPP.Config.DirectTLS := FConfig.DirectTLS;
    FXMPP.Config.AllowPlain := FConfig.AllowPlain;
    FXMPP.Config.CommandCapacity := FConfig.CommandCapacity;
    FXMPP.Connect;
    Result := True;
  except
    on E: Exception do
      FState.AddJournal('XMPP connect failed: ' + UTF8String(E.Message));
  end;
end;

procedure TNXBotHost.DisconnectXMPP;
begin
  FAppServer.CancelPrompts('XMPP disconnected.');
  FXMPP.Disconnect;
end;

function TNXBotHost.JoinRoom(const ARoomJID: UTF8String): Boolean;
begin
  Result := FMUC.Join(ARoomJID, UTF8String(FConfig.Nick), '');
  if not Result then
    FState.AddJournal('Room join command rejected.');
end;

function TNXBotHost.LeaveRoom(const ARoomJID: UTF8String): Boolean;
begin
  FAppServer.CancelRoomPrompts(ARoomJID, 'Bot left the XMPP room.');
  Result := FMUC.Leave(ARoomJID);
  if not Result then
    FState.AddJournal('Room leave command rejected.');
end;

procedure TNXBotHost.ClearView;
begin
  FState.ClearJournal;
end;

procedure TNXBotHost.Shutdown;
var
  lIndex: Integer;
  lSnapshot: TNXBotHostSnapshot;
begin
  FAppServer.CancelPrompts('BotHost is shutting down.');
  if FXMPP.State = xcsOnline then
  begin
    lSnapshot := FState.Snapshot;
    for lIndex := 0 to High(lSnapshot.Rooms) do
      if lSnapshot.Rooms[lIndex].State = 'joined' then
        FMUC.Leave(lSnapshot.Rooms[lIndex].RoomJID);
  end;
  FXMPP.Disconnect;
  FAppServer.Shutdown;
end;

procedure TNXBotHost.AppServerDiagnostic(ASender: TObject;
  const AText: UTF8String);
begin
  FState.AddJournal('App Server: ' + AText);
  Changed;
end;

procedure TNXBotHost.AppServerFinalAnswer(ASender: TObject;
  APrompt: TNXBotPrompt; const AText: UTF8String);
begin
  if FMUC.SendGroupMessage(APrompt.RoomJID, AText) then
    FState.AddJournal('Queued answer for ' + APrompt.SenderJID + '.')
  else
    FState.AddJournal('Answer could not be queued to XMPP.');
  Changed;
end;

procedure TNXBotHost.AppServerPromptFailed(ASender: TObject;
  APrompt: TNXBotPrompt; const AText: UTF8String);
begin
  FState.AddJournal('Prompt ' + UTF8String(IntToStr(APrompt.Sequence)) +
    ' failed: ' + AText);
  Changed;
end;

procedure TNXBotHost.AppServerState(ASender: TObject;
  AState: TNXCodexAppServerState; const ADetail: UTF8String);
var
  lMessage: UTF8String;
begin
  FState.SetAppServer(AState, ADetail);
  lMessage := 'App Server state: ' + NXCodexAppServerStateName(AState);
  if ADetail <> '' then
    lMessage := lMessage + ' (' + ADetail + ')';
  FState.AddJournal(lMessage + '.');
  Changed;
end;

procedure TNXBotHost.XMPPError(ASender: TObject; AStage: TNXXMPPErrorStage;
  const ACondition, AMessage: UTF8String);
begin
  FState.AddJournal('XMPP error: ' + ACondition + ': ' + AMessage);
  Changed;
end;

procedure TNXBotHost.XMPPRoomMessage(ASender: TObject; ARoom: TNXXMPPRoom;
  AMessage: TNXXMPPMessage);
var
  lDecision: TNXBotRouteDecision;
  lNick: UTF8String;
  lOccupant: TNXXMPPOccupant;
  lPrompt: TNXBotPrompt;
  lSeparator: Integer;
  lVerifiedJID: UTF8String;
begin
  if ARoom.State <> xrsJoined then
    Exit;
  if not (FAppServer.State in [cassReady, cassBusy]) then
  begin
    FState.AddJournal('Ignored room message: App Server is not ready.');
    Exit;
  end;
  Inc(FSequence);
  lDecision := TNXBotHostRouter.Admit(FSequence, ARoom.JID, ARoom.Nick,
    AMessage.FromJID, AMessage.ID, AMessage.TypeValue, AMessage.Body,
    AMessage.DisplayBody, AMessage.Reply, AMessage.Context, AMessage.Valid,
    FConfig.PromptMaximumBytes, lPrompt);
  if lDecision = brdAccepted then
  begin
    lSeparator := Pos('/', AMessage.FromJID);
    if lSeparator > 0 then
      lNick := Copy(AMessage.FromJID, lSeparator + 1, MaxInt)
    else
      lNick := '';
    lOccupant := ARoom.Occupant(lNick);
    if Assigned(lOccupant) and lOccupant.Available and
      (lOccupant.RealJID <> '') then
    begin
      lVerifiedJID := lOccupant.RealJID;
      lSeparator := Pos('/', lVerifiedJID);
      if lSeparator > 0 then
        lVerifiedJID := Copy(lVerifiedJID, 1, lSeparator - 1);
      lPrompt.SetVerifiedCaller(lVerifiedJID, True);
    end;
    if Assigned(FOnPrompt) and FOnPrompt(Self, lPrompt) then
    begin
      FState.AddJournal('Accepted control prompt from ' + AMessage.FromJID + '.');
      lPrompt.Free;
    end
    else if FAppServer.SubmitPrompt(lPrompt) then
      FState.AddJournal('Accepted prompt from ' + AMessage.FromJID + '.')
    else
      FState.AddJournal('Prompt rejected: App Server command queue full.');
  end
  else if lDecision <> brdNotAddressed then
    FState.AddJournal('Ignored room message: ' +
      NXBotRouteDecisionName(lDecision) + '.');
  Changed;
end;

procedure TNXBotHost.XMPPRoomState(ASender: TObject; ARoom: TNXXMPPRoom);
begin
  FState.SetRoom(ARoom.JID, NXRoomStateName(ARoom.State));
  FState.AddJournal('Room ' + ARoom.JID + ' state: ' +
    NXRoomStateName(ARoom.State) + '.');
  if ARoom.State in [xrsFailed, xrsLeft] then
    FAppServer.CancelRoomPrompts(ARoom.JID, 'XMPP room is unavailable.');
  Changed;
end;

procedure TNXBotHost.XMPPState(ASender: TObject;
  AState: TNXXMPPConnectionState);
begin
  FState.SetXMPP(UTF8String(NXXMPPConnectionStateName(AState)));
  FState.AddJournal('XMPP state: ' +
    UTF8String(NXXMPPConnectionStateName(AState)) + '.');
  if AState in [xcsDisconnected, xcsFailed] then
    FAppServer.CancelPrompts('XMPP connection is unavailable.');
  Changed;
end;

end.
