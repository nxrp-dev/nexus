unit obNXTreeMap;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  tpNXPlatform,
  obNXElement,
  obNXControl;

type
  TTransaction = record
    Amount: Double;
    Category: String;
    Subcategory: String;
  end;

  TTransactionArray = array of TTransaction;

  TTreeMapNodeKind = (
    tnkCategory,
    tnkTransaction
  );

  TTreeMapNode = record
    Rect: TNXRect;
    Caption: String;
    Amount: Double;
    Color: TNXColor;
    Level: Integer;
    Kind: TTreeMapNodeKind;
    DataIndex: Integer;
  end;

  TTreeMapNodeArray = array of TTreeMapNode;

  TTreeMapHoverEvent = procedure(
    ASender: TObject;
    ANodeIndex: Integer;
    const ANode: TTreeMapNode;
    ATransactionIndex: Integer;
    const ATransaction: TTransaction;
    const ACategory: String
  ) of object;

  TTreeMapSelectedEvent = procedure(
    ASender: TObject;
    ANodeIndex: Integer;
    const ANode: TTreeMapNode;
    ATransactionIndex: Integer;
    const ATransaction: TTransaction;
    const ACategory: String
  ) of object;

  TNXTreeMap = class(TNXControl)
  private
    FData: TTransactionArray;
    FNodes: TTreeMapNodeArray;
    FHoverIndex: Integer;
    FSelectedIndex: Integer;
    FLayoutDirty: Boolean;
    FOnHover: TTreeMapHoverEvent;
    FOnSelected: TTreeMapSelectedEvent;

    procedure SetData(const AValue: TTransactionArray);
    procedure RebuildLayout;
    procedure ClearLayout;

    function AddNode(
      const ARect: TNXRect;
      const ACaption: String;
      const AAmount: Double;
      const AColor: TNXColor;
      const ALevel: Integer;
      const AKind: TTreeMapNodeKind;
      const ADataIndex: Integer
    ): Integer;

    function GetClientRect: TNXRect;
    function NodeAt(const AX, AY: Integer): Integer;
    procedure DrawNode(const ANode: TTreeMapNode);
    procedure DrawTextIfRoom(const ARect: TNXRect; const AText: String);
    procedure SetHoverIndex(const AValue: Integer);
    procedure NotifyHover;
    procedure SetSelectedIndex(const AValue: Integer);
    procedure NotifySelected;

  public
    constructor Create(AParent: TNXElement); overload; override;

    procedure Render; override;
    procedure DoResize; override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure DoMouseExit; override;

    property Data: TTransactionArray read FData write SetData;
    property Nodes: TTreeMapNodeArray read FNodes;
    property HoverIndex: Integer read FHoverIndex;
    property SelectedIndex: Integer read FSelectedIndex;
    property OnHover: TTreeMapHoverEvent read FOnHover write FOnHover;
    property OnSelected: TTreeMapSelectedEvent read FOnSelected write FOnSelected;
  end;

implementation

type
  TLayoutItem = record
    Caption: String;
    Amount: Double;
    Color: TNXColor;
    Kind: TTreeMapNodeKind;
    DataIndex: Integer;
  end;

  TLayoutItemArray = array of TLayoutItem;

  TCategoryItem = record
    Caption: String;
    Amount: Double;
    Color: TNXColor;
    Transactions: TLayoutItemArray;
  end;

  TCategoryItemArray = array of TCategoryItem;

const
  cCategoryHeaderHeight = 18;
  cMinNodeSize = 3;

  cWhite: TNXColor = (r: 255; g: 255; b: 255; a: 255);
  cBlack: TNXColor = (r: 0; g: 0; b: 0; a: 255);
  cGray: TNXColor = (r: 128; g: 128; b: 128; a: 255);
  cYellow: TNXColor = (r: 255; g: 255; b: 0; a: 255);
  cNone: TNXColor = (r: 0; g: 0; b: 0; a: 0);

  cPalette: array[0..11] of TNXColor = (
    (r: 220; g: 64; b: 64; a: 255),
    (r: 64; g: 180; b: 96; a: 255),
    (r: 64; g: 112; b: 220; a: 255),
    (r: 64; g: 200; b: 200; a: 255),
    (r: 220; g: 200; b: 64; a: 255),
    (r: 200; g: 64; b: 200; a: 255),
    (r: 128; g: 128; b: 64; a: 255),
    (r: 64; g: 64; b: 160; a: 255),
    (r: 64; g: 128; b: 128; a: 255),
    (r: 128; g: 64; b: 64; a: 255),
    (r: 128; g: 64; b: 128; a: 255),
    (r: 128; g: 128; b: 128; a: 255)
  );

