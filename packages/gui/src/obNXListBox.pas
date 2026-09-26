unit obNXListBox;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Math,
  fgl,
  tpNXEvents,
  tpNXPlatform,
  obNXControl,
  obNXScrollableControl;

type
  TNXListBox = class;

  TNXListBoxItem = class
  private
    FIndexNo: Integer;
    FCaption: string;
    FSelected: Boolean;
  public
    constructor Create;

    property Str: string read FCaption write FCaption;
    property Index: Integer read FIndexNo write FIndexNo;
    property Selected: Boolean read FSelected write FSelected;
  end;

  TNXListBoxItemListBase = specialize TFPGObjectList<TNXListBoxItem>;

  TNXListBoxItemList = class(TNXListBoxItemListBase)
  private
    FOwner: TNXListBox;
    procedure NotifyOwnerContentChanged;
  protected
    function GetSelectedItem: TNXListBoxItem;
  public
    function Add(const AItem: TNXListBoxItem): Integer;
    procedure AddItem(const AStr: string; AIndex: Integer);
    procedure Clear;
    procedure Delete(AIndex: Integer);
    function ReturnItem(AItemIndex: Integer): TNXListBoxItem;

    property SelectedItem: TNXListBoxItem read GetSelectedItem;
  end;

  TNXListBox = class(TNXScrollableControl)
  private
    FItems: TNXListBoxItemList;
  protected
    procedure EnsureItemVisible(AItem: TNXListBoxItem); virtual;
    function GetItemHeight: Integer; virtual;
    function GetSelectedItem: TNXListBoxItem;
    procedure MeasureContent; override;
    procedure RenderViewport; override;
    procedure SelectItem(AItem: TNXListBoxItem);
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDown(X, Y: integer; Button: TNXMouseButton); override;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;
    procedure Render; override;
    procedure ctrl_FontChanged; override;
    procedure ctrl_NewSelection(Selection: TNXListBoxItem); virtual;
    procedure NewSelection(Selection: TNXListBoxItem); virtual;

    property Items: TNXListBoxItemList read FItems;
    property SelectedItem: TNXListBoxItem read GetSelectedItem;
  end;

implementation

constructor TNXListBoxItem.Create;
begin
  Index := 0;
end;

function TNXListBoxItemList.GetSelectedItem: TNXListBoxItem;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to Count - 1 do
  begin
    if Items[lIndex].Selected then
    begin
      Result := Items[lIndex];
      Exit;
    end;
  end;
end;

procedure TNXListBoxItemList.NotifyOwnerContentChanged;
begin
  if Assigned(FOwner) then
    FOwner.InvalidateContentSize;
end;

function TNXListBoxItemList.Add(const AItem: TNXListBoxItem): Integer;
begin
  Result := inherited Add(AItem);
  NotifyOwnerContentChanged;
end;

procedure TNXListBoxItemList.AddItem(const AStr: string; AIndex: Integer);
var
  lItem: TNXListBoxItem;
begin
  lItem := TNXListBoxItem.Create;
  lItem.Str := AStr;
  lItem.Index := AIndex;
  Add(lItem);
end;

procedure TNXListBoxItemList.Clear;
begin
  inherited Clear;
  NotifyOwnerContentChanged;
end;

procedure TNXListBoxItemList.Delete(AIndex: Integer);
begin
  inherited Delete(AIndex);
  NotifyOwnerContentChanged;
end;

function TNXListBoxItemList.ReturnItem(AItemIndex: Integer): TNXListBoxItem;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to Count - 1 do
  begin
    if Items[lIndex].Index = AItemIndex then
    begin
      Result := Items[lIndex];
      Exit;
    end;
  end;
end;

constructor TNXListBox.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  BorderStyle := BS_Single;
  CanFocus := True;
  FItems := TNXListBoxItemList.Create(True);
  FItems.FOwner := Self;
end;

destructor TNXListBox.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TNXListBox.ctrl_FontChanged;
begin
  inherited;
  InvalidateContentSize;
end;

function TNXListBox.GetItemHeight: Integer;
begin
  if FontLineSkip > 0 then
    Result := FontLineSkip
  else
    Result := Max(1, GUI_TitleBarHeight);
end;

procedure TNXListBox.EnsureItemVisible(AItem: TNXListBoxItem);
var
  lIndex: Integer;
  lItemBottom: Integer;
  lItemHeight: Integer;
  lItemTop: Integer;
