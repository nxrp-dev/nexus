unit obNXWindow;
{$mode objfpc}{$H+}
{$interfaces corba}

interface

uses
  Classes,
  Math,
  SysUtils,
  obNXCanvas,
  obNXControl,
  obNXFont,
  obNXSkin,
  obNXTitleBar,
  tpNXEvents,
  tpNXLayout,
  tpNXPlatform,
  tpNXWindow;

type
  TNXWindowManager = class;

  TNXWindow = class(TNXControlHost)
  private
    FActive: Boolean;
    FBackColor: TNXColor;
    FBorderColor: TNXColor;
    FCanClose: Boolean;
    FCaption: string;
    FCloseAction: TNXWindowCloseAction;
    FFillStyle: TFillStyle;
    FFont: TNXFont;
    FForeColor: TNXColor;
    FHeight: Integer;
    FLeft: Integer;
    FManager: TNXWindowManager;
    FModal: Boolean;
    FModalResult: TNXModalResult;
    FMovable: Boolean;
    FOnClose: TNotifyEvent;
    FOnHide: TNotifyEvent;
    FOnShow: TNotifyEvent;
    FStartPosition: TNXWindowStartPosition;
    FStartPositionApplied: Boolean;
    FTitleBar: TNXTitleBar;
    FTop: Integer;
    FVisible: Boolean;
    FWidth: Integer;
    FWindowBorderStyle: TNXWindowBorderStyle;
    procedure SetActive(AValue: Boolean);
    procedure SetHeight(AValue: Integer);
    procedure SetLeft(AValue: Integer);
    procedure SetMovable(AValue: Boolean);
    procedure SetStartPosition(AValue: TNXWindowStartPosition);
    procedure SetTop(AValue: Integer);
    procedure SetWindowBorderStyle(AValue: TNXWindowBorderStyle);
    procedure SetWidth(AValue: Integer);
  protected
    procedure DoClose; virtual;
    procedure DoHide; virtual;
    procedure DoShow; virtual;
    function GetAbsContentRect: TNXRect; virtual;
    function GetBorderThickness: Integer; virtual;
    function GetChildAreaHeight: Integer; override;
    function GetChildAreaLeft: Integer; override;
    function GetChildAreaTop: Integer; override;
    function GetChildAreaWidth: Integer; override;
    function GetChildOriginX(AChild: TNXControl): Integer; override;
    function GetChildOriginY(AChild: TNXControl): Integer; override;
    function GetContentRect: TNXRect; virtual;
    function GetTitleBarHeight: Integer; virtual;
    procedure InternalClose; virtual;
    procedure InternalHide; virtual;
    procedure InternalShow(AActivate: Boolean); virtual;
    procedure Render; virtual;
    procedure RenderClient; virtual;
    procedure SetManager(AManager: TNXWindowManager); virtual;
    procedure TitleBarDragged(Sender: TObject; ADeltaX, ADeltaY: Integer);
  public
    constructor Create; overload; override;
    constructor Create(const ACaption: string; const ARect: TNXRect); overload; virtual;
    destructor Destroy; override;

    procedure Activate; virtual;
    procedure AddChild(AChild: TNXControl); override;
    procedure BringWindowToFront; virtual;
    procedure ClearMouseHover; virtual;
    procedure Close; virtual;
    function GetAbsLeft: Integer; override;
    function GetAbsTop: Integer; override;
    function GetFontForChildren: TNXFont; override;
    function GetHeight: Integer; override;
    function GetLeft: Integer; virtual;
    function GetSkin: TNXSkin; override;
    function GetTop: Integer; virtual;
    function GetWidth: Integer; override;
    procedure Hide; virtual;
    function InWindow(AX, AY: Integer): Boolean; virtual;
    procedure Paint; virtual;
    procedure ProcessKeyDown(const AEvent: TNXKeyEventData); virtual;
    procedure ProcessKeyUp(const AEvent: TNXKeyEventData); virtual;
    procedure ProcessMouseDown(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure ProcessMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); virtual;
    procedure ProcessMouseUp(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure ProcessTextInput(const AText: string); virtual;
    procedure Show; virtual;

    property AbsContentRect: TNXRect read GetAbsContentRect;
    property AbsLeft: Integer read GetAbsLeft;
    property AbsTop: Integer read GetAbsTop;
    property BackColor: TNXColor read FBackColor write FBackColor;
    property BorderColor: TNXColor read FBorderColor write FBorderColor;
    property BorderStyleKind: TNXWindowBorderStyle read FWindowBorderStyle write SetWindowBorderStyle;
    property CanClose: Boolean read FCanClose write FCanClose;
    property Canvas;
    property Caption: string read FCaption write FCaption;
    property Children;
    property CloseAction: TNXWindowCloseAction read FCloseAction write FCloseAction;
    property ContentRect: TNXRect read GetContentRect;
    property FillStyle: TFillStyle read FFillStyle write FFillStyle;
    property Font: TNXFont read FFont write FFont;
    property FontForChildren: TNXFont read GetFontForChildren;
    property ForeColor: TNXColor read FForeColor write FForeColor;
    property Height: Integer read GetHeight write SetHeight;
    property IsSelected: Boolean read FActive;
    property Left: Integer read GetLeft write SetLeft;
    property Manager: TNXWindowManager read FManager;
    property Modal: Boolean read FModal;
    property ModalResult: TNXModalResult read FModalResult write FModalResult;
    property Movable: Boolean read FMovable write SetMovable;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property Skin: TNXSkin read GetSkin;
    property StartPosition: TNXWindowStartPosition read FStartPosition write SetStartPosition;
    property Top: Integer read GetTop write SetTop;
    property Visible: Boolean read FVisible write FVisible;
    property Width: Integer read GetWidth write SetWidth;
  end;

  TNXWindowManager = class
  private
    FActiveWindow: TNXWindow;
    FCanvas: TNXCanvas;
    FHoverWindow: TNXWindow;
    FModalWindow: TNXWindow;
    FWindows: TList;

    function GetWindow(AIndex: Integer): TNXWindow;
    function GetWindowCount: Integer;
    procedure SetActiveWindow(AWindow: TNXWindow);
  public
    constructor Create(ACanvas: TNXCanvas);
    destructor Destroy; override;

    procedure AddWindow(AWindow: TNXWindow);
    procedure ApplyStartPosition(AWindow: TNXWindow);
    procedure BringToFront(AWindow: TNXWindow);
    procedure CloseWindow(AWindow: TNXWindow);
    function CreateWindow(const ACaption: string; const ARect: TNXRect): TNXWindow;
    procedure HideWindow(AWindow: TNXWindow);
    function IndexOf(AWindow: TNXWindow): Integer;
    procedure Paint;
    function ProcessKeyDown(const AEvent: TNXKeyEventData): Boolean;
    function ProcessKeyUp(const AEvent: TNXKeyEventData): Boolean;
    function ProcessMouseDown(AX, AY: Integer; AButton: TNXMouseButton): Boolean;
    function ProcessMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons): Boolean;
    function ProcessMouseUp(AX, AY: Integer; AButton: TNXMouseButton): Boolean;
    function ProcessTextInput(const AText: string): Boolean;
    procedure RemoveWindow(AWindow: TNXWindow);
    procedure ShowModal(AWindow: TNXWindow);
    procedure ShowWindow(AWindow: TNXWindow);

    property ActiveWindow: TNXWindow read FActiveWindow;
    property ModalWindow: TNXWindow read FModalWindow;
    property WindowCount: Integer read GetWindowCount;
    property Windows[AIndex: Integer]: TNXWindow read GetWindow;
  end;

