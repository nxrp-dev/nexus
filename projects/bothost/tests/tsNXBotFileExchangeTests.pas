unit tsNXBotFileExchangeTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXBotFileExchangeTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes, Contnrs, SyncObjs, SysUtils, blcksock, ssl_openssl3, synsock,
  obNXBotFileExchange, obNXBotHostConfig, obNXXMPPFileSharing,
  obNXTestContext, obNXTestSuite, tpNXBotFileTypes, tpNXBotHost,
  tpNXXMPPFileTypes;

type
  TFakeFileTransferExecutor = class(TNXBotFileTransferExecutor)
  public
    Aborted: Boolean;
    AbortCount: LongInt;
    AbortStartedEvent: TEvent;
    BlockAbort: Boolean;
    BlockDownloads: Boolean;
    BlockUploads: Boolean;
    ContinueAbortEvent: TEvent;
    ContinueEvent: TEvent;
    ContinueUploadEvent: TEvent;
    IgnoreAbort: Boolean;
    StartedEvent: TEvent;
    UploadStartedEvent: TEvent;
    constructor Create;
    destructor Destroy; override;
    function Download(const AShare: TNXXMPPFileShare;
      const ADestination, ACAFile: string; AMaximumBytes: Int64;
      ATimeoutMS: Cardinal; ATrustedOrigins: TStrings;
      out AResult: TNXBotFileTransferResult): Boolean; override;
    function Upload(const ASource, ACAFile: string;
      const ASlot: TNXXMPPHTTPUploadSlot; ATimeoutMS: Cardinal;
      ATrustedOrigins: TStrings; out AError: UTF8String): Boolean; override;
    procedure Abort; override;
  end;

  TFakeFileTransferExecutorFactory = class
  public
    BlockAbort: Boolean;
    BlockCreate: Boolean;
    BlockDownloads: Boolean;
    BlockUploads: Boolean;
    ContinueCreateEvent: TEvent;
    CreateStartedEvent: TEvent;
    Executors: TObjectList;
    IgnoreAbort: Boolean;
    RaiseOnCreate: Boolean;
    constructor Create;
    destructor Destroy; override;
    function CreateExecutor: TNXBotFileTransferExecutor;
  end;

  TFakeFileSharingModule = class(TNXXMPPFileSharingModule)
  public
    BlockSend: Boolean;
    ContinueSendEvent: TEvent;
    DelayDiscovery: Boolean;
    DiscoveryEvent: TEvent;
    DiscoveryHandler: TNXXMPPHTTPUploadServiceEvent;
    SentCount: Integer;
    SendStartedEvent: TEvent;
    SentTarget: UTF8String;
    constructor Create;
    destructor Destroy; override;
    procedure CompleteDiscovery;
    function DiscoverUploadService(AFileSize: Int64;
      AHandler: TNXXMPPHTTPUploadServiceEvent): Boolean; override;
    function RequestUploadSlot(const AServiceJID, AFileName,
      AMediaType: UTF8String; AFileSize: Int64;
      AHandler: TNXXMPPHTTPUploadSlotEvent): Boolean; override;
    function SendFileShare(const AToJID, AMessageType: UTF8String;
      const AReplyJID, AReplyID: UTF8String;
      const AShare: TNXXMPPFileShare): Boolean; override;
  end;

  THTTPFixtureServer = class(TThread)
  private
    FCertificateFile: string;
    FListener: TTCPBlockSocket;
    FPort: Word;
    FPrivateKeyFile: string;
    FRequest: RawByteString;
    FResponse: RawByteString;
  protected
    procedure Execute; override;
  public
    constructor Create(const ACertificateFile, APrivateKeyFile: string;
      const AResponse: RawByteString);
    destructor Destroy; override;
    property Port: Word read FPort;
    property Request: RawByteString read FRequest;
  end;

  TFilePromptRecorder = class
  public
    BlockReady: Boolean;
    ContinueReadyEvent: TEvent;
    Error: UTF8String;
    Event: TEvent;
    Prompt: TNXBotPrompt;
    ReadyCount: LongInt;
    ReadyStartedEvent: TEvent;
    UploadError: UTF8String;
    UploadEvent: TEvent;
    UploadSuccess: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Ready(ASender: TObject; APrompt: TNXBotPrompt;
      const AError: UTF8String);
    procedure FileSent(ASuccess: Boolean; const ADetail: UTF8String);
  end;

  TSignalRoomThread = class(TThread)
  private
    FExchange: TNXBotFileExchange;
    FGate: TEvent;
    FReason: UTF8String;
    FRoomJID: UTF8String;
  protected
    procedure Execute; override;
  public
    constructor Create(AExchange: TNXBotFileExchange; AGate: TEvent;
      const ARoomJID, AReason: UTF8String);
  end;

  TAcceptInboundThread = class(TThread)
  private
    FExchange: TNXBotFileExchange;
    FGate: TEvent;
    FShares: TNXXMPPFileShareArray;
  protected
    procedure Execute; override;
  public
    Accepted: Boolean;
    Prompt: TNXBotPrompt;
    constructor Create(AExchange: TNXBotFileExchange; AGate: TEvent;
      APrompt: TNXBotPrompt; const AShares: TNXXMPPFileShareArray);
  end;

constructor TFakeFileTransferExecutor.Create;
begin
  inherited Create;
  AbortStartedEvent := TEvent.Create(nil, True, False, '');
  ContinueAbortEvent := TEvent.Create(nil, True, False, '');
  ContinueEvent := TEvent.Create(nil, True, False, '');
  ContinueUploadEvent := TEvent.Create(nil, True, False, '');
  StartedEvent := TEvent.Create(nil, True, False, '');
  UploadStartedEvent := TEvent.Create(nil, True, False, '');
end;

destructor TFakeFileTransferExecutor.Destroy;
begin
  UploadStartedEvent.Free;
  AbortStartedEvent.Free;
  ContinueAbortEvent.Free;
  ContinueEvent.Free;
  ContinueUploadEvent.Free;
  StartedEvent.Free;
  inherited Destroy;
end;

procedure TFakeFileTransferExecutor.Abort;
begin
  Aborted := True;
  InterlockedIncrement(AbortCount);
  AbortStartedEvent.SetEvent;
  if BlockAbort then
    ContinueAbortEvent.WaitFor(5000);
  ContinueEvent.SetEvent;
  ContinueUploadEvent.SetEvent;
end;

function TFakeFileTransferExecutor.Download(const AShare: TNXXMPPFileShare;
  const ADestination, ACAFile: string; AMaximumBytes: Int64;
  ATimeoutMS: Cardinal; ATrustedOrigins: TStrings;
  out AResult: TNXBotFileTransferResult): Boolean;
const
  cBody: RawByteString = 'hello';
var
  lFile: TFileStream;
begin
  AResult := Default(TNXBotFileTransferResult);
  StartedEvent.SetEvent;
  if BlockDownloads then
    ContinueEvent.WaitFor(5000);
  if Aborted and not IgnoreAbort then
  begin
    AResult.Error := 'fixture transfer cancelled';
    Exit(False);
  end;
  if (Length(AShare.Sources) = 0) or
    (Pos('fail', string(AShare.Sources[0].URL)) > 0) then
  begin
    AResult.Error := 'fixture download failed';
    Exit(False);
  end;
  lFile := TFileStream.Create(ADestination, fmCreate);
  try
    lFile.WriteBuffer(cBody[1], Length(cBody));
  finally
    lFile.Free;
  end;
  AResult.ActualSize := Length(cBody);
  AResult.HashSHA256 := 'fixture-hash';
  AResult.SourceURL := AShare.Sources[0].URL;
  Result := True;
