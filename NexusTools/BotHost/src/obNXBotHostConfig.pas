unit obNXBotHostConfig;

{$mode objfpc}{$H+}
{$TYPEINFO ON}

interface

uses
  Classes,
  obNXPersist;

type
  TNXBotDeploymentBinding = class(TNXPersistObject)
  private
    FAllowPlain: Boolean;
    FCAFile: string;
    FBotName: string;
    FCodexExecutable: string;
    FEndpointHost: string;
    FEndpointPort: Integer;
    FDirectTLS: Boolean;
    FNick: string;
    FPasswordEnvironmentVariable: string;
    FResource: string;
    FRuntimeDirectory: string;
    FXMPPJID: string;
  published
    property AllowPlain: Boolean read FAllowPlain write FAllowPlain;
    property CAFile: string read FCAFile write FCAFile;
    property BotName: string read FBotName write FBotName;
    property CodexExecutable: string read FCodexExecutable
      write FCodexExecutable;
    property EndpointHost: string read FEndpointHost write FEndpointHost;
    property EndpointPort: Integer read FEndpointPort write FEndpointPort;
    property DirectTLS: Boolean read FDirectTLS write FDirectTLS;
    property Nick: string read FNick write FNick;
    property PasswordEnvironmentVariable: string
      read FPasswordEnvironmentVariable write FPasswordEnvironmentVariable;
    property Resource: string read FResource write FResource;
    property RuntimeDirectory: string read FRuntimeDirectory
      write FRuntimeDirectory;
    property XMPPJID: string read FXMPPJID write FXMPPJID;
  end;

  TNXBotDeploymentList = class(TNXPersistList)
  public
    constructor Create; override;
    function Binding(AIndex: Integer): TNXBotDeploymentBinding;
    function Find(const ABotName: string): TNXBotDeploymentBinding;
  end;

  TNXBotControllerConfig = class(TNXPersistObject)
  private
    FBindings: TNXBotDeploymentList;
    FCatalogFile: string;
    FControllerFullJID: string;
    FOperationCapacity: Integer;
    FOperators: TStringList;
    FReaders: TStringList;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Bindings: TNXBotDeploymentList read FBindings write FBindings;
    property CatalogFile: string read FCatalogFile write FCatalogFile;
    property ControllerFullJID: string read FControllerFullJID
      write FControllerFullJID;
    property OperationCapacity: Integer read FOperationCapacity
      write FOperationCapacity;
    property Operators: TStringList read FOperators write FOperators;
    property Readers: TStringList read FReaders write FReaders;
  end;

  TNXBotHostConfig = class(TNXPersistObject)
  private
    FAllowPlain: Boolean;
    FAnswerMaximumBytes: Integer;
    FCAFile: string;
    FCodexExecutable: string;
    FCodexModel: string;
    FCommandCapacity: Integer;
    FEndpointHost: string;
    FEndpointPort: Integer;
    FDirectTLS: Boolean;
    FJournalCapacity: Integer;
    FNick: string;
    FPasswordEnvironmentVariable: string;
    FPromptCapacity: Integer;
    FPromptMaximumBytes: Integer;
    FRequestTimeoutMS: Integer;
    FResource: string;
    FRoomJID: string;
    FRuntimeDirectory: string;
    FXMPPJID: string;
  public
    constructor Create; override;
    procedure Validate;
    procedure ValidateAppServer;
    procedure ValidateXMPP;
    function Password: UTF8String;
  published
    property AllowPlain: Boolean read FAllowPlain write FAllowPlain;
    property AnswerMaximumBytes: Integer read FAnswerMaximumBytes
      write FAnswerMaximumBytes;
    property CAFile: string read FCAFile write FCAFile;
    property CodexExecutable: string read FCodexExecutable
      write FCodexExecutable;
    property CodexModel: string read FCodexModel write FCodexModel;
    property CommandCapacity: Integer read FCommandCapacity
      write FCommandCapacity;
    property EndpointHost: string read FEndpointHost write FEndpointHost;
    property EndpointPort: Integer read FEndpointPort write FEndpointPort;
    property DirectTLS: Boolean read FDirectTLS write FDirectTLS;
    property JournalCapacity: Integer read FJournalCapacity
      write FJournalCapacity;
    property Nick: string read FNick write FNick;
    property PasswordEnvironmentVariable: string
      read FPasswordEnvironmentVariable write FPasswordEnvironmentVariable;
    property PromptCapacity: Integer read FPromptCapacity
      write FPromptCapacity;
    property PromptMaximumBytes: Integer read FPromptMaximumBytes
      write FPromptMaximumBytes;
    property RequestTimeoutMS: Integer read FRequestTimeoutMS
      write FRequestTimeoutMS;
    property Resource: string read FResource write FResource;
    property RoomJID: string read FRoomJID write FRoomJID;
    property RuntimeDirectory: string read FRuntimeDirectory
      write FRuntimeDirectory;
    property XMPPJID: string read FXMPPJID write FXMPPJID;
  end;