implementation

uses
  obNXApplication;

constructor TNXWindow.Create;
begin
  inherited Create;
  FActive := False;
  FHeight := 256;
  FWidth := 256;
  FVisible := True;
  FCanClose := True;
  FCloseAction := wcaHide;
  FFillStyle := FS_Filled;
  FManager := nil;
  FModal := False;
  FModalResult := mrNone;
  FStartPosition := wspManual;
  FStartPositionApplied := False;

  if Assigned(Skin) then
  begin
    FBackColor := Skin.BackColor;
    FBorderColor := Skin.BorderColor;
    FForeColor := Skin.ForeColor;
  end;

  FTitleBar := TNXTitleBar.Create(INXControlParent(Self));
  FTitleBar.Align := caTop;
  if Assigned(Skin) then
    FTitleBar.BackColor := Skin.TitleBarBackColor;
  FTitleBar.Active := FActive;
  FTitleBar.OnDrag := @TitleBarDragged;
  FTitleBar.ParentSizeCallback(Width, Height);
  SetWindowBorderStyle(wbsSingle);
  Movable := True;
end;

constructor TNXWindow.Create(const ACaption: string; const ARect: TNXRect);
begin
  Create;
  Caption := ACaption;
  FTitleBar.Caption := ACaption;
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

destructor TNXWindow.Destroy;
begin
  inherited Destroy;
