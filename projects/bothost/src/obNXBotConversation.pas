unit obNXBotConversation;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  tpNXXMPPMessageTypes;

type
  TNXBotConversationTracker = class
  private
    FBotNicks: TStringList;
    FCriticalSection: TRTLCriticalSection;
    FMessages: TObjectList;
    FPendingAnswers: TObjectList;
    FRooms: TObjectList;
    FTimeoutMS: QWord;
    function AddressedBotUnsafe(const ABody,
      ADisplayBody: UTF8String): UTF8String;
    procedure ClearExpiredUnsafe(const ANow: QWord);
    function FindMessageUnsafe(const AKey: UTF8String): TObject;
    function FindPendingUnsafe(const ARoomJID,
      ABotNick: UTF8String): TObject;
    function FindRoomUnsafe(const ARoomJID: UTF8String): TObject;
    function RegisteredBotUnsafe(const ANick: UTF8String): Boolean;
  protected
    function CurrentTick: QWord; virtual;
  public
    constructor Create(ATimeoutMS: QWord);
    destructor Destroy; override;
    procedure BeginAnswer(const ARoomJID, ABotNick, ASenderJID,
      ASenderIdentity, ABody: UTF8String);
    procedure CancelAnswer(const ARoomJID, ABotNick: UTF8String);
    procedure ClearBotRoom(const ARoomJID, ABotNick: UTF8String);
    function Observe(const ARoomJID, ASenderJID,
      ASenderIdentity, AMessageID, ATypeValue, ABody,
      ADisplayBody: UTF8String; const AReply: TNXXMPPReplyReference;
      AContext: TNXXMPPMessageDeliveryContext; AValid: Boolean;
      out AReason: UTF8String): UTF8String;
    procedure RegisterBot(const ANick: UTF8String);
  end;

implementation

uses
  SysUtils,
  obNXBotHostRouter;

const
  cMessageCapacity = 256;

type
  TNXBotConversationRoom = class
  public
    BotNick: UTF8String;
    ExpiresAt: QWord;
    Generation: QWord;
    RoomJID: UTF8String;
    SenderIdentity: UTF8String;
    SenderJID: UTF8String;
  end;

  TNXBotPendingAnswer = class
  public
    Body: UTF8String;
    BotNick: UTF8String;
    CreatedAt: QWord;
    Generation: QWord;
    RoomJID: UTF8String;
    SenderIdentity: UTF8String;
    SenderJID: UTF8String;
  end;

  TNXBotObservedMessage = class
  public
    CreatedAt: QWord;
    Key: UTF8String;
    Reason: UTF8String;
    TargetBot: UTF8String;
  end;

function HasLeadingAddress(const ABody: UTF8String): Boolean;
var
  lPosition: Integer;
