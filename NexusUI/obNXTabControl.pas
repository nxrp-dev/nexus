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
  TNXTabPage = class(TNXPanel)
  private
    FTabVisible: Boolean;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    property TabVisible: Boolean read FTabVisible write FTabVisible;
  end;

  TNXTabPageList = class(specialize TFPGObjectList<TNXTabPage>)
  end;

  TNXTabControl = class(TNXControl)
  private
    FActivePageIndex: Integer;
    FOnPageChanged: TNotifyEvent;
    FPages: TNXTabPageList;
    FTabHeight: Integer;

    function GetActivePage: TNXTabPage;
    function GetPage(AIndex: Integer): TNXTabPage;
    function GetPageCount: Integer;
    procedure SetActivePageIndex(AValue: Integer);
    procedure SetTabHeight(AValue: Integer);
  protected
    function GetChildAreaTop: Integer; override;
    function GetChildAreaHeight: Integer; override;
    function GetTabRect(AIndex: Integer): TNXRect; virtual;
    function GetTabWidth(APage: TNXTabPage): Integer; virtual;
    function HitTestTab(AX, AY: Integer): Integer; virtual;
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
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure Render; override;
    procedure SelectNextPage; virtual;
    procedure SelectPreviousPage; virtual;

    property ActivePage: TNXTabPage read GetActivePage;
    property ActivePageIndex: Integer read FActivePageIndex write SetActivePageIndex;
    property OnPageChanged: TNotifyEvent read FOnPageChanged write FOnPageChanged;
    property PageCount: Integer read GetPageCount;
    property Pages[AIndex: Integer]: TNXTabPage read GetPage;
    property TabHeight: Integer read FTabHeight write SetTabHeight;
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
  FTabVisible := True;
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
  FreeAndNil(FPages);
  inherited Destroy;
end;

function TNXTabControl.AddPage(const ACaption: string): TNXTabPage;
begin
  Result := TNXTabPage.Create(Self);
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

  FreeChild(lPage);
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

procedure TNXTabControl.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  lTabIndex: Integer;
begin
  inherited DoMouseDown(X, Y, Button);

  if Button <> mbLeft then
    Exit;

  lTabIndex := HitTestTab(X, Y);
  if lTabIndex >= 0 then
    ActivePageIndex := lTabIndex;
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

function TNXTabControl.GetChildAreaTop: Integer;
begin
  Result := inherited GetChildAreaTop + TabHeight;
end;

function TNXTabControl.GetChildAreaHeight: Integer;
begin
  Result := Max(0, inherited GetChildAreaHeight - TabHeight);
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

function TNXTabControl.GetTabRect(AIndex: Integer): TNXRect;
var
  lIndex: Integer;
  lLeft: Integer;
begin
  lLeft := 0;
  for lIndex := 0 to AIndex - 1 do
    if Pages[lIndex].TabVisible then
      Inc(lLeft, GetTabWidth(Pages[lIndex]));

  if Pages[AIndex].TabVisible then
    Result := MakeNXRect(lLeft, 0, GetTabWidth(Pages[AIndex]), TabHeight)
  else
    Result := MakeNXRect(lLeft, 0, 0, TabHeight);
end;

function TNXTabControl.GetTabWidth(APage: TNXTabPage): Integer;
var
  lTextWidth: Integer;
begin
  lTextWidth := 0;
  if Assigned(Canvas) and Assigned(Font) and Assigned(APage) then
    lTextWidth := Canvas.TextWidth(APage.Caption, Font);

  Result := Max(cMinTabWidth, lTextWidth + (cTabPaddingX * 2));
end;

function TNXTabControl.HitTestTab(AX, AY: Integer): Integer;
var
  lIndex: Integer;
  lRect: TNXRect;
begin
  Result := -1;

  if (AY < 0) or (AY >= TabHeight) then
    Exit;

  for lIndex := 0 to PageCount - 1 do
  begin
    if not Pages[lIndex].TabVisible then
      Continue;

    lRect := GetTabRect(lIndex);
    if (AX >= lRect.x) and (AX < lRect.x + lRect.w) then
    begin
      Result := lIndex;
      Exit;
    end;
  end;
end;

procedure TNXTabControl.Render;
var
  lIndex: Integer;
  lRect: TNXRect;
  lTextY: Integer;
begin
  if IsSelected then
    CurBorderColor := Skin.ForeColor
  else
    CurBorderColor := BorderColor;

  inherited Render;

  if not Assigned(Canvas) then
    Exit;

  lTextY := (TabHeight - FontHeight) div 2;
  if lTextY < 0 then
    lTextY := cTabTextOffsetY;

  for lIndex := 0 to PageCount - 1 do
  begin
    if not Pages[lIndex].TabVisible then
      Continue;

    lRect := GetTabRect(lIndex);
    Inc(lRect.x, AbsLeft);
    Inc(lRect.y, AbsTop);

    if lIndex = ActivePageIndex then
      RenderFilledRect(lRect, Skin.SelectedColor)
    else
      RenderFilledRect(lRect, BackColor);

    RenderRect(lRect, BorderColor);
    RenderText(Pages[lIndex].Caption,
      lRect.x - AbsLeft + (lRect.w div 2), lTextY, Align_Center);
  end;
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
