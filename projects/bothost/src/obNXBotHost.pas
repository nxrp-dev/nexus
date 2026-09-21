unit obNXBotHost;

{$mode objfpc}{$H+}

interface

uses
  obNXBotConversation,
  obNXBotFileExchange,
  obNXBotHostConfig,
  obNXBotProvider,
  obNXBotHostState,
  obNXXMPPClient,
  obNXXMPPFileSharing,
  obNXXMPPMessage,
  obNXXMPPMessageFeatures,
  obNXXMPPModule,
  obNXXMPPMUC,
  tpNXBotHost,
  tpNXBotFileTypes,
  tpNXXMPPTypes;

type
  TNXBotHostChangedEvent = procedure(ASender: TObject) of object;
  TNXBotHostPromptEvent = function(ASender: TObject;
    APrompt: TNXBotPrompt): Boolean of object;

  TNXBotHost = class
  private
    FConfig: TNXBotHostConfig;
    FConversation: TNXBotConversationTracker;
    FExchange: TNXBotFileExchange;
    FFileSharing: TNXXMPPFileSharingModule;
    FInstructions: UTF8String;
    FMessages: TNXXMPPMessageModule;
    FMUC: TNXXMPPMUCModule;
    FSequence: QWord;
    FState: TNXBotHostState;
    FXMPP: TNXXMPPClient;
    FOnChanged: TNXBotHostChangedEvent;
    FOnBotControl: TNXBotControlEvent;
    FOnPrompt: TNXBotHostPromptEvent;
    FProvider: TNXBotProvider;
    procedure Changed;
    procedure FilePromptReady(ASender: TObject; APrompt: TNXBotPrompt;
      const AError: UTF8String);
    procedure SubmitAcceptedPrompt(APrompt: TNXBotPrompt;
      const AJournalText: UTF8String);
    procedure ProviderDiagnostic(ASender: TObject; const AText: UTF8String);
    procedure ProviderFinalAnswer(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    function ProviderFileSend(ASender: TObject;
      const ARequest: TNXBotFileSendRequest;
      ACompletion: TNXBotFileSendCompletion): Boolean;
    procedure ProviderPromptFailed(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    procedure ProviderState(ASender: TObject;
      AState: TNXBotProviderState; const ADetail: UTF8String);
    procedure SetOnBotControl(AValue: TNXBotControlEvent);
    procedure XMPPError(ASender: TObject; AStage: TNXXMPPErrorStage;
      const ACondition, AMessage: UTF8String);
    procedure XMPPDirectMessage(ASender: TObject; AMessage: TNXXMPPMessage);
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
    function StartProvider: Boolean; virtual;
    function StopProvider: Boolean; virtual;
    procedure RefreshIdentity;
    procedure ClearView;
    procedure Shutdown; virtual;
    procedure AddXMPPModule(AModule: TNXXMPPModule);
    function SendRoomMessage(const ARoomJID,
      AText: UTF8String): Boolean;
    function SendPromptResponse(APrompt: TNXBotPrompt;
      const AText: UTF8String): Boolean;

    property Config: TNXBotHostConfig read FConfig;
    property Conversation: TNXBotConversationTracker read FConversation
      write FConversation;
    property State: TNXBotHostState read FState;
    property MUC: TNXXMPPMUCModule read FMUC;
    property XMPP: TNXXMPPClient read FXMPP;
    property OnChanged: TNXBotHostChangedEvent read FOnChanged write FOnChanged;
    property OnBotControl: TNXBotControlEvent read FOnBotControl
      write SetOnBotControl;
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
  FState.SetIdentity(UTF8String(FConfig.Model), UTF8String(FConfig.Nick));
  FState.SetRoom(UTF8String(FConfig.RoomJID), 'left');

  FProvider := TNXBotProviderRegistry.CreateProvider(UTF8String(FConfig.Provider));
  FProvider.Configure(FConfig, FInstructions);
  FProvider.OnDiagnostic := @ProviderDiagnostic;
  FProvider.OnFinalAnswer := @ProviderFinalAnswer;
  FProvider.OnFileSend := @ProviderFileSend;
  FProvider.OnPromptFailed := @ProviderPromptFailed;
  FProvider.OnState := @ProviderState;

  if FConfig.ExchangeDirectory <> '' then
  begin
    FExchange := TNXBotFileExchange.Create(FConfig);
    FExchange.OnPromptReady := @FilePromptReady;
  end;

  FXMPP := TNXXMPPClient.Create;
  FXMPP.OnError := @XMPPError;
  FXMPP.OnState := @XMPPState;
  FMUC := TNXXMPPMUCModule.Create;
  FMUC.OnRoomMessage := @XMPPRoomMessage;
  FMUC.OnRoomState := @XMPPRoomState;
  FXMPP.AddModule(FMUC);
  FMessages := TNXXMPPMessageModule.Create;
  FMessages.OnMessage := @XMPPDirectMessage;
  FXMPP.AddModule(FMessages);
  FFileSharing := TNXXMPPFileSharingModule.Create;
  FXMPP.AddModule(FFileSharing);
end;

destructor TNXBotHost.Destroy;
begin
  Shutdown;
  Conversation := nil;
  FreeAndNil(FProvider);
  FreeAndNil(FExchange);
  FreeAndNil(FXMPP);
  FMUC := nil;
  FMessages := nil;
  FFileSharing := nil;
  FreeAndNil(FState);
  FreeAndNil(FConfig);
  inherited Destroy;
end;

procedure TNXBotHost.SubmitAcceptedPrompt(APrompt: TNXBotPrompt;
  const AJournalText: UTF8String);
begin
  if not Assigned(APrompt) then
    Exit;
  if Assigned(FOnPrompt) and FOnPrompt(Self, APrompt) then
  begin
    FState.AddJournal(AJournalText);
    APrompt.Free;
  end
  else if FProvider.SubmitPrompt(APrompt) then
    FState.AddJournal(AJournalText)
  else
    FState.AddJournal('Prompt rejected: provider command queue full.');
end;

procedure TNXBotHost.FilePromptReady(ASender: TObject;
  APrompt: TNXBotPrompt; const AError: UTF8String);
begin
  if AError <> '' then
  begin
    FState.AddJournal('File prompt failed: ' + AError);
    APrompt.Free;
  end
  else
    SubmitAcceptedPrompt(APrompt, 'Accepted prompt with verified files.');
  Changed;
end;

function TNXBotHost.StartProvider: Boolean;
begin
  FConfig.ValidateProvider;
  Result := FProvider.Start;
  if not Result then
    FState.AddJournal('Provider start command rejected: command queue full.');
end;

function TNXBotHost.StopProvider: Boolean;
begin
  Result := FProvider.Stop;
  if Result then
  begin
    if Assigned(FExchange) then
      FExchange.SignalProvider('The provider stopped.');
  end
  else
    FState.AddJournal('Provider stop command rejected: command queue full.');
end;

procedure TNXBotHost.RefreshIdentity;
begin
  FState.SetIdentity(UTF8String(FConfig.Model), UTF8String(FConfig.Nick));
  FState.SetRoom(UTF8String(FConfig.RoomJID), 'left');
  Changed;
end;

procedure TNXBotHost.Changed;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TNXBotHost.SetOnBotControl(AValue: TNXBotControlEvent);
begin
  FOnBotControl := AValue;
  FProvider.OnBotControl := AValue;
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

function TNXBotHost.SendPromptResponse(APrompt: TNXBotPrompt;
  const AText: UTF8String): Boolean;
var
  lIdentity: TNXXMPPOutgoingMessageIdentity;
begin
  Result := Assigned(APrompt) and (AText <> '');
  if not Result then
    Exit;
  if APrompt.Delivery = bpdRoom then
  begin
    if Assigned(FConversation) then
      FConversation.BeginAnswer(APrompt.RoomJID, UTF8String(FConfig.Nick),
        APrompt.SenderJID, APrompt.VerifiedCallerBareJID, AText);
    Result := FMUC.SendGroupMessage(APrompt.RoomJID, AText);
    if not Result and Assigned(FConversation) then
      FConversation.CancelAnswer(APrompt.RoomJID,
        UTF8String(FConfig.Nick));
    Exit;
  end;
  if APrompt.ReplyID <> '' then
    Result := FMessages.SendReply(APrompt.SenderJID, AText,
      APrompt.SenderJID, APrompt.ReplyID, False, lIdentity)
  else
    Result := FMessages.SendChatMessage(APrompt.SenderJID, AText, False,
      lIdentity);
end;

function TNXBotHost.ConnectXMPP: Boolean;
begin
  Result := False;
  try
    FConfig.ValidateXMPP;
    FXMPP.Config.JID := UTF8String(FConfig.XMPPJID);
    FXMPP.Config.Password := UTF8String(FConfig.Password);
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
  if Assigned(FExchange) then
    FExchange.SignalXMPP('XMPP disconnected.');
  FProvider.CancelPrompts('XMPP disconnected.');
  FXMPP.Disconnect;
end;

function TNXBotHost.JoinRoom(const ARoomJID: UTF8String): Boolean;
begin
  Result := FMUC.JoinOrCreateInstantRoom(ARoomJID,
    UTF8String(FConfig.Nick));
  if not Result then
    FState.AddJournal('Room join command rejected.');
end;

function TNXBotHost.LeaveRoom(const ARoomJID: UTF8String): Boolean;
begin
  Result := FMUC.Leave(ARoomJID);
  if Result then
  begin
    if Assigned(FExchange) then
      FExchange.SignalRoom(ARoomJID, 'Bot left the XMPP room.');
    FProvider.CancelRoomPrompts(ARoomJID, 'Bot left the XMPP room.');
  end
  else
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
  if Assigned(FExchange) then
  begin
    FExchange.SignalProvider('BotHost is shutting down.');
    FExchange.SignalXMPP('BotHost is shutting down.');
  end;
  if Assigned(FProvider) then
    FProvider.CancelPrompts('BotHost is shutting down.');
  if Assigned(FXMPP) and (FXMPP.State = xcsOnline) then
  begin
    lSnapshot := FState.Snapshot;
    for lIndex := 0 to High(lSnapshot.Rooms) do
      if lSnapshot.Rooms[lIndex].State = 'joined' then
        FMUC.Leave(lSnapshot.Rooms[lIndex].RoomJID);
  end;
  if Assigned(FXMPP) then
    FXMPP.Disconnect;
  if Assigned(FExchange) then
    FExchange.Shutdown;
  if Assigned(FProvider) then
    FProvider.Shutdown;
end;

procedure TNXBotHost.ProviderDiagnostic(ASender: TObject;
  const AText: UTF8String);
begin
  FState.AddJournal('Provider: ' + AText);
  Changed;
end;

procedure TNXBotHost.ProviderFinalAnswer(ASender: TObject;
  APrompt: TNXBotPrompt; const AText: UTF8String);
begin
  if SendPromptResponse(APrompt, AText) then
    FState.AddJournal('Queued answer for ' + APrompt.SenderJID + '.')
  else
    FState.AddJournal('Answer could not be queued to XMPP.');
  Changed;
end;

function TNXBotHost.ProviderFileSend(ASender: TObject;
  const ARequest: TNXBotFileSendRequest;
  ACompletion: TNXBotFileSendCompletion): Boolean;
var
  lAttachment: TNXBotAttachment;
  lMessageType: UTF8String;
  lRoomOwner: UTF8String;
  lTargetJID: UTF8String;
begin
  Result := False;
  if not Assigned(FExchange) or not Assigned(FFileSharing) or
    not Assigned(ACompletion) or
    not (FProvider.State in [bpsReady, bpsWorking]) or
    (FXMPP.State <> xcsOnline) then Exit;
  lAttachment := FExchange.FindAttachment(ARequest.ArtifactID);
  if not Assigned(lAttachment) then Exit;
  if ARequest.RoomDelivery then
  begin
    lTargetJID := ARequest.RoomJID;
    lMessageType := 'groupchat';
    lRoomOwner := ARequest.RoomJID;
  end
  else
  begin
    lTargetJID := ARequest.SenderJID;
    lMessageType := 'chat';
    lRoomOwner := ARequest.RoomJID;
  end;
  if lTargetJID = '' then
  begin
    lAttachment.Free;
    Exit;
  end;
  Result := FExchange.AcceptOutbound(lAttachment, FFileSharing,
    lTargetJID, lMessageType, ARequest.SenderJID, ARequest.ReplyID,
    lRoomOwner, ACompletion);
  if not Result then lAttachment.Free;
end;

procedure TNXBotHost.XMPPDirectMessage(ASender: TObject;
  AMessage: TNXXMPPMessage);
var
  lCallerJID: UTF8String;
  lNick: UTF8String;
  lOccupant: TNXXMPPOccupant;
  lPrompt: TNXBotPrompt;
  lReplyID: UTF8String;
  lRoom: TNXXMPPRoom;
  lRoomJID: UTF8String;
  lSeparator: Integer;
begin
  if not Assigned(AMessage) or not AMessage.Valid or
    (AMessage.Context <> xmdcLive) or AMessage.Delay.Present or
    (AMessage.TypeValue <> 'chat') or
    ((AMessage.Body = '') and (Length(AMessage.Attachments) = 0)) or
    ((AMessage.DisplayBody = '') and (Length(AMessage.Attachments) = 0)) or
    (AMessage.FromJID = '') then
    Exit;
  if AMessage.FromJID = UTF8String(FConfig.XMPPJID + '/' + FConfig.Resource) then
    Exit;
  if not (FProvider.State in [bpsReady, bpsWorking]) then
  begin
    FState.AddJournal('Ignored direct message: provider is not ready.');
    Changed;
    Exit;
  end;
  if (FConfig.PromptMaximumBytes < 1) or
    (Length(AMessage.DisplayBody) > FConfig.PromptMaximumBytes) then
  begin
    FState.AddJournal('Ignored direct message: prompt exceeds configured ' +
      'byte limit.');
    Changed;
    Exit;
  end;

  lSeparator := Pos('/', AMessage.FromJID);
  if lSeparator > 0 then
  begin
    lCallerJID := Copy(AMessage.FromJID, 1, lSeparator - 1);
    lNick := Copy(AMessage.FromJID, lSeparator + 1, MaxInt);
  end
  else
  begin
    lCallerJID := AMessage.FromJID;
    lNick := '';
  end;
  lRoom := FMUC.FindRoom(lCallerJID);
  if Assigned(lRoom) and (lRoom.State = xrsJoined) then
    lRoomJID := lRoom.JID
  else
  begin
    lRoom := nil;
    lRoomJID := '';
  end;

  Inc(FSequence);
  lPrompt := TNXBotPrompt.Create(FSequence, lRoomJID, AMessage.FromJID,
    AMessage.ID, AMessage.DisplayBody);
  if AMessage.OriginID <> '' then
    lReplyID := AMessage.OriginID
  else
    lReplyID := AMessage.ID;
  lPrompt.SetDirectResponse(lReplyID);
  if Assigned(lRoom) then
  begin
    lPrompt.SetVerifiedCaller('', True);
    lOccupant := lRoom.Occupant(lNick);
    if Assigned(lOccupant) and lOccupant.Available and
      (lOccupant.RealJID <> '') then
    begin
      lCallerJID := lOccupant.RealJID;
      lSeparator := Pos('/', lCallerJID);
      if lSeparator > 0 then
        lCallerJID := Copy(lCallerJID, 1, lSeparator - 1);
      lPrompt.SetVerifiedCaller(lCallerJID, True);
    end;
  end
  else
    lPrompt.SetVerifiedCaller(lCallerJID, False);

  if Length(AMessage.Attachments) > 0 then
  begin
    if Assigned(FExchange) and
      FExchange.AcceptInbound(lPrompt, AMessage.Attachments) then
      FState.AddJournal('Accepted direct file transfer from ' +
        AMessage.FromJID + '.')
    else
    begin
      FState.AddJournal('Direct file prompt rejected: transfer capacity full.');
      lPrompt.Free;
    end;
  end
  else
    SubmitAcceptedPrompt(lPrompt, 'Accepted direct prompt from ' +
      AMessage.FromJID + '.');
  Changed;
end;

procedure TNXBotHost.ProviderPromptFailed(ASender: TObject;
  APrompt: TNXBotPrompt; const AText: UTF8String);
begin
  FState.AddJournal('Prompt ' + UTF8String(IntToStr(APrompt.Sequence)) +
    ' failed: ' + AText);
  Changed;
end;

procedure TNXBotHost.ProviderState(ASender: TObject;
  AState: TNXBotProviderState; const ADetail: UTF8String);
var
  lMessage: UTF8String;
begin
  if (AState in [bpsStopped, bpsFailed]) and Assigned(FExchange) then
    FExchange.SignalProvider('The provider is unavailable.');
  FState.SetProvider(AState, ADetail);
  lMessage := 'Provider state: ' + NXBotProviderStateName(AState);
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
  lImplied: Boolean;
  lImpliedBot: UTF8String;
  lImpliedReason: UTF8String;
  lMessageID: UTF8String;
  lNick: UTF8String;
  lOccupant: TNXXMPPOccupant;
  lPrompt: TNXBotPrompt;
  lSeparator: Integer;
  lVerifiedJID: UTF8String;
begin
  if ARoom.State <> xrsJoined then
    Exit;
  lSeparator := Pos('/', AMessage.FromJID);
  if lSeparator > 0 then
    lNick := Copy(AMessage.FromJID, lSeparator + 1, MaxInt)
  else
    lNick := '';
  lVerifiedJID := '';
  if lNick <> '' then
  begin
    lOccupant := ARoom.Occupant(lNick);
    if Assigned(lOccupant) and lOccupant.Available and
      (lOccupant.RealJID <> '') then
    begin
      lVerifiedJID := lOccupant.RealJID;
      lSeparator := Pos('/', lVerifiedJID);
      if lSeparator > 0 then
        lVerifiedJID := Copy(lVerifiedJID, 1, lSeparator - 1);
    end;
  end;
  if Assigned(FConversation) then
  begin
    if not AMessage.StanzaIDFor(ARoom.JID, lMessageID) then
      if AMessage.OriginID <> '' then
        lMessageID := AMessage.OriginID
      else
        lMessageID := AMessage.ID;
    lImpliedBot := FConversation.Observe(ARoom.JID, AMessage.FromJID,
      lVerifiedJID, lMessageID, AMessage.TypeValue, AMessage.Body,
      AMessage.DisplayBody, AMessage.Reply, AMessage.Context,
      AMessage.Valid, lImpliedReason);
  end
  else
  begin
    lImpliedBot := '';
    lImpliedReason := '';
  end;
  lImplied := SameText(string(lImpliedBot), FConfig.Nick);
  if not (FProvider.State in [bpsReady, bpsWorking]) then
  begin
    FState.AddJournal('Ignored room message: provider is not ready.');
    Exit;
  end;
  Inc(FSequence);
  lDecision := TNXBotHostRouter.Admit(FSequence, ARoom.JID, ARoom.Nick,
    AMessage.FromJID, AMessage.ID, AMessage.TypeValue, AMessage.Body,
    AMessage.DisplayBody, AMessage.Reply, AMessage.Context, AMessage.Valid,
    FConfig.PromptMaximumBytes, lImplied,
    Length(AMessage.Attachments) > 0, lPrompt);
  if lDecision = brdAccepted then
  begin
    if lNick <> '' then
    begin
      lPrompt.SetVerifiedCaller('', True);
      if lVerifiedJID <> '' then
        lPrompt.SetVerifiedCaller(lVerifiedJID, True);
    end;
    if Length(AMessage.Attachments) > 0 then
    begin
      if Assigned(FExchange) and
        FExchange.AcceptInbound(lPrompt, AMessage.Attachments) then
        FState.AddJournal('Accepted addressed room file transfer from ' +
          AMessage.FromJID + '.')
      else
      begin
        FState.AddJournal('Room file prompt rejected: transfer capacity full.');
        lPrompt.Free;
      end;
    end
    else
    begin
      if lImplied then
        SubmitAcceptedPrompt(lPrompt, 'Accepted implied reply from ' +
          AMessage.FromJID + ': ' + lImpliedReason + '.')
      else
        SubmitAcceptedPrompt(lPrompt, 'Accepted prompt from ' +
          AMessage.FromJID + '.');
    end;
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
  begin
    if Assigned(FExchange) then
      FExchange.SignalRoom(ARoom.JID, 'XMPP room is unavailable.');
    if Assigned(FConversation) then
      FConversation.ClearBotRoom(ARoom.JID, UTF8String(FConfig.Nick));
    FProvider.CancelRoomPrompts(ARoom.JID, 'XMPP room is unavailable.');
  end;
  Changed;
end;

procedure TNXBotHost.XMPPState(ASender: TObject;
  AState: TNXXMPPConnectionState);
begin
  FState.SetXMPP(UTF8String(NXXMPPConnectionStateName(AState)));
  FState.AddJournal('XMPP state: ' +
    UTF8String(NXXMPPConnectionStateName(AState)) + '.');
  if AState in [xcsDisconnected, xcsFailed] then
  begin
    if Assigned(FExchange) then
      FExchange.SignalXMPP('XMPP connection is unavailable.');
    FProvider.CancelPrompts('XMPP connection is unavailable.');
  end;
  Changed;
end;

end.
