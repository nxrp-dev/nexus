unit obNXListBox;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fgl,
  tpNXEvents,
  tpNXPlatform,
  obNXControl,

  obNXScrollBar;

type
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
  protected
    function GetSelectedItem: TNXListBoxItem;
  public
    procedure AddItem(const AStr: string; AIndex: Integer);
    function ReturnItem(AItemIndex: Integer): TNXListBoxItem;

    property SelectedItem: TNXListBoxItem read GetSelectedItem;
  end;

  TNXListBox = class(TNXControl)
  private
    FItems: TNXListBoxItemList;
    FListCount: Integer;
    FItemsToShow: Integer;
    FScrollbar: TNXScrollBar;
  protected
    function GetSelectedItem: TNXListBoxItem;
    procedure SelectItem(AItem: TNXListBoxItem);
    procedure UpdateItemsToShow;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;
    procedure Render; override;
    procedure ctrl_FontChanged; override;
    procedure DoResize; override;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDown(X, Y: integer; Button: TNXMouseButton); override;
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

procedure TNXListBoxItemList.AddItem(const AStr: string; AIndex: Integer);
var
  lItem: TNXListBoxItem;
begin
  lItem := TNXListBoxItem.Create;
  lItem.Str := AStr;
  lItem.Index := AIndex;
  Add(lItem);
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
  Selectable := True;
  FItems := TNXListBoxItemList.Create(True);
  FScrollbar := TNXScrollBar.Create(Self);
  FScrollbar.Min := 0;
  FScrollbar.Dir := DIR_VERTICAL;
  FScrollbar.AutoAlign := True;
end;

destructor TNXListBox.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TNXListBox.ctrl_FontChanged;
begin
  inherited;
  UpdateItemsToShow;
end;

procedure TNXListBox.UpdateItemsToShow;
begin
  if (Font <> nil) and (FontLineSkip <> 0) then
  begin
    FItemsToShow := (Height div FontLineSkip);
  end
  else
    FItemsToShow := 0;
end;

procedure TNXListBox.DoResize;
begin
  inherited;
  UpdateItemsToShow;
end;

procedure TNXListBox.Render;
var
  lCount: Integer;
  lIndex: Integer;
  lItemIndex: Integer;
  lMaxScroll: Integer;
  lItem: TNXListBoxItem;
  lRect: TNXRect;
begin
  UpdateItemsToShow;

  if IsSelected then
    CurBorderColor := Skin.ForeColor
  else
    CurBorderColor := BorderColor;
  inherited;

  lCount := Items.Count;
  if lCount <> FListCount then
  begin
    FListCount := lCount;
    lMaxScroll := lCount - FItemsToShow;
    if lMaxScroll > 0 then
    begin
      FScrollbar.Max := lMaxScroll;
      FScrollbar.Visible := True;
    end
    else
    begin
      FScrollbar.Value := 0;
      FScrollbar.Max := 0;
      FScrollbar.Visible := False;
    end;
  end;

  lIndex := 0;
  lItemIndex := FScrollbar.Value;
  while (lIndex < FItemsToShow) and (lItemIndex < Items.Count) do
  begin
    lItem := Items[lItemIndex];
    if lItem.Selected then
    begin
      lRect.x := 1;
      lRect.w := Width - 2;
      lRect.y := lIndex * FontLineSkip + 1;
      lRect.h := FontLineSkip - 2;

      if IsSelected then
        RenderFilledRect(lRect, Skin.SelectedColor)
      else
        RenderFilledRect(lRect, Skin.TextBackColor);
    end;
    RenderText(lItem.Str, 3, lIndex * FontLineSkip, Align_Left);
    Inc(lItemIndex);
    Inc(lIndex);
  end;
end;

procedure TNXListBox.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lItem: TNXListBoxItem;
  lIndex: Integer;
begin
  inherited DoKeyDown(AEvent);

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
  lItemIndex: Integer;
  lItem: TNXListBoxItem;
begin
  inherited;
  if Button <> mbLeft then
    Exit;

  UpdateItemsToShow;

  if FontLineSkip = 0 then
    Exit;

  lItemIndex := FScrollbar.Value + (Y div FontLineSkip);
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
end;

end.
