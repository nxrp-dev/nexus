unit obNXCommandOverlay;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Math,
  fgl,
  tpNXLayout,
  tpNXPlatform,
  obNXControl;

type
  TNXCommandOverlayEdge = (coeTop, coeLeft, coeRight, coeBottom);

  TNXCommandOverlay = class;

  TNXCommandOverlayItem = class
  private
    FControl: TNXControl;
    FEdge: TNXCommandOverlayEdge;
  public
    constructor Create(AControl: TNXControl; AEdge: TNXCommandOverlayEdge);

    property Control: TNXControl read FControl;
    property Edge: TNXCommandOverlayEdge read FEdge write FEdge;
  end;

  TNXCommandOverlayItemList = specialize TFPGObjectList<TNXCommandOverlayItem>;

  TNXCommandOverlay = class(TNXControl)
  private
    FBandColors: array[TNXCommandOverlayEdge] of TNXColor;
    FBandVisible: array[TNXCommandOverlayEdge] of Boolean;
    FEdgeSizes: array[TNXCommandOverlayEdge] of Integer;
    FItems: TNXCommandOverlayItemList;
    FPadding: Integer;
    FShowBorders: Boolean;
    FSpacing: Integer;

    function FindItem(AControl: TNXControl): TNXCommandOverlayItem;
    function GetBandColor(AEdge: TNXCommandOverlayEdge): TNXColor;
    function GetBandVisible(AEdge: TNXCommandOverlayEdge): Boolean;
    function GetEdgeSize(AEdge: TNXCommandOverlayEdge): Integer;
    function GetEffectiveBottomSize: Integer;
    function GetEffectiveLeftSize: Integer;
    function GetEffectiveRightSize: Integer;
    function GetEffectiveTopSize: Integer;
    function GetItemEdge(AControl: TNXControl): TNXCommandOverlayEdge;
    function GetLocalEdgeRect(AEdge: TNXCommandOverlayEdge): TNXRect;
    function PointInRect(AX, AY: Integer; const ARect: TNXRect): Boolean;
    procedure ArrangeBottomEdge;
    procedure ArrangeHorizontalEdge(AEdge: TNXCommandOverlayEdge; AY: Integer;
      AHeight: Integer);
    procedure ArrangeLeftEdge;
    procedure ArrangeRightEdge;
    procedure ArrangeTopEdge;
    procedure ArrangeVerticalEdge(AEdge: TNXCommandOverlayEdge; AX: Integer;
      AWidth: Integer; AY: Integer; AHeight: Integer);
    procedure RegisterControl(AControl: TNXControl; AEdge: TNXCommandOverlayEdge);
    procedure SetBandColor(AEdge: TNXCommandOverlayEdge; const AValue: TNXColor);
    procedure SetBandVisible(AEdge: TNXCommandOverlayEdge; AValue: Boolean);
    procedure SetEdgeSize(AEdge: TNXCommandOverlayEdge; AValue: Integer);
    procedure SetPadding(AValue: Integer);
    procedure SetShowBorders(AValue: Boolean);
    procedure SetSpacing(AValue: Integer);
  protected
    function HitTestSelf(AX, AY: Integer): Boolean; override;
    procedure RenderClient; override;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;

    procedure AddChild(AChild: TNXControl); override;
    procedure AddBottom(AControl: TNXControl);
    procedure AddLeft(AControl: TNXControl);
    procedure AddRight(AControl: TNXControl);
    procedure AddTop(AControl: TNXControl);
    procedure BringOverlayToFront;
    procedure ChildDestroying(AChild: TNXControl); override;
    procedure LayoutChildren; override;
    function GetControlEdge(AControl: TNXControl): TNXCommandOverlayEdge;
    function IsInCommandBand(AX, AY: Integer): Boolean;
    function LocalEdgeRect(AEdge: TNXCommandOverlayEdge): TNXRect;
    procedure RemoveControl(AControl: TNXControl);
    procedure SetControlEdge(AControl: TNXControl; AEdge: TNXCommandOverlayEdge);

    property BandColor[AEdge: TNXCommandOverlayEdge]: TNXColor
      read GetBandColor write SetBandColor;
    property BandVisible[AEdge: TNXCommandOverlayEdge]: Boolean
      read GetBandVisible write SetBandVisible;
    property EdgeSize[AEdge: TNXCommandOverlayEdge]: Integer
      read GetEdgeSize write SetEdgeSize;
    property Padding: Integer read FPadding write SetPadding;
    property ShowBorders: Boolean read FShowBorders write SetShowBorders;
    property Spacing: Integer read FSpacing write SetSpacing;
  end;