end;

procedure TNXWindow.Activate;
begin
  if Assigned(FManager) then
    FManager.ShowWindow(Self)
  else
    InternalShow(True);
end;

procedure TNXWindow.AddChild(AChild: TNXControl);
begin
  inherited AddChild(AChild);
end;

procedure TNXWindow.BringWindowToFront;
begin
  if Assigned(FManager) then
    FManager.BringToFront(Self);
end;

procedure TNXWindow.ClearMouseHover;
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].MouseEntered then
      Children[lIndex].ProcessMouseExit;
end;

procedure TNXWindow.Close;
begin
  if Assigned(FManager) then
    FManager.CloseWindow(Self)
  else
    InternalClose;
end;

procedure TNXWindow.DoClose;
begin
  if Assigned(FOnClose) then
    FOnClose(Self);
end;

procedure TNXWindow.DoHide;
begin
  if Assigned(FOnHide) then
    FOnHide(Self);
end;

procedure TNXWindow.DoShow;
begin
  if Assigned(FOnShow) then
    FOnShow(Self);
end;

function TNXWindow.GetAbsContentRect: TNXRect;
var
  lBorderThickness: Integer;
  lTitleBarHeight: Integer;
begin
  lBorderThickness := GetBorderThickness;
  lTitleBarHeight := GetTitleBarHeight;

  Result := MakeNXRect(
    AbsLeft + lBorderThickness,
    AbsTop + lBorderThickness + lTitleBarHeight,
    Max(0, Width - (lBorderThickness * 2)),
    Max(0, Height - (lBorderThickness * 2) - lTitleBarHeight)
  );
end;

function TNXWindow.GetAbsLeft: Integer;
begin
  Result := Left;
end;

function TNXWindow.GetAbsTop: Integer;
begin
  Result := Top;
end;

function TNXWindow.GetBorderThickness: Integer;
begin
  if BorderStyleKind = wbsSingle then
    Result := 1
  else
    Result := 0;
end;

function TNXWindow.GetChildAreaHeight: Integer;
var
  lBorderThickness: Integer;
begin
  lBorderThickness := GetBorderThickness;
  Result := Max(0, Height - (lBorderThickness * 2));
end;

function TNXWindow.GetChildAreaLeft: Integer;
begin
  Result := GetBorderThickness;
end;

function TNXWindow.GetChildAreaTop: Integer;
begin
  Result := GetBorderThickness;
end;

function TNXWindow.GetChildAreaWidth: Integer;
var
  lBorderThickness: Integer;
begin
  lBorderThickness := GetBorderThickness;
  Result := Max(0, Width - (lBorderThickness * 2));
end;

function TNXWindow.GetChildOriginX(AChild: TNXControl): Integer;
begin
  Result := inherited GetChildOriginX(AChild);
end;

function TNXWindow.GetChildOriginY(AChild: TNXControl): Integer;
begin
  Result := inherited GetChildOriginY(AChild);
end;

function TNXWindow.GetContentRect: TNXRect;
var
  lBorderThickness: Integer;
  lTitleBarHeight: Integer;
begin
  lBorderThickness := GetBorderThickness;
  lTitleBarHeight := GetTitleBarHeight;

  Result := MakeNXRect(
    lBorderThickness,
    lBorderThickness + lTitleBarHeight,
    Max(0, Width - (lBorderThickness * 2)),
    Max(0, Height - (lBorderThickness * 2) - lTitleBarHeight)
  );
end;

function TNXWindow.GetFontForChildren: TNXFont;
begin
  Result := Font;

  if (Result = nil) and Assigned(Application) and Assigned(Application.Fonts) then
    Result := Application.Fonts.DefaultFont;
end;

function TNXWindow.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TNXWindow.GetLeft: Integer;
begin
  Result := FLeft;
end;

