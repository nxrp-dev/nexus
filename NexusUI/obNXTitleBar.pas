unit obNXTitleBar;
{$mode objfpc}{$H+}

interface

uses
  Math,
  obNXControl,
  obNXElement,
  tpNXPlatform;

type
  TNXTitleBar = class(TNXControl)
  private
    FMoving: Boolean;
    FInitMoveX: Integer;
    FInitMoveY: Integer;
    FMovable: Boolean;
  public
    constructor Create(AParent: TNXElement); overload; override;

    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure ParentSizeCallback(AWidth, AHeight: Integer); override;
    procedure Render; override;

    property Movable: Boolean read FMovable write FMovable;
  end;

implementation

constructor TNXTitleBar.Create(AParent: TNXElement);
begin
  inherited Create(AParent);
  Left := 0;
  Top := 0;
  BackColor := Skin.TitleBarBackColor;
  BorderStyle := BS_Single;
  FMoving := False;
  FMovable := False;
end;

procedure TNXTitleBar.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited;

  if FMovable and (AButton = mbLeft) then
  begin
    FMoving := True;
    CaptureMouse;
  end;

  FInitMoveX := AX;
  FInitMoveY := AY;
end;

procedure TNXTitleBar.DoMouseMotion(AX, AY: Integer;
  AButtonState: TNXMouseButtons);
var
  lAmtX: Integer;
  lAmtY: Integer;
begin
  inherited;

  if FMoving and (not (mbLeft in AButtonState)) then
  begin
    FMoving := False;
    ReleaseMouseCapture;
    Exit;
  end;

  if FMoving and Assigned(Parent) then
  begin
    lAmtX := AX - FInitMoveX;
    lAmtY := AY - FInitMoveY;

    Parent.Left := Max(Parent.Left + lAmtX, 0);
    Parent.Top := Max(Parent.Top + lAmtY, 0);
  end;
end;

procedure TNXTitleBar.DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited;

  if FMoving and (AButton = mbLeft) then
  begin
    FMoving := False;
    ReleaseMouseCapture;
  end;
end;

procedure TNXTitleBar.ParentSizeCallback(AWidth, AHeight: Integer);
begin
  Width := AWidth;

  if FontHeight > 0 then
    Height := FontHeight
  else
    Height := GUI_TitleBarHeight;
end;

procedure TNXTitleBar.Render;
begin
  if Assigned(Parent) and Parent.IsSelected then
    CurFillColor := BackColor
  else
    CurFillColor := Skin.UnselectedTitleBarBackColor;

  inherited Render;

  RenderText(Caption, Width div 2, (Height - FontHeight) div 2,
    Align_Center);
end;

end.