implementation

const
  cDefaultBandSize = 40;
  cDefaultPadding = 6;
  cDefaultSpacing = 4;

constructor TNXCommandOverlayItem.Create(AControl: TNXControl;
  AEdge: TNXCommandOverlayEdge);
begin
  inherited Create;
  FControl := AControl;
  FEdge := AEdge;
end;

constructor TNXCommandOverlay.Create(const AParent: INXControlParent);
var
  lEdge: TNXCommandOverlayEdge;
  lColor: TNXColor;
begin
  inherited Create(AParent);

  FItems := TNXCommandOverlayItemList.Create(True);
  FPadding := cDefaultPadding;
  FSpacing := cDefaultSpacing;
  FShowBorders := True;

  lColor := BackColor;
  lColor.a := 192;
  for lEdge := Low(TNXCommandOverlayEdge) to High(TNXCommandOverlayEdge) do
  begin
    FBandColors[lEdge] := lColor;
    FBandVisible[lEdge] := True;
    FEdgeSizes[lEdge] := cDefaultBandSize;
  end;

  Align := caClient;
  BorderStyle := BS_None;
  FillStyle := FS_None;
  CanFocus := False;
  TabStop := False;
  ReceiveAllEvents := False;
  SkinClass := 'CommandOverlay';
  BringOverlayToFront;
end;

destructor TNXCommandOverlay.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

function TNXCommandOverlay.FindItem(AControl: TNXControl): TNXCommandOverlayItem;
var
  lIndex: Integer;
begin
  Result := nil;
  if (FItems = nil) or (AControl = nil) then
    Exit;

  for lIndex := 0 to FItems.Count - 1 do
    if FItems[lIndex].Control = AControl then
    begin
      Result := FItems[lIndex];
      Exit;
    end;
end;

function TNXCommandOverlay.GetBandColor(AEdge: TNXCommandOverlayEdge): TNXColor;
begin
  Result := FBandColors[AEdge];
end;

function TNXCommandOverlay.GetBandVisible(AEdge: TNXCommandOverlayEdge): Boolean;
begin
  Result := FBandVisible[AEdge];
end;

function TNXCommandOverlay.GetEdgeSize(AEdge: TNXCommandOverlayEdge): Integer;
begin
  Result := FEdgeSizes[AEdge];
end;

function TNXCommandOverlay.GetEffectiveBottomSize: Integer;
begin
  if FBandVisible[coeBottom] then
    Result := FEdgeSizes[coeBottom]
  else
    Result := 0;
end;

function TNXCommandOverlay.GetEffectiveLeftSize: Integer;
begin
  if FBandVisible[coeLeft] then
    Result := FEdgeSizes[coeLeft]
  else
    Result := 0;
end;

function TNXCommandOverlay.GetEffectiveRightSize: Integer;
begin
  if FBandVisible[coeRight] then
    Result := FEdgeSizes[coeRight]
  else
    Result := 0;
end;

function TNXCommandOverlay.GetEffectiveTopSize: Integer;
begin
  if FBandVisible[coeTop] then
    Result := FEdgeSizes[coeTop]
  else
    Result := 0;
end;

function TNXCommandOverlay.GetItemEdge(AControl: TNXControl): TNXCommandOverlayEdge;
var
  lItem: TNXCommandOverlayItem;
begin
  lItem := FindItem(AControl);
  if Assigned(lItem) then
    Result := lItem.Edge
  else
    Result := coeTop;
end;

function TNXCommandOverlay.GetLocalEdgeRect(AEdge: TNXCommandOverlayEdge): TNXRect;
var
  lSize: Integer;
begin
  if not FBandVisible[AEdge] then
  begin
    Result := MakeNXRect(0, 0, 0, 0);
    Exit;
  end;

  lSize := FEdgeSizes[AEdge];
  case AEdge of
    coeTop:
      Result := MakeNXRect(0, 0, Width, Min(lSize, Height));
    coeLeft:
      Result := MakeNXRect(0, 0, Min(lSize, Width), Height);
    coeRight:
      Result := MakeNXRect(Max(0, Width - lSize), 0, Min(lSize, Width), Height);
    coeBottom:
      Result := MakeNXRect(0, Max(0, Height - lSize), Width, Min(lSize, Height));
  end;
