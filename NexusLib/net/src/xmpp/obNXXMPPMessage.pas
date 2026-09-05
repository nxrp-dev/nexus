unit obNXXMPPMessage;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, DOM, obNXXMPPStanza, tpNXXMPPMessageTypes,
  tpNXXMPPTypes, utNXXMPPDateTime, utNXXMPPDOM;

type
  TNXXMPPMessage = class
  private
    FBody: UTF8String;
    FChatState: TNXXMPPChatState;
    FContext: TNXXMPPMessageDeliveryContext;
    FDelay: TNXXMPPDelay;
    FDisplayBody: UTF8String;
    FFromJID: UTF8String;
    FID: UTF8String;
    FOriginID: UTF8String;
    FRawXML: UTF8String;
    FReceiptID: UTF8String;
    FReceiptKind: TNXXMPPReceiptKind;
    FReply: TNXXMPPReplyReference;
    FStanzaIDs: TNXXMPPStanzaIDArray;
    FSubject: UTF8String;
    FToJID: UTF8String;
    FTypeValue: UTF8String;
    FValid: Boolean;
    FValidationError: UTF8String;
    procedure Invalidate(const AReason: UTF8String);
    procedure Parse(AStanza: TNXXMPPStanza);
  public
    constructor Create(AStanza: TNXXMPPStanza;
      AContext: TNXXMPPMessageDeliveryContext = xmdcLive);
    function StanzaIDFor(const AByJID: UTF8String;
      out AID: UTF8String): Boolean;
    property Body: UTF8String read FBody;
    property ChatState: TNXXMPPChatState read FChatState;
    property Context: TNXXMPPMessageDeliveryContext read FContext;
    property Delay: TNXXMPPDelay read FDelay;
    property DisplayBody: UTF8String read FDisplayBody;
    property FromJID: UTF8String read FFromJID;
    property ID: UTF8String read FID;
    property OriginID: UTF8String read FOriginID;
    property RawXML: UTF8String read FRawXML;
    property ReceiptID: UTF8String read FReceiptID;
    property ReceiptKind: TNXXMPPReceiptKind read FReceiptKind;
    property Reply: TNXXMPPReplyReference read FReply;
    property StanzaIDs: TNXXMPPStanzaIDArray read FStanzaIDs;
    property Subject: UTF8String read FSubject;
    property ToJID: UTF8String read FToJID;
    property TypeValue: UTF8String read FTypeValue;
    property Valid: Boolean read FValid;
    property ValidationError: UTF8String read FValidationError;
  end;

implementation

function NXXMPPUTF8Offset(const AValue: UTF8String; ACharacterIndex: Integer;
  out AByteOffset: Integer): Boolean;
var
  lCharacter: Integer;
  lLength: Integer;
begin
  Result := False;
  AByteOffset := 1;
  if ACharacterIndex < 0 then
    Exit;
  lCharacter := 0;
  while (AByteOffset <= Length(AValue)) and
    (lCharacter < ACharacterIndex) do
  begin
    if Byte(AValue[AByteOffset]) < $80 then
      lLength := 1
    else if (Byte(AValue[AByteOffset]) and $E0) = $C0 then
      lLength := 2
    else if (Byte(AValue[AByteOffset]) and $F0) = $E0 then
      lLength := 3
    else if (Byte(AValue[AByteOffset]) and $F8) = $F0 then
      lLength := 4
    else
      Exit;
    Inc(AByteOffset, lLength);
    Inc(lCharacter);
  end;
  Result := lCharacter = ACharacterIndex;
end;

constructor TNXXMPPMessage.Create(AStanza: TNXXMPPStanza;
  AContext: TNXXMPPMessageDeliveryContext);
begin
  inherited Create;
  FContext := AContext;
  FValid := True;
  Parse(AStanza);
end;

procedure TNXXMPPMessage.Invalidate(const AReason: UTF8String);
begin
  FValid := False;
  if FValidationError = '' then
    FValidationError := AReason;
end;

procedure TNXXMPPMessage.Parse(AStanza: TNXXMPPStanza);
var
  lChild: TDOMElement;
  lID: TNXXMPPStanzaID;
  lLocalName: UTF8String;
  lNamespace: UTF8String;
  lState: TNXXMPPChatState;
  lIndex: Integer;
  lFallbackEnd: Integer;
  lFallbackStart: Integer;
  lRange: TDOMElement;
  lStartByte: Integer;
  lEndByte: Integer;