begin
  if not Assigned(AItem) then
    Exit;

  UpdateLayoutIfNeeded;
  lIndex := Items.IndexOf(AItem);
  if lIndex < 0 then
    Exit;

  lItemHeight := GetItemHeight;
  lItemTop := lIndex * lItemHeight;
  lItemBottom := lItemTop + lItemHeight;

  if lItemTop < ScrollY then
    ScrollY := lItemTop
  else if lItemBottom > ScrollY + ViewportHeight then
    ScrollY := lItemBottom - ViewportHeight;
end;

procedure TNXListBox.Render;
begin
  if IsFocused then
    CurBorderColor := Skin.ForeColor
  else
    CurBorderColor := BorderColor;
  inherited;
end;

procedure TNXListBox.MeasureContent;
begin
  ContentWidth := 0;
  ContentHeight := Items.Count * GetItemHeight;
end;

procedure TNXListBox.RenderViewport;
var
  lDrawIndex: Integer;
  lFirstItemIndex: Integer;
  lItem: TNXListBoxItem;
  lItemHeight: Integer;
  lItemIndex: Integer;
  lRect: TNXRect;
  lViewportRect: TNXRect;
begin
  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Exit;

  lViewportRect := ScrollableViewportRect;
  lFirstItemIndex := Max(0, ScrollY div lItemHeight);
  lDrawIndex := 0;
  lItemIndex := lFirstItemIndex;

  while (lItemIndex < Items.Count) and
    (lDrawIndex * lItemHeight - (ScrollY mod lItemHeight) < lViewportRect.h) do
  begin
    lItem := Items[lItemIndex];
    lRect.x := lViewportRect.x;
    lRect.w := lViewportRect.w;
    lRect.y := lViewportRect.y + (lDrawIndex * lItemHeight) -
      (ScrollY mod lItemHeight);
    lRect.h := lItemHeight;

    if lItem.Selected then
    begin
      if IsFocused then
        RenderFilledRect(lRect, Skin.SelectedColor)
      else
        RenderFilledRect(lRect, Skin.TextBackColor);
    end;

    RenderText(lItem.Str, lRect.x + 2, lRect.y, Align_Left);
    Inc(lItemIndex);
    Inc(lDrawIndex);
  end;
end;

procedure TNXListBox.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lItem: TNXListBoxItem;
  lIndex: Integer;
begin
  inherited DoKeyDown(AEvent);
  UpdateLayoutIfNeeded;

  lItem := Items.SelectedItem;
  lIndex := Items.IndexOf(lItem);
  case AEvent.Key of
    nkUp:
    begin
      if lIndex > 0 then
      begin
        lItem := Items[lIndex - 1];
        SelectItem(lItem);
        ctrl_NewSelection(lItem);
      end;
    end;
    nkDown:
    begin
      if (lIndex >= 0) and (lIndex < Items.Count - 1) then
      begin
        lItem := Items[lIndex + 1];
        SelectItem(lItem);
        ctrl_NewSelection(lItem);
      end;
    end;
  end;
end;

procedure TNXListBox.DoMouseDown(X, Y: integer; Button: TNXMouseButton);
var
  lContentY: Integer;
  lItemIndex: Integer;
  lItemHeight: Integer;
  lItem: TNXListBoxItem;
  lViewportRect: TNXRect;
begin
  inherited;
  if Button <> mbLeft then
    Exit;

  UpdateLayoutIfNeeded;
  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Exit;

  lViewportRect := ScrollableViewportRect;
  if (X < lViewportRect.x) or (X >= lViewportRect.x + lViewportRect.w) or
    (Y < lViewportRect.y) or (Y >= lViewportRect.y + lViewportRect.h) then
    Exit;

  lContentY := Y - lViewportRect.y + ScrollY;
  lItemIndex := lContentY div lItemHeight;
  if (lItemIndex >= 0) and (lItemIndex < Items.Count) then
  begin
    lItem := Items[lItemIndex];
    SelectItem(lItem);
    ctrl_NewSelection(lItem);
  end;
end;

procedure TNXListBox.ctrl_NewSelection(Selection: TNXListBoxItem);
begin
  NewSelection(Selection);
end;

procedure TNXListBox.NewSelection(Selection: TNXListBoxItem);
begin

end;

function TNXListBox.GetSelectedItem: TNXListBoxItem;
begin
  Result := Items.SelectedItem;
end;

procedure TNXListBox.SelectItem(AItem: TNXListBoxItem);
var
  lIndex: Integer;
begin
  for lIndex := 0 to Items.Count - 1 do
    Items[lIndex].Selected := Items[lIndex] = AItem;
  EnsureItemVisible(AItem);
end;

end.
