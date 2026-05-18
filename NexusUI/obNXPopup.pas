unit obNXPopup;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXControl,
  obNXElement,
  tpNXPlatform;

type
  TNXPopup = class(TNXControl)
  private
    FOwner: TNXElement;
  protected
    procedure DoClosed; virtual;
    procedure DoOpened; virtual;
  public
    constructor Create(AParent, AOwner: TNXElement); reintroduce; virtual;
    procedure Close; virtual;
    procedure Open; virtual;

    property Owner: TNXElement read FOwner;
  end;

  TNXPopupManager = class
  private
    FActivePopup: TNXPopup;
    FHost: TNXElement;

    function PointInElement(AElement: TNXElement; AX, AY: Integer): Boolean;
  public
    constructor Create(AHost: TNXElement);
    procedure BringActiveToFront;
    procedure HidePopup(APopup: TNXPopup);
    procedure HidePopups;
    procedure ProcessMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
    procedure ShowPopup(APopup: TNXPopup);

    property ActivePopup: TNXPopup read FActivePopup;
  end;

implementation

constructor TNXPopup.Create(AParent, AOwner: TNXElement);
begin
  inherited Create(AParent);
  FOwner := AOwner;
  BorderStyle := BS_Single;
  Selectable := False;
  Visible := False;
end;

procedure TNXPopup.Close;
begin
  if not Visible then
    Exit;

  Visible := False;
  DoClosed;
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

constructor TNXPopupManager.Create(AHost: TNXElement);
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

function TNXPopupManager.PointInElement(AElement: TNXElement; AX,
  AY: Integer): Boolean;
begin
  Result := Assigned(AElement) and AElement.Visible and
    (AX >= AElement.AbsLeft) and (AX < AElement.AbsLeft + AElement.Width) and
    (AY >= AElement.AbsTop) and (AY < AElement.AbsTop + AElement.Height);
end;

procedure TNXPopupManager.HidePopup(APopup: TNXPopup);
begin
  if not Assigned(APopup) then
    Exit;

  APopup.Close;
  if FActivePopup = APopup then
    FActivePopup := nil;
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
    FActivePopup.Close;

  FActivePopup := APopup;
  BringActiveToFront;
  APopup.Open;
end;

end.
