unit obNXTabControl;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Math,
  fgl,
  tpNXEvents,
  tpNXLayout,
  tpNXPlatform,
  obNXControl,
  obNXPanel;

type
  TNXTabControl = class;

  TNXTabPage = class(TNXPanel)
  private
    FTabVisible: Boolean;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    property TabVisible: Boolean read FTabVisible write FTabVisible;
  end;

  TNXTabPageList = class(specialize TFPGObjectList<TNXTabPage>)
  end;

  TNXTabPageHost = class(TNXPanel)
  public
    constructor Create(const AParent: INXControlParent); overload; override;
  end;

  TNXTabStrip = class(TNXControl)
  private
    FOwnerTabControl: TNXTabControl;
  protected
    function GetTabRect(AIndex: Integer): TNXRect; virtual;
    function GetTabWidth(APage: TNXTabPage): Integer; virtual;
    function HitTestTab(AX, AY: Integer): Integer; virtual;
  public
    constructor Create(const AParent: INXControlParent;
      AOwnerTabControl: TNXTabControl); reintroduce; overload; virtual;

    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure Render; override;

    property OwnerTabControl: TNXTabControl read FOwnerTabControl;
  end;

  TNXTabControl = class(TNXControl)
  private
    FActivePageIndex: Integer;
    FOnPageChanged: TNotifyEvent;
    FPageHost: TNXTabPageHost;
    FPages: TNXTabPageList;
    FTabHeight: Integer;
    FTabStrip: TNXTabStrip;

    function GetActivePage: TNXTabPage;
    function GetPage(AIndex: Integer): TNXTabPage;
    function GetPageCount: Integer;
    procedure SetActivePageIndex(AValue: Integer);
    procedure SetTabHeight(AValue: Integer);
  protected
    procedure DoPageChanged; virtual;
    procedure UpdatePageVisibility; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    constructor Create(const AParent: INXControlParent; const ARect: TNXRect); overload; override;
    destructor Destroy; override;

    function AddPage(const ACaption: string): TNXTabPage; virtual;
    procedure ClearPages; virtual;
    procedure DeletePage(AIndex: Integer); virtual;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure SelectNextPage; virtual;
    procedure SelectPreviousPage; virtual;

    property ActivePage: TNXTabPage read GetActivePage;
    property ActivePageIndex: Integer read FActivePageIndex write SetActivePageIndex;
    property OnPageChanged: TNotifyEvent read FOnPageChanged write FOnPageChanged;
    property PageCount: Integer read GetPageCount;
    property PageHost: TNXTabPageHost read FPageHost;
    property Pages[AIndex: Integer]: TNXTabPage read GetPage;
    property TabHeight: Integer read FTabHeight write SetTabHeight;
    property TabStrip: TNXTabStrip read FTabStrip;
  end;

implementation

const
  cDefaultTabHeight = 24;
  cMinTabWidth = 56;
  cTabPaddingX = 12;
  cTabTextOffsetY = 4;

constructor TNXTabPage.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  Align := caClient;
  BorderStyle := BS_None;
  FillStyle := FS_Filled;
  FTabVisible := True;
end;

constructor TNXTabPageHost.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  Align := caClient;
  BorderStyle := BS_None;
  FillStyle := FS_None;
  Selectable := False;
end;

constructor TNXTabStrip.Create(const AParent: INXControlParent;
  AOwnerTabControl: TNXTabControl);
begin
  inherited Create(AParent);
  FOwnerTabControl := AOwnerTabControl;
  Align := caTop;
  BorderStyle := BS_None;
  FillStyle := FS_None;
  Height := cDefaultTabHeight;
  Selectable := False;
end;

procedure TNXTabStrip.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
var
  lTabIndex: Integer;
