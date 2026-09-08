unit obNXBotFileExchange;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SyncObjs, SysUtils, obNXBotHostConfig,
  obNXXMPPFileSharing, tpNXBotFileTypes, tpNXBotHost, tpNXXMPPFileTypes;

type
  TNXBotFileTransferResult = record
    ActualSize: Int64;
    Error: UTF8String;
    HashSHA256: UTF8String;
    SourceURL: UTF8String;
  end;

  TNXBotFileTransferExecutor = class
  public
    function Download(const AShare: TNXXMPPFileShare;
      const ADestination, ACAFile: string; AMaximumBytes: Int64;
      ATimeoutMS: Cardinal; ATrustedOrigins: TStrings;
      out AResult: TNXBotFileTransferResult): Boolean; virtual; abstract;
    function Upload(const ASource, ACAFile: string;
      const ASlot: TNXXMPPHTTPUploadSlot; ATimeoutMS: Cardinal;
      ATrustedOrigins: TStrings;
      out AError: UTF8String): Boolean; virtual; abstract;
    procedure Abort; virtual; abstract;
  end;

  TNXBotFileTransferExecutorFactory = function:
    TNXBotFileTransferExecutor of object;

  TNXBotSynapseFileTransferExecutor = class(TNXBotFileTransferExecutor)
  private
    FCriticalSection: TRTLCriticalSection;
    FAbortRequested: Boolean;
    FHTTP: TObject;
    function BeginHTTP(AHTTP: TObject): Boolean;
    procedure EndHTTP;
  public
    constructor Create;
    destructor Destroy; override;
    function Download(const AShare: TNXXMPPFileShare;
      const ADestination, ACAFile: string; AMaximumBytes: Int64;
      ATimeoutMS: Cardinal; ATrustedOrigins: TStrings;
      out AResult: TNXBotFileTransferResult): Boolean; override;
    function Upload(const ASource, ACAFile: string;
      const ASlot: TNXXMPPHTTPUploadSlot; ATimeoutMS: Cardinal;
      ATrustedOrigins: TStrings;
      out AError: UTF8String): Boolean; override;
    procedure Abort; override;
  end;

  TNXBotFileExchange = class;
  TNXBotFilePromptEvent = procedure(ASender: TObject;
    APrompt: TNXBotPrompt; const AError: UTF8String) of object;

  TNXBotFileExchange = class
  private
    FAdmissionClosed: LongInt;
    FArtifacts: TObjectList;
    FArtifactBytes: Int64;
    FArtifactCriticalSection: TRTLCriticalSection;
    FCAFile: string;
    FDirectory: string;
    FExecutorFactory: TNXBotFileTransferExecutorFactory;
    FFileMaximumBytes: Int64;
    FReservedBytes: Int64;
    FReservedFiles: Integer;
    FTransferCapacity: Integer;
    FTransferCriticalSection: TRTLCriticalSection;
    FOnPromptReady: TNXBotFilePromptEvent;
    FStagedFileCapacity: Integer;
    FStagedMaximumBytes: Int64;
    FTimeoutMS: Cardinal;
    FTransfers: TObjectList;
    FTrustedOrigins: TStringList;
    procedure CommitArtifacts(AArtifacts: TObjectList;
      AReservedFiles: Integer; AReservedBytes: Int64);
    function CreateExecutor: TNXBotFileTransferExecutor;
    procedure ReapFinished;
    procedure ReleaseReservation(AFiles: Integer; ABytes: Int64);
    function ReserveStaging(AFiles: Integer; ABytes: Int64): Boolean;
  public
    constructor Create(AConfig: TNXBotHostConfig;
      AExecutorFactory: TNXBotFileTransferExecutorFactory = nil);
    destructor Destroy; override;
    function AcceptInbound(APrompt: TNXBotPrompt;
      const AShares: TNXXMPPFileShareArray): Boolean;
    function AcceptOutbound(AAttachment: TNXBotAttachment;
      AFileSharing: TNXXMPPFileSharingModule;
      const ATargetJID, AMessageType, AReplyJID, AReplyID,
      ARoomJID: UTF8String; ACompletion: TNXBotFileSendCompletion): Boolean;
    function FindAttachment(const AID: UTF8String): TNXBotAttachment;
    procedure SignalProvider(const AReason: UTF8String);
    procedure SignalRoom(const ARoomJID, AReason: UTF8String);
    procedure SignalXMPP(const AReason: UTF8String);
    procedure Shutdown;
    property OnPromptReady: TNXBotFilePromptEvent read FOnPromptReady
      write FOnPromptReady;
  end;

implementation

uses
  blcksock, httpsend, ssl_openssl3, synacode, synaip, synautil,
  obNXXMPPOpenSSL, utNXXMPPIDs;

type
  ENXBotFileLimit = class(Exception);

const
  cTransferActive: LongInt = 0;
  cTransferCancelled: LongInt = 1;
  cTransferCommitted: LongInt = 2;