function TNXWindow.GetSkin: TNXSkin;
begin
  if Assigned(Application) then
    Result := Application.Skin
  else
    Result := nil;
end;

function TNXWindow.GetTop: Integer;
begin
  Result := FTop;
end;

function TNXWindow.GetTitleBarHeight: Integer;
begin
  if Assigned(FTitleBar) and FTitleBar.Visible then
    Result := FTitleBar.Height
  else
    Result := 0;
end;

function TNXWindow.GetWidth: Integer;
begin
  Result := FWidth;
end;

procedure TNXWindow.Hide;
begin
  if Assigned(FManager) then
    FManager.HideWindow(Self)
  else
    InternalHide;
end;

function TNXWindow.InWindow(AX, AY: Integer): Boolean;
begin
  Result := Visible and (AX >= AbsLeft) and (AX < AbsLeft + Width) and
    (AY >= AbsTop) and (AY < AbsTop + Height);
end;

procedure TNXWindow.InternalClose;
begin
  if not FCanClose then
    Exit;

  DoClose;

  if FCloseAction = wcaHide then
    InternalHide;
end;

procedure TNXWindow.InternalHide;
begin
  if not Visible then
    Exit;

  Visible := False;
  FModal := False;
  DoHide;
end;

procedure TNXWindow.InternalShow(AActivate: Boolean);
begin
  if not Visible then
  begin
    Visible := True;
    DoShow;
  end;

  if AActivate then
    BringWindowToFront;
end;

procedure TNXWindow.Paint;
var
  lChild: TNXControl;
  lChildClipRect: TNXRect;
  lClipRect: TNXRect;
  lIndex: Integer;
begin
  if Assigned(Canvas) and Visible then
  begin
    lClipRect := MakeNXRect(AbsLeft, AbsTop, Max(0, Width), Max(0, Height));

    Canvas.PushClip(lClipRect);
    try
      Render;

      lChildClipRect := AbsContentRect;
      Canvas.PushClip(lChildClipRect);
      try
        for lIndex := 0 to Children.Count - 1 do
        begin
          lChild := Children[lIndex];
          if lChild <> FTitleBar then
            lChild.Paint;
        end;
      finally
        Canvas.PopClip;
      end;

      if Assigned(FTitleBar) and FTitleBar.Visible then
        FTitleBar.Paint;
    finally
      Canvas.PopClip;
    end;
  end;
end;

procedure TNXWindow.ProcessKeyDown(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessKeyDown(AEvent);
end;

procedure TNXWindow.ProcessKeyUp(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessKeyUp(AEvent);
end;

procedure TNXWindow.ProcessMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  lChild: TNXControl;
  lIndex: Integer;
begin
  if Button = mbNone then
    Exit;

  for lIndex := Children.Count - 1 downto 0 do
  begin
    lChild := Children[lIndex];
    if lChild.Visible and lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) then
    begin
      lChild.ProcessMouseDown(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top,
        Button
      );
      lChild.IsSelected := True;
      Exit;
    end;
  end;

  UnselectChildren;
end;

procedure TNXWindow.ProcessMouseMotion(X, Y: Integer;
  ButtonState: TNXMouseButtons);
var
  lCapturedControl: TNXControl;
  lChild: TNXControl;
  lIndex: Integer;
  lPassed: Boolean;
begin
  lCapturedControl := NXCapturedMouseControl;
  if Assigned(lCapturedControl) then
  begin
    lCapturedControl.ProcessMouseMotion(
      X + AbsLeft - lCapturedControl.AbsLeft,
      Y + AbsTop - lCapturedControl.AbsTop,
      ButtonState
    );
    Exit;
  end;

  lPassed := False;
  for lIndex := Children.Count - 1 downto 0 do
  begin
    lChild := Children[lIndex];
    if lChild.Visible and lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) then
    begin
      lPassed := True;
      if not lChild.MouseEntered then
        lChild.ProcessMouseEnter;
      lChild.ProcessMouseMotion(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top,
        ButtonState
      );
    end
    else if lChild.MouseEntered then
      lChild.ProcessMouseExit;

    if lPassed then
      Break;
  end;
end;

procedure TNXWindow.ProcessMouseUp(X, Y: Integer; Button: TNXMouseButton);
var
  lCapturedControl: TNXControl;
  lChild: TNXControl;
  lIndex: Integer;
