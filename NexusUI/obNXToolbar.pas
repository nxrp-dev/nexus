unit obNXToolbar;

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
  obNXControl;

type
  TNXToolbar = class;
  TNXToolbarItem = class;

  TNXToolbarItemEvent = procedure(Sender: TObject; AItem: TNXToolbarItem) of object;

  TNXToolbarItem = class
  private
    FToolbar: TNXToolbar;
    FCaption: string;
    FEnabled: Boolean;
    FSeparator: Boolean;
    FTag: PtrInt;
    FVisible: Boolean;
    FWidth: Integer;
    FOnClick: TNotifyEvent;

    procedure Changed;
    procedure SetCaption(const AValue: string);
    procedure SetEnabled(AValue: Boolean);
    procedure SetSeparator(AValue: Boolean);
    procedure SetVisible(AValue: Boolean);
    procedure SetWidth(AValue: Integer);
  public
    constructor Create(AToolbar: TNXToolbar);

    property Caption: string read FCaption write SetCaption;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Separator: Boolean read FSeparator write SetSeparator;
    property Tag: PtrInt read FTag write FTag;
    property Visible: Boolean read FVisible write SetVisible;
    property Width: Integer read FWidth write SetWidth;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  TNXToolbarItemList = specialize TFPGObjectList<TNXToolbarItem>;

  TNXToolbar = class(TNXControl)
  private
    FItems: TNXToolbarItemList;
    FActiveIndex: Integer;
    FAutoSizeToContent: Boolean;
    FButtonHeight: Integer;
    FButtonSpacing: Integer;
    FHotIndex: Integer;
    FOnButtonClick: TNXToolbarItemEvent;
    FSeparatorWidth: Integer;

    function GetCount: Integer;
    function GetItem(AIndex: Integer): TNXToolbarItem;
    function GetItemRect(AIndex: Integer): TNXRect;
    function GetItemWidth(AIndex: Integer): Integer;
    function GetTotalWidth: Integer;
    function IsSelectable(AIndex: Integer): Boolean;
    function ItemAt(AX, AY: Integer): Integer;
    function FirstSelectableIndex: Integer;
    function LastSelectableIndex: Integer;
    procedure ExecuteIndex(AIndex: Integer);
    procedure MoveActive(ADelta: Integer);
    procedure SetActiveIndex(AValue: Integer);
    procedure SetAutoSizeToContent(AValue: Boolean);
    procedure SetButtonHeight(AValue: Integer);
    procedure SetButtonSpacing(AValue: Integer);
    procedure SetHotIndex(AValue: Integer);
    procedure SetSeparatorWidth(AValue: Integer);
  protected
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoLoseFocus; override;
    procedure DoMouseClick(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseExit; override;
    procedure DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons); override;
    procedure ItemChanged; virtual;
    procedure RenderButton(AIndex: Integer; const ARect: TNXRect); virtual;
    procedure RenderClient; override;
    procedure RenderSeparator(const ARect: TNXRect); virtual;
    procedure ResizeToContent; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;

    function AddButton(const ACaption: string; AOnClick: TNotifyEvent = nil;
      AWidth: Integer = 0): TNXToolbarItem;
    function AddSeparator: TNXToolbarItem;
    procedure Clear;

    property ActiveIndex: Integer read FActiveIndex write SetActiveIndex;
    property AutoSizeToContent: Boolean read FAutoSizeToContent write SetAutoSizeToContent;
    property ButtonHeight: Integer read FButtonHeight write SetButtonHeight;
    property ButtonSpacing: Integer read FButtonSpacing write SetButtonSpacing;
    property Count: Integer read GetCount;
    property HotIndex: Integer read FHotIndex write SetHotIndex;
    property Items[AIndex: Integer]: TNXToolbarItem read GetItem;
    property OnButtonClick: TNXToolbarItemEvent read FOnButtonClick write FOnButtonClick;
    property SeparatorWidth: Integer read FSeparatorWidth write SetSeparatorWidth;
    property TotalWidth: Integer read GetTotalWidth;
  end;

implementation

const
  cToolbarHeight = 30;
  cToolbarButtonHeight = 24;
  cToolbarButtonSpacing = 4;
  cToolbarButtonPaddingX = 10;
  cToolbarMinButtonWidth = 28;
  cToolbarSeparatorWidth = 8;

constructor TNXToolbarItem.Create(AToolbar: TNXToolbar);
begin
  inherited Create;
  FToolbar := AToolbar;
  FCaption := '';
  FEnabled := True;
  FSeparator := False;
  FTag := 0;
  FVisible := True;
  FWidth := 0;
end;

procedure TNXToolbarItem.Changed;
begin
  if Assigned(FToolbar) then
    FToolbar.ItemChanged;
end;

procedure TNXToolbarItem.SetCaption(const AValue: string);
begin
  if FCaption = AValue then
    Exit;

  FCaption := AValue;
  Changed;
end;

procedure TNXToolbarItem.SetEnabled(AValue: Boolean);
begin
  if FEnabled = AValue then
    Exit;

  FEnabled := AValue;
  Changed;
end;