begin
  inherited DoMouseDown(AX, AY, AButton);

  if (AButton <> mbLeft) or (not Assigned(FOwnerTabControl)) then
    Exit;

  lTabIndex := HitTestTab(AX, AY);
  if lTabIndex >= 0 then
  begin
    FOwnerTabControl.ActivePageIndex := lTabIndex;
    FOwnerTabControl.IsSelected := True;
  end;
end;

function TNXTabStrip.GetTabRect(AIndex: Integer): TNXRect;
var
  lIndex: Integer;
  lLeft: Integer;
begin
  Result := MakeNXRect(0, 0, 0, Height);
  if (not Assigned(FOwnerTabControl)) or
    (AIndex < 0) or (AIndex >= FOwnerTabControl.PageCount) then
    Exit;

  lLeft := 0;
  for lIndex := 0 to AIndex - 1 do
    if FOwnerTabControl.Pages[lIndex].TabVisible then
      Inc(lLeft, GetTabWidth(FOwnerTabControl.Pages[lIndex]));

  if FOwnerTabControl.Pages[AIndex].TabVisible then
    Result := MakeNXRect(lLeft, 0,
      GetTabWidth(FOwnerTabControl.Pages[AIndex]), Height)
  else
    Result := MakeNXRect(lLeft, 0, 0, Height);
end;

function TNXTabStrip.GetTabWidth(APage: TNXTabPage): Integer;
var
  lTextWidth: Integer;
begin
  lTextWidth := 0;
  if Assigned(Canvas) and Assigned(Font) and Assigned(APage) then
    lTextWidth := Canvas.TextWidth(APage.Caption, Font);

  Result := Max(cMinTabWidth, lTextWidth + (cTabPaddingX * 2));
end;

function TNXTabStrip.HitTestTab(AX, AY: Integer): Integer;
var
  lIndex: Integer;
  lRect: TNXRect;
begin
  Result := -1;

  if (not Assigned(FOwnerTabControl)) or (AY < 0) or (AY >= Height) then
    Exit;

  for lIndex := 0 to FOwnerTabControl.PageCount - 1 do
  begin
    if not FOwnerTabControl.Pages[lIndex].TabVisible then
      Continue;

    lRect := GetTabRect(lIndex);
    if (AX >= lRect.x) and (AX < lRect.x + lRect.w) then
    begin
      Result := lIndex;
      Exit;
    end;
  end;
end;

procedure TNXTabStrip.Render;
var
  lIndex: Integer;
  lRect: TNXRect;
  lTextY: Integer;
begin
  inherited Render;

  if (not Assigned(Canvas)) or (not Assigned(FOwnerTabControl)) then
    Exit;

  lTextY := (Height - FontHeight) div 2;
  if lTextY < 0 then
    lTextY := cTabTextOffsetY;

  for lIndex := 0 to FOwnerTabControl.PageCount - 1 do
  begin
    if not FOwnerTabControl.Pages[lIndex].TabVisible then
      Continue;

    lRect := GetTabRect(lIndex);

    if lIndex = FOwnerTabControl.ActivePageIndex then
      RenderFilledRect(lRect, Skin.SelectedColor)
    else
      RenderFilledRect(lRect, BackColor);

    RenderRect(lRect, BorderColor);
    RenderText(FOwnerTabControl.Pages[lIndex].Caption,
      lRect.x + (lRect.w div 2), lTextY, Align_Center);
  end;
end;

constructor TNXTabControl.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FPages := TNXTabPageList.Create(False);
  FActivePageIndex := -1;
  FTabHeight := cDefaultTabHeight;
  BorderStyle := BS_Single;
  Selectable := True;
  SkinClass := 'TabControl';

  FTabStrip := TNXTabStrip.Create(Self, Self);
  FTabStrip.Height := FTabHeight;
  FPageHost := TNXTabPageHost.Create(Self);
end;

constructor TNXTabControl.Create(const AParent: INXControlParent;
  const ARect: TNXRect);
begin
  Create(AParent);
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

destructor TNXTabControl.Destroy;
begin
  FTabStrip := nil;
  FPageHost := nil;
  FreeAndNil(FPages);
  inherited Destroy;