end;

function TFakeFileTransferExecutor.Upload(const ASource, ACAFile: string;
  const ASlot: TNXXMPPHTTPUploadSlot; ATimeoutMS: Cardinal;
  ATrustedOrigins: TStrings; out AError: UTF8String): Boolean;
begin
  UploadStartedEvent.SetEvent;
  if BlockUploads then
    ContinueUploadEvent.WaitFor(5000);
  if Aborted and not IgnoreAbort then
  begin
    AError := 'fixture transfer cancelled';
    Exit(False);
  end;
  AError := '';
  Result := FileExists(ASource);
end;

constructor TFakeFileTransferExecutorFactory.Create;
begin
  inherited Create;
  ContinueCreateEvent := TEvent.Create(nil, True, False, '');
  CreateStartedEvent := TEvent.Create(nil, True, False, '');
  Executors := TObjectList.Create(False);
end;

destructor TFakeFileTransferExecutorFactory.Destroy;
begin
  Executors.Free;
  CreateStartedEvent.Free;
  ContinueCreateEvent.Free;
  inherited Destroy;
end;

function TFakeFileTransferExecutorFactory.CreateExecutor:
  TNXBotFileTransferExecutor;
var
  lExecutor: TFakeFileTransferExecutor;
begin
  if BlockCreate then
  begin
    CreateStartedEvent.SetEvent;
    ContinueCreateEvent.WaitFor(5000);
  end;
  if RaiseOnCreate then
    raise Exception.Create('fixture executor construction failed');
  lExecutor := TFakeFileTransferExecutor.Create;
  lExecutor.BlockAbort := BlockAbort;
  lExecutor.BlockDownloads := BlockDownloads;
  lExecutor.BlockUploads := BlockUploads;
  lExecutor.IgnoreAbort := IgnoreAbort;
  Executors.Add(lExecutor);
  Result := lExecutor;
end;

constructor TFakeFileSharingModule.Create;
begin
  inherited Create;
  ContinueSendEvent := TEvent.Create(nil, True, False, '');
  DiscoveryEvent := TEvent.Create(nil, True, False, '');
  SendStartedEvent := TEvent.Create(nil, True, False, '');
end;

destructor TFakeFileSharingModule.Destroy;
begin
  SendStartedEvent.Free;
  DiscoveryEvent.Free;
  ContinueSendEvent.Free;
  inherited Destroy;
end;

procedure TFakeFileSharingModule.CompleteDiscovery;
var
  lHandler: TNXXMPPHTTPUploadServiceEvent;
  lService: TNXXMPPHTTPUploadService;
begin
  lHandler := DiscoveryHandler;
  DiscoveryHandler := nil;
  lService := Default(TNXXMPPHTTPUploadService);
  lService.JID := 'upload.example';
  lHandler(Self, lService, '');
end;

function TFakeFileSharingModule.DiscoverUploadService(AFileSize: Int64;
  AHandler: TNXXMPPHTTPUploadServiceEvent): Boolean;
var
  lService: TNXXMPPHTTPUploadService;
begin
  if DelayDiscovery then
  begin
    DiscoveryHandler := AHandler;
    DiscoveryEvent.SetEvent;
    Exit(True);
  end;
  DiscoveryEvent.SetEvent;
  lService := Default(TNXXMPPHTTPUploadService);
  lService.JID := 'upload.example';
  AHandler(Self, lService, '');
  Result := True;
end;

function TFakeFileSharingModule.RequestUploadSlot(const AServiceJID,
  AFileName, AMediaType: UTF8String; AFileSize: Int64;
  AHandler: TNXXMPPHTTPUploadSlotEvent): Boolean;
var
  lSlot: TNXXMPPHTTPUploadSlot;
begin
  lSlot := Default(TNXXMPPHTTPUploadSlot);
  lSlot.PutURL := 'https://upload.example/put';
  lSlot.GetURL := 'https://upload.example/get';
  AHandler(Self, lSlot, '');
  Result := True;
end;

function TFakeFileSharingModule.SendFileShare(const AToJID,
  AMessageType, AReplyJID, AReplyID: UTF8String;
  const AShare: TNXXMPPFileShare): Boolean;
begin
  SendStartedEvent.SetEvent;
  if BlockSend then
    ContinueSendEvent.WaitFor(5000);
  Inc(SentCount);
  SentTarget := AToJID;
  Result := (AMessageType <> '') and (Length(AShare.Sources) = 1);
end;

constructor THTTPFixtureServer.Create(const ACertificateFile,
  APrivateKeyFile: string; const AResponse: RawByteString);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FCertificateFile := ACertificateFile;
  FPrivateKeyFile := APrivateKeyFile;
  FResponse := AResponse;
  FListener := TTCPBlockSocket.Create;
  FListener.Bind('127.0.0.1', '0');
  FListener.Listen;
  if FListener.LastError <> 0 then
    raise Exception.Create('Could not create the HTTPS fixture listener.');
  FPort := FListener.GetLocalSinPort;
end;

destructor THTTPFixtureServer.Destroy;
begin
  FListener.CloseSocket;
  if not Finished then
    WaitFor;
  FListener.Free;
  inherited Destroy;
end;

procedure THTTPFixtureServer.Execute;
var
  lClient: TTCPBlockSocket;
  lContentLength: Integer;
  lLine: RawByteString;
begin
  lClient := TTCPBlockSocket.Create;
  try
    lClient.Socket := FListener.Accept;
    if lClient.Socket = INVALID_SOCKET then
      Exit;
    lClient.ConnectionTimeout := 1000;
    lClient.SSL.CertificateFile := FCertificateFile;
    lClient.SSL.PrivateKeyFile := FPrivateKeyFile;
    lClient.SSL.SSLType := LT_TLSv1_2;
    if not lClient.SSLAcceptConnection then
      Exit;
    lContentLength := 0;
    repeat
      lLine := lClient.RecvString(1000);
      if Pos('content-length:', LowerCase(string(lLine))) = 1 then
        lContentLength := StrToIntDef(Trim(Copy(string(lLine), 16, MaxInt)), 0);
      FRequest := FRequest + lLine + #13#10;
    until (lLine = '') or (lClient.LastError <> 0);
    if lContentLength > 0 then
      FRequest := FRequest + lClient.RecvBufferStr(lContentLength, 1000);
    lClient.SendString(FResponse);
    lClient.AbortSocket;
  finally
    lClient.Free;
  end;
end;

constructor TFilePromptRecorder.Create;
begin
  inherited Create;
  ContinueReadyEvent := TEvent.Create(nil, True, False, '');
  Event := TEvent.Create(nil, False, False, '');
  ReadyStartedEvent := TEvent.Create(nil, True, False, '');
  UploadEvent := TEvent.Create(nil, False, False, '');
end;

destructor TFilePromptRecorder.Destroy;
begin
  Prompt.Free;
  UploadEvent.Free;
  ReadyStartedEvent.Free;
  Event.Free;
  ContinueReadyEvent.Free;
  inherited Destroy;
