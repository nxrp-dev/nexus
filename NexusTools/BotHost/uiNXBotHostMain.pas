unit uiNXBotHostMain;

{$mode objfpc}{$H+}

interface

procedure RunNexusBotHost;

implementation

uses
  Classes,
  SysUtils,
  obNXApplication,
  obNXBotCatalog,
  obNXBotControlInterpreter,
  obNXBotController,
  obNXBotHost,
  obNXBotHostConfig,
  obNXBotHostState,
  obNXButton,
  obNXControl,
  obNXEditBox,
  obNXLabel,
  obNXMemo,
  obNXPanel,
  obNXXMPPBotControl,
  obNXXMPPDisco,
  tpNXLayout,
  tpNXPlatform,
  tpNXWindow;

type
  TNXBotHostView = class(TNXMemo)
  private
    FSnapshot: TNXBotHostSnapshot;
    FState: TNXBotHostState;
    FStateRevision: PtrUInt;
  protected
    procedure RenderClient; override;
  public
    constructor Create(const AParent: INXControlParent;
      AState: TNXBotHostState); reintroduce;
  end;

  TNXBotHostUI = class
  private
    FAppServerStart: TNXButton;
    FAppServerStop: TNXButton;
    FCAFile: TNXEditBox;
    FCodexExecutable: TNXEditBox;
    FController: TNXBotController;
    FControllerConfig: TNXBotControllerConfig;
    FControllerConfigFile: string;
    FConfigFile: string;
    FControlInterpreter: TNXBotControlInterpreter;
    FControlModule: TNXXMPPBotControlModule;
    FConnect: TNXButton;
    FDisconnect: TNXButton;
    FEndpointHost: TNXEditBox;
    FEndpointPort: TNXEditBox;
    FHost: TNXBotHost;
    FJID: TNXEditBox;
    FJoin: TNXButton;
    FLeave: TNXButton;
    FModel: TNXEditBox;
    FNick: TNXEditBox;
    FPasswordVariable: TNXEditBox;
    FResource: TNXEditBox;
    FRoom: TNXEditBox;
    FRuntimeDirectory: TNXEditBox;
    FView: TNXBotHostView;
    procedure AddEdit(AParent: TNXPanel; const ACaption: string;
      ATop: Integer; out AEdit: TNXEditBox);
    procedure ApplySettings;
    procedure AppServerStartClick(ASender: TObject; AX, AY: Integer;
      AButton: TNXMouseButton);
    procedure AppServerStopClick(ASender: TObject; AX, AY: Integer;
      AButton: TNXMouseButton);
    procedure ClearClick(ASender: TObject; AX, AY: Integer;
      AButton: TNXMouseButton);
    procedure ConnectClick(ASender: TObject; AX, AY: Integer;
      AButton: TNXMouseButton);
    procedure DisconnectClick(ASender: TObject; AX, AY: Integer;
      AButton: TNXMouseButton);
    procedure JoinClick(ASender: TObject; AX, AY: Integer;
      AButton: TNXMouseButton);
    procedure LeaveClick(ASender: TObject; AX, AY: Integer;
      AButton: TNXMouseButton);
    procedure ReportException(AException: Exception);
    procedure SyncDeploymentBinding;
  public
    constructor Create;
    destructor Destroy; override;
    procedure BuildUI;
  end;

constructor TNXBotHostView.Create(const AParent: INXControlParent;
  AState: TNXBotHostState);
begin
  inherited Create(AParent);
  FState := AState;
  ReadOnly := True;
end;

procedure TNXBotHostView.RenderClient;
var
  lIndex: Integer;
  lLines: TStringList;
  lSnapshot: TNXBotHostSnapshot;
  lObservedRevision: PtrUInt;
begin
  lObservedRevision := FState.Revision;
  if FStateRevision <> lObservedRevision then
  begin
    FSnapshot := FState.Snapshot;
    FStateRevision := lObservedRevision;
    lSnapshot := FSnapshot;
    lLines := TStringList.Create;
    try
      lLines.Add('App Server: ' +
        string(NXCodexAppServerStateName(lSnapshot.AppServerState)) + ' ' +
        string(lSnapshot.AppServerDetail));
      lLines.Add('Model: ' + string(lSnapshot.Model));
      lLines.Add('XMPP: ' + string(lSnapshot.XMPPState));
      if Length(lSnapshot.Rooms) = 0 then
        lLines.Add('Rooms: none')
      else
      begin
        lLines.Add('Rooms:');
        for lIndex := 0 to High(lSnapshot.Rooms) do
          lLines.Add('  ' + string(lSnapshot.Rooms[lIndex].State) + '  ' +
            string(lSnapshot.Rooms[lIndex].RoomJID) + '/' +
            string(lSnapshot.Nick));
      end;
      lLines.Add('');
      lLines.Add('Activity');
      lLines.Text := lLines.Text + string(lSnapshot.Journal);
      Text := lLines.Text;
    finally
      lLines.Free;
    end;
  end;
  inherited RenderClient;
