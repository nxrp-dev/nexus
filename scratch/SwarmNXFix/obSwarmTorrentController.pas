unit obSwarmTorrentController;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, tpNXTorrent, tpSwarmTypes, obNXTorrentMetaInfo,
  obNXTorrentSession, obNXTorrentPeerConnection, obNXTorrentTracker,
  obSwarmTorrentViewModel;

type
  ESwarmTorrentControllerError = class(Exception);

  TSwarmTorrentController = class
  private
    FDestinationRoot: string;
    FMetaInfo: TNXTorrentMetaInfo;
    FPeerId: string;
    FSession: TNXTorrentSession;
    FTorrentPath: string;
    procedure ClearTorrent;
    procedure EnsureSession;
    function LoadFileBytes(const AFileName: string): string;
    function MetaInfo: TNXTorrentMetaInfo;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadTorrent(const AFileName: string);
    procedure SetDestinationRoot(const APath: string);
    procedure StartSession;
    procedure PauseSession;
    procedure StopSession;
    procedure VerifyPiece(APieceIndex: Integer);
    function Announce(const AURL: string; APort: Integer): string;
    function ConnectToPeer(const AHost: string; APort: Integer): string;
    function BuildViewModel: TSwarmTorrentViewModel;

    property DestinationRoot: string read FDestinationRoot;
    property PeerId: string read FPeerId write FPeerId;
    property TorrentPath: string read FTorrentPath;
  end;

implementation

constructor TSwarmTorrentController.Create;
begin
  inherited Create;
  FPeerId := '-NX0001-SwarmNX0001';
end;

destructor TSwarmTorrentController.Destroy;
begin
  ClearTorrent;
  inherited Destroy;
end;

procedure TSwarmTorrentController.ClearTorrent;
begin
  FreeAndNil(FSession);
  FreeAndNil(FMetaInfo);
  FTorrentPath := '';
end;

function TSwarmTorrentController.LoadFileBytes(const AFileName: string): string;
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, lStream.Size);
    if lStream.Size > 0 then
      lStream.ReadBuffer(Result[1], lStream.Size);
  finally
    lStream.Free;
  end;
end;

function TSwarmTorrentController.MetaInfo: TNXTorrentMetaInfo;
begin
  if Assigned(FSession) then
    Result := FSession.MetaInfo
  else
    Result := FMetaInfo;
end;

procedure TSwarmTorrentController.LoadTorrent(const AFileName: string);
var
  lMetaInfo: TNXTorrentMetaInfo;
begin
  if AFileName = '' then
    raise ESwarmTorrentControllerError.Create('Torrent file path is empty.');
  lMetaInfo := TNXTorrentMetaInfo.LoadFromBEncodedString(LoadFileBytes(AFileName));
  try
    ClearTorrent;
    FMetaInfo := lMetaInfo;
    lMetaInfo := nil;
    FTorrentPath := AFileName;
  finally
    lMetaInfo.Free;
  end;
end;

procedure TSwarmTorrentController.SetDestinationRoot(const APath: string);
begin
  if APath = '' then
    raise ESwarmTorrentControllerError.Create('Destination path is empty.');
  if Assigned(FSession) then
    raise ESwarmTorrentControllerError.Create(
      'Destination cannot be changed after the session has started.');
  FDestinationRoot := APath;
end;

procedure TSwarmTorrentController.EnsureSession;
begin
  if Assigned(FSession) then
    Exit;
  if not Assigned(FMetaInfo) then
    raise ESwarmTorrentControllerError.Create('Load a torrent before starting a session.');
  if FDestinationRoot = '' then
    raise ESwarmTorrentControllerError.Create('Select a destination before starting a session.');

  FSession := TNXTorrentSession.Create(FMetaInfo, FDestinationRoot);
  FMetaInfo := nil;
  FSession.PeerId := FPeerId;
end;

procedure TSwarmTorrentController.StartSession;
begin
  EnsureSession;
  FSession.Start;
end;

procedure TSwarmTorrentController.PauseSession;
begin
  EnsureSession;
  FSession.Pause;
end;

procedure TSwarmTorrentController.StopSession;
begin
  EnsureSession;
  FSession.Stop;
end;

procedure TSwarmTorrentController.VerifyPiece(APieceIndex: Integer);
begin
  EnsureSession;
  FSession.VerifyPiece(APieceIndex);
end;

function TSwarmTorrentController.Announce(const AURL: string;
  APort: Integer): string;
var
  lResponse: TNXTorrentTrackerResponse;
begin
  EnsureSession;
  lResponse := FSession.AnnounceToTracker(AURL, APort);
  try
    if lResponse.FailureReason <> '' then
      Result := 'Tracker failure: ' + lResponse.FailureReason
    else
      Result := Format('Tracker returned %d peers; interval %d seconds.',
        [lResponse.PeerCount, lResponse.Interval]);
  finally
    lResponse.Free;
  end;
end;

function TSwarmTorrentController.ConnectToPeer(const AHost: string;
  APort: Integer): string;
var
  lConnection: TNXTorrentPeerConnection;
begin
  EnsureSession;
  lConnection := FSession.ConnectToPeer(AHost, APort);
  try
    Result := Format('Connected to peer %s:%d.', [lConnection.Host,
      lConnection.Port]);
  finally
    lConnection.Free;
  end;
end;

function TSwarmTorrentController.BuildViewModel: TSwarmTorrentViewModel;
var
  lMetaInfo: TNXTorrentMetaInfo;
  lStatus: TNXTorrentStatus;
begin
  lMetaInfo := MetaInfo;
  if not Assigned(lMetaInfo) then
    Exit(TSwarmTorrentViewModel.CreateEmpty);

  if Assigned(FSession) then
  begin
    lStatus := FSession.Status;
    try
      Result := TSwarmTorrentViewModel.Create(FTorrentPath, FDestinationRoot,
        lStatus.Name, lStatus.InfoHashHex, lMetaInfo.Announce,
        lMetaInfo.PieceLength, lStatus.PieceCount, lStatus.VerifiedPieces,
        lStatus.TotalBytes, lStatus.DownloadedBytes, lStatus.State);
    finally
      lStatus.Free;
    end;
  end
  else
    Result := TSwarmTorrentViewModel.Create(FTorrentPath, FDestinationRoot,
      lMetaInfo.Name, lMetaInfo.InfoHashHex, lMetaInfo.Announce,
      lMetaInfo.PieceLength, lMetaInfo.PieceCount, 0,
      lMetaInfo.Files.TotalLength, 0, tssStopped);
end;

end.
