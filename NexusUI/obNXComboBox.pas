unit obNXComboBox;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Math,
  SysUtils,
  tpNXEvents,
  tpNXPlatform,
  obNXControl,

  obNXPopup;

type
  TNXComboBox = class(TNXControl)
  private
    FDropDown: TNXPopup;
    FDropDownItemCount: Integer;
    FDroppedDown: Boolean;
    FItems: TStringList;
    FOnChange: TNotifyEvent;
    FSelectedIndex: Integer;

    function GetDropDownHeight: Integer;
    function GetItemHeight: Integer;
    function GetSelectedText: string;
    function GetVisibleItemCount: Integer;
    procedure EnsureDropDown;
    procedure ItemsChanged(ASender: TObject);
    procedure PositionDropDown;
    procedure SetDroppedDown(AValue: Boolean);
    procedure SetDropDownItemCount(AValue: Integer);
    procedure SetSelectedIndex(AValue: Integer);
    procedure SyncDropDownItems;
    procedure SyncDropDownSelection;
  protected
    procedure DrawArrow(const ARect: TNXRect); virtual;
    procedure EnsureSelectedVisible; virtual;

    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoLoseFocus; override;
    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure SelectionChanged; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;

    procedure Render; override;

    property DropDownItemCount: Integer read FDropDownItemCount write SetDropDownItemCount;
    property DroppedDown: Boolean read FDroppedDown write SetDroppedDown;
    property Items: TStringList read FItems;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property SelectedText: string read GetSelectedText;
  end;

implementation

uses
  obNXApplication,
  obNXListBox;

type
  TNXComboBoxDropDownList = class(TNXListBox)
  private
    FComboBox: TNXComboBox;
  public
    constructor Create(const AParent: INXControlParent; AComboBox: TNXComboBox); reintroduce;
    procedure NewSelection(ASelection: TNXListBoxItem); override;
    procedure SyncSelection(AIndex: Integer);
  end;

  TNXComboBoxDropDown = class(TNXPopup)
  private
    FComboBox: TNXComboBox;
    FList: TNXComboBoxDropDownList;
  protected
    procedure DoClosed; override;
  public
    constructor Create(const AParent: INXControlParent; AComboBox: TNXComboBox); reintroduce;
    procedure SetListBounds; virtual;

    property List: TNXComboBoxDropDownList read FList;
  end;

const
  cDropButtonWidth = 22;
  cDefaultDropDownItemCount = 8;
  cTextPadding = 4;

constructor TNXComboBox.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  BorderStyle := BS_Single;
  FillStyle := FS_Filled;
  Height := GUI_TitleBarHeight;
  FDropDownItemCount := cDefaultDropDownItemCount;
  FDroppedDown := False;
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FSelectedIndex := -1;
  FDropDown := nil;
end;

destructor TNXComboBox.Destroy;
begin
  if Assigned(FDropDown) then
  begin
    FDropDown.Close;
    if Assigned(FDropDown.Parent) then
      FDropDown.Parent.FreeChild(FDropDown);
    FDropDown := nil;
  end;
  FreeAndNil(FItems);
  inherited Destroy;
end;

function TNXComboBox.GetItemHeight: Integer;
begin
  if FontLineSkip > 0 then
    Result := FontLineSkip
  else
    Result := Max(Height, 1);
end;

function TNXComboBox.GetVisibleItemCount: Integer;
begin
  Result := Min(FDropDownItemCount, FItems.Count);
  Result := Max(Result, 0);
end;

function TNXComboBox.GetDropDownHeight: Integer;
begin
  Result := GetVisibleItemCount * GetItemHeight;
end;

function TNXComboBox.GetSelectedText: string;
begin
  Result := '';
  if (FSelectedIndex >= 0) and (FSelectedIndex < FItems.Count) then
    Result := FItems[FSelectedIndex];
end;

procedure TNXComboBox.EnsureDropDown;
begin
  if Assigned(FDropDown) then
    Exit;

  FDropDown := TNXComboBoxDropDown.Create(Application.RootWindow, Self);
end;

procedure TNXComboBox.PositionDropDown;
var
  lDropDownHeight: Integer;
  lRootWindowHeight: Integer;
  lTop: Integer;
