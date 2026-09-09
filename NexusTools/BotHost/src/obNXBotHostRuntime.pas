unit obNXBotHostRuntime;

{$mode objfpc}{$H+}

interface

uses
  obNXBotController,
  obNXBotControlInterpreter,
  obNXBotHost,
  obNXBotHostConfig,
  obNXXMPPBotControl;

type
  TNXBotHostActivityEvent = procedure(const AText: UTF8String) of object;

  TNXBotHostRuntime = class
  private
    FAutoStart: Boolean;
    FController: TNXBotController;
    FControllerConfig: TNXBotControllerConfig;
    FControlInterpreter: TNXBotControlInterpreter;
    FControlModule: TNXXMPPBotControlModule;
    FHost: TNXBotHost;
    FOnActivity: TNXBotHostActivityEvent;
    FRoomJID: UTF8String;
    FShutdown: Boolean;
    FStarted: Boolean;
    procedure Activity(ASender: TObject; const AText: UTF8String);
    procedure Configure(const AConfigFile: string);
  public
    constructor Create(const AConfigFile: string);
    destructor Destroy; override;
    procedure Start;
    procedure Shutdown;

    property Controller: TNXBotController read FController;
    property Host: TNXBotHost read FHost;
    property OnActivity: TNXBotHostActivityEvent read FOnActivity
      write FOnActivity;
  end;

implementation

uses
  Classes,
  SysUtils,
  obNXBotCatalog,
  obNXXMPPDisco;

constructor TNXBotHostRuntime.Create(const AConfigFile: string);
begin
  inherited Create;
  Configure(AConfigFile);
end;

procedure TNXBotHostRuntime.Configure(const AConfigFile: string);
var
  lBinding: TNXBotDeploymentBinding;
  lCatalog: TNXBotCatalog;
  lCatalogDiagnostic: string;
  lEntry: TNXBotCatalogEntry;
  lHostConfig: TNXBotHostConfig;
  lLaunchConfig: TNXBotHostLaunchConfig;
begin
  if not FileExists(AConfigFile) then
    raise Exception.Create('BotHost launch configuration not found: ' +
      AConfigFile);
  lCatalog := nil;
  lHostConfig := nil;
  lLaunchConfig := TNXBotHostLaunchConfig.Create;
  try
    lLaunchConfig.LoadFromJSONFile(AConfigFile);
    lLaunchConfig.Validate;
    lLaunchConfig.ResolvePaths(AConfigFile);
    if not FileExists(lLaunchConfig.ControllerFile) then
      raise Exception.Create('BotHost controller configuration not found: ' +
        lLaunchConfig.ControllerFile);

    FControllerConfig := TNXBotControllerConfig.Create;
    FControllerConfig.LoadFromJSONFile(lLaunchConfig.ControllerFile);
    FControllerConfig.ResolvePaths(lLaunchConfig.ControllerFile);
    lBinding := FControllerConfig.Bindings.Find(lLaunchConfig.BotName);
    if not Assigned(lBinding) then
      raise Exception.Create('No deployment binding exists for bot ' +
        lLaunchConfig.BotName + '.');
    FControllerConfig.ControllerFullJID := lBinding.XMPPJID + '/' +
      lBinding.Resource;

    lCatalog := TNXBotCatalog.Create;
    if not lCatalog.Load(FControllerConfig.CatalogFile,
      FControllerConfig) then
    begin
      lCatalogDiagnostic := lCatalog.Diagnostics.Text;
      raise Exception.Create('Could not load the NexusBot catalog:' +
        LineEnding + lCatalogDiagnostic);
    end;
    lEntry := lCatalog.Find(UTF8String(lLaunchConfig.BotName));
    if not Assigned(lEntry) then
      raise Exception.Create('The configured launch bot is not in the catalog: ' +
        lLaunchConfig.BotName);

    lHostConfig := TNXBotHostConfig.Create;
    lHostConfig.ApplyDeployment(lBinding);
    lHostConfig.Provider := string(lEntry.Provider);
    lHostConfig.Model := string(lEntry.Model);
    lHostConfig.RoomJID := lLaunchConfig.RoomJID;
    FController := TNXBotController.Create(lCatalog, FControllerConfig);
    lCatalog := nil;
    FHost := TNXBotHost.Create(lHostConfig, lEntry.Instructions);
    lHostConfig := nil;
    if not FController.AdoptHost(lLaunchConfig.BotName, FHost) then
    begin
      FreeAndNil(FHost);
      raise Exception.Create('Could not adopt the configured bot host.');
    end;

    FControlInterpreter := TNXBotControlInterpreter.Create(
      FController, FHost);
    FHost.OnPrompt := @FControlInterpreter.HandlePrompt;
    FHost.OnBotControl := @FController.HandleModelControl;
    FControlModule := TNXXMPPBotControlModule.Create;
    FControlModule.OnRequest := @FController.Execute;
    FControlModule.OnCancel := @FController.Cancel;
    FHost.AddXMPPModule(FControlModule);
    FHost.AddXMPPModule(TNXXMPPDiscoModule.Create('client', 'bot',
      lLaunchConfig.BotName));
    FHost.State.OnActivity := @Activity;

    FAutoStart := lLaunchConfig.AutoStart;
    FRoomJID := UTF8String(lLaunchConfig.RoomJID);
  finally
    lHostConfig.Free;
    lCatalog.Free;
    lLaunchConfig.Free;
  end;
end;

destructor TNXBotHostRuntime.Destroy;
begin
  Shutdown;
  if Assigned(FHost) then
  begin
    FHost.State.OnActivity := nil;
    FHost.OnPrompt := nil;
  end;
  FHost := nil;
  FControlModule := nil;
  FreeAndNil(FControlInterpreter);
  FreeAndNil(FController);
  FreeAndNil(FControllerConfig);
  inherited Destroy;
end;

procedure TNXBotHostRuntime.Activity(ASender: TObject;
  const AText: UTF8String);
begin
  if Assigned(FOnActivity) then
    FOnActivity(AText);
end;

procedure TNXBotHostRuntime.Start;
begin
  if FShutdown then
    raise Exception.Create('A shut down BotHost runtime cannot be restarted.');
  if FStarted then
    Exit;
  if not FAutoStart then
    Exit;
  FController.PrepareWorkspaces;
  ForceDirectories(FHost.Config.RuntimeDirectory);
  if not FHost.StartProvider then
    raise Exception.Create('Provider start command was rejected.');
  if not FHost.ConnectXMPP then
    raise Exception.Create('XMPP connect command was rejected.');
  if not FHost.JoinRoom(FRoomJID) then
    raise Exception.Create('Room join command was rejected.');
  FStarted := True;
end;

procedure TNXBotHostRuntime.Shutdown;
begin
  if FShutdown or not Assigned(FHost) then
    Exit;
  FHost.Shutdown;
  FShutdown := True;
  FStarted := False;
end;

end.
