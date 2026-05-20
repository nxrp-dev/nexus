unit obNXPopupMenu;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Math,
  fgl,
  tpNXEvents,
  tpNXPlatform,
  obNXControl,

  obNXPopup;

type
  TNXPopupMenu = class;
  TNXMenuItem = class;

  TNXMenuItemEvent = procedure(Sender: TObject; AItem: TNXMenuItem) of object;

  TNXMenuItem = class
  private
    FOwner: TNXPopupMenu;
    FCaption: string;
    FShortcutText: string;
    FEnabled: Boolean;
    FChecked: Boolean;
    FSeparator: Boolean;
    FTag: PtrInt;
    FOnClick: TNotifyEvent;

    procedure SetCaption(const AValue: string);
    procedure SetShortcutText(const AValue: string);
    procedure SetEnabled(AValue: Boolean);
    procedure SetChecked(AValue: Boolean);
    procedure SetSeparator(AValue: Boolean);
    procedure Changed;
  public
    constructor Create(AOwner: TNXPopupMenu);

    property Caption: string read FCaption write SetCaption;
    property ShortcutText: string read FShortcutText write SetShortcutText;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Checked: Boolean read FChecked write SetChecked;
    property Separator: Boolean read FSeparator write SetSeparator;
    property Tag: PtrInt read FTag write FTag;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  TNXMenuItemList = specialize TFPGObjectList<TNXMenuItem>;

  TNXPopupMenu = class(TNXPopup)
  private
    FItems: TNXMenuItemList;
    FSelectedIndex: Integer;
    FOnExecute: TNXMenuItemEvent;

    function GetCount: Integer;
    function GetItem(AIndex: Integer): TNXMenuItem;
    function GetRowHeight: Integer;
    function GetItemRect(AIndex: Integer): TNXRect;
    function ItemAt(AX, AY: Integer): Integer;
    function IsExecutable(AIndex: Integer): Boolean;
    function FirstExecutableIndex: Integer;
    function LastExecutableIndex: Integer;
    procedure SetSelectedIndex(AValue: Integer);
    procedure ExecuteIndex(AIndex: Integer);
    procedure MoveSelection(ADelta: Integer);
  protected
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure DoOpened; override;
    procedure RenderClient; override;
    procedure ItemChanged(AItem: TNXMenuItem); virtual;
    procedure AutoSizeMenu; virtual;
  public
    constructor Create(const AParent: INXControlParent; AOwner: TNXControl); override;
    destructor Destroy; override;

    function AddItem(
      const ACaption: string;
      AOnClick: TNotifyEvent = nil;
      const AShortcutText: string = ''
    ): TNXMenuItem;
    function AddSeparator: TNXMenuItem;
    procedure Clear;
    procedure ShowAt(AX, AY: Integer);

    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TNXMenuItem read GetItem;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property OnExecute: TNXMenuItemEvent read FOnExecute write FOnExecute;
  end;

implementation

uses
  obNXApplication;

const
  cMenuMinWidth = 140;
  cMenuPaddingX = 8;
  cMenuCheckWidth = 22;
  cMenuShortcutGap = 20;
  cMenuSeparatorHeight = 8;
  cMenuTextVPadding = 6;

constructor TNXMenuItem.Create(AOwner: TNXPopupMenu);
begin
  inherited Create;
  FOwner := AOwner;
  FCaption := '';
  FShortcutText := '';
  FEnabled := True;
  FChecked := False;
  FSeparator := False;
  FTag := 0;
end;

procedure TNXMenuItem.Changed;
begin
  if Assigned(FOwner) then
    FOwner.ItemChanged(Self);
end;

procedure TNXMenuItem.SetCaption(const AValue: string);
begin
  if FCaption = AValue then
    Exit;

  FCaption := AValue;
  Changed;
end;

procedure TNXMenuItem.SetShortcutText(const AValue: string);
begin
  if FShortcutText = AValue then
    Exit;

  FShortcutText := AValue;
  Changed;
end;

procedure TNXMenuItem.SetEnabled(AValue: Boolean);
begin
  if FEnabled = AValue then
    Exit;

  FEnabled := AValue;
  Changed;
end;

procedure TNXMenuItem.SetChecked(AValue: Boolean);
begin
  if FChecked = AValue then
    Exit;

  FChecked := AValue;
  Changed;
end;

procedure TNXMenuItem.SetSeparator(AValue: Boolean);
begin
  if FSeparator = AValue then
    Exit;

  FSeparator := AValue;
  Changed;
end;

constructor TNXPopupMenu.Create(const AParent: INXControlParent; AOwner: TNXControl);
begin
  inherited Create(AParent, AOwner);

  FItems := TNXMenuItemList.Create(True);
  FSelectedIndex := -1;

  BorderStyle := BS_Single;
  FillStyle := FS_Filled;
  BackColor := Skin.BackColor;
  ForeColor := Skin.ForeColor;
  CanFocus := True;
  ReceiveAllEvents := True;

  Width := cMenuMinWidth;
  Height := 1;