end;

constructor TNXBotHostUI.Create;
var
  lBinding: TNXBotDeploymentBinding;
  lCatalog: TNXBotCatalog;
  lCatalogFile: string;
  lCodexExecutable: string;
  lExecutableDirectory: string;
  lHostConfig: TNXBotHostConfig;
begin
  inherited Create;
  FConfigFile := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) +
    'NexusBotHost' + PathDelim + 'NexusBotHost.json';
  FControllerConfigFile := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) +
    'NexusBotHost' + PathDelim + 'NexusBotController.json';
  lHostConfig := TNXBotHostConfig.Create;
  lCodexExecutable := FileSearch(lHostConfig.CodexExecutable,
    GetEnvironmentVariable('PATH'));
  if lCodexExecutable <> '' then
    lHostConfig.CodexExecutable := ExpandFileName(lCodexExecutable);
  lHostConfig.RuntimeDirectory := IncludeTrailingPathDelimiter(
    GetAppConfigDir(False)) + 'NexusBotHost' + PathDelim + 'runtime';
  lExecutableDirectory := IncludeTrailingPathDelimiter(
    ExtractFileDir(ParamStr(0)));
  lHostConfig.CAFile := ExpandFileName(lExecutableDirectory +
    '..\..\..\NexusLib\net\tests\fixtures\xmpp\openfire-nexus-local.crt');
  if FileExists(FConfigFile) then
    lHostConfig.LoadFromJSONFile(FConfigFile);

  FControllerConfig := TNXBotControllerConfig.Create;
  if FileExists(FControllerConfigFile) then
    FControllerConfig.LoadFromJSONFile(FControllerConfigFile);
  if FControllerConfig.Operators.Count = 0 then
    FControllerConfig.Operators.Add('kcollins@nexus.local');
  lCatalogFile := ExpandFileName(lExecutableDirectory +
    '..\..\..\NexusTools\BotHost\catalog\Bots.nxscript');
  FControllerConfig.CatalogFile := lCatalogFile;
  lBinding := FControllerConfig.Bindings.Find('NexusBot');
  if not Assigned(lBinding) then
  begin
    lBinding := TNXBotDeploymentBinding.Create;
    lBinding.BotName := 'NexusBot';
    FControllerConfig.Bindings.Add(lBinding);
  end;
  lBinding.CodexExecutable := lHostConfig.CodexExecutable;
  lBinding.AllowPlain := lHostConfig.AllowPlain;
  lBinding.CAFile := lHostConfig.CAFile;
  lBinding.DirectTLS := lHostConfig.DirectTLS;
  lBinding.EndpointHost := lHostConfig.EndpointHost;
  lBinding.EndpointPort := lHostConfig.EndpointPort;
  lBinding.Nick := lHostConfig.Nick;
  lBinding.PasswordEnvironmentVariable :=
    lHostConfig.PasswordEnvironmentVariable;
  lBinding.Resource := lHostConfig.Resource;
  lBinding.RuntimeDirectory := lHostConfig.RuntimeDirectory;
  lBinding.XMPPJID := lHostConfig.XMPPJID;
  FControllerConfig.ControllerFullJID := lHostConfig.XMPPJID + '/' +
    lHostConfig.Resource;

  lCatalog := TNXBotCatalog.Create;
  if not lCatalog.Load(lCatalogFile, FControllerConfig) then
  begin
    lCatalog.Free;
    FreeAndNil(FControllerConfig);
    lHostConfig.Free;
    raise Exception.Create('Could not load the NexusBot catalog.');
  end;
  FController := TNXBotController.Create(lCatalog, FControllerConfig);
  FHost := TNXBotHost.Create(lHostConfig,
    lCatalog.Find('NexusBot').Instructions);
  if not FController.AdoptHost('NexusBot', FHost) then
    raise Exception.Create('Could not adopt the distinguished NexusBot host.');
  FControlInterpreter := TNXBotControlInterpreter.Create(FController, FHost);
  FHost.OnPrompt := @FControlInterpreter.HandlePrompt;
  FHost.AppServer.OnBotControl := @FController.HandleModelControl;
  FControlModule := TNXXMPPBotControlModule.Create;
  FControlModule.OnRequest := @FController.Execute;
  FControlModule.OnCancel := @FController.Cancel;
  FHost.AddXMPPModule(FControlModule);
  FHost.AddXMPPModule(TNXXMPPDiscoModule.Create('client', 'bot', 'NexusBot'));
