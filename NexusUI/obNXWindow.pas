unit obNXWindow;
{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  obNXElement,
  obNXPanel,
  tpNXEvents,
  tpNXPlatform,
  tpNXWindow;

type
  TNXWindowManager = class;

  TNXWindow = class(TNXPanel)
  private
    FWindowBorderStyle: TNXWindowBorderStyle;
    FCanClose: Boolean;
    FCloseAction: TNXWindowCloseAction;
    FManager: TNXWindowManager;
    FModal: Boolean;
    FModalResult: TNXModalResult;
    FOnClose: TNotifyEvent;
    FOnHide: TNotifyEvent;
    FOnShow: TNotifyEvent;
  protected
    procedure DoClose; virtual;
    procedure DoHide; virtual;
    procedure DoShow; virtual;
    procedure InternalClose; virtual;
    procedure InternalHide; virtual;
    procedure InternalShow(AActivate: Boolean); virtual;
    procedure SetManager(AManager: TNXWindowManager); virtual;
  public
    constructor Create(AParent: TNXElement); overload; override;
    constructor Create(AParent: TNXElement; const ACaption: string;
      const ARect: TNXRect); overload; override;

    procedure Activate; virtual;
    procedure BringWindowToFront; virtual;
    procedure Close; virtual;
    procedure Hide; virtual;
    procedure Show; virtual;

    property BorderStyleKind: TNXWindowBorderStyle read FWindowBorderStyle write FWindowBorderStyle;
    property CanClose: Boolean read FCanClose write FCanClose;
    property CloseAction: TNXWindowCloseAction read FCloseAction write FCloseAction;
    property Manager: TNXWindowManager read FManager;
    property Modal: Boolean read FModal;
    property ModalResult: TNXModalResult read FModalResult write FModalResult;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
  end;

  TNXWindowManager = class
  private
    FActiveWindow: TNXWindow;
    FHost: TNXElement;
    FModalWindow: TNXWindow;
    FWindows: TList;

    function GetWindow(AIndex: Integer): TNXWindow;
    function GetWindowCount: Integer;
    function PointInWindow(AWindow: TNXWindow; AX, AY: Integer): Boolean;
    procedure SetActiveWindow(AWindow: TNXWindow);
  public
    constructor Create(AHost: TNXElement);
    destructor Destroy; override;

    procedure AddWindow(AWindow: TNXWindow);
    function CreateWindow(const ACaption: string; const ARect: TNXRect): TNXWindow;
    procedure BringToFront(AWindow: TNXWindow);
    procedure CloseWindow(AWindow: TNXWindow);
    procedure HideWindow(AWindow: TNXWindow);
    function IndexOf(AWindow: TNXWindow): Integer;
    procedure RemoveWindow(AWindow: TNXWindow);
    procedure ShowModal(AWindow: TNXWindow);
    procedure ShowWindow(AWindow: TNXWindow);

    function ProcessKeyDown(const AEvent: TNXKeyEventData): Boolean;
    function ProcessKeyUp(const AEvent: TNXKeyEventData): Boolean;
    function ProcessMouseDown(AX, AY: Integer; AButton: TNXMouseButton): Boolean;
    function ProcessMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons): Boolean;
    function ProcessMouseUp(AX, AY: Integer; AButton: TNXMouseButton): Boolean;
    function ProcessTextInput(const AText: string): Boolean;

    property ActiveWindow: TNXWindow read FActiveWindow;
    property Host: TNXElement read FHost;
    property ModalWindow: TNXWindow read FModalWindow;
    property WindowCount: Integer read GetWindowCount;
    property Windows[AIndex: Integer]: TNXWindow read GetWindow;
  end;

implementation

constructor TNXWindow.Create(AParent: TNXElement);
begin
  inherited Create(AParent);
  FWindowBorderStyle := wbsSingle;
  FCanClose := True;
  FCloseAction := wcaHide;
  FManager := nil;
  FModal := False;
  FModalResult := mrNone;
end;

constructor TNXWindow.Create(AParent: TNXElement; const ACaption: string;
  const ARect: TNXRect);
begin
  inherited Create(AParent, ACaption, ARect);
  FWindowBorderStyle := wbsSingle;
  FCanClose := True;
  FCloseAction := wcaHide;
  FManager := nil;
  FModal := False;
  FModalResult := mrNone;
end;

procedure TNXWindow.Activate;
begin
  if Assigned(FManager) then
    FManager.ShowWindow(Self)
  else
    InternalShow(True);
end;

procedure TNXWindow.BringWindowToFront;
begin
  inherited BringToFront;
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