function RectRight(const ARect: TNXRect): Integer;
begin
  Result := ARect.x + ARect.w;
end;

function RectBottom(const ARect: TNXRect): Integer;
begin
  Result := ARect.y + ARect.h;
end;

function RectWidth(const ARect: TNXRect): Integer;
begin
  Result := ARect.w;
end;

function RectHeight(const ARect: TNXRect): Integer;
begin
  Result := ARect.h;
end;

function RectIsUsable(const ARect: TNXRect): Boolean;
begin
  Result :=
    (RectWidth(ARect) >= cMinNodeSize) and
    (RectHeight(ARect) >= cMinNodeSize);
end;

function PointInNodeRect(const ARect: TNXRect; const AX, AY: Integer): Boolean;
begin
  Result :=
    (AX >= ARect.x) and
    (AX < RectRight(ARect)) and
    (AY >= ARect.y) and
    (AY < RectBottom(ARect));
end;

function InflateNodeRect(const ARect: TNXRect; const ADX, ADY: Integer): TNXRect;
begin
  Result.x := ARect.x + ADX;
  Result.y := ARect.y + ADY;
  Result.w := ARect.w - (ADX * 2);
  Result.h := ARect.h - (ADY * 2);

  if Result.w < 0 then
    Result.w := 0;

  if Result.h < 0 then
    Result.h := 0;
end;

function BlendColor(const AColor1, AColor2: TNXColor; const ARatio: Double): TNXColor;
begin
  Result.r := Round(AColor1.r + ((AColor2.r - AColor1.r) * ARatio));
  Result.g := Round(AColor1.g + ((AColor2.g - AColor1.g) * ARatio));
  Result.b := Round(AColor1.b + ((AColor2.b - AColor1.b) * ARatio));
  Result.a := Round(AColor1.a + ((AColor2.a - AColor1.a) * ARatio));
end;

function GetStringHash(const AValue: String): Cardinal;
var
  lIndex: Integer;
begin
  Result := 2166136261;

  for lIndex := 1 to Length(AValue) do
  begin
    Result := Result xor Ord(AValue[lIndex]);
    Result := Result * 16777619;
  end;
end;

function GetCategoryColor(const ACategory: String): TNXColor;
begin
  Result := cPalette[GetStringHash(ACategory) mod Length(cPalette)];
end;

function NormalizeCategoryCaption(const ACategory: String): String;
begin
  Result := Trim(ACategory);

  if Result = '' then
    Result := '(Uncategorized)';
end;

procedure SortLayoutItemsByAmountDescending(var AItems: TLayoutItemArray);
var
  lOuterIndex: Integer;
  lInnerIndex: Integer;
  lTemp: TLayoutItem;
begin
  for lOuterIndex := 0 to High(AItems) - 1 do
    for lInnerIndex := lOuterIndex + 1 to High(AItems) do
      if AItems[lInnerIndex].Amount > AItems[lOuterIndex].Amount then
      begin
        lTemp := AItems[lOuterIndex];
        AItems[lOuterIndex] := AItems[lInnerIndex];
        AItems[lInnerIndex] := lTemp;
      end;
end;

procedure SortCategoriesByAmountDescending(var ACategories: TCategoryItemArray);
var
  lOuterIndex: Integer;
  lInnerIndex: Integer;
  lTemp: TCategoryItem;
begin
  for lOuterIndex := 0 to High(ACategories) - 1 do
    for lInnerIndex := lOuterIndex + 1 to High(ACategories) do
      if ACategories[lInnerIndex].Amount > ACategories[lOuterIndex].Amount then
      begin
        lTemp := ACategories[lOuterIndex];
        ACategories[lOuterIndex] := ACategories[lInnerIndex];
        ACategories[lInnerIndex] := lTemp;
      end;
end;

function SumLayoutItems(
  const AItems: TLayoutItemArray;
  const AFirstIndex: Integer;
  const ALastIndex: Integer
): Double;
var
  lIndex: Integer;
begin
  Result := 0;

  for lIndex := AFirstIndex to ALastIndex do
    Result := Result + AItems[lIndex].Amount;
end;