begin
  Result := (Length(ABody) > 1) and (ABody[1] = '@');
  if not Result then
    Exit;
  lPosition := 2;
  while (lPosition <= Length(ABody)) and
    not (ABody[lPosition] in [#9, #10, #13, ' ']) do
    Inc(lPosition);
  Result := lPosition > 2;
end;

function TNXBotConversationTracker.CurrentTick: QWord;
begin
  Result := GetTickCount64;
end;

constructor TNXBotConversationTracker.Create(ATimeoutMS: QWord);
begin
  inherited Create;
  if ATimeoutMS < 1 then
    raise Exception.Create('Implied reply timeout must be positive.');
  FTimeoutMS := ATimeoutMS;
  FBotNicks := TStringList.Create;
  FBotNicks.CaseSensitive := False;
  FBotNicks.Sorted := True;
  FBotNicks.Duplicates := dupIgnore;
  FMessages := TObjectList.Create(True);
  FPendingAnswers := TObjectList.Create(True);
  FRooms := TObjectList.Create(True);
  InitCriticalSection(FCriticalSection);
end;

destructor TNXBotConversationTracker.Destroy;
begin
  DoneCriticalSection(FCriticalSection);
  FRooms.Free;
  FPendingAnswers.Free;
  FMessages.Free;
  FBotNicks.Free;
  inherited Destroy;
end;

function TNXBotConversationTracker.RegisteredBotUnsafe(
  const ANick: UTF8String): Boolean;
begin
  Result := FBotNicks.IndexOf(string(ANick)) >= 0;
end;

function TNXBotConversationTracker.AddressedBotUnsafe(const ABody,
  ADisplayBody: UTF8String): UTF8String;
var
  lIndex: Integer;
  lNick: UTF8String;
begin
  Result := '';
  for lIndex := 0 to FBotNicks.Count - 1 do
  begin
    lNick := UTF8String(FBotNicks[lIndex]);
    if NXBotHostHasAddress(ABody, ADisplayBody, lNick) then
      Exit(lNick);
  end;
end;

function TNXBotConversationTracker.FindRoomUnsafe(
  const ARoomJID: UTF8String): TObject;
var
  lIndex: Integer;
begin
  Result := nil;
  for lIndex := 0 to FRooms.Count - 1 do
    if TNXBotConversationRoom(FRooms[lIndex]).RoomJID = ARoomJID then
      Exit(FRooms[lIndex]);
end;

function TNXBotConversationTracker.FindPendingUnsafe(const ARoomJID,
  ABotNick: UTF8String): TObject;
var
  lIndex: Integer;
  lPending: TNXBotPendingAnswer;
begin
  Result := nil;
  for lIndex := 0 to FPendingAnswers.Count - 1 do
  begin
    lPending := TNXBotPendingAnswer(FPendingAnswers[lIndex]);
    if (lPending.RoomJID = ARoomJID) and
      SameText(string(lPending.BotNick), string(ABotNick)) then
      Exit(lPending);
  end;
end;

function TNXBotConversationTracker.FindMessageUnsafe(
  const AKey: UTF8String): TObject;
var
  lIndex: Integer;
begin
  Result := nil;
  for lIndex := FMessages.Count - 1 downto 0 do
    if TNXBotObservedMessage(FMessages[lIndex]).Key = AKey then
      Exit(FMessages[lIndex]);
end;

procedure TNXBotConversationTracker.ClearExpiredUnsafe(const ANow: QWord);
var
  lIndex: Integer;
  lRoom: TNXBotConversationRoom;
begin
  for lIndex := FPendingAnswers.Count - 1 downto 0 do
    if ANow - TNXBotPendingAnswer(FPendingAnswers[lIndex]).CreatedAt >=
      FTimeoutMS then
      FPendingAnswers.Delete(lIndex);
  for lIndex := FMessages.Count - 1 downto 0 do
    if ANow - TNXBotObservedMessage(FMessages[lIndex]).CreatedAt >=
      FTimeoutMS then
      FMessages.Delete(lIndex);
  for lIndex := FRooms.Count - 1 downto 0 do
  begin
    lRoom := TNXBotConversationRoom(FRooms[lIndex]);
    if (lRoom.BotNick <> '') and (ANow >= lRoom.ExpiresAt) then
    begin
      lRoom.BotNick := '';
      lRoom.SenderJID := '';
      lRoom.SenderIdentity := '';
      lRoom.ExpiresAt := 0;
    end;
  end;
end;

procedure TNXBotConversationTracker.RegisterBot(const ANick: UTF8String);
begin
  if ANick = '' then
    Exit;
  EnterCriticalSection(FCriticalSection);
  try
    FBotNicks.Add(string(ANick));
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotConversationTracker.BeginAnswer(const ARoomJID, ABotNick,
  ASenderJID, ASenderIdentity, ABody: UTF8String);
var
  lPending: TNXBotPendingAnswer;
  lRoom: TNXBotConversationRoom;
  lNow: QWord;
begin
  if (ARoomJID = '') or (ABotNick = '') or (ASenderJID = '') or
    (ABody = '') then
    Exit;
  EnterCriticalSection(FCriticalSection);
  try
    lNow := CurrentTick;
    ClearExpiredUnsafe(lNow);
    lPending := TNXBotPendingAnswer(FindPendingUnsafe(ARoomJID, ABotNick));
    if not Assigned(lPending) then
    begin
      lPending := TNXBotPendingAnswer.Create;
      FPendingAnswers.Add(lPending);
    end;
    lRoom := TNXBotConversationRoom(FindRoomUnsafe(ARoomJID));
    if not Assigned(lRoom) then
    begin
      lRoom := TNXBotConversationRoom.Create;
      lRoom.RoomJID := ARoomJID;
      FRooms.Add(lRoom);
    end;
    lPending.Body := ABody;
    lPending.BotNick := ABotNick;
    lPending.CreatedAt := lNow;
    lPending.Generation := lRoom.Generation;
    lPending.RoomJID := ARoomJID;
    lPending.SenderIdentity := ASenderIdentity;
    lPending.SenderJID := ASenderJID;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotConversationTracker.CancelAnswer(const ARoomJID,
  ABotNick: UTF8String);
var
  lPending: TObject;
begin
  EnterCriticalSection(FCriticalSection);
  try
    lPending := FindPendingUnsafe(ARoomJID, ABotNick);
    if Assigned(lPending) then
      FPendingAnswers.Remove(lPending);
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotConversationTracker.ClearBotRoom(const ARoomJID,
  ABotNick: UTF8String);
var
  lPending: TObject;
  lRoom: TNXBotConversationRoom;
begin
  EnterCriticalSection(FCriticalSection);
  try
    lPending := FindPendingUnsafe(ARoomJID, ABotNick);
    if Assigned(lPending) then
      FPendingAnswers.Remove(lPending);
    lRoom := TNXBotConversationRoom(FindRoomUnsafe(ARoomJID));
    if Assigned(lRoom) and
      SameText(string(lRoom.BotNick), string(ABotNick)) then
    begin
      lRoom.BotNick := '';
      lRoom.SenderJID := '';
      lRoom.SenderIdentity := '';
      lRoom.ExpiresAt := 0;
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TNXBotConversationTracker.Observe(const ARoomJID, ASenderJID,
  ASenderIdentity, AMessageID, ATypeValue, ABody,
  ADisplayBody: UTF8String; const AReply: TNXXMPPReplyReference;
  AContext: TNXXMPPMessageDeliveryContext; AValid: Boolean;
  out AReason: UTF8String): UTF8String;
var
  lAddressedBot: UTF8String;
  lKey: UTF8String;
  lMessage: TNXBotObservedMessage;
  lNow: QWord;
  lPending: TNXBotPendingAnswer;
  lRoom: TNXBotConversationRoom;
  lSenderNick: UTF8String;
begin
  Result := '';
  AReason := '';
  if not AValid or (AContext <> xmdcLive) or
    (ATypeValue <> 'groupchat') or (ABody = '') or
    (Copy(ASenderJID, 1, Length(ARoomJID) + 1) <> ARoomJID + '/') then
    Exit;
  lSenderNick := Copy(ASenderJID, Length(ARoomJID) + 2, MaxInt);
  EnterCriticalSection(FCriticalSection);
  try
    lNow := CurrentTick;
    ClearExpiredUnsafe(lNow);
    if AMessageID <> '' then
      lKey := ARoomJID + #0 + ASenderJID + #0 + AMessageID
    else
      lKey := '';
    if lKey <> '' then
    begin
      lMessage := TNXBotObservedMessage(FindMessageUnsafe(lKey));
      if Assigned(lMessage) then
      begin
        Result := lMessage.TargetBot;
        AReason := lMessage.Reason;
        Exit;
      end;
    end;

    lRoom := TNXBotConversationRoom(FindRoomUnsafe(ARoomJID));
    if not Assigned(lRoom) then
    begin
      lRoom := TNXBotConversationRoom.Create;
      lRoom.RoomJID := ARoomJID;
      FRooms.Add(lRoom);
    end;

    if RegisteredBotUnsafe(lSenderNick) then
    begin
      lPending := TNXBotPendingAnswer(FindPendingUnsafe(ARoomJID,
        lSenderNick));
      if Assigned(lPending) and (lPending.Body = ADisplayBody) then
      begin
        if lPending.Generation = lRoom.Generation then
        begin
          lRoom.BotNick := lPending.BotNick;
          lRoom.SenderJID := lPending.SenderJID;
          lRoom.SenderIdentity := lPending.SenderIdentity;
          lRoom.ExpiresAt := lNow + FTimeoutMS;
        end;
        FPendingAnswers.Remove(lPending);
      end
      else
      begin
        lRoom.BotNick := '';
        lRoom.SenderJID := '';
        lRoom.SenderIdentity := '';
        lRoom.ExpiresAt := 0;
      end;
    end
    else
    begin
      Inc(lRoom.Generation);
      lAddressedBot := AddressedBotUnsafe(ABody, ADisplayBody);
      if AReply.Present or HasLeadingAddress(ABody) or
        (lAddressedBot <> '') then
      begin
        lRoom.BotNick := '';
        lRoom.SenderJID := '';
        lRoom.SenderIdentity := '';
        lRoom.ExpiresAt := 0;
      end
      else if (lRoom.BotNick <> '') and
        (lRoom.SenderJID = ASenderJID) and
        ((lRoom.SenderIdentity = '') or
        ((ASenderIdentity <> '') and
        (lRoom.SenderIdentity = ASenderIdentity))) then
      begin
        Result := lRoom.BotNick;
        AReason := 'same participant immediately followed the bot answer';
      end
      else
      begin
        lRoom.BotNick := '';
        lRoom.SenderJID := '';
        lRoom.SenderIdentity := '';
        lRoom.ExpiresAt := 0;
      end;
    end;

    if lKey <> '' then
    begin
      while FMessages.Count >= cMessageCapacity do
        FMessages.Delete(0);
      lMessage := TNXBotObservedMessage.Create;
      lMessage.CreatedAt := lNow;
      lMessage.Key := lKey;
      lMessage.Reason := AReason;
      lMessage.TargetBot := Result;
      FMessages.Add(lMessage);
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

end.