end;

function TNXCommandOverlay.PointInRect(AX, AY: Integer;
  const ARect: TNXRect): Boolean;
begin
  Result := (ARect.w > 0) and (ARect.h > 0) and
    (AX >= ARect.x) and (AX < ARect.x + ARect.w) and
    (AY >= ARect.y) and (AY < ARect.y + ARect.h);
end;

procedure TNXCommandOverlay.ArrangeHorizontalEdge(AEdge: TNXCommandOverlayEdge;
  AY: Integer; AHeight: Integer);
var
  lChild: TNXControl;
  lIndex: Integer;
  lItem: TNXCommandOverlayItem;
  lX: Integer;
  lY: Integer;
begin
  if (AHeight <= 0) or (FItems = nil) then
    Exit;

  lX := FPadding;
  for lIndex := 0 to FItems.Count - 1 do
  begin
    lItem := FItems[lIndex];
    if lItem.Edge <> AEdge then
      Continue;

    lChild := lItem.Control;
    if (lChild = nil) or (not lChild.Visible) then
      Continue;

    lY := AY + Max(0, (AHeight - lChild.Height) div 2);
    lChild.SetBounds(lX, lY, lChild.Width, lChild.Height);
    Inc(lX, lChild.Width + FSpacing);
  end;
end;

procedure TNXCommandOverlay.ArrangeVerticalEdge(AEdge: TNXCommandOverlayEdge;
  AX: Integer; AWidth: Integer; AY: Integer; AHeight: Integer);
var
  lChild: TNXControl;
  lIndex: Integer;
  lItem: TNXCommandOverlayItem;
  lX: Integer;
  lY: Integer;
begin
  if (AWidth <= 0) or (AHeight <= 0) or (FItems = nil) then
    Exit;

  lY := AY + FPadding;
  for lIndex := 0 to FItems.Count - 1 do
  begin
    lItem := FItems[lIndex];
    if lItem.Edge <> AEdge then
      Continue;

    lChild := lItem.Control;
    if (lChild = nil) or (not lChild.Visible) then
      Continue;

    lX := AX + Max(0, (AWidth - lChild.Width) div 2);
    lChild.SetBounds(lX, lY, lChild.Width, lChild.Height);
    Inc(lY, lChild.Height + FSpacing);
  end;
end;

procedure TNXCommandOverlay.ArrangeBottomEdge;
begin
  ArrangeHorizontalEdge(coeBottom, Max(0, Height - GetEffectiveBottomSize),
    GetEffectiveBottomSize);
end;

procedure TNXCommandOverlay.ArrangeLeftEdge;
begin
  ArrangeVerticalEdge(coeLeft, 0, GetEffectiveLeftSize, GetEffectiveTopSize,
    Max(0, Height - GetEffectiveTopSize - GetEffectiveBottomSize));
end;

procedure TNXCommandOverlay.ArrangeRightEdge;
begin
  ArrangeVerticalEdge(coeRight, Max(0, Width - GetEffectiveRightSize),
    GetEffectiveRightSize, GetEffectiveTopSize,
    Max(0, Height - GetEffectiveTopSize - GetEffectiveBottomSize));
end;

procedure TNXCommandOverlay.ArrangeTopEdge;
begin
  ArrangeHorizontalEdge(coeTop, 0, GetEffectiveTopSize);
end;

procedure TNXCommandOverlay.RegisterControl(AControl: TNXControl;
  AEdge: TNXCommandOverlayEdge);
var
  lItem: TNXCommandOverlayItem;
begin
  if AControl = nil then
    Exit;

  if Children.IndexOf(AControl) < 0 then
  begin
    if Assigned(AControl.Parent) then
      raise Exception.Create('Cannot add command overlay control owned by another parent');
    AddChild(AControl);
  end;

  lItem := FindItem(AControl);
  if not Assigned(lItem) then
  begin
    lItem := TNXCommandOverlayItem.Create(AControl, AEdge);
    FItems.Add(lItem);
  end
  else
    lItem.Edge := AEdge;

  LayoutChildren;
end;

procedure TNXCommandOverlay.SetBandColor(AEdge: TNXCommandOverlayEdge;
  const AValue: TNXColor);
begin
  FBandColors[AEdge] := AValue;
end;

procedure TNXCommandOverlay.SetBandVisible(AEdge: TNXCommandOverlayEdge;
  AValue: Boolean);
