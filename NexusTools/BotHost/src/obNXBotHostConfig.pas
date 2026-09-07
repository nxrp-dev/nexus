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
    FOpenAICAFile: string;
    FOpenAIAPIKey: string;
    FPassword: string;
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
    property OpenAICAFile: string read FOpenAICAFile write FOpenAICAFile;
    property OpenAIAPIKey: string read FOpenAIAPIKey write FOpenAIAPIKey;
    property Password: string read FPassword write FPassword;
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
    FImpliedReplyTimeoutMS: Integer;
    FOperationCapacity: Integer;
    FOperators: TStringList;
    FReaders: TStringList;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure ResolvePaths(const AConfigFile: string);
  published
    property Bindings: TNXBotDeploymentList read FBindings write FBindings;
    property CatalogFile: string read FCatalogFile write FCatalogFile;
    property ControllerFullJID: string read FControllerFullJID
      write FControllerFullJID;
    property ImpliedReplyTimeoutMS: Integer read FImpliedReplyTimeoutMS
      write FImpliedReplyTimeoutMS;
    property OperationCapacity: Integer read FOperationCapacity
      write FOperationCapacity;
    property Operators: TStringList read FOperators write FOperators;
    property Readers: TStringList read FReaders write FReaders;
  end;

  TNXBotHostLaunchConfig = class(TNXPersistObject)
  private
    FAutoStart: Boolean;
    FBotName: string;
    FControllerFile: string;
    FRoomJID: string;
  public
    constructor Create; override;
    procedure ResolvePaths(const AConfigFile: string);
    procedure Validate;
  published
    property AutoStart: Boolean read FAutoStart write FAutoStart;
    property BotName: string read FBotName write FBotName;
    property ControllerFile: string read FControllerFile
      write FControllerFile;
    property RoomJID: string read FRoomJID write FRoomJID;
  end;

  TNXBotHostConfig = class(TNXPersistObject)
  private
    FAllowPlain: Boolean;
    FAnswerMaximumBytes: Integer;
    FCAFile: string;
    FCodexExecutable: string;
    FModel: string;
    FCommandCapacity: Integer;
    FEndpointHost: string;
    FEndpointPort: Integer;
    FDirectTLS: Boolean;
    FJournalCapacity: Integer;
    FNick: string;
    FOpenAICAFile: string;
    FOpenAIAPIKey: string;
    FPassword: string;
    FPromptCapacity: Integer;
    FPromptMaximumBytes: Integer;
    FProvider: string;
    FRequestTimeoutMS: Integer;
    FResource: string;
    FRoomJID: string;
    FRuntimeDirectory: string;
    FXMPPJID: string;
  public
    constructor Create; override;
    procedure ApplyDeployment(ABinding: TNXBotDeploymentBinding);
    procedure Validate;
    procedure ValidateProvider;
    procedure ValidateXMPP;
  published
    property AllowPlain: Boolean read FAllowPlain write FAllowPlain;
    property AnswerMaximumBytes: Integer read FAnswerMaximumBytes
      write FAnswerMaximumBytes;
    property CAFile: string read FCAFile write FCAFile;
    property CodexExecutable: string read FCodexExecutable
      write FCodexExecutable;
    property CommandCapacity: Integer read FCommandCapacity
      write FCommandCapacity;
    property EndpointHost: string read FEndpointHost write FEndpointHost;
    property EndpointPort: Integer read FEndpointPort write FEndpointPort;
    property DirectTLS: Boolean read FDirectTLS write FDirectTLS;
    property JournalCapacity: Integer read FJournalCapacity
      write FJournalCapacity;
    property Model: string read FModel write FModel;
    property Nick: string read FNick write FNick;
    property OpenAICAFile: string read FOpenAICAFile write FOpenAICAFile;
    property OpenAIAPIKey: string read FOpenAIAPIKey write FOpenAIAPIKey;
    property Password: string read FPassword write FPassword;
    property PromptCapacity: Integer read FPromptCapacity
      write FPromptCapacity;
    property PromptMaximumBytes: Integer read FPromptMaximumBytes
      write FPromptMaximumBytes;
    property Provider: string read FProvider write FProvider;
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

function NXResolveConfigPath(const APath, AConfigFile: string): string;
var
  lBaseDirectory: string;
begin
  if APath = '' then
    Exit('');
  if (ExtractFileDrive(APath) <> '') or
    (APath[1] = DirectorySeparator) then
    Exit(ExpandFileName(APath));
  lBaseDirectory := ExtractFileDir(ExpandFileName(AConfigFile));
  Result := ExpandFileName(IncludeTrailingPathDelimiter(lBaseDirectory) +
    APath);
