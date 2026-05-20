unit obNXPopup;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXControl,

  tpNXEvents,
  tpNXPlatform;

type
  TNXPopupManager = class;

  TNXPopup = class(TNXControl)
  private
    FManager: TNXPopupManager;
    FOwner: TNXControl;
    procedure CloseInternal;
  protected
    procedure DoClosed; virtual;
    procedure DoOpened; virtual;
  public
    constructor Create(const AParent: INXControlParent; AOwner: TNXControl); reintroduce; virtual;
    destructor Destroy; override;
    procedure Close; virtual;
    procedure Open; virtual;
    procedure SetAbsoluteBounds(ALeft, ATop, AWidth, AHeight: Integer); virtual;
    procedure SetAbsolutePosition(ALeft, ATop: Integer); virtual;

    property Owner: TNXControl read FOwner;
  end;

  TNXPopupManager = class
  private
    FActivePopup: TNXPopup;
    FHost: INXControlParent;

    procedure ForgetPopup(APopup: TNXPopup);
    function PointInElement(AElement: TNXControl; AX, AY: Integer): Boolean;
  public
    constructor Create(const AHost: INXControlParent);
    procedure BringActiveToFront;
    procedure HidePopup(APopup: TNXPopup);
    procedure HidePopups;
    function ProcessKeyDown(const AEvent: TNXKeyEventData): Boolean;
    function ProcessKeyUp(const AEvent: TNXKeyEventData): Boolean;
    function ProcessMouseDown(AX, AY: Integer; AButton: TNXMouseButton): Boolean;
    function ProcessMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons): Boolean;
    function ProcessMouseUp(AX, AY: Integer; AButton: TNXMouseButton): Boolean;
    function ProcessTextInput(const AText: string): Boolean;
    procedure ShowPopup(APopup: TNXPopup);

    property ActivePopup: TNXPopup read FActivePopup;
  end;

implementation

constructor TNXPopup.Create(const AParent: INXControlParent; AOwner: TNXControl);
begin
  inherited Create(AParent);
  FManager := nil;
  FOwner := AOwner;
  BorderStyle := BS_Single;
  CanFocus := False;
  Visible := False;
end;

destructor TNXPopup.Destroy;
begin
  if Assigned(FManager) then
    FManager.ForgetPopup(Self);

  inherited Destroy;
end;

procedure TNXPopup.CloseInternal;
begin
  if not Visible then
    Exit;

  Visible := False;
  DoClosed;
end;

procedure TNXPopup.Close;
begin
  if Assigned(FManager) then
    FManager.HidePopup(Self)
  else
    CloseInternal;
end;

procedure TNXPopup.Open;
begin
  if Visible then
    Exit;

  Visible := True;
  DoOpened;
end;

procedure TNXPopup.DoClosed;
begin
end;

procedure TNXPopup.DoOpened;
begin
end;

procedure TNXPopup.SetAbsoluteBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  Width := AWidth;
  Height := AHeight;
  SetAbsolutePosition(ALeft, ATop);
end;

procedure TNXPopup.SetAbsolutePosition(ALeft, ATop: Integer);
var
  lPoint: TNXPoint;
begin
  if Assigned(Parent) then
  begin
    lPoint := Parent.ScreenToLocal(ALeft, ATop);
    Left := lPoint.x - Parent.GetChildOriginX(Self);
    Top := lPoint.y - Parent.GetChildOriginY(Self);
  end
  else
  begin
    Left := ALeft;
    Top := ATop;
  end;
end;

constructor TNXPopupManager.Create(const AHost: INXControlParent);
begin
  inherited Create;
  FHost := AHost;
  FActivePopup := nil;
end;

procedure TNXPopupManager.BringActiveToFront;
var
  lIndex: Integer;
begin
  if not Assigned(FHost) or not Assigned(FActivePopup) then
    Exit;

  lIndex := FHost.Children.IndexOf(FActivePopup);
  if (lIndex >= 0) and (lIndex < FHost.Children.Count - 1) then
    FHost.Children.Move(lIndex, FHost.Children.Count - 1);
end;