begin
  if not Assigned(AStanza) or (AStanza.Kind <> xskMessage) then
  begin
    Invalidate('The retained stanza is not a message.');
    Exit;
  end;
  FRawXML := AStanza.RawXML;
  FFromJID := AStanza.FromJID;
  FToJID := AStanza.ToJID;
  FID := AStanza.ID;
  FTypeValue := AStanza.TypeValue;
  lFallbackStart := -1;
  lFallbackEnd := -1;
  lChild := NXXMPPFirstChildElement(AStanza.Root);
  while Assigned(lChild) do
  begin
    lLocalName := NXXMPPElementLocalName(lChild);
    lNamespace := NXXMPPElementNamespaceURI(lChild);
    if (lNamespace = 'jabber:client') and (lLocalName = 'body') then
    begin
      if FBody = '' then
        FBody := NXXMPPDirectText(lChild);
    end
    else if (lNamespace = 'jabber:client') and (lLocalName = 'subject') then
    begin
      if FSubject = '' then
        FSubject := NXXMPPDirectText(lChild);
    end
    else if (lNamespace = 'urn:xmpp:sid:0') and
      (lLocalName = 'origin-id') then
    begin
      if FOriginID <> '' then
        Invalidate('The message contains more than one origin-id.')
      else
        FOriginID := UTF8Encode(lChild.GetAttribute('id'));
      if FOriginID = '' then
        Invalidate('The message origin-id is empty.');
    end
    else if (lNamespace = 'urn:xmpp:sid:0') and
      (lLocalName = 'stanza-id') then
    begin
      lID.ByJID := UTF8Encode(lChild.GetAttribute('by'));
      lID.ID := UTF8Encode(lChild.GetAttribute('id'));
      if (lID.ByJID = '') or (lID.ID = '') then
        Invalidate('A stanza-id requires both by and id.')
      else
      begin
        for lIndex := 0 to High(FStanzaIDs) do
          if FStanzaIDs[lIndex].ByJID = lID.ByJID then
            Invalidate('A stanza-id issuer occurs more than once.');
        SetLength(FStanzaIDs, Length(FStanzaIDs) + 1);
        FStanzaIDs[High(FStanzaIDs)] := lID;
      end;
    end
    else if (lNamespace = 'urn:xmpp:reply:0') and
      (lLocalName = 'reply') then
    begin
      if FReply.Present then
        Invalidate('The message contains more than one reply element.')
      else
      begin
        FReply.Present := True;
        FReply.ToJID := UTF8Encode(lChild.GetAttribute('to'));
        FReply.ID := UTF8Encode(lChild.GetAttribute('id'));
        if FReply.ID = '' then
          Invalidate('A reply reference requires an id.');
      end;
    end
    else if (lNamespace = 'urn:xmpp:receipts') and
      (lLocalName = 'request') then
    begin
      if FReceiptKind <> xrkNone then
        Invalidate('The message contains conflicting receipt elements.')
      else
        FReceiptKind := xrkRequest;
    end
    else if (lNamespace = 'urn:xmpp:receipts') and
      (lLocalName = 'received') then
    begin
      if FReceiptKind <> xrkNone then
        Invalidate('The message contains conflicting receipt elements.')
      else
      begin
        FReceiptKind := xrkReceived;
        FReceiptID := UTF8Encode(lChild.GetAttribute('id'));
        if FReceiptID = '' then
          Invalidate('A delivery receipt requires an id.');
      end;
    end
    else if lNamespace = 'http://jabber.org/protocol/chatstates' then
    begin
      lState := NXXMPPChatStateFromName(lLocalName);
      if lState <> xcsNone then
      begin
        if FChatState <> xcsNone then
          Invalidate('The message contains more than one chat state.')
        else
          FChatState := lState;
      end;
    end
    else if (lNamespace = 'urn:xmpp:delay') and
      (lLocalName = 'delay') then
    begin
      if FDelay.Present then
        Invalidate('The message contains more than one delay element.')
      else
      begin
        FDelay.Present := True;
        FDelay.FromJID := UTF8Encode(lChild.GetAttribute('from'));
        FDelay.Stamp := UTF8Encode(lChild.GetAttribute('stamp'));
        FDelay.Valid := NXXMPPTryParseTimestamp(FDelay.Stamp,
          FDelay.Timestamp);
        if not FDelay.Valid then
          Invalidate('The message delay timestamp is invalid.');
        FDelay.Reason := NXXMPPDirectText(lChild);
      end;
    end
    else if (lNamespace = 'urn:xmpp:fallback:0') and
      (lLocalName = 'fallback') and
      (UTF8Encode(lChild.GetAttribute('for')) = 'urn:xmpp:reply:0') then
    begin
      if lFallbackStart >= 0 then
        Invalidate('The message contains more than one reply fallback.')
      else
      begin
        lRange := NXXMPPFindChild(lChild, 'urn:xmpp:fallback:0', 'body');
        if not Assigned(lRange) or
          not TryStrToInt(string(UTF8Encode(lRange.GetAttribute('start'))),
            lFallbackStart) or
          not TryStrToInt(string(UTF8Encode(lRange.GetAttribute('end'))),
            lFallbackEnd) or (lFallbackStart < 0) or
          (lFallbackEnd < lFallbackStart) then
          Invalidate('The reply fallback body range is invalid.');
      end;
    end;
    lChild := NXXMPPNextSiblingElement(lChild);
  end;
  FDisplayBody := FBody;
  if lFallbackStart >= 0 then
  begin
    if not NXXMPPUTF8Offset(FBody, lFallbackStart, lStartByte) or
      not NXXMPPUTF8Offset(FBody, lFallbackEnd, lEndByte) then
      Invalidate('The reply fallback body range exceeds the body.')
    else
      Delete(FDisplayBody, lStartByte, lEndByte - lStartByte);
  end;
end;

function TNXXMPPMessage.StanzaIDFor(const AByJID: UTF8String;
  out AID: UTF8String): Boolean;
var
  lIndex: Integer;
begin
  AID := '';
  for lIndex := 0 to High(FStanzaIDs) do
    if FStanzaIDs[lIndex].ByJID = AByJID then
    begin
      AID := FStanzaIDs[lIndex].ID;
      Exit(True);
    end;
  Result := False;
end;

end.
