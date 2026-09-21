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

  obNXScrollableControl;

type
  TNXTreeList = class;
  TNXTreeListNode = class;
  TNXTreeListNodeListBase = specialize TFPGObjectList<TNXTreeListNode>;
  TNXTreeListVisibleNodeListBase = specialize TFPGList<TNXTreeListNode>;

  TNXTreeListNode = class
  private
    FCaption: string;
    FChildren: TNXTreeListNodeListBase;
    FData: Pointer;
    FExpanded: Boolean;
    FOwner: TNXTreeList;
    FParent: TNXTreeListNode;
    FSelected: Boolean;

    function GetChildCount: Integer;
    function GetChild(AIndex: Integer): TNXTreeListNode;
    function GetLevel: Integer;
    procedure InvalidateOwnerContentSize;
    procedure SetExpanded(AValue: Boolean);
    procedure SetOwner(AOwner: TNXTreeList);
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
  private
    FOwner: TNXTreeList;
    procedure NotifyOwnerContentChanged;
  public
    function Add(const ANode: TNXTreeListNode): Integer;
    function AddNode(const ACaption: string; AData: Pointer = nil): TNXTreeListNode;
    procedure Clear;
    procedure Delete(AIndex: Integer);
  end;

  TNXTreeListVisibleNodeList = class(TNXTreeListVisibleNodeListBase)
  end;

  TNXTreeListNodeEvent = procedure(Sender: TObject; ANode: TNXTreeListNode) of object;

  TNXTreeList = class(TNXScrollableControl)
  private
    FIndentWidth: Integer;
    FOnChange: TNXTreeListNodeEvent;
    FOnCollapsed: TNXTreeListNodeEvent;
    FOnExpanded: TNXTreeListNodeEvent;
    FRootNodes: TNXTreeListRootList;
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
    procedure DrawNode(ANode: TNXTreeListNode; const ANodeRect: TNXRect); virtual;
    procedure EnsureSelectedVisible; virtual;
    procedure ExpandNode(ANode: TNXTreeListNode); virtual;
    function GetNodeAtY(AY: Integer): TNXTreeListNode; virtual;
    function GetNodeGlyphRect(ANode: TNXTreeListNode; const ANodeRect: TNXRect): TNXRect; virtual;
    function GetNodeTextX(ANode: TNXTreeListNode): Integer; virtual;
    procedure MeasureContent; override;
    procedure RebuildVisibleNodes; virtual;
    procedure RenderViewport; override;
    procedure SelectNode(ANode: TNXTreeListNode); virtual;
    procedure ToggleNode(ANode: TNXTreeListNode); virtual;

    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDoubleClick(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
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
  Result.SetOwner(FOwner);
  FChildren.Add(Result);
  InvalidateOwnerContentSize;
end;

procedure TNXTreeListNode.Clear;
begin
  FChildren.Clear;
  InvalidateOwnerContentSize;
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

procedure TNXTreeListNode.InvalidateOwnerContentSize;
begin
  if Assigned(FOwner) then
    FOwner.InvalidateContentSize;
end;

procedure TNXTreeListNode.SetExpanded(AValue: Boolean);
begin
  if FExpanded = AValue then
    Exit;

  FExpanded := AValue;
  InvalidateOwnerContentSize;
end;

procedure TNXTreeListNode.SetOwner(AOwner: TNXTreeList);
var
  lIndex: Integer;
begin
  FOwner := AOwner;
  for lIndex := 0 to ChildCount - 1 do
    Child[lIndex].SetOwner(AOwner);
end;

procedure TNXTreeListRootList.NotifyOwnerContentChanged;
begin
  if Assigned(FOwner) then
    FOwner.InvalidateContentSize;
end;

function TNXTreeListRootList.Add(const ANode: TNXTreeListNode): Integer;
begin
  if Assigned(ANode) then
    ANode.SetOwner(FOwner);

  Result := inherited Add(ANode);
  NotifyOwnerContentChanged;
end;

function TNXTreeListRootList.AddNode(const ACaption: string; AData: Pointer): TNXTreeListNode;
begin
  Result := TNXTreeListNode.Create(ACaption, AData);
  Add(Result);
end;

procedure TNXTreeListRootList.Clear;
begin
  inherited Clear;
  NotifyOwnerContentChanged;
end;

procedure TNXTreeListRootList.Delete(AIndex: Integer);
begin
  inherited Delete(AIndex);
  NotifyOwnerContentChanged;
end;

constructor TNXTreeList.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  BorderStyle := BS_Single;
  FillStyle := FS_Filled;
  CanFocus := True;
  FIndentWidth := cDefaultIndentWidth;
  FRootNodes := TNXTreeListRootList.Create(True);
  FRootNodes.FOwner := Self;
  FVisibleNodes := TNXTreeListVisibleNodeList.Create;
  FSelectedNode := nil;
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
  ScrollY := 0;
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

  EnsureSelectedVisible;
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

  EnsureSelectedVisible;
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
  EnsureSelectedVisible;

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
  EnsureSelectedVisible;

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
  lViewportRect: TNXRect;
begin
  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Result := 0
  else
  begin
    lViewportRect := ScrollableViewportRect;
    Result := Max(0, (lViewportRect.h + lItemHeight - 1) div lItemHeight);
  end;
end;

function TNXTreeList.GetNodeAtY(AY: Integer): TNXTreeListNode;
var
  lContentY: Integer;
  lIndex: Integer;
  lItemHeight: Integer;
  lViewportRect: TNXRect;
begin
  Result := nil;
  UpdateLayoutIfNeeded;

  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Exit;

  lViewportRect := ScrollableViewportRect;
  if (AY < lViewportRect.y) or (AY >= lViewportRect.y + lViewportRect.h) then
    Exit;

  lContentY := AY - lViewportRect.y + ScrollY;
  lIndex := lContentY div lItemHeight;
  if (lIndex >= 0) and (lIndex < FVisibleNodes.Count) then
    Result := FVisibleNodes[lIndex];
end;

function TNXTreeList.GetNodeGlyphRect(ANode: TNXTreeListNode;
  const ANodeRect: TNXRect): TNXRect;
var
  lLeft: Integer;
  lTop: Integer;
begin
  lLeft := ANodeRect.x + (ANode.Level * FIndentWidth) + cTextPadding;
  lTop := ANodeRect.y + ((ANodeRect.h - cGlyphSize) div 2);
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

procedure TNXTreeList.DrawNode(ANode: TNXTreeListNode; const ANodeRect: TNXRect);
var
  lGlyphRect: TNXRect;
  lTextClip: TNXRect;
  lTextX: Integer;
begin
  if not Assigned(ANode) then
    Exit;

  if ANode = FSelectedNode then
    if IsFocused then
      RenderFilledRect(ANodeRect, Skin.SelectedColor)
    else
      RenderFilledRect(ANodeRect, Skin.TextBackColor);

  lGlyphRect := GetNodeGlyphRect(ANode, ANodeRect);
  DrawExpandGlyph(ANode, lGlyphRect);

  lTextX := ANodeRect.x + GetNodeTextX(ANode);
  lTextClip := LocalRectToAbs(MakeNXRect(lTextX, ANodeRect.y,
    Max(0, (ANodeRect.x + ANodeRect.w) - lTextX - cTextPadding), ANodeRect.h));
  Canvas.PushClip(lTextClip);
  try
    RenderText(ANode.Caption, lTextX, ANodeRect.y, Align_Left);
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

  UpdateLayoutIfNeeded;
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

  lNode := GetNodeAtY(AY);
  if Assigned(lNode) then
    ToggleNode(lNode);
end;

procedure TNXTreeList.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
var
  lGlyphRect: TNXRect;
  lItemHeight: Integer;
  lNode: TNXTreeListNode;
  lNodeIndex: Integer;
  lNodeRect: TNXRect;
  lViewportRect: TNXRect;
begin
  inherited DoMouseDown(AX, AY, AButton);
  if AButton <> mbLeft then
    Exit;

  UpdateLayoutIfNeeded;
  lViewportRect := ScrollableViewportRect;
  if not NXRectContainsPoint(lViewportRect, AX, AY) then
    Exit;

  lNode := GetNodeAtY(AY);
  if not Assigned(lNode) then
    Exit;

  SelectNode(lNode);

  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Exit;

  lNodeIndex := FVisibleNodes.IndexOf(lNode);
  if lNodeIndex < 0 then
    Exit;

  lNodeRect := MakeNXRect(lViewportRect.x,
    lViewportRect.y + (lNodeIndex * lItemHeight) - ScrollY,
    lViewportRect.w, lItemHeight);
  lGlyphRect := GetNodeGlyphRect(lNode, lNodeRect);
  if NXRectContainsPoint(lGlyphRect, AX, AY) then
    ToggleNode(lNode);
end;

procedure TNXTreeList.EnsureSelectedVisible;
var
  lIndex: Integer;
  lItemBottom: Integer;
  lItemHeight: Integer;
  lItemTop: Integer;
  lViewportRect: TNXRect;
begin
  if not Assigned(FSelectedNode) then
    Exit;

  UpdateLayoutIfNeeded;
  lIndex := FVisibleNodes.IndexOf(FSelectedNode);
  if lIndex < 0 then
    Exit;

  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Exit;

  lViewportRect := ScrollableViewportRect;
  if lViewportRect.h <= 0 then
    Exit;

  lItemTop := lIndex * lItemHeight;
  lItemBottom := lItemTop + lItemHeight;

  if lItemTop < ScrollY then
    ScrollY := lItemTop
  else if lItemBottom > ScrollY + lViewportRect.h then
    ScrollY := lItemBottom - lViewportRect.h;
end;

procedure TNXTreeList.NodeChanged(ANode: TNXTreeListNode);
begin
  InvalidateContentSize;
  EnsureSelectedVisible;
end;

procedure TNXTreeList.RebuildVisibleNodes;
begin
  FVisibleNodes.Clear;
  AddVisibleNodes(FRootNodes);
end;

procedure TNXTreeList.MeasureContent;
begin
  RebuildVisibleNodes;
  ContentWidth := 0;
  ContentHeight := FVisibleNodes.Count * GetItemHeight;
end;

procedure TNXTreeList.RenderViewport;
var
  lItemHeight: Integer;
  lNodeRect: TNXRect;
  lNodeIndex: Integer;
  lNodeTop: Integer;
  lViewportRect: TNXRect;
begin
  lItemHeight := GetItemHeight;
  if lItemHeight <= 0 then
    Exit;

  lViewportRect := ScrollableViewportRect;
  lNodeIndex := Max(0, ScrollY div lItemHeight);
  lNodeTop := lViewportRect.y - (ScrollY mod lItemHeight);

  while (lNodeIndex < FVisibleNodes.Count) and (lNodeTop < lViewportRect.y + lViewportRect.h) do
  begin
    lNodeRect := MakeNXRect(lViewportRect.x, lNodeTop, lViewportRect.w,
      lItemHeight);
    DrawNode(FVisibleNodes[lNodeIndex], lNodeRect);
    Inc(lNodeIndex);
    Inc(lNodeTop, lItemHeight);
  end;
end;

procedure TNXTreeList.SelectNode(ANode: TNXTreeListNode);
begin
  SelectedNode := ANode;
end;

procedure TNXTreeList.SetIndentWidth(AValue: Integer);
begin
  AValue := Max(4, AValue);
  if FIndentWidth = AValue then
    Exit;

  FIndentWidth := AValue;
  InvalidateContentSize;
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

end.
