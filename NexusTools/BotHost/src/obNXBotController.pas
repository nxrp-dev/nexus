unit obNXBotController;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, obNXBotCatalog, obNXBotHost, obNXBotHostConfig,
  tpNXBotControl, tpNXBotHost;

type
  TNXBotController = class;

  TNXPendingBotPhase = (pbpReady, pbpWaitingAppServer, pbpWaitingXMPP,
    pbpWaitingRoom);

  TNXActiveBot = class
  public
    Detached: Boolean;
    Entry: TNXBotCatalogEntry;
    Host: TNXBotHost;
    ReferenceCount: Integer;
    destructor Destroy; override;
  end;

  TNXPendingBotOperation = class
  public
    Active: TNXActiveBot;
    Authorization: TNXBotAuthorization;
    Busy: Boolean;
    Completion: TNXBotControlCompletion;
    CompletionRequested: Boolean;
    CreatedHost: Boolean;
    Operation: TNXBotControlOperation;
    Phase: TNXPendingBotPhase;
    RequestedResult: TNXBotControlResult;
    Token: QWord;
  end;

  TNXPendingBotClaim = record
    Active: TNXActiveBot;
    Operation: TNXBotControlOperation;
    Phase: TNXPendingBotPhase;
    Token: QWord;
  end;

  TNXBotController = class
  private
    FActive: TObjectList;
    FCatalog: TNXBotCatalog;
    FConfig: TNXBotControllerConfig;
    FCriticalSection: TRTLCriticalSection;
    FNextToken: QWord;
    FPending: TObjectList;
    FShuttingDown: Boolean;
    function AcquireActive(const AName: UTF8String): TNXActiveBot;
    procedure AdvancePending;
    function Authorized(const AOperation: TNXBotControlOperation;
      const AAuthorization: TNXBotAuthorization): Boolean;
    function ClaimNextPending(AAfterToken: QWord;
      out AClaim: TNXPendingBotClaim): Boolean;
    function CreateConfiguredHost(AEntry: TNXBotCatalogEntry): TNXBotHost;
    function DetachActiveUnsafe(AActive: TNXActiveBot): Boolean;
    function ExtractPendingUnsafe(AIndex: Integer;
      const AResult: TNXBotControlResult;
      out APending: TNXPendingBotOperation;
      out ACleanup: TNXActiveBot): Boolean;
    function FindActiveUnsafe(const AName: UTF8String): TNXActiveBot;
    function FindPendingUnsafe(AToken: QWord): Integer;
    function FindRoom(const ARoomJID: UTF8String;
      const ARooms: TNXBotRoomStatusArray; out AState: UTF8String): Boolean;
    procedure FinishPending(APending: TNXPendingBotOperation;
      ACleanup: TNXActiveBot; const AResult: TNXBotControlResult);
    procedure HostChanged(ASender: TObject);
    function HostHasPendingUnsafe(AActive: TNXActiveBot): Boolean;
    function MakeStatus(AEntry: TNXBotCatalogEntry): TNXBotStatus;
    function NextToken(out AToken: QWord): Boolean;
    function ProcessClaim(const AClaim: TNXPendingBotClaim): Boolean;
    procedure ReleaseActive(AActive: TNXActiveBot);
    procedure ReleaseClaim(const AClaim: TNXPendingBotClaim;
      APhase: TNXPendingBotPhase; AComplete: Boolean;
      const AResult: TNXBotControlResult);
    function ResolveEntry(const AName: UTF8String;
      AOrigin: TNXBotControlOrigin): TNXBotCatalogEntry;
    function RequestCompletion(AToken: QWord;
      const AResult: TNXBotControlResult): Boolean;
  protected
    function CreateHost(AConfig: TNXBotHostConfig;
      const AInstructions: UTF8String): TNXBotHost; virtual;
  public
    constructor Create(ACatalog: TNXBotCatalog;
      AConfig: TNXBotControllerConfig);
    destructor Destroy; override;
    function AdoptHost(const ABotName: UTF8String;
      AHost: TNXBotHost): Boolean;
    function Cancel(AToken: QWord; const AReason: UTF8String): Boolean;
    function Execute(const AOperation: TNXBotControlOperation;
      const AAuthorization: TNXBotAuthorization;
      ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
    function HandleModelControl(ASender: TObject;
      const AOperation: TNXBotControlOperation;
      const AAuthorization: TNXBotAuthorization;
      ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
    procedure SetOperationCapacity(AValue: Integer);
    procedure Shutdown;
    function UpdateDeployment(ABinding: TNXBotDeploymentBinding): Boolean;
    property Catalog: TNXBotCatalog read FCatalog;
  end;

implementation

uses
  SysUtils, obNXBotHostState, obNXXMPPJID;

type
  TNXBotHostAction = (bhaNone, bhaStartAppServer, bhaConnectXMPP,
    bhaJoinRoom, bhaLeaveRoom);

destructor TNXActiveBot.Destroy;
begin
  Host.Free;
  inherited Destroy;
end;

constructor TNXBotController.Create(ACatalog: TNXBotCatalog;
  AConfig: TNXBotControllerConfig);
begin
  inherited Create;
  if not Assigned(ACatalog) or not Assigned(AConfig) then
    raise Exception.Create('Bot controller requires catalog and configuration.');
  if AConfig.OperationCapacity < 1 then
    raise Exception.Create('Bot controller capacity must be positive.');
  FCatalog := ACatalog;
  FConfig := TNXBotControllerConfig.Create;
  FConfig.JSON := AConfig.JSON;
  FActive := TObjectList.Create(True);
  FActive.Capacity := FCatalog.Entries.Count;
  FPending := TObjectList.Create(True);
  FPending.Capacity := FConfig.OperationCapacity;
  InitCriticalSection(FCriticalSection);
end;

destructor TNXBotController.Destroy;
begin
  Shutdown;
  FPending.Free;
  FActive.Free;
  DoneCriticalSection(FCriticalSection);
  FConfig.Free;
  FCatalog.Free;
  inherited Destroy;
end;

function NormalizedBareJID(const AValue: UTF8String): UTF8String;
var
  lJID: TNXXMPPJID;
begin
  Result := '';
  try
    lJID := TNXXMPPJID.Create(AValue);
    try
      Result := lJID.Bare;
    finally
      lJID.Free;
    end;
  except
    Result := '';
  end;
end;

function ListContainsJID(AList: TStrings; const AJID: UTF8String): Boolean;
var
  lIndex: Integer;
  lNormalized: UTF8String;
begin
  Result := False;
  for lIndex := 0 to AList.Count - 1 do
  begin
    lNormalized := NormalizedBareJID(UTF8String(AList[lIndex]));
    if (lNormalized <> '') and (lNormalized = AJID) then
      Exit(True);
  end;
end;

function TNXBotController.Authorized(const AOperation: TNXBotControlOperation;
  const AAuthorization: TNXBotAuthorization): Boolean;
var
  lCaller: UTF8String;
begin
  if (AAuthorization.Origin in [bcoHumanMUC, bcoModelTool]) and
    not AAuthorization.VerifiedMUCIdentity then
    Exit(False);
  lCaller := NormalizedBareJID(AAuthorization.CallerBareJID);
  if lCaller = '' then
    Exit(False);
  if ListContainsJID(FConfig.Operators, lCaller) then
    Exit(True);
  Result := (AOperation.Kind in [bcokList, bcokStatus]) and
    ListContainsJID(FConfig.Readers, lCaller);
end;

function TNXBotController.FindActiveUnsafe(
  const AName: UTF8String): TNXActiveBot;
var
  lActive: TNXActiveBot;
  lIndex: Integer;
begin
  Result := nil;
  for lIndex := 0 to FActive.Count - 1 do
  begin
    lActive := TNXActiveBot(FActive[lIndex]);
    if lActive.Entry.Name = AName then
      Exit(lActive);
  end;
end;

function TNXBotController.AcquireActive(
  const AName: UTF8String): TNXActiveBot;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := FindActiveUnsafe(AName);
    if Assigned(Result) then
      Inc(Result.ReferenceCount);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotController.ReleaseActive(AActive: TNXActiveBot);
var
  lFree: Boolean;
begin
  if not Assigned(AActive) then
    Exit;
  EnterCriticalSection(FCriticalSection);
  try
    Dec(AActive.ReferenceCount);
    lFree := AActive.Detached and (AActive.ReferenceCount = 0);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  if lFree then
    AActive.Free;
end;

function TNXBotController.DetachActiveUnsafe(
  AActive: TNXActiveBot): Boolean;
begin
  Result := Assigned(AActive) and not AActive.Detached and
    (FActive.IndexOf(AActive) >= 0);
  if Result then
  begin
    FActive.Extract(AActive);
    AActive.Detached := True;
  end;
end;

function TNXBotController.ResolveEntry(const AName: UTF8String;
  AOrigin: TNXBotControlOrigin): TNXBotCatalogEntry;
var
  lEntry: TNXBotCatalogEntry;
  lMatch: TNXBotCatalogEntry;
begin
  Result := FCatalog.Find(AName);
  if Assigned(Result) or (AOrigin = bcoRemoteIQ) then
    Exit;
  lMatch := nil;
  for lEntry in FCatalog.Entries do
    if SameText(string(lEntry.Name), string(AName)) then
    begin
      if Assigned(lMatch) then
        Exit(nil);
      lMatch := lEntry;
    end;
  Result := lMatch;
end;

function TNXBotController.HostHasPendingUnsafe(
  AActive: TNXActiveBot): Boolean;
var
  lIndex: Integer;
begin
  Result := False;
  for lIndex := 0 to FPending.Count - 1 do
    if TNXPendingBotOperation(FPending[lIndex]).Active = AActive then
      Exit(True);
end;

function TNXBotController.CreateHost(AConfig: TNXBotHostConfig;
  const AInstructions: UTF8String): TNXBotHost;
begin
  Result := TNXBotHost.Create(AConfig, AInstructions);
end;

function TNXBotController.CreateConfiguredHost(
  AEntry: TNXBotCatalogEntry): TNXBotHost;
var
  lBinding: TNXBotDeploymentBinding;
  lConfig: TNXBotHostConfig;
  lFound: Boolean;
begin
  lConfig := TNXBotHostConfig.Create;
  try
    EnterCriticalSection(FCriticalSection);
    try
      lBinding := FConfig.Bindings.Find(string(AEntry.Name));
      lFound := Assigned(lBinding);
      if lFound then
      begin
        lConfig.CodexExecutable := lBinding.CodexExecutable;
        lConfig.CodexModel := string(AEntry.Model);
        lConfig.AllowPlain := lBinding.AllowPlain;
        lConfig.CAFile := lBinding.CAFile;
        lConfig.DirectTLS := lBinding.DirectTLS;
        lConfig.EndpointHost := lBinding.EndpointHost;
        lConfig.EndpointPort := lBinding.EndpointPort;
        lConfig.Nick := lBinding.Nick;
        lConfig.PasswordEnvironmentVariable :=
          lBinding.PasswordEnvironmentVariable;
        lConfig.Resource := lBinding.Resource;
        lConfig.RuntimeDirectory := lBinding.RuntimeDirectory;
        lConfig.XMPPJID := lBinding.XMPPJID;
      end;
    finally
      LeaveCriticalSection(FCriticalSection);
    end;
    if not lFound then
      raise Exception.Create('Deployment binding is unavailable.');
    Result := CreateHost(lConfig, AEntry.Instructions);
    lConfig := nil;
  finally
    lConfig.Free;
  end;
end;

function TNXBotController.FindRoom(const ARoomJID: UTF8String;
  const ARooms: TNXBotRoomStatusArray; out AState: UTF8String): Boolean;
var
  lIndex: Integer;
begin
  AState := 'left';
  for lIndex := 0 to High(ARooms) do
    if ARooms[lIndex].RoomJID = ARoomJID then
    begin
      AState := ARooms[lIndex].State;
      Exit(True);
    end;
  Result := False;
end;

function TNXBotController.MakeStatus(AEntry: TNXBotCatalogEntry): TNXBotStatus;
var
  lActive: TNXActiveBot;
  lSnapshot: TNXBotHostSnapshot;
begin
  Result.Name := AEntry.Name;
  Result.Known := True;
  Result.Available := AEntry.Available;
  Result.Provider := AEntry.Provider;
  Result.Model := AEntry.Model;
  Result.Diagnostic := AEntry.Diagnostic;
  lActive := AcquireActive(AEntry.Name);
  Result.Active := Assigned(lActive);
  if not Assigned(lActive) then
  begin
    Result.AppServerState := 'stopped';
    Result.XMPPState := 'disconnected';
    SetLength(Result.Rooms, 0);
    Exit;
  end;
  try
    lSnapshot := lActive.Host.State.Snapshot;
    Result.AppServerState := NXCodexAppServerStateName(
      lSnapshot.AppServerState);
    Result.XMPPState := lSnapshot.XMPPState;
    Result.Rooms := Copy(lSnapshot.Rooms);
    if lSnapshot.AppServerDetail <> '' then
      Result.Diagnostic := lSnapshot.AppServerDetail;
  finally
    ReleaseActive(lActive);
  end;
end;

function TNXBotController.FindPendingUnsafe(AToken: QWord): Integer;
begin
  for Result := 0 to FPending.Count - 1 do
    if TNXPendingBotOperation(FPending[Result]).Token = AToken then
      Exit;
  Result := -1;
end;

function TNXBotController.ExtractPendingUnsafe(AIndex: Integer;
  const AResult: TNXBotControlResult;
  out APending: TNXPendingBotOperation;
  out ACleanup: TNXActiveBot): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < FPending.Count);
  APending := nil;
  ACleanup := nil;
  if not Result then
    Exit;
  APending := TNXPendingBotOperation(FPending.Extract(FPending[AIndex]));
  if (AResult.Error <> bceNone) and APending.CreatedHost and
    DetachActiveUnsafe(APending.Active) then
    ACleanup := APending.Active;
end;

procedure TNXBotController.FinishPending(APending: TNXPendingBotOperation;
  ACleanup: TNXActiveBot; const AResult: TNXBotControlResult);
var
  lCompletion: TNXBotControlCompletion;
  lToken: QWord;
begin
  if not Assigned(APending) then
    Exit;
  try
    if Assigned(ACleanup) then
    begin
      ACleanup.Host.OnChanged := nil;
      ACleanup.Host.Shutdown;
    end;
    lCompletion := APending.Completion;
    lToken := APending.Token;
    if Assigned(lCompletion) then
      lCompletion(lToken, AResult);
  finally
    ReleaseActive(APending.Active);
    APending.Free;
  end;
end;

function TNXBotController.RequestCompletion(AToken: QWord;
  const AResult: TNXBotControlResult): Boolean;
var
  lCleanup: TNXActiveBot;
  lIndex: Integer;
  lPending: TNXPendingBotOperation;
begin
  lCleanup := nil;
  lPending := nil;
  EnterCriticalSection(FCriticalSection);
  try
    lIndex := FindPendingUnsafe(AToken);
    Result := lIndex >= 0;
    if not Result then
      Exit;
    if TNXPendingBotOperation(FPending[lIndex]).Busy then
    begin
      if not TNXPendingBotOperation(FPending[lIndex]).CompletionRequested then
      begin
        TNXPendingBotOperation(FPending[lIndex]).CompletionRequested := True;
        TNXPendingBotOperation(FPending[lIndex]).RequestedResult := AResult;
      end;
    end
    else
      ExtractPendingUnsafe(lIndex, AResult, lPending, lCleanup);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  FinishPending(lPending, lCleanup, AResult);
end;

function TNXBotController.ClaimNextPending(AAfterToken: QWord;
  out AClaim: TNXPendingBotClaim): Boolean;
var
  lCandidate: TNXPendingBotOperation;
  lIndex: Integer;
  lPending: TNXPendingBotOperation;
begin
  lCandidate := nil;
  EnterCriticalSection(FCriticalSection);
  try
    for lIndex := 0 to FPending.Count - 1 do
    begin
      lPending := TNXPendingBotOperation(FPending[lIndex]);
      if not lPending.Busy and (lPending.Token > AAfterToken) and
        (not Assigned(lCandidate) or (lPending.Token < lCandidate.Token)) then
        lCandidate := lPending;
    end;
    Result := Assigned(lCandidate);
    if Result then
    begin
      lCandidate.Busy := True;
      AClaim.Active := lCandidate.Active;
      AClaim.Operation := lCandidate.Operation;
      AClaim.Phase := lCandidate.Phase;
      AClaim.Token := lCandidate.Token;
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotController.ReleaseClaim(const AClaim: TNXPendingBotClaim;
  APhase: TNXPendingBotPhase; AComplete: Boolean;
  const AResult: TNXBotControlResult);
var
  lCleanup: TNXActiveBot;
  lFinalResult: TNXBotControlResult;
  lIndex: Integer;
  lPending: TNXPendingBotOperation;
begin
  lCleanup := nil;
  lPending := nil;
  lFinalResult := AResult;
  EnterCriticalSection(FCriticalSection);
  try
    lIndex := FindPendingUnsafe(AClaim.Token);
    if lIndex < 0 then
      Exit;
    if TNXPendingBotOperation(FPending[lIndex]).CompletionRequested then
    begin
      AComplete := True;
      lFinalResult := TNXPendingBotOperation(FPending[lIndex]).RequestedResult;
    end;
    if AComplete then
      ExtractPendingUnsafe(lIndex, lFinalResult, lPending, lCleanup)
    else
    begin
      TNXPendingBotOperation(FPending[lIndex]).Phase := APhase;
      TNXPendingBotOperation(FPending[lIndex]).Busy := False;
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  FinishPending(lPending, lCleanup, lFinalResult);
end;

function TNXBotController.ProcessClaim(
  const AClaim: TNXPendingBotClaim): Boolean;
var
  lAccepted: Boolean;
  lAction: TNXBotHostAction;
  lComplete: Boolean;
  lEntry: TNXBotCatalogEntry;
  lPhase: TNXPendingBotPhase;
  lResult: TNXBotControlResult;
  lRoomState: UTF8String;
  lSnapshot: TNXBotHostSnapshot;
begin
  Result := False;
  lAction := bhaNone;
  lComplete := False;
  lPhase := AClaim.Phase;
  lResult := NXBotControlFailure(bceNone, '');
  lSnapshot := AClaim.Active.Host.State.Snapshot;
  FindRoom(AClaim.Operation.RoomJID, lSnapshot.Rooms, lRoomState);
  if AClaim.Operation.Kind = bcokInvite then
  begin
    if lRoomState = 'joined' then
    begin
      lResult.Error := bceNone;
      lResult.Detail := 'Bot joined the room.';
      lResult.NoOp := False;
      SetLength(lResult.Bots, 1);
      lEntry := FCatalog.Find(AClaim.Operation.BotName);
      lResult.Bots[0] := MakeStatus(lEntry);
      lComplete := True;
    end
    else if (lSnapshot.AppServerState = cassFailed) or
      (lSnapshot.XMPPState = 'failed') or (lRoomState = 'failed') then
    begin
      lResult := NXBotControlFailure(bceUnavailable,
        'Bot activation or room join failed.');
      lComplete := True;
    end
    else if (lSnapshot.AppServerState = cassStopped) and
      (AClaim.Phase <> pbpWaitingAppServer) then
    begin
      lAction := bhaStartAppServer;
      lPhase := pbpWaitingAppServer;
    end
    else if (lSnapshot.AppServerState = cassReady) and
      (lSnapshot.XMPPState = 'disconnected') and
      (AClaim.Phase <> pbpWaitingXMPP) then
    begin
      lAction := bhaConnectXMPP;
      lPhase := pbpWaitingXMPP;
    end
    else if (lSnapshot.AppServerState = cassReady) and
      (lSnapshot.XMPPState = 'online') and (lRoomState = 'left') and
      (AClaim.Phase <> pbpWaitingRoom) then
    begin
      lAction := bhaJoinRoom;
      lPhase := pbpWaitingRoom;
    end;
  end
  else if lRoomState = 'left' then
  begin
    lResult.Error := bceNone;
    lResult.Detail := 'Bot left the room.';
    lResult.NoOp := False;
    SetLength(lResult.Bots, 1);
    lEntry := FCatalog.Find(AClaim.Operation.BotName);
    lResult.Bots[0] := MakeStatus(lEntry);
    lComplete := True;
  end
  else if lRoomState = 'failed' then
  begin
    lResult := NXBotControlFailure(bceUnavailable,
      'Bot could not leave the room.');
    lComplete := True;
  end
  else if AClaim.Phase <> pbpWaitingRoom then
  begin
    lAction := bhaLeaveRoom;
    lPhase := pbpWaitingRoom;
  end;

  if lAction <> bhaNone then
  begin
    case lAction of
      bhaStartAppServer:
        lAccepted := AClaim.Active.Host.StartAppServer;
      bhaConnectXMPP:
        lAccepted := AClaim.Active.Host.ConnectXMPP;
      bhaJoinRoom:
        lAccepted := AClaim.Active.Host.JoinRoom(AClaim.Operation.RoomJID);
      bhaLeaveRoom:
        lAccepted := AClaim.Active.Host.LeaveRoom(AClaim.Operation.RoomJID);
      else
        lAccepted := False;
    end;
    if not lAccepted then
    begin
      lResult := NXBotControlFailure(bceUnavailable,
        'The bot lifecycle command was rejected.');
      lComplete := True;
    end;
    Result := lAccepted;
  end;
  ReleaseClaim(AClaim, lPhase, lComplete, lResult);
end;

procedure TNXBotController.AdvancePending;
var
  lAfterToken: QWord;
  lClaim: TNXPendingBotClaim;
  lProgress: Boolean;
begin
  repeat
    lAfterToken := 0;
    lProgress := False;
    while ClaimNextPending(lAfterToken, lClaim) do
    begin
      lAfterToken := lClaim.Token;
      if ProcessClaim(lClaim) then
        lProgress := True;
    end;
  until not lProgress;
end;

procedure TNXBotController.HostChanged(ASender: TObject);
begin
  if not FShuttingDown then
    AdvancePending;
end;

function TNXBotController.NextToken(out AToken: QWord): Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := not FShuttingDown;
    if not Result then
    begin
      AToken := 0;
      Exit;
    end;
    Inc(FNextToken);
    if FNextToken = 0 then
      Inc(FNextToken);
    AToken := FNextToken;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TNXBotController.Execute(const AOperation: TNXBotControlOperation;
  const AAuthorization: TNXBotAuthorization;
  ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
var
  lActive: TNXActiveBot;
  lCandidate: TNXActiveBot;
  lCleanup: TNXActiveBot;
  lEntry: TNXBotCatalogEntry;
  lIndex: Integer;
  lNewInstance: Boolean;
  lPending: TNXPendingBotOperation;
  lPendingAdded: Boolean;
  lResolvedOperation: TNXBotControlOperation;
  lResult: TNXBotControlResult;
  lRoomState: UTF8String;
  lSnapshot: TNXBotHostSnapshot;
begin
  Result := False;
  AToken := 0;
  if not Assigned(ACompletion) or not NextToken(AToken) then
    Exit;
  Result := True;
  if not Authorized(AOperation, AAuthorization) then
  begin
    ACompletion(AToken, NXBotControlFailure(bceForbidden,
      'The caller is not authorized for this operation.'));
    Exit;
  end;
  if AOperation.Kind = bcokList then
  begin
    lResult.Error := bceNone;
    lResult.Detail := '';
    lResult.NoOp := False;
    SetLength(lResult.Bots, FCatalog.Entries.Count);
    for lIndex := 0 to FCatalog.Entries.Count - 1 do
      lResult.Bots[lIndex] := MakeStatus(FCatalog.Entries[lIndex]);
    ACompletion(AToken, lResult);
    Exit;
  end;
  if AOperation.BotName = '' then
  begin
    ACompletion(AToken, NXBotControlFailure(bceBadRequest,
      'A bot name is required.'));
    Exit;
  end;
  lEntry := ResolveEntry(AOperation.BotName, AAuthorization.Origin);
  if not Assigned(lEntry) then
  begin
    ACompletion(AToken, NXBotControlFailure(bceNotFound,
      'The bot is not present in the catalog.'));
    Exit;
  end;
  lResolvedOperation := AOperation;
  lResolvedOperation.BotName := lEntry.Name;
  if AOperation.Kind = bcokStatus then
  begin
    lResult.Error := bceNone;
    lResult.Detail := '';
    lResult.NoOp := False;
    SetLength(lResult.Bots, 1);
    lResult.Bots[0] := MakeStatus(lEntry);
    ACompletion(AToken, lResult);
    Exit;
  end;
  if NormalizedBareJID(lResolvedOperation.RoomJID) <>
    lResolvedOperation.RoomJID then
  begin
    ACompletion(AToken, NXBotControlFailure(bceBadRequest,
      'A canonical bare room JID is required.'));
    Exit;
  end;

  lActive := AcquireActive(lResolvedOperation.BotName);
  lNewInstance := False;
  if lResolvedOperation.Kind = bcokDismiss then
  begin
    if not Assigned(lActive) then
    begin
      lResult.Error := bceNone;
      lResult.Detail := 'Bot is already absent from the room.';
      lResult.NoOp := True;
      SetLength(lResult.Bots, 1);
      lResult.Bots[0] := MakeStatus(lEntry);
      ACompletion(AToken, lResult);
      Exit;
    end;
  end
  else
  begin
    if not lEntry.Available then
    begin
      ReleaseActive(lActive);
      ACompletion(AToken, NXBotControlFailure(bceUnavailable,
        lEntry.Diagnostic));
      Exit;
    end;
    if not Assigned(lActive) then
    begin
      lCandidate := TNXActiveBot.Create;
      try
        lCandidate.Entry := lEntry;
        lCandidate.Host := CreateConfiguredHost(lEntry);
        lCandidate.Host.OnChanged := @HostChanged;
        lCandidate.ReferenceCount := 1;
      except
        on E: Exception do
        begin
          lCandidate.Free;
          ACompletion(AToken, NXBotControlFailure(bceUnavailable,
            UTF8String(E.Message)));
          Exit;
        end;
      end;
      EnterCriticalSection(FCriticalSection);
      try
        if not FShuttingDown then
        begin
          lActive := FindActiveUnsafe(lResolvedOperation.BotName);
          if Assigned(lActive) then
            Inc(lActive.ReferenceCount)
          else
          begin
            FActive.Add(lCandidate);
            lActive := lCandidate;
            lCandidate := nil;
            lNewInstance := True;
          end;
        end;
      finally
        LeaveCriticalSection(FCriticalSection);
      end;
      if Assigned(lCandidate) then
      begin
        lCandidate.Host.OnChanged := nil;
        lCandidate.Free;
      end;
      if not Assigned(lActive) then
      begin
        ACompletion(AToken, NXBotControlFailure(bceCancelled,
          'The bot controller is shutting down.'));
        Exit;
      end;
    end;
  end;

  lSnapshot := lActive.Host.State.Snapshot;
  if (lResolvedOperation.Kind = bcokDismiss) and
    (not FindRoom(lResolvedOperation.RoomJID, lSnapshot.Rooms,
    lRoomState) or (lRoomState = 'left')) then
  begin
    ReleaseActive(lActive);
    lResult.Error := bceNone;
    lResult.Detail := 'Bot is already absent from the room.';
    lResult.NoOp := True;
    SetLength(lResult.Bots, 1);
    lResult.Bots[0] := MakeStatus(lEntry);
    ACompletion(AToken, lResult);
    Exit;
  end;
  if (lResolvedOperation.Kind = bcokInvite) and
    FindRoom(lResolvedOperation.RoomJID, lSnapshot.Rooms, lRoomState) and
    (lRoomState = 'joined') then
  begin
    ReleaseActive(lActive);
    lResult.Error := bceNone;
    lResult.Detail := 'Bot is already joined.';
    lResult.NoOp := True;
    SetLength(lResult.Bots, 1);
    lResult.Bots[0] := MakeStatus(lEntry);
    ACompletion(AToken, lResult);
    Exit;
  end;

  lPending := TNXPendingBotOperation.Create;
  lPending.Active := lActive;
  lPending.Authorization := AAuthorization;
  lPending.Completion := ACompletion;
  lPending.Operation := lResolvedOperation;
  lPending.Phase := pbpReady;
  lPending.Token := AToken;
  lPending.CreatedHost := lNewInstance;
  lPendingAdded := False;
  lCleanup := nil;
  EnterCriticalSection(FCriticalSection);
  try
    if FShuttingDown then
      lResult := NXBotControlFailure(bceCancelled,
        'The bot controller is shutting down.')
    else if HostHasPendingUnsafe(lActive) then
      lResult := NXBotControlFailure(bceCapacity,
        'The bot already has a pending lifecycle operation.')
    else if FPending.Count >= FConfig.OperationCapacity then
      lResult := NXBotControlFailure(bceCapacity,
        'The pending control-operation limit has been reached.')
    else
    begin
      FPending.Add(lPending);
      lPendingAdded := True;
    end;
    if not lPendingAdded and lNewInstance and
      not HostHasPendingUnsafe(lActive) and DetachActiveUnsafe(lActive) then
      lCleanup := lActive;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  if not lPendingAdded then
  begin
    if Assigned(lCleanup) then
    begin
      lCleanup.Host.OnChanged := nil;
      lCleanup.Host.Shutdown;
    end;
    ReleaseActive(lActive);
    lPending.Free;
    ACompletion(AToken, lResult);
    Exit;
  end;
  AdvancePending;
end;

function TNXBotController.AdoptHost(const ABotName: UTF8String;
  AHost: TNXBotHost): Boolean;
var
  lActive: TNXActiveBot;
  lEntry: TNXBotCatalogEntry;
begin
  Result := False;
  if not Assigned(AHost) then
    Exit;
  lEntry := FCatalog.Find(ABotName);
  if not Assigned(lEntry) then
    Exit;
  lActive := TNXActiveBot.Create;
  lActive.Entry := lEntry;
  lActive.Host := AHost;
  lActive.Host.OnChanged := @HostChanged;
  EnterCriticalSection(FCriticalSection);
  try
    if not FShuttingDown and not Assigned(FindActiveUnsafe(ABotName)) then
    begin
      FActive.Add(lActive);
      lActive := nil;
      Result := True;
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  if Assigned(lActive) then
  begin
    lActive.Host.OnChanged := nil;
    lActive.Host := nil;
    lActive.Free;
  end;
end;

function TNXBotController.HandleModelControl(ASender: TObject;
  const AOperation: TNXBotControlOperation;
  const AAuthorization: TNXBotAuthorization;
  ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean;
begin
  Result := Execute(AOperation, AAuthorization, ACompletion, AToken);
end;

function TNXBotController.Cancel(AToken: QWord;
  const AReason: UTF8String): Boolean;
begin
  Result := RequestCompletion(AToken,
    NXBotControlFailure(bceCancelled, AReason));
end;

procedure TNXBotController.SetOperationCapacity(AValue: Integer);
begin
  if AValue < 1 then
    raise Exception.Create('Bot controller capacity must be positive.');
  if AValue > FPending.Capacity then
    raise Exception.Create(
      'Bot controller capacity cannot exceed its constructed capacity.');
  EnterCriticalSection(FCriticalSection);
  try
    FConfig.OperationCapacity := AValue;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TNXBotController.UpdateDeployment(
  ABinding: TNXBotDeploymentBinding): Boolean;
var
  lBinding: TNXBotDeploymentBinding;
begin
  Result := False;
  if not Assigned(ABinding) then
    Exit;
  EnterCriticalSection(FCriticalSection);
  try
    lBinding := FConfig.Bindings.Find(ABinding.BotName);
    Result := Assigned(lBinding);
    if Result then
    begin
      lBinding.AllowPlain := ABinding.AllowPlain;
      lBinding.CAFile := ABinding.CAFile;
      lBinding.CodexExecutable := ABinding.CodexExecutable;
      lBinding.DirectTLS := ABinding.DirectTLS;
      lBinding.EndpointHost := ABinding.EndpointHost;
      lBinding.EndpointPort := ABinding.EndpointPort;
      lBinding.Nick := ABinding.Nick;
      lBinding.PasswordEnvironmentVariable :=
        ABinding.PasswordEnvironmentVariable;
      lBinding.Resource := ABinding.Resource;
      lBinding.RuntimeDirectory := ABinding.RuntimeDirectory;
      lBinding.XMPPJID := ABinding.XMPPJID;
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotController.Shutdown;
var
  lActive: TNXActiveBot;
  lActiveHosts: TList;
  lCleanup: TNXActiveBot;
  lIndex: Integer;
  lPending: TNXPendingBotOperation;
  lResult: TNXBotControlResult;
begin
  lResult := NXBotControlFailure(bceCancelled,
    'The bot controller is shutting down.');
  lActiveHosts := TList.Create;
  lActiveHosts.Capacity := FCatalog.Entries.Count;
  try
    EnterCriticalSection(FCriticalSection);
    try
      if FShuttingDown then
        Exit;
      FShuttingDown := True;
      for lIndex := 0 to FActive.Count - 1 do
      begin
        lActive := TNXActiveBot(FActive[lIndex]);
        Inc(lActive.ReferenceCount);
        lActiveHosts.Add(lActive);
      end;
    finally
      LeaveCriticalSection(FCriticalSection);
    end;

    for lIndex := 0 to lActiveHosts.Count - 1 do
      TNXActiveBot(lActiveHosts[lIndex]).Host.OnChanged := nil;
    for lIndex := 0 to lActiveHosts.Count - 1 do
      TNXActiveBot(lActiveHosts[lIndex]).Host.Shutdown;

    while True do
    begin
      lPending := nil;
      lCleanup := nil;
      EnterCriticalSection(FCriticalSection);
      try
        if FPending.Count > 0 then
          ExtractPendingUnsafe(0, lResult, lPending, lCleanup);
      finally
        LeaveCriticalSection(FCriticalSection);
      end;
      if not Assigned(lPending) then
        Break;
      FinishPending(lPending, lCleanup, lResult);
    end;

    for lIndex := 0 to lActiveHosts.Count - 1 do
    begin
      lActive := TNXActiveBot(lActiveHosts[lIndex]);
      EnterCriticalSection(FCriticalSection);
      try
        DetachActiveUnsafe(lActive);
      finally
        LeaveCriticalSection(FCriticalSection);
      end;
      ReleaseActive(lActive);
    end;
  finally
    lActiveHosts.Free;
  end;
end;

end.