function FindBalancedSplit(
  const AItems: TLayoutItemArray;
  const AFirstIndex: Integer;
  const ALastIndex: Integer
): Integer;
var
  lTotal: Double;
  lRunningTotal: Double;
  lIndex: Integer;
begin
  Result := AFirstIndex;
  lTotal := SumLayoutItems(AItems, AFirstIndex, ALastIndex);
  lRunningTotal := 0;

  for lIndex := AFirstIndex to ALastIndex - 1 do
  begin
    lRunningTotal := lRunningTotal + AItems[lIndex].Amount;

    if lRunningTotal >= (lTotal / 2) then
    begin
      Result := lIndex;
      Exit;
    end;
  end;
end;

procedure LayoutItemsRecursive(
  const AOwner: TNXTreeMap;
  const AItems: TLayoutItemArray;
  const AFirstIndex: Integer;
  const ALastIndex: Integer;
  const ARect: TNXRect;
  const ALevel: Integer
);
var
  lTotal: Double;
  lLeftTotal: Double;
  lSplitIndex: Integer;
  lSplitOffset: Integer;
  lFirstRect: TNXRect;
  lSecondRect: TNXRect;
  lItem: TLayoutItem;
begin
  if (AFirstIndex > ALastIndex) or (not RectIsUsable(ARect)) then
    Exit;

  if AFirstIndex = ALastIndex then
  begin
    lItem := AItems[AFirstIndex];

    if lItem.Amount > 0 then
      AOwner.AddNode(
        ARect,
        lItem.Caption,
        lItem.Amount,
        lItem.Color,
        ALevel,
        lItem.Kind,
        lItem.DataIndex
      );

    Exit;
  end;

  lTotal := SumLayoutItems(AItems, AFirstIndex, ALastIndex);

  if lTotal <= 0 then
    Exit;

  lSplitIndex := FindBalancedSplit(AItems, AFirstIndex, ALastIndex);
  lLeftTotal := SumLayoutItems(AItems, AFirstIndex, lSplitIndex);

  lFirstRect := ARect;
  lSecondRect := ARect;

  if RectWidth(ARect) >= RectHeight(ARect) then
  begin
    lSplitOffset := Round(RectWidth(ARect) * (lLeftTotal / lTotal));

    if lSplitOffset < cMinNodeSize then
      lSplitOffset := cMinNodeSize;

    if lSplitOffset > RectWidth(ARect) - cMinNodeSize then
      lSplitOffset := RectWidth(ARect) - cMinNodeSize;

    lFirstRect.w := lSplitOffset;
    lSecondRect.x := ARect.x + lSplitOffset;
    lSecondRect.w := ARect.w - lSplitOffset;
  end
  else
  begin
    lSplitOffset := Round(RectHeight(ARect) * (lLeftTotal / lTotal));

    if lSplitOffset < cMinNodeSize then
      lSplitOffset := cMinNodeSize;

    if lSplitOffset > RectHeight(ARect) - cMinNodeSize then
      lSplitOffset := RectHeight(ARect) - cMinNodeSize;

    lFirstRect.h := lSplitOffset;
    lSecondRect.y := ARect.y + lSplitOffset;
    lSecondRect.h := ARect.h - lSplitOffset;
  end;

  LayoutItemsRecursive(AOwner, AItems, AFirstIndex, lSplitIndex, lFirstRect, ALevel);
  LayoutItemsRecursive(AOwner, AItems, lSplitIndex + 1, ALastIndex, lSecondRect, ALevel);
end;

function FindCategoryIndex(
  const ACategories: TCategoryItemArray;
  const ACaption: String
): Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  for lIndex := 0 to High(ACategories) do
    if SameText(ACategories[lIndex].Caption, ACaption) then
    begin
      Result := lIndex;
      Exit;
    end;
end;

procedure BuildCategories(
  const AData: TTransactionArray;
  out ACategories: TCategoryItemArray
);
var
  lDataIndex: Integer;
  lCategoryIndex: Integer;
  lTransactionIndex: Integer;
  lCaption: String;