procedure TNXToolbarItem.SetSeparator(AValue: Boolean);
begin
  if FSeparator = AValue then
    Exit;

  FSeparator := AValue;
  Changed;
end;

procedure TNXToolbarItem.SetVisible(AValue: Boolean);
begin
  if FVisible = AValue then
    Exit;

  FVisible := AValue;
  Changed;
end;

procedure TNXToolbarItem.SetWidth(AValue: Integer);
begin
  AValue := Max(0, AValue);

  if FWidth = AValue then
    Exit;

  FWidth := AValue;
  Changed;
end;

constructor TNXToolbar.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  FItems := TNXToolbarItemList.Create(True);
  FActiveIndex := -1;
  FAutoSizeToContent := True;
  FButtonHeight := cToolbarButtonHeight;
  FButtonSpacing := cToolbarButtonSpacing;
  FHotIndex := -1;
  FSeparatorWidth := cToolbarSeparatorWidth;

  Align := caTop;
  Height := cToolbarHeight;
  BorderStyle := BS_None;
  FillStyle := FS_Filled;
  CanFocus := True;
  ReceiveAllEvents := False;
  BackColor := Skin.BackColor;
  ForeColor := Skin.ForeColor;
  ActiveColor := Skin.ActiveColor;
  SkinClass := 'Toolbar';
end;

destructor TNXToolbar.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

function TNXToolbar.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TNXToolbar.GetItem(AIndex: Integer): TNXToolbarItem;
begin
  Result := FItems[AIndex];
end;

function TNXToolbar.GetItemRect(AIndex: Integer): TNXRect;
var
  lIndex: Integer;
  lItem: TNXToolbarItem;
  lLeft: Integer;
begin
  lLeft := FButtonSpacing;

  for lIndex := 0 to AIndex - 1 do
  begin
    lItem := FItems[lIndex];
    if not lItem.Visible then
      Continue;

    Inc(lLeft, GetItemWidth(lIndex) + FButtonSpacing);
  end;

  Result := MakeNXRect(lLeft, Max(0, (Height - FButtonHeight) div 2),
    GetItemWidth(AIndex), FButtonHeight);
end;

function TNXToolbar.GetItemWidth(AIndex: Integer): Integer;
var
  lItem: TNXToolbarItem;
  lTextWidth: Integer;
begin
  Result := 0;
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit;

  lItem := FItems[AIndex];
  if lItem.Separator then
    Result := FSeparatorWidth
  else if lItem.Width > 0 then
    Result := lItem.Width
  else
  begin
    lTextWidth := 0;
    if Assigned(Canvas) and Assigned(Font) then
      lTextWidth := Canvas.TextWidth(lItem.Caption, Font);
    Result := Max(cToolbarMinButtonWidth,
      lTextWidth + (cToolbarButtonPaddingX * 2));
  end;
end;

function TNXToolbar.GetTotalWidth: Integer;
var
  lIndex: Integer;
  lRect: TNXRect;
begin
  Result := FButtonSpacing;

  for lIndex := 0 to FItems.Count - 1 do
  begin
    if not FItems[lIndex].Visible then
      Continue;

    lRect := GetItemRect(lIndex);
    Result := lRect.x + lRect.w + FButtonSpacing;
  end;
end;

function TNXToolbar.IsSelectable(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < FItems.Count) and
    FItems[AIndex].Visible and FItems[AIndex].Enabled and
    (not FItems[AIndex].Separator);
end;

function TNXToolbar.ItemAt(AX, AY: Integer): Integer;
var
  lIndex: Integer;
  lRect: TNXRect;
begin
  Result := -1;

  for lIndex := 0 to FItems.Count - 1 do
  begin
    if not FItems[lIndex].Visible then
      Continue;

    lRect := GetItemRect(lIndex);
    if (AX >= lRect.x) and (AX < lRect.x + lRect.w) and
      (AY >= lRect.y) and (AY < lRect.y + lRect.h) then
    begin
      Result := lIndex;
      Exit;
    end;
  end;
end;

function TNXToolbar.FirstSelectableIndex: Integer;
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

function TNXToolbar.LastSelectableIndex: Integer;
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

procedure TNXToolbar.ExecuteIndex(AIndex: Integer);
var
  lItem: TNXToolbarItem;
begin
  if not IsSelectable(AIndex) then
    Exit;

  lItem := FItems[AIndex];

  if Assigned(lItem.OnClick) then
    lItem.OnClick(lItem);

  if Assigned(FOnButtonClick) then
    FOnButtonClick(Self, lItem);
end;

procedure TNXToolbar.MoveActive(ADelta: Integer);
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

procedure TNXToolbar.SetActiveIndex(AValue: Integer);
begin
  if not IsSelectable(AValue) then
    AValue := -1;

  if FActiveIndex = AValue then
    Exit;

  FActiveIndex := AValue;
  FHotIndex := AValue;
end;

procedure TNXToolbar.SetAutoSizeToContent(AValue: Boolean);
begin
  if FAutoSizeToContent = AValue then
    Exit;

  FAutoSizeToContent := AValue;
  ResizeToContent;
