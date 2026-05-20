unit obNXApplication;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXCanvas,
  obNXControl,
  obNXFont,
  obNXPopup,
  obNXPlatform,
  obNXSDL2,
  obNXSkin,
  obNXWindow,
  tpNXEvents,
  tpNXWindow;

type
  TNXApplication = class
  private
    FInitialized: Boolean;
    FRunning: Boolean;
    FCanvas: TNXCanvas;
    FDeferredFreeControls: TList;
    FFonts: TNXFontManager;
    FPopups: TNXPopupManager;
    FPlatform: TNXPlatform;
    FRootWindow: TNXWindow;
    FSkin: TNXSkin;
    FWindows: TNXWindowManager;
    procedure CreateRootWindow;
    procedure DestroyPlatform;
    procedure HandleEvent(const AEvent: TNXEvent);
    procedure ProcessDeferredFrees;
    procedure ResizeRootWindow;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize(const ATitle: AnsiString; AWidth, AHeight: Integer;
      AStartPosition: TNXWindowStartPosition = wspDefault; ALeft: Integer = 0;
      ATop: Integer = 0);
    procedure ProcessMessages;
    procedure QueueFreeControl(AControl: TNXControl);
    procedure Render;
    procedure Run;
    procedure Terminate;

    property Running: Boolean read FRunning;
    property Fonts: TNXFontManager read FFonts;
    property Popups: TNXPopupManager read FPopups;
    property Platform: TNXPlatform read FPlatform;
    property RootWindow: TNXWindow read FRootWindow;
    property Skin: TNXSkin read FSkin;
    property Canvas: TNXCanvas read FCanvas;
    property Windows: TNXWindowManager read FWindows;
  end;

var
  Application: TNXApplication;

implementation

uses
  SysUtils;

constructor TNXApplication.Create;
begin
  inherited Create;
  FDeferredFreeControls := TList.Create;
  FSkin := TNXSkin.Create;
  FPlatform := TNXSDL2.Create;
  FFonts := TNXFontManager.Create(FPlatform);
end;

destructor TNXApplication.Destroy;
begin
  ProcessDeferredFrees;
  FreeAndNil(FDeferredFreeControls);
  FreeAndNil(FWindows);
  FreeAndNil(FPopups);
  FreeAndNil(FRootWindow);
  FreeAndNil(FSkin);
  FreeAndNil(FCanvas);
  FreeAndNil(FFonts);
  DestroyPlatform;
  FreeAndNil(FPlatform);
  inherited Destroy;
end;

procedure TNXApplication.CreateRootWindow;
begin
  FreeAndNil(FWindows);
  FreeAndNil(FPopups);
  FreeAndNil(FRootWindow);

  FRootWindow := TNXWindow.Create;
  FRootWindow.Canvas := FCanvas;
  FRootWindow.BorderStyleKind := wbsNone;
  FRootWindow.Movable := False;
  FRootWindow.Visible := True;
  ResizeRootWindow;

  FPopups := TNXPopupManager.Create(FRootWindow);
  FWindows := TNXWindowManager.Create(FCanvas);

  FPlatform.StopTextInput;
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
      ResizeRootWindow;
      Render;
    end;

    nxeWindowExposed:
      Render;

    nxeKeyDown:
    begin
      if AEvent.Key.Key = nkEscape then
        Terminate;

      if FRootWindow <> nil then
      begin
        if not FWindows.ProcessKeyDown(AEvent.Key) then
          FRootWindow.ProcessKeyDown(AEvent.Key);
      end;
    end;

    nxeKeyUp:
      if FRootWindow <> nil then
      begin
        if not FWindows.ProcessKeyUp(AEvent.Key) then
          FRootWindow.ProcessKeyUp(AEvent.Key);
      end;

    nxeMouseMotion:
      if FRootWindow <> nil then
      begin
        if not FWindows.ProcessMouseMotion(AEvent.Mouse.X, AEvent.Mouse.Y,
          AEvent.Mouse.ButtonState) then
          FRootWindow.ProcessMouseMotion(AEvent.Mouse.X, AEvent.Mouse.Y,
            AEvent.Mouse.ButtonState);
      end;

    nxeMouseDown:
      if FRootWindow <> nil then
      begin
        FPopups.ProcessMouseDown(AEvent.Mouse.X, AEvent.Mouse.Y,
          AEvent.Mouse.Button);

        if not FWindows.ProcessMouseDown(AEvent.Mouse.X, AEvent.Mouse.Y,
          AEvent.Mouse.Button) then
        begin
          FRootWindow.ProcessMouseDown(AEvent.Mouse.X, AEvent.Mouse.Y,
            AEvent.Mouse.Button);
          FPopups.BringActiveToFront;
        end;
      end;

    nxeMouseUp:
      if FRootWindow <> nil then
      begin
        if not FWindows.ProcessMouseUp(AEvent.Mouse.X, AEvent.Mouse.Y,
          AEvent.Mouse.Button) then
          FRootWindow.ProcessMouseUp(AEvent.Mouse.X, AEvent.Mouse.Y,
            AEvent.Mouse.Button);
      end;

    nxeTextInput:
      if FRootWindow <> nil then
      begin
        if not FWindows.ProcessTextInput(AEvent.Text) then
          FRootWindow.ProcessTextInput(AEvent.Text);
      end;
  end;
