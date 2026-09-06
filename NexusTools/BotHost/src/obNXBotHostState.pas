unit obNXBotHostState;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  tpNXBotControl,
  tpNXBotHost;

type
  TNXBotHostActivityEvent = procedure(ASender: TObject;
    const AText: UTF8String) of object;

  TNXBotHostSnapshot = record
    ProviderState: TNXBotProviderState;
    ProviderDetail: UTF8String;
    XMPPState: UTF8String;
    Model: UTF8String;
    Nick: UTF8String;
    Journal: UTF8String;
    Rooms: TNXBotRoomStatusArray;
  end;

  TNXBotHostState = class
  private
    FProviderDetail: UTF8String;
    FProviderState: TNXBotProviderState;
    FCriticalSection: TRTLCriticalSection;
    FJournal: TStringList;
    FJournalCapacity: Integer;
    FModel: UTF8String;
    FNick: UTF8String;
    FOnActivity: TNXBotHostActivityEvent;
    FRevision: PtrUInt;
    FRooms: TStringList;
    FXMPPState: UTF8String;
    procedure Changed;
  public
    constructor Create(AJournalCapacity: Integer = 256);
    destructor Destroy; override;

    procedure AddJournal(const AText: UTF8String);
    procedure ClearJournal;
    procedure SetProvider(AState: TNXBotProviderState;
      const ADetail: UTF8String);
    procedure SetIdentity(const AModel, ANick: UTF8String);
    procedure SetRoom(const ARoomJID, AState: UTF8String);
    procedure SetXMPP(const AState: UTF8String);
    function Snapshot: TNXBotHostSnapshot;

    property Revision: PtrUInt read FRevision;
    property OnActivity: TNXBotHostActivityEvent read FOnActivity
      write FOnActivity;
  end;

function NXBotProviderStateName(AState: TNXBotProviderState): UTF8String;

implementation

function NXBotProviderStateName(AState: TNXBotProviderState): UTF8String;
begin
  case AState of
    bpsStopped: Result := 'stopped';
    bpsStarting: Result := 'starting';
    bpsReady: Result := 'ready';
    bpsWorking: Result := 'working';
    bpsStopping: Result := 'stopping';
    bpsFailed: Result := 'failed';
  end;
end;

constructor TNXBotHostState.Create(AJournalCapacity: Integer);
begin
  inherited Create;
  if AJournalCapacity < 1 then
    raise Exception.Create('Journal capacity must be positive.');
  InitCriticalSection(FCriticalSection);
  FJournal := TStringList.Create;
  FRooms := TStringList.Create;
  FRooms.CaseSensitive := True;
  FRooms.NameValueSeparator := '=';
  FJournalCapacity := AJournalCapacity;
  FProviderState := bpsStopped;
  FXMPPState := 'disconnected';
end;

destructor TNXBotHostState.Destroy;
begin
  FRooms.Free;
  FJournal.Free;
  DoneCriticalSection(FCriticalSection);
  inherited Destroy;
end;

procedure TNXBotHostState.Changed;
begin
  Inc(FRevision);
end;

procedure TNXBotHostState.AddJournal(const AText: UTF8String);
var
  lEntry: string;
  lOnActivity: TNXBotHostActivityEvent;
begin
  lEntry := FormatDateTime('hh:nn:ss', Now) + '  ' + string(AText);
  EnterCriticalSection(FCriticalSection);
  try
    FJournal.Add(lEntry);
    while FJournal.Count > FJournalCapacity do
      FJournal.Delete(0);
    Changed;
    lOnActivity := FOnActivity;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
  if Assigned(lOnActivity) then
    lOnActivity(Self, UTF8String(lEntry));
end;

procedure TNXBotHostState.ClearJournal;
begin
  EnterCriticalSection(FCriticalSection);
  try
    FJournal.Clear;
    Changed;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotHostState.SetProvider(AState: TNXBotProviderState;
  const ADetail: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FProviderState := AState;
    FProviderDetail := ADetail;
    Changed;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotHostState.SetIdentity(const AModel, ANick: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FModel := AModel;
    FNick := ANick;
    Changed;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotHostState.SetRoom(const ARoomJID, AState: UTF8String);
var
  lIndex: Integer;
begin
  EnterCriticalSection(FCriticalSection);
  try
    lIndex := FRooms.IndexOfName(string(ARoomJID));
    if lIndex < 0 then
      FRooms.Add(string(ARoomJID) + '=' + string(AState))
    else
      FRooms.ValueFromIndex[lIndex] := string(AState);
    Changed;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotHostState.SetXMPP(const AState: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FXMPPState := AState;
    Changed;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TNXBotHostState.Snapshot: TNXBotHostSnapshot;
var
  lIndex: Integer;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result.ProviderState := FProviderState;
    Result.ProviderDetail := FProviderDetail;
    Result.XMPPState := FXMPPState;
    Result.Model := FModel;
    Result.Nick := FNick;
    Result.Journal := UTF8String(FJournal.Text);
    SetLength(Result.Rooms, FRooms.Count);
    for lIndex := 0 to FRooms.Count - 1 do
    begin
      Result.Rooms[lIndex].RoomJID := UTF8String(FRooms.Names[lIndex]);
      Result.Rooms[lIndex].State := UTF8String(FRooms.ValueFromIndex[lIndex]);
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

end.