end;

destructor TNXPopupMenu.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

function TNXPopupMenu.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TNXPopupMenu.GetItem(AIndex: Integer): TNXMenuItem;
begin
  Result := FItems[AIndex];
end;

function TNXPopupMenu.GetRowHeight: Integer;
begin
  Result := Max(20, FontHeight + cMenuTextVPadding);
end;

function TNXPopupMenu.GetItemRect(AIndex: Integer): TNXRect;
var
  lIndex: Integer;
  lTop: Integer;
begin
  lTop := 0;

  for lIndex := 0 to AIndex - 1 do
  begin
    if FItems[lIndex].Separator then
      Inc(lTop, cMenuSeparatorHeight)
    else
      Inc(lTop, GetRowHeight);
  end;

  if FItems[AIndex].Separator then
    Result := MakeNXRect(0, lTop, Width, cMenuSeparatorHeight)
  else
    Result := MakeNXRect(0, lTop, Width, GetRowHeight);
end;

function TNXPopupMenu.ItemAt(AX, AY: Integer): Integer;
var
  lIndex: Integer;
  lRect: TNXRect;
begin
  Result := -1;

  for lIndex := 0 to FItems.Count - 1 do
  begin
    lRect := GetItemRect(lIndex);

    if (AX >= lRect.x) and (AX < lRect.x + lRect.w) and
      (AY >= lRect.y) and (AY < lRect.y + lRect.h) then
    begin
      Result := lIndex;
      Exit;
    end;
  end;
end;

function TNXPopupMenu.IsExecutable(AIndex: Integer): Boolean;
begin
  Result :=
    (AIndex >= 0) and
    (AIndex < FItems.Count) and
    (not FItems[AIndex].Separator) and
    FItems[AIndex].Enabled;
end;

function TNXPopupMenu.FirstExecutableIndex: Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  for lIndex := 0 to FItems.Count - 1 do
    if IsExecutable(lIndex) then
    begin
      Result := lIndex;
      Exit;
    end;
end;

function TNXPopupMenu.LastExecutableIndex: Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  for lIndex := FItems.Count - 1 downto 0 do
    if IsExecutable(lIndex) then
    begin
      Result := lIndex;
      Exit;
    end;
end;

procedure TNXPopupMenu.SetSelectedIndex(AValue: Integer);
begin
  if not IsExecutable(AValue) then
    AValue := -1;

  if FSelectedIndex = AValue then
    Exit;

  FSelectedIndex := AValue;
end;

procedure TNXPopupMenu.ExecuteIndex(AIndex: Integer);
var
  lItem: TNXMenuItem;
begin
  if not IsExecutable(AIndex) then
    Exit;

  lItem := FItems[AIndex];

  Close;

  if Assigned(lItem.OnClick) then
    lItem.OnClick(lItem);

  if Assigned(FOnExecute) then
    FOnExecute(Self, lItem);
end;

procedure TNXPopupMenu.MoveSelection(ADelta: Integer);
var
  lIndex: Integer;
  lStart: Integer;
begin
  if FItems.Count = 0 then
  begin
    FSelectedIndex := -1;
    Exit;
  end;

  if FSelectedIndex < 0 then
  begin
    if ADelta >= 0 then
      FSelectedIndex := FirstExecutableIndex
    else
      FSelectedIndex := LastExecutableIndex;
    Exit;
  end;

  lStart := FSelectedIndex;
  lIndex := FSelectedIndex;

  repeat
    Inc(lIndex, ADelta);

    if lIndex < 0 then
      lIndex := FItems.Count - 1
    else if lIndex >= FItems.Count then
      lIndex := 0;

    if IsExecutable(lIndex) then
    begin
      FSelectedIndex := lIndex;
      Exit;
    end;
  until lIndex = lStart;
end;

procedure TNXPopupMenu.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  case AEvent.Key of
    nkEscape:
      Close;
    nkUp:
      MoveSelection(-1);
    nkDown:
      MoveSelection(1);
    nkHome:
      FSelectedIndex := FirstExecutableIndex;
    nkEnd:
      FSelectedIndex := LastExecutableIndex;
    nkEnter:
      ExecuteIndex(FSelectedIndex);
  end;
end;

procedure TNXPopupMenu.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  lIndex: Integer;
begin
  inherited DoMouseDown(X, Y, Button);

  if Button <> mbLeft then
    Exit;

  lIndex := ItemAt(X, Y);

  if IsExecutable(lIndex) then
    ExecuteIndex(lIndex);
end;

procedure TNXPopupMenu.DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons);
var
  lIndex: Integer;
begin
  inherited DoMouseMotion(X, Y, ButtonState);

  lIndex := ItemAt(X, Y);

  if IsExecutable(lIndex) then
    FSelectedIndex := lIndex
  else if lIndex >= 0 then
    FSelectedIndex := -1;
end;

procedure TNXPopupMenu.DoOpened;
begin
  inherited DoOpened;

  AutoSizeMenu;

  if FSelectedIndex < 0 then
    FSelectedIndex := FirstExecutableIndex;

  Focus;
