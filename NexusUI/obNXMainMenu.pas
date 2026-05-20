unit obNXMainMenu;

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
  obNXPopupMenu;

type
  TNXMainMenu = class;
  TNXMainMenuItem = class;

  TNXMainMenuItemEvent = procedure(Sender: TObject; AItem: TNXMainMenuItem) of object;

  TNXMainMenuItem = class
  private
    FMainMenu: TNXMainMenu;
    FCaption: string;
    FEnabled: Boolean;
    FTag: PtrInt;
    FDropDown: TNXPopupMenu;
    FOnClick: TNotifyEvent;

    procedure SetCaption(const AValue: string);
    procedure SetEnabled(AValue: Boolean);
    procedure Changed;
    function GetDropDown: TNXPopupMenu;
    procedure FreeDropDown;
  public
    constructor Create(AMainMenu: TNXMainMenu);
    destructor Destroy; override;

    function AddItem(const ACaption: string; AOnClick: TNotifyEvent = nil;
      const AShortcutText: string = ''): TNXMenuItem;
    function AddSeparator: TNXMenuItem;
    procedure Clear;

    property Caption: string read FCaption write SetCaption;
    property DropDown: TNXPopupMenu read GetDropDown;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Tag: PtrInt read FTag write FTag;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  TNXMainMenuItemList = specialize TFPGObjectList<TNXMainMenuItem>;

  TNXMainMenu = class(TNXControl)
  private
    FItems: TNXMainMenuItemList;
    FHotIndex: Integer;
    FActiveIndex: Integer;
    FOnMenuClick: TNXMainMenuItemEvent;

    function GetCount: Integer;
    function GetItem(AIndex: Integer): TNXMainMenuItem;
    function GetItemRect(AIndex: Integer): TNXRect;
    function ItemAt(AX, AY: Integer): Integer;
    function IsSelectable(AIndex: Integer): Boolean;
    function FirstSelectableIndex: Integer;
    function LastSelectableIndex: Integer;
    function HasOpenDropDown: Boolean;
    procedure SetActiveIndex(AValue: Integer);
    procedure SetHotIndex(AValue: Integer);
    procedure MoveActive(ADelta: Integer);
    procedure ExecuteIndex(AIndex: Integer);
    procedure OpenDropDown(AIndex: Integer);
    procedure CloseDropDown;
  protected
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoLoseFocus; override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure RenderClient; override;
    procedure ItemChanged(AItem: TNXMainMenuItem); virtual;
    procedure ResizeToContent; virtual;
  public
    constructor Create(const AParent: INXControlParent); override;
    destructor Destroy; override;

    function AddMenu(const ACaption: string; AOnClick: TNotifyEvent = nil): TNXMainMenuItem;
    procedure Clear;

    property ActiveIndex: Integer read FActiveIndex write SetActiveIndex;
    property Count: Integer read GetCount;
    property HotIndex: Integer read FHotIndex write SetHotIndex;
    property Items[AIndex: Integer]: TNXMainMenuItem read GetItem;
    property OnMenuClick: TNXMainMenuItemEvent read FOnMenuClick write FOnMenuClick;
  end;

implementation

uses
  obNXApplication;

const
  cMenuHeight = 24;
  cMenuPaddingX = 10;
  cMenuPaddingY = 4;
  cMenuMinItemWidth = 32;

{ TNXMainMenuItem }

constructor TNXMainMenuItem.Create(AMainMenu: TNXMainMenu);
begin
  inherited Create;
  FMainMenu := AMainMenu;
  FCaption := '';
  FEnabled := True;
  FTag := 0;
  FDropDown := nil;
end;

destructor TNXMainMenuItem.Destroy;
begin
  FreeDropDown;
  inherited Destroy;
end;

procedure TNXMainMenuItem.Changed;
begin
  if Assigned(FMainMenu) then
    FMainMenu.ItemChanged(Self);
end;

procedure TNXMainMenuItem.SetCaption(const AValue: string);
begin
  if FCaption = AValue then
    Exit;

  FCaption := AValue;
  Changed;
end;

procedure TNXMainMenuItem.SetEnabled(AValue: Boolean);
begin
  if FEnabled = AValue then
    Exit;

  FEnabled := AValue;
  Changed;
end;

function TNXMainMenuItem.GetDropDown: TNXPopupMenu;
begin
  if not Assigned(FDropDown) then
  begin
    if not Assigned(FMainMenu) or not Assigned(FMainMenu.Parent) then
      raise Exception.Create('Cannot create menu drop-down before TNXMainMenu has a parent');

    FDropDown := TNXPopupMenu.Create(FMainMenu.Parent, FMainMenu);
    FDropDown.Visible := False;
  end;

  Result := FDropDown;
end;