end;

procedure TFilePromptRecorder.Ready(ASender: TObject; APrompt: TNXBotPrompt;
  const AError: UTF8String);
begin
  Prompt := APrompt;
  Error := AError;
  InterlockedIncrement(ReadyCount);
  ReadyStartedEvent.SetEvent;
  if BlockReady then
    ContinueReadyEvent.WaitFor(5000);
  Event.SetEvent;
end;

constructor TSignalRoomThread.Create(AExchange: TNXBotFileExchange;
  AGate: TEvent; const ARoomJID, AReason: UTF8String);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FExchange := AExchange;
  FGate := AGate;
  FRoomJID := ARoomJID;
  FReason := AReason;
  Start;
end;

procedure TSignalRoomThread.Execute;
begin
  FGate.WaitFor(INFINITE);
  FExchange.SignalRoom(FRoomJID, FReason);
end;

constructor TAcceptInboundThread.Create(AExchange: TNXBotFileExchange;
  AGate: TEvent; APrompt: TNXBotPrompt;
  const AShares: TNXXMPPFileShareArray);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FExchange := AExchange;
  FGate := AGate;
  Prompt := APrompt;
  FShares := Copy(AShares);
  Start;
end;

procedure TAcceptInboundThread.Execute;
begin
  FGate.WaitFor(INFINITE);
  Accepted := FExchange.AcceptInbound(Prompt, FShares);
end;

procedure TFilePromptRecorder.FileSent(ASuccess: Boolean;
  const ADetail: UTF8String);
begin
  UploadSuccess := ASuccess;
  UploadError := ADetail;
  UploadEvent.SetEvent;
end;

function FileShare(const AURL: UTF8String): TNXXMPPFileShare;
begin
  Result := Default(TNXXMPPFileShare);
  Result.ID := AURL;
  Result.Name := 'test.txt';
  Result.MediaType := 'text/plain';
  Result.HasSize := True;
  Result.DeclaredSize := 5;
  SetLength(Result.Sources, 1);
  Result.Sources[0].URL := AURL;
end;