begin
  SetLength(ACategories, 0);

  for lDataIndex := 0 to High(AData) do
  begin
    if AData[lDataIndex].Amount <= 0 then
      Continue;

    lCaption := NormalizeCategoryCaption(AData[lDataIndex].Category);
    lCategoryIndex := FindCategoryIndex(ACategories, lCaption);

    if lCategoryIndex < 0 then
    begin
      SetLength(ACategories, Length(ACategories) + 1);
      lCategoryIndex := High(ACategories);

      ACategories[lCategoryIndex].Caption := lCaption;
      ACategories[lCategoryIndex].Amount := 0;
      ACategories[lCategoryIndex].Color := GetCategoryColor(lCaption);
      SetLength(ACategories[lCategoryIndex].Transactions, 0);
    end;

    ACategories[lCategoryIndex].Amount :=
      ACategories[lCategoryIndex].Amount + AData[lDataIndex].Amount;

    lTransactionIndex := Length(ACategories[lCategoryIndex].Transactions);
    SetLength(ACategories[lCategoryIndex].Transactions, lTransactionIndex + 1);

    if Trim(AData[lDataIndex].Subcategory) <> '' then
      ACategories[lCategoryIndex].Transactions[lTransactionIndex].Caption :=
        AData[lDataIndex].Subcategory
    else
      ACategories[lCategoryIndex].Transactions[lTransactionIndex].Caption :=
        AData[lDataIndex].Category;

    ACategories[lCategoryIndex].Transactions[lTransactionIndex].Amount :=
      AData[lDataIndex].Amount;

    ACategories[lCategoryIndex].Transactions[lTransactionIndex].Color :=
      BlendColor(ACategories[lCategoryIndex].Color, cWhite, 0.35);

    ACategories[lCategoryIndex].Transactions[lTransactionIndex].Kind :=
      tnkTransaction;

    ACategories[lCategoryIndex].Transactions[lTransactionIndex].DataIndex :=
      lDataIndex;
  end;

  SortCategoriesByAmountDescending(ACategories);

  for lCategoryIndex := 0 to High(ACategories) do
    SortLayoutItemsByAmountDescending(ACategories[lCategoryIndex].Transactions);
end;

constructor TNXTreeMap.Create(AParent: TNXElement);
begin
  inherited Create(AParent);

  Width := 400;
  Height := 300;
  BackColor := cWhite;
  ForeColor := cBlack;
  BorderStyle := BS_None;
  FillStyle := FS_Filled;

  FHoverIndex := -1;
  FSelectedIndex := -1;
  FLayoutDirty := True;
end;

procedure TNXTreeMap.SetData(const AValue: TTransactionArray);
begin
  FData := AValue;
  FLayoutDirty := True;
  FHoverIndex := -1;
  FSelectedIndex := -1;
end;

procedure TNXTreeMap.ClearLayout;
begin
  SetLength(FNodes, 0);
  FLayoutDirty := False;
end;

function TNXTreeMap.GetClientRect: TNXRect;
begin
  Result := MakeNXRect(0, 0, Width, Height);
end;

function TNXTreeMap.AddNode(
  const ARect: TNXRect;
  const ACaption: String;
  const AAmount: Double;
  const AColor: TNXColor;
  const ALevel: Integer;
  const AKind: TTreeMapNodeKind;
  const ADataIndex: Integer
): Integer;
begin
  Result := Length(FNodes);
  SetLength(FNodes, Result + 1);

  FNodes[Result].Rect := ARect;
  FNodes[Result].Caption := ACaption;
  FNodes[Result].Amount := AAmount;
  FNodes[Result].Color := AColor;
  FNodes[Result].Level := ALevel;
  FNodes[Result].Kind := AKind;
  FNodes[Result].DataIndex := ADataIndex;
end;

procedure TNXTreeMap.RebuildLayout;
var
  lCategories: TCategoryItemArray;
  lCategoryItems: TLayoutItemArray;
  lCategoryIndex: Integer;
  lCategoryNodeIndex: Integer;
  lCategoryRect: TNXRect;
  lClientRect: TNXRect;
  lTransactionRect: TNXRect;
