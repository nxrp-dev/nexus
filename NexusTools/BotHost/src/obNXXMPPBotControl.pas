unit obNXXMPPBotControl;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes,
  Contnrs,
  obNXXMPPCommand,
  obNXXMPPDispatcher,
  obNXXMPPModule,
  obNXXMPPStanza,
  SyncObjs,
  tpNXBotControl,
  tpNXXMPPTypes;

const
  cNXBotControlNamespace = 'urn:nexus:bot-control:1';

type
  TNXBotControlRequestEvent = function(
    const AOperation: TNXBotControlOperation;
    const AAuthorization: TNXBotAuthorization;
    ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean of object;
  TNXBotControlCancelEvent = function(AToken: QWord;
    const AReason: UTF8String): Boolean of object;
  TNXBotControlIQCompletion = procedure(
    const AResult: TNXBotControlResult) of object;

  TNXXMPPBotControlModule = class;

  TNXXMPPBotControlCall = class
  private
    FCompletion: TNXBotControlIQCompletion;
    FModule: TNXXMPPBotControlModule;
    procedure Complete(AStanza: TNXXMPPStanza; const AError: UTF8String);
  end;

  TNXXMPPBotControlModule = class(TNXXMPPModule)
  private
    FIncoming: TObjectList;
    FLock: TCriticalSection;
    FOnCancel: TNXBotControlCancelEvent;
    FOnRequest: TNXBotControlRequestEvent;
    FTransportAvailable: Boolean;
    procedure CancelIncoming(AIncoming: TObject; const AReason: UTF8String);
    procedure HandleDismiss(AStanza: TNXXMPPStanza);
    procedure HandleInvite(AStanza: TNXXMPPStanza);
    procedure HandleList(AStanza: TNXXMPPStanza);
    procedure HandleRequest(AStanza: TNXXMPPStanza;
      AKind: TNXBotControlOperationKind);
    procedure HandleStatus(AStanza: TNXXMPPStanza);
    function ParseResult(AStanza: TNXXMPPStanza;
      const AError: UTF8String): TNXBotControlResult;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFeatures(AFeatures: TStrings); override;
    function Call(const AControllerJID: UTF8String;
      const AOperation: TNXBotControlOperation;
      ACompletion: TNXBotControlIQCompletion;
      ATimeoutMS: Cardinal = cNXXMPPDefaultTimeoutMS): Boolean;
    procedure Lifecycle(ALifecycle: TNXXMPPModuleLifecycle); override;
    procedure ProcessCommand(AOperation: TNXXMPPModuleOperation); override;
    procedure RegisterHandlers(ADispatcher: TNXXMPPDispatcher); override;
    property OnCancel: TNXBotControlCancelEvent read FOnCancel write FOnCancel;
    property OnRequest: TNXBotControlRequestEvent read FOnRequest
      write FOnRequest;
  end;

implementation

uses
  DOM,
  SysUtils,
  obNXXMPPJID,
  utNXXMPPDOM,
  utNXXMPPXML;

type
  TNXXMPPBotControlPublication = (bcpRetained, bcpCompleted,
    bcpTransportLost, bcpRejected);

  TNXXMPPBotControlResponse = class(TNXXMPPModuleOperation)
  public
    XML: UTF8String;
  end;

  TNXXMPPBotControlIncoming = class
  private
    FCancelRequested: Boolean;
    FCompleted: Boolean;
    FCompletedResult: TNXBotControlResult;
    FFromJID: UTF8String;
    FID: UTF8String;
    FModule: TNXXMPPBotControlModule;
    FRequestXML: UTF8String;
    FResponseName: UTF8String;
    FToken: QWord;
    FPublishing: Boolean;
    FTransportLost: Boolean;
    procedure Complete(const AToken: QWord;
      const AResult: TNXBotControlResult);
    procedure Deliver(const AResult: TNXBotControlResult;
      ATransportAvailable: Boolean);
  end;

function BoolText(AValue: Boolean): UTF8String;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function ChildElement(AStanza: TNXXMPPStanza): TDOMElement;
begin
  Result := NXXMPPFirstChildElement(AStanza.Root);
end;

function HasOnlyAttributes(AElement: TDOMElement;
  const AAllowed: array of UTF8String): Boolean;
var
  lAllowed: Boolean;
  lIndex: Integer;
  lName: UTF8String;
  lPermit: Integer;
begin
  Result := Assigned(AElement);
  if not Result then
    Exit;
  for lIndex := 0 to AElement.Attributes.Length - 1 do
  begin
    lName := UTF8Encode(AElement.Attributes.Item[lIndex].NodeName);
    if (lName = 'xmlns') or (Copy(lName, 1, 6) = 'xmlns:') then
      Continue;
    lAllowed := False;
    for lPermit := Low(AAllowed) to High(AAllowed) do
      if lName = AAllowed[lPermit] then
      begin
        lAllowed := True;
        Break;
      end;
    if not lAllowed then
      Exit(False);
  end;
end;

function EmptyElement(AElement: TDOMElement): Boolean;
var
  lNode: TDOMNode;
begin
  Result := False;
  if not Assigned(AElement) then
    Exit;
  lNode := AElement.FirstChild;
  while Assigned(lNode) do
  begin
    if (lNode is TDOMElement) or
      (Trim(UTF8Encode(lNode.NodeValue)) <> '') then
      Exit;
    lNode := lNode.NextSibling;
  end;
  Result := True;
end;

function RequestPayload(const AOperation: TNXBotControlOperation): UTF8String;
begin
  case AOperation.Kind of
    bcokList:
      Result := '<bots xmlns=''' + cNXBotControlNamespace + '''/>';
    bcokStatus:
      Result := '<status xmlns=''' + cNXBotControlNamespace + ''' bot=''' +
        NXXMPPEscapeAttribute(AOperation.BotName) + '''/>';
    bcokInvite:
      Result := '<invite xmlns=''' + cNXBotControlNamespace + ''' bot=''' +
        NXXMPPEscapeAttribute(AOperation.BotName) + ''' room=''' +
        NXXMPPEscapeAttribute(AOperation.RoomJID) + '''/>';
    bcokDismiss:
      Result := '<dismiss xmlns=''' + cNXBotControlNamespace + ''' bot=''' +
        NXXMPPEscapeAttribute(AOperation.BotName) + ''' room=''' +
        NXXMPPEscapeAttribute(AOperation.RoomJID) + '''/>';
  end;
end;

function SerializeBot(const AStatus: TNXBotStatus): UTF8String;
var
  lIndex: Integer;
begin
  Result := '<bot name=''' + NXXMPPEscapeAttribute(AStatus.Name) +
    ''' known=''' + BoolText(AStatus.Known) + ''' available=''' +
    BoolText(AStatus.Available) + ''' active=''' + BoolText(AStatus.Active) +
    ''' provider=''' + NXXMPPEscapeAttribute(AStatus.Provider) +
    ''' model=''' + NXXMPPEscapeAttribute(AStatus.Model) +
    ''' app-server=''' + NXXMPPEscapeAttribute(AStatus.AppServerState) +
    ''' xmpp=''' + NXXMPPEscapeAttribute(AStatus.XMPPState) + '''';
  if AStatus.Diagnostic <> '' then
    Result := Result + ' diagnostic=''' +
      NXXMPPEscapeAttribute(AStatus.Diagnostic) + '''';
  if Length(AStatus.Rooms) = 0 then
    Exit(Result + '/>');
  Result := Result + '>';
  for lIndex := 0 to High(AStatus.Rooms) do
    Result := Result + '<room jid=''' +
      NXXMPPEscapeAttribute(AStatus.Rooms[lIndex].RoomJID) + ''' state=''' +
      NXXMPPEscapeAttribute(AStatus.Rooms[lIndex].State) + '''/>';
  Result := Result + '</bot>';
end;

function ErrorType(AError: TNXBotControlError): UTF8String;
begin
  case AError of
    bceBadRequest: Result := 'modify';
    bceForbidden: Result := 'auth';
    bceCapacity, bceTimeout: Result := 'wait';
  else
    Result := 'cancel';
  end;
end;

function ErrorCondition(AError: TNXBotControlError): UTF8String;
begin
  case AError of
    bceBadRequest: Result := 'bad-request';
    bceForbidden: Result := 'forbidden';
    bceNotFound: Result := 'item-not-found';
    bceCapacity: Result := 'resource-constraint';
    bceTimeout: Result := 'remote-server-timeout';
  else
    Result := 'service-unavailable';
  end;
end;

function ResponseXML(const AID, AFromJID, ARequestXML,
  AResponseName: UTF8String; const AResult: TNXBotControlResult): UTF8String;
var
  lIndex: Integer;
begin
  Result := '<iq type=''';
  if AResult.Error = bceNone then
    Result := Result + 'result'
  else
    Result := Result + 'error';
  Result := Result + ''' id=''' + NXXMPPEscapeAttribute(AID) + '''';
  if AFromJID <> '' then
    Result := Result + ' to=''' + NXXMPPEscapeAttribute(AFromJID) + '''';
  Result := Result + '>';
  if AResult.Error = bceNone then
  begin
    Result := Result + '<' + AResponseName + ' xmlns=''' +
      cNXBotControlNamespace + ''' no-op=''' + BoolText(AResult.NoOp) + '''>';
    for lIndex := 0 to High(AResult.Bots) do
      Result := Result + SerializeBot(AResult.Bots[lIndex]);
    if AResult.Detail <> '' then
      Result := Result + '<detail>' + NXXMPPEscapeText(AResult.Detail) +
        '</detail>';
    Result := Result + '</' + AResponseName + '>';
  end
  else
  begin
    Result := Result + ARequestXML + '<error type=''' +
      ErrorType(AResult.Error) + '''><' + ErrorCondition(AResult.Error) +
      ' xmlns=''urn:ietf:params:xml:ns:xmpp-stanzas''/>';
    if AResult.Error = bceUnavailable then
      Result := Result + '<bot-unavailable xmlns=''' +
        cNXBotControlNamespace + '''/>';
    if AResult.Detail <> '' then
      Result := Result + '<text xmlns=''urn:ietf:params:xml:ns:xmpp-stanzas''>' +
        NXXMPPEscapeText(AResult.Detail) + '</text>';
    Result := Result + '</error>';
  end;
  Result := Result + '</iq>';
end;

procedure TNXXMPPBotControlIncoming.Complete(const AToken: QWord;
  const AResult: TNXBotControlResult);
var
  lRetained: Boolean;
  lTransportAvailable: Boolean;
begin
  FModule.FLock.Acquire;
  try
    lRetained := FModule.FIncoming.IndexOf(Self) >= 0;
    if lRetained and FPublishing then
    begin
      FCompleted := True;
      FCompletedResult := AResult;
      FToken := AToken;
      Exit;
    end;
    if lRetained then
      FModule.FIncoming.Extract(Self);
    lTransportAvailable := FModule.FTransportAvailable;
  finally
    FModule.FLock.Release;
  end;
  if not lRetained then
    Exit;
  Deliver(AResult, lTransportAvailable);
end;

procedure TNXXMPPBotControlIncoming.Deliver(
  const AResult: TNXBotControlResult; ATransportAvailable: Boolean);
var
  lOperation: TNXXMPPBotControlResponse;
begin
  if not ATransportAvailable then
  begin
    Free;
    Exit;
  end;
  lOperation := TNXXMPPBotControlResponse.Create;
  lOperation.XML := ResponseXML(FID, FFromJID, FRequestXML, FResponseName,
    AResult);
  if not FModule.Submit(lOperation) then
    lOperation := nil;
  Free;
end;

constructor TNXXMPPBotControlModule.Create;
begin
  inherited Create;
  FIncoming := TObjectList.Create(True);
  FLock := TCriticalSection.Create;
  FTransportAvailable := True;
end;

procedure TNXXMPPBotControlModule.CancelIncoming(AIncoming: TObject;
  const AReason: UTF8String);
var
  lAccepted: Boolean;
  lIncoming: TNXXMPPBotControlIncoming;
  lRetained: Boolean;
begin
  lIncoming := TNXXMPPBotControlIncoming(AIncoming);
  lAccepted := Assigned(FOnCancel) and (lIncoming.FToken <> 0) and
    FOnCancel(lIncoming.FToken, AReason);
  if lAccepted then
    Exit;
  FLock.Acquire;
  try
    lRetained := FIncoming.IndexOf(lIncoming) >= 0;
    if lRetained then
      FIncoming.Extract(lIncoming);
  finally
    FLock.Release;
  end;
  if lRetained then
    lIncoming.Free;
end;

destructor TNXXMPPBotControlModule.Destroy;
begin
  Lifecycle(xmlFinalDisconnect);
  FLock.Free;
  FIncoming.Free;
  inherited Destroy;
end;

procedure TNXXMPPBotControlModule.AddFeatures(AFeatures: TStrings);
begin
  AFeatures.Add(cNXBotControlNamespace);
end;

procedure TNXXMPPBotControlModule.ProcessCommand(
  AOperation: TNXXMPPModuleOperation);
begin
  if not (AOperation is TNXXMPPBotControlResponse) then
  begin
    inherited ProcessCommand(AOperation);
    Exit;
  end;
  Send(TNXXMPPBotControlResponse(AOperation).XML);
end;

procedure TNXXMPPBotControlModule.Lifecycle(
  ALifecycle: TNXXMPPModuleLifecycle);
var
  lIncoming: TNXXMPPBotControlIncoming;
  lIndex: Integer;
begin
  if ALifecycle in [xmlStreamResumed, xmlNewSession] then
  begin
    FLock.Acquire;
    try
      FTransportAvailable := True;
    finally
      FLock.Release;
    end;
    Exit;
  end;
  if not (ALifecycle in [xmlPermanentLoss, xmlFinalDisconnect]) then
    Exit;
  while True do
  begin
    FLock.Acquire;
    try
      FTransportAvailable := False;
      lIncoming := nil;
      for lIndex := 0 to FIncoming.Count - 1 do
        if TNXXMPPBotControlIncoming(FIncoming[lIndex]).FPublishing then
          TNXXMPPBotControlIncoming(FIncoming[lIndex]).FTransportLost := True
        else if not TNXXMPPBotControlIncoming(
          FIncoming[lIndex]).FCancelRequested then
        begin
          lIncoming := TNXXMPPBotControlIncoming(FIncoming[lIndex]);
          lIncoming.FCancelRequested := True;
          lIncoming.FTransportLost := True;
          Break;
        end;
    finally
      FLock.Release;
    end;
    if not Assigned(lIncoming) then
      Break;
    CancelIncoming(lIncoming, 'The XMPP control transport was lost.');
  end;
end;

procedure TNXXMPPBotControlModule.RegisterHandlers(
  ADispatcher: TNXXMPPDispatcher);
begin
  ADispatcher.RegisterIQResponder(xitGet, cNXBotControlNamespace, 'bots',
    @HandleList);
  ADispatcher.RegisterIQResponder(xitGet, cNXBotControlNamespace, 'status',
    @HandleStatus);
  ADispatcher.RegisterIQResponder(xitSet, cNXBotControlNamespace, 'invite',
    @HandleInvite);
  ADispatcher.RegisterIQResponder(xitSet, cNXBotControlNamespace, 'dismiss',
    @HandleDismiss);
end;

procedure TNXXMPPBotControlModule.HandleList(AStanza: TNXXMPPStanza);
begin
  HandleRequest(AStanza, bcokList);
end;

procedure TNXXMPPBotControlModule.HandleStatus(AStanza: TNXXMPPStanza);
begin
  HandleRequest(AStanza, bcokStatus);
end;

procedure TNXXMPPBotControlModule.HandleInvite(AStanza: TNXXMPPStanza);
begin
  HandleRequest(AStanza, bcokInvite);
end;

procedure TNXXMPPBotControlModule.HandleDismiss(AStanza: TNXXMPPStanza);
begin
  HandleRequest(AStanza, bcokDismiss);
end;

procedure TNXXMPPBotControlModule.HandleRequest(AStanza: TNXXMPPStanza;
  AKind: TNXBotControlOperationKind);
var
  lAccepted: Boolean;
  lAuthorization: TNXBotAuthorization;
  lBotName: UTF8String;
  lCaller: TNXXMPPJID;
  lChild: TDOMElement;
  lIncoming: TNXXMPPBotControlIncoming;
  lOperation: TNXBotControlOperation;
  lPublication: TNXXMPPBotControlPublication;
  lResult: TNXBotControlResult;
  lRoomJID: UTF8String;
  lToken: QWord;
  lTransportAvailable: Boolean;
begin
  lChild := ChildElement(AStanza);
  lBotName := '';
  lRoomJID := '';
  if Assigned(lChild) then
  begin
    lBotName := UTF8Encode(lChild.GetAttribute('bot'));
    lRoomJID := UTF8Encode(lChild.GetAttribute('room'));
  end;
  lResult := NXBotControlFailure(bceBadRequest,
    'The bot-control request is malformed.');
  if (AStanza.ID = '') or (AStanza.FromJID = '') or
    not Assigned(lChild) or not EmptyElement(lChild) or
    ((AKind = bcokList) and not HasOnlyAttributes(lChild, [])) or
    ((AKind = bcokStatus) and ((lBotName = '') or
      not HasOnlyAttributes(lChild, ['bot']))) or
    ((AKind in [bcokInvite, bcokDismiss]) and
      ((lBotName = '') or (lRoomJID = '') or
      not HasOnlyAttributes(lChild, ['bot', 'room']))) then
  begin
    lIncoming := TNXXMPPBotControlIncoming.Create;
    lIncoming.FModule := Self;
    lIncoming.FID := AStanza.ID;
    lIncoming.FFromJID := AStanza.FromJID;
    lIncoming.FRequestXML := AStanza.ChildXML;
    lIncoming.FResponseName := AStanza.ChildLocalName;
    FLock.Acquire;
    try
      lTransportAvailable := FTransportAvailable;
    finally
      FLock.Release;
    end;
    lIncoming.Deliver(lResult, lTransportAvailable);
    Exit;
  end;
  try
    lCaller := TNXXMPPJID.Create(AStanza.FromJID);
    try
      lAuthorization := NXBotAuthorization(bcoRemoteIQ, lCaller.Bare, '', True);
    finally
      lCaller.Free;
    end;
  except
    lIncoming := TNXXMPPBotControlIncoming.Create;
    lIncoming.FModule := Self;
    lIncoming.FID := AStanza.ID;
    lIncoming.FFromJID := AStanza.FromJID;
    lIncoming.FRequestXML := AStanza.ChildXML;
    lIncoming.FResponseName := AStanza.ChildLocalName;
    FLock.Acquire;
    try
      lTransportAvailable := FTransportAvailable;
    finally
      FLock.Release;
    end;
    lIncoming.Deliver(lResult, lTransportAvailable);
    Exit;
  end;
  lOperation := NXBotControlOperation(AKind, lBotName, lRoomJID);
  lIncoming := TNXXMPPBotControlIncoming.Create;
  lIncoming.FModule := Self;
  lIncoming.FID := AStanza.ID;
  lIncoming.FFromJID := AStanza.FromJID;
  lIncoming.FRequestXML := AStanza.ChildXML;
  lIncoming.FResponseName := AStanza.ChildLocalName;
  lIncoming.FPublishing := True;
  FLock.Acquire;
  try
    FIncoming.Add(lIncoming);
  finally
    FLock.Release;
  end;
  lToken := 0;
  if not Assigned(FOnRequest) then
    lAccepted := False
  else
    lAccepted := FOnRequest(lOperation, lAuthorization,
      @lIncoming.Complete, lToken);
  lPublication := bcpRetained;
  FLock.Acquire;
  try
    lTransportAvailable := FTransportAvailable;
    lIncoming.FToken := lToken;
    lIncoming.FPublishing := False;
    if lIncoming.FCompleted then
    begin
      FIncoming.Extract(lIncoming);
      lPublication := bcpCompleted;
      lResult := lIncoming.FCompletedResult;
    end
    else if lIncoming.FTransportLost then
    begin
      if lAccepted and (lToken <> 0) then
        lIncoming.FCancelRequested := True
      else
        FIncoming.Extract(lIncoming);
      lPublication := bcpTransportLost;
    end
    else if not lAccepted then
    begin
      FIncoming.Extract(lIncoming);
      lPublication := bcpRejected;
    end;
  finally
    FLock.Release;
  end;
  case lPublication of
    bcpCompleted:
      lIncoming.Deliver(lResult,
        not lIncoming.FTransportLost and lTransportAvailable);
    bcpTransportLost:
      begin
        if lAccepted and (lToken <> 0) then
          CancelIncoming(lIncoming,
            'The XMPP control transport was lost.')
        else
          lIncoming.Free;
      end;
    bcpRejected:
      lIncoming.Deliver(NXBotControlFailure(bceUnavailable,
        'The bot controller did not accept the request.'),
        lTransportAvailable);
  end;
end;

function TNXXMPPBotControlModule.Call(const AControllerJID: UTF8String;
  const AOperation: TNXBotControlOperation;
  ACompletion: TNXBotControlIQCompletion; ATimeoutMS: Cardinal): Boolean;
var
  lCall: TNXXMPPBotControlCall;
  lType: TNXXMPPIQType;
begin
  Result := False;
  if (AControllerJID = '') or not Assigned(ACompletion) then
    Exit;
  if AOperation.Kind in [bcokList, bcokStatus] then
    lType := xitGet
  else
    lType := xitSet;
  lCall := TNXXMPPBotControlCall.Create;
  lCall.FModule := Self;
  lCall.FCompletion := ACompletion;
  Result := SubmitIQ(lType, AControllerJID, AControllerJID,
    RequestPayload(AOperation), @lCall.Complete, ATimeoutMS);
  if not Result then
    lCall.Free;
end;

procedure TNXXMPPBotControlCall.Complete(AStanza: TNXXMPPStanza;
  const AError: UTF8String);
var
  lResult: TNXBotControlResult;
begin
  lResult := FModule.ParseResult(AStanza, AError);
  try
    if Assigned(FCompletion) then
      FCompletion(lResult);
  finally
    Free;
  end;
end;

function ParseBooleanAttribute(AElement: TDOMElement;
  const AName: UnicodeString): Boolean;
begin
  Result := UTF8Encode(AElement.GetAttribute(AName)) = 'true';
end;

function TNXXMPPBotControlModule.ParseResult(AStanza: TNXXMPPStanza;
  const AError: UTF8String): TNXBotControlResult;
var
  lBot: TDOMElement;
  lChild: TDOMElement;
  lRoom: TDOMElement;
  lStatus: TNXBotStatus;
begin
  if AError <> '' then
    Exit(NXBotControlFailure(bceTimeout, AError));
  if not Assigned(AStanza) then
    Exit(NXBotControlFailure(bceUnavailable,
      'The bot-control response is missing.'));
  if AStanza.IQType = xitError then
  begin
    lChild := NXXMPPFindChild(AStanza.Root,
      'urn:ietf:params:xml:ns:xmpp-stanzas', 'forbidden');
    if Assigned(lChild) then
      Exit(NXBotControlFailure(bceForbidden, AStanza.TextContent));
    lChild := NXXMPPFindChild(AStanza.Root,
      'urn:ietf:params:xml:ns:xmpp-stanzas', 'bad-request');
    if Assigned(lChild) then
      Exit(NXBotControlFailure(bceBadRequest, AStanza.TextContent));
    lChild := NXXMPPFindChild(AStanza.Root,
      'urn:ietf:params:xml:ns:xmpp-stanzas', 'item-not-found');
    if Assigned(lChild) then
      Exit(NXBotControlFailure(bceNotFound, AStanza.TextContent));
    lChild := NXXMPPFindChild(AStanza.Root,
      'urn:ietf:params:xml:ns:xmpp-stanzas', 'resource-constraint');
    if Assigned(lChild) then
      Exit(NXBotControlFailure(bceCapacity, AStanza.TextContent));
    lChild := NXXMPPFindChild(AStanza.Root,
      'urn:ietf:params:xml:ns:xmpp-stanzas', 'remote-server-timeout');
    if Assigned(lChild) then
      Exit(NXBotControlFailure(bceTimeout, AStanza.TextContent));
    Exit(NXBotControlFailure(bceUnavailable, AStanza.TextContent));
  end;
  if AStanza.IQType <> xitResult then
    Exit(NXBotControlFailure(bceBadRequest,
      'The bot-control response has an invalid IQ type.'));
  lChild := ChildElement(AStanza);
  if not Assigned(lChild) then
    Exit(NXBotControlFailure(bceBadRequest,
      'The bot-control result payload is missing.'));
  Result.Error := bceNone;
  Result.NoOp := ParseBooleanAttribute(lChild, 'no-op');
  Result.Detail := '';
  SetLength(Result.Bots, 0);
  lBot := NXXMPPFirstChildElement(lChild);
  while Assigned(lBot) do
  begin
    if UTF8Encode(lBot.NodeName) = 'detail' then
      Result.Detail := NXXMPPDirectText(lBot)
    else if UTF8Encode(lBot.NodeName) = 'bot' then
    begin
      lStatus.Name := UTF8Encode(lBot.GetAttribute('name'));
      lStatus.Known := ParseBooleanAttribute(lBot, 'known');
      lStatus.Available := ParseBooleanAttribute(lBot, 'available');
      lStatus.Active := ParseBooleanAttribute(lBot, 'active');
      lStatus.Provider := UTF8Encode(lBot.GetAttribute('provider'));
      lStatus.Model := UTF8Encode(lBot.GetAttribute('model'));
      lStatus.AppServerState := UTF8Encode(lBot.GetAttribute('app-server'));
      lStatus.XMPPState := UTF8Encode(lBot.GetAttribute('xmpp'));
      lStatus.Diagnostic := UTF8Encode(lBot.GetAttribute('diagnostic'));
      SetLength(lStatus.Rooms, 0);
      lRoom := NXXMPPFirstChildElement(lBot);
      while Assigned(lRoom) do
      begin
        if UTF8Encode(lRoom.NodeName) = 'room' then
        begin
          SetLength(lStatus.Rooms, Length(lStatus.Rooms) + 1);
          lStatus.Rooms[High(lStatus.Rooms)].RoomJID :=
            UTF8Encode(lRoom.GetAttribute('jid'));
          lStatus.Rooms[High(lStatus.Rooms)].State :=
            UTF8Encode(lRoom.GetAttribute('state'));
        end;
        lRoom := NXXMPPNextSiblingElement(lRoom);
      end;
      SetLength(Result.Bots, Length(Result.Bots) + 1);
      Result.Bots[High(Result.Bots)] := lStatus;
    end;
    lBot := NXXMPPNextSiblingElement(lBot);
  end;
end;

end.