procedure TNXWindow.Hide;
begin
  if Assigned(FManager) then
    FManager.HideWindow(Self)
  else
    InternalHide;
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
  begin
    IsSelected := True;
    BringWindowToFront;
  end;
end;

procedure TNXWindow.SetManager(AManager: TNXWindowManager);
begin
  FManager := AManager;
end;

procedure TNXWindow.Show;
begin
  if Assigned(FManager) then
    FManager.ShowWindow(Self)
  else
    InternalShow(True);
end;

constructor TNXWindowManager.Create(AHost: TNXElement);
begin
  inherited Create;
  FActiveWindow := nil;
  FHost := AHost;
  FModalWindow := nil;
  FWindows := TList.Create;
end;

destructor TNXWindowManager.Destroy;
begin
  FreeAndNil(FWindows);
  inherited Destroy;
end;

procedure TNXWindowManager.AddWindow(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  if AWindow.Parent <> FHost then
    raise Exception.Create('TNXWindowManager can only manage windows parented by its host');

  if IndexOf(AWindow) >= 0 then
    Exit;

  FWindows.Add(AWindow);
  AWindow.SetManager(Self);
end;

function TNXWindowManager.CreateWindow(const ACaption: string;
  const ARect: TNXRect): TNXWindow;
begin
  Result := TNXWindow.Create(FHost, ACaption, ARect);
  AddWindow(Result);
end;

procedure TNXWindowManager.BringToFront(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  AddWindow(AWindow);
  AWindow.BringWindowToFront;
end;

procedure TNXWindowManager.CloseWindow(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  if AWindow.CloseAction = wcaDestroy then
  begin
    AWindow.DoClose;
    RemoveWindow(AWindow);

    if Assigned(FHost) and (AWindow.Parent = FHost) then
      FHost.FreeChild(AWindow)
    else
      AWindow.Free;

    Exit;
  end;

  AWindow.InternalClose;

  if FActiveWindow = AWindow then
    FActiveWindow := nil;
  if FModalWindow = AWindow then
    FModalWindow := nil;
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
    FActiveWindow := nil;
  if FModalWindow = AWindow then
    FModalWindow := nil;
end;

function TNXWindowManager.IndexOf(AWindow: TNXWindow): Integer;
begin
  Result := FWindows.IndexOf(AWindow);
end;

function TNXWindowManager.PointInWindow(AWindow: TNXWindow; AX,
  AY: Integer): Boolean;
begin
  Result := Assigned(AWindow) and AWindow.Visible and
    (AX >= AWindow.AbsLeft) and (AX < AWindow.AbsLeft + AWindow.Width) and
    (AY >= AWindow.AbsTop) and (AY < AWindow.AbsTop + AWindow.Height);
end;

function TNXWindowManager.ProcessKeyDown(
  const AEvent: TNXKeyEventData): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
    FModalWindow.ProcessKeyDown(AEvent);
end;

function TNXWindowManager.ProcessKeyUp(
  const AEvent: TNXKeyEventData): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
    FModalWindow.ProcessKeyUp(AEvent);
end;

function TNXWindowManager.ProcessMouseDown(AX, AY: Integer;
  AButton: TNXMouseButton): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if not Result then
    Exit;

  if PointInWindow(FModalWindow, AX, AY) then
  begin
    SetActiveWindow(FModalWindow);
    FModalWindow.ProcessMouseDown(AX - FModalWindow.AbsLeft,
      AY - FModalWindow.AbsTop, AButton);
  end
  else
    BringToFront(FModalWindow);
end;

function TNXWindowManager.ProcessMouseMotion(AX, AY: Integer;
  AButtonState: TNXMouseButtons): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
    FModalWindow.ProcessMouseMotion(AX - FModalWindow.AbsLeft,
      AY - FModalWindow.AbsTop, AButtonState);
end;

function TNXWindowManager.ProcessMouseUp(AX, AY: Integer;
  AButton: TNXMouseButton): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
    FModalWindow.ProcessMouseUp(AX - FModalWindow.AbsLeft,
      AY - FModalWindow.AbsTop, AButton);
end;

function TNXWindowManager.ProcessTextInput(const AText: string): Boolean;
begin
  Result := Assigned(FModalWindow) and FModalWindow.Visible;
  if Result then
    FModalWindow.ProcessTextInput(AText);
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
    FActiveWindow := nil;
  if FModalWindow = AWindow then
    FModalWindow := nil;

  AWindow.SetManager(nil);
end;

procedure TNXWindowManager.SetActiveWindow(AWindow: TNXWindow);
begin
  if not Assigned(AWindow) then
    Exit;

  AddWindow(AWindow);
  FActiveWindow := AWindow;
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
