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
    FContentSizeDirty: Boolean;
    FContentHeight: Integer;
    FContentWidth: Integer;
    FHorizontalScrollBar: TNXScrollBar;
    FScrollX: Integer;
    FScrollY: Integer;
    FScrollMetricsDirty: Boolean;
    FUpdatingScrollBars: Boolean;
    FVerticalScrollBar: TNXScrollBar;

    function GetMaxScrollX: Integer;
    function GetMaxScrollY: Integer;
    procedure ScrollBarChanged(ASender: TObject);
    procedure SetContentHeight(AValue: Integer);
    procedure SetContentWidth(AValue: Integer);
    procedure SyncScrollBarValue(AScrollBar: TNXScrollBar; AValue: Integer);
  protected
    procedure BeginScrollBarUpdate(var AWasUpdating: Boolean); virtual;
    procedure DoMouseWheel(X, Y, ADeltaX, ADeltaY: Integer); override;
    procedure EndScrollBarUpdate(AWasUpdating: Boolean); virtual;
    function GetAbsScrollableViewportRect: TNXRect; virtual;
    function GetAbsViewportRect: TNXRect; virtual;
    function GetScrollableViewportRect: TNXRect; virtual;
    function GetViewportHeight: Integer; virtual;
    function GetViewportRect: TNXRect; virtual;
    function GetViewportWidth: Integer; virtual;
    procedure InvalidateContentSize; virtual;
    procedure InvalidateScrollMetrics; virtual;
    procedure MeasureContent; virtual;
    procedure SetScrollX(AValue: Integer); virtual;
    procedure SetScrollY(AValue: Integer); virtual;
    procedure RenderClient; override;
    procedure RenderViewport; virtual;
    procedure RenderViewportChrome; virtual;
    procedure UpdateLayoutIfNeeded; virtual;
    procedure UpdateScrollMetrics; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    property AbsScrollableViewportRect: TNXRect read GetAbsScrollableViewportRect;
    property AbsViewportRect: TNXRect read GetAbsViewportRect;
    property ContentHeight: Integer read FContentHeight write SetContentHeight;
    property ContentWidth: Integer read FContentWidth write SetContentWidth;
    property HorizontalScrollBar: TNXScrollBar read FHorizontalScrollBar;
    property ScrollX: Integer read FScrollX write SetScrollX;
    property ScrollY: Integer read FScrollY write SetScrollY;
    property ScrollableViewportRect: TNXRect read GetScrollableViewportRect;
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
  FHorizontalScrollBar.OnChange := @ScrollBarChanged;

  FVerticalScrollBar := TNXScrollBar.Create(Self);
  FVerticalScrollBar.Min := 0;
  FVerticalScrollBar.Max := 0;
  FVerticalScrollBar.Value := 0;
  FVerticalScrollBar.Dir := Dir_Vertical;
  FVerticalScrollBar.AutoAlign := True;
  FVerticalScrollBar.Visible := False;
  FVerticalScrollBar.OnChange := @ScrollBarChanged;

  InvalidateContentSize;
end;

procedure TNXScrollableControl.BeginScrollBarUpdate(var AWasUpdating: Boolean);
begin
  AWasUpdating := FUpdatingScrollBars;
  FUpdatingScrollBars := True;
end;

procedure TNXScrollableControl.EndScrollBarUpdate(AWasUpdating: Boolean);
begin
  FUpdatingScrollBars := AWasUpdating;
end;

function TNXScrollableControl.GetMaxScrollX: Integer;
begin
  if Assigned(FHorizontalScrollBar) then
    Result := FHorizontalScrollBar.Max
  else
    Result := Max(0, ContentWidth - ViewportWidth);
end;

function TNXScrollableControl.GetMaxScrollY: Integer;
begin
  if Assigned(FVerticalScrollBar) then
    Result := FVerticalScrollBar.Max
  else
    Result := Max(0, ContentHeight - ViewportHeight);
end;

procedure TNXScrollableControl.ScrollBarChanged(ASender: TObject);
begin
  if FUpdatingScrollBars then
    Exit;

  if ASender = FHorizontalScrollBar then
    SetScrollX(FHorizontalScrollBar.Value)
  else if ASender = FVerticalScrollBar then
    SetScrollY(FVerticalScrollBar.Value);
end;

procedure TNXScrollableControl.SetContentHeight(AValue: Integer);
begin
  AValue := Max(0, AValue);
  if FContentHeight = AValue then
    Exit;

  FContentHeight := AValue;
  InvalidateScrollMetrics;
end;

procedure TNXScrollableControl.SetContentWidth(AValue: Integer);
begin
  AValue := Max(0, AValue);
  if FContentWidth = AValue then
    Exit;

  FContentWidth := AValue;
  InvalidateScrollMetrics;
