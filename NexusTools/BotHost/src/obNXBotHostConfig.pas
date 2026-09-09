unit obNXBotHostConfig;

{$mode objfpc}{$H+}
{$TYPEINFO ON}

interface

uses
  Classes,
  obNXPersist,
  obNXBotWorkspace;

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
    FExchangeDirectory: string;
    FFileMaximumBytes: Int64;
    FFileTransferCapacity: Integer;
    FFileTransferTimeoutMS: Integer;
    FStagedFileCapacity: Integer;
    FStagedMaximumBytes: Int64;
    FShellCallMaximum: Integer;
    FShellCommandTimeoutMS: Integer;
    FShellOutputMaximumBytes: Integer;
    FTrustedFileOrigins: TStringList;
    FXMPPJID: string;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure ValidateFileExchange;
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
    property ExchangeDirectory: string read FExchangeDirectory
      write FExchangeDirectory;
    property FileMaximumBytes: Int64 read FFileMaximumBytes
      write FFileMaximumBytes;
    property FileTransferCapacity: Integer read FFileTransferCapacity
      write FFileTransferCapacity;
    property FileTransferTimeoutMS: Integer read FFileTransferTimeoutMS
      write FFileTransferTimeoutMS;
    property StagedFileCapacity: Integer read FStagedFileCapacity
      write FStagedFileCapacity;
    property StagedMaximumBytes: Int64 read FStagedMaximumBytes
      write FStagedMaximumBytes;
    property ShellCallMaximum: Integer read FShellCallMaximum
      write FShellCallMaximum;
    property ShellCommandTimeoutMS: Integer read FShellCommandTimeoutMS
      write FShellCommandTimeoutMS;
    property ShellOutputMaximumBytes: Integer read FShellOutputMaximumBytes
      write FShellOutputMaximumBytes;
    property TrustedFileOrigins: TStringList read FTrustedFileOrigins
      write FTrustedFileOrigins;
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
    FExchangeDirectory: string;
    FFileMaximumBytes: Int64;
    FFileTransferCapacity: Integer;
    FFileTransferTimeoutMS: Integer;
    FStagedFileCapacity: Integer;
    FStagedMaximumBytes: Int64;
    FShellCallMaximum: Integer;
    FShellCommandTimeoutMS: Integer;
    FShellOutputMaximumBytes: Integer;
    FTrustedFileOrigins: TStringList;
    FXMPPJID: string;
    FWorkspaces: TNXBotWorkspaceAccessList;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure ApplyDeployment(ABinding: TNXBotDeploymentBinding);
    procedure Validate;
    procedure ValidateProvider;
    procedure ValidateXMPP;
    property Workspaces: TNXBotWorkspaceAccessList read FWorkspaces;
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
    property ExchangeDirectory: string read FExchangeDirectory
      write FExchangeDirectory;
    property FileMaximumBytes: Int64 read FFileMaximumBytes
      write FFileMaximumBytes;
    property FileTransferCapacity: Integer read FFileTransferCapacity
      write FFileTransferCapacity;
    property FileTransferTimeoutMS: Integer read FFileTransferTimeoutMS
      write FFileTransferTimeoutMS;
    property StagedFileCapacity: Integer read FStagedFileCapacity
      write FStagedFileCapacity;
    property StagedMaximumBytes: Int64 read FStagedMaximumBytes
      write FStagedMaximumBytes;
    property ShellCallMaximum: Integer read FShellCallMaximum
      write FShellCallMaximum;
    property ShellCommandTimeoutMS: Integer read FShellCommandTimeoutMS
      write FShellCommandTimeoutMS;
    property ShellOutputMaximumBytes: Integer read FShellOutputMaximumBytes
      write FShellOutputMaximumBytes;
    property TrustedFileOrigins: TStringList read FTrustedFileOrigins
      write FTrustedFileOrigins;
    property XMPPJID: string read FXMPPJID write FXMPPJID;
  end;

implementation

uses
  SysUtils, synaip, synautil;

function NXCanonicalTrustedOrigin(const AValue: string): string;
var
  lHost: string;
  lPara: string;
  lPass: string;
  lPath: string;
  lPort: string;
  lPortNumber: Integer;
  lProtocol: string;
  lUser: string;
begin
  ParseURL(Trim(AValue), lProtocol, lUser, lPass, lHost, lPort,
    lPath, lPara);
  if not SameText(lProtocol, 'https') or (lHost = '') or (lUser <> '') or
    (lPass <> '') or IsIP(lHost) or IsIP6(lHost) or (lPara <> '') or
    ((lPath <> '') and (lPath <> '/')) or (Pos('#', AValue) > 0) then
    raise Exception.CreateFmt('Trusted file origin is invalid: %s',
      [AValue]);
  if lPort = '' then lPort := '443';
  if not TryStrToInt(lPort, lPortNumber) or (lPortNumber < 1) or
    (lPortNumber > High(Word)) then
    raise Exception.CreateFmt('Trusted file origin port is invalid: %s',
      [AValue]);
  Result := 'https://' + LowerCase(lHost) + ':' + IntToStr(lPortNumber);