procedure TNXMainMenuItem.FreeDropDown;
begin
  if not Assigned(FDropDown) then
    Exit;

  if Assigned(Application) and Assigned(Application.Popups) then
    Application.Popups.HidePopup(FDropDown)
  else
    FDropDown.Close;

  if Assigned(FDropDown.Parent) then
    FDropDown.Parent.FreeChild(FDropDown)
  else
    FreeAndNil(FDropDown);

  FDropDown := nil;
end;

function TNXMainMenuItem.AddItem(const ACaption: string; AOnClick: TNotifyEvent;
  const AShortcutText: string): TNXMenuItem;
begin
  Result := DropDown.AddItem(ACaption, AOnClick, AShortcutText);
end;

function TNXMainMenuItem.AddSeparator: TNXMenuItem;
begin
  Result := DropDown.AddSeparator;
end;

procedure TNXMainMenuItem.Clear;
begin
  DropDown.Clear;
end;

{ TNXMainMenu }

constructor TNXMainMenu.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  FItems := TNXMainMenuItemList.Create(True);
  FHotIndex := -1;
  FActiveIndex := -1;

  Align := caTop;
  Height := cMenuHeight;
  BorderStyle := BS_None;
  FillStyle := FS_Filled;
  CanFocus := True;
  ReceiveAllEvents := False;
  BackColor := Skin.BackColor;
  ForeColor := Skin.ForeColor;
  ActiveColor := Skin.ActiveColor;
end;

destructor TNXMainMenu.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

function TNXMainMenu.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TNXMainMenu.GetItem(AIndex: Integer): TNXMainMenuItem;
begin
  Result := FItems[AIndex];
end;

function TNXMainMenu.GetItemRect(AIndex: Integer): TNXRect;
var
  lIndex: Integer;
  lLeft: Integer;
  lTextWidth: Integer;
begin
  lLeft := 0;

  for lIndex := 0 to AIndex - 1 do
    Inc(lLeft, GetItemRect(lIndex).w);

  lTextWidth := 0;
  if Assigned(Canvas) and Assigned(Font) and (AIndex >= 0) and (AIndex < FItems.Count) then
    lTextWidth := Canvas.TextWidth(FItems[AIndex].Caption, Font);

  Result := MakeNXRect(lLeft, 0, Max(cMenuMinItemWidth,
    lTextWidth + (cMenuPaddingX * 2)), Height);
end;

function TNXMainMenu.ItemAt(AX, AY: Integer): Integer;
var
  lIndex: Integer;
  lRect: TNXRect;
begin
  Result := -1;

  if (AY < 0) or (AY >= Height) then
    Exit;

  for lIndex := 0 to FItems.Count - 1 do
  begin
    lRect := GetItemRect(lIndex);

    if (AX >= lRect.x) and (AX < lRect.x + lRect.w) then
    begin
      Result := lIndex;
      Exit;
    end;
  end;
end;

function TNXMainMenu.IsSelectable(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < FItems.Count) and FItems[AIndex].Enabled;
end;

function TNXMainMenu.FirstSelectableIndex: Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  for lIndex := 0 to FItems.Count - 1 do
    if IsSelectable(lIndex) then
    begin
      Result := lIndex;
      Exit;
    end;
end;

function TNXMainMenu.LastSelectableIndex: Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  for lIndex := FItems.Count - 1 downto 0 do
    if IsSelectable(lIndex) then
    begin
      Result := lIndex;
      Exit;
    end;
end;

function TNXMainMenu.HasOpenDropDown: Boolean;
begin
  Result := (FActiveIndex >= 0) and (FActiveIndex < FItems.Count) and
    Assigned(FItems[FActiveIndex].FDropDown) and FItems[FActiveIndex].FDropDown.Visible;
end;

procedure TNXMainMenu.SetActiveIndex(AValue: Integer);
begin
  if not IsSelectable(AValue) then
    AValue := -1;

  if FActiveIndex = AValue then
    Exit;

  FActiveIndex := AValue;
  FHotIndex := AValue;
end;

procedure TNXMainMenu.SetHotIndex(AValue: Integer);
begin
  if not IsSelectable(AValue) then
    AValue := -1;

  FHotIndex := AValue;
end;

procedure TNXMainMenu.MoveActive(ADelta: Integer);
var
  lIndex: Integer;
  lStart: Integer;
begin
  if FItems.Count = 0 then
  begin
    FActiveIndex := -1;
    FHotIndex := -1;
    Exit;
  end;

  if FActiveIndex < 0 then
  begin
    if ADelta >= 0 then
      SetActiveIndex(FirstSelectableIndex)
    else
      SetActiveIndex(LastSelectableIndex);
    Exit;
  end;

  lStart := FActiveIndex;
  lIndex := FActiveIndex;

  repeat
    Inc(lIndex, ADelta);

    if lIndex < 0 then
      lIndex := FItems.Count - 1
    else if lIndex >= FItems.Count then
      lIndex := 0;

    if IsSelectable(lIndex) then
    begin
      SetActiveIndex(lIndex);
      Exit;
    end;
  until lIndex = lStart;
