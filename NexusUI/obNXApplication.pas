unit obNXApplication;

{$mode objfpc}{$H+}

interface

uses
  obNXCanvas,
  obNXFont,
  obNXMaster,
  obNXPlatform,
  obNXSDL2,
  obNXSkin,
  tpNXEvents;

type
  TNXApplication = class
  private
    FInitialized: Boolean;
    FRunning: Boolean;
    FCanvas: TNXCanvas;
    FMaster: TGUI_Master;
    FFonts: TNXFontManager;
    FPlatform: TNXPlatform;
    FSkin: TNXSkin;
    procedure CreateMaster;
    procedure DestroyPlatform;
    procedure HandleEvent(const AEvent: TNXEvent);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize(const ATitle: AnsiString; AWidth, AHeight: Integer);
    procedure ProcessMessages;
    procedure Render;
    procedure Run;
    procedure Terminate;

    property Master: TGUI_Master read FMaster;
    property Running: Boolean read FRunning;
    property Fonts: TNXFontManager read FFonts;
    property Platform: TNXPlatform read FPlatform;
    property Skin: TNXSkin read FSkin;
    property Canvas: TNXCanvas read FCanvas;
  end;

var
  Application: TNXApplication;

implementation

uses
  SysUtils;

constructor TNXApplication.Create;
begin
  inherited Create;
  FSkin := TNXSkin.Create;
  FPlatform := TNXSDL2.Create;
  FFonts := TNXFontManager.Create(FPlatform);
end;

destructor TNXApplication.Destroy;
begin
  FreeAndNil(FMaster);
  FreeAndNil(FCanvas);
  FreeAndNil(FFonts);
  FreeAndNil(FSkin);
  DestroyPlatform;
  FreeAndNil(FPlatform);
  inherited Destroy;
end;

procedure TNXApplication.CreateMaster;
begin
  FreeAndNil(FMaster);
  FMaster := TGUI_Master.Create(nil);
  FMaster.Canvas := FCanvas;
  FMaster.ResizeToWindow;
end;

procedure TNXApplication.DestroyPlatform;
begin
  if FInitialized then
    FPlatform.Finalize;

  FInitialized := False;
end;

procedure TNXApplication.HandleEvent(const AEvent: TNXEvent);
begin
  case AEvent.EventType of
    nxeQuit:
      Terminate;

    nxeWindowResized:
    begin
      if FMaster <> nil then
        FMaster.ResizeToWindow;
      Render;
    end;

    nxeWindowExposed:
      Render;

    nxeKeyDown:
    begin
      if AEvent.Key.Key = nkEscape then
        Terminate;

      if FMaster <> nil then
        FMaster.InjectNXEvent(AEvent);
    end;

    nxeKeyUp, nxeMouseMotion, nxeMouseDown, nxeMouseUp, nxeTextInput:
      if FMaster <> nil then
        FMaster.InjectNXEvent(AEvent);
  end;
end;

procedure TNXApplication.Initialize(const ATitle: AnsiString; AWidth,
  AHeight: Integer);
begin
  if FInitialized then
    Exit;

  FPlatform.CreateDisplay(ATitle, AWidth, AHeight);
  FInitialized := True;
  FreeAndNil(FCanvas);
  FCanvas := TNXCanvas.Create(FPlatform);

  CreateMaster;

  FFonts.Initialize;
  FFonts.LoadDefaultFont('resources\Federation.ttf', 13);
  Master.Font := FFonts.DefaultFont;
end;

procedure TNXApplication.ProcessMessages;
var
  lEvent: TNXEvent;
begin
  while FPlatform.PollEvent(lEvent) do
    HandleEvent(lEvent);
end;

procedure TNXApplication.Render;
begin
  if FMaster <> nil then
    FMaster.Paint;

  if FCanvas <> nil then
    FCanvas.Present;
end;

procedure TNXApplication.Run;
begin
  FRunning := True;
  while FRunning do
  begin
    ProcessMessages;
    Render;
  end;
end;

procedure TNXApplication.Terminate;
begin
  FRunning := False;
end;

initialization
  Application := TNXApplication.Create;

finalization
  FreeAndNil(Application);

end.