begin
  EnsureDropDown;

  lDropDownHeight := GetDropDownHeight;
  lTop := AbsTop + Height;

  if Assigned(Application.RootWindow) then
  begin
    lRootWindowHeight := Application.RootWindow.Height;
    if (lTop + lDropDownHeight > lRootWindowHeight) and
      (AbsTop - lDropDownHeight >= 0) then
      lTop := AbsTop - lDropDownHeight;
  end;

  FDropDown.SetAbsoluteBounds(AbsLeft, lTop, Width, lDropDownHeight);
  TNXComboBoxDropDown(FDropDown).SetListBounds;
end;

procedure TNXComboBox.SetDropDownItemCount(AValue: Integer);
begin
  FDropDownItemCount := Max(1, AValue);
  EnsureSelectedVisible;
  if FDroppedDown then
    PositionDropDown;
end;

procedure TNXComboBox.SetDroppedDown(AValue: Boolean);
begin
  if FDroppedDown = AValue then
    Exit;

  FDroppedDown := AValue;
  if FDroppedDown then
  begin
    EnsureDropDown;
    SyncDropDownItems;
    EnsureSelectedVisible;
    PositionDropDown;
    Application.Popups.ShowPopup(FDropDown);
  end
  else if Assigned(FDropDown) then
    Application.Popups.HidePopup(FDropDown);
end;

procedure TNXComboBox.SetSelectedIndex(AValue: Integer);
var
  lNewValue: Integer;
begin
  lNewValue := AValue;
  if lNewValue < -1 then
    lNewValue := -1;
  if lNewValue >= FItems.Count then
    lNewValue := FItems.Count - 1;

  if FSelectedIndex = lNewValue then
    Exit;

  FSelectedIndex := lNewValue;
  EnsureSelectedVisible;
  SelectionChanged;
end;

procedure TNXComboBox.ItemsChanged(ASender: TObject);
var
  lOldSelectedIndex: Integer;
begin
  lOldSelectedIndex := FSelectedIndex;

  if FItems.Count = 0 then
    FSelectedIndex := -1
  else if FSelectedIndex >= FItems.Count then
    FSelectedIndex := FItems.Count - 1;

  SyncDropDownItems;
  EnsureSelectedVisible;
  if FDroppedDown then
    PositionDropDown;

  if FSelectedIndex <> lOldSelectedIndex then
    SelectionChanged;
end;

procedure TNXComboBox.SyncDropDownItems;
var
  lDropDown: TNXComboBoxDropDown;
  lIndex: Integer;
begin
  if not Assigned(FDropDown) then
    Exit;

  lDropDown := TNXComboBoxDropDown(FDropDown);
  lDropDown.List.Items.Clear;
  for lIndex := 0 to FItems.Count - 1 do
    lDropDown.List.Items.AddItem(FItems[lIndex], lIndex);
  lDropDown.List.SyncSelection(FSelectedIndex);
end;

procedure TNXComboBox.SyncDropDownSelection;
begin
  if Assigned(FDropDown) then
    TNXComboBoxDropDown(FDropDown).List.SyncSelection(FSelectedIndex);
end;

procedure TNXComboBox.EnsureSelectedVisible;
begin
  SyncDropDownSelection;
end;

procedure TNXComboBox.Render;
var
  lArrowRect: TNXRect;
  lMainRect: TNXRect;
  lText: string;
  lTextY: Integer;
begin
  if IsFocused or FDroppedDown then
    CurBorderColor := ForeColor
  else
    CurBorderColor := BorderColor;

  lMainRect := MakeNXRect(0, 0, Width, Height);
  RenderFilledRect(lMainRect, BackColor);
  RenderRect(lMainRect, CurBorderColor);

  lArrowRect := MakeNXRect(Max(0, Width - cDropButtonWidth), 0,
    Min(cDropButtonWidth, Width), Height);
  RenderFilledRect(lArrowRect, ActiveColor);
  RenderRect(lArrowRect, CurBorderColor);
  DrawArrow(lArrowRect);

  lText := SelectedText;
  if lText = '' then
    lText := Caption;

  if lText <> '' then
  begin
    lTextY := (Height - FontHeight) div 2;
    Canvas.PushClip(LocalRectToAbs(MakeNXRect(cTextPadding, 1,
      Max(0, Width - cDropButtonWidth - cTextPadding - 2),
      Max(0, Height - 2))));
    try
      RenderText(lText, cTextPadding, lTextY, Align_Left);
    finally
      Canvas.PopClip;
    end;
  end;

