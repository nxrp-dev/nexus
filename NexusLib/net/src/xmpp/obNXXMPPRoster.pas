unit obNXXMPPRoster;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, DOM, obNXXMPPDispatcher, obNXXMPPModule,
  obNXXMPPStanza, tpNXXMPPTypes, utNXXMPPXML;

type
  TNXXMPPRosterModule = class(TNXXMPPModule)
  private
    FItems: TStringList;
    procedure HandlePush(AStanza: TNXXMPPStanza);
  public
    constructor Create;
    destructor Destroy; override;
    function Item(const AJID: UTF8String): UTF8String;
    class function RequestPayload: UTF8String; static;
    procedure RegisterHandlers(ADispatcher: TNXXMPPDispatcher); override;
  end;

implementation

constructor TNXXMPPRosterModule.Create;
begin
  inherited Create;
  FItems := TStringList.Create;
  FItems.CaseSensitive := True;
  FItems.NameValueSeparator := '=';
end;

destructor TNXXMPPRosterModule.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

class function TNXXMPPRosterModule.RequestPayload: UTF8String;
begin
  Result := '<query xmlns=''jabber:iq:roster''/>';
end;

procedure TNXXMPPRosterModule.RegisterHandlers(
  ADispatcher: TNXXMPPDispatcher);
begin
  ADispatcher.RegisterIQResponder(xitSet, 'jabber:iq:roster', 'query',
    @HandlePush);
end;

procedure TNXXMPPRosterModule.HandlePush(AStanza: TNXXMPPStanza);
var
  lItem: TDOMElement;
  lJID: UTF8String;
begin
  lItem := TDOMElement(AStanza.Root.FindNode('query'));
  if Assigned(lItem) then
    lItem := TDOMElement(lItem.FindNode('item'));
  if Assigned(lItem) then
  begin
    lJID := UTF8Encode(lItem.GetAttribute('jid'));
    if UTF8Encode(lItem.GetAttribute('subscription')) = 'remove' then
      FItems.Values[string(lJID)] := ''
    else
      FItems.Values[string(lJID)] := string(UTF8Encode(
        lItem.GetAttribute('name')));
  end;
  Send('<iq type=''result'' id=''' + NXXMPPEscapeAttribute(AStanza.ID) +
    '''/>');
end;

function TNXXMPPRosterModule.Item(const AJID: UTF8String): UTF8String;
begin
  Result := UTF8String(FItems.Values[string(AJID)]);
end;

end.