end;

procedure TNXToolbar.SetButtonHeight(AValue: Integer);
begin
  AValue := Max(8, AValue);

  if FButtonHeight = AValue then
    Exit;

  FButtonHeight := AValue;
  ResizeToContent;
end;

procedure TNXToolbar.SetButtonSpacing(AValue: Integer);
begin
  AValue := Max(0, AValue);

  if FButtonSpacing = AValue then
    Exit;

  FButtonSpacing := AValue;
  ResizeToContent;
end;

procedure TNXToolbar.SetHotIndex(AValue: Integer);
begin
  if not IsSelectable(AValue) then
    AValue := -1;

  FHotIndex := AValue;
end;

procedure TNXToolbar.SetSeparatorWidth(AValue: Integer);
begin
  AValue := Max(2, AValue);

  if FSeparatorWidth = AValue then
    Exit;

  FSeparatorWidth := AValue;
  ResizeToContent;
end;

procedure TNXToolbar.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  case AEvent.Key of
    nkEscape:
    begin
      FActiveIndex := -1;
      FHotIndex := -1;
    end;
    nkLeft:
      MoveActive(-1);
    nkRight:
      MoveActive(1);
    nkHome:
      SetActiveIndex(FirstSelectableIndex);
    nkEnd:
      SetActiveIndex(LastSelectableIndex);
    nkEnter:
    begin
      if FActiveIndex < 0 then
        SetActiveIndex(FirstSelectableIndex);
      ExecuteIndex(FActiveIndex);
    end;
  end;
end;

procedure TNXToolbar.DoLoseFocus;
begin
  inherited DoLoseFocus;
  FHotIndex := -1;
end;

procedure TNXToolbar.DoMouseClick(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited DoMouseClick(AX, AY, AButton);

  if AButton <> mbLeft then
    Exit;

  ExecuteIndex(ItemAt(AX, AY));
end;

procedure TNXToolbar.DoMouseExit;
begin
  inherited DoMouseExit;
  FHotIndex := -1;
end;

procedure TNXToolbar.DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons);
begin
  inherited DoMouseMotion(AX, AY, AButtonState);
  SetHotIndex(ItemAt(AX, AY));
end;

procedure TNXToolbar.ItemChanged;
begin
  ResizeToContent;
end;

procedure TNXToolbar.RenderButton(AIndex: Integer; const ARect: TNXRect);
var
  lItem: TNXToolbarItem;
  lOldForeColor: TNXColor;
  lTextY: Integer;
begin
  lItem := FItems[AIndex];
  lOldForeColor := ForeColor;

  if AIndex = FActiveIndex then
    RenderFilledRect(ARect, ActiveColor)
  else if AIndex = FHotIndex then
    RenderFilledRect(ARect, Skin.SelectedColor)
  else
    RenderFilledRect(ARect, BackColor);

  if lItem.Enabled then
    ForeColor := Skin.ForeColor
  else
    ForeColor := Skin.BorderColor;

  RenderRect(ARect, BorderColor);

  lTextY := ARect.y + ((ARect.h - FontHeight) div 2);
  RenderText(lItem.Caption, ARect.x + (ARect.w div 2), lTextY, Align_Center);
  ForeColor := lOldForeColor;
end;

procedure TNXToolbar.RenderClient;
var
  lIndex: Integer;
  lItem: TNXToolbarItem;
  lRect: TNXRect;
begin
  inherited RenderClient;

  RenderFilledRect(MakeNXRect(0, 0, Width, Height), BackColor);

  for lIndex := 0 to FItems.Count - 1 do
  begin
    lItem := FItems[lIndex];
    if not lItem.Visible then
      Continue;

    lRect := GetItemRect(lIndex);

    if lItem.Separator then
      RenderSeparator(lRect)
    else
      RenderButton(lIndex, lRect);
  end;

  RenderLine(0, Height - 1, Width, Height - 1, Skin.BorderColor);
end;

procedure TNXToolbar.RenderSeparator(const ARect: TNXRect);
var
  lX: Integer;
begin
  lX := ARect.x + (ARect.w div 2);
  RenderLine(lX, ARect.y + 3, lX, ARect.y + ARect.h - 4, Skin.BorderColor);
end;

procedure TNXToolbar.ResizeToContent;
begin
  if FAutoSizeToContent then
    Height := Max(cToolbarHeight, FButtonHeight + (FButtonSpacing * 2));
end;

function TNXToolbar.AddButton(const ACaption: string; AOnClick: TNotifyEvent;
  AWidth: Integer): TNXToolbarItem;
begin
  Result := TNXToolbarItem.Create(Self);
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  Result.Width := AWidth;
  FItems.Add(Result);
  ResizeToContent;
end;

function TNXToolbar.AddSeparator: TNXToolbarItem;
begin
  Result := TNXToolbarItem.Create(Self);
  Result.Separator := True;
  FItems.Add(Result);
  ResizeToContent;
end;

procedure TNXToolbar.Clear;
begin
  FItems.Clear;
  FActiveIndex := -1;
  FHotIndex := -1;
  ResizeToContent;
end;

end.