type
  TNXBotFileTransferThread = class(TThread)
  private
    FCancelReason: UTF8String;
    FCancelReasonCriticalSection: TRTLCriticalSection;
    FExchange: TNXBotFileExchange;
    FExecutor: TNXBotFileTransferExecutor;
    FReferenceCount: LongInt;
    FRequiresProvider: Boolean;
    FRequiresXMPP: Boolean;
    FRoomJID: UTF8String;
    FTerminalState: LongInt;
    function Cancellation(out AReason: UTF8String): Boolean;
  protected
    function Commit(out AReason: UTF8String): Boolean;
    procedure Execute; override;
    procedure Finish(const AError: UTF8String); virtual; abstract;
    procedure Run(out AError: UTF8String); virtual; abstract;
    property Exchange: TNXBotFileExchange read FExchange;
    property Executor: TNXBotFileTransferExecutor read FExecutor;
  public
    constructor Create(AExchange: TNXBotFileExchange;
      const ARoomJID: UTF8String; ARequiresProvider,
      ARequiresXMPP: Boolean);
    destructor Destroy; override;
    procedure Release;
    procedure Retain;
    procedure SignalCancellation(const AReason: UTF8String);
    property RequiresProvider: Boolean read FRequiresProvider;
    property RequiresXMPP: Boolean read FRequiresXMPP;
    property RoomJID: UTF8String read FRoomJID;
  end;

  TNXBotBoundedFileStream = class(TFileStream)
  private
    FMaximum: Int64;
  public
    constructor Create(const AFileName: string; AMaximum: Int64);
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

  TNXBotFileReadStream = class(TStream)
  private
    FFile: TFileStream;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
  end;

  TNXBotPinnedSocket = class(TTCPBlockSocket)
  private
    FAddress: string;
    FHost: string;
  public
    constructor Create(const AAddress, AHost: string);
    procedure Connect(IP, Port: string); override;
  end;

  TNXBotPinnedHTTPSend = class(THTTPSend)
  public
    constructor Create(const AAddress, AHost: string);
  end;

  TNXBotInboundTransfer = class(TNXBotFileTransferThread)
  private
    FCompleted: TObjectList;
    FPrompt: TNXBotPrompt;
    FReservedBytes: Int64;
    FReservedFiles: Integer;
    FShares: TNXXMPPFileShareArray;
    function DownloadAttachment(const AShare: TNXXMPPFileShare;
      out AAttachment: TNXBotAttachment; out AError: UTF8String): Boolean;
  protected
    procedure Finish(const AError: UTF8String); override;
    procedure Run(out AError: UTF8String); override;
  public
    constructor Create(AExchange: TNXBotFileExchange; APrompt: TNXBotPrompt;
      const AShares: TNXXMPPFileShareArray; AReservedFiles: Integer;
      AReservedBytes: Int64);
    destructor Destroy; override;
  end;

  TNXBotOutboundTransfer = class(TNXBotFileTransferThread)
  private
    FAttachment: TNXBotAttachment;
    FCompletion: TNXBotFileSendCompletion;
    FFileSharing: TNXXMPPFileSharingModule;
    FMessageType: UTF8String;
    FReplyID: UTF8String;
    FReplyJID: UTF8String;
    FResultError: UTF8String;
    FResultEvent: TEvent;
    FService: TNXXMPPHTTPUploadService;
    FSlot: TNXXMPPHTTPUploadSlot;
    FTargetJID: UTF8String;
    procedure Discovered(ASender: TObject;
      const AService: TNXXMPPHTTPUploadService; const AError: UTF8String);
    procedure SlotReady(ASender: TObject;
      const ASlot: TNXXMPPHTTPUploadSlot; const AError: UTF8String);
    function WaitForCallback(out AError: UTF8String): Boolean;
  protected
    procedure Finish(const AError: UTF8String); override;
    procedure Run(out AError: UTF8String); override;
  public
    constructor Create(AExchange: TNXBotFileExchange;
      AAttachment: TNXBotAttachment; AFileSharing: TNXXMPPFileSharingModule;
      const ATargetJID, AMessageType, AReplyJID, AReplyID,
      ARoomJID: UTF8String; ACompletion: TNXBotFileSendCompletion);
    destructor Destroy; override;
  end;

constructor TNXBotBoundedFileStream.Create(const AFileName: string;
  AMaximum: Int64);
begin
  inherited Create(AFileName, fmCreate or fmShareDenyWrite);
  FMaximum := AMaximum;
end;

function TNXBotBoundedFileStream.Write(const ABuffer;
  ACount: LongInt): LongInt;
begin
  if (ACount < 0) or (Position > FMaximum) or
    (Int64(ACount) > FMaximum - Position) then
    raise ENXBotFileLimit.Create('The downloaded file exceeds the byte limit.');
  Result := inherited Write(ABuffer, ACount);
end;

constructor TNXBotFileReadStream.Create(const AFileName: string);
begin
  inherited Create;
  FFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
end;

destructor TNXBotFileReadStream.Destroy;
begin
  FFile.Free;
  inherited Destroy;
end;

function TNXBotFileReadStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  Result := FFile.Read(ABuffer, ACount);
end;

function TNXBotFileReadStream.Seek(const AOffset: Int64;
  AOrigin: TSeekOrigin): Int64;
begin
  Result := FFile.Seek(AOffset, AOrigin);
end;

constructor TNXBotPinnedSocket.Create(const AAddress, AHost: string);
begin
  inherited Create;
  FAddress := AAddress;
  FHost := AHost;
end;

procedure TNXBotPinnedSocket.Connect(IP, Port: string);
begin
  SSL.SNIHost := FHost;
  inherited Connect(FAddress, Port);
end;

constructor TNXBotPinnedHTTPSend.Create(const AAddress, AHost: string);
begin
  inherited Create;
  FSock.Free;
  FSock := TNXBotPinnedSocket.Create(AAddress, AHost);
  FSock.Owner := Self;
  FSock.ConvertLineEnd := True;
  FSock.SizeRecvBuffer := 65536;
  FSock.SizeSendBuffer := 65536;
end;

function NXBotHeaderValue(AHeaders: TStrings;
  const AName: string): string;
var
  lIndex: Integer;
  lPrefix: string;
begin
  Result := '';
  lPrefix := LowerCase(AName) + ':';
  for lIndex := 0 to AHeaders.Count - 1 do
    if Pos(lPrefix, LowerCase(AHeaders[lIndex])) = 1 then
      Exit(Trim(Copy(AHeaders[lIndex], Length(lPrefix) + 1, MaxInt)));
end;

function NXBotIPv4Public(const AValue: string): Boolean;
var
  lA: array[0..3] of Integer;
  lIndex: Integer;
  lPart: string;
  lRest: string;
  lSeparator: Integer;
begin
  lRest := AValue;
  for lIndex := 0 to 3 do
  begin
    lSeparator := Pos('.', lRest);
    if (lSeparator = 0) and (lIndex < 3) then Exit(False);
    if lSeparator = 0 then lPart := lRest
    else lPart := Copy(lRest, 1, lSeparator - 1);
    if not TryStrToInt(lPart, lA[lIndex]) or
      (lA[lIndex] < 0) or (lA[lIndex] > 255) then Exit(False);
    if lSeparator > 0 then Delete(lRest, 1, lSeparator)
    else lRest := '';
  end;
  Result := not ((lA[0] = 0) or (lA[0] = 10) or (lA[0] = 127) or
    (lA[0] >= 224) or ((lA[0] = 169) and (lA[1] = 254)) or
    ((lA[0] = 172) and (lA[1] >= 16) and (lA[1] <= 31)) or
    ((lA[0] = 192) and (lA[1] = 168)) or
    ((lA[0] = 100) and (lA[1] >= 64) and (lA[1] <= 127)) or
    ((lA[0] = 192) and (lA[1] = 0) and (lA[2] = 0)) or
    ((lA[0] = 192) and (lA[1] = 0) and (lA[2] = 2)) or
    ((lA[0] = 198) and (lA[1] in [18, 19])) or
    ((lA[0] = 198) and (lA[1] = 51) and (lA[2] = 100)) or
    ((lA[0] = 203) and (lA[1] = 0) and (lA[2] = 113)));
