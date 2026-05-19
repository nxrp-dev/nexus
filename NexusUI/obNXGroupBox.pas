unit obNXGroupBox;
{$mode objfpc}{$H+}

interface

uses
  Math,
  obNXControl,
  obNXPanel,
  obNXTitleBar,
  tpNXPlatform;

type
  TNXGroupBox = class(TNXPanel)
  private
    FTitleBar: TNXTitleBar;
  protected
    function GetAbsContentRect: TNXRect; override;
    function GetChildOriginX(AChild: TNXControl): Integer; override;
    function GetChildOriginY(AChild: TNXControl): Integer; override;
    function GetContentRect: TNXRect; override;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    constructor Create(const AParent: INXControlParent; const ACaption: string;
      const ARect: TNXRect); overload; override;

    procedure AddChild(AChild: TNXControl); override;
    procedure Paint; override;
  end;

implementation

constructor TNXGroupBox.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  FTitleBar := TNXTitleBar.Create(Self);
  FTitleBar.BackColor := Skin.TitleBarBackColor;
  FTitleBar.ParentSizeCallback(Width, Height);
end;

constructor TNXGroupBox.Create(const AParent: INXControlParent; const ACaption: string;
  const ARect: TNXRect);
begin
  Create(AParent);
  Caption := ACaption;
  FTitleBar.Caption := ACaption;
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

function TNXGroupBox.GetAbsContentRect: TNXRect;
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

function TNXGroupBox.GetChildOriginX(AChild: TNXControl): Integer;
begin
  if AChild = FTitleBar then
    Result := 0
  else
    Result := ContentRect.x;
end;

function TNXGroupBox.GetChildOriginY(AChild: TNXControl): Integer;
begin
  if AChild = FTitleBar then
    Result := 0
  else
    Result := ContentRect.y;
end;

function TNXGroupBox.GetContentRect: TNXRect;
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

procedure TNXGroupBox.AddChild(AChild: TNXControl);
var
  lTitleBarIndex: Integer;
begin
  inherited AddChild(AChild);

  if Assigned(FTitleBar) and (AChild <> FTitleBar) then
  begin
    lTitleBarIndex := Children.IndexOf(FTitleBar);
    if (lTitleBarIndex >= 0) and (lTitleBarIndex < Children.Count - 1) then
      Children.Move(lTitleBarIndex, Children.Count - 1);
  end;
end;

procedure TNXGroupBox.Paint;
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

      if Assigned(FTitleBar) then
        FTitleBar.Paint;
    finally
      Canvas.PopClip;
    end;
  end;
end;

end.