end;

destructor TNXBotHostUI.Destroy;
begin
  if Assigned(FHost) then
  begin
    if Assigned(FCodexExecutable) then
      ApplySettings;
    ForceDirectories(ExtractFileDir(FConfigFile));
    FHost.Config.SaveToJSONFile(FConfigFile);
    FControllerConfig.SaveToJSONFile(FControllerConfigFile);
  end;
  if Assigned(FHost) then
    FHost.OnPrompt := nil;
  FHost := nil;
  FControlModule := nil;
  FreeAndNil(FControlInterpreter);
  FreeAndNil(FController);
  FreeAndNil(FControllerConfig);
  inherited Destroy;
end;

procedure TNXBotHostUI.AddEdit(AParent: TNXPanel; const ACaption: string;
  ATop: Integer; out AEdit: TNXEditBox);
var
  lLabel: TNXLabel;
begin
  lLabel := TNXLabel.Create(AParent);
  lLabel.SetBounds(8, ATop, 135, 24);
  lLabel.Caption := ACaption;
  lLabel.VertA := VAlign_Center;
  AEdit := TNXEditBox.Create(AParent);
  AEdit.SetBounds(143, ATop, 390, 24);
end;

procedure TNXBotHostUI.BuildUI;
var
  lButton: TNXButton;
  lPanel: TNXPanel;
begin
  lPanel := TNXPanel.Create(Application.RootWindow);
  lPanel.Align := caLeft;
  lPanel.Width := 550;
  AddEdit(lPanel, 'Codex executable', 10, FCodexExecutable);
  AddEdit(lPanel, 'Model', 40, FModel);
  AddEdit(lPanel, 'Runtime directory', 70, FRuntimeDirectory);
  AddEdit(lPanel, 'XMPP JID', 120, FJID);
  AddEdit(lPanel, 'Password env name', 150, FPasswordVariable);
  AddEdit(lPanel, 'Resource', 180, FResource);
  AddEdit(lPanel, 'Endpoint host', 210, FEndpointHost);
  AddEdit(lPanel, 'Endpoint port', 240, FEndpointPort);
  AddEdit(lPanel, 'CA file', 270, FCAFile);
  AddEdit(lPanel, 'Room JID', 300, FRoom);
  AddEdit(lPanel, 'Nickname', 330, FNick);

  FCodexExecutable.Text := FHost.Config.CodexExecutable;
  FModel.Text := FHost.Config.CodexModel;
  FRuntimeDirectory.Text := FHost.Config.RuntimeDirectory;
  FJID.Text := FHost.Config.XMPPJID;
  FPasswordVariable.Text := 'NEXUS_BOT_XMPP_PASSWORD';
  FPasswordVariable.ReadOnly := True;
  FResource.Text := FHost.Config.Resource;
  FEndpointHost.Text := '127.0.0.1';
  FEndpointPort.Text := '5222';
  FCAFile.Text := FHost.Config.CAFile;
  FRoom.Text := FHost.Config.RoomJID;
  FNick.Text := FHost.Config.Nick;

  FAppServerStart := TNXButton.Create(lPanel);
  FAppServerStart.SetBounds(8, 375, 125, 28);
  FAppServerStart.Caption := 'Start App Server';
  FAppServerStart.OnMouseClick := @AppServerStartClick;
  FAppServerStop := TNXButton.Create(lPanel);
  FAppServerStop.SetBounds(141, 375, 125, 28);
  FAppServerStop.Caption := 'Stop App Server';
  FAppServerStop.OnMouseClick := @AppServerStopClick;
  FConnect := TNXButton.Create(lPanel);
  FConnect.SetBounds(8, 411, 125, 28);
  FConnect.Caption := 'Connect XMPP';
  FConnect.OnMouseClick := @ConnectClick;
  FDisconnect := TNXButton.Create(lPanel);
  FDisconnect.SetBounds(141, 411, 125, 28);
  FDisconnect.Caption := 'Disconnect XMPP';
  FDisconnect.OnMouseClick := @DisconnectClick;
  FJoin := TNXButton.Create(lPanel);
  FJoin.SetBounds(8, 447, 125, 28);
  FJoin.Caption := 'Join Room';
  FJoin.OnMouseClick := @JoinClick;
  FLeave := TNXButton.Create(lPanel);
  FLeave.SetBounds(141, 447, 125, 28);
  FLeave.Caption := 'Leave Room';
  FLeave.OnMouseClick := @LeaveClick;
  lButton := TNXButton.Create(lPanel);
  lButton.SetBounds(8, 483, 125, 28);
  lButton.Caption := 'Clear View';
  lButton.OnMouseClick := @ClearClick;

  FView := TNXBotHostView.Create(Application.RootWindow, FHost.State);
  FView.Align := caClient;