end;

procedure TNXApplication.Initialize(const ATitle: AnsiString; AWidth,
  AHeight: Integer; AStartPosition: TNXWindowStartPosition; ALeft: Integer;
  ATop: Integer);
begin
  if FInitialized then
    Exit;

  FPlatform.CreateDisplay(ATitle, AWidth, AHeight, AStartPosition, ALeft, ATop);
  FInitialized := True;
  FreeAndNil(FCanvas);
  FCanvas := TNXCanvas.Create(FPlatform);

  CreateRootWindow;

  FFonts.Initialize;
  FFonts.LoadDefaultFont('resources' + PathDelim + 'Federation.ttf', 13);
  RootWindow.Font := FFonts.DefaultFont;
end;

procedure TNXApplication.ProcessMessages;
var
  lEvent: TNXEvent;
begin
  while FPlatform.PollEvent(lEvent) do
  begin
    HandleEvent(lEvent);
    ProcessDeferredFrees;
  end;
end;

procedure TNXApplication.ProcessDeferredFrees;
var
  lControl: TNXControl;
begin
  while Assigned(FDeferredFreeControls) and (FDeferredFreeControls.Count > 0) do
  begin
    lControl := TNXControl(FDeferredFreeControls[0]);
    FDeferredFreeControls.Delete(0);

    if not Assigned(lControl) then
      Continue;

    if Assigned(lControl.Parent) then
      lControl.Parent.FreeChild(lControl)
    else
      lControl.Free;
  end;
end;

procedure TNXApplication.QueueFreeControl(AControl: TNXControl);
begin
  if (not Assigned(FDeferredFreeControls)) or (not Assigned(AControl)) then
    Exit;

  if FDeferredFreeControls.IndexOf(AControl) < 0 then
    FDeferredFreeControls.Add(AControl);
end;

procedure TNXApplication.Render;
begin
  if FCanvas <> nil then
    FCanvas.Clear(Skin.FormBackColor);

  if FRootWindow <> nil then
    FRootWindow.Paint;

  if FWindows <> nil then
    FWindows.Paint;

  if FCanvas <> nil then
    FCanvas.Present;
end;

procedure TNXApplication.ResizeRootWindow;
var
  lHeight: Integer;
  lWidth: Integer;
begin
  if (not Assigned(FRootWindow)) or (not Assigned(FCanvas)) or
    (not Assigned(FCanvas.Platform)) then
    Exit;

  FCanvas.Platform.GetDisplaySize(lWidth, lHeight);
  FRootWindow.Left := 0;
  FRootWindow.Top := 0;
  FRootWindow.Width := lWidth;
  FRootWindow.Height := lHeight;
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
