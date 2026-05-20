unit obNXScrollableControl;

{$mode objfpc}{$H+}

interface

uses
  Math,
  tpNXPlatform,
  obNXControl,

  obNXScrollBar;

type
  TNXScrollableControl = class(TNXControl)
  private
    FContentHeight: Integer;
    FContentWidth: Integer;
    FHorizontalScrollBar: TNXScrollBar;
    FScrollX: Integer;
    FScrollY: Integer;
    FVerticalScrollBar: TNXScrollBar;

    procedure SetContentHeight(AValue: Integer);
    procedure SetContentWidth(AValue: Integer);
    procedure SetScrollX(AValue: Integer);
    procedure SetScrollY(AValue: Integer);
  protected
    procedure DoMouseWheel(X, Y, ADeltaX, ADeltaY: Integer); override;
    function GetAbsViewportRect: TNXRect; virtual;
    function GetViewportHeight: Integer; virtual;
    function GetViewportRect: TNXRect; virtual;
    function GetViewportWidth: Integer; virtual;
    procedure RenderClient; override;
    procedure RenderViewport; virtual;
    procedure UpdateScrollBars; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    property AbsViewportRect: TNXRect read GetAbsViewportRect;
    property ContentHeight: Integer read FContentHeight write SetContentHeight;
    property ContentWidth: Integer read FContentWidth write SetContentWidth;
    property HorizontalScrollBar: TNXScrollBar read FHorizontalScrollBar;
    property ScrollX: Integer read FScrollX write SetScrollX;
    property ScrollY: Integer read FScrollY write SetScrollY;
    property VerticalScrollBar: TNXScrollBar read FVerticalScrollBar;
    property ViewportHeight: Integer read GetViewportHeight;
    property ViewportRect: TNXRect read GetViewportRect;
    property ViewportWidth: Integer read GetViewportWidth;
  end;

implementation

constructor TNXScrollableControl.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  FHorizontalScrollBar := TNXScrollBar.Create(Self);
  FHorizontalScrollBar.Min := 0;
  FHorizontalScrollBar.Max := 0;
  FHorizontalScrollBar.Value := 0;
  FHorizontalScrollBar.Dir := Dir_Horizontal;
  FHorizontalScrollBar.AutoAlign := True;
  FHorizontalScrollBar.Visible := False;

  FVerticalScrollBar := TNXScrollBar.Create(Self);
  FVerticalScrollBar.Min := 0;
  FVerticalScrollBar.Max := 0;
  FVerticalScrollBar.Value := 0;
  FVerticalScrollBar.Dir := Dir_Vertical;
  FVerticalScrollBar.AutoAlign := True;
  FVerticalScrollBar.Visible := False;
end;

procedure TNXScrollableControl.SetContentHeight(AValue: Integer);
begin
  FContentHeight := Max(0, AValue);
  UpdateScrollBars;
end;

procedure TNXScrollableControl.SetContentWidth(AValue: Integer);
begin
  FContentWidth := Max(0, AValue);
  UpdateScrollBars;
end;

procedure TNXScrollableControl.SetScrollX(AValue: Integer);
begin
  if Assigned(FHorizontalScrollBar) then
    FScrollX := EnsureRange(AValue, FHorizontalScrollBar.Min, FHorizontalScrollBar.Max)
  else
    FScrollX := EnsureRange(AValue, 0, Max(0, ContentWidth - ViewportWidth));
  if Assigned(FHorizontalScrollBar) and (FHorizontalScrollBar.Value <> FScrollX) then
    FHorizontalScrollBar.Value := FScrollX;
end;

procedure TNXScrollableControl.SetScrollY(AValue: Integer);
begin
  if Assigned(FVerticalScrollBar) then
    FScrollY := EnsureRange(AValue, FVerticalScrollBar.Min, FVerticalScrollBar.Max)
  else
    FScrollY := EnsureRange(AValue, 0, Max(0, ContentHeight - ViewportHeight));
  if Assigned(FVerticalScrollBar) and (FVerticalScrollBar.Value <> FScrollY) then
    FVerticalScrollBar.Value := FScrollY;