begin
  ClearLayout;
  lClientRect := GetClientRect;

  if (Length(FData) = 0) or (RectWidth(lClientRect) <= 0) or (RectHeight(lClientRect) <= 0) then
    Exit;

  BuildCategories(FData, lCategories);

  if Length(lCategories) = 0 then
    Exit;

  SetLength(lCategoryItems, Length(lCategories));

  for lCategoryIndex := 0 to High(lCategories) do
  begin
    lCategoryItems[lCategoryIndex].Caption := lCategories[lCategoryIndex].Caption;
    lCategoryItems[lCategoryIndex].Amount := lCategories[lCategoryIndex].Amount;
    lCategoryItems[lCategoryIndex].Color := lCategories[lCategoryIndex].Color;
    lCategoryItems[lCategoryIndex].Kind := tnkCategory;
    lCategoryItems[lCategoryIndex].DataIndex := lCategoryIndex;
  end;

  LayoutItemsRecursive(Self, lCategoryItems, 0, High(lCategoryItems), lClientRect, 0);

  for lCategoryNodeIndex := 0 to High(FNodes) do
  begin
    if FNodes[lCategoryNodeIndex].Kind <> tnkCategory then
      Continue;

    lCategoryIndex := FNodes[lCategoryNodeIndex].DataIndex;

    if (lCategoryIndex < 0) or (lCategoryIndex > High(lCategories)) then
      Continue;

    lCategoryRect := FNodes[lCategoryNodeIndex].Rect;
    lTransactionRect := lCategoryRect;

    if RectHeight(lTransactionRect) > cCategoryHeaderHeight + cMinNodeSize then
    begin
      Inc(lTransactionRect.y, cCategoryHeaderHeight);
      Dec(lTransactionRect.h, cCategoryHeaderHeight);
    end;

    lTransactionRect := InflateNodeRect(lTransactionRect, 2, 2);

    if RectIsUsable(lTransactionRect) and (Length(lCategories[lCategoryIndex].Transactions) > 0) then
      LayoutItemsRecursive(
        Self,
        lCategories[lCategoryIndex].Transactions,
        0,
        High(lCategories[lCategoryIndex].Transactions),
        lTransactionRect,
        1
      );
  end;
end;

procedure TNXTreeMap.DrawTextIfRoom(const ARect: TNXRect; const AText: String);
begin
  if (AText = '') or (RectWidth(ARect) < 24) or (RectHeight(ARect) < 12) then
    Exit;

  if not Assigned(Font) then
    Exit;

  RenderText(AText, ARect.x + 3, ARect.y + 2, Align_Left);
end;

procedure TNXTreeMap.DrawNode(const ANode: TTreeMapNode);
var
  lRect: TNXRect;
  lScreenRect: TNXRect;
  lDisplayText: String;
  lBorderColor: TNXColor;
begin
  lRect := ANode.Rect;

  if not RectIsUsable(lRect) then
    Exit;

  lScreenRect := MakeNXRect(AbsLeft + lRect.x, AbsTop + lRect.y, lRect.w, lRect.h);

  RenderFilledRect(lScreenRect, ANode.Color);

  if ANode.Kind = tnkCategory then
    lBorderColor := cBlack
  else
    lBorderColor := cGray;

  RenderRect(lScreenRect, lBorderColor);

  if ANode.Kind = tnkCategory then
    lDisplayText := ANode.Caption + '  ' + FormatFloat('$#,##0.00', ANode.Amount)
  else
    lDisplayText := ANode.Caption;

  DrawTextIfRoom(lRect, lDisplayText);
end;

procedure TNXTreeMap.Render;
var
  lIndex: Integer;
  lScreenRect: TNXRect;
  lHighlightColor: TNXColor;
begin
  inherited Render;

  if not Assigned(Canvas) then
    Exit;

  if FLayoutDirty then
    RebuildLayout;

  for lIndex := 0 to High(FNodes) do
    DrawNode(FNodes[lIndex]);

  if (FHoverIndex >= 0) and (FHoverIndex <= High(FNodes)) then
  begin
    lScreenRect := MakeNXRect(
      AbsLeft + FNodes[FHoverIndex].Rect.x,
      AbsTop + FNodes[FHoverIndex].Rect.y,
      FNodes[FHoverIndex].Rect.w,
      FNodes[FHoverIndex].Rect.h
    );
    lHighlightColor := cWhite;
    RenderRect(lScreenRect, lHighlightColor);
  end;

  if (FSelectedIndex >= 0) and (FSelectedIndex <= High(FNodes)) then
  begin
    lScreenRect := MakeNXRect(
      AbsLeft + FNodes[FSelectedIndex].Rect.x,
      AbsTop + FNodes[FSelectedIndex].Rect.y,
      FNodes[FSelectedIndex].Rect.w,
      FNodes[FSelectedIndex].Rect.h
    );
    lHighlightColor := cYellow;
    RenderRect(lScreenRect, lHighlightColor);
  end;
end;

procedure TNXTreeMap.DoResize;
begin
  inherited DoResize;
  FLayoutDirty := True;
