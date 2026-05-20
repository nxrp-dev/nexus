unit obNXTreeList;

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

  obNXScrollBar;

type
  TNXTreeListNode = class;
  TNXTreeListNodeListBase = specialize TFPGObjectList<TNXTreeListNode>;
  TNXTreeListVisibleNodeListBase = specialize TFPGList<TNXTreeListNode>;

  TNXTreeListNode = class
  private
    FCaption: string;
    FChildren: TNXTreeListNodeListBase;
    FData: Pointer;
    FExpanded: Boolean;
    FParent: TNXTreeListNode;
    FSelected: Boolean;

    function GetChildCount: Integer;
    function GetChild(AIndex: Integer): TNXTreeListNode;
    function GetLevel: Integer;
    procedure SetExpanded(AValue: Boolean);
  public
    constructor Create(const ACaption: string; AData: Pointer = nil); virtual;
    destructor Destroy; override;

    function AddChild(const ACaption: string; AData: Pointer = nil): TNXTreeListNode; virtual;
    procedure Clear; virtual;
    function Contains(ANode: TNXTreeListNode): Boolean; virtual;
    function HasChildren: Boolean; virtual;

    property Caption: string read FCaption write FCaption;
    property Child[AIndex: Integer]: TNXTreeListNode read GetChild;
    property ChildCount: Integer read GetChildCount;
    property Data: Pointer read FData write FData;
    property Expanded: Boolean read FExpanded write SetExpanded;
    property Level: Integer read GetLevel;
    property Parent: TNXTreeListNode read FParent;
    property Selected: Boolean read FSelected write FSelected;
  end;

  TNXTreeListRootList = class(TNXTreeListNodeListBase)
  public
    function AddNode(const ACaption: string; AData: Pointer = nil): TNXTreeListNode;
  end;

  TNXTreeListVisibleNodeList = class(TNXTreeListVisibleNodeListBase)
  end;

  TNXTreeListNodeEvent = procedure(Sender: TObject; ANode: TNXTreeListNode) of object;

  TNXTreeList = class(TNXControl)
  private
    FIndentWidth: Integer;
    FOnChange: TNXTreeListNodeEvent;
    FOnCollapsed: TNXTreeListNodeEvent;
    FOnExpanded: TNXTreeListNodeEvent;
    FRootNodes: TNXTreeListRootList;
    FScrollbar: TNXScrollBar;
    FSelectedNode: TNXTreeListNode;
    FVisibleNodes: TNXTreeListVisibleNodeList;

    function GetItemHeight: Integer;
    function GetVisibleItemCount: Integer;
    procedure SetIndentWidth(AValue: Integer);
    procedure SetSelectedNode(AValue: TNXTreeListNode);
  protected
    procedure AddVisibleNodes(ANodes: TNXTreeListNodeListBase); virtual;
    procedure CollapseNode(ANode: TNXTreeListNode); virtual;
    procedure DrawExpandGlyph(ANode: TNXTreeListNode; const ARect: TNXRect); virtual;
    procedure DrawNode(ANode: TNXTreeListNode; ADrawIndex: Integer); virtual;
    procedure EnsureSelectedVisible; virtual;
    procedure ExpandNode(ANode: TNXTreeListNode); virtual;
    function GetNodeAtY(AY: Integer): TNXTreeListNode; virtual;
    function GetNodeGlyphRect(ANode: TNXTreeListNode; ADrawIndex: Integer): TNXRect; virtual;
    function GetNodeTextX(ANode: TNXTreeListNode): Integer; virtual;
    procedure RebuildVisibleNodes; virtual;
    procedure SelectNode(ANode: TNXTreeListNode); virtual;
    procedure ToggleNode(ANode: TNXTreeListNode); virtual;
    procedure UpdateScrollBar; virtual;

    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDoubleClick(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure RenderClient; override;
  public
    constructor Create(const AParent: INXControlParent); override;
    destructor Destroy; override;

    function AddChildNode(AParentNode: TNXTreeListNode; const ACaption: string; AData: Pointer = nil): TNXTreeListNode; virtual;
    function AddNode(const ACaption: string; AData: Pointer = nil): TNXTreeListNode; virtual;
    procedure Clear; virtual;
    procedure CollapseAll; virtual;
    procedure ExpandAll; virtual;
    procedure NodeChanged(ANode: TNXTreeListNode); virtual;

    property IndentWidth: Integer read FIndentWidth write SetIndentWidth;
    property OnChange: TNXTreeListNodeEvent read FOnChange write FOnChange;
    property OnCollapsed: TNXTreeListNodeEvent read FOnCollapsed write FOnCollapsed;
    property OnExpanded: TNXTreeListNodeEvent read FOnExpanded write FOnExpanded;
    property RootNodes: TNXTreeListRootList read FRootNodes;
    property SelectedNode: TNXTreeListNode read FSelectedNode write SetSelectedNode;
  end;

implementation

const
  cDefaultIndentWidth = 18;
  cGlyphSize = 9;
  cTextPadding = 4;

constructor TNXTreeListNode.Create(const ACaption: string; AData: Pointer);
begin
  inherited Create;
  FCaption := ACaption;
  FData := AData;
  FChildren := TNXTreeListNodeListBase.Create(True);
  FExpanded := False;
  FParent := nil;
  FSelected := False;
end;

destructor TNXTreeListNode.Destroy;
begin
  FreeAndNil(FChildren);
  inherited Destroy;
end;

function TNXTreeListNode.AddChild(const ACaption: string; AData: Pointer): TNXTreeListNode;
begin
  Result := TNXTreeListNode.Create(ACaption, AData);
  Result.FParent := Self;
  FChildren.Add(Result);
end;

procedure TNXTreeListNode.Clear;
begin
  FChildren.Clear;
end;

function TNXTreeListNode.Contains(ANode: TNXTreeListNode): Boolean;
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

function TNXTreeListNode.GetChild(AIndex: Integer): TNXTreeListNode;
begin
  Result := FChildren[AIndex];
end;

function TNXTreeListNode.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TNXTreeListNode.GetLevel: Integer;
var
  lNode: TNXTreeListNode;
begin
  Result := 0;
  lNode := FParent;
  while lNode <> nil do
  begin
    Inc(Result);
    lNode := lNode.Parent;
  end;
end;

function TNXTreeListNode.HasChildren: Boolean;
begin
  Result := FChildren.Count > 0;
end;

procedure TNXTreeListNode.SetExpanded(AValue: Boolean);
begin
  if FExpanded = AValue then
    Exit;

  FExpanded := AValue;
end;

function TNXTreeListRootList.AddNode(const ACaption: string; AData: Pointer): TNXTreeListNode;
begin
  Result := TNXTreeListNode.Create(ACaption, AData);
  Add(Result);
end;

constructor TNXTreeList.Create(const AParent: INXControlParent);
begin
  inherited Create(nil);
  BorderStyle := BS_Single;
  FillStyle := FS_Filled;
  Selectable := True;
  FIndentWidth := cDefaultIndentWidth;
  FRootNodes := TNXTreeListRootList.Create(True);
  FVisibleNodes := TNXTreeListVisibleNodeList.Create;
  FSelectedNode := nil;
  FScrollbar := TNXScrollBar.Create(Self);
  with FScrollbar do
  begin
    Min := 0;
    Max := 0;
    Value := 0;
    Dir := Dir_Vertical;
    AutoAlign := True;
    Visible := False;
  end;
  AttachToParent(AParent);
end;

destructor TNXTreeList.Destroy;
begin
  FreeAndNil(FVisibleNodes);
  FreeAndNil(FRootNodes);
  inherited Destroy;
end;

function TNXTreeList.AddChildNode(AParentNode: TNXTreeListNode; const ACaption: string; AData: Pointer): TNXTreeListNode;
begin
  if Assigned(AParentNode) then
    Result := AParentNode.AddChild(ACaption, AData)
  else
    Result := FRootNodes.AddNode(ACaption, AData);

  RebuildVisibleNodes;
  UpdateScrollBar;
end;

function TNXTreeList.AddNode(const ACaption: string; AData: Pointer): TNXTreeListNode;
begin
  Result := AddChildNode(nil, ACaption, AData);
end;

procedure TNXTreeList.AddVisibleNodes(ANodes: TNXTreeListNodeListBase);
var
  lIndex: Integer;
  lNode: TNXTreeListNode;
begin
  for lIndex := 0 to ANodes.Count - 1 do
  begin
    lNode := ANodes[lIndex];
    FVisibleNodes.Add(lNode);
    if lNode.Expanded then
      AddVisibleNodes(lNode.FChildren);
  end;
end;

procedure TNXTreeList.Clear;
begin
  FSelectedNode := nil;
  FRootNodes.Clear;
  FVisibleNodes.Clear;
  UpdateScrollBar;
end;

procedure TNXTreeList.CollapseAll;
var
  lIndex: Integer;

  procedure CollapseChildren(ANode: TNXTreeListNode);
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
  UpdateScrollBar;
end;

procedure TNXTreeList.ExpandAll;
var
  lIndex: Integer;

  procedure ExpandChildren(ANode: TNXTreeListNode);
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
  UpdateScrollBar;
end;

procedure TNXTreeList.CollapseNode(ANode: TNXTreeListNode);
begin
  if not Assigned(ANode) then
    Exit;

  if not ANode.Expanded then
    Exit;

  ANode.Expanded := False;
  if ANode.Contains(FSelectedNode) and (ANode <> FSelectedNode) then
    SelectNode(ANode);
  RebuildVisibleNodes;
  EnsureSelectedVisible;
  UpdateScrollBar;

  if Assigned(FOnCollapsed) then
    FOnCollapsed(Self, ANode);
end;

procedure TNXTreeList.ExpandNode(ANode: TNXTreeListNode);
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
  UpdateScrollBar;

  if Assigned(FOnExpanded) then
    FOnExpanded(Self, ANode);
end;

function TNXTreeList.GetItemHeight: Integer;
begin
  if FontLineSkip > 0 then
    Result := FontLineSkip
  else
    Result := Max(1, GUI_TitleBarHeight);
end;

function TNXTreeList.GetVisibleItemCount: Integer;
var
  lItemHeight: Integer;
begin
  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Result := 0
  else
    Result := Max(0, ContentRect.h div lItemHeight);
end;

function TNXTreeList.GetNodeAtY(AY: Integer): TNXTreeListNode;
var
  lIndex: Integer;
  lItemHeight: Integer;
begin
  Result := nil;
  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Exit;

  lIndex := FScrollbar.Value + (AY div lItemHeight);
  if (lIndex >= 0) and (lIndex < FVisibleNodes.Count) then
    Result := FVisibleNodes[lIndex];
end;

function TNXTreeList.GetNodeGlyphRect(ANode: TNXTreeListNode; ADrawIndex: Integer): TNXRect;
var
  lItemHeight: Integer;
  lLeft: Integer;
  lTop: Integer;
begin
  lItemHeight := GetItemHeight;
  lLeft := GetBorderThickness + (ANode.Level * FIndentWidth) + cTextPadding;
  lTop := GetBorderThickness + (ADrawIndex * lItemHeight) +
    ((lItemHeight - cGlyphSize) div 2);
  Result := MakeNXRect(lLeft, lTop, cGlyphSize, cGlyphSize);
end;

function TNXTreeList.GetNodeTextX(ANode: TNXTreeListNode): Integer;
begin
  Result := cTextPadding + (ANode.Level * FIndentWidth) + cGlyphSize + cTextPadding;
end;

procedure TNXTreeList.DrawExpandGlyph(ANode: TNXTreeListNode; const ARect: TNXRect);
var
  lCenterX: Integer;
  lCenterY: Integer;
begin
  if not ANode.HasChildren then
    Exit;

  RenderRect(ARect, ForeColor);
  lCenterX := ARect.x + ARect.w div 2;
  lCenterY := ARect.y + ARect.h div 2;

  RenderLine(ARect.x + 2, lCenterY, ARect.x + ARect.w - 3, lCenterY, ForeColor);
  if not ANode.Expanded then
    RenderLine(lCenterX, ARect.y + 2, lCenterX, ARect.y + ARect.h - 3, ForeColor);
end;

procedure TNXTreeList.DrawNode(ANode: TNXTreeListNode; ADrawIndex: Integer);
var
  lGlyphRect: TNXRect;
  lItemHeight: Integer;
  lNodeRect: TNXRect;
  lTextClip: TNXRect;
begin
  if not Assigned(ANode) then
    Exit;

  lItemHeight := GetItemHeight;
  lNodeRect := MakeNXRect(GetBorderThickness,
    GetBorderThickness + (ADrawIndex * lItemHeight),
    Max(0, Width - (GetBorderThickness * 2) - IfThen(FScrollbar.Visible, GUI_ScrollbarSize + 4, 0)),
    lItemHeight);

  if ANode = FSelectedNode then
    if IsSelected then
      RenderFilledRect(lNodeRect, Skin.SelectedColor)
    else
      RenderFilledRect(lNodeRect, Skin.TextBackColor);

  lGlyphRect := GetNodeGlyphRect(ANode, ADrawIndex);
  DrawExpandGlyph(ANode, lGlyphRect);

  lTextClip := LocalRectToAbs(MakeNXRect(GetNodeTextX(ANode), lNodeRect.y,
    Max(0, lNodeRect.w - GetNodeTextX(ANode) - cTextPadding), lItemHeight));
  Canvas.PushClip(lTextClip);
  try
    RenderText(ANode.Caption, GetNodeTextX(ANode),
      GetBorderThickness + (ADrawIndex * lItemHeight), Align_Left);
  finally
    Canvas.PopClip;
  end;
end;

procedure TNXTreeList.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
  lNode: TNXTreeListNode;
begin
  inherited DoKeyDown(AEvent);

  RebuildVisibleNodes;
  lIndex := FVisibleNodes.IndexOf(FSelectedNode);

  case AEvent.Key of
    nkUp:
      if lIndex > 0 then
        SelectNode(FVisibleNodes[lIndex - 1]);

    nkDown:
      if (lIndex >= 0) and (lIndex < FVisibleNodes.Count - 1) then
        SelectNode(FVisibleNodes[lIndex + 1])
      else if (lIndex < 0) and (FVisibleNodes.Count > 0) then
        SelectNode(FVisibleNodes[0]);

    nkHome:
      if FVisibleNodes.Count > 0 then
        SelectNode(FVisibleNodes[0]);

    nkEnd:
      if FVisibleNodes.Count > 0 then
        SelectNode(FVisibleNodes[FVisibleNodes.Count - 1]);

    nkRight:
    begin
      lNode := FSelectedNode;
      if Assigned(lNode) then
      begin
        if lNode.HasChildren and not lNode.Expanded then
          ExpandNode(lNode)
        else if lNode.HasChildren then
          SelectNode(lNode.Child[0]);
      end;
    end;

    nkLeft:
    begin
      lNode := FSelectedNode;
      if Assigned(lNode) then
      begin
        if lNode.Expanded then
          CollapseNode(lNode)
        else if Assigned(lNode.Parent) then
          SelectNode(lNode.Parent);
      end;
    end;
  end;
end;

procedure TNXTreeList.DoMouseDoubleClick(AX, AY: Integer; AButton: TNXMouseButton);
var
  lNode: TNXTreeListNode;
begin
  inherited DoMouseDoubleClick(AX, AY, AButton);
  if AButton <> mbLeft then
    Exit;

  lNode := GetNodeAtY(AY - GetBorderThickness);
  if Assigned(lNode) then
    ToggleNode(lNode);
end;

procedure TNXTreeList.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
var
  lDrawIndex: Integer;
  lGlyphRect: TNXRect;
  lNode: TNXTreeListNode;
begin
  inherited DoMouseDown(AX, AY, AButton);
  if AButton <> mbLeft then
    Exit;

  RebuildVisibleNodes;
  lNode := GetNodeAtY(AY - GetBorderThickness);
  if not Assigned(lNode) then
    Exit;

  SelectNode(lNode);

  lDrawIndex := FVisibleNodes.IndexOf(lNode) - FScrollbar.Value;
  if lDrawIndex < 0 then
    Exit;

  lGlyphRect := GetNodeGlyphRect(lNode, lDrawIndex);
  if (AX >= lGlyphRect.x) and (AX < lGlyphRect.x + lGlyphRect.w) and
    (AY >= lGlyphRect.y) and (AY < lGlyphRect.y + lGlyphRect.h) then
    ToggleNode(lNode);
end;

procedure TNXTreeList.EnsureSelectedVisible;
var
  lIndex: Integer;
  lVisibleCount: Integer;
begin
  if not Assigned(FSelectedNode) then
    Exit;

  RebuildVisibleNodes;
  lIndex := FVisibleNodes.IndexOf(FSelectedNode);
  if lIndex < 0 then
    Exit;

  lVisibleCount := GetVisibleItemCount;
  if lVisibleCount <= 0 then
    Exit;

  if lIndex < FScrollbar.Value then
    FScrollbar.Value := lIndex
  else if lIndex >= FScrollbar.Value + lVisibleCount then
    FScrollbar.Value := lIndex - lVisibleCount + 1;
end;

procedure TNXTreeList.NodeChanged(ANode: TNXTreeListNode);
begin
  RebuildVisibleNodes;
  EnsureSelectedVisible;
  UpdateScrollBar;
end;

procedure TNXTreeList.RebuildVisibleNodes;
begin
  FVisibleNodes.Clear;
  AddVisibleNodes(FRootNodes);
end;

procedure TNXTreeList.RenderClient;
var
  lDrawIndex: Integer;
  lNodeIndex: Integer;
  lVisibleCount: Integer;
begin
  RebuildVisibleNodes;
  UpdateScrollBar;

  lVisibleCount := GetVisibleItemCount;
  lNodeIndex := FScrollbar.Value;
  lDrawIndex := 0;

  while (lDrawIndex < lVisibleCount) and (lNodeIndex < FVisibleNodes.Count) do
  begin
    DrawNode(FVisibleNodes[lNodeIndex], lDrawIndex);
    Inc(lDrawIndex);
    Inc(lNodeIndex);
  end;
end;

procedure TNXTreeList.SelectNode(ANode: TNXTreeListNode);
begin
  SelectedNode := ANode;
end;

procedure TNXTreeList.SetIndentWidth(AValue: Integer);
begin
  FIndentWidth := Max(4, AValue);
end;

procedure TNXTreeList.SetSelectedNode(AValue: TNXTreeListNode);
begin
  if FSelectedNode = AValue then
    Exit;

  if Assigned(FSelectedNode) then
    FSelectedNode.Selected := False;

  FSelectedNode := AValue;

  if Assigned(FSelectedNode) then
    FSelectedNode.Selected := True;

  EnsureSelectedVisible;

  if Assigned(FOnChange) then
    FOnChange(Self, FSelectedNode);
end;

procedure TNXTreeList.ToggleNode(ANode: TNXTreeListNode);
begin
  if not Assigned(ANode) then
    Exit;

  if ANode.Expanded then
    CollapseNode(ANode)
  else
    ExpandNode(ANode);
end;

procedure TNXTreeList.UpdateScrollBar;
var
  lMaxValue: Integer;
  lVisibleCount: Integer;
begin
  RebuildVisibleNodes;
  lVisibleCount := GetVisibleItemCount;
  lMaxValue := Max(0, FVisibleNodes.Count - lVisibleCount);
  FScrollbar.Max := lMaxValue;
  if FScrollbar.Value > lMaxValue then
    FScrollbar.Value := lMaxValue;
  FScrollbar.Visible := lMaxValue > 0;
end;

end.