function TNXPopupManager.PointInElement(AElement: TNXControl; AX,
  AY: Integer): Boolean;
begin
  Result := Assigned(AElement) and AElement.Visible and
    AElement.ContainsScreenPoint(AX, AY);
end;

procedure TNXPopupManager.ForgetPopup(APopup: TNXPopup);
begin
  if not Assigned(APopup) then
    Exit;

  if FActivePopup = APopup then
    FActivePopup := nil;

  if APopup.FManager = Self then
    APopup.FManager := nil;
end;

procedure TNXPopupManager.HidePopup(APopup: TNXPopup);
begin
  if not Assigned(APopup) then
    Exit;

  if FActivePopup = APopup then
    FActivePopup := nil;

  APopup.CloseInternal;
end;

procedure TNXPopupManager.HidePopups;
begin
  HidePopup(FActivePopup);
end;

function TNXPopupManager.ProcessKeyDown(const AEvent: TNXKeyEventData): Boolean;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if AEvent.Key = nkEscape then
  begin
    HidePopup(FActivePopup);
    Exit;
  end;

  if FActivePopup.CanFocus then
    FActivePopup.ProcessKeyDown(AEvent)
  else if Assigned(FActivePopup.Owner) then
    FActivePopup.Owner.ProcessKeyDown(AEvent);
end;

function TNXPopupManager.ProcessKeyUp(const AEvent: TNXKeyEventData): Boolean;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if FActivePopup.CanFocus then
    FActivePopup.ProcessKeyUp(AEvent)
  else if Assigned(FActivePopup.Owner) then
    FActivePopup.Owner.ProcessKeyUp(AEvent);
end;

function TNXPopupManager.ProcessMouseDown(AX, AY: Integer;
  AButton: TNXMouseButton): Boolean;
var
  lPoint: TNXPoint;
begin
  Result := False;
  if AButton = mbNone then
    Exit;

  if not Assigned(FActivePopup) or not FActivePopup.Visible then
    Exit;

  if PointInElement(FActivePopup, AX, AY) then
  begin
    lPoint := FActivePopup.ScreenToLocal(AX, AY);
    FActivePopup.ProcessMouseDown(lPoint.x, lPoint.y, AButton);
    Result := True;
    Exit;
  end;

  if PointInElement(FActivePopup.Owner, AX, AY) then
    Exit;

  HidePopup(FActivePopup);
end;

function TNXPopupManager.ProcessMouseMotion(AX, AY: Integer;
  AButtonState: TNXMouseButtons): Boolean;
var
  lPoint: TNXPoint;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if PointInElement(FActivePopup, AX, AY) then
  begin
    if not FActivePopup.MouseEntered then
      FActivePopup.ProcessMouseEnter;

    lPoint := FActivePopup.ScreenToLocal(AX, AY);
    FActivePopup.ProcessMouseMotion(lPoint.x, lPoint.y, AButtonState);
    Exit;
  end;

  if FActivePopup.MouseEntered then
    FActivePopup.ProcessMouseExit;

  Result := False;
end;

function TNXPopupManager.ProcessMouseUp(AX, AY: Integer;
  AButton: TNXMouseButton): Boolean;
var
  lPoint: TNXPoint;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if PointInElement(FActivePopup, AX, AY) then
  begin
    lPoint := FActivePopup.ScreenToLocal(AX, AY);
    FActivePopup.ProcessMouseUp(lPoint.x, lPoint.y, AButton);
    Exit;
  end;

  Result := False;
end;

function TNXPopupManager.ProcessTextInput(const AText: string): Boolean;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if FActivePopup.CanFocus then
    FActivePopup.ProcessTextInput(AText)
  else if Assigned(FActivePopup.Owner) then
    FActivePopup.Owner.ProcessTextInput(AText);
end;

procedure TNXPopupManager.ShowPopup(APopup: TNXPopup);
begin
  if not Assigned(APopup) then
    Exit;

  if Assigned(FActivePopup) and (FActivePopup <> APopup) then
    HidePopup(FActivePopup);

  FActivePopup := APopup;
  APopup.FManager := Self;
  BringActiveToFront;
  APopup.Open;
end;

end.