end;

function NXBotIPAddressPublic(const AValue: string): Boolean;
var
  lValue: string;
begin
  if IsIP(AValue) then
    Exit(NXBotIPv4Public(AValue));
  if not IsIP6(AValue) then
    Exit(False);
  lValue := LowerCase(AValue);
  Result := not ((lValue = '::') or (lValue = '::1') or
    (Pos('fc', lValue) = 1) or (Pos('fd', lValue) = 1) or
    (Pos('fe8', lValue) = 1) or (Pos('fe9', lValue) = 1) or
    (Pos('fea', lValue) = 1) or (Pos('feb', lValue) = 1) or
    (Pos('ff', lValue) = 1) or (Pos('2001:db8:', lValue) = 1));
end;

function NXBotValidateURL(const AURL: UTF8String; ATrustedOrigins: TStrings;
  out AOrigin: UTF8String; out AHost, AAddress: string;
  out AError: UTF8String): Boolean;
var
  lHost: string;
  lIPs: TStringList;
  lIndex: Integer;
  lPara: string;
  lPass: string;
  lPath: string;
  lPort: string;
  lProtocol: string;
  lSocket: TTCPBlockSocket;
  lUser: string;
  lTrusted: Boolean;
begin
  Result := False;
  AError := '';
  AAddress := '';
  AHost := '';
  ParseURL(string(AURL), lProtocol, lUser, lPass, lHost, lPort,
    lPath, lPara);
  if (not SameText(lProtocol, 'https')) or (lHost = '') or
    (Pos('#', string(AURL)) > 0) then
  begin
    AError := 'The file source must use HTTPS with a DNS hostname.';
    Exit;
  end;
  if (lUser <> '') or (lPass <> '') then
  begin
    AError := 'The file source contains prohibited user information.';
    Exit;
  end;
  if IsIP(lHost) or IsIP6(lHost) then
  begin
    AError := 'The file source must use a DNS hostname.';
    Exit;
  end;
  if lPort = '' then lPort := '443';
  if not TryStrToInt(lPort, lIndex) or (lIndex < 1) or (lIndex > 65535) then
  begin
    AError := 'The file source port is invalid.';
    Exit;
  end;
  AOrigin := 'https://' + UTF8String(LowerCase(lHost)) + ':' +
    UTF8String(lPort);
  lTrusted := Assigned(ATrustedOrigins) and
    (ATrustedOrigins.IndexOf(string(AOrigin)) >= 0);
  lIPs := TStringList.Create;
  lSocket := TTCPBlockSocket.Create;
  try
    lSocket.ResolveNameToIP(lHost, lIPs);
    if lIPs.Count = 0 then
    begin
      AError := 'The file source hostname did not resolve.';
      Exit;
    end;
    if not lTrusted then
      for lIndex := 0 to lIPs.Count - 1 do
        if not NXBotIPAddressPublic(lIPs[lIndex]) then
        begin
          AError := 'The file source resolves to a prohibited address.';
          Exit;
        end;
    AHost := lHost;
    AAddress := lIPs[0];
    for lIndex := 0 to lIPs.Count - 1 do
      if IsIP(lIPs[lIndex]) then
      begin
        AAddress := lIPs[lIndex];
        Break;
      end;
  finally
    lSocket.Free;
    lIPs.Free;
  end;
  Result := True;
end;

function NXBotRedirectURL(const ACurrent: UTF8String;
  const ALocation: string): UTF8String;
var
  lHost: string;
  lOrigin: UTF8String;
  lPara: string;
  lPass: string;
  lPath: string;
  lPort: string;
  lProtocol: string;
  lSlash: Integer;
  lUser: string;
begin
  if Pos('://', ALocation) > 0 then
    Exit(UTF8String(ALocation));
  ParseURL(string(ACurrent), lProtocol, lUser, lPass, lHost, lPort,
    lPath, lPara);
  if not SameText(lProtocol, 'https') or (lHost = '') then
    Exit('');
  if lPort = '' then lPort := '443';
  lOrigin := 'https://' + UTF8String(LowerCase(lHost)) + ':' +
    UTF8String(lPort);
  if (ALocation <> '') and (ALocation[1] = '/') then
    Exit(lOrigin + UTF8String(ALocation));
  Result := ACurrent;
  lSlash := RPos('/', string(Result));
  if lSlash > Pos('://', string(Result)) + 2 then
    SetLength(Result, lSlash);
  Result := Result + UTF8String(ALocation);
end;

constructor TNXBotSynapseFileTransferExecutor.Create;
begin
  inherited Create;
  InitCriticalSection(FCriticalSection);
end;

function TNXBotSynapseFileTransferExecutor.BeginHTTP(AHTTP: TObject): Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try
    Result := not FAbortRequested;
    if Result then
      FHTTP := AHTTP;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TNXBotSynapseFileTransferExecutor.EndHTTP;
begin
  EnterCriticalSection(FCriticalSection);
  try
    FHTTP := nil;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

destructor TNXBotSynapseFileTransferExecutor.Destroy;
begin
  Abort;
  DoneCriticalSection(FCriticalSection);
  inherited Destroy;
end;

procedure TNXBotSynapseFileTransferExecutor.Abort;
var
  lHTTP: THTTPSend;
begin
  EnterCriticalSection(FCriticalSection);
  try
    FAbortRequested := True;
    lHTTP := THTTPSend(FHTTP);
    if Assigned(lHTTP) then
      lHTTP.Abort;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

function TNXBotSynapseFileTransferExecutor.Download(
  const AShare: TNXXMPPFileShare; const ADestination, ACAFile: string;
  AMaximumBytes: Int64; ATimeoutMS: Cardinal; ATrustedOrigins: TStrings;
  out AResult: TNXBotFileTransferResult): Boolean;
var
  lContentLength: Int64;
  lDigest: RawByteString;
  lError: UTF8String;
  lExpectedHash: UTF8String;
  lFile: TNXBotBoundedFileStream;
  lHTTP: THTTPSend;
  lAddress: string;
  lHost: string;
  lIndex: Integer;
  lOrigin: UTF8String;
  lRead: TFileStream;
  lRedirect: Integer;
  lSource: Integer;
  lTimeout: Integer;
  lURL: UTF8String;
  lWasRedirect: Boolean;