end;

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
  FImpliedReplyTimeoutMS := 120000;
  FOperators := TStringList.Create;
  FReaders := TStringList.Create;
  FOperationCapacity := 32;
end;

constructor TNXBotHostLaunchConfig.Create;
begin
  inherited Create;
  FAutoStart := True;
  FBotName := 'NexusBot';
  FControllerFile := 'NexusBotController.json';
  FRoomJID := 'nexus-test@conference.nexus.local';
end;

procedure TNXBotHostLaunchConfig.ResolvePaths(const AConfigFile: string);
begin
  FControllerFile := NXResolveConfigPath(FControllerFile, AConfigFile);
end;

procedure TNXBotHostLaunchConfig.Validate;
begin
  if FBotName = '' then
    raise Exception.Create('Launch bot name is required.');
  if FControllerFile = '' then
    raise Exception.Create('Launch controller file is required.');
  if FRoomJID = '' then
    raise Exception.Create('Launch room JID is required.');
end;

destructor TNXBotControllerConfig.Destroy;
begin
  FReaders.Free;
  FOperators.Free;
  FBindings.Free;
  inherited Destroy;
end;

procedure TNXBotControllerConfig.ResolvePaths(const AConfigFile: string);
var
  lBinding: TNXBotDeploymentBinding;
  lIndex: Integer;
begin
  FCatalogFile := NXResolveConfigPath(FCatalogFile, AConfigFile);
  for lIndex := 0 to FBindings.Count - 1 do
  begin
    lBinding := FBindings.Binding(lIndex);
    lBinding.CAFile := NXResolveConfigPath(lBinding.CAFile, AConfigFile);
    lBinding.OpenAICAFile := NXResolveConfigPath(
      lBinding.OpenAICAFile, AConfigFile);
    lBinding.CodexExecutable := NXResolveConfigPath(
      lBinding.CodexExecutable, AConfigFile);
    lBinding.RuntimeDirectory := NXResolveConfigPath(
      lBinding.RuntimeDirectory, AConfigFile);
  end;
end;

constructor TNXBotHostConfig.Create;
begin
  inherited Create;
  FAnswerMaximumBytes := 16 * 1024;
  FAllowPlain := True;
  FCodexExecutable := 'codex.exe';
  FModel := 'gpt-5.6-luna';
  FCommandCapacity := 64;
  FEndpointHost := '127.0.0.1';
  FEndpointPort := 5222;
  FJournalCapacity := 256;
  FNick := 'NexusBot';
  FPromptCapacity := 16;
  FPromptMaximumBytes := 16 * 1024;
  FProvider := 'Codex';
  FRequestTimeoutMS := 30000;
  FResource := 'NexusBotHost';
  FRoomJID := 'nexus-test@conference.nexus.local';
  FXMPPJID := 'test1@nexus.local';
end;

procedure TNXBotHostConfig.ApplyDeployment(
  ABinding: TNXBotDeploymentBinding);
begin
  if not Assigned(ABinding) then
    raise Exception.Create('Bot deployment binding is required.');
  FAllowPlain := ABinding.AllowPlain;
  FCAFile := ABinding.CAFile;
  FCodexExecutable := ABinding.CodexExecutable;
  FDirectTLS := ABinding.DirectTLS;
  FEndpointHost := ABinding.EndpointHost;
  FEndpointPort := ABinding.EndpointPort;
  FNick := ABinding.Nick;
  FOpenAICAFile := ABinding.OpenAICAFile;
  FOpenAIAPIKey := ABinding.OpenAIAPIKey;
  FPassword := ABinding.Password;
  FResource := ABinding.Resource;
  FRuntimeDirectory := ABinding.RuntimeDirectory;
  FXMPPJID := ABinding.XMPPJID;
end;

procedure TNXBotHostConfig.Validate;
begin
  ValidateXMPP;
  ValidateProvider;
end;

procedure TNXBotHostConfig.ValidateProvider;
begin
  if FProvider = '' then
    raise Exception.Create('Bot provider is required.');
  if FModel = '' then
    raise Exception.Create('Bot model is required.');
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

initialization
  TNXPersistObject.RegisterPersistClass(TNXBotDeploymentBinding);
  TNXPersistObject.RegisterPersistClass(TNXBotDeploymentList);
  TNXPersistObject.RegisterPersistClass(TNXBotControllerConfig);
  TNXPersistObject.RegisterPersistClass(TNXBotHostLaunchConfig);
  TNXPersistObject.RegisterPersistClass(TNXBotHostConfig);

end.