end;

procedure TNXPopupMenu.RenderClient;
var
  lIndex: Integer;
  lItem: TNXMenuItem;
  lLineY: Integer;
  lRect: TNXRect;
  lTextY: Integer;
  lShortcutWidth: Integer;
begin
  inherited RenderClient;

  for lIndex := 0 to FItems.Count - 1 do
  begin
    lItem := FItems[lIndex];
    lRect := GetItemRect(lIndex);

    if lItem.Separator then
    begin
      lLineY := lRect.y + (lRect.h div 2);
      RenderLine(
        cMenuPaddingX,
        lLineY,
        Width - cMenuPaddingX,
        lLineY,
        Skin.BorderColor
      );
      Continue;
    end;

    if lIndex = FSelectedIndex then
      RenderFilledRect(
        lRect,
        Skin.SelectedColor
      );

    if lItem.Checked then
      RenderText('x', cMenuPaddingX + 4, lRect.y + ((lRect.h - FontHeight) div 2), Align_Left);

    if lItem.Enabled then
      ForeColor := Skin.ForeColor
    else
      ForeColor := Skin.BorderColor;

    lTextY := lRect.y + ((lRect.h - FontHeight) div 2);
    RenderText(lItem.Caption, cMenuCheckWidth + cMenuPaddingX, lTextY, Align_Left);

    if lItem.ShortcutText <> '' then
    begin
      lShortcutWidth := 0;
      if Assigned(Canvas) and Assigned(Font) then
        lShortcutWidth := Canvas.TextWidth(lItem.ShortcutText, Font);

      RenderText(
        lItem.ShortcutText,
        Width - cMenuPaddingX - lShortcutWidth,
        lTextY,
        Align_Left
      );
    end;
  end;

  ForeColor := Skin.ForeColor;
end;

procedure TNXPopupMenu.ItemChanged(AItem: TNXMenuItem);
begin
  AutoSizeMenu;
end;

procedure TNXPopupMenu.AutoSizeMenu;
var
  lHeight: Integer;
  lIndex: Integer;
  lItem: TNXMenuItem;
  lTextWidth: Integer;
  lWidth: Integer;
begin
  lWidth := cMenuMinWidth;
  lHeight := 0;

  for lIndex := 0 to FItems.Count - 1 do
  begin
    lItem := FItems[lIndex];

    if lItem.Separator then
    begin
      Inc(lHeight, cMenuSeparatorHeight);
      Continue;
    end;

    Inc(lHeight, GetRowHeight);

    lTextWidth := cMenuCheckWidth + cMenuPaddingX * 2;
    if Assigned(Canvas) and Assigned(Font) then
    begin
      Inc(lTextWidth, Canvas.TextWidth(lItem.Caption, Font));

      if lItem.ShortcutText <> '' then
        Inc(lTextWidth, cMenuShortcutGap + Canvas.TextWidth(lItem.ShortcutText, Font));
    end
    else
      Inc(lTextWidth, 120);

    lWidth := Max(lWidth, lTextWidth);
  end;

  Width := lWidth;
  Height := Max(1, lHeight);
end;

function TNXPopupMenu.AddItem(const ACaption: string; AOnClick: TNotifyEvent;
  const AShortcutText: string): TNXMenuItem;
begin
  Result := TNXMenuItem.Create(Self);
  Result.Caption := ACaption;
  Result.ShortcutText := AShortcutText;
  Result.OnClick := AOnClick;

  FItems.Add(Result);
  AutoSizeMenu;
end;

function TNXPopupMenu.AddSeparator: TNXMenuItem;
begin
  Result := TNXMenuItem.Create(Self);
  Result.Separator := True;
  Result.Enabled := False;

  FItems.Add(Result);
  AutoSizeMenu;
end;

procedure TNXPopupMenu.Clear;
begin
  FItems.Clear;
  FSelectedIndex := -1;
  AutoSizeMenu;
end;

procedure TNXPopupMenu.ShowAt(AX, AY: Integer);
var
  lMaxLeft: Integer;
  lMaxTop: Integer;
  lOriginX: Integer;
  lOriginY: Integer;
begin
  AutoSizeMenu;

  if Assigned(Parent) then
  begin
    lOriginX := Parent.AbsLeft + Parent.GetChildOriginX(Self);
    lOriginY := Parent.AbsTop + Parent.GetChildOriginY(Self);
    lMaxLeft := Max(lOriginX, Parent.AbsLeft + Parent.Width - Width);
    lMaxTop := Max(lOriginY, Parent.AbsTop + Parent.Height - Height);

    AX := Max(lOriginX, Min(AX, lMaxLeft));
    AY := Max(lOriginY, Min(AY, lMaxTop));
  end;

  SetAbsolutePosition(AX, AY);

  if Assigned(Application) and Assigned(Application.RootWindow) then
    Application.Popups.ShowPopup(Self)
  else
    Open;
end;

end.