end;

procedure TNXMainMenu.ExecuteIndex(AIndex: Integer);
var
  lItem: TNXMainMenuItem;
begin
  if not IsSelectable(AIndex) then
    Exit;

  lItem := FItems[AIndex];

  if Assigned(lItem.OnClick) then
    lItem.OnClick(lItem);

  if Assigned(FOnMenuClick) then
    FOnMenuClick(Self, lItem);
end;

procedure TNXMainMenu.OpenDropDown(AIndex: Integer);
var
  lItem: TNXMainMenuItem;
  lRect: TNXRect;
begin
  if not IsSelectable(AIndex) then
    Exit;

  SetActiveIndex(AIndex);
  lItem := FItems[AIndex];
  if not Assigned(lItem.FDropDown) or (lItem.FDropDown.Count = 0) then
    Exit;

  lRect := GetItemRect(AIndex);

  lItem.DropDown.ShowAt(AbsLeft + lRect.x, AbsTop + Height);
end;

procedure TNXMainMenu.CloseDropDown;
begin
  if not HasOpenDropDown then
    Exit;

  if Assigned(Application) and Assigned(Application.Popups) then
    Application.Popups.HidePopup(FItems[FActiveIndex].FDropDown)
  else
    FItems[FActiveIndex].FDropDown.Close;
end;

procedure TNXMainMenu.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  case AEvent.Key of
    nkEscape:
    begin
      CloseDropDown;
      FActiveIndex := -1;
      FHotIndex := -1;
    end;
    nkLeft:
    begin
      MoveActive(-1);
      if HasOpenDropDown then
        OpenDropDown(FActiveIndex);
    end;
    nkRight:
    begin
      MoveActive(1);
      if HasOpenDropDown then
        OpenDropDown(FActiveIndex);
    end;
    nkDown,
    nkEnter:
    begin
      if FActiveIndex < 0 then
        SetActiveIndex(FirstSelectableIndex);

      if FActiveIndex >= 0 then
        OpenDropDown(FActiveIndex);
    end;
  end;
end;

procedure TNXMainMenu.DoLoseFocus;
begin
  inherited DoLoseFocus;
  FHotIndex := -1;
end;

procedure TNXMainMenu.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  lIndex: Integer;
begin
  inherited DoMouseDown(X, Y, Button);

  if Button <> mbLeft then
    Exit;

  lIndex := ItemAt(X, Y);
  if not IsSelectable(lIndex) then
    Exit;

  if Assigned(FItems[lIndex].FDropDown) and (FItems[lIndex].FDropDown.Count > 0) then
    OpenDropDown(lIndex)
  else
    ExecuteIndex(lIndex);
end;

procedure TNXMainMenu.DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons);
var
  lIndex: Integer;
begin
  inherited DoMouseMotion(X, Y, ButtonState);

  lIndex := ItemAt(X, Y);
  SetHotIndex(lIndex);

  if HasOpenDropDown and IsSelectable(lIndex) and (lIndex <> FActiveIndex) then
    OpenDropDown(lIndex);
end;

procedure TNXMainMenu.RenderClient;
var
  lIndex: Integer;
  lItem: TNXMainMenuItem;
  lRect: TNXRect;
  lTextY: Integer;
begin
  inherited RenderClient;

  RenderFilledRect(MakeNXRect(0, 0, Width, Height), BackColor);

  for lIndex := 0 to FItems.Count - 1 do
  begin
    lItem := FItems[lIndex];
    lRect := GetItemRect(lIndex);

    if (lIndex = FActiveIndex) or (lIndex = FHotIndex) then
      RenderFilledRect(lRect, Skin.SelectedColor);

    if lItem.Enabled then
      ForeColor := Skin.ForeColor
    else
      ForeColor := Skin.BorderColor;

    lTextY := cMenuPaddingY + ((Height - (cMenuPaddingY * 2) - FontHeight) div 2);
    RenderText(lItem.Caption, lRect.x + cMenuPaddingX, lTextY, Align_Left);
  end;

  ForeColor := Skin.ForeColor;
  RenderLine(0, Height - 1, Width, Height - 1, Skin.BorderColor);
end;

procedure TNXMainMenu.ItemChanged(AItem: TNXMainMenuItem);
begin
  ResizeToContent;
end;

procedure TNXMainMenu.ResizeToContent;
begin
  Height := Max(cMenuHeight, FontHeight + (cMenuPaddingY * 2));
end;

function TNXMainMenu.AddMenu(const ACaption: string;
  AOnClick: TNotifyEvent): TNXMainMenuItem;
begin
  Result := TNXMainMenuItem.Create(Self);
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  FItems.Add(Result);
  ResizeToContent;
end;

procedure TNXMainMenu.Clear;
begin
  CloseDropDown;
  FItems.Clear;
  FHotIndex := -1;
  FActiveIndex := -1;
  ResizeToContent;
end;

end.