end;

procedure TNXScrollableControl.SyncScrollBarValue(AScrollBar: TNXScrollBar;
  AValue: Integer);
var
  lWasUpdating: Boolean;
begin
  if not Assigned(AScrollBar) then
    Exit;

  lWasUpdating := False;
  BeginScrollBarUpdate(lWasUpdating);
  try
    AScrollBar.Value := AValue;
  finally
    EndScrollBarUpdate(lWasUpdating);
  end;
end;

procedure TNXScrollableControl.SetScrollX(AValue: Integer);
var
  lValue: Integer;
begin
  lValue := EnsureRange(AValue, 0, GetMaxScrollX);
  if FScrollX <> lValue then
    FScrollX := lValue;

  SyncScrollBarValue(FHorizontalScrollBar, FScrollX);
end;

procedure TNXScrollableControl.SetScrollY(AValue: Integer);
var
  lValue: Integer;
begin
  lValue := EnsureRange(AValue, 0, GetMaxScrollY);
  if FScrollY <> lValue then
    FScrollY := lValue;

  SyncScrollBarValue(FVerticalScrollBar, FScrollY);
end;

function TNXScrollableControl.GetViewportRect: TNXRect;
begin
  Result := ContentRect;

  if Assigned(FVerticalScrollBar) and FVerticalScrollBar.Visible then
    Result.w := Max(0, Result.w - FVerticalScrollBar.Width - 2);

  if Assigned(FHorizontalScrollBar) and FHorizontalScrollBar.Visible then
    Result.h := Max(0, Result.h - FHorizontalScrollBar.Height - 2);
end;

function TNXScrollableControl.GetScrollableViewportRect: TNXRect;
begin
  Result := ViewportRect;
end;

procedure TNXScrollableControl.DoMouseWheel(X, Y, ADeltaX, ADeltaY: Integer);
var
  lStep: Integer;
begin
  inherited DoMouseWheel(X, Y, ADeltaX, ADeltaY);
  UpdateLayoutIfNeeded;

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

function TNXScrollableControl.GetAbsScrollableViewportRect: TNXRect;
begin
  Result := ScrollableViewportRect;
  Result.x := AbsLeft + Result.x;
  Result.y := AbsTop + Result.y;
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

procedure TNXScrollableControl.InvalidateContentSize;
begin
  FContentSizeDirty := True;
  InvalidateScrollMetrics;
end;

procedure TNXScrollableControl.InvalidateScrollMetrics;
begin
  FScrollMetricsDirty := True;
end;

procedure TNXScrollableControl.MeasureContent;
begin
end;

procedure TNXScrollableControl.UpdateScrollMetrics;
var
  lContentRect: TNXRect;
  lHorizontalVisible: Boolean;
  lWasUpdating: Boolean;
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

  lViewportWidth := Max(0, lViewportWidth);
  lViewportHeight := Max(0, lViewportHeight);

  lWasUpdating := False;
  BeginScrollBarUpdate(lWasUpdating);
  try
    FHorizontalScrollBar.AutoAlignBoth := lVerticalVisible;
    FVerticalScrollBar.AutoAlignBoth := lHorizontalVisible;
    FHorizontalScrollBar.Visible := lHorizontalVisible;
    FVerticalScrollBar.Visible := lVerticalVisible;

    FHorizontalScrollBar.Min := 0;
    FHorizontalScrollBar.Max := Max(0, ContentWidth - lViewportWidth);
    FHorizontalScrollBar.PageSize := lViewportWidth;

    FVerticalScrollBar.Min := 0;
    FVerticalScrollBar.Max := Max(0, ContentHeight - lViewportHeight);
    FVerticalScrollBar.PageSize := lViewportHeight;
  finally
    EndScrollBarUpdate(lWasUpdating);
  end;

  SetScrollX(FScrollX);
  SetScrollY(FScrollY);
end;

procedure TNXScrollableControl.UpdateLayoutIfNeeded;
begin
  if FContentSizeDirty then
  begin
    MeasureContent;
    FContentSizeDirty := False;
    FScrollMetricsDirty := True;
  end;

  if FScrollMetricsDirty then
  begin
    UpdateScrollMetrics;
    FScrollMetricsDirty := False;
  end;
end;

procedure TNXScrollableControl.RenderClient;
var
  lClipRect: TNXRect;
begin
  UpdateLayoutIfNeeded;

  lClipRect := AbsViewportRect;
  Canvas.PushClip(lClipRect);
  try
    RenderViewportChrome;
  finally
    Canvas.PopClip;
  end;

  lClipRect := AbsScrollableViewportRect;
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

procedure TNXScrollableControl.RenderViewportChrome;
begin
end;

end.
