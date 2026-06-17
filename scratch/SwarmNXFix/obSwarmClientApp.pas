unit obSwarmClientApp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, obNXApplication, obSwarmMainWindow,
  obSwarmTorrentController;

type
  TSwarmClientApp = class
  private
    FController: TSwarmTorrentController;
    FMainWindow: TSwarmMainWindow;
    procedure CopyDirectory(const ASourceDir, ADestDir: string);
    procedure CopyFileBytes(const ASourceFile, ADestFile: string);
    procedure EnsureRuntimeAssets;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Run;
  end;

implementation

constructor TSwarmClientApp.Create;
begin
  inherited Create;
  FController := TSwarmTorrentController.Create;
end;

destructor TSwarmClientApp.Destroy;
begin
  FMainWindow.Free;
  FController.Free;
  inherited Destroy;
end;

procedure TSwarmClientApp.CopyDirectory(const ASourceDir, ADestDir: string);
var
  lDestName: string;
  lItem: TSearchRec;
  lSourceName: string;
begin
  if not DirectoryExists(ASourceDir) then
    Exit;

  ForceDirectories(ADestDir);
  if FindFirst(IncludeTrailingPathDelimiter(ASourceDir) + '*',
    faAnyFile, lItem) <> 0 then
    Exit;
  try
    repeat
      if (lItem.Name = '.') or (lItem.Name = '..') then
        Continue;

      lSourceName := IncludeTrailingPathDelimiter(ASourceDir) + lItem.Name;
      lDestName := IncludeTrailingPathDelimiter(ADestDir) + lItem.Name;
      if (lItem.Attr and faDirectory) <> 0 then
        CopyDirectory(lSourceName, lDestName)
      else
        CopyFileBytes(lSourceName, lDestName);
    until FindNext(lItem) <> 0;
  finally
    FindClose(lItem);
  end;
end;

procedure TSwarmClientApp.CopyFileBytes(const ASourceFile, ADestFile: string);
var
  lDest: TFileStream;
  lSource: TFileStream;
begin
  lSource := TFileStream.Create(ASourceFile, fmOpenRead or fmShareDenyWrite);
  try
    lDest := TFileStream.Create(ADestFile, fmCreate);
    try
      lDest.CopyFrom(lSource, 0);
    finally
      lDest.Free;
    end;
  finally
    lSource.Free;
  end;
end;

procedure TSwarmClientApp.EnsureRuntimeAssets;
var
  lExeDir: string;
  lProjectDir: string;
begin
  lExeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  lProjectDir := IncludeTrailingPathDelimiter(GetCurrentDir);

  CopyDirectory(lProjectDir + 'resources', lExeDir + 'resources');
  CopyDirectory(lProjectDir + 'skins', lExeDir + 'skins');
end;

procedure TSwarmClientApp.Run;
begin
  EnsureRuntimeAssets;
  Application.Initialize('SwarmNX', 1024, 720);
  Application.Skin.LoadNamedSkin('default', Application.Canvas);
  FMainWindow := TSwarmMainWindow.Create(Application.RootWindow, FController);
  FMainWindow.Build;
  Application.Run;
end;

end.