end;

procedure TNXComboBox.DrawArrow(const ARect: TNXRect);
var
  lCenterX: Integer;
  lCenterY: Integer;
  lSize: Integer;
begin
  lCenterX := ARect.x + ARect.w div 2;
  lCenterY := ARect.y + ARect.h div 2;
  lSize := Max(3, Min(ARect.w, ARect.h) div 5);

  if FDroppedDown then
  begin
    RenderLine(lCenterX - lSize, lCenterY + lSize div 2,
      lCenterX, lCenterY - lSize div 2, ForeColor);
    RenderLine(lCenterX, lCenterY - lSize div 2,
      lCenterX + lSize, lCenterY + lSize div 2, ForeColor);
  end
  else
  begin
    RenderLine(lCenterX - lSize, lCenterY - lSize div 2,
      lCenterX, lCenterY + lSize div 2, ForeColor);
    RenderLine(lCenterX, lCenterY + lSize div 2,
      lCenterX + lSize, lCenterY - lSize div 2, ForeColor);
  end;
end;

constructor TNXComboBoxDropDownList.Create(const AParent: INXControlParent;
  AComboBox: TNXComboBox);
begin
  inherited Create(AParent);
  FComboBox := AComboBox;
  BorderStyle := BS_None;
  FillStyle := FS_None;
end;

procedure TNXComboBoxDropDownList.NewSelection(ASelection: TNXListBoxItem);
begin
  inherited NewSelection(ASelection);
  if Assigned(FComboBox) and Assigned(ASelection) then
  begin
    FComboBox.SelectedIndex := ASelection.Index;
    FComboBox.DroppedDown := False;
  end;
end;

procedure TNXComboBoxDropDownList.SyncSelection(AIndex: Integer);
begin
  SelectItem(Items.ReturnItem(AIndex));
end;

constructor TNXComboBoxDropDown.Create(const AParent: INXControlParent;
  AComboBox: TNXComboBox);
begin
  inherited Create(AParent, AComboBox);
  FComboBox := AComboBox;
  BackColor := Skin.TextBackColor;
  FList := TNXComboBoxDropDownList.Create(Self, AComboBox);
  FList.BackColor := Skin.TextBackColor;
end;

procedure TNXComboBoxDropDown.DoClosed;
begin
  inherited DoClosed;
  if Assigned(FComboBox) then
    FComboBox.FDroppedDown := False;
end;

procedure TNXComboBoxDropDown.SetListBounds;
begin
  if Assigned(FList) then
    FList.SetBounds(0, 0, Width, Height);
end;

procedure TNXComboBox.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited DoMouseDown(AX, AY, AButton);
  if AButton <> mbLeft then
    Exit;

  if AY < Height then
  begin
    DroppedDown := not DroppedDown;
    Exit;
  end;
end;

procedure TNXComboBox.DoLoseFocus;
begin
  DroppedDown := False;
  inherited DoLoseFocus;
end;

procedure TNXComboBox.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  case AEvent.Key of
    nkEscape:
      DroppedDown := False;

    nkDown:
    begin
      if not FDroppedDown then
      begin
        DroppedDown := True;
        if (FSelectedIndex < 0) and (FItems.Count > 0) then
          SelectedIndex := 0;
      end
      else if FSelectedIndex < FItems.Count - 1 then
        SelectedIndex := FSelectedIndex + 1;
    end;

    nkUp:
    begin
      if not FDroppedDown then
        DroppedDown := True
      else if FSelectedIndex > 0 then
        SelectedIndex := FSelectedIndex - 1;
    end;

    nkHome:
      if FItems.Count > 0 then
        SelectedIndex := 0;

    nkEnd:
      if FItems.Count > 0 then
        SelectedIndex := FItems.Count - 1;
  end;
end;

procedure TNXComboBox.SelectionChanged;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

end.