procedure TestOutboundSingleTransfer(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lFactory: TFakeFileTransferExecutorFactory;
  lFile: TFileStream;
  lFileSharing: TFakeFileSharingModule;
  lPath: string;
  lRecorder: TFilePromptRecorder;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxfo');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lFileSharing := TFakeFileSharingModule.Create;
  lRecorder := TFilePromptRecorder.Create;
  lPath := GetTempFileName(lDirectory, 'send');
  lFile := TFileStream.Create(lPath, fmCreate);
  lFile.Free;
  lAttachment := TNXBotAttachment.Create;
  lAttachment.ID := 'artifact';
  lAttachment.Name := 'test.txt';
  lAttachment.MediaType := 'text/plain';
  lAttachment.Size := 0;
  lAttachment.HashSHA256 := 'hash';
  lAttachment.Path := lPath;
  try
    AContext.AssertTrue(lExchange.AcceptOutbound(lAttachment, lFileSharing,
      'room@example', 'groupchat', '', '', 'room@example',
      @lRecorder.FileSent), 'The outbound transfer should be accepted.');
    lAttachment := nil;
    AContext.AssertTrue(lRecorder.UploadEvent.WaitFor(5000) = wrSignaled,
      'The transfer thread should complete discovery, slot, upload, and send.');
    AContext.AssertTrue(lRecorder.UploadSuccess,
      'The sequential outbound transfer should report success.');
    AContext.AssertEquals(1, lFileSharing.SentCount,
      'The final file-share command should be submitted exactly once.');
    AContext.AssertEquals('room@example', string(lFileSharing.SentTarget),
      'The transfer should retain its delivery target.');
    AContext.AssertEquals(1, lFactory.Executors.Count,
      'One accepted transfer should create exactly one executor.');
    lExchange.Shutdown;
  finally
    lAttachment.Free;
    lExchange.Free;
    lRecorder.Free;
    lFileSharing.Free;
    lFactory.Free;
    lConfig.Free;
    if FileExists(lPath) then DeleteFile(lPath);
    RemoveDir(lDirectory);
  end;
end;

procedure TestOutboundCancellationDrainsCallback(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lFactory: TFakeFileTransferExecutorFactory;
  lFileSharing: TFakeFileSharingModule;
  lRecorder: TFilePromptRecorder;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxfd');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lFileSharing := TFakeFileSharingModule.Create;
  lFileSharing.DelayDiscovery := True;
  lRecorder := TFilePromptRecorder.Create;
  lAttachment := TNXBotAttachment.Create;
  lAttachment.ID := 'cancel-artifact';
  lAttachment.Name := 'test.txt';
  lAttachment.Size := 0;
  try
    AContext.AssertTrue(lExchange.AcceptOutbound(lAttachment, lFileSharing,
      'room@example', 'groupchat', '', '', 'room@example',
      @lRecorder.FileSent), 'The outbound transfer should be accepted.');
    lAttachment := nil;
    AContext.AssertTrue(lFileSharing.DiscoveryEvent.WaitFor(5000) = wrSignaled,
      'The transfer should establish its discovery callback.');
    lExchange.SignalRoom('room@example', 'The room was lost.');
    AContext.AssertTrue(lRecorder.UploadEvent.WaitFor(50) = wrTimeout,
      'Cancellation must retain the transfer until its callback is drained.');
    lFileSharing.CompleteDiscovery;
    AContext.AssertTrue(lRecorder.UploadEvent.WaitFor(5000) = wrSignaled,
      'The drained callback should allow the transfer to finish.');
    AContext.AssertFalse(lRecorder.UploadSuccess,
      'The cancelled transfer must report failure.');
    AContext.AssertEquals('The room was lost.', string(lRecorder.UploadError),
      'The transfer should retain its own cancellation reason.');
    AContext.AssertEquals(0, lFileSharing.SentCount,
      'Cancellation before commitment must not submit a file share.');
    lExchange.Shutdown;
  finally
    lAttachment.Free;
    lExchange.Free;
    lRecorder.Free;
    lFileSharing.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestOutboundDelayedCallback(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lFactory: TFakeFileTransferExecutorFactory;
  lFile: TFileStream;
  lFileSharing: TFakeFileSharingModule;
  lPath: string;
  lRecorder: TFilePromptRecorder;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxdc');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lFileSharing := TFakeFileSharingModule.Create;
  lFileSharing.DelayDiscovery := True;
  lRecorder := TFilePromptRecorder.Create;
  lPath := GetTempFileName(lDirectory, 'send');
  lFile := TFileStream.Create(lPath, fmCreate);
  lFile.Free;
  lAttachment := TNXBotAttachment.Create;
  lAttachment.ID := 'delayed-artifact';
  lAttachment.Name := 'test.txt';
  lAttachment.Size := 0;
  lAttachment.Path := lPath;
  try
    AContext.AssertTrue(lExchange.AcceptOutbound(lAttachment, lFileSharing,
      'room@example', 'groupchat', '', '', 'room@example',
      @lRecorder.FileSent), 'The delayed-callback transfer should be accepted.');
    lAttachment := nil;
    AContext.AssertTrue(lFileSharing.DiscoveryEvent.WaitFor(5000) = wrSignaled,
      'The transfer should register its delayed callback.');
    AContext.AssertTrue(lRecorder.UploadEvent.WaitFor(0) = wrTimeout,
      'The transfer must remain pending until the callback arrives.');
    lFileSharing.CompleteDiscovery;
    AContext.AssertTrue(lRecorder.UploadEvent.WaitFor(5000) = wrSignaled,
      'The delayed callback should wake the transfer exactly once.');
    AContext.AssertTrue(lRecorder.UploadSuccess and
      (lFileSharing.SentCount = 1),
      'The delayed callback result should complete one file-share send.');
    lExchange.Shutdown;
  finally
    lAttachment.Free;
    lExchange.Free;
    lRecorder.Free;
    lFileSharing.Free;
    lFactory.Free;
    lConfig.Free;
    if FileExists(lPath) then DeleteFile(lPath);
    RemoveDir(lDirectory);
  end;
end;

procedure TestOutboundCommitBoundary(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lExecutor: TFakeFileTransferExecutor;
  lFactory: TFakeFileTransferExecutorFactory;
  lFile: TFileStream;
  lFileSharing: TFakeFileSharingModule;
  lPath: string;
  lRecorder: TFilePromptRecorder;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxoc');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lFactory.BlockUploads := True;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lFileSharing := TFakeFileSharingModule.Create;
  lRecorder := TFilePromptRecorder.Create;
  lPath := GetTempFileName(lDirectory, 'send');
  lFile := TFileStream.Create(lPath, fmCreate);
  lFile.Free;
  lAttachment := TNXBotAttachment.Create;
  try
    lAttachment.ID := 'cancel-before-commit';
    lAttachment.Name := 'test.txt';
    lAttachment.Size := 0;
    lAttachment.Path := lPath;
    AContext.AssertTrue(lExchange.AcceptOutbound(lAttachment, lFileSharing,
      'room@example', 'groupchat', '', '', 'room@example',
      @lRecorder.FileSent), 'The blocked upload should be accepted.');
    lAttachment := nil;
    lExecutor := TFakeFileTransferExecutor(lFactory.Executors[0]);
    AContext.AssertTrue(lExecutor.UploadStartedEvent.WaitFor(5000) =
      wrSignaled, 'The upload should reach the pre-commit barrier.');
    lExchange.SignalRoom('room@example', 'The room was lost before commit.');
    AContext.AssertTrue(lRecorder.UploadEvent.WaitFor(5000) = wrSignaled,
      'Cancellation before commitment should complete the transfer.');
    AContext.AssertTrue((not lRecorder.UploadSuccess) and
      (lFileSharing.SentCount = 0),
      'Cancellation must win before the file-share handoff.');

    lFactory.BlockUploads := False;
    lFileSharing.BlockSend := True;
    lAttachment := TNXBotAttachment.Create;
    lAttachment.ID := 'commit-before-cancel';
    lAttachment.Name := 'test.txt';
    lAttachment.Size := 0;
    lAttachment.Path := lPath;
    AContext.AssertTrue(lExchange.AcceptOutbound(lAttachment, lFileSharing,
      'room@example', 'groupchat', '', '', 'room@example',
      @lRecorder.FileSent), 'The committed upload should be accepted.');
    lAttachment := nil;
    lExecutor := TFakeFileTransferExecutor(
      lFactory.Executors[lFactory.Executors.Count - 1]);
    AContext.AssertTrue(lFileSharing.SendStartedEvent.WaitFor(5000) =
      wrSignaled, 'The transfer should reach the post-commit send boundary.');
    lExchange.SignalRoom('room@example', 'This cancellation is too late.');
    AContext.AssertFalse(lExecutor.Aborted,
      'Cancellation must not reverse an already committed transfer.');
    lFileSharing.ContinueSendEvent.SetEvent;
    AContext.AssertTrue(lRecorder.UploadEvent.WaitFor(5000) = wrSignaled,
      'The committed send should complete normally.');
    AContext.AssertTrue(lRecorder.UploadSuccess and
      (lFileSharing.SentCount = 1),
      'The committed file-share handoff should occur exactly once.');
    lExchange.Shutdown;
  finally
    lAttachment.Free;
    lExchange.Free;
    lRecorder.Free;
    lFileSharing.Free;
    lFactory.Free;
    lConfig.Free;
    if FileExists(lPath) then DeleteFile(lPath);
    RemoveDir(lDirectory);
  end;
end;

procedure TestInboundOwnershipAndRollback(AContext: TNXTestContext);
var
  lAttachment: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lFactory: TFakeFileTransferExecutorFactory;
  lPrompt: TNXBotPrompt;
  lRecorder: TFilePromptRecorder;
  lShares: TNXXMPPFileShareArray;
  lStagedPath: string;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxfx');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lConfig.FileMaximumBytes := 8;
  lConfig.StagedFileCapacity := 3;
  lConfig.StagedMaximumBytes := 16;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lRecorder := TFilePromptRecorder.Create;
  try
    lExchange.OnPromptReady := @lRecorder.Ready;
    SetLength(lShares, 1);
    lShares[0] := FileShare('https://files.example/one');
    lPrompt := TNXBotPrompt.Create(1, 'room@example', 'sender@example',
      'm1', 'inspect');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'A bounded file prompt should be accepted.');
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The exchange worker should complete the prompt.');
    AContext.AssertEquals('', string(lRecorder.Error),
      'Successful staging should have no error.');
    AContext.AssertEquals(1, lRecorder.Prompt.Attachments.Count,
      'The completed prompt should own its staged attachment.');
    lAttachment := lExchange.FindAttachment(
      lRecorder.Prompt.Attachments[0].ID);
    AContext.AssertTrue(Assigned(lAttachment) and
      FileExists(lAttachment.Path),
      'The exchange registry should authorize the staged artifact.');
    lStagedPath := lAttachment.Path;
    lAttachment.Free;
    lExchange.SignalRoom('room@example', 'This cancellation is too late.');
    lAttachment := lExchange.FindAttachment(
      lRecorder.Prompt.Attachments[0].ID);
    AContext.AssertTrue(Assigned(lAttachment) and
      FileExists(lAttachment.Path),
      'Cancellation must not reverse a committed artifact handoff.');
    lAttachment.Free;
    FreeAndNil(lRecorder.Prompt);

    SetLength(lShares, 2);
    lShares[0] := FileShare('https://files.example/first');
    lShares[1] := FileShare('https://files.example/fail');
    lPrompt := TNXBotPrompt.Create(2, 'room@example', 'sender@example',
      'm2', 'rollback');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'Capacity should be reserved for the complete multi-file operation.');
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'A failed multi-file operation should complete once.');
    AContext.AssertTrue(lRecorder.Error <> '',
      'A source failure should fail the whole prompt.');
    AContext.AssertEquals(0, lRecorder.Prompt.Attachments.Count,
      'A failed multi-file operation must not publish partial attachments.');
    FreeAndNil(lRecorder.Prompt);

    SetLength(lShares, 1);
    lShares[0] := FileShare('https://files.example/oversize');
    lShares[0].DeclaredSize := 9;
    lPrompt := TNXBotPrompt.Create(3, 'room@example', 'sender@example',
      'm3', 'reject');
    AContext.AssertFalse(lExchange.AcceptInbound(lPrompt, lShares),
      'Declared oversize work should reject before transfer.');
    lPrompt.Free;

    lExchange.Shutdown;
    AContext.AssertFalse(FileExists(lStagedPath),
      'Shutdown should delete artifacts after registry extraction.');
  finally
    lExchange.Free;
    lRecorder.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestIndependentTransferCancellation(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lFirst: TFakeFileTransferExecutor;
  lFactory: TFakeFileTransferExecutorFactory;
  lSecond: TFakeFileTransferExecutor;
  lPrompt: TNXBotPrompt;
  lRecorder: TFilePromptRecorder;
  lShares: TNXXMPPFileShareArray;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxfc');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lConfig.FileMaximumBytes := 8;
  lConfig.FileTransferCapacity := 2;
  lConfig.StagedFileCapacity := 4;
  lConfig.StagedMaximumBytes := 32;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lFactory.BlockDownloads := True;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lRecorder := TFilePromptRecorder.Create;
  try
    lExchange.OnPromptReady := @lRecorder.Ready;
    SetLength(lShares, 1);
    lShares[0] := FileShare('https://files.example/active');
    lPrompt := TNXBotPrompt.Create(10, 'active-room@example', 'sender@example',
      'active', 'active');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'The active transfer should be accepted.');
    lFirst := TFakeFileTransferExecutor(lFactory.Executors[0]);
    AContext.AssertTrue(lFirst.StartedEvent.WaitFor(5000) = wrSignaled,
      'The first transfer should enter its blocking executor.');
    lPrompt := TNXBotPrompt.Create(11, 'second-room@example', 'sender@example',
      'second', 'second');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'A second transfer should receive its own thread.');
    lSecond := TFakeFileTransferExecutor(lFactory.Executors[1]);
    AContext.AssertTrue(lSecond.StartedEvent.WaitFor(5000) = wrSignaled,
      'The second transfer must progress while the first is blocked.');
    lPrompt := TNXBotPrompt.Create(13, 'third-room@example',
      'sender@example', 'third', 'third');
    AContext.AssertFalse(lExchange.AcceptInbound(lPrompt, lShares),
      'Admission must stop at the configured simultaneous-transfer limit.');
    lPrompt.Free;
    AContext.AssertTrue(lRecorder.Event.WaitFor(0) = wrTimeout,
      'Rejected transfer construction must not run work or publish a prompt.');
    lExchange.SignalRoom('second-room@example', 'The second room was lost.');
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The matching transfer should complete after cancellation.');
    AContext.AssertTrue(lRecorder.Error = 'The second room was lost.',
      'Transfer cancellation should retain its terminal reason.');
    FreeAndNil(lRecorder.Prompt);
    AContext.AssertTrue(lSecond.Aborted and not lFirst.Aborted,
      'Room cancellation must interrupt only the matching executor.');
    lExchange.SignalRoom('active-room@example', 'The active room was lost.');
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'Active cancellation should complete after aborting the executor.');
    AContext.AssertTrue((lRecorder.Error = 'The active room was lost.') and
      Assigned(lRecorder.Prompt) and
      (lRecorder.Prompt.Attachments.Count = 0),
      'An aborted transfer must not publish or submit staged work.');
    FreeAndNil(lRecorder.Prompt);
    lPrompt := TNXBotPrompt.Create(12, 'shutdown-room@example',
      'sender@example', 'shutdown', 'shutdown');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'A transfer should be accepted before shutdown.');
    AContext.AssertTrue(TFakeFileTransferExecutor(
      lFactory.Executors[lFactory.Executors.Count - 1]).StartedEvent.WaitFor(
      5000) = wrSignaled,
      'The shutdown transfer should enter the blocking executor.');
    lExchange.Shutdown;
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'Shutdown should terminally complete active transfer work.');
    AContext.AssertTrue(Pos('shutdown', LowerCase(string(lRecorder.Error))) > 0,
      'Shutdown cancellation should be surfaced explicitly.');
    FreeAndNil(lRecorder.Prompt);
  finally
    lExchange.Free;
    lRecorder.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestInboundCommitBoundary(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lExecutor: TFakeFileTransferExecutor;
  lFactory: TFakeFileTransferExecutorFactory;
  lPrompt: TNXBotPrompt;
  lRecorder: TFilePromptRecorder;
  lShares: TNXXMPPFileShareArray;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxic');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lConfig.FileMaximumBytes := 8;
  lConfig.FileTransferCapacity := 2;
  lConfig.StagedFileCapacity := 2;
  lConfig.StagedMaximumBytes := 16;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lFactory.BlockDownloads := True;
  lFactory.IgnoreAbort := True;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lRecorder := TFilePromptRecorder.Create;
  try
    lExchange.OnPromptReady := @lRecorder.Ready;
    SetLength(lShares, 1);
    lShares[0] := FileShare('https://files.example/precommit');
    lPrompt := TNXBotPrompt.Create(30, 'room@example', 'sender@example',
      'precommit', 'precommit');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'The pre-commit transfer should be accepted.');
    lExecutor := TFakeFileTransferExecutor(lFactory.Executors[0]);
    AContext.AssertTrue(lExecutor.StartedEvent.WaitFor(5000) = wrSignaled,
      'The transfer should reach its final executor barrier.');
    lExchange.SignalRoom('room@example', 'Cancellation won commitment.');
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The cancelled transfer should complete once.');
    AContext.AssertTrue((lRecorder.Error =
      'Cancellation won commitment.') and Assigned(lRecorder.Prompt) and
      (lRecorder.Prompt.Attachments.Count = 0),
      'Cancellation immediately before commitment must prevent handoff.');
    FreeAndNil(lRecorder.Prompt);

    lFactory.BlockDownloads := False;
    lFactory.IgnoreAbort := False;
    lRecorder.BlockReady := True;
    lRecorder.ReadyStartedEvent.ResetEvent;
    lRecorder.ContinueReadyEvent.ResetEvent;
    lShares[0] := FileShare('https://files.example/committed');
    lPrompt := TNXBotPrompt.Create(31, 'room@example', 'sender@example',
      'committed', 'committed');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'The post-commit transfer should be accepted.');
    lExecutor := TFakeFileTransferExecutor(
      lFactory.Executors[lFactory.Executors.Count - 1]);
    AContext.AssertTrue(lRecorder.ReadyStartedEvent.WaitFor(5000) =
      wrSignaled, 'The transfer should reach its post-commit callback.');
    lExchange.SignalRoom('room@example', 'Cancellation lost commitment.');
    AContext.AssertFalse(lExecutor.Aborted,
      'Cancellation must not abort an already committed transfer.');
    lRecorder.ContinueReadyEvent.SetEvent;
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The committed prompt should complete normally.');
    AContext.AssertTrue((lRecorder.Error = '') and
      (lRecorder.Prompt.Attachments.Count = 1),
      'Commitment must preserve the completed prompt handoff.');
    AContext.AssertEquals(2, lRecorder.ReadyCount,
      'Each transfer should publish exactly one terminal prompt result.');
    FreeAndNil(lRecorder.Prompt);
    lExchange.Shutdown;
  finally
    lRecorder.ContinueReadyEvent.SetEvent;
    lExchange.Free;
    lRecorder.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestCancellationReasonContention(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lExecutor: TFakeFileTransferExecutor;
  lFactory: TFakeFileTransferExecutorFactory;
  lGate: TEvent;
  lPrompt: TNXBotPrompt;
  lRecorder: TFilePromptRecorder;
  lShares: TNXXMPPFileShareArray;
  lSignalOne: TSignalRoomThread;
  lSignalTwo: TSignalRoomThread;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxrc');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lConfig.FileMaximumBytes := 8;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lFactory.BlockAbort := True;
  lFactory.BlockDownloads := True;
  lFactory.IgnoreAbort := True;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lRecorder := TFilePromptRecorder.Create;
  lGate := TEvent.Create(nil, True, False, '');
  lExecutor := nil;
  lSignalOne := nil;
  lSignalTwo := nil;
  try
    lExchange.OnPromptReady := @lRecorder.Ready;
    SetLength(lShares, 1);
    lShares[0] := FileShare('https://files.example/contention');
    lPrompt := TNXBotPrompt.Create(32, 'room@example', 'sender@example',
      'contention', 'contention');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'The contended transfer should be accepted.');
    lExecutor := TFakeFileTransferExecutor(lFactory.Executors[0]);
    AContext.AssertTrue(lExecutor.StartedEvent.WaitFor(5000) = wrSignaled,
      'The transfer should reach its executor barrier.');
    lSignalOne := TSignalRoomThread.Create(lExchange, lGate,
      'room@example', 'First complete cancellation reason.');
    lSignalTwo := TSignalRoomThread.Create(lExchange, lGate,
      'room@example', 'Second complete cancellation reason.');
    lGate.SetEvent;
    AContext.AssertTrue(lExecutor.AbortStartedEvent.WaitFor(5000) =
      wrSignaled, 'One cancellation winner should enter executor abort.');
    lExecutor.ContinueAbortEvent.SetEvent;
    lSignalOne.WaitFor;
    lSignalTwo.WaitFor;
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The contended cancellation should complete the transfer.');
    AContext.AssertTrue((lRecorder.Error =
      'First complete cancellation reason.') or (lRecorder.Error =
      'Second complete cancellation reason.'),
      'The winning managed-string reason must be published intact.');
    AContext.AssertEquals(1, lExecutor.AbortCount,
      'Only the terminal-state winner may invoke executor abort.');
    AContext.AssertEquals(1, lRecorder.ReadyCount,
      'Contended cancellation must publish exactly one completion.');
    FreeAndNil(lRecorder.Prompt);
    lExchange.Shutdown;
  finally
    if Assigned(lExecutor) then lExecutor.ContinueAbortEvent.SetEvent;
    lGate.SetEvent;
    lSignalOne.Free;
    lSignalTwo.Free;
    lGate.Free;
    lExchange.Free;
    lRecorder.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestConcurrentStagingBounds(AContext: TNXTestContext);
