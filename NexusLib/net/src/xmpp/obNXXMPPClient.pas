unit obNXXMPPClient;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Contnrs,
  obNXXMPPCommand, obNXXMPPConfig, obNXXMPPConnection,
  obNXXMPPDispatcher, obNXXMPPError, obNXXMPPEvents, obNXXMPPModule,
  obNXXMPPQueue, obNXXMPPRequestManager, obNXXMPPStanza,
  obNXXMPPRoster,
  tpNXXMPPTypes, utNXXMPPXML;

type
  TNXXMPPStateEvent = procedure(ASender: TObject;
    AState: TNXXMPPConnectionState) of object;
  TNXXMPPStanzaEvent = procedure(ASender: TObject;
    AStanza: TNXXMPPStanza) of object;
  TNXXMPPErrorEvent = procedure(ASender: TObject; AStage: TNXXMPPErrorStage;
    const ACondition, AMessage: UTF8String) of object;

  TNXXMPPClient = class
  private
    FCommands: TNXXMPPObjectQueue;
    FConfig: TNXXMPPClientConfig;
    FConnection: TNXXMPPConnection;
    FDispatcher: TNXXMPPDispatcher;
    FEvents: TNXXMPPObjectQueue;
    FIQCapacity: TNXXMPPIQCapacity;
    FModules: TObjectList;
    FModulesFrozen: Boolean;
    FOnError: TNXXMPPErrorEvent;
    FOnStanza: TNXXMPPStanzaEvent;
    FOnState: TNXXMPPStateEvent;
    FState: TNXXMPPConnectionState;
    function EnqueueCommand(ACommand: TNXXMPPCommand): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddModule(AModule: TNXXMPPModule);
    procedure Connect;
    procedure Disconnect;
    function PumpEvents(AMaxCount: Integer = 100): Integer;
    function SendIQ(AType: TNXXMPPIQType; const AToJID, AExpectedFrom,
      APayload: UTF8String; AHandler: TNXXMPPIQCompletionHandler;
      ATimeoutMS: Cardinal = cNXXMPPDefaultTimeoutMS): Boolean;
    function SendMessage(const AToJID, ABody: UTF8String): Boolean;
    function RequestRoster(ARoster: TNXXMPPRosterModule;
      ATimeoutMS: Cardinal = cNXXMPPDefaultTimeoutMS): Boolean;
    function SendPresence(const AType: UTF8String = ''): Boolean;
    function SendRaw(const AXML: UTF8String): Boolean;
    function State: TNXXMPPConnectionState;
    property Config: TNXXMPPClientConfig read FConfig;
    property OnError: TNXXMPPErrorEvent read FOnError write FOnError;
    property OnStanza: TNXXMPPStanzaEvent read FOnStanza write FOnStanza;
    property OnState: TNXXMPPStateEvent read FOnState write FOnState;
  end;

implementation

constructor TNXXMPPClient.Create;
begin
  inherited Create;
  FConfig := TNXXMPPClientConfig.Create;
  FModules := TObjectList.Create(True);
  FState := xcsDisconnected;
end;

destructor TNXXMPPClient.Destroy;
begin
  Disconnect;
  FEvents.Free;
  FIQCapacity.Free;
  FCommands.Free;
  FDispatcher.Free;
  FModules.Free;
  FConfig.Free;
  inherited Destroy;
end;

procedure TNXXMPPClient.AddModule(AModule: TNXXMPPModule);
begin
  if not Assigned(AModule) then
    raise ENXXMPPError.Create(xesConfiguration, 'missing-module',
      'An XMPP module is required.');
  if FModulesFrozen then
    raise ENXXMPPError.Create(xesConfiguration, 'modules-frozen',
      'XMPP modules cannot change while connected.');
  FModules.Add(AModule);
end;

procedure TNXXMPPClient.Connect;
var
  lIndex: Integer;
begin
  if Assigned(FConnection) then
    raise ENXXMPPError.Create(xesConfiguration, 'already-connected',
      'The XMPP client already has an active connection.');
  FConfig.Validate;
  FreeAndNil(FEvents);
  FreeAndNil(FCommands);
  FreeAndNil(FDispatcher);
  FreeAndNil(FIQCapacity);
  FEvents := TNXXMPPObjectQueue.Create(FConfig.EventCapacity);
  FCommands := TNXXMPPObjectQueue.Create(FConfig.CommandCapacity);
  FDispatcher := TNXXMPPDispatcher.Create;
  FIQCapacity := TNXXMPPIQCapacity.Create(FConfig.PendingIQCapacity);
  for lIndex := 0 to FModules.Count - 1 do
    TNXXMPPModule(FModules[lIndex]).RegisterHandlers(FDispatcher);
  FModulesFrozen := True;
  FConnection := TNXXMPPConnection.Create(FConfig.Clone, FCommands,
    FEvents, FDispatcher, FIQCapacity);
  for lIndex := 0 to FModules.Count - 1 do
    TNXXMPPModule(FModules[lIndex]).Sender := @FConnection.SendModuleXML;
  FConnection.Start;