end;

function TNXTreeMap.NodeAt(const AX, AY: Integer): Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  for lIndex := High(FNodes) downto 0 do
    if PointInNodeRect(FNodes[lIndex].Rect, AX, AY) then
    begin
      Result := lIndex;
      Exit;
    end;
end;

procedure TNXTreeMap.SetHoverIndex(const AValue: Integer);
begin
  if FHoverIndex = AValue then
    Exit;

  FHoverIndex := AValue;
  NotifyHover;
end;

procedure TNXTreeMap.NotifyHover;
var
  lNode: TTreeMapNode;
  lTransaction: TTransaction;
  lTransactionIndex: Integer;
  lCategory: String;
begin
  if not Assigned(FOnHover) then
    Exit;

  lNode.Rect := MakeNXRect(0, 0, 0, 0);
  lNode.Caption := '';
  lNode.Amount := 0;
  lNode.Color := cNone;
  lNode.Level := 0;
  lNode.Kind := tnkCategory;
  lNode.DataIndex := -1;

  lTransaction.Amount := 0;
  lTransaction.Category := '';
  lTransaction.Subcategory := '';
  lTransactionIndex := -1;
  lCategory := '';

  if (FHoverIndex >= 0) and (FHoverIndex <= High(FNodes)) then
  begin
    lNode := FNodes[FHoverIndex];

    if lNode.Kind = tnkTransaction then
    begin
      lTransactionIndex := lNode.DataIndex;

      if (lTransactionIndex >= 0) and (lTransactionIndex <= High(FData)) then
      begin
        lTransaction := FData[lTransactionIndex];
        lCategory := NormalizeCategoryCaption(lTransaction.Category);
      end;
    end
    else
      lCategory := lNode.Caption;
  end;

  FOnHover(Self, FHoverIndex, lNode, lTransactionIndex, lTransaction, lCategory);
end;

procedure TNXTreeMap.SetSelectedIndex(const AValue: Integer);
begin
  if FSelectedIndex = AValue then
    Exit;

  FSelectedIndex := AValue;
  NotifySelected;
end;

procedure TNXTreeMap.NotifySelected;
var
  lNode: TTreeMapNode;
  lTransaction: TTransaction;
  lTransactionIndex: Integer;
  lCategory: String;
begin
  if not Assigned(FOnSelected) then
    Exit;

  lNode.Rect := MakeNXRect(0, 0, 0, 0);
  lNode.Caption := '';
  lNode.Amount := 0;
  lNode.Color := cNone;
  lNode.Level := 0;
  lNode.Kind := tnkCategory;
  lNode.DataIndex := -1;

  lTransaction.Amount := 0;
  lTransaction.Category := '';
  lTransaction.Subcategory := '';
  lTransactionIndex := -1;
  lCategory := '';

  if (FSelectedIndex >= 0) and (FSelectedIndex <= High(FNodes)) then
  begin
    lNode := FNodes[FSelectedIndex];

    if lNode.Kind = tnkTransaction then
    begin
      lTransactionIndex := lNode.DataIndex;

      if (lTransactionIndex >= 0) and (lTransactionIndex <= High(FData)) then
      begin
        lTransaction := FData[lTransactionIndex];
        lCategory := NormalizeCategoryCaption(lTransaction.Category);
      end;
    end
    else
      lCategory := lNode.Caption;
  end;

  FOnSelected(Self, FSelectedIndex, lNode, lTransactionIndex, lTransaction, lCategory);
end;

procedure TNXTreeMap.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  lNodeIndex: Integer;
begin
  inherited DoMouseDown(X, Y, Button);

  if Button <> mbLeft then
    Exit;

  if FLayoutDirty then
    RebuildLayout;

  lNodeIndex := NodeAt(X, Y);

  if (lNodeIndex >= 0) and
     (lNodeIndex <= High(FNodes)) and
     (FNodes[lNodeIndex].Kind = tnkTransaction) then
    SetSelectedIndex(lNodeIndex);
end;

procedure TNXTreeMap.DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons);
begin
  inherited DoMouseMotion(X, Y, ButtonState);

  if FLayoutDirty then
    RebuildLayout;

  SetHoverIndex(NodeAt(X, Y));
end;

procedure TNXTreeMap.DoMouseExit;
begin
  inherited DoMouseExit;
  SetHoverIndex(-1);
end;

end.
