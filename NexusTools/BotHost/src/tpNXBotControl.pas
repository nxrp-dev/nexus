unit tpNXBotControl;

{$mode objfpc}{$H+}

interface

type
  TNXBotControlOperationKind = (bcokList, bcokStatus, bcokInvite,
    bcokDismiss);
  TNXBotControlOrigin = (bcoHumanMUC, bcoModelTool, bcoRemoteIQ);
  TNXBotControlError = (bceNone, bceBadRequest, bceForbidden,
    bceNotFound, bceUnavailable, bceCapacity, bceTimeout, bceCancelled);

  TNXBotControlOperation = record
    Kind: TNXBotControlOperationKind;
    BotName: UTF8String;
    RoomJID: UTF8String;
  end;

  TNXBotAuthorization = record
    Origin: TNXBotControlOrigin;
    CallerBareJID: UTF8String;
    SourceRoomJID: UTF8String;
    VerifiedMUCIdentity: Boolean;
  end;

  TNXBotRoomStatus = record
    RoomJID: UTF8String;
    State: UTF8String;
  end;
  TNXBotRoomStatusArray = array of TNXBotRoomStatus;

  TNXBotStatus = record
    Name: UTF8String;
    Known: Boolean;
    Available: Boolean;
    Active: Boolean;
    Provider: UTF8String;
    Model: UTF8String;
    AppServerState: UTF8String;
    XMPPState: UTF8String;
    Diagnostic: UTF8String;
    Rooms: TNXBotRoomStatusArray;
  end;
  TNXBotStatusArray = array of TNXBotStatus;

  TNXBotControlResult = record
    Error: TNXBotControlError;
    Detail: UTF8String;
    NoOp: Boolean;
    Bots: TNXBotStatusArray;
  end;

  TNXBotControlCompletion = procedure(const AToken: QWord;
    const AResult: TNXBotControlResult) of object;

function NXBotControlOperation(AKind: TNXBotControlOperationKind;
  const ABotName, ARoomJID: UTF8String): TNXBotControlOperation;
function NXBotAuthorization(AOrigin: TNXBotControlOrigin;
  const ACallerBareJID, ASourceRoomJID: UTF8String;
  AVerifiedMUCIdentity: Boolean): TNXBotAuthorization;
function NXBotControlFailure(AError: TNXBotControlError;
  const ADetail: UTF8String): TNXBotControlResult;
function NXBotControlErrorName(AError: TNXBotControlError): UTF8String;
function NXBotControlOperationName(
  AKind: TNXBotControlOperationKind): UTF8String;

implementation

function NXBotControlOperation(AKind: TNXBotControlOperationKind;
  const ABotName, ARoomJID: UTF8String): TNXBotControlOperation;
begin
  Result.Kind := AKind;
  Result.BotName := ABotName;
  Result.RoomJID := ARoomJID;
end;

function NXBotAuthorization(AOrigin: TNXBotControlOrigin;
  const ACallerBareJID, ASourceRoomJID: UTF8String;
  AVerifiedMUCIdentity: Boolean): TNXBotAuthorization;
begin
  Result.Origin := AOrigin;
  Result.CallerBareJID := ACallerBareJID;
  Result.SourceRoomJID := ASourceRoomJID;
  Result.VerifiedMUCIdentity := AVerifiedMUCIdentity;
end;

function NXBotControlFailure(AError: TNXBotControlError;
  const ADetail: UTF8String): TNXBotControlResult;
begin
  Result.Error := AError;
  Result.Detail := ADetail;
  Result.NoOp := False;
  SetLength(Result.Bots, 0);
end;

function NXBotControlErrorName(AError: TNXBotControlError): UTF8String;
begin
  case AError of
    bceNone: Result := 'none';
    bceBadRequest: Result := 'bad-request';
    bceForbidden: Result := 'forbidden';
    bceNotFound: Result := 'item-not-found';
    bceUnavailable: Result := 'service-unavailable';
    bceCapacity: Result := 'resource-constraint';
    bceTimeout: Result := 'remote-server-timeout';
    bceCancelled: Result := 'cancelled';
  end;
end;

function NXBotControlOperationName(
  AKind: TNXBotControlOperationKind): UTF8String;
begin
  case AKind of
    bcokList: Result := 'list';
    bcokStatus: Result := 'status';
    bcokInvite: Result := 'invite';
    bcokDismiss: Result := 'dismiss';
  end;
end;

end.