begin
  AResult := Default(TNXBotFileTransferResult);
  Result := False;
  lExpectedHash := '';
  for lIndex := 0 to High(AShare.Hashes) do
    if SameText(string(AShare.Hashes[lIndex].Algorithm), 'sha-256') then
      lExpectedHash := AShare.Hashes[lIndex].Value;
  if ATimeoutMS > Cardinal(High(Integer)) then lTimeout := High(Integer)
  else lTimeout := ATimeoutMS;
  for lSource := 0 to High(AShare.Sources) do
  begin
    lURL := AShare.Sources[lSource].URL;
    for lRedirect := 0 to 3 do
    begin
      lContentLength := -1;
      lWasRedirect := False;
      if not NXBotValidateURL(lURL, ATrustedOrigins, lOrigin, lHost,
        lAddress, lError) then
        Break;
      if FileExists(ADestination) then DeleteFile(ADestination);
      lFile := TNXBotBoundedFileStream.Create(ADestination, AMaximumBytes);
      lHTTP := TNXBotPinnedHTTPSend.Create(lAddress, lHost);
      try
        lHTTP.Timeout := lTimeout;
        lHTTP.Sock.ConnectionTimeout := lTimeout;
        lHTTP.Sock.SSL.VerifyCert := True;
        lHTTP.Sock.SSL.CertCAFile := ACAFile;
        lHTTP.UserAgent := 'NexusBotHost/1.0';
        lHTTP.OutputStream := lFile;
        if not BeginHTTP(lHTTP) then
          lError := 'The file transfer was cancelled.'
        else try
          if not lHTTP.HTTPMethod('GET', string(lURL)) then
            lError := 'The HTTPS download failed.'
          else if (lHTTP.ResultCode >= 300) and (lHTTP.ResultCode < 400) then
          begin
            lWasRedirect := True;
            if lRedirect = 3 then
              lError := 'The HTTPS download exceeded the redirect limit.'
            else
            begin
              lURL := NXBotRedirectURL(lURL,
                NXBotHeaderValue(lHTTP.Headers, 'Location'));
              if lURL = '' then lError := 'The HTTPS redirect is invalid.'
              else lError := '';
            end;
          end
          else if (lHTTP.ResultCode < 200) or (lHTTP.ResultCode >= 300) then
            lError := 'The HTTPS download returned a non-success status.'
          else
          begin
            lError := '';
            if not TryStrToInt64(NXBotHeaderValue(lHTTP.Headers,
              'Content-Length'), lContentLength) then
              lContentLength := -1;
          end;
        except
          on E: Exception do lError := UTF8String(E.Message);
        end;
      finally
        EndHTTP;
        lHTTP.Free;
        lFile.Free;
      end;
      if (lError = '') and lWasRedirect then
        Continue;
      if lError = '' then
      begin
        lRead := TFileStream.Create(ADestination,
          fmOpenRead or fmShareDenyWrite);
        try
          AResult.ActualSize := lRead.Size;
        finally
          lRead.Free;
        end;
        if (lContentLength >= 0) and
          (AResult.ActualSize <> lContentLength) then
          lError := 'The HTTPS download ended before its declared length.'
        else if AShare.HasSize and
          (AResult.ActualSize <> AShare.DeclaredSize) then
          lError := 'The downloaded size does not match the file metadata.'
        else
        begin
          lRead := TFileStream.Create(ADestination,
            fmOpenRead or fmShareDenyWrite);
          try
            lDigest := TNXXMPPOpenSSL.SHA256Stream(lRead);
          finally
            lRead.Free;
          end;
          AResult.HashSHA256 := UTF8String(EncodeBase64(lDigest));
          if (lExpectedHash <> '') and
            (AResult.HashSHA256 <> lExpectedHash) then
            lError := 'The downloaded SHA-256 hash does not match.'
          else
          begin
            AResult.SourceURL := lURL;
            Exit(True);
          end;
        end;
      end;
    end;
    if FileExists(ADestination) then DeleteFile(ADestination);
    AResult.Error := lError;
  end;
end;

function TNXBotSynapseFileTransferExecutor.Upload(const ASource,
  ACAFile: string; const ASlot: TNXXMPPHTTPUploadSlot; ATimeoutMS: Cardinal;
  ATrustedOrigins: TStrings;
  out AError: UTF8String): Boolean;
var
  lFile: TNXBotFileReadStream;
  lHTTP: THTTPSend;
  lAddress: string;
  lGetAddress: string;
  lGetHost: string;
  lHost: string;
  lIndex: Integer;
  lTimeout: Integer;
  lOrigin: UTF8String;
begin
  Result := False;
  AError := '';
  if not NXBotValidateURL(ASlot.PutURL, ATrustedOrigins, lOrigin, lHost,
    lAddress, AError) or
    not NXBotValidateURL(ASlot.GetURL, ATrustedOrigins, lOrigin, lGetHost,
    lGetAddress, AError) then
    Exit;
  if ATimeoutMS > Cardinal(High(Integer)) then lTimeout := High(Integer)
  else lTimeout := ATimeoutMS;
  lFile := TNXBotFileReadStream.Create(ASource);
  lHTTP := TNXBotPinnedHTTPSend.Create(lAddress, lHost);
  try
    lHTTP.Timeout := lTimeout;
    lHTTP.Sock.ConnectionTimeout := lTimeout;
    lHTTP.Sock.SSL.VerifyCert := True;
    lHTTP.Sock.SSL.CertCAFile := ACAFile;
    lHTTP.InputStream := lFile;
    for lIndex := 0 to High(ASlot.Headers) do
      lHTTP.Headers.Add(string(ASlot.Headers[lIndex].Name + ': ' +
        ASlot.Headers[lIndex].Value));
    if not BeginHTTP(lHTTP) then
      AError := 'The file upload was cancelled.'
    else try
      Result := lHTTP.HTTPMethod('PUT', string(ASlot.PutURL)) and
        (lHTTP.ResultCode >= 200) and (lHTTP.ResultCode < 300);
      if not Result then
        AError := 'The HTTPS upload failed or returned a non-success status.';
    except
      on E: Exception do AError := UTF8String(E.Message);
    end;
  finally
    EndHTTP;
    lHTTP.Free;
    lFile.Free;
  end;
end;

