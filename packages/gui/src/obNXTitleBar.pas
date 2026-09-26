unit obNXTitleBar;
{$mode objfpc}{$H+}

interface

uses
  obNXControl,

  tpNXPlatform;

type
  TNXTitleBarDragEvent = procedure(Sender: TObject; ADeltaX,
    ADeltaY: Integer) of object;

  TNXTitleBar = class(TNXControl)
  private
    FActive: Boolean;
    FMoving: Boolean;
    FInitMoveX: Integer;
    FInitMoveY: Integer;
    FOnDrag: TNXTitleBarDragEvent;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure ParentSizeCallback(AWidth, AHeight: Integer); override;
    procedure Render; override;

    property Active: Boolean read FActive write FActive;
    property OnDrag: TNXTitleBarDragEvent read FOnDrag write FOnDrag;
  end;

implementation

constructor TNXTitleBar.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  Left := 0;
  Top := 0;
  BackColor := Skin.TitleBarBackColor;
  BorderStyle := BS_Single;
  FActive := False;
  FMoving := False;
end;

procedure TNXTitleBar.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited;

  if AButton = mbLeft then
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

  if FMoving then
  begin
    lAmtX := AX - FInitMoveX;
    lAmtY := AY - FInitMoveY;

    if Assigned(FOnDrag) then
      FOnDrag(Self, lAmtX, lAmtY);
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
  if Active then
    CurFillColor := BackColor
  else
    CurFillColor := Skin.UnselectedTitleBarBackColor;

  inherited Render;

  RenderText(Caption, Width div 2, (Height - FontHeight) div 2,
    Align_Center);
end;

end.