begin
  if Button = mbNone then
    Exit;

  lCapturedControl := NXCapturedMouseControl;
  if Assigned(lCapturedControl) then
  begin
    lCapturedControl.ProcessMouseUp(
      X + AbsLeft - lCapturedControl.AbsLeft,
      Y + AbsTop - lCapturedControl.AbsTop,
      Button
    );
    Exit;
  end;

  for lIndex := Children.Count - 1 downto 0 do
  begin
    lChild := Children[lIndex];
    if lChild.Visible and lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) then
    begin
      lChild.ProcessMouseUp(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top,
        Button
      );
      Exit;
    end;
  end;
end;

procedure TNXWindow.ProcessTextInput(const AText: string);
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessTextInput(AText);
end;

procedure TNXWindow.Render;
var
  lRect: TNXRect;
begin
  lRect := MakeNXRect(AbsLeft, AbsTop, Width, Height);

  if FillStyle = FS_Filled then
    Canvas.FillRect(lRect, BackColor);

  RenderClient;

  if BorderStyleKind = wbsSingle then
    Canvas.DrawRect(lRect, BorderColor);
end;

procedure TNXWindow.RenderClient;
begin
end;

procedure TNXWindow.SetActive(AValue: Boolean);
begin
  FActive := AValue;

  if Assigned(FTitleBar) then
    FTitleBar.Active := AValue;
end;

procedure TNXWindow.SetHeight(AValue: Integer);
begin
  FHeight := AValue;
  SendSizeCallback;
end;

procedure TNXWindow.SetLeft(AValue: Integer);
begin
  FLeft := AValue;
end;

procedure TNXWindow.SetManager(AManager: TNXWindowManager);
begin
  FManager := AManager;
end;

procedure TNXWindow.SetMovable(AValue: Boolean);
begin
  FMovable := AValue;
end;

procedure TNXWindow.SetStartPosition(AValue: TNXWindowStartPosition);
begin
  if FStartPosition = AValue then
    Exit;

  FStartPosition := AValue;
  FStartPositionApplied := False;
end;

procedure TNXWindow.SetTop(AValue: Integer);
begin
  FTop := AValue;
end;

procedure TNXWindow.SetWidth(AValue: Integer);
begin
  FWidth := AValue;
  SendSizeCallback;
end;

procedure TNXWindow.SetWindowBorderStyle(AValue: TNXWindowBorderStyle);
begin
  FWindowBorderStyle := AValue;

  if AValue = wbsNone then
    FFillStyle := FS_None
  else
    FFillStyle := FS_Filled;

  if Assigned(FTitleBar) then
    FTitleBar.Visible := AValue <> wbsNone;
end;

procedure TNXWindow.Show;
begin
  if Assigned(FManager) then
    FManager.ShowWindow(Self)
  else
    InternalShow(True);
end;

procedure TNXWindow.TitleBarDragged(Sender: TObject; ADeltaX,
  ADeltaY: Integer);
begin
  if not Movable then
    Exit;

  Left := Max(Left + ADeltaX, 0);
  Top := Max(Top + ADeltaY, 0);
end;

constructor TNXWindowManager.Create(ACanvas: TNXCanvas);
begin
  inherited Create;
  FActiveWindow := nil;
  FCanvas := ACanvas;
  FHoverWindow := nil;
  FModalWindow := nil;
  FWindows := TList.Create;
end;

destructor TNXWindowManager.Destroy;
var
  lIndex: Integer;
begin
  FActiveWindow := nil;
  FHoverWindow := nil;
  FModalWindow := nil;

  if Assigned(FWindows) then
    for lIndex := FWindows.Count - 1 downto 0 do
    begin
      Windows[lIndex].SetManager(nil);
      Windows[lIndex].Free;
    end;

  FreeAndNil(FWindows);
  inherited Destroy;
end;

