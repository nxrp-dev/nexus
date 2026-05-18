unit obNXPanel;
{$mode objfpc}{$H+}

interface

uses
  Math, tpNXPlatform, obNXElement, obNXControl;

type
  TNXPanelKind = (
    pkPanel,
    pkGroupBox
  );

  TGUI_TitleBar = class(TNXControl)
  public
    constructor Create(AParent: TNXElement); overload; override;
    destructor Destroy; override;
    procedure Render; override;
    procedure ParentSizeCallback(AWidth, AHeight: Integer); override;
    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseExit; override;
  private
    FMoving: Boolean;
    FInitMoveX, FInitMoveY: Integer;
  end;

  TNXPanel = class(TNXControl)
  private
    FKind: TNXPanelKind;
    FMovable: Boolean;
    FTitleBar: TGUI_TitleBar;
  protected
    function GetAbsContentRect: TNXRect; override;
    function GetChildOriginX(AChild: TNXElement): Integer; override;
    function GetChildOriginY(AChild: TNXElement): Integer; override;
    function GetContentRect: TNXRect; override;
    procedure SetMovable(AValue: Boolean);
    function GetMovable: Boolean;
  public
    constructor Create(AParent: TNXElement); overload; override;
    constructor Create(AParent: TNXElement; const ACaption: string;
      const ARect: TNXRect); overload; virtual;
    destructor Destroy; override;
    procedure AddChild(Child: TNXElement); override;
    procedure Paint; override;
    procedure ProcessSelected; override;

    property Movable: Boolean read GetMovable write SetMovable;
    property Kind: TNXPanelKind read FKind write FKind;
  end;

implementation

constructor TGUI_TitleBar.Create(AParent: TNXElement);
begin
  inherited Create(AParent);
  Left := 0;
  Top := 0;
  BackColor := Skin.TitleBarBackColor;
  FMoving := False;
end;

destructor TGUI_TitleBar.Destroy;
begin
  inherited Destroy;
end;

procedure TGUI_TitleBar.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
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

procedure TGUI_TitleBar.DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons);
var
  lAmtX, lAmtY: Integer;
begin
  inherited;

  if FMoving and (Parent <> nil) and (Parent is TNXPanel) and
    (not (Parent as TNXPanel).Movable) then
  begin
    FMoving := False;
    ReleaseMouseCapture;
    Exit;
  end;

  if FMoving and
    (not (mbLeft in AButtonState)) then
  begin
    FMoving := False;
    ReleaseMouseCapture;
    Exit;
  end;

  if FMoving and (Parent <> nil) then
  begin
    lAmtX := AX - FInitMoveX;
    lAmtY := AY - FInitMoveY;

    Parent.Left := Max(Parent.Left + lAmtX, 0);
    Parent.Top := Max(Parent.Top + lAmtY, 0);
  end;
end;

procedure TGUI_TitleBar.DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited;
  if FMoving and (AButton = mbLeft) then
  begin
    FMoving := False;
    ReleaseMouseCapture;
  end;
end;

procedure TGUI_TitleBar.DoMouseExit;
begin
  inherited;
end;

procedure TGUI_TitleBar.Render;
begin
  if Parent.IsSelected then
    CurFillColor := BackColor
  else
    CurFillColor := Skin.UnselectedTitleBarBackColor;

  inherited Render;

  RenderText(
    (Parent as TNXControl).Caption,
    Width div 2,
    (Height - FontHeight) div 2,
    Align_Center
  );
end;

procedure TGUI_TitleBar.ParentSizeCallback(AWidth, AHeight: Integer);
begin
  Width := AWidth;
  if FontHeight > 0 then
    Height := FontHeight
  else
    Height := GUI_TitleBarHeight;
end;

constructor TNXPanel.Create(AParent: TNXElement);
begin
  inherited Create(AParent);

  FTitleBar := TGUI_TitleBar.Create(Self);
  FTitleBar.BorderStyle := BS_Single;
  FTitleBar.BackColor := Skin.TitleBarBackColor;
  FTitleBar.Left := 0;
  FTitleBar.Top := 0;

  FKind := pkGroupBox;
  BackColor := Skin.FormBackColor;
  Left := 100;
  Top := 100;
  Movable := True;

  BorderStyle := BS_Single;

end;

constructor TNXPanel.Create(AParent: TNXElement; const ACaption: string;
  const ARect: TNXRect);
begin
  Create(AParent);
  Caption := ACaption;
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

destructor TNXPanel.Destroy;
begin
  inherited Destroy;
end;

procedure TNXPanel.ProcessSelected;
begin
  inherited ProcessSelected;
  BringToFront;
end;

function TNXPanel.GetAbsContentRect: TNXRect;
var
  lBorderThickness: Integer;
  lTitleBarHeight: Integer;
begin
  lBorderThickness := GetBorderThickness;
  lTitleBarHeight := 0;
  if Assigned(FTitleBar) then
    lTitleBarHeight := FTitleBar.Height;

  Result := MakeNXRect(
    AbsLeft + lBorderThickness,
    AbsTop + lBorderThickness + lTitleBarHeight,
    Max(0, Width - (lBorderThickness * 2)),
    Max(0, Height - (lBorderThickness * 2) - lTitleBarHeight)
  );
end;

function TNXPanel.GetContentRect: TNXRect;
var
  lBorderThickness: Integer;
  lTitleBarHeight: Integer;
begin
  lBorderThickness := GetBorderThickness;
  lTitleBarHeight := 0;
  if Assigned(FTitleBar) then
    lTitleBarHeight := FTitleBar.Height;

  Result := MakeNXRect(
    lBorderThickness,
    lBorderThickness + lTitleBarHeight,
    Max(0, Width - (lBorderThickness * 2)),
    Max(0, Height - (lBorderThickness * 2) - lTitleBarHeight)
  );
end;

function TNXPanel.GetChildOriginX(AChild: TNXElement): Integer;
begin
  if AChild = FTitleBar then
    Result := 0
  else
    Result := ContentRect.x;
end;

function TNXPanel.GetChildOriginY(AChild: TNXElement): Integer;
begin
  if AChild = FTitleBar then
    Result := 0
  else
    Result := ContentRect.y;
end;

procedure TNXPanel.AddChild(Child: TNXElement);
var
  lTitleBarIndex: Integer;
begin
  inherited AddChild(Child);

  if Assigned(FTitleBar) and (Child <> FTitleBar) then
  begin
    lTitleBarIndex := Children.IndexOf(FTitleBar);
    if (lTitleBarIndex >= 0) and (lTitleBarIndex < Children.Count - 1) then
      Children.Move(lTitleBarIndex, Children.Count - 1);
  end;
end;

procedure TNXPanel.Paint;
var
  lChild: TNXElement;
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

      if Assigned(FTitleBar) then
        FTitleBar.Paint;
    finally
      Canvas.PopClip;
    end;
  end;
end;

procedure TNXPanel.SetMovable(AValue: Boolean);
begin
  FMovable := AValue;
end;

function TNXPanel.GetMovable: Boolean;
begin
  Result := FMovable;
end;

begin

end.
