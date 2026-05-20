unit obNXPropertyEditor;

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
  obNXEditBox,
  obNXFont,
  obNXScrollableControl;

type
  TNXPropertyKind = (
    pkString,
    pkInteger,
    pkFloat,
    pkBoolean,
    pkColor,
    pkEnum,
    pkObject,
    pkReadOnly
  );

  TNXPropertyEditorItem = class
  private
    FCategory: string;
    FName: string;
    FReadOnly: Boolean;
    FTag: PtrInt;
    FValue: string;
    FValueKind: TNXPropertyKind;
  public
    constructor Create(const AName, AValue: string;
      AValueKind: TNXPropertyKind = pkString; AReadOnly: Boolean = False);

    property Category: string read FCategory write FCategory;
    property Name: string read FName write FName;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property Tag: PtrInt read FTag write FTag;
    property Value: string read FValue write FValue;
    property ValueKind: TNXPropertyKind read FValueKind write FValueKind;
  end;

  TNXPropertyEditorItemList = class(specialize TFPGObjectList<TNXPropertyEditorItem>)
  end;

  TNXPropertyEditorItemEvent = procedure(Sender: TObject;
    AItem: TNXPropertyEditorItem) of object;
  TNXPropertyEditorGetValueEvent = procedure(Sender: TObject;
    AItem: TNXPropertyEditorItem; var AValue: string) of object;
  TNXPropertyEditorSetValueEvent = procedure(Sender: TObject;
    AItem: TNXPropertyEditorItem; const AValue: string; var AAccepted: Boolean) of object;

  TNXPropertyEditor = class(TNXScrollableControl)
  private
    FEditingIndex: Integer;
    FEditor: TNXEditBox;
    FItems: TNXPropertyEditorItemList;
    FNameColumnWidth: Integer;
    FOnItemActivate: TNXPropertyEditorItemEvent;
    FOnItemSelected: TNXPropertyEditorItemEvent;
    FOnGetValue: TNXPropertyEditorGetValueEvent;
    FOnSetValue: TNXPropertyEditorSetValueEvent;
    FRowHeight: Integer;
    FSelectedIndex: Integer;
    FShowGridLines: Boolean;

    function GetCount: Integer;
    function GetItem(AIndex: Integer): TNXPropertyEditorItem;
    procedure HandleEditorKeyDown(Sender: TObject; const AEvent: TNXKeyEventData);
    procedure SetNameColumnWidth(AValue: Integer);
    procedure SetRowHeight(AValue: Integer);
    procedure SetSelectedIndex(AValue: Integer);
  protected
    function RowAt(AX, AY: Integer): Integer; virtual;
    function RowRect(AIndex: Integer): TNXRect; virtual;
    function NameRect(AIndex: Integer): TNXRect; virtual;
    function ValueRect(AIndex: Integer): TNXRect; virtual;
    function ItemValue(AItem: TNXPropertyEditorItem): string; virtual;

    procedure DoItemActivate(AItem: TNXPropertyEditorItem); virtual;
    procedure DoItemSelected(AItem: TNXPropertyEditorItem); virtual;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDoubleClick(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DrawCellText(const AText: string; const ARect: TNXRect;
      AAlign: TTextAlign); virtual;
    procedure DrawItem(AIndex: Integer; const ARect: TNXRect); virtual;
    procedure RenderViewport; override;
    procedure UpdateContentSize; virtual;
    procedure UpdateEditorBounds; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;

    function AddProperty(const AName, AValue: string;
      AValueKind: TNXPropertyKind = pkString; AReadOnly: Boolean = False): TNXPropertyEditorItem; virtual;
    procedure BeginEdit; virtual;
    procedure CancelEdit; virtual;
    procedure Clear; virtual;
    procedure CommitEdit; virtual;
    procedure DeleteProperty(AIndex: Integer); virtual;
    procedure EndEdit(AAccept: Boolean); virtual;

    property Count: Integer read GetCount;
    property EditingIndex: Integer read FEditingIndex;
    property Items[AIndex: Integer]: TNXPropertyEditorItem read GetItem;
    property NameColumnWidth: Integer read FNameColumnWidth write SetNameColumnWidth;
    property OnGetValue: TNXPropertyEditorGetValueEvent read FOnGetValue write FOnGetValue;
    property OnItemActivate: TNXPropertyEditorItemEvent read FOnItemActivate write FOnItemActivate;
    property OnItemSelected: TNXPropertyEditorItemEvent read FOnItemSelected write FOnItemSelected;
    property OnSetValue: TNXPropertyEditorSetValueEvent read FOnSetValue write FOnSetValue;
    property RowHeight: Integer read FRowHeight write SetRowHeight;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property ShowGridLines: Boolean read FShowGridLines write FShowGridLines;
  end;

implementation

const
  cDefaultNameColumnWidth = 140;
  cDefaultRowHeight = 22;
  cCellPaddingX = 5;

constructor TNXPropertyEditorItem.Create(const AName, AValue: string;
  AValueKind: TNXPropertyKind; AReadOnly: Boolean);
begin
  inherited Create;
  FCategory := '';
  FName := AName;
  FReadOnly := AReadOnly;
  FTag := 0;
  FValue := AValue;
  FValueKind := AValueKind;
end;

constructor TNXPropertyEditor.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  BorderStyle := BS_Single;
  Selectable := True;

  FEditingIndex := -1;
  FItems := TNXPropertyEditorItemList.Create(True);
  FNameColumnWidth := cDefaultNameColumnWidth;
  FRowHeight := cDefaultRowHeight;
  FSelectedIndex := -1;
  FShowGridLines := True;

  FEditor := TNXEditBox.Create(Self);
  FEditor.Visible := False;
  FEditor.OnKeyDown := @HandleEditorKeyDown;
end;

destructor TNXPropertyEditor.Destroy;
begin
  FEditor := nil;
  FreeAndNil(FItems);
  inherited Destroy;
end;

function TNXPropertyEditor.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TNXPropertyEditor.GetItem(AIndex: Integer): TNXPropertyEditorItem;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit(nil);

  Result := FItems[AIndex];
end;

procedure TNXPropertyEditor.SetNameColumnWidth(AValue: Integer);
begin
  FNameColumnWidth := Max(40, AValue);
  UpdateEditorBounds;
end;

procedure TNXPropertyEditor.SetRowHeight(AValue: Integer);
begin
  FRowHeight := Max(12, AValue);
  UpdateContentSize;
  UpdateEditorBounds;
end;

procedure TNXPropertyEditor.SetSelectedIndex(AValue: Integer);
begin
  if FItems.Count = 0 then
    AValue := -1
  else if AValue < 0 then
    AValue := -1
  else
    AValue := EnsureRange(AValue, 0, FItems.Count - 1);

  if FSelectedIndex = AValue then
    Exit;

  EndEdit(True);
  FSelectedIndex := AValue;
  if FSelectedIndex >= 0 then
    DoItemSelected(FItems[FSelectedIndex]);
end;

function TNXPropertyEditor.AddProperty(const AName, AValue: string;
  AValueKind: TNXPropertyKind; AReadOnly: Boolean): TNXPropertyEditorItem;
begin
  Result := TNXPropertyEditorItem.Create(AName, AValue, AValueKind, AReadOnly);
  FItems.Add(Result);
  if FSelectedIndex < 0 then
    FSelectedIndex := 0;
  UpdateContentSize;
end;

procedure TNXPropertyEditor.Clear;
begin
  CancelEdit;
  FItems.Clear;
  FSelectedIndex := -1;
  UpdateContentSize;
end;

procedure TNXPropertyEditor.DeleteProperty(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit;

  if FEditingIndex = AIndex then
    CancelEdit;

  FItems.Delete(AIndex);

  if FSelectedIndex >= FItems.Count then
    FSelectedIndex := FItems.Count - 1;

  if FEditingIndex > AIndex then
    Dec(FEditingIndex);

  UpdateContentSize;
end;

function TNXPropertyEditor.ItemValue(AItem: TNXPropertyEditorItem): string;
begin
  if not Assigned(AItem) then
    Exit('');

  Result := AItem.Value;
  if Assigned(FOnGetValue) then
    FOnGetValue(Self, AItem, Result);
end;

function TNXPropertyEditor.RowAt(AX, AY: Integer): Integer;
var
  lViewportRect: TNXRect;
  lY: Integer;
begin
  Result := -1;
  lViewportRect := ViewportRect;

  if (AX < lViewportRect.x) or (AX >= lViewportRect.x + lViewportRect.w) or
    (AY < lViewportRect.y) or (AY >= lViewportRect.y + lViewportRect.h) then
    Exit;

  lY := AY - lViewportRect.y + ScrollY;
  if FRowHeight <= 0 then
    Exit;

  Result := lY div FRowHeight;
  if (Result < 0) or (Result >= FItems.Count) then
    Result := -1;
end;

function TNXPropertyEditor.RowRect(AIndex: Integer): TNXRect;
begin
  Result := MakeNXRect(ViewportRect.x - ScrollX,
    ViewportRect.y + (AIndex * FRowHeight) - ScrollY,
    Max(ViewportWidth, ContentWidth), FRowHeight);
end;

function TNXPropertyEditor.NameRect(AIndex: Integer): TNXRect;
var
  lRowRect: TNXRect;
begin
  lRowRect := RowRect(AIndex);
  Result := MakeNXRect(lRowRect.x, lRowRect.y, FNameColumnWidth, lRowRect.h);
end;

function TNXPropertyEditor.ValueRect(AIndex: Integer): TNXRect;
var
  lRowRect: TNXRect;
begin
  lRowRect := RowRect(AIndex);
  Result := MakeNXRect(lRowRect.x + FNameColumnWidth, lRowRect.y,
    Max(0, lRowRect.w - FNameColumnWidth), lRowRect.h);
end;

procedure TNXPropertyEditor.UpdateContentSize;
begin
  ContentWidth := Max(0, FNameColumnWidth + 160);
  ContentHeight := FItems.Count * FRowHeight;
end;

procedure TNXPropertyEditor.UpdateEditorBounds;
var
  lLocalLeft: Integer;
  lLocalTop: Integer;
  lValueRect: TNXRect;
begin
  if (not Assigned(FEditor)) or (FEditingIndex < 0) then
    Exit;

  lValueRect := ValueRect(FEditingIndex);
  lLocalLeft := lValueRect.x + 1;
  lLocalTop := lValueRect.y + 1;

  FEditor.SetBounds(lLocalLeft, lLocalTop,
    Max(0, lValueRect.w - 2), Max(0, lValueRect.h - 2));
end;

procedure TNXPropertyEditor.BeginEdit;
var
  lItem: TNXPropertyEditorItem;
begin
  if (FSelectedIndex < 0) or (FSelectedIndex >= FItems.Count) then
    Exit;

  lItem := FItems[FSelectedIndex];
  if lItem.ReadOnly or (lItem.ValueKind = pkReadOnly) or (lItem.ValueKind = pkObject) then
    Exit;

  FEditingIndex := FSelectedIndex;
  FEditor.Text := ItemValue(lItem);
  FEditor.Visible := True;
  FEditor.IsSelected := True;
  UpdateEditorBounds;
end;

procedure TNXPropertyEditor.CancelEdit;
begin
  if not Assigned(FEditor) then
    Exit;

  FEditingIndex := -1;
  FEditor.Visible := False;
  FEditor.IsSelected := False;
end;

procedure TNXPropertyEditor.CommitEdit;
begin
  EndEdit(True);
end;

procedure TNXPropertyEditor.EndEdit(AAccept: Boolean);
var
  lAccepted: Boolean;
  lItem: TNXPropertyEditorItem;
begin
  if (FEditingIndex < 0) or (FEditingIndex >= FItems.Count) then
  begin
    CancelEdit;
    Exit;
  end;

  lItem := FItems[FEditingIndex];
  if AAccept then
  begin
    lAccepted := True;
    if Assigned(FOnSetValue) then
      FOnSetValue(Self, lItem, FEditor.Text, lAccepted);

    if lAccepted then
      lItem.Value := FEditor.Text;
  end;

  CancelEdit;
end;

procedure TNXPropertyEditor.HandleEditorKeyDown(Sender: TObject;
  const AEvent: TNXKeyEventData);
begin
  case AEvent.Key of
    nkEnter:
      CommitEdit;
    nkEscape:
      CancelEdit;
  end;
end;

procedure TNXPropertyEditor.DoItemSelected(AItem: TNXPropertyEditorItem);
begin
  if Assigned(FOnItemSelected) then
    FOnItemSelected(Self, AItem);
end;

procedure TNXPropertyEditor.DoItemActivate(AItem: TNXPropertyEditorItem);
begin
  if Assigned(FOnItemActivate) then
    FOnItemActivate(Self, AItem);
end;

procedure TNXPropertyEditor.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
var
  lRow: Integer;
begin
  inherited DoMouseDown(AX, AY, AButton);

  if AButton <> mbLeft then
    Exit;

  lRow := RowAt(AX, AY);
  if lRow < 0 then
  begin
    EndEdit(True);
    Exit;
  end;

  SelectedIndex := lRow;
end;

procedure TNXPropertyEditor.DoMouseDoubleClick(AX, AY: Integer;
  AButton: TNXMouseButton);
var
  lRow: Integer;
begin
  inherited DoMouseDoubleClick(AX, AY, AButton);

  if AButton <> mbLeft then
    Exit;

  lRow := RowAt(AX, AY);
  if lRow < 0 then
    Exit;

  SelectedIndex := lRow;
  DoItemActivate(FItems[lRow]);
  BeginEdit;
end;

procedure TNXPropertyEditor.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
begin
  inherited DoKeyDown(AEvent);

  if FEditingIndex >= 0 then
    Exit;

  lIndex := FSelectedIndex;
  if lIndex < 0 then
    lIndex := 0;

  case AEvent.Key of
    nkUp:
      SelectedIndex := Max(0, lIndex - 1);
    nkDown:
      SelectedIndex := Min(FItems.Count - 1, lIndex + 1);
    nkHome:
      SelectedIndex := 0;
    nkEnd:
      SelectedIndex := FItems.Count - 1;
    nkEnter:
      BeginEdit;
  end;
end;

procedure TNXPropertyEditor.DrawCellText(const AText: string; const ARect: TNXRect;
  AAlign: TTextAlign);
var
  lFont: TNXFont;
  lTextWidth: Integer;
  lTextX: Integer;
  lTextY: Integer;
begin
  if AText = '' then
    Exit;

  lFont := Font;
  if (not Assigned(Canvas)) or (not Assigned(lFont)) then
    Exit;

  lTextWidth := Canvas.TextWidth(AText, lFont);
  case AAlign of
    Align_Center:
      lTextX := ARect.x + (ARect.w div 2) - (lTextWidth div 2);
    Align_Right:
      lTextX := ARect.x + ARect.w - lTextWidth - cCellPaddingX;
  else
    lTextX := ARect.x + cCellPaddingX;
  end;

  lTextY := ARect.y + Max(0, (ARect.h - FontHeight) div 2);
  Canvas.DrawText(AText, AbsLeft + lTextX, AbsTop + lTextY, ForeColor, lFont);
end;

procedure TNXPropertyEditor.DrawItem(AIndex: Integer; const ARect: TNXRect);
var
  lItem: TNXPropertyEditorItem;
  lNameRect: TNXRect;
  lValueRect: TNXRect;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit;

  lItem := FItems[AIndex];
  lNameRect := NameRect(AIndex);
  lValueRect := ValueRect(AIndex);

  if AIndex = FSelectedIndex then
    RenderFilledRect(ARect, Skin.SelectedColor)
  else
    RenderFilledRect(ARect, Skin.TextBackColor);

  RenderFilledRect(lNameRect, Skin.BackColor);
  DrawCellText(lItem.Name, lNameRect, Align_Left);

  if AIndex <> FEditingIndex then
    DrawCellText(ItemValue(lItem), lValueRect, Align_Left);

  if FShowGridLines then
  begin
    RenderLine(ARect.x, ARect.y + ARect.h - 1,
      ARect.x + ARect.w, ARect.y + ARect.h - 1, Skin.BorderColor);
    RenderLine(lValueRect.x - 1, ARect.y,
      lValueRect.x - 1, ARect.y + ARect.h, Skin.BorderColor);
  end;
end;

procedure TNXPropertyEditor.RenderViewport;
var
  lFirstRow: Integer;
  lLastRow: Integer;
  lRow: Integer;
  lRowRect: TNXRect;
  lViewportBottom: Integer;
begin
  UpdateContentSize;
  UpdateEditorBounds;

  if FRowHeight <= 0 then
    Exit;

  lViewportBottom := ViewportRect.y + ViewportHeight;
  lFirstRow := Max(0, ScrollY div FRowHeight);
  lLastRow := Min(FItems.Count - 1, (ScrollY + ViewportHeight) div FRowHeight + 1);

  for lRow := lFirstRow to lLastRow do
  begin
    lRowRect := RowRect(lRow);
    if (lRowRect.y + lRowRect.h <= ViewportRect.y) or
      (lRowRect.y >= lViewportBottom) then
      Continue;

    DrawItem(lRow, lRowRect);
  end;
end;

end.