end;

procedure TNXXMPPClient.Disconnect;
var
  lIndex: Integer;
begin
  if not Assigned(FConnection) then
    Exit;
  FConnection.RequestDisconnect;
  FConnection.WaitFor;
  FState := FConnection.State;
  FreeAndNil(FConnection);
  for lIndex := 0 to FModules.Count - 1 do
    TNXXMPPModule(FModules[lIndex]).Sender := nil;
  if FState <> xcsFailed then
    FState := xcsDisconnected;
  FModulesFrozen := False;
end;

function TNXXMPPClient.EnqueueCommand(ACommand: TNXXMPPCommand): Boolean;
begin
  Result := Assigned(FConnection) and FCommands.Enqueue(ACommand);
  if not Result then
    ACommand.Free;
end;

function TNXXMPPClient.SendRaw(const AXML: UTF8String): Boolean;
begin
  if AXML = '' then
    Exit(False);
  Result := EnqueueCommand(TNXXMPPCommand.CreateRaw(AXML));
end;

function TNXXMPPClient.SendMessage(const AToJID,
  ABody: UTF8String): Boolean;
begin
  if (AToJID = '') or (ABody = '') then
    Exit(False);
  Result := SendRaw('<message to=''' + NXXMPPEscapeAttribute(AToJID) +
    ''' type=''chat''><body>' + NXXMPPEscapeText(ABody) +
    '</body></message>');
end;

function TNXXMPPClient.RequestRoster(ARoster: TNXXMPPRosterModule;
  ATimeoutMS: Cardinal): Boolean;
begin
  if not Assigned(ARoster) or (FModules.IndexOf(ARoster) < 0) then
    Exit(False);
  Result := SendIQ(xitGet, '', '', TNXXMPPRosterModule.RequestPayload,
    @ARoster.CompleteRequest, ATimeoutMS);
end;

function TNXXMPPClient.SendPresence(const AType: UTF8String): Boolean;
begin
  if AType = '' then
    Result := SendRaw('<presence/>')
  else
    Result := SendRaw('<presence type=''' +
      NXXMPPEscapeAttribute(AType) + '''/>');
end;

function TNXXMPPClient.SendIQ(AType: TNXXMPPIQType; const AToJID,
  AExpectedFrom, APayload: UTF8String; AHandler: TNXXMPPIQCompletionHandler;
  ATimeoutMS: Cardinal): Boolean;
begin
  if not (AType in [xitGet, xitSet]) or (APayload = '') then
    Exit(False);
  if not Assigned(FIQCapacity) or not FIQCapacity.TryReserve then
    Exit(False);
  Result := EnqueueCommand(TNXXMPPCommand.CreateIQ(AType, AToJID,
    AExpectedFrom, APayload, ATimeoutMS, AHandler));
  if not Result then
    FIQCapacity.Release;
end;

function TNXXMPPClient.PumpEvents(AMaxCount: Integer): Integer;
var
  lEvent: TNXXMPPEvent;
  lIndex: Integer;
begin
  Result := 0;
  if (AMaxCount < 1) or not Assigned(FEvents) then
    Exit;
  while Result < AMaxCount do
  begin
    lEvent := TNXXMPPEvent(FEvents.Dequeue);
    if not Assigned(lEvent) then
      Exit;
    try
      case lEvent.Kind of
        xekState:
          begin
            FState := lEvent.State;
            if Assigned(FOnState) then
              FOnState(Self, lEvent.State);
          end;
        xekStanza:
          begin
            for lIndex := 0 to FModules.Count - 1 do
              TNXXMPPModule(FModules[lIndex]).PumpStanza(lEvent.Stanza);
            if Assigned(FOnStanza) then
              FOnStanza(Self, lEvent.Stanza);
          end;
        xekError:
          if Assigned(FOnError) then
            FOnError(Self, lEvent.ErrorStage, lEvent.Condition,
              lEvent.ErrorMessage);
        xekIQCompletion:
          lEvent.Completion.Invoke;
      end;
    finally
      lEvent.Free;
    end;
    Inc(Result);
  end;
end;

function TNXXMPPClient.State: TNXXMPPConnectionState;
begin
  if Assigned(FConnection) then
    Result := FConnection.State
  else
    Result := FState;
end;

end.