var
  lAcceptedCount: Integer;
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lFactory: TFakeFileTransferExecutorFactory;
  lGate: TEvent;
  lPrompt: TNXBotPrompt;
  lRecorder: TFilePromptRecorder;
  lShares: TNXXMPPFileShareArray;
  lTransferOne: TAcceptInboundThread;
  lTransferTwo: TAcceptInboundThread;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxsb');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lConfig.FileMaximumBytes := 5;
  lConfig.FileTransferCapacity := 2;
  lConfig.StagedFileCapacity := 1;
  lConfig.StagedMaximumBytes := 5;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lFactory.BlockDownloads := True;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lRecorder := TFilePromptRecorder.Create;
  lGate := TEvent.Create(nil, True, False, '');
  SetLength(lShares, 1);
  lShares[0] := FileShare('https://files.example/bounded');
  lTransferOne := TAcceptInboundThread.Create(lExchange, lGate,
    TNXBotPrompt.Create(40, 'one@example', 'sender@example', 'one', 'one'),
    lShares);
  lTransferTwo := TAcceptInboundThread.Create(lExchange, lGate,
    TNXBotPrompt.Create(41, 'two@example', 'sender@example', 'two', 'two'),
    lShares);
  try
    lExchange.OnPromptReady := @lRecorder.Ready;
    lGate.SetEvent;
    lTransferOne.WaitFor;
    lTransferTwo.WaitFor;
    lAcceptedCount := Ord(lTransferOne.Accepted) + Ord(lTransferTwo.Accepted);
    AContext.AssertEquals(1, lAcceptedCount,
      'Exact staging bounds must admit only one concurrent reservation.');
    AContext.AssertEquals(1, lFactory.Executors.Count,
      'Rejected staging work must not construct a transfer executor.');
    if lTransferOne.Accepted then lTransferOne.Prompt := nil
    else FreeAndNil(lTransferOne.Prompt);
    if lTransferTwo.Accepted then lTransferTwo.Prompt := nil
    else FreeAndNil(lTransferTwo.Prompt);
    lExchange.SignalXMPP('The bounded transfer was cancelled.');
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The admitted bounded transfer should complete after cancellation.');
    FreeAndNil(lRecorder.Prompt);

    lFactory.BlockDownloads := False;
    lPrompt := TNXBotPrompt.Create(42, 'three@example', 'sender@example',
      'three', 'three');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'Completion must release staging capacity for the next transfer.');
    lPrompt := nil;
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The transfer admitted after release should complete normally.');
    FreeAndNil(lRecorder.Prompt);
    lExchange.Shutdown;
  finally
    lGate.SetEvent;
    lTransferOne.Free;
    lTransferTwo.Free;
    lGate.Free;
    lExchange.Free;
    lRecorder.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestBlockedAbortIsolation(AContext: TNXTestContext);