procedure TNXWindowManager.AddWindow(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  if IndexOf(AWindow) >= 0 then
    Exit;

  if Assigned(AWindow.Manager) and (AWindow.Manager <> Self) then
    AWindow.Manager.RemoveWindow(AWindow);

  AWindow.Canvas := FCanvas;
  FWindows.Add(AWindow);
  AWindow.SetManager(Self);
end;

procedure TNXWindowManager.ApplyStartPosition(AWindow: TNXWindow);
var
  lDisplayHeight: Integer;
  lDisplayWidth: Integer;
begin
  if (not Assigned(AWindow)) or AWindow.FStartPositionApplied then
    Exit;

  AWindow.FStartPositionApplied := True;

  if (not Assigned(FCanvas)) or (not Assigned(FCanvas.Platform)) then
    Exit;

  FCanvas.Platform.GetDisplaySize(lDisplayWidth, lDisplayHeight);

  case AWindow.StartPosition of
    wspTopLeft:
    begin
      AWindow.Left := 0;
      AWindow.Top := 0;
    end;

    wspCentered,
    wspDefault:
    begin
      AWindow.Left := Max(0, (lDisplayWidth - AWindow.Width) div 2);
      AWindow.Top := Max(0, (lDisplayHeight - AWindow.Height) div 2);
    end;

    wspMaximized:
    begin
      AWindow.Left := 0;
      AWindow.Top := 0;
      AWindow.Width := lDisplayWidth;
      AWindow.Height := lDisplayHeight;
    end;
  else
    { wspManual keeps the explicit bounds already on the window. }
  end;
end;

procedure TNXWindowManager.BringToFront(AWindow: TNXWindow);
var
  lIndex: Integer;
begin
  if not Assigned(AWindow) then
    Exit;

  AddWindow(AWindow);
  lIndex := IndexOf(AWindow);
  if (lIndex >= 0) and (lIndex < FWindows.Count - 1) then
    FWindows.Move(lIndex, FWindows.Count - 1);
end;

procedure TNXWindowManager.CloseWindow(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  if not AWindow.CanClose then
    Exit;

  if AWindow.CloseAction = wcaDestroy then
  begin
    AWindow.DoClose;
    RemoveWindow(AWindow);
    AWindow.Free;
    Exit;
  end;

  AWindow.InternalClose;

  if FActiveWindow = AWindow then
  begin
    AWindow.SetActive(False);
    FActiveWindow := nil;
  end;
  if FModalWindow = AWindow then
    FModalWindow := nil;
  if FHoverWindow = AWindow then
  begin
    AWindow.ClearMouseHover;
    FHoverWindow := nil;
  end;
end;

function TNXWindowManager.CreateWindow(const ACaption: string;
  const ARect: TNXRect): TNXWindow;
begin
  Result := TNXWindow.Create(ACaption, ARect);
  AddWindow(Result);
end;

function TNXWindowManager.GetWindow(AIndex: Integer): TNXWindow;
begin
  Result := TNXWindow(FWindows[AIndex]);
end;

function TNXWindowManager.GetWindowCount: Integer;
begin
  Result := FWindows.Count;
end;

procedure TNXWindowManager.HideWindow(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  AWindow.InternalHide;

  if FActiveWindow = AWindow then
  begin
    AWindow.SetActive(False);
    FActiveWindow := nil;
  end;
  if FModalWindow = AWindow then
    FModalWindow := nil;
  if FHoverWindow = AWindow then
  begin
    AWindow.ClearMouseHover;
    FHoverWindow := nil;
  end;
end;

function TNXWindowManager.IndexOf(AWindow: TNXWindow): Integer;
begin
  Result := FWindows.IndexOf(AWindow);
end;

procedure TNXWindowManager.Paint;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FWindows.Count - 1 do
    Windows[lIndex].Paint;
end;

function TNXWindowManager.ProcessKeyDown(
  const AEvent: TNXKeyEventData): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
    FModalWindow.ProcessKeyDown(AEvent)
  else if Assigned(FActiveWindow) and FActiveWindow.Visible then
  begin
    Result := True;
    FActiveWindow.ProcessKeyDown(AEvent);
  end;
end;

function TNXWindowManager.ProcessKeyUp(
  const AEvent: TNXKeyEventData): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
    FModalWindow.ProcessKeyUp(AEvent)
  else if Assigned(FActiveWindow) and FActiveWindow.Visible then
  begin
    Result := True;
    FActiveWindow.ProcessKeyUp(AEvent);
  end;
end;

function TNXWindowManager.ProcessMouseDown(AX, AY: Integer;
  AButton: TNXMouseButton): Boolean;
var
  lIndex: Integer;
  lWindow: TNXWindow;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
  begin
    if FModalWindow.InWindow(AX, AY) then
    begin
      SetActiveWindow(FModalWindow);
      FModalWindow.ProcessMouseDown(AX - FModalWindow.AbsLeft,
        AY - FModalWindow.AbsTop, AButton);
    end
    else
      BringToFront(FModalWindow);
    Exit;
  end;

  for lIndex := FWindows.Count - 1 downto 0 do
  begin
    lWindow := Windows[lIndex];
    if lWindow.InWindow(AX, AY) then
    begin
      SetActiveWindow(lWindow);
      lWindow.ProcessMouseDown(AX - lWindow.AbsLeft, AY - lWindow.AbsTop,
        AButton);
      Result := True;
      Exit;
    end;
  end;
end;

function TNXWindowManager.ProcessMouseMotion(AX, AY: Integer;
  AButtonState: TNXMouseButtons): Boolean;
var
  lIndex: Integer;
  lWindow: TNXWindow;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
  begin
    if (FHoverWindow <> FModalWindow) and Assigned(FHoverWindow) then
      FHoverWindow.ClearMouseHover;
    FHoverWindow := FModalWindow;

    FModalWindow.ProcessMouseMotion(AX - FModalWindow.AbsLeft,
      AY - FModalWindow.AbsTop, AButtonState);
    Exit;
  end;

  for lIndex := FWindows.Count - 1 downto 0 do
  begin
    lWindow := Windows[lIndex];
    if lWindow.InWindow(AX, AY) then
    begin
      if (FHoverWindow <> lWindow) and Assigned(FHoverWindow) then
        FHoverWindow.ClearMouseHover;
      FHoverWindow := lWindow;

      lWindow.ProcessMouseMotion(AX - lWindow.AbsLeft, AY - lWindow.AbsTop,
        AButtonState);
      Result := True;
      Exit;
    end;
  end;

  if Assigned(FHoverWindow) then
  begin
    FHoverWindow.ClearMouseHover;
    FHoverWindow := nil;
  end;
end;

function TNXWindowManager.ProcessMouseUp(AX, AY: Integer;
  AButton: TNXMouseButton): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
  begin
    FModalWindow.ProcessMouseUp(AX - FModalWindow.AbsLeft,
      AY - FModalWindow.AbsTop, AButton);
    Exit;
  end;

  if Assigned(FActiveWindow) and FActiveWindow.Visible then
  begin
    FActiveWindow.ProcessMouseUp(AX - FActiveWindow.AbsLeft,
      AY - FActiveWindow.AbsTop, AButton);
    Result := True;
  end;
end;

function TNXWindowManager.ProcessTextInput(const AText: string): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
    FModalWindow.ProcessTextInput(AText)
  else if Assigned(FActiveWindow) and FActiveWindow.Visible then
  begin
    Result := True;
    FActiveWindow.ProcessTextInput(AText);
  end;
end;

procedure TNXWindowManager.RemoveWindow(AWindow: TNXWindow);
var
  lIndex: Integer;
begin
  if not Assigned(AWindow) then
    Exit;

  lIndex := IndexOf(AWindow);
  if lIndex >= 0 then
    FWindows.Delete(lIndex);

  if FActiveWindow = AWindow then
  begin
    AWindow.SetActive(False);
    FActiveWindow := nil;
  end;
  if FModalWindow = AWindow then
    FModalWindow := nil;
  if FHoverWindow = AWindow then
  begin
    AWindow.ClearMouseHover;
    FHoverWindow := nil;
  end;

  AWindow.SetManager(nil);
end;

procedure TNXWindowManager.SetActiveWindow(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  AddWindow(AWindow);
  if Assigned(FActiveWindow) and (FActiveWindow <> AWindow) then
    FActiveWindow.SetActive(False);
  FActiveWindow := AWindow;
  FActiveWindow.SetActive(True);
  ApplyStartPosition(AWindow);
  AWindow.InternalShow(True);
end;

procedure TNXWindowManager.ShowModal(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  AddWindow(AWindow);
  FModalWindow := AWindow;
  AWindow.FModal := True;
  SetActiveWindow(AWindow);
end;

procedure TNXWindowManager.ShowWindow(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  AddWindow(AWindow);
  SetActiveWindow(AWindow);
end;

end.
