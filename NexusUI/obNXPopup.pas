unit obNXPopup;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXControl,

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
    procedure ProcessMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
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

procedure TNXPopupManager.ProcessMouseDown(AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  if AButton = mbNone then
    Exit;

  if not Assigned(FActivePopup) or not FActivePopup.Visible then
    Exit;

  if PointInElement(FActivePopup, AX, AY) or
    PointInElement(FActivePopup.Owner, AX, AY) then
    Exit;

  HidePopup(FActivePopup);
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
