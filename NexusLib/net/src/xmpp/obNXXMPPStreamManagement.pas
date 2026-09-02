unit obNXXMPPStreamManagement;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPError, tpNXXMPPTypes;

type
  TNXXMPPStreamManagement = class
  private
    FEnabled: Boolean;
    FHandledIncoming: Cardinal;
    FHandledOutgoing: Cardinal;
    FLastAcknowledged: Cardinal;
    FReplay: TStringList;
    FReplayCapacity: Integer;
    FResumeID: UTF8String;
  public
    constructor Create(AReplayCapacity: Integer);
    destructor Destroy; override;
    procedure Acknowledge(AHandled: Cardinal);
    function AcknowledgementXML: UTF8String;
    procedure Enable(const AResumeID: UTF8String);
    procedure IncomingHandled;
    procedure OutgoingSent(const AXML: UTF8String; AReplayable: Boolean);
    function ReplayCount: Integer;
    function ReplayXML(AIndex: Integer): UTF8String;
    function RequestAcknowledgementXML: UTF8String;
    procedure Reset;
    property Enabled: Boolean read FEnabled;
    property HandledIncoming: Cardinal read FHandledIncoming;
    property HandledOutgoing: Cardinal read FHandledOutgoing;
    property ResumeID: UTF8String read FResumeID;
  end;

implementation

constructor TNXXMPPStreamManagement.Create(AReplayCapacity: Integer);
begin
  inherited Create;
  if AReplayCapacity < 1 then
    raise ENXXMPPError.Create(xesConfiguration, 'invalid-replay-capacity',
      'The stream-management replay capacity must be positive.');
  FReplayCapacity := AReplayCapacity;
  FReplay := TStringList.Create;
  FReplay.NameValueSeparator := '=';
end;

destructor TNXXMPPStreamManagement.Destroy;
begin
  FReplay.Free;
  inherited Destroy;
end;

procedure TNXXMPPStreamManagement.Reset;
begin
  FEnabled := False;
  FHandledIncoming := 0;
  FHandledOutgoing := 0;
  FLastAcknowledged := 0;
  FReplay.Clear;
  FResumeID := '';
end;

procedure TNXXMPPStreamManagement.Enable(const AResumeID: UTF8String);
begin
  FEnabled := True;
  FResumeID := AResumeID;
end;

procedure TNXXMPPStreamManagement.IncomingHandled;
begin
  if FEnabled then
    Inc(FHandledIncoming);
end;

procedure TNXXMPPStreamManagement.OutgoingSent(const AXML: UTF8String;
  AReplayable: Boolean);
begin
  if not FEnabled then
    Exit;
  Inc(FHandledOutgoing);
  if not AReplayable then
    Exit;
  if FReplay.Count >= FReplayCapacity then
    raise ENXXMPPError.Create(xesProtocol, 'replay-queue-full',
      'The stream-management replay queue is full.');
  FReplay.Add(UIntToStr(FHandledOutgoing) + '=' + string(AXML));
end;

procedure TNXXMPPStreamManagement.Acknowledge(AHandled: Cardinal);
var
  lSequence: QWord;
begin
  if not FEnabled or (AHandled < FLastAcknowledged) or
    (AHandled > FHandledOutgoing) then
    raise ENXXMPPError.Create(xesProtocol, 'invalid-sm-acknowledgement',
      'The stream-management acknowledgement is outside the sent range.');
  FLastAcknowledged := AHandled;
  while FReplay.Count > 0 do
  begin
    if not TryStrToQWord(FReplay.Names[0], lSequence) or
      (lSequence > AHandled) then
      Break;
    FReplay.Delete(0);
  end;
end;

function TNXXMPPStreamManagement.AcknowledgementXML: UTF8String;
begin
  Result := '<a xmlns=''urn:xmpp:sm:3'' h=''' +
    UTF8String(UIntToStr(FHandledIncoming)) + '''/>';
end;

function TNXXMPPStreamManagement.RequestAcknowledgementXML: UTF8String;
begin
  Result := '<r xmlns=''urn:xmpp:sm:3''/>';
end;

function TNXXMPPStreamManagement.ReplayCount: Integer;
begin
  Result := FReplay.Count;
end;

function TNXXMPPStreamManagement.ReplayXML(AIndex: Integer): UTF8String;
begin
  Result := UTF8String(FReplay.ValueFromIndex[AIndex]);
end;

end.