implementation

uses
  SysUtils;

constructor TNXBotDeploymentList.Create;
begin
  inherited Create;
  ItemClass := TNXBotDeploymentBinding;
end;

function TNXBotDeploymentList.Binding(
  AIndex: Integer): TNXBotDeploymentBinding;
begin
  Result := TNXBotDeploymentBinding(Items[AIndex]);
end;

function TNXBotDeploymentList.Find(
  const ABotName: string): TNXBotDeploymentBinding;
var
  lIndex: Integer;
begin
  Result := nil;
  for lIndex := 0 to Count - 1 do
    if Binding(lIndex).BotName = ABotName then
      Exit(Binding(lIndex));
end;

constructor TNXBotControllerConfig.Create;
begin
  inherited Create;
  FBindings := TNXBotDeploymentList.Create;
  FOperators := TStringList.Create;
  FReaders := TStringList.Create;
  FOperationCapacity := 32;
end;

destructor TNXBotControllerConfig.Destroy;
begin
  FReaders.Free;
  FOperators.Free;
  FBindings.Free;
  inherited Destroy;
end;

constructor TNXBotHostConfig.Create;
begin
  inherited Create;
  FAnswerMaximumBytes := 16 * 1024;
  FAllowPlain := True;
  FCodexExecutable := 'codex.exe';
  FCodexModel := 'gpt-5.6-luna';
  FCommandCapacity := 64;
  FEndpointHost := '127.0.0.1';
  FEndpointPort := 5222;
  FJournalCapacity := 256;
  FNick := 'NexusBot';
  FPasswordEnvironmentVariable := 'NEXUS_BOT_XMPP_PASSWORD';
  FPromptCapacity := 16;
  FPromptMaximumBytes := 16 * 1024;
  FRequestTimeoutMS := 30000;
  FResource := 'NexusBotHost';
  FRoomJID := 'nexus-test@conference.nexus.local';
  FXMPPJID := 'test1@nexus.local';
end;

procedure TNXBotHostConfig.Validate;
begin
  ValidateXMPP;
  ValidateAppServer;
end;

procedure TNXBotHostConfig.ValidateAppServer;
begin
  if FCodexExecutable = '' then
    raise Exception.Create('Codex executable is required.');
  if FRuntimeDirectory = '' then
    raise Exception.Create('Codex runtime directory is required.');
  if FCodexModel = '' then
    raise Exception.Create('Codex model is required.');
  if (FCommandCapacity < 1) or (FPromptCapacity < 1) or
    (FPromptMaximumBytes < 1) or (FAnswerMaximumBytes < 1) or
    (FRequestTimeoutMS < 1) or (FJournalCapacity < 1) then
    raise Exception.Create('BotHost capacities, limits, and timeouts must be positive.');
end;

procedure TNXBotHostConfig.ValidateXMPP;
begin
  if FXMPPJID = '' then
    raise Exception.Create('XMPP JID is required.');
  if FRoomJID = '' then
    raise Exception.Create('Room JID is required.');
  if FNick = '' then
    raise Exception.Create('Room nickname is required.');
  if (FEndpointPort < 0) or (FEndpointPort > High(Word)) then
    raise Exception.Create('XMPP endpoint port is invalid.');
end;

function TNXBotHostConfig.Password: UTF8String;
begin
  Result := UTF8String(GetEnvironmentVariable(FPasswordEnvironmentVariable));
  if Result = '' then
    raise Exception.CreateFmt('XMPP password environment variable is empty: %s',
      [FPasswordEnvironmentVariable]);
end;

initialization
  TNXPersistObject.RegisterPersistClass(TNXBotDeploymentBinding);
  TNXPersistObject.RegisterPersistClass(TNXBotDeploymentList);
  TNXPersistObject.RegisterPersistClass(TNXBotControllerConfig);
  TNXPersistObject.RegisterPersistClass(TNXBotHostConfig);

end.
