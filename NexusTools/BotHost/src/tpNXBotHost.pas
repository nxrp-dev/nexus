unit tpNXBotHost;

{$mode objfpc}{$H+}

interface

type
  TNXBotPromptDelivery = (bpdRoom, bpdDirect);

  TNXBotProviderState = (
    bpsStopped,
    bpsStarting,
    bpsReady,
    bpsWorking,
    bpsStopping,
    bpsFailed
  );

  TNXBotPrompt = class
  private
    FBody: UTF8String;
    FDelivery: TNXBotPromptDelivery;
    FMessageID: UTF8String;
    FReplyID: UTF8String;
    FRoomJID: UTF8String;
    FSenderJID: UTF8String;
    FSequence: QWord;
    FVerifiedCallerBareJID: UTF8String;
    FVerifiedMUCIdentity: Boolean;
  public
    constructor Create(const ASequence: QWord; const ARoomJID, ASenderJID,
      AMessageID, ABody: UTF8String);
    function Clone: TNXBotPrompt;
    function ModelInput: UTF8String;
    procedure SetDirectResponse(const AReplyID: UTF8String);
    procedure SetVerifiedCaller(const ABareJID: UTF8String;
      AVerified: Boolean);

    property Body: UTF8String read FBody;
    property Delivery: TNXBotPromptDelivery read FDelivery;
    property MessageID: UTF8String read FMessageID;
    property ReplyID: UTF8String read FReplyID;
    property RoomJID: UTF8String read FRoomJID;
    property SenderJID: UTF8String read FSenderJID;
    property Sequence: QWord read FSequence;
    property VerifiedCallerBareJID: UTF8String read FVerifiedCallerBareJID;
    property VerifiedMUCIdentity: Boolean read FVerifiedMUCIdentity;
  end;

implementation

constructor TNXBotPrompt.Create(const ASequence: QWord; const ARoomJID,
  ASenderJID, AMessageID, ABody: UTF8String);
begin
  inherited Create;
  FDelivery := bpdRoom;
  FSequence := ASequence;
  FRoomJID := ARoomJID;
  FSenderJID := ASenderJID;
  FMessageID := AMessageID;
  FBody := ABody;
end;

function TNXBotPrompt.Clone: TNXBotPrompt;
begin
  Result := TNXBotPrompt.Create(FSequence, FRoomJID, FSenderJID, FMessageID,
    FBody);
  if FDelivery = bpdDirect then
    Result.SetDirectResponse(FReplyID);
  Result.SetVerifiedCaller(FVerifiedCallerBareJID, FVerifiedMUCIdentity);
end;

function TNXBotPrompt.ModelInput: UTF8String;
begin
  if FDelivery = bpdRoom then
    Result := 'XMPP context: group message in room ' + FRoomJID + '.'
  else if FRoomJID <> '' then
    Result := 'XMPP context: private message from room ' + FRoomJID + '.'
  else
    Result := 'XMPP context: direct message with no originating room.';
  Result := Result + LineEnding + LineEnding + FBody;
end;

procedure TNXBotPrompt.SetDirectResponse(const AReplyID: UTF8String);
begin
  FDelivery := bpdDirect;
  FReplyID := AReplyID;
end;

procedure TNXBotPrompt.SetVerifiedCaller(const ABareJID: UTF8String;
  AVerified: Boolean);
begin
  FVerifiedCallerBareJID := ABareJID;
  FVerifiedMUCIdentity := AVerified;
end;

end.