constructor TNXBotFileTransferThread.Create(AExchange: TNXBotFileExchange;
  const ARoomJID: UTF8String; ARequiresProvider, ARequiresXMPP: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  InitCriticalSection(FCancelReasonCriticalSection);
  FReferenceCount := 1;
  FTerminalState := cTransferActive;
  FExchange := AExchange;
  FExecutor := AExchange.CreateExecutor;
  FRoomJID := ARoomJID;
  FRequiresProvider := ARequiresProvider;
  FRequiresXMPP := ARequiresXMPP;
end;

destructor TNXBotFileTransferThread.Destroy;
begin
  Terminate;
  inherited Destroy;
  FExecutor.Free;
  DoneCriticalSection(FCancelReasonCriticalSection);
end;

function TNXBotFileTransferThread.Cancellation(
  out AReason: UTF8String): Boolean;
begin
  Result := InterlockedCompareExchange(FTerminalState, cTransferActive,
    cTransferActive) = cTransferCancelled;
  if not Result then
  begin
    AReason := '';
    Exit;
  end;
  EnterCriticalSection(FCancelReasonCriticalSection);
  try
    AReason := FCancelReason;
  finally
    LeaveCriticalSection(FCancelReasonCriticalSection);
  end;
end;

function TNXBotFileTransferThread.Commit(out AReason: UTF8String): Boolean;
begin
  Result := InterlockedCompareExchange(FTerminalState, cTransferCommitted,
    cTransferActive) = cTransferActive;
  if Result then AReason := ''
  else Cancellation(AReason);
end;

procedure TNXBotFileTransferThread.Execute;
var
  lCancelReason: UTF8String;
  lError: UTF8String;
begin
  if Terminated then Exit;
  lError := '';
  try
    if Cancellation(lError) then
      { The cancellation reason is the result. }
    else
      Run(lError);
  except
    on E: Exception do
      lError := 'The file transfer failed: ' + UTF8String(E.Message);
  end;
  if Cancellation(lCancelReason) then
    lError := lCancelReason;
  Finish(lError);
end;

procedure TNXBotFileTransferThread.Release;
begin
  if InterlockedDecrement(FReferenceCount) = 0 then
    Free;
end;

procedure TNXBotFileTransferThread.Retain;
begin
  InterlockedIncrement(FReferenceCount);
end;

procedure TNXBotFileTransferThread.SignalCancellation(
  const AReason: UTF8String);
var
  lSignal: Boolean;
begin
  EnterCriticalSection(FCancelReasonCriticalSection);
  try
    lSignal := InterlockedCompareExchange(FTerminalState,
      cTransferCancelled, cTransferActive) = cTransferActive;
    if lSignal then FCancelReason := AReason;
  finally
    LeaveCriticalSection(FCancelReasonCriticalSection);
  end;
  if lSignal then FExecutor.Abort;
end;

constructor TNXBotInboundTransfer.Create(AExchange: TNXBotFileExchange;
  APrompt: TNXBotPrompt; const AShares: TNXXMPPFileShareArray;
  AReservedFiles: Integer; AReservedBytes: Int64);
begin
  inherited Create(AExchange, APrompt.RoomJID, True, True);
  FCompleted := TObjectList.Create(True);
  FShares := Copy(AShares);
  FReservedFiles := AReservedFiles;
  FReservedBytes := AReservedBytes;
  FPrompt := APrompt;
end;

destructor TNXBotInboundTransfer.Destroy;
var
  lIndex: Integer;
begin
  if Assigned(FCompleted) then
    for lIndex := 0 to FCompleted.Count - 1 do
      if FileExists(TNXBotAttachment(FCompleted[lIndex]).Path) then
        DeleteFile(TNXBotAttachment(FCompleted[lIndex]).Path);
  FCompleted.Free;
  FPrompt.Free;
  inherited Destroy;
end;

function TNXBotInboundTransfer.DownloadAttachment(
  const AShare: TNXXMPPFileShare; out AAttachment: TNXBotAttachment;
  out AError: UTF8String): Boolean;
var
  lID: UTF8String;
  lPartial: string;
  lPath: string;
  lResult: TNXBotFileTransferResult;
begin
  AAttachment := nil;
  lID := NXXMPPCreateID;
  lPartial := IncludeTrailingPathDelimiter(Exchange.FDirectory) +
    string(lID) + '.part';
  lPath := IncludeTrailingPathDelimiter(Exchange.FDirectory) +
    string(lID) + '.bin';
  Result := Executor.Download(AShare, lPartial, Exchange.FCAFile,
    Exchange.FFileMaximumBytes, Exchange.FTimeoutMS,
    Exchange.FTrustedOrigins, lResult);
  if not Result then
  begin
    AError := lResult.Error;
    if FileExists(lPartial) then DeleteFile(lPartial);
    Exit;
  end;
  if not RenameFile(lPartial, lPath) then
  begin
    AError := 'The verified attachment could not be staged.';
    if FileExists(lPartial) then DeleteFile(lPartial);
    Exit(False);
  end;
  AAttachment := TNXBotAttachment.Create;
  AAttachment.ID := lID;
  AAttachment.ArtifactID := lID;
  AAttachment.Name := AShare.Name;
  AAttachment.Description := AShare.Description;
  AAttachment.MediaType := AShare.MediaType;
  AAttachment.Size := lResult.ActualSize;
  AAttachment.HashSHA256 := lResult.HashSHA256;
  AAttachment.Path := lPath;
  AAttachment.SFSID := AShare.ID;
  AAttachment.Disposition := AShare.Disposition;
  AAttachment.SourceURL := lResult.SourceURL;
  AAttachment.Origin := bfoInboundXMPP;
end;

procedure TNXBotInboundTransfer.Run(out AError: UTF8String);
var
  lAttachment: TNXBotAttachment;
  lArtifacts: TObjectList;
  lIndex: Integer;
begin
  for lIndex := 0 to High(FShares) do
  begin
    if Cancellation(AError) then Exit;
    if not DownloadAttachment(FShares[lIndex], lAttachment, AError) then Exit;
    FCompleted.Add(lAttachment);
  end;
  lArtifacts := TObjectList.Create(True);
  try
    for lIndex := 0 to FCompleted.Count - 1 do
      lArtifacts.Add(TNXBotAttachment(FCompleted[lIndex]).Clone);
    if not Commit(AError) then Exit;
    Exchange.CommitArtifacts(lArtifacts, FReservedFiles, FReservedBytes);
    FReservedFiles := 0;
    FReservedBytes := 0;
  finally
    lArtifacts.Free;
  end;
  while FCompleted.Count > 0 do
    FPrompt.AddAttachment(TNXBotAttachment(FCompleted.Extract(
      FCompleted[0])));
  AError := '';
end;

procedure TNXBotInboundTransfer.Finish(const AError: UTF8String);
begin
  if (FReservedFiles <> 0) or (FReservedBytes <> 0) then
    Exchange.ReleaseReservation(FReservedFiles, FReservedBytes);
  FReservedFiles := 0;
  FReservedBytes := 0;
  if Assigned(Exchange.FOnPromptReady) then
    Exchange.FOnPromptReady(Exchange, FPrompt, AError)
  else
    FPrompt.Free;
  FPrompt := nil;
end;

constructor TNXBotOutboundTransfer.Create(AExchange: TNXBotFileExchange;
  AAttachment: TNXBotAttachment; AFileSharing: TNXXMPPFileSharingModule;
  const ATargetJID, AMessageType, AReplyJID, AReplyID,
  ARoomJID: UTF8String; ACompletion: TNXBotFileSendCompletion);
begin
  inherited Create(AExchange, ARoomJID, True, True);
  FResultEvent := TEvent.Create(nil, False, False, '');
  FFileSharing := AFileSharing;
  FTargetJID := ATargetJID;
  FMessageType := AMessageType;
  FReplyJID := AReplyJID;
  FReplyID := AReplyID;
  FCompletion := ACompletion;
  FAttachment := AAttachment;
end;

destructor TNXBotOutboundTransfer.Destroy;
begin
  FResultEvent.Free;
  FAttachment.Free;
  inherited Destroy;
end;

procedure TNXBotOutboundTransfer.Discovered(ASender: TObject;
  const AService: TNXXMPPHTTPUploadService; const AError: UTF8String);
begin
  FService := AService;
  FResultError := AError;
  FResultEvent.SetEvent;
end;

procedure TNXBotOutboundTransfer.SlotReady(ASender: TObject;
  const ASlot: TNXXMPPHTTPUploadSlot; const AError: UTF8String);
begin
  FSlot := ASlot;
  FResultError := AError;
  FResultEvent.SetEvent;
end;

function TNXBotOutboundTransfer.WaitForCallback(
  out AError: UTF8String): Boolean;
begin
  FResultEvent.WaitFor(INFINITE);
  Result := not Cancellation(AError);
  if Result then
  begin
    AError := FResultError;
    Result := AError = '';
  end;
end;

procedure TNXBotOutboundTransfer.Run(out AError: UTF8String);
var
  lShare: TNXXMPPFileShare;
begin
  FResultError := '';
  if not FFileSharing.DiscoverUploadService(FAttachment.Size,
    @Discovered) then
  begin
    AError := 'The upload-service request could not be queued.';
    Exit;
  end;
  if not WaitForCallback(AError) then Exit;

  FResultError := '';
  if not FFileSharing.RequestUploadSlot(FService.JID, FAttachment.Name,
    FAttachment.MediaType, FAttachment.Size, @SlotReady) then
  begin
    AError := 'The upload-slot request could not be queued.';
    Exit;
  end;
  if not WaitForCallback(AError) then Exit;
  if Cancellation(AError) then Exit;
  if not Executor.Upload(FAttachment.Path, Exchange.FCAFile, FSlot,
    Exchange.FTimeoutMS, Exchange.FTrustedOrigins, AError) then
  begin
    if AError = '' then AError := 'The file upload failed.';
    Exit;
  end;
  if Cancellation(AError) then Exit;

  lShare := Default(TNXXMPPFileShare);
  lShare.ID := FAttachment.SFSID;
  if lShare.ID = '' then lShare.ID := FAttachment.ID;
  lShare.Disposition := FAttachment.Disposition;
  lShare.Name := FAttachment.Name;
  lShare.Description := FAttachment.Description;
  lShare.MediaType := FAttachment.MediaType;
  lShare.HasSize := True;
  lShare.DeclaredSize := FAttachment.Size;
  SetLength(lShare.Hashes, 1);
  lShare.Hashes[0].Algorithm := 'sha-256';
  lShare.Hashes[0].Value := FAttachment.HashSHA256;
  SetLength(lShare.Sources, 1);
  lShare.Sources[0].URL := FSlot.GetURL;
  if not Commit(AError) then Exit;
  if not FFileSharing.SendFileShare(FTargetJID, FMessageType,
    FReplyJID, FReplyID, lShare) then
    AError := 'The XMPP file-share message could not be queued.'
  else
    AError := '';
end;

procedure TNXBotOutboundTransfer.Finish(const AError: UTF8String);
var
  lCompletion: TNXBotFileSendCompletion;
begin
  lCompletion := FCompletion;
  FCompletion := nil;
  if Assigned(lCompletion) then
    if AError = '' then
      lCompletion(True, 'The file was uploaded and queued for XMPP delivery.')
    else
      lCompletion(False, AError);
end;

constructor TNXBotFileExchange.Create(AConfig: TNXBotHostConfig;
  AExecutorFactory: TNXBotFileTransferExecutorFactory);
begin
  inherited Create;
  if not Assigned(AConfig) then
    raise Exception.Create('Bot file exchange configuration is required.');
  FDirectory := AConfig.ExchangeDirectory;
  FCAFile := AConfig.CAFile;
  FFileMaximumBytes := AConfig.FileMaximumBytes;
  FTransferCapacity := AConfig.FileTransferCapacity;
  FStagedFileCapacity := AConfig.StagedFileCapacity;
  FStagedMaximumBytes := AConfig.StagedMaximumBytes;
  FTimeoutMS := AConfig.FileTransferTimeoutMS;
  FExecutorFactory := AExecutorFactory;
  FTrustedOrigins := TStringList.Create;
  FTrustedOrigins.CaseSensitive := False;
  FTrustedOrigins.Assign(AConfig.TrustedFileOrigins);
  InitCriticalSection(FArtifactCriticalSection);
  InitCriticalSection(FTransferCriticalSection);
  FArtifacts := TObjectList.Create(True);
  FTransfers := TObjectList.Create(False);
  if not ForceDirectories(FDirectory) and not DirectoryExists(FDirectory) then
    raise Exception.Create('The file exchange directory could not be created.');
end;

destructor TNXBotFileExchange.Destroy;
begin
  Shutdown;
  FTransfers.Free;
  FArtifacts.Free;
  DoneCriticalSection(FTransferCriticalSection);
  DoneCriticalSection(FArtifactCriticalSection);
  FTrustedOrigins.Free;
  inherited Destroy;
end;

procedure TNXBotFileExchange.CommitArtifacts(AArtifacts: TObjectList;
  AReservedFiles: Integer; AReservedBytes: Int64);
var
  lAttachment: TNXBotAttachment;
begin
  EnterCriticalSection(FArtifactCriticalSection);
  try
    Dec(FReservedFiles, AReservedFiles);
    Dec(FReservedBytes, AReservedBytes);
    while AArtifacts.Count > 0 do
    begin
      lAttachment := TNXBotAttachment(AArtifacts.Extract(AArtifacts[0]));
      FArtifacts.Add(lAttachment);
      Inc(FArtifactBytes, lAttachment.Size);
    end;
  finally
    LeaveCriticalSection(FArtifactCriticalSection);
  end;
end;

function TNXBotFileExchange.CreateExecutor: TNXBotFileTransferExecutor;
begin
  if Assigned(FExecutorFactory) then Result := FExecutorFactory()
  else Result := TNXBotSynapseFileTransferExecutor.Create;
  if not Assigned(Result) then
    raise Exception.Create('The file transfer executor factory returned nil.');
end;

procedure TNXBotFileExchange.ReleaseReservation(AFiles: Integer;
  ABytes: Int64);
begin
  EnterCriticalSection(FArtifactCriticalSection);
  try
    Dec(FReservedFiles, AFiles);
    Dec(FReservedBytes, ABytes);
  finally
    LeaveCriticalSection(FArtifactCriticalSection);
  end;
end;

function TNXBotFileExchange.ReserveStaging(AFiles: Integer;
  ABytes: Int64): Boolean;
begin
  Result := False;
  if (AFiles < 1) or (ABytes < 0) then Exit;
  EnterCriticalSection(FArtifactCriticalSection);
  try
    if (AFiles > FStagedFileCapacity - FArtifacts.Count - FReservedFiles) or
      (ABytes > FStagedMaximumBytes - FArtifactBytes - FReservedBytes) then
      Exit;
    Inc(FReservedFiles, AFiles);
    Inc(FReservedBytes, ABytes);
    Result := True;
  finally
    LeaveCriticalSection(FArtifactCriticalSection);
  end;
end;

procedure TNXBotFileExchange.ReapFinished;
var
  lFinished: TObjectList;
  lIndex: Integer;
  lTransfer: TNXBotFileTransferThread;
begin
  lFinished := TObjectList.Create(False);
  try
    EnterCriticalSection(FTransferCriticalSection);
    try
      for lIndex := FTransfers.Count - 1 downto 0 do
      begin
        lTransfer := TNXBotFileTransferThread(FTransfers[lIndex]);
        if lTransfer.Finished then
          lFinished.Add(FTransfers.Extract(lTransfer));
      end;
    finally
      LeaveCriticalSection(FTransferCriticalSection);
    end;
    while lFinished.Count > 0 do
    begin
      lTransfer := TNXBotFileTransferThread(
        lFinished.Extract(lFinished[0]));
      lTransfer.WaitFor;
      lTransfer.Release;
    end;
  finally
    lFinished.Free;
  end;
end;

function TNXBotFileExchange.AcceptInbound(APrompt: TNXBotPrompt;
  const AShares: TNXXMPPFileShareArray): Boolean;
var
  lIndex: Integer;
  lReservedBytes: Int64;
  lTransfer: TNXBotInboundTransfer;
begin
  Result := False;
  if not Assigned(APrompt) or (Length(AShares) = 0) then Exit;
  if InterlockedCompareExchange(FAdmissionClosed, 0, 0) <> 0 then Exit;
  lReservedBytes := 0;
  for lIndex := 0 to High(AShares) do
    if AShares[lIndex].HasSize then
    begin
      if (AShares[lIndex].DeclaredSize < 0) or
        (AShares[lIndex].DeclaredSize > FFileMaximumBytes) or
        (AShares[lIndex].DeclaredSize >
          FStagedMaximumBytes - lReservedBytes) then Exit;
      Inc(lReservedBytes, AShares[lIndex].DeclaredSize);
    end
    else
    begin
      if FFileMaximumBytes > FStagedMaximumBytes - lReservedBytes then Exit;
      Inc(lReservedBytes, FFileMaximumBytes);
    end;
  if not ReserveStaging(Length(AShares), lReservedBytes) then Exit;
  lTransfer := nil;
  try
    ReapFinished;
    lTransfer := TNXBotInboundTransfer.Create(Self, APrompt, AShares,
      Length(AShares), lReservedBytes);
    EnterCriticalSection(FTransferCriticalSection);
    try
      if (InterlockedCompareExchange(FAdmissionClosed, 0, 0) = 0) and
        (FTransfers.Count < FTransferCapacity) then
      begin
        lTransfer.Retain;
        FTransfers.Add(lTransfer);
        Result := True;
      end;
    finally
      LeaveCriticalSection(FTransferCriticalSection);
    end;
    if Result then
    begin
      lTransfer.Start;
      lTransfer.Release;
      lTransfer := nil;
    end
    else
      lTransfer.FPrompt := nil;
  except
    ReleaseReservation(Length(AShares), lReservedBytes);
    if Assigned(lTransfer) then lTransfer.Release;
    raise;
  end;
  if not Result then
  begin
    lTransfer.Release;
    ReleaseReservation(Length(AShares), lReservedBytes);
  end;
end;

function TNXBotFileExchange.AcceptOutbound(AAttachment: TNXBotAttachment;
  AFileSharing: TNXXMPPFileSharingModule; const ATargetJID, AMessageType,
  AReplyJID, AReplyID, ARoomJID: UTF8String;
  ACompletion: TNXBotFileSendCompletion): Boolean;
var
  lTransfer: TNXBotOutboundTransfer;
begin
  Result := False;
  if not Assigned(AAttachment) or not Assigned(AFileSharing) or
    not Assigned(ACompletion) or (ATargetJID = '') then Exit;
  if InterlockedCompareExchange(FAdmissionClosed, 0, 0) <> 0 then Exit;
  ReapFinished;
  lTransfer := TNXBotOutboundTransfer.Create(Self, AAttachment,
    AFileSharing, ATargetJID, AMessageType, AReplyJID, AReplyID,
    ARoomJID, ACompletion);
  try
    EnterCriticalSection(FTransferCriticalSection);
    try
      if (InterlockedCompareExchange(FAdmissionClosed, 0, 0) = 0) and
        (FTransfers.Count < FTransferCapacity) then
      begin
        lTransfer.Retain;
        FTransfers.Add(lTransfer);
        Result := True;
      end;
    finally
      LeaveCriticalSection(FTransferCriticalSection);
    end;
    if Result then
    begin
      lTransfer.Start;
      lTransfer.Release;
      lTransfer := nil;
    end;
  except
    if Assigned(lTransfer) then lTransfer.Release;
    raise;
  end;
  if not Result then
  begin
    lTransfer.FAttachment := nil;
    lTransfer.FCompletion := nil;
    lTransfer.Release;
  end;
end;

procedure TNXBotFileExchange.SignalProvider(const AReason: UTF8String);
var
  lIndex: Integer;
  lTransfers: TObjectList;
  lTransfer: TNXBotFileTransferThread;
begin
  lTransfers := TObjectList.Create(False);
  try
    EnterCriticalSection(FTransferCriticalSection);
    try
      for lIndex := 0 to FTransfers.Count - 1 do
      begin
        lTransfer := TNXBotFileTransferThread(FTransfers[lIndex]);
        if not lTransfer.Finished and lTransfer.RequiresProvider then
        begin
          lTransfer.Retain;
          lTransfers.Add(lTransfer);
        end;
      end;
    finally
      LeaveCriticalSection(FTransferCriticalSection);
    end;
    for lIndex := 0 to lTransfers.Count - 1 do
      TNXBotFileTransferThread(lTransfers[lIndex]).SignalCancellation(AReason);
  finally
    for lIndex := 0 to lTransfers.Count - 1 do
      TNXBotFileTransferThread(lTransfers[lIndex]).Release;
    lTransfers.Free;
  end;
end;

procedure TNXBotFileExchange.SignalRoom(const ARoomJID,
  AReason: UTF8String);
var
  lIndex: Integer;
  lTransfers: TObjectList;
  lTransfer: TNXBotFileTransferThread;
begin
  lTransfers := TObjectList.Create(False);
  try
    EnterCriticalSection(FTransferCriticalSection);
    try
      for lIndex := 0 to FTransfers.Count - 1 do
      begin
        lTransfer := TNXBotFileTransferThread(FTransfers[lIndex]);
        if not lTransfer.Finished and (lTransfer.RoomJID = ARoomJID) then
        begin
          lTransfer.Retain;
          lTransfers.Add(lTransfer);
        end;
      end;
    finally
      LeaveCriticalSection(FTransferCriticalSection);
    end;
    for lIndex := 0 to lTransfers.Count - 1 do
      TNXBotFileTransferThread(lTransfers[lIndex]).SignalCancellation(AReason);
  finally
    for lIndex := 0 to lTransfers.Count - 1 do
      TNXBotFileTransferThread(lTransfers[lIndex]).Release;
    lTransfers.Free;
  end;
end;

procedure TNXBotFileExchange.SignalXMPP(const AReason: UTF8String);
var
  lIndex: Integer;
  lTransfers: TObjectList;
  lTransfer: TNXBotFileTransferThread;
begin
  lTransfers := TObjectList.Create(False);
  try
    EnterCriticalSection(FTransferCriticalSection);
    try
      for lIndex := 0 to FTransfers.Count - 1 do
      begin
        lTransfer := TNXBotFileTransferThread(FTransfers[lIndex]);
        if not lTransfer.Finished and lTransfer.RequiresXMPP then
        begin
          lTransfer.Retain;
          lTransfers.Add(lTransfer);
        end;
      end;
    finally
      LeaveCriticalSection(FTransferCriticalSection);
    end;
    for lIndex := 0 to lTransfers.Count - 1 do
      TNXBotFileTransferThread(lTransfers[lIndex]).SignalCancellation(AReason);
  finally
    for lIndex := 0 to lTransfers.Count - 1 do
      TNXBotFileTransferThread(lTransfers[lIndex]).Release;
    lTransfers.Free;
  end;
end;

function TNXBotFileExchange.FindAttachment(
  const AID: UTF8String): TNXBotAttachment;
var
  lIndex: Integer;
begin
  Result := nil;
  EnterCriticalSection(FArtifactCriticalSection);
  try
    for lIndex := 0 to FArtifacts.Count - 1 do
      if TNXBotAttachment(FArtifacts[lIndex]).ID = AID then
        Exit(TNXBotAttachment(FArtifacts[lIndex]).Clone);
  finally
    LeaveCriticalSection(FArtifactCriticalSection);
  end;
end;

procedure TNXBotFileExchange.Shutdown;
var
  lArtifacts: TObjectList;
  lIndex: Integer;
  lTransfer: TNXBotFileTransferThread;
  lTransfers: TObjectList;
begin
  if InterlockedExchange(FAdmissionClosed, 1) <> 0 then Exit;
  lTransfers := TObjectList.Create(False);
  try
    EnterCriticalSection(FTransferCriticalSection);
    try
      while FTransfers.Count > 0 do
        lTransfers.Add(FTransfers.Extract(FTransfers[0]));
    finally
      LeaveCriticalSection(FTransferCriticalSection);
    end;
    for lIndex := 0 to lTransfers.Count - 1 do
      TNXBotFileTransferThread(lTransfers[lIndex]).SignalCancellation(
        'The file transfer was cancelled during shutdown.');
    while lTransfers.Count > 0 do
    begin
      lTransfer := TNXBotFileTransferThread(
        lTransfers.Extract(lTransfers[0]));
      lTransfer.WaitFor;
      lTransfer.Release;
    end;
  finally
    lTransfers.Free;
  end;
  lArtifacts := TObjectList.Create(True);
  try
    EnterCriticalSection(FArtifactCriticalSection);
    try
      while FArtifacts.Count > 0 do
        lArtifacts.Add(FArtifacts.Extract(FArtifacts[0]));
      FArtifactBytes := 0;
      FReservedFiles := 0;
      FReservedBytes := 0;
    finally
      LeaveCriticalSection(FArtifactCriticalSection);
    end;
    for lIndex := 0 to lArtifacts.Count - 1 do
      if FileExists(TNXBotAttachment(lArtifacts[lIndex]).Path) then
        DeleteFile(TNXBotAttachment(lArtifacts[lIndex]).Path);
  finally
    lArtifacts.Free;
  end;
end;

end.