end;

function TNXScrollableControl.GetViewportRect: TNXRect;
begin
  Result := ContentRect;

  if Assigned(FVerticalScrollBar) and FVerticalScrollBar.Visible then
    Result.w := Max(0, Result.w - FVerticalScrollBar.Width - 2);

  if Assigned(FHorizontalScrollBar) and FHorizontalScrollBar.Visible then
    Result.h := Max(0, Result.h - FHorizontalScrollBar.Height - 2);
end;

procedure TNXScrollableControl.DoMouseWheel(X, Y, ADeltaX, ADeltaY: Integer);
var
  lStep: Integer;
begin
  inherited DoMouseWheel(X, Y, ADeltaX, ADeltaY);

  if FontLineSkip > 0 then
    lStep := FontLineSkip
  else
    lStep := GUI_ScrollbarSize;

  if (ADeltaY <> 0) and Assigned(FVerticalScrollBar) and
    FVerticalScrollBar.Visible then
    ScrollY := ScrollY - (ADeltaY * lStep);

  if (ADeltaX <> 0) and Assigned(FHorizontalScrollBar) and
    FHorizontalScrollBar.Visible then
    ScrollX := ScrollX + (ADeltaX * lStep);
end;

function TNXScrollableControl.GetAbsViewportRect: TNXRect;
begin
  Result := ViewportRect;
  Result.x := AbsLeft + Result.x;
  Result.y := AbsTop + Result.y;
end;

function TNXScrollableControl.GetViewportHeight: Integer;
begin
  Result := ViewportRect.h;
end;

function TNXScrollableControl.GetViewportWidth: Integer;
begin
  Result := ViewportRect.w;
end;

procedure TNXScrollableControl.UpdateScrollBars;
var
  lContentRect: TNXRect;
  lHorizontalVisible: Boolean;
  lVerticalVisible: Boolean;
  lViewportHeight: Integer;
  lViewportWidth: Integer;
begin
  if (not Assigned(FHorizontalScrollBar)) or (not Assigned(FVerticalScrollBar)) then
    Exit;

  lContentRect := ContentRect;
  lViewportWidth := lContentRect.w;
  lViewportHeight := lContentRect.h;

  lVerticalVisible := ContentHeight > lViewportHeight;
  if lVerticalVisible then
    Dec(lViewportWidth, FVerticalScrollBar.Width + 2);

  lHorizontalVisible := ContentWidth > lViewportWidth;
  if lHorizontalVisible then
    Dec(lViewportHeight, FHorizontalScrollBar.Height + 2);

  if (not lVerticalVisible) and (ContentHeight > lViewportHeight) then
  begin
    lVerticalVisible := True;
    Dec(lViewportWidth, FVerticalScrollBar.Width + 2);
  end;

  FHorizontalScrollBar.AutoAlignBoth := lVerticalVisible;
  FVerticalScrollBar.AutoAlignBoth := lHorizontalVisible;
  FHorizontalScrollBar.Visible := lHorizontalVisible;
  FVerticalScrollBar.Visible := lVerticalVisible;

  FHorizontalScrollBar.Max := Max(0, ContentWidth - Max(0, lViewportWidth));
  FVerticalScrollBar.Max := Max(0, ContentHeight - Max(0, lViewportHeight));

  SetScrollX(FScrollX);
  SetScrollY(FScrollY);
end;

procedure TNXScrollableControl.RenderClient;
var
  lClipRect: TNXRect;
begin
  UpdateScrollBars;

  if Assigned(FHorizontalScrollBar) then
    FScrollX := FHorizontalScrollBar.Value;
  if Assigned(FVerticalScrollBar) then
    FScrollY := FVerticalScrollBar.Value;

  lClipRect := AbsViewportRect;
  Canvas.PushClip(lClipRect);
  try
    RenderViewport;
  finally
    Canvas.PopClip;
  end;
end;

procedure TNXScrollableControl.RenderViewport;
begin
end;

end.