end;

procedure TNXBotHostUI.ApplySettings;
begin
  FHost.Config.CodexExecutable := FCodexExecutable.Text;
  FHost.Config.CodexModel := FModel.Text;
  FHost.Config.RuntimeDirectory := FRuntimeDirectory.Text;
  FHost.Config.XMPPJID := FJID.Text;
  FHost.Config.PasswordEnvironmentVariable := 'NEXUS_BOT_XMPP_PASSWORD';
  FHost.Config.Resource := FResource.Text;
  FHost.Config.EndpointHost := FEndpointHost.Text;
  FHost.Config.EndpointPort := StrToIntDef(FEndpointPort.Text, 0);
  FHost.Config.CAFile := FCAFile.Text;
  FHost.Config.RoomJID := FRoom.Text;
  FHost.Config.Nick := FNick.Text;
  FHost.RefreshIdentity;
  SyncDeploymentBinding;
end;

procedure TNXBotHostUI.SyncDeploymentBinding;
var
  lBinding: TNXBotDeploymentBinding;
begin
  lBinding := FControllerConfig.Bindings.Find('NexusBot');
  if not Assigned(lBinding) then
    Exit;
  lBinding.CodexExecutable := FHost.Config.CodexExecutable;
  lBinding.AllowPlain := FHost.Config.AllowPlain;
  lBinding.CAFile := FHost.Config.CAFile;
  lBinding.DirectTLS := FHost.Config.DirectTLS;
  lBinding.EndpointHost := FHost.Config.EndpointHost;
  lBinding.EndpointPort := FHost.Config.EndpointPort;
  lBinding.Nick := FHost.Config.Nick;
  lBinding.PasswordEnvironmentVariable :=
    FHost.Config.PasswordEnvironmentVariable;
  lBinding.Resource := FHost.Config.Resource;
  lBinding.RuntimeDirectory := FHost.Config.RuntimeDirectory;
  lBinding.XMPPJID := FHost.Config.XMPPJID;
  FControllerConfig.ControllerFullJID := FHost.Config.XMPPJID + '/' +
    FHost.Config.Resource;
  FController.UpdateDeployment(lBinding);
end;

procedure TNXBotHostUI.ReportException(AException: Exception);
begin
  FHost.State.AddJournal('Operator command failed: ' +
    UTF8String(AException.Message));
end;

procedure TNXBotHostUI.AppServerStartClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  try
    ApplySettings;
    ForceDirectories(FHost.Config.RuntimeDirectory);
    FHost.StartAppServer;
  except
    on E: Exception do ReportException(E);
  end;
end;

procedure TNXBotHostUI.AppServerStopClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  FHost.StopAppServer;
end;

procedure TNXBotHostUI.ConnectClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  try
    ApplySettings;
    FHost.ConnectXMPP;
  except
    on E: Exception do ReportException(E);
  end;
end;

procedure TNXBotHostUI.DisconnectClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  FHost.DisconnectXMPP;
end;

procedure TNXBotHostUI.JoinClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  try
    ApplySettings;
    FHost.JoinRoom(UTF8String(FHost.Config.RoomJID));
  except
    on E: Exception do ReportException(E);
  end;
end;

procedure TNXBotHostUI.LeaveClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  FHost.LeaveRoom(UTF8String(FHost.Config.RoomJID));
end;

procedure TNXBotHostUI.ClearClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  FHost.ClearView;
end;

procedure RunNexusBotHost;
var
  lUI: TNXBotHostUI;
begin
  Application.Initialize('Nexus Codex XMPP Bot', 1200, 760, wspCentered);
  lUI := TNXBotHostUI.Create;
  try
    lUI.BuildUI;
    Application.Run;
  finally
    lUI.Free;
  end;
end;

end.
