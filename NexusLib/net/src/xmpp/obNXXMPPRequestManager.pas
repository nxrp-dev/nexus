unit obNXXMPPRequestManager;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Contnrs, obNXXMPPError, obNXXMPPStanza,
  tpNXXMPPTypes;

type
  TNXXMPPIQCompletionHandler = procedure(AStanza: TNXXMPPStanza;
    const AError: UTF8String) of object;

  TNXXMPPIQCompletionEvent = class
  private
    FError: UTF8String;
    FHandler: TNXXMPPIQCompletionHandler;
    FStanza: TNXXMPPStanza;
  public
    constructor Create(AHandler: TNXXMPPIQCompletionHandler;
      AStanza: TNXXMPPStanza; const AError: UTF8String);
    destructor Destroy; override;
    procedure Invoke;
    property Error: UTF8String read FError;
    property Stanza: TNXXMPPStanza read FStanza;
  end;

  TNXXMPPRequestManager = class
  private
    FCapacity: Integer;
    FNextID: QWord;
    FPending: TObjectList;
  public
    constructor Create(ACapacity: Integer = cNXXMPPDefaultPendingIQCapacity);
    destructor Destroy; override;
    function BeginRequest(const AExpectedFrom: UTF8String; ATimeoutMS: Cardinal;
      AHandler: TNXXMPPIQCompletionHandler): UTF8String;
    function Complete(AStanza: TNXXMPPStanza): TNXXMPPIQCompletionEvent;
    procedure CollectTimeouts(ANow: QWord; AEvents: TObjectList);
    procedure CancelAll(const AReason: UTF8String; AEvents: TObjectList);
    function Count: Integer;
    property Capacity: Integer read FCapacity;
  end;

implementation

type
  TNXXMPPPendingIQ = class
  public
    Deadline: QWord;
    ExpectedFrom: UTF8String;
    Handler: TNXXMPPIQCompletionHandler;
    ID: UTF8String;
  end;

constructor TNXXMPPIQCompletionEvent.Create(
  AHandler: TNXXMPPIQCompletionHandler; AStanza: TNXXMPPStanza;
  const AError: UTF8String);
begin
  inherited Create;
  FHandler := AHandler;
  FStanza := AStanza;
  FError := AError;
end;

destructor TNXXMPPIQCompletionEvent.Destroy;
begin
  FStanza.Free;
  inherited Destroy;
end;

procedure TNXXMPPIQCompletionEvent.Invoke;
begin
  if Assigned(FHandler) then
    FHandler(FStanza, FError);
end;

constructor TNXXMPPRequestManager.Create(ACapacity: Integer);
begin
  inherited Create;
  if ACapacity < 1 then
    raise ENXXMPPError.Create(xesConfiguration, 'invalid-iq-capacity',
      'The pending IQ capacity must be positive.');
  FCapacity := ACapacity;
  FPending := TObjectList.Create(True);
end;

destructor TNXXMPPRequestManager.Destroy;
begin
  FPending.Free;
  inherited Destroy;
end;

function TNXXMPPRequestManager.BeginRequest(const AExpectedFrom: UTF8String;
  ATimeoutMS: Cardinal; AHandler: TNXXMPPIQCompletionHandler): UTF8String;
var
  lPending: TNXXMPPPendingIQ;
begin
  if FPending.Count >= FCapacity then
    raise ENXXMPPError.Create(xesProtocol, 'pending-iq-full',
      'The pending IQ request limit has been reached.', True);
  Inc(FNextID);
  Result := UTF8String('nx-' + IntToStr(FNextID));
  lPending := TNXXMPPPendingIQ.Create;
  lPending.ID := Result;
  lPending.ExpectedFrom := AExpectedFrom;
  lPending.Deadline := GetTickCount64 + ATimeoutMS;
  lPending.Handler := AHandler;
  FPending.Add(lPending);
end;

function TNXXMPPRequestManager.Complete(
  AStanza: TNXXMPPStanza): TNXXMPPIQCompletionEvent;
var
  lIndex: Integer;
  lPending: TNXXMPPPendingIQ;
begin
  Result := nil;
  if not Assigned(AStanza) or (AStanza.Kind <> xskIQ) or
    not (AStanza.IQType in [xitResult, xitError]) then
    Exit;
  for lIndex := 0 to FPending.Count - 1 do
  begin
    lPending := TNXXMPPPendingIQ(FPending[lIndex]);
    if lPending.ID <> AStanza.ID then
      Continue;
    if (lPending.ExpectedFrom <> '') and
      (lPending.ExpectedFrom <> AStanza.FromJID) then
      Exit;
    FPending.Extract(lPending);
    Result := TNXXMPPIQCompletionEvent.Create(lPending.Handler, AStanza, '');
    lPending.Free;
    Exit;
  end;
end;

procedure TNXXMPPRequestManager.CollectTimeouts(ANow: QWord;
  AEvents: TObjectList);
var
  lIndex: Integer;
  lPending: TNXXMPPPendingIQ;
begin
  if not Assigned(AEvents) then
    Exit;
  lIndex := FPending.Count - 1;
  while lIndex >= 0 do
  begin
    lPending := TNXXMPPPendingIQ(FPending[lIndex]);
    if ANow >= lPending.Deadline then
    begin
      FPending.Extract(lPending);
      AEvents.Add(TNXXMPPIQCompletionEvent.Create(lPending.Handler, nil,
        'IQ request timed out.'));
      lPending.Free;
    end;
    Dec(lIndex);
  end;
end;

procedure TNXXMPPRequestManager.CancelAll(const AReason: UTF8String;
  AEvents: TObjectList);
var
  lPending: TNXXMPPPendingIQ;
begin
  while FPending.Count > 0 do
  begin
    lPending := TNXXMPPPendingIQ(FPending.Extract(FPending[0]));
    if Assigned(AEvents) then
      AEvents.Add(TNXXMPPIQCompletionEvent.Create(lPending.Handler, nil,
        AReason));
    lPending.Free;
  end;
end;

function TNXXMPPRequestManager.Count: Integer;
begin
  Result := FPending.Count;
end;

end.
