unit obNXTreeView;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Math,
  SysUtils,
  fgl,
  tpNXEvents,
  tpNXPlatform,
  obNXControl,
  obNXFont,
  obNXScrollableControl;

type
  TNXTreeViewNode = class;
  TNXTreeViewCell = class;
  TNXTreeViewColumn = class;

  TNXTreeViewCellAlign = (
    tvcaLeft,
    tvcaCenter,
    tvcaRight
  );

  TNXTreeViewGlyphKind = (
    tvgkNone,
    tvgkCircle,
    tvgkSquare
  );

  TNXTreeViewColumnListBase = specialize TFPGObjectList<TNXTreeViewColumn>;
  TNXTreeViewCellListBase = specialize TFPGObjectList<TNXTreeViewCell>;
  TNXTreeViewNodeListBase = specialize TFPGObjectList<TNXTreeViewNode>;
  TNXTreeViewVisibleNodeListBase = specialize TFPGList<TNXTreeViewNode>;

  TNXTreeViewCell = class
  private
    FAlign: TNXTreeViewCellAlign;
    FBackColor: TNXColor;
    FForeColor: TNXColor;
    FGlyphColor: TNXColor;
    FGlyphKind: TNXTreeViewGlyphKind;
    FImage: TNXImageHandle;
    FImageHeight: Integer;
    FImageWidth: Integer;
    FText: string;
    FUseBackColor: Boolean;
    FUseForeColor: Boolean;
    FUseGlyphColor: Boolean;
  public
    constructor Create; virtual;
    procedure Clear; virtual;

    property Align: TNXTreeViewCellAlign read FAlign write FAlign;
    property BackColor: TNXColor read FBackColor write FBackColor;
    property ForeColor: TNXColor read FForeColor write FForeColor;
    property GlyphColor: TNXColor read FGlyphColor write FGlyphColor;
    property GlyphKind: TNXTreeViewGlyphKind read FGlyphKind write FGlyphKind;
    property Image: TNXImageHandle read FImage write FImage;
    property ImageHeight: Integer read FImageHeight write FImageHeight;
    property ImageWidth: Integer read FImageWidth write FImageWidth;
    property Text: string read FText write FText;
    property UseBackColor: Boolean read FUseBackColor write FUseBackColor;
    property UseForeColor: Boolean read FUseForeColor write FUseForeColor;
    property UseGlyphColor: Boolean read FUseGlyphColor write FUseGlyphColor;
  end;

  TNXTreeViewColumn = class
  private
    FAlign: TNXTreeViewCellAlign;
    FCaption: string;
    FMinWidth: Integer;
    FVisible: Boolean;
    FWidth: Integer;
    procedure SetMinWidth(AValue: Integer);
    procedure SetWidth(AValue: Integer);
  public
    constructor Create(const ACaption: string; AWidth: Integer); virtual;

    property Align: TNXTreeViewCellAlign read FAlign write FAlign;
    property Caption: string read FCaption write FCaption;
    property MinWidth: Integer read FMinWidth write SetMinWidth;
    property Visible: Boolean read FVisible write FVisible;
    property Width: Integer read FWidth write SetWidth;
  end;

  TNXTreeViewNode = class
  private
    FCells: TNXTreeViewCellListBase;
    FChildren: TNXTreeViewNodeListBase;
    FData: Pointer;
    FExpanded: Boolean;
    FParent: TNXTreeViewNode;
    FSelected: Boolean;

    function GetCell(AIndex: Integer): TNXTreeViewCell;
    function GetCellCount: Integer;
    function GetChild(AIndex: Integer): TNXTreeViewNode;
    function GetChildCount: Integer;
    function GetLevel: Integer;
    function GetText: string;
    procedure SetText(const AValue: string);
  public
    constructor Create(const AText: string = ''; AData: Pointer = nil); virtual;
    destructor Destroy; override;

    function AddChild(const AText: string = ''; AData: Pointer = nil): TNXTreeViewNode; virtual;
    procedure Clear; virtual;
    procedure ClearCells; virtual;
    function Contains(ANode: TNXTreeViewNode): Boolean; virtual;
    procedure EnsureCellCount(ACount: Integer); virtual;
    function HasChildren: Boolean; virtual;

    property Cell[AIndex: Integer]: TNXTreeViewCell read GetCell;
    property CellCount: Integer read GetCellCount;
    property Child[AIndex: Integer]: TNXTreeViewNode read GetChild;
    property ChildCount: Integer read GetChildCount;
    property Data: Pointer read FData write FData;
    property Expanded: Boolean read FExpanded write FExpanded;
    property Level: Integer read GetLevel;
    property Parent: TNXTreeViewNode read FParent;
    property Selected: Boolean read FSelected write FSelected;
    property Text: string read GetText write SetText;
  end;

  TNXTreeViewRootList = class(TNXTreeViewNodeListBase)
  public
    function AddNode(const AText: string = ''; AData: Pointer = nil): TNXTreeViewNode;
  end;

  TNXTreeViewColumnList = class(TNXTreeViewColumnListBase)
  public
    function AddColumn(const ACaption: string; AWidth: Integer): TNXTreeViewColumn;
  end;

  TNXTreeViewVisibleNodeList = class(TNXTreeViewVisibleNodeListBase)
  end;

  TNXTreeViewNodeEvent = procedure(Sender: TObject; ANode: TNXTreeViewNode) of object;
  TNXTreeViewCellEvent = procedure(Sender: TObject; ANode: TNXTreeViewNode; AColumn: Integer) of object;
  TNXTreeViewColumnEvent = procedure(Sender: TObject; AColumn: Integer) of object;

  TNXTreeView = class(TNXScrollableControl)
  private
    FColumns: TNXTreeViewColumnList;
    FDefaultColumnWidth: Integer;
    FHeaderHeight: Integer;
    FIndentWidth: Integer;
    FLineHeight: Integer;
    FOnCellActivate: TNXTreeViewCellEvent;
    FOnCellClick: TNXTreeViewCellEvent;
    FOnChange: TNXTreeViewNodeEvent;
    FOnCollapsed: TNXTreeViewNodeEvent;
    FOnColumnClick: TNXTreeViewColumnEvent;
    FOnExpanded: TNXTreeViewNodeEvent;
    FRootNodes: TNXTreeViewRootList;
    FSelectedColumn: Integer;
    FSelectedNode: TNXTreeViewNode;
    FShowColumnHeaders: Boolean;
    FShowGridLines: Boolean;
    FVisibleNodes: TNXTreeViewVisibleNodeList;

    function GetTotalColumnWidth: Integer;
    procedure SetHeaderHeight(AValue: Integer);
    procedure SetIndentWidth(AValue: Integer);
    procedure SetLineHeight(AValue: Integer);
    procedure SetSelectedNode(AValue: TNXTreeViewNode);
    procedure SetShowColumnHeaders(AValue: Boolean);
  protected
    procedure AddVisibleNodes(ANodes: TNXTreeViewNodeListBase); virtual;
    function CellAt(AX, AY: Integer; out AColumn: Integer; out ANode: TNXTreeViewNode): Boolean; virtual;
    function CellRect(AColumn, AVisibleIndex: Integer): TNXRect; virtual;
    procedure CollapseNode(ANode: TNXTreeViewNode); virtual;
    function ColumnAt(AX, AY: Integer; out AColumn: Integer): Boolean; virtual;
    function ColumnLeft(AColumn: Integer): Integer; virtual;
    procedure DoCellActivate(ANode: TNXTreeViewNode; AColumn: Integer); virtual;
    procedure DoCellClick(ANode: TNXTreeViewNode; AColumn: Integer); virtual;
    procedure DoColumnClick(AColumn: Integer); virtual;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDoubleClick(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DrawCell(ANode: TNXTreeViewNode; AColumn, AVisibleIndex: Integer; const ARect: TNXRect); virtual;
    procedure DrawCellContent(ANode: TNXTreeViewNode; AColumn: Integer; const ARect: TNXRect); virtual;
    procedure DrawCellText(const AText: string; const ARect: TNXRect; AAlign: TNXTreeViewCellAlign; const AColor: TNXColor); virtual;
    procedure DrawExpandGlyph(ANode: TNXTreeViewNode; const ARect: TNXRect); virtual;
    procedure DrawHeader(AColumn: Integer; const ARect: TNXRect); virtual;
    procedure DrawStatusGlyph(const ACell: TNXTreeViewCell; const ARect: TNXRect); virtual;
    procedure EnsureSelectedVisible; virtual;
    procedure ExpandNode(ANode: TNXTreeViewNode); virtual;
    function GetContentTop: Integer; virtual;
    function GetDefaultLineHeight: Integer; virtual;
    function GetHeaderRect(AColumn: Integer): TNXRect; virtual;
    function GetNodeGlyphRect(ANode: TNXTreeViewNode; AVisibleIndex: Integer; const ACellRect: TNXRect): TNXRect; virtual;
    procedure RebuildVisibleNodes; virtual;
    procedure RenderViewport; override;
    procedure SelectNode(ANode: TNXTreeViewNode; AColumn: Integer = 0); virtual;
    procedure ToggleNode(ANode: TNXTreeViewNode); virtual;
    procedure UpdateContentSize; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;

    function AddChildNode(AParentNode: TNXTreeViewNode; const AText: string = ''; AData: Pointer = nil): TNXTreeViewNode; virtual;
    function AddColumn(const ACaption: string; AWidth: Integer = 0): TNXTreeViewColumn; virtual;
    function AddNode(const AText: string = ''; AData: Pointer = nil): TNXTreeViewNode; virtual;
    procedure Clear; virtual;
    procedure ClearColumns; virtual;
    procedure CollapseAll; virtual;
    procedure ExpandAll; virtual;
    procedure NodeChanged(ANode: TNXTreeViewNode); virtual;

    property Columns: TNXTreeViewColumnList read FColumns;
    property DefaultColumnWidth: Integer read FDefaultColumnWidth write FDefaultColumnWidth;
    property HeaderHeight: Integer read FHeaderHeight write SetHeaderHeight;
    property IndentWidth: Integer read FIndentWidth write SetIndentWidth;
    property LineHeight: Integer read FLineHeight write SetLineHeight;
    property OnCellActivate: TNXTreeViewCellEvent read FOnCellActivate write FOnCellActivate;
    property OnCellClick: TNXTreeViewCellEvent read FOnCellClick write FOnCellClick;
    property OnChange: TNXTreeViewNodeEvent read FOnChange write FOnChange;
    property OnCollapsed: TNXTreeViewNodeEvent read FOnCollapsed write FOnCollapsed;
    property OnColumnClick: TNXTreeViewColumnEvent read FOnColumnClick write FOnColumnClick;
    property OnExpanded: TNXTreeViewNodeEvent read FOnExpanded write FOnExpanded;
    property RootNodes: TNXTreeViewRootList read FRootNodes;
    property SelectedColumn: Integer read FSelectedColumn;
    property SelectedNode: TNXTreeViewNode read FSelectedNode write SetSelectedNode;
    property ShowColumnHeaders: Boolean read FShowColumnHeaders write SetShowColumnHeaders;
    property ShowGridLines: Boolean read FShowGridLines write FShowGridLines;
  end;

implementation

const
  cDefaultColumnWidth = 120;
  cDefaultHeaderHeight = 22;
  cDefaultIndentWidth = 18;
  cDefaultLineHeight = 22;
  cCellPaddingX = 4;
  cGlyphSize = 9;
  cStatusGlyphSize = 10;

constructor TNXTreeViewCell.Create;
begin
  inherited Create;
  Clear;
end;

procedure TNXTreeViewCell.Clear;
begin
  FAlign := tvcaLeft;
  FBackColor := MakeNXColor(0, 0, 0, 0);
  FForeColor := MakeNXColor(0, 0, 0, 0);
  FGlyphColor := MakeNXColor(128, 128, 128, 255);
  FGlyphKind := tvgkNone;
  FImage := nil;
  FImageHeight := 0;
  FImageWidth := 0;
  FText := '';
  FUseBackColor := False;
  FUseForeColor := False;
  FUseGlyphColor := False;
end;

constructor TNXTreeViewColumn.Create(const ACaption: string; AWidth: Integer);
begin
  inherited Create;
  FAlign := tvcaLeft;
  FCaption := ACaption;
  FMinWidth := 24;
  FVisible := True;
  FWidth := Max(FMinWidth, AWidth);
end;

procedure TNXTreeViewColumn.SetMinWidth(AValue: Integer);
begin
  FMinWidth := Max(8, AValue);
  if FWidth < FMinWidth then
    FWidth := FMinWidth;
end;

procedure TNXTreeViewColumn.SetWidth(AValue: Integer);
begin
  FWidth := Max(FMinWidth, AValue);
end;

constructor TNXTreeViewNode.Create(const AText: string; AData: Pointer);
begin
  inherited Create;
  FCells := TNXTreeViewCellListBase.Create(True);
  FChildren := TNXTreeViewNodeListBase.Create(True);
  FData := AData;
  FExpanded := False;
  FParent := nil;
  FSelected := False;
  Text := AText;
end;

destructor TNXTreeViewNode.Destroy;
begin
  FreeAndNil(FChildren);
  FreeAndNil(FCells);
  inherited Destroy;
end;

function TNXTreeViewNode.AddChild(const AText: string; AData: Pointer): TNXTreeViewNode;
begin
  Result := TNXTreeViewNode.Create(AText, AData);
  Result.FParent := Self;
  FChildren.Add(Result);
end;

procedure TNXTreeViewNode.Clear;
begin
  FChildren.Clear;
end;

procedure TNXTreeViewNode.ClearCells;
begin
  FCells.Clear;
end;

function TNXTreeViewNode.Contains(ANode: TNXTreeViewNode): Boolean;
var
  lIndex: Integer;
begin
  Result := False;
  if ANode = Self then
  begin
    Result := True;
    Exit;
  end;

  for lIndex := 0 to ChildCount - 1 do
  begin
    if Child[lIndex].Contains(ANode) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TNXTreeViewNode.EnsureCellCount(ACount: Integer);
begin
  while FCells.Count < ACount do
    FCells.Add(TNXTreeViewCell.Create);
end;

function TNXTreeViewNode.GetCell(AIndex: Integer): TNXTreeViewCell;
begin
  EnsureCellCount(AIndex + 1);
  Result := FCells[AIndex];
end;

function TNXTreeViewNode.GetCellCount: Integer;
begin
  Result := FCells.Count;
end;

function TNXTreeViewNode.GetChild(AIndex: Integer): TNXTreeViewNode;
begin
  Result := FChildren[AIndex];
end;

function TNXTreeViewNode.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TNXTreeViewNode.GetLevel: Integer;
var
  lNode: TNXTreeViewNode;
begin
  Result := 0;
  lNode := FParent;
  while lNode <> nil do
  begin
    Inc(Result);
    lNode := lNode.Parent;
  end;
end;

function TNXTreeViewNode.GetText: string;
begin
  Result := Cell[0].Text;
end;

function TNXTreeViewNode.HasChildren: Boolean;
begin
  Result := FChildren.Count > 0;
end;

procedure TNXTreeViewNode.SetText(const AValue: string);
begin
  Cell[0].Text := AValue;
end;

function TNXTreeViewRootList.AddNode(const AText: string; AData: Pointer): TNXTreeViewNode;
begin
  Result := TNXTreeViewNode.Create(AText, AData);
  Add(Result);
end;

function TNXTreeViewColumnList.AddColumn(const ACaption: string; AWidth: Integer): TNXTreeViewColumn;
begin
  Result := TNXTreeViewColumn.Create(ACaption, AWidth);
  Add(Result);
end;

constructor TNXTreeView.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  BorderStyle := BS_Single;
  CanFocus := True;
  FColumns := TNXTreeViewColumnList.Create(True);
  FDefaultColumnWidth := cDefaultColumnWidth;
  FHeaderHeight := cDefaultHeaderHeight;
  FIndentWidth := cDefaultIndentWidth;
  FLineHeight := cDefaultLineHeight;
  FRootNodes := TNXTreeViewRootList.Create(True);
  FSelectedColumn := -1;
  FSelectedNode := nil;
  FShowColumnHeaders := True;
  FShowGridLines := True;
  FVisibleNodes := TNXTreeViewVisibleNodeList.Create;
  FColumns.AddColumn('Name', FDefaultColumnWidth);
  UpdateContentSize;
end;

destructor TNXTreeView.Destroy;
begin
  FreeAndNil(FVisibleNodes);
  FreeAndNil(FRootNodes);
  FreeAndNil(FColumns);
  inherited Destroy;
end;

function TNXTreeView.AddChildNode(AParentNode: TNXTreeViewNode; const AText: string; AData: Pointer): TNXTreeViewNode;
begin
  if Assigned(AParentNode) then
    Result := AParentNode.AddChild(AText, AData)
  else
    Result := FRootNodes.AddNode(AText, AData);

  Result.EnsureCellCount(Max(1, FColumns.Count));
  RebuildVisibleNodes;
  UpdateContentSize;
end;

function TNXTreeView.AddColumn(const ACaption: string; AWidth: Integer): TNXTreeViewColumn;
var
  lWidth: Integer;
begin
  if AWidth <= 0 then
    lWidth := FDefaultColumnWidth
  else
    lWidth := AWidth;

  Result := FColumns.AddColumn(ACaption, lWidth);
  UpdateContentSize;
end;

function TNXTreeView.AddNode(const AText: string; AData: Pointer): TNXTreeViewNode;
begin
  Result := AddChildNode(nil, AText, AData);
end;

procedure TNXTreeView.AddVisibleNodes(ANodes: TNXTreeViewNodeListBase);
var
  lIndex: Integer;
  lNode: TNXTreeViewNode;
begin
  for lIndex := 0 to ANodes.Count - 1 do
  begin
    lNode := ANodes[lIndex];
    FVisibleNodes.Add(lNode);
    if lNode.Expanded then
      AddVisibleNodes(lNode.FChildren);
  end;
end;

procedure TNXTreeView.Clear;
begin
  FSelectedColumn := -1;
  FSelectedNode := nil;
  FRootNodes.Clear;
  FVisibleNodes.Clear;
  UpdateContentSize;
end;

procedure TNXTreeView.ClearColumns;
begin
  FColumns.Clear;
  FSelectedColumn := -1;
  UpdateContentSize;
end;

procedure TNXTreeView.CollapseAll;
var
  lIndex: Integer;

  procedure CollapseChildren(ANode: TNXTreeViewNode);
  var
    lChildIndex: Integer;
  begin
    ANode.Expanded := False;
    for lChildIndex := 0 to ANode.ChildCount - 1 do
      CollapseChildren(ANode.Child[lChildIndex]);
  end;

begin
  for lIndex := 0 to FRootNodes.Count - 1 do
    CollapseChildren(FRootNodes[lIndex]);

  RebuildVisibleNodes;
  EnsureSelectedVisible;
  UpdateContentSize;
end;

procedure TNXTreeView.ExpandAll;
var
  lIndex: Integer;

  procedure ExpandChildren(ANode: TNXTreeViewNode);
  var
    lChildIndex: Integer;
  begin
    if ANode.HasChildren then
      ANode.Expanded := True;
    for lChildIndex := 0 to ANode.ChildCount - 1 do
      ExpandChildren(ANode.Child[lChildIndex]);
  end;

begin
  for lIndex := 0 to FRootNodes.Count - 1 do
    ExpandChildren(FRootNodes[lIndex]);

  RebuildVisibleNodes;
  EnsureSelectedVisible;
  UpdateContentSize;
end;

function TNXTreeView.GetTotalColumnWidth: Integer;
var
  lIndex: Integer;
begin
  Result := 0;
  for lIndex := 0 to FColumns.Count - 1 do
    if FColumns[lIndex].Visible then
      Inc(Result, FColumns[lIndex].Width);
end;

procedure TNXTreeView.SetHeaderHeight(AValue: Integer);
begin
  FHeaderHeight := Max(0, AValue);
  UpdateContentSize;
end;

procedure TNXTreeView.SetIndentWidth(AValue: Integer);
begin
  FIndentWidth := Max(4, AValue);
  UpdateContentSize;
end;

procedure TNXTreeView.SetLineHeight(AValue: Integer);
begin
  FLineHeight := Max(8, AValue);
  UpdateContentSize;
end;

procedure TNXTreeView.SetSelectedNode(AValue: TNXTreeViewNode);
begin
  SelectNode(AValue, FSelectedColumn);
end;

procedure TNXTreeView.SetShowColumnHeaders(AValue: Boolean);
begin
  if FShowColumnHeaders = AValue then
    Exit;

  FShowColumnHeaders := AValue;
  UpdateContentSize;
end;

function TNXTreeView.CellAt(AX, AY: Integer; out AColumn: Integer; out ANode: TNXTreeViewNode): Boolean;
var
  lContentY: Integer;
  lRow: Integer;
  lViewportRect: TNXRect;
begin
  Result := False;
  AColumn := -1;
  ANode := nil;

  lViewportRect := ViewportRect;
  if (AX < lViewportRect.x) or (AX >= lViewportRect.x + lViewportRect.w) or
    (AY < lViewportRect.y) or (AY >= lViewportRect.y + lViewportRect.h) then
    Exit;

  if FShowColumnHeaders and (AY < lViewportRect.y + FHeaderHeight) then
    Exit;

  if not ColumnAt(AX, AY, AColumn) then
    Exit;

  lContentY := AY - lViewportRect.y - GetContentTop + ScrollY;
  if FLineHeight <= 0 then
    Exit;

  lRow := lContentY div FLineHeight;
  if (lRow < 0) or (lRow >= FVisibleNodes.Count) then
    Exit;

  ANode := FVisibleNodes[lRow];
  Result := Assigned(ANode);
end;

function TNXTreeView.CellRect(AColumn, AVisibleIndex: Integer): TNXRect;
begin
  Result.x := ViewportRect.x + ColumnLeft(AColumn) - ScrollX;
  Result.y := ViewportRect.y + GetContentTop + (AVisibleIndex * FLineHeight) - ScrollY;
  Result.w := FColumns[AColumn].Width;
  Result.h := FLineHeight;
end;

procedure TNXTreeView.CollapseNode(ANode: TNXTreeViewNode);
begin
  if not Assigned(ANode) then
    Exit;

  if not ANode.Expanded then
    Exit;

  ANode.Expanded := False;
  if ANode.Contains(FSelectedNode) and (ANode <> FSelectedNode) then
    SelectNode(ANode, FSelectedColumn);

  RebuildVisibleNodes;
  EnsureSelectedVisible;
  UpdateContentSize;

  if Assigned(FOnCollapsed) then
    FOnCollapsed(Self, ANode);
end;

function TNXTreeView.ColumnAt(AX, AY: Integer; out AColumn: Integer): Boolean;
var
  lContentX: Integer;
  lIndex: Integer;
  lLeft: Integer;
  lViewportRect: TNXRect;
begin
  Result := False;
  AColumn := -1;
  lViewportRect := ViewportRect;
  if (AX < lViewportRect.x) or (AX >= lViewportRect.x + lViewportRect.w) or
    (AY < lViewportRect.y) or (AY >= lViewportRect.y + lViewportRect.h) then
    Exit;

  lContentX := AX - lViewportRect.x + ScrollX;
  lLeft := 0;
  for lIndex := 0 to FColumns.Count - 1 do
  begin
    if not FColumns[lIndex].Visible then
      Continue;

    if (lContentX >= lLeft) and (lContentX < lLeft + FColumns[lIndex].Width) then
    begin
      AColumn := lIndex;
      Result := True;
      Exit;
    end;
    Inc(lLeft, FColumns[lIndex].Width);
  end;
end;

function TNXTreeView.ColumnLeft(AColumn: Integer): Integer;
var
  lIndex: Integer;
begin
  Result := 0;
  for lIndex := 0 to AColumn - 1 do
    if FColumns[lIndex].Visible then
      Inc(Result, FColumns[lIndex].Width);
end;

procedure TNXTreeView.DoCellActivate(ANode: TNXTreeViewNode; AColumn: Integer);
begin
  if Assigned(FOnCellActivate) then
    FOnCellActivate(Self, ANode, AColumn);
end;

procedure TNXTreeView.DoCellClick(ANode: TNXTreeViewNode; AColumn: Integer);
begin
  if Assigned(FOnCellClick) then
    FOnCellClick(Self, ANode, AColumn);
end;

procedure TNXTreeView.DoColumnClick(AColumn: Integer);
begin
  if Assigned(FOnColumnClick) then
    FOnColumnClick(Self, AColumn);
end;

procedure TNXTreeView.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
  lNode: TNXTreeViewNode;
begin
  inherited DoKeyDown(AEvent);

  RebuildVisibleNodes;
  lIndex := FVisibleNodes.IndexOf(FSelectedNode);

  case AEvent.Key of
    nkUp:
      if lIndex > 0 then
        SelectNode(FVisibleNodes[lIndex - 1], FSelectedColumn);

    nkDown:
      if (lIndex >= 0) and (lIndex < FVisibleNodes.Count - 1) then
        SelectNode(FVisibleNodes[lIndex + 1], FSelectedColumn)
      else if (lIndex < 0) and (FVisibleNodes.Count > 0) then
        SelectNode(FVisibleNodes[0], 0);

    nkHome:
      if FVisibleNodes.Count > 0 then
        SelectNode(FVisibleNodes[0], FSelectedColumn);

    nkEnd:
      if FVisibleNodes.Count > 0 then
        SelectNode(FVisibleNodes[FVisibleNodes.Count - 1], FSelectedColumn);

    nkLeft:
    begin
      lNode := FSelectedNode;
      if Assigned(lNode) then
      begin
        if lNode.Expanded then
          CollapseNode(lNode)
        else if Assigned(lNode.Parent) then
          SelectNode(lNode.Parent, FSelectedColumn);
      end;
    end;

    nkRight:
    begin
      lNode := FSelectedNode;
      if Assigned(lNode) then
      begin
        if lNode.HasChildren and not lNode.Expanded then
          ExpandNode(lNode)
        else if lNode.HasChildren then
          SelectNode(lNode.Child[0], FSelectedColumn);
      end;
    end;

    nkEnter:
      if Assigned(FSelectedNode) then
        DoCellActivate(FSelectedNode, Max(0, FSelectedColumn));
  end;
end;

procedure TNXTreeView.DoMouseDoubleClick(AX, AY: Integer; AButton: TNXMouseButton);
var
  lColumn: Integer;
  lNode: TNXTreeViewNode;
begin
  inherited DoMouseDoubleClick(AX, AY, AButton);
  if AButton <> mbLeft then
    Exit;

  if CellAt(AX, AY, lColumn, lNode) then
    DoCellActivate(lNode, lColumn);
end;

procedure TNXTreeView.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
var
  lCellRect: TNXRect;
  lColumn: Integer;
  lGlyphRect: TNXRect;
  lNode: TNXTreeViewNode;
  lVisibleIndex: Integer;
begin
  inherited DoMouseDown(AX, AY, AButton);
  if AButton <> mbLeft then
    Exit;

  if FShowColumnHeaders and (AY >= ViewportRect.y) and
    (AY < ViewportRect.y + FHeaderHeight) then
  begin
    if ColumnAt(AX, AY, lColumn) then
      DoColumnClick(lColumn);
    Exit;
  end;

  if not CellAt(AX, AY, lColumn, lNode) then
    Exit;

  SelectNode(lNode, lColumn);
  DoCellClick(lNode, lColumn);

  if lColumn <> 0 then
    Exit;

  lVisibleIndex := FVisibleNodes.IndexOf(lNode);
  if lVisibleIndex < 0 then
    Exit;

  lCellRect := CellRect(0, lVisibleIndex);
  lGlyphRect := GetNodeGlyphRect(lNode, lVisibleIndex, lCellRect);
  if (AX >= lGlyphRect.x) and (AX < lGlyphRect.x + lGlyphRect.w) and
    (AY >= lGlyphRect.y) and (AY < lGlyphRect.y + lGlyphRect.h) then
    ToggleNode(lNode);
end;

procedure TNXTreeView.DrawCell(ANode: TNXTreeViewNode; AColumn, AVisibleIndex: Integer; const ARect: TNXRect);
var
  lCell: TNXTreeViewCell;
  lSelected: Boolean;
begin
  lCell := ANode.Cell[AColumn];
  lSelected := ANode = FSelectedNode;

  if lSelected then
  begin
    if IsFocused then
      RenderFilledRect(ARect, Skin.SelectedColor)
    else
      RenderFilledRect(ARect, Skin.TextBackColor);
  end
  else if lCell.UseBackColor then
    RenderFilledRect(ARect, lCell.BackColor)
  else
    RenderFilledRect(ARect, Skin.TextBackColor);

  DrawCellContent(ANode, AColumn, ARect);

  if FShowGridLines then
  begin
    RenderLine(ARect.x, ARect.y + ARect.h - 1,
      ARect.x + ARect.w, ARect.y + ARect.h - 1, Skin.BorderColor);
    RenderLine(ARect.x + ARect.w - 1, ARect.y,
      ARect.x + ARect.w - 1, ARect.y + ARect.h, Skin.BorderColor);
  end;
end;

procedure TNXTreeView.DrawCellContent(ANode: TNXTreeViewNode; AColumn: Integer; const ARect: TNXRect);
var
  lCell: TNXTreeViewCell;
  lContentRect: TNXRect;
  lColor: TNXColor;
  lGlyphRect: TNXRect;
  lImageHeight: Integer;
  lImageRect: TNXRect;
  lImageWidth: Integer;
  lTextRect: TNXRect;
begin
  lCell := ANode.Cell[AColumn];
  lContentRect := ARect;
  Inc(lContentRect.x, cCellPaddingX);
  Dec(lContentRect.w, cCellPaddingX * 2);

  if AColumn = 0 then
  begin
    lGlyphRect := GetNodeGlyphRect(ANode, FVisibleNodes.IndexOf(ANode), ARect);
    DrawExpandGlyph(ANode, lGlyphRect);
    lContentRect.x := lGlyphRect.x + lGlyphRect.w + cCellPaddingX;
    lContentRect.w := Max(0, ARect.x + ARect.w - lContentRect.x - cCellPaddingX);
  end;

  if lCell.GlyphKind <> tvgkNone then
  begin
    lGlyphRect := MakeNXRect(lContentRect.x,
      lContentRect.y + Max(0, (lContentRect.h - cStatusGlyphSize) div 2),
      cStatusGlyphSize, cStatusGlyphSize);
    DrawStatusGlyph(lCell, lGlyphRect);
    Inc(lContentRect.x, cStatusGlyphSize + cCellPaddingX);
    Dec(lContentRect.w, cStatusGlyphSize + cCellPaddingX);
  end;

  if Assigned(lCell.Image) then
  begin
    lImageWidth := lCell.ImageWidth;
    lImageHeight := lCell.ImageHeight;
    if (lImageWidth <= 0) or (lImageHeight <= 0) then
      Canvas.GetImageSize(lCell.Image, lImageWidth, lImageHeight);

    if (lImageWidth > 0) and (lImageHeight > 0) then
    begin
      lImageRect := MakeNXRect(lContentRect.x,
        lContentRect.y + Max(0, (lContentRect.h - lImageHeight) div 2),
        lImageWidth, lImageHeight);
      Canvas.DrawImage(lCell.Image, LocalRectToAbs(lImageRect));
      Inc(lContentRect.x, lImageWidth + cCellPaddingX);
      Dec(lContentRect.w, lImageWidth + cCellPaddingX);
    end;
  end;

  if lCell.Text = '' then
    Exit;

  if lCell.UseForeColor then
    lColor := lCell.ForeColor
  else
    lColor := ForeColor;

  lTextRect := lContentRect;
  if lTextRect.w <= 0 then
    Exit;

  DrawCellText(lCell.Text, lTextRect, lCell.Align, lColor);
end;

procedure TNXTreeView.DrawCellText(const AText: string; const ARect: TNXRect; AAlign: TNXTreeViewCellAlign; const AColor: TNXColor);
var
  lFont: TNXFont;
  lTextWidth: Integer;
  lTextX: Integer;
  lTextY: Integer;
  lClipRect: TNXRect;
begin
  if AText = '' then
    Exit;

  lFont := Font;
  if not Assigned(lFont) then
    Exit;

  lTextWidth := Canvas.TextWidth(AText, lFont);
  case AAlign of
    tvcaCenter:
      lTextX := ARect.x + (ARect.w div 2) - (lTextWidth div 2);
    tvcaRight:
      lTextX := ARect.x + ARect.w - lTextWidth - cCellPaddingX;
  else
    lTextX := ARect.x;
  end;

  lTextY := ARect.y + Max(0, (ARect.h - FontHeight) div 2);
  lClipRect := LocalRectToAbs(ARect);
  Canvas.PushClip(lClipRect);
  try
    Canvas.DrawText(AText, AbsLeft + lTextX, AbsTop + lTextY, AColor, lFont);
  finally
    Canvas.PopClip;
  end;
end;

procedure TNXTreeView.DrawExpandGlyph(ANode: TNXTreeViewNode; const ARect: TNXRect);
var
  lCenterX: Integer;
  lCenterY: Integer;
begin
  if not Assigned(ANode) or not ANode.HasChildren then
    Exit;

  RenderRect(ARect, ForeColor);
  lCenterX := ARect.x + ARect.w div 2;
  lCenterY := ARect.y + ARect.h div 2;

  RenderLine(ARect.x + 2, lCenterY, ARect.x + ARect.w - 3, lCenterY, ForeColor);
  if not ANode.Expanded then
    RenderLine(lCenterX, ARect.y + 2, lCenterX, ARect.y + ARect.h - 3, ForeColor);
end;

procedure TNXTreeView.DrawHeader(AColumn: Integer; const ARect: TNXRect);
begin
  RenderFilledRect(ARect, Skin.BackColor);
  DrawCellText(FColumns[AColumn].Caption, ARect, FColumns[AColumn].Align, ForeColor);

  if FShowGridLines then
  begin
    RenderLine(ARect.x, ARect.y + ARect.h - 1,
      ARect.x + ARect.w, ARect.y + ARect.h - 1, Skin.BorderColor);
    RenderLine(ARect.x + ARect.w - 1, ARect.y,
      ARect.x + ARect.w - 1, ARect.y + ARect.h, Skin.BorderColor);
  end;
end;

procedure TNXTreeView.DrawStatusGlyph(const ACell: TNXTreeViewCell; const ARect: TNXRect);
var
  lColor: TNXColor;
begin
  if ACell.UseGlyphColor then
    lColor := ACell.GlyphColor
  else
    lColor := ForeColor;

  case ACell.GlyphKind of
    tvgkCircle:
      Canvas.FillCircle(AbsLeft + ARect.x + (ARect.w div 2),
        AbsTop + ARect.y + (ARect.h div 2), Min(ARect.w, ARect.h) div 2,
        lColor);
    tvgkSquare:
      RenderFilledRect(ARect, lColor);
  end;
end;

procedure TNXTreeView.EnsureSelectedVisible;
var
  lIndex: Integer;
  lLineBottom: Integer;
  lLineTop: Integer;
  lVisibleHeight: Integer;
begin
  if not Assigned(FSelectedNode) then
    Exit;

  RebuildVisibleNodes;
  lIndex := FVisibleNodes.IndexOf(FSelectedNode);
  if lIndex < 0 then
    Exit;

  lVisibleHeight := Max(0, ViewportHeight - GetContentTop);
  lLineTop := lIndex * FLineHeight;
  lLineBottom := lLineTop + FLineHeight;

  if lLineTop < ScrollY then
    ScrollY := lLineTop
  else if lLineBottom > ScrollY + lVisibleHeight then
    ScrollY := lLineBottom - lVisibleHeight;
end;

procedure TNXTreeView.ExpandNode(ANode: TNXTreeViewNode);
begin
  if not Assigned(ANode) then
    Exit;

  if not ANode.HasChildren then
    Exit;

  if ANode.Expanded then
    Exit;

  ANode.Expanded := True;
  RebuildVisibleNodes;
  EnsureSelectedVisible;
  UpdateContentSize;

  if Assigned(FOnExpanded) then
    FOnExpanded(Self, ANode);
end;

function TNXTreeView.GetContentTop: Integer;
begin
  if FShowColumnHeaders then
    Result := FHeaderHeight
  else
    Result := 0;
end;

function TNXTreeView.GetDefaultLineHeight: Integer;
begin
  if FontLineSkip > 0 then
    Result := Max(cDefaultLineHeight, FontLineSkip + 4)
  else
    Result := cDefaultLineHeight;
end;

function TNXTreeView.GetHeaderRect(AColumn: Integer): TNXRect;
begin
  Result.x := ViewportRect.x + ColumnLeft(AColumn) - ScrollX;
  Result.y := ViewportRect.y;
  Result.w := FColumns[AColumn].Width;
  Result.h := FHeaderHeight;
end;

function TNXTreeView.GetNodeGlyphRect(ANode: TNXTreeViewNode; AVisibleIndex: Integer; const ACellRect: TNXRect): TNXRect;
begin
  Result := MakeNXRect(ACellRect.x + cCellPaddingX + (ANode.Level * FIndentWidth),
    ACellRect.y + Max(0, (ACellRect.h - cGlyphSize) div 2), cGlyphSize,
    cGlyphSize);
end;

procedure TNXTreeView.NodeChanged(ANode: TNXTreeViewNode);
begin
  RebuildVisibleNodes;
  EnsureSelectedVisible;
  UpdateContentSize;
end;

procedure TNXTreeView.RebuildVisibleNodes;
begin
  FVisibleNodes.Clear;
  AddVisibleNodes(FRootNodes);
end;

procedure TNXTreeView.RenderViewport;
var
  lColumn: Integer;
  lFirstLine: Integer;
  lLastLine: Integer;
  lLine: Integer;
  lRect: TNXRect;
  lViewportBottom: Integer;
  lViewportRight: Integer;
begin
  RebuildVisibleNodes;
  UpdateContentSize;

  lViewportRight := ViewportRect.x + ViewportWidth;
  lViewportBottom := ViewportRect.y + ViewportHeight;

  if FShowColumnHeaders then
    for lColumn := 0 to FColumns.Count - 1 do
    begin
      if not FColumns[lColumn].Visible then
        Continue;

      lRect := GetHeaderRect(lColumn);
      if (lRect.x + lRect.w <= ViewportRect.x) or (lRect.x >= lViewportRight) then
        Continue;
      DrawHeader(lColumn, lRect);
    end;

  if FLineHeight <= 0 then
    Exit;

  lFirstLine := Max(0, ScrollY div FLineHeight);
  lLastLine := Min(FVisibleNodes.Count - 1,
    (ScrollY + ViewportHeight - GetContentTop) div FLineHeight + 1);

  for lLine := lFirstLine to lLastLine do
    for lColumn := 0 to FColumns.Count - 1 do
    begin
      if not FColumns[lColumn].Visible then
        Continue;

      lRect := CellRect(lColumn, lLine);
      if (lRect.x + lRect.w <= ViewportRect.x) or
        (lRect.x >= lViewportRight) or
        (lRect.y + lRect.h <= ViewportRect.y + GetContentTop) or
        (lRect.y >= lViewportBottom) then
        Continue;
      DrawCell(FVisibleNodes[lLine], lColumn, lLine, lRect);
    end;
end;

procedure TNXTreeView.SelectNode(ANode: TNXTreeViewNode; AColumn: Integer);
begin
  if (FSelectedNode = ANode) and (FSelectedColumn = AColumn) then
    Exit;

  if Assigned(FSelectedNode) then
    FSelectedNode.Selected := False;

  FSelectedNode := ANode;
  FSelectedColumn := AColumn;

  if Assigned(FSelectedNode) then
    FSelectedNode.Selected := True;

  EnsureSelectedVisible;

  if Assigned(FOnChange) then
    FOnChange(Self, FSelectedNode);
end;

procedure TNXTreeView.ToggleNode(ANode: TNXTreeViewNode);
begin
  if not Assigned(ANode) then
    Exit;

  if ANode.Expanded then
    CollapseNode(ANode)
  else
    ExpandNode(ANode);
end;

procedure TNXTreeView.UpdateContentSize;
var
  lLineHeight: Integer;
begin
  if FLineHeight <= 0 then
  begin
    lLineHeight := GetDefaultLineHeight;
    if lLineHeight > 0 then
      FLineHeight := lLineHeight;
  end;

  RebuildVisibleNodes;
  ContentWidth := GetTotalColumnWidth;
  ContentHeight := GetContentTop + (FVisibleNodes.Count * FLineHeight);
end;

end.
