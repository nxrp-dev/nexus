unit obNXBotHostRouter;

{$mode objfpc}{$H+}

interface

uses
  tpNXBotHost,
  tpNXXMPPMessageTypes;

type
  TNXBotRouteDecision = (
    brdAccepted,
    brdInvalid,
    brdNotLive,
    brdNotGroupChat,
    brdSelf,
    brdNotAddressed,
    brdEmpty,
    brdTooLarge
  );

  TNXBotHostRouter = class
  public
    class function Admit(const ASequence: QWord; const ARoomJID, ANick,
      ASenderJID, AMessageID, ATypeValue, ABody, ADisplayBody: UTF8String;
      const AReply: TNXXMPPReplyReference;
      AContext: TNXXMPPMessageDeliveryContext; AValid: Boolean;
      AMaximumBytes: Integer; out APrompt: TNXBotPrompt): TNXBotRouteDecision;
  end;

function NXBotRouteDecisionName(ADecision: TNXBotRouteDecision): UTF8String;

implementation

uses
  SysUtils;

function NXBotHostIsNameCharacter(const ACharacter: AnsiChar): Boolean;
begin
  Result := (ACharacter in ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function NXBotHostFindAddress(const ABody, ANick: UTF8String;
  out APosition, ALength: Integer): Boolean;
var
  lAfter: Integer;
  lPosition: Integer;
begin
  Result := False;
  APosition := 0;
  ALength := 0;
  if ANick = '' then
    Exit;

  for lPosition := 1 to Length(ABody) - Length(ANick) do
  begin
    if (lPosition > 1) and
      NXBotHostIsNameCharacter(ABody[lPosition - 1]) then
      Continue;
    if not SameText(Copy(ABody, lPosition, Length(ANick)), ANick) then
      Continue;

    lAfter := lPosition + Length(ANick);
    if (lAfter > Length(ABody)) or (ABody[lAfter] <> ',') then
      Continue;
    Inc(lAfter);
    if (lAfter > Length(ABody)) or
      not (ABody[lAfter] in [#9, #10, #13, ' ']) then
      Continue;
    while (lAfter <= Length(ABody)) and
      (ABody[lAfter] in [#9, #10, #13, ' ']) do
      Inc(lAfter);

    APosition := lPosition;
    ALength := lAfter - lPosition;
    Exit(True);
  end;
end;

function NXBotRouteDecisionName(ADecision: TNXBotRouteDecision): UTF8String;
begin
  case ADecision of
    brdAccepted: Result := 'accepted';
    brdInvalid: Result := 'invalid message';
    brdNotLive: Result := 'history or archived message';
    brdNotGroupChat: Result := 'not a groupchat message';
    brdSelf: Result := 'self message';
    brdNotAddressed: Result := 'not addressed to the bot';
    brdEmpty: Result := 'empty prompt';
    brdTooLarge: Result := 'prompt exceeds configured byte limit';
  end;
end;

class function TNXBotHostRouter.Admit(const ASequence: QWord;
  const ARoomJID, ANick, ASenderJID, AMessageID, ATypeValue,
  ABody, ADisplayBody: UTF8String; const AReply: TNXXMPPReplyReference;
  AContext: TNXXMPPMessageDeliveryContext; AValid: Boolean;
  AMaximumBytes: Integer;
  out APrompt: TNXBotPrompt): TNXBotRouteDecision;
var
  lAddressLength: Integer;
  lAddressPosition: Integer;
  lPrefix: UTF8String;
  lPrompt: UTF8String;
  lPosition: Integer;
begin
  APrompt := nil;
  if not AValid then
    Exit(brdInvalid);
  if AContext <> xmdcLive then
    Exit(brdNotLive);
  if ATypeValue <> 'groupchat' then
    Exit(brdNotGroupChat);
  if (ASenderJID = ARoomJID + '/' + ANick) then
    Exit(brdSelf);
  if ABody = '' then
    Exit(brdEmpty);

  lPrefix := '@' + ANick;
  lPosition := Length(lPrefix) + 1;
  if SameText(Copy(ABody, 1, Length(lPrefix)), lPrefix) and
    ((lPosition > Length(ABody)) or
    (ABody[lPosition] in [#9, #10, #13, ' '])) then
  begin
    while (lPosition <= Length(ABody)) and
      (ABody[lPosition] in [#9, #10, #13, ' ']) do
      Inc(lPosition);
    lPrompt := Copy(ABody, lPosition, MaxInt);
  end
  else if NXBotHostFindAddress(ADisplayBody, ANick, lAddressPosition,
    lAddressLength) then
    lPrompt := Copy(ADisplayBody, 1, lAddressPosition - 1) +
      Copy(ADisplayBody, lAddressPosition + lAddressLength, MaxInt)
  else if AReply.Present and
    (AReply.ToJID = ARoomJID + '/' + ANick) then
    lPrompt := ADisplayBody
  else
    Exit(brdNotAddressed);
  if lPrompt = '' then
    Exit(brdEmpty);
  if (AMaximumBytes < 1) or (Length(lPrompt) > AMaximumBytes) then
    Exit(brdTooLarge);

  APrompt := TNXBotPrompt.Create(ASequence, ARoomJID, ASenderJID,
    AMessageID, lPrompt);
  Result := brdAccepted;
end;

end.