var
  lArtifact: TNXBotAttachment;
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lExecutor: TFakeFileTransferExecutor;
  lFactory: TFakeFileTransferExecutorFactory;
  lGate: TEvent;
  lPrompt: TNXBotPrompt;
  lRecorder: TFilePromptRecorder;
  lShares: TNXXMPPFileShareArray;
  lSignal: TSignalRoomThread;
  lStagedID: UTF8String;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxab');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lConfig.FileMaximumBytes := 8;
  lConfig.FileTransferCapacity := 1;
  lConfig.StagedFileCapacity := 3;
  lConfig.StagedMaximumBytes := 24;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lRecorder := TFilePromptRecorder.Create;
  lGate := TEvent.Create(nil, True, False, '');
  lSignal := nil;
  lExecutor := nil;
  try
    lExchange.OnPromptReady := @lRecorder.Ready;
    SetLength(lShares, 1);
    lShares[0] := FileShare('https://files.example/artifact');
    lPrompt := TNXBotPrompt.Create(50, 'artifact@example', 'sender@example',
      'artifact', 'artifact');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'The artifact setup transfer should be accepted.');
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The artifact setup transfer should complete.');
    lStagedID := lRecorder.Prompt.Attachments[0].ID;
    FreeAndNil(lRecorder.Prompt);

    lFactory.BlockAbort := True;
    lFactory.BlockDownloads := True;
    lPrompt := TNXBotPrompt.Create(51, 'blocked@example', 'sender@example',
      'blocked', 'blocked');
    AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
      'The abort-isolation transfer should be accepted.');
    lExecutor := TFakeFileTransferExecutor(
      lFactory.Executors[lFactory.Executors.Count - 1]);
    AContext.AssertTrue(lExecutor.StartedEvent.WaitFor(5000) = wrSignaled,
      'The transfer should enter its blocking executor.');
    lSignal := TSignalRoomThread.Create(lExchange, lGate,
      'blocked@example', 'The blocked transfer was cancelled.');
    lGate.SetEvent;
    AContext.AssertTrue(lExecutor.AbortStartedEvent.WaitFor(5000) =
      wrSignaled, 'Cancellation should block inside the executor fixture.');

    lArtifact := lExchange.FindAttachment(lStagedID);
    AContext.AssertTrue(Assigned(lArtifact),
      'Artifact lookup must proceed while an unrelated abort is blocked.');
    lArtifact.Free;
    lPrompt := TNXBotPrompt.Create(52, 'capacity@example', 'sender@example',
      'capacity', 'capacity');
    AContext.AssertFalse(lExchange.AcceptInbound(lPrompt, lShares),
      'Transfer admission must inspect capacity while abort is blocked.');
    lPrompt.Free;

    lExecutor.ContinueAbortEvent.SetEvent;
    lSignal.WaitFor;
    AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
      'The retained cancellation snapshot should complete safely.');
    AContext.AssertEquals(2, lRecorder.ReadyCount,
      'The cancelled transfer should publish one additional result.');
    FreeAndNil(lRecorder.Prompt);
    lExchange.Shutdown;
  finally
    if Assigned(lExecutor) then lExecutor.ContinueAbortEvent.SetEvent;
    lGate.SetEvent;
    lSignal.Free;
    lGate.Free;
    lExchange.Free;
    lRecorder.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestConstructorFailureBeforeAdmission(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lFactory: TFakeFileTransferExecutorFactory;
  lPrompt: TNXBotPrompt;
  lRecorder: TFilePromptRecorder;
  lShares: TNXXMPPFileShareArray;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxcf');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lConfig.FileMaximumBytes := 8;
  lConfig.FileTransferCapacity := 1;
  lConfig.StagedFileCapacity := 1;
  lConfig.StagedMaximumBytes := 8;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lFactory.RaiseOnCreate := True;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lRecorder := TFilePromptRecorder.Create;
  try
    lExchange.OnPromptReady := @lRecorder.Ready;
    SetLength(lShares, 1);
    lShares[0] := FileShare('https://files.example/constructor');
    lPrompt := TNXBotPrompt.Create(20, 'room@example', 'sender@example',
      'constructor', 'constructor');
    try
      try
        lExchange.AcceptInbound(lPrompt, lShares);
        AContext.Fail('Executor construction should fail deterministically.');
      except
        on E: Exception do
          AContext.AssertTrue(E.Message =
            'fixture executor construction failed',
            'The constructor failure should be surfaced unchanged.');
      end;
      AContext.AssertTrue(lRecorder.Event.WaitFor(0) = wrTimeout,
        'Constructor failure must not publish the caller-owned prompt.');
      lFactory.RaiseOnCreate := False;
      AContext.AssertTrue(lExchange.AcceptInbound(lPrompt, lShares),
        'Constructor failure must release admission and staging capacity.');
      lPrompt := nil;
      AContext.AssertTrue(lRecorder.Event.WaitFor(5000) = wrSignaled,
        'The next accepted transfer should complete normally.');
      AContext.AssertTrue((lRecorder.Error = '') and
        Assigned(lRecorder.Prompt),
        'The next transfer should publish the retained prompt exactly once.');
      FreeAndNil(lRecorder.Prompt);
    finally
      lPrompt.Free;
    end;
  finally
    lExchange.Free;
    lRecorder.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestShutdownDuringCandidateConstruction(AContext: TNXTestContext);
var
  lConfig: TNXBotHostConfig;
  lDirectory: string;
  lExchange: TNXBotFileExchange;
  lFactory: TFakeFileTransferExecutorFactory;
  lGate: TEvent;
  lRecorder: TFilePromptRecorder;
  lShares: TNXXMPPFileShareArray;
  lTransfer: TAcceptInboundThread;
begin
  lDirectory := GetTempFileName(GetTempDir(False), 'nxsc');
  DeleteFile(lDirectory);
  CreateDir(lDirectory);
  lConfig := TNXBotHostConfig.Create;
  lConfig.ExchangeDirectory := lDirectory;
  lConfig.FileMaximumBytes := 8;
  lFactory := TFakeFileTransferExecutorFactory.Create;
  lFactory.BlockCreate := True;
  lExchange := TNXBotFileExchange.Create(lConfig, @lFactory.CreateExecutor);
  lRecorder := TFilePromptRecorder.Create;
  lGate := TEvent.Create(nil, True, False, '');
  SetLength(lShares, 1);
  lShares[0] := FileShare('https://files.example/shutdown-construction');
  lTransfer := TAcceptInboundThread.Create(lExchange, lGate,
    TNXBotPrompt.Create(60, 'room@example', 'sender@example',
      'shutdown', 'shutdown'), lShares);
  try
    lExchange.OnPromptReady := @lRecorder.Ready;
    lGate.SetEvent;
    AContext.AssertTrue(lFactory.CreateStartedEvent.WaitFor(5000) =
      wrSignaled, 'Candidate construction should reach its barrier.');
    lExchange.Shutdown;
    lFactory.ContinueCreateEvent.SetEvent;
    lTransfer.WaitFor;
    AContext.AssertFalse(lTransfer.Accepted,
      'A candidate completed after admission closes must be rejected.');
    AContext.AssertTrue(lRecorder.Event.WaitFor(0) = wrTimeout,
      'The rejected candidate must not run or publish a callback.');
    lTransfer.Prompt.Free;
    lTransfer.Prompt := nil;
  finally
    lFactory.ContinueCreateEvent.SetEvent;
    lGate.SetEvent;
    lTransfer.Free;
    lGate.Free;
    lExchange.Free;
    lRecorder.Free;
    lFactory.Free;
    lConfig.Free;
    RemoveDir(lDirectory);
  end;
end;

procedure TestHTTPSBoundary(AContext: TNXTestContext);
const
  cHelloResponse: RawByteString = 'HTTP/1.1 200 OK'#13#10 +
    'Content-Length: 5'#13#10'Connection: close'#13#10#13#10'hello';
var
  lCAFile: string;
  lDestination: string;
  lExecutor: TNXBotSynapseFileTransferExecutor;
  lFailureServer: THTTPFixtureServer;
  lFixturePath: string;
  lRedirectServer: THTTPFixtureServer;
  lResult: TNXBotFileTransferResult;
  lServer: THTTPFixtureServer;
  lShare: TNXXMPPFileShare;
  lSlot: TNXXMPPHTTPUploadSlot;
  lTrusted: TStringList;
  lUploadFile: TFileStream;
  lUploadPath: string;
  lError: UTF8String;
begin
  lFixturePath := IncludeTrailingPathDelimiter(GetCurrentDir) +
    'NexusLib' + DirectorySeparator + 'net' + DirectorySeparator + 'tests' +
    DirectorySeparator + 'fixtures' + DirectorySeparator + 'xmpp' +
    DirectorySeparator;
  lCAFile := lFixturePath + 'ca.crt';
  AContext.AssertTrue(FileExists(lCAFile),
    'The synthetic HTTPS CA fixture should be available.');
  lTrusted := TStringList.Create;
  lExecutor := TNXBotSynapseFileTransferExecutor.Create;
  lDestination := GetTempFileName(GetTempDir(False), 'nxhd');
  DeleteFile(lDestination);
  try
    lServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', cHelloResponse);
    try
      lTrusted.Add('https://localhost:' + IntToStr(lServer.Port));
      lServer.Start;
      lShare := FileShare('https://localhost:' +
        UTF8String(IntToStr(lServer.Port)) + '/file');
      AContext.AssertTrue(lExecutor.Download(lShare, lDestination, lCAFile,
        5, 1000, lTrusted, lResult),
        'The real Synapse HTTPS boundary should stream a bounded response.');
      AContext.AssertEquals(5, lResult.ActualSize,
        'The HTTPS boundary should report the exact streamed size.');
    finally
      lServer.Free;
    end;

    lServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', cHelloResponse);
    try
      lTrusted.Add('https://localhost:' + IntToStr(lServer.Port));
      lServer.Start;
      lShare := FileShare('https://localhost:' +
        UTF8String(IntToStr(lServer.Port)) + '/wrong-hash');
      SetLength(lShare.Hashes, 1);
      lShare.Hashes[0].Algorithm := 'sha-256';
      lShare.Hashes[0].Value := 'not-the-file-hash';
      AContext.AssertFalse(lExecutor.Download(lShare, lDestination, lCAFile,
        5, 1000, lTrusted, lResult),
        'A streamed response with the wrong SHA-256 hash must fail.');
    finally
      lServer.Free;
    end;

    lFailureServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', 'HTTP/1.1 500 Failed'#13#10 +
      'Content-Length: 0'#13#10'Connection: close'#13#10#13#10);
    lServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', cHelloResponse);
    try
      lTrusted.Add('https://localhost:' + IntToStr(lFailureServer.Port));
      lTrusted.Add('https://localhost:' + IntToStr(lServer.Port));
      lFailureServer.Start;
      lServer.Start;
      lShare := FileShare('https://localhost:' +
        UTF8String(IntToStr(lFailureServer.Port)) + '/fail');
      SetLength(lShare.Sources, 2);
      lShare.Sources[1].URL := 'https://localhost:' +
        UTF8String(IntToStr(lServer.Port)) + '/success';
      AContext.AssertTrue(lExecutor.Download(lShare, lDestination, lCAFile,
        5, 1000, lTrusted, lResult) and
        (lResult.SourceURL = lShare.Sources[1].URL),
        'Supported sources should be attempted in wire order until success.');
    finally
      lServer.Free;
      lFailureServer.Free;
    end;

    lServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', cHelloResponse);
    lRedirectServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', 'HTTP/1.1 302 Found'#13#10 +
      'Location: https://localhost:' + RawByteString(IntToStr(lServer.Port)) +
      '/redirected'#13#10'Content-Length: 0'#13#10 +
      'Connection: close'#13#10#13#10);
    try
      lTrusted.Add('https://localhost:' + IntToStr(lRedirectServer.Port));
      lTrusted.Add('https://localhost:' + IntToStr(lServer.Port));
      lServer.Start;
      lRedirectServer.Start;
      lShare := FileShare('https://localhost:' +
        UTF8String(IntToStr(lRedirectServer.Port)) + '/redirect');
      AContext.AssertTrue(lExecutor.Download(lShare, lDestination, lCAFile,
        5, 1000, lTrusted, lResult),
        'A validated redirect should be followed through the real boundary.');
    finally
      lRedirectServer.Free;
      lServer.Free;
    end;

    lServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', 'HTTP/1.1 200 OK'#13#10 +
      'Content-Length: 10'#13#10'Connection: close'#13#10#13#10'hello');
    try
      lTrusted.Add('https://localhost:' + IntToStr(lServer.Port));
      lServer.Start;
      lShare := FileShare('https://localhost:' +
        UTF8String(IntToStr(lServer.Port)) + '/short');
      AContext.AssertFalse(lExecutor.Download(lShare, lDestination, lCAFile,
        10, 1000, lTrusted, lResult),
        'A response ending before Content-Length must fail.');
    finally
      lServer.Free;
    end;

    lServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', cHelloResponse);
    try
      lTrusted.Add('https://localhost:' + IntToStr(lServer.Port));
      lServer.Start;
      lShare := FileShare('https://localhost:' +
        UTF8String(IntToStr(lServer.Port)) + '/oversize');
      AContext.AssertFalse(lExecutor.Download(lShare, lDestination, lCAFile,
        4, 1000, lTrusted, lResult),
        'The streaming byte limit must stop an oversized response.');
    finally
      lServer.Free;
    end;

    lServer := THTTPFixtureServer.Create(lFixturePath + 'server.crt',
      lFixturePath + 'server.key', 'HTTP/1.1 201 Created'#13#10 +
      'Content-Length: 0'#13#10'Connection: close'#13#10#13#10);
    lUploadPath := GetTempFileName(GetTempDir(False), 'nxhu');
    lUploadFile := TFileStream.Create(lUploadPath, fmCreate);
    try
      lUploadFile.WriteBuffer('hello'[1], 5);
    finally
      lUploadFile.Free;
    end;
    try
      lTrusted.Add('https://localhost:' + IntToStr(lServer.Port));
      lSlot.PutURL := 'https://localhost:' +
        UTF8String(IntToStr(lServer.Port)) + '/upload';
      lSlot.GetURL := lSlot.PutURL;
      lServer.Start;
      AContext.AssertTrue(lExecutor.Upload(lUploadPath, lCAFile, lSlot,
        1000, lTrusted, lError),
        'The real HTTPS boundary should upload staged bytes: ' +
        string(lError));
      AContext.AssertTrue((Pos('PUT /upload', string(lServer.Request)) = 1) and
        (Pos('hello', string(lServer.Request)) > 0),
        'The fixture should receive the PUT body intact.');
    finally
      DeleteFile(lUploadPath);
      lServer.Free;
    end;
  finally
    if FileExists(lDestination) then DeleteFile(lDestination);
    lExecutor.Free;
    lTrusted.Free;
  end;
end;

procedure RegisterNXBotFileExchangeTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusBotHost.FileExchange');
  lSuite.AddTest('InboundOwnershipAndRollback',
    @TestInboundOwnershipAndRollback);
  lSuite.AddTest('IndependentTransferCancellation',
    @TestIndependentTransferCancellation);
  lSuite.AddTest('InboundCommitBoundary', @TestInboundCommitBoundary);
  lSuite.AddTest('CancellationReasonContention',
    @TestCancellationReasonContention);
  lSuite.AddTest('ConcurrentStagingBounds', @TestConcurrentStagingBounds);
  lSuite.AddTest('BlockedAbortIsolation', @TestBlockedAbortIsolation);
  lSuite.AddTest('ConstructorFailureBeforeAdmission',
    @TestConstructorFailureBeforeAdmission);
  lSuite.AddTest('ShutdownDuringCandidateConstruction',
    @TestShutdownDuringCandidateConstruction);
  lSuite.AddTest('OutboundSingleTransfer', @TestOutboundSingleTransfer);
  lSuite.AddTest('OutboundCancellationDrainsCallback',
    @TestOutboundCancellationDrainsCallback);
  lSuite.AddTest('OutboundDelayedCallback', @TestOutboundDelayedCallback);
  lSuite.AddTest('OutboundCommitBoundary', @TestOutboundCommitBoundary);
  lSuite.AddTest('HTTPSBoundary', @TestHTTPSBoundary);
end;

end.