end;

function TNXTabControl.AddPage(const ACaption: string): TNXTabPage;
begin
  Result := TNXTabPage.Create(FPageHost);
  Result.Caption := ACaption;
  FPages.Add(Result);

  if FActivePageIndex < 0 then
    FActivePageIndex := 0;

  UpdatePageVisibility;
  LayoutChildren;
end;

procedure TNXTabControl.ClearPages;
begin
  while PageCount > 0 do
    DeletePage(PageCount - 1);
end;

procedure TNXTabControl.DeletePage(AIndex: Integer);
var
  lPage: TNXTabPage;
begin
  if (AIndex < 0) or (AIndex >= PageCount) then
    Exit;

  lPage := FPages[AIndex];
  FPages.Delete(AIndex);

  if AIndex < FActivePageIndex then
    Dec(FActivePageIndex)
  else if FActivePageIndex >= PageCount then
    FActivePageIndex := PageCount - 1;
  if PageCount = 0 then
    FActivePageIndex := -1;

  FPageHost.FreeChild(lPage);
  UpdatePageVisibility;
  LayoutChildren;
  DoPageChanged;
end;

procedure TNXTabControl.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  case AEvent.Key of
    nkLeft:
      SelectPreviousPage;
    nkRight:
      SelectNextPage;
  end;
end;

procedure TNXTabControl.DoPageChanged;
begin
  if Assigned(FOnPageChanged) then
    FOnPageChanged(Self);
end;

function TNXTabControl.GetActivePage: TNXTabPage;
begin
  Result := nil;
  if (FActivePageIndex >= 0) and (FActivePageIndex < PageCount) then
    Result := Pages[FActivePageIndex];
end;

function TNXTabControl.GetPage(AIndex: Integer): TNXTabPage;
begin
  if (AIndex < 0) or (AIndex >= PageCount) then
    raise Exception.Create('Tab page index out of range');

  Result := FPages[AIndex];
end;

function TNXTabControl.GetPageCount: Integer;
begin
  Result := FPages.Count;
end;

procedure TNXTabControl.SelectNextPage;
var
  lIndex: Integer;
  lStep: Integer;
begin
  if PageCount = 0 then
    Exit;

  lIndex := FActivePageIndex;
  for lStep := 1 to PageCount do
  begin
    Inc(lIndex);
    if lIndex >= PageCount then
      lIndex := 0;
    if Pages[lIndex].TabVisible then
    begin
      ActivePageIndex := lIndex;
      Exit;
    end;
  end;
end;

procedure TNXTabControl.SelectPreviousPage;
var
  lIndex: Integer;
  lStep: Integer;
begin
  if PageCount = 0 then
    Exit;

  lIndex := FActivePageIndex;
  for lStep := 1 to PageCount do
  begin
    Dec(lIndex);
    if lIndex < 0 then
      lIndex := PageCount - 1;
    if Pages[lIndex].TabVisible then
    begin
      ActivePageIndex := lIndex;
      Exit;
    end;
  end;
end;

procedure TNXTabControl.SetActivePageIndex(AValue: Integer);
begin
  if AValue < -1 then
    AValue := -1;
  if AValue >= PageCount then
    AValue := PageCount - 1;

  if FActivePageIndex = AValue then
    Exit;

  FActivePageIndex := AValue;
  UpdatePageVisibility;
  LayoutChildren;
  DoPageChanged;
end;

procedure TNXTabControl.SetTabHeight(AValue: Integer);
begin
  FTabHeight := Max(0, AValue);
  if Assigned(FTabStrip) then
    FTabStrip.Height := FTabHeight;
  LayoutChildren;
end;

procedure TNXTabControl.UpdatePageVisibility;
var
  lIndex: Integer;
begin
  for lIndex := 0 to PageCount - 1 do
    Pages[lIndex].Visible := lIndex = FActivePageIndex;
end;

end.
