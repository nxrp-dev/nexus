unit obNXXMPPDisco;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPDispatcher, obNXXMPPModule, obNXXMPPStanza,
  tpNXXMPPTypes, utNXXMPPXML;

type
  TNXXMPPDiscoModule = class(TNXXMPPModule)
  private
    FCategory: UTF8String;
    FFeatures: TStringList;
    FIdentityName: UTF8String;
    FIdentityType: UTF8String;
    procedure HandleInfo(AStanza: TNXXMPPStanza);
  public
    constructor Create(const ACategory, AType, AName: UTF8String);
    destructor Destroy; override;
    procedure AddFeature(const AFeature: UTF8String);
    procedure RegisterHandlers(ADispatcher: TNXXMPPDispatcher); override;
  end;

implementation

constructor TNXXMPPDiscoModule.Create(const ACategory, AType,
  AName: UTF8String);
begin
  inherited Create;
  FCategory := ACategory;
  FIdentityType := AType;
  FIdentityName := AName;
  FFeatures := TStringList.Create;
  FFeatures.Sorted := True;
  FFeatures.Duplicates := dupIgnore;
end;

destructor TNXXMPPDiscoModule.Destroy;
begin
  FFeatures.Free;
  inherited Destroy;
end;

procedure TNXXMPPDiscoModule.AddFeature(const AFeature: UTF8String);
begin
  if AFeature <> '' then
    FFeatures.Add(string(AFeature));
end;

procedure TNXXMPPDiscoModule.RegisterHandlers(
  ADispatcher: TNXXMPPDispatcher);
begin
  ADispatcher.RegisterIQResponder(xitGet,
    'http://jabber.org/protocol/disco#info', 'query', @HandleInfo);
end;

procedure TNXXMPPDiscoModule.HandleInfo(AStanza: TNXXMPPStanza);
var
  lIndex: Integer;
  lResult: UTF8String;
begin
  lResult := '<iq type=''result'' id=''' + NXXMPPEscapeAttribute(AStanza.ID) +
    '''';
  if AStanza.FromJID <> '' then
    lResult := lResult + ' to=''' +
      NXXMPPEscapeAttribute(AStanza.FromJID) + '''';
  lResult := lResult + '><query xmlns=' +
    '''http://jabber.org/protocol/disco#info''><identity category=''' +
    NXXMPPEscapeAttribute(FCategory) + ''' type=''' +
    NXXMPPEscapeAttribute(FIdentityType) + ''' name=''' +
    NXXMPPEscapeAttribute(FIdentityName) + '''/>';
  for lIndex := 0 to FFeatures.Count - 1 do
    lResult := lResult + '<feature var=''' +
      NXXMPPEscapeAttribute(UTF8String(FFeatures[lIndex])) + '''/>';
  Send(lResult + '</query></iq>');
end;

end.
