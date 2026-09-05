unit tpNXBotHost;

{$mode objfpc}{$H+}

interface

type
  TNXCodexAppServerState = (
    cassStopped,
    cassStarting,
    cassInitializing,
    cassResolvingModel,
    cassCreatingThread,
    cassReady,
    cassBusy,
    cassStopping,
    cassFailed
  );

  TNXBotPrompt = class
  private
    FBody: UTF8String;
    FMessageID: UTF8String;
    FRoomJID: UTF8String;
    FSenderJID: UTF8String;
    FSequence: QWord;
    FVerifiedCallerBareJID: UTF8String;
    FVerifiedMUCIdentity: Boolean;
  public
    constructor Create(const ASequence: QWord; const ARoomJID, ASenderJID,
      AMessageID, ABody: UTF8String);
    function Clone: TNXBotPrompt;
    procedure SetVerifiedCaller(const ABareJID: UTF8String;
      AVerified: Boolean);

    property Body: UTF8String read FBody;
    property MessageID: UTF8String read FMessageID;
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
  Result.SetVerifiedCaller(FVerifiedCallerBareJID, FVerifiedMUCIdentity);
end;

procedure TNXBotPrompt.SetVerifiedCaller(const ABareJID: UTF8String;
  AVerified: Boolean);
begin
  FVerifiedCallerBareJID := ABareJID;
  FVerifiedMUCIdentity := AVerified;
end;

end.