end;

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

procedure NXValidateFileExchange(const AExchangeDirectory: string;
  AFileMaximumBytes: Int64; AFileTransferCapacity,
  AFileTransferTimeoutMS, AStagedFileCapacity: Integer;
  AStagedMaximumBytes: Int64; ATrustedOrigins: TStringList);
var
  lIndex: Integer;
  lOrigin: string;
  lOrigins: TStringList;
begin
  if AExchangeDirectory = '' then
    raise Exception.Create('BotHost exchange directory is required.');
  if (AFileMaximumBytes < 1) or (AFileTransferCapacity < 1) or
    (AFileTransferTimeoutMS < 1) or (AStagedFileCapacity < 1) or
    (AStagedMaximumBytes < 1) then
    raise Exception.Create('BotHost file limits and timeouts must be positive.');
  lOrigins := TStringList.Create;
  try
    lOrigins.CaseSensitive := False;
    lOrigins.Sorted := True;
    lOrigins.Duplicates := dupError;
    for lIndex := 0 to ATrustedOrigins.Count - 1 do
    begin
      lOrigin := NXCanonicalTrustedOrigin(ATrustedOrigins[lIndex]);
      try
        lOrigins.Add(lOrigin);
      except
        on E: EStringListError do
          raise Exception.CreateFmt('Trusted file origin is duplicated: %s',
            [ATrustedOrigins[lIndex]]);
      end;
    end;
    ATrustedOrigins.Assign(lOrigins);
  finally
    lOrigins.Free;
  end;
end;

constructor TNXBotDeploymentBinding.Create;
begin
  inherited Create;
  FFileMaximumBytes := 16 * 1024 * 1024;
  FFileTransferCapacity := 8;
  FFileTransferTimeoutMS := 120000;
  FStagedFileCapacity := 32;
  FStagedMaximumBytes := 64 * 1024 * 1024;
  FShellCallMaximum := 8;
  FShellCommandTimeoutMS := 30000;
  FShellOutputMaximumBytes := 64 * 1024;
  FTrustedFileOrigins := TStringList.Create;
  FTrustedFileOrigins.CaseSensitive := False;
end;

destructor TNXBotDeploymentBinding.Destroy;
begin
  FTrustedFileOrigins.Free;
  inherited Destroy;
end;

procedure TNXBotDeploymentBinding.ValidateFileExchange;
begin
  NXValidateFileExchange(FExchangeDirectory, FFileMaximumBytes,
    FFileTransferCapacity, FFileTransferTimeoutMS, FStagedFileCapacity,
    FStagedMaximumBytes, FTrustedFileOrigins);
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
    lBinding.ExchangeDirectory := NXResolveConfigPath(
      lBinding.ExchangeDirectory, AConfigFile);
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
  FFileMaximumBytes := 16 * 1024 * 1024;
  FFileTransferCapacity := 8;
  FFileTransferTimeoutMS := 120000;
  FStagedFileCapacity := 32;
  FStagedMaximumBytes := 64 * 1024 * 1024;
  FShellCallMaximum := 8;
  FShellCommandTimeoutMS := 30000;
  FShellOutputMaximumBytes := 64 * 1024;
  FTrustedFileOrigins := TStringList.Create;
  FTrustedFileOrigins.CaseSensitive := False;
  FWorkspaces := TNXBotWorkspaceAccessList.Create(True);
  FXMPPJID := 'test1@nexus.local';
end;

destructor TNXBotHostConfig.Destroy;
begin
  FWorkspaces.Free;
  FTrustedFileOrigins.Free;
  inherited Destroy;
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
  FExchangeDirectory := ABinding.ExchangeDirectory;
  FFileMaximumBytes := ABinding.FileMaximumBytes;
  FFileTransferCapacity := ABinding.FileTransferCapacity;
  FFileTransferTimeoutMS := ABinding.FileTransferTimeoutMS;
  FStagedFileCapacity := ABinding.StagedFileCapacity;
  FStagedMaximumBytes := ABinding.StagedMaximumBytes;
  FShellCallMaximum := ABinding.ShellCallMaximum;
  FShellCommandTimeoutMS := ABinding.ShellCommandTimeoutMS;
  FShellOutputMaximumBytes := ABinding.ShellOutputMaximumBytes;
  FTrustedFileOrigins.Assign(ABinding.TrustedFileOrigins);
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
  if (FShellCallMaximum < 1) or (FShellCommandTimeoutMS < 1) or
    (FShellOutputMaximumBytes < 1) then
    raise Exception.Create('OpenAI shell limits and timeout must be positive.');
  NXValidateFileExchange(FExchangeDirectory, FFileMaximumBytes,
    FFileTransferCapacity, FFileTransferTimeoutMS, FStagedFileCapacity,
    FStagedMaximumBytes, FTrustedFileOrigins);
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