begin
  if FBandVisible[AEdge] = AValue then
    Exit;

  FBandVisible[AEdge] := AValue;
  LayoutChildren;
end;

procedure TNXCommandOverlay.SetEdgeSize(AEdge: TNXCommandOverlayEdge;
  AValue: Integer);
begin
  AValue := Max(0, AValue);
  if FEdgeSizes[AEdge] = AValue then
    Exit;

  FEdgeSizes[AEdge] := AValue;
  LayoutChildren;
end;


procedure TNXCommandOverlay.SetPadding(AValue: Integer);
begin
  AValue := Max(0, AValue);
  if FPadding = AValue then
    Exit;

  FPadding := AValue;
  LayoutChildren;
end;

procedure TNXCommandOverlay.SetShowBorders(AValue: Boolean);
begin
  FShowBorders := AValue;
end;

procedure TNXCommandOverlay.SetSpacing(AValue: Integer);
begin
  AValue := Max(0, AValue);
  if FSpacing = AValue then
    Exit;

  FSpacing := AValue;
  LayoutChildren;
end;

procedure TNXCommandOverlay.RenderClient;
var
  lEdge: TNXCommandOverlayEdge;
  lRect: TNXRect;
begin
  for lEdge := Low(TNXCommandOverlayEdge) to High(TNXCommandOverlayEdge) do
  begin
    lRect := GetLocalEdgeRect(lEdge);
    if (lRect.w <= 0) or (lRect.h <= 0) then
      Continue;

    RenderFilledRect(lRect, FBandColors[lEdge]);
    if FShowBorders then
      RenderRect(lRect, BorderColor);
  end;
end;

procedure TNXCommandOverlay.AddChild(AChild: TNXControl);
begin
  inherited AddChild(AChild);
  if (FItems <> nil) and (AChild <> nil) and (FindItem(AChild) = nil) then
    FItems.Add(TNXCommandOverlayItem.Create(AChild, coeTop));
  LayoutChildren;
end;

procedure TNXCommandOverlay.AddBottom(AControl: TNXControl);
begin
  RegisterControl(AControl, coeBottom);
end;

procedure TNXCommandOverlay.AddLeft(AControl: TNXControl);
begin
  RegisterControl(AControl, coeLeft);
end;

procedure TNXCommandOverlay.AddRight(AControl: TNXControl);
begin
  RegisterControl(AControl, coeRight);
end;

procedure TNXCommandOverlay.AddTop(AControl: TNXControl);
begin
  RegisterControl(AControl, coeTop);
end;

procedure TNXCommandOverlay.BringOverlayToFront;
begin
  BringToFront;
end;

procedure TNXCommandOverlay.ChildDestroying(AChild: TNXControl);
begin
  RemoveControl(AChild);
  inherited ChildDestroying(AChild);
end;

procedure TNXCommandOverlay.LayoutChildren;
begin
  ArrangeTopEdge;
  ArrangeBottomEdge;
  ArrangeLeftEdge;
  ArrangeRightEdge;
end;

function TNXCommandOverlay.HitTestSelf(AX, AY: Integer): Boolean;
begin
  Result := IsInCommandBand(AX, AY);
end;

function TNXCommandOverlay.GetControlEdge(AControl: TNXControl): TNXCommandOverlayEdge;
begin
  Result := GetItemEdge(AControl);
end;

function TNXCommandOverlay.IsInCommandBand(AX, AY: Integer): Boolean;
var
  lEdge: TNXCommandOverlayEdge;
begin
  Result := False;
  for lEdge := Low(TNXCommandOverlayEdge) to High(TNXCommandOverlayEdge) do
    if PointInRect(AX, AY, GetLocalEdgeRect(lEdge)) then
    begin
      Result := True;
      Exit;
    end;
end;

function TNXCommandOverlay.LocalEdgeRect(AEdge: TNXCommandOverlayEdge): TNXRect;
begin
  Result := GetLocalEdgeRect(AEdge);
end;

procedure TNXCommandOverlay.SetControlEdge(AControl: TNXControl;
  AEdge: TNXCommandOverlayEdge);
begin
  RegisterControl(AControl, AEdge);
end;

procedure TNXCommandOverlay.RemoveControl(AControl: TNXControl);
var
  lIndex: Integer;
begin
  if (FItems = nil) or (AControl = nil) then
    Exit;

  for lIndex := FItems.Count - 1 downto 0 do
    if FItems[lIndex].Control = AControl then
      FItems.Delete(lIndex);
end;

end.
