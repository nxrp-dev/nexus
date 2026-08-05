unit obNXSplitter;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Math,
  tpNXLayout,
  tpNXPlatform,
  obNXControl;

type
  TNXSplitterOrientation = (
    spoVertical,
    spoHorizontal
  );

  TNXSplitter = class(TNXControl)
  private
    FAutoFindTarget: Boolean;
    FDragging: Boolean;
    FDragOrigin: Integer;
    FMinSize: Integer;
    FMaxSize: Integer;
    FOnChange: TNotifyEvent;
    FOrientation: TNXSplitterOrientation;
    FOriginalSize: Integer;
    FResizeControl: TNXControl;

    function GetEffectiveOrientation: TNXSplitterOrientation;
    function GetResizeControl: TNXControl;
    function GetTargetSize(AControl: TNXControl): Integer;
    procedure SetAutoFindTarget(AValue: Boolean);
    procedure SetMaxSize(AValue: Integer);
    procedure SetMinSize(AValue: Integer);
    procedure SetOrientation(AValue: TNXSplitterOrientation);
    procedure SetResizeControl(AValue: TNXControl);
    procedure SetTargetSize(AControl: TNXControl; AValue: Integer);
  protected
    function FindResizeControl: TNXControl; virtual;
    function NormalizeTargetSize(AValue: Integer): Integer; virtual;
    procedure Change; virtual;
    procedure ResizeFromMouse(AX, AY: Integer); virtual;

    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure RenderClient; override;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    property AutoFindTarget: Boolean read FAutoFindTarget write SetAutoFindTarget;
    property Dragging: Boolean read FDragging;
    property MaxSize: Integer read FMaxSize write SetMaxSize;
    property MinSize: Integer read FMinSize write SetMinSize;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Orientation: TNXSplitterOrientation read FOrientation write SetOrientation;
    property ResizeControl: TNXControl read FResizeControl write SetResizeControl;
  end;

implementation

const
  cDefaultSplitterSize = 6;
  cDefaultMinSize = 24;

constructor TNXSplitter.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FAutoFindTarget := True;
  FDragging := False;
  FDragOrigin := 0;
  FMaxSize := 0;
  FMinSize := cDefaultMinSize;
  FOrientation := spoVertical;
  FOriginalSize := 0;
  FResizeControl := nil;

  CanFocus := False;
  FillStyle := FS_Filled;
  BorderStyle := BS_None;
  Width := cDefaultSplitterSize;
  Height := cDefaultSplitterSize;
end;

function TNXSplitter.GetEffectiveOrientation: TNXSplitterOrientation;
begin
  Result := FOrientation;

  case Align of
    caTop,
    caBottom:
      Result := spoHorizontal;
    caLeft,
    caRight:
      Result := spoVertical;
  end;
end;

function TNXSplitter.GetResizeControl: TNXControl;
begin
  Result := FResizeControl;

  if (Result = nil) and FAutoFindTarget then
    Result := FindResizeControl;
end;

function TNXSplitter.GetTargetSize(AControl: TNXControl): Integer;
begin
  case GetEffectiveOrientation of
    spoVertical:
      Result := AControl.Width;
    spoHorizontal:
      Result := AControl.Height;
  end;
end;

procedure TNXSplitter.SetAutoFindTarget(AValue: Boolean);
begin
  FAutoFindTarget := AValue;
end;

procedure TNXSplitter.SetMaxSize(AValue: Integer);
begin
  FMaxSize := Max(0, AValue);
end;

procedure TNXSplitter.SetMinSize(AValue: Integer);
begin
  FMinSize := Max(0, AValue);
end;

procedure TNXSplitter.SetOrientation(AValue: TNXSplitterOrientation);
begin
  FOrientation := AValue;
end;

procedure TNXSplitter.SetResizeControl(AValue: TNXControl);
begin
  FResizeControl := AValue;
end;

procedure TNXSplitter.SetTargetSize(AControl: TNXControl; AValue: Integer);
begin
  if AControl = nil then
    Exit;

  AValue := NormalizeTargetSize(AValue);

  case GetEffectiveOrientation of
    spoVertical:
      AControl.Width := AValue;
    spoHorizontal:
      AControl.Height := AValue;
  end;

  if Assigned(Parent) then
    Parent.LayoutChildren;

  Change;
end;

function TNXSplitter.FindResizeControl: TNXControl;
var
  lIndex: Integer;
begin
  Result := nil;

  if Parent = nil then
    Exit;

  lIndex := Parent.Children.IndexOf(Self) - 1;
  while lIndex >= 0 do
  begin
    if Parent.Children[lIndex].Visible and (Parent.Children[lIndex] <> Self) then
      Exit(Parent.Children[lIndex]);
    Dec(lIndex);
  end;
end;

function TNXSplitter.NormalizeTargetSize(AValue: Integer): Integer;
begin
  Result := Max(FMinSize, AValue);

  if FMaxSize > 0 then
    Result := Min(FMaxSize, Result);
end;

procedure TNXSplitter.Change;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TNXSplitter.ResizeFromMouse(AX, AY: Integer);
var
  lDelta: Integer;
  lPoint: TNXPoint;
  lTarget: TNXControl;
  lTargetSize: Integer;
begin
  lTarget := GetResizeControl;
  if lTarget = nil then
    Exit;

  lPoint := LocalToScreen(AX, AY);
  case GetEffectiveOrientation of
    spoVertical:
      lDelta := lPoint.x - FDragOrigin;
    spoHorizontal:
      lDelta := lPoint.y - FDragOrigin;
  end;

  case lTarget.Align of
    caRight,
    caBottom:
      lTargetSize := FOriginalSize - lDelta;
  else
    lTargetSize := FOriginalSize + lDelta;
  end;

  SetTargetSize(lTarget, lTargetSize);
end;

procedure TNXSplitter.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
var
  lPoint: TNXPoint;
  lTarget: TNXControl;
begin
  inherited DoMouseDown(AX, AY, AButton);

  if AButton <> mbLeft then
    Exit;

  lTarget := GetResizeControl;
  if lTarget = nil then
    Exit;

  lPoint := LocalToScreen(AX, AY);
  case GetEffectiveOrientation of
    spoVertical:
      FDragOrigin := lPoint.x;
    spoHorizontal:
      FDragOrigin := lPoint.y;
  end;

  FOriginalSize := GetTargetSize(lTarget);
  FDragging := True;
  CaptureMouse;
end;

procedure TNXSplitter.DoMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons);
begin
  inherited DoMouseMotion(AX, AY, AButtonState);

  if not FDragging then
    Exit;

  if not (mbLeft in AButtonState) then
  begin
    FDragging := False;
    ReleaseMouseCapture;
    Exit;
  end;

  ResizeFromMouse(AX, AY);
end;

procedure TNXSplitter.DoMouseUp(AX, AY: Integer; AButton: TNXMouseButton);
begin
  inherited DoMouseUp(AX, AY, AButton);

  if FDragging and (AButton = mbLeft) then
  begin
    ResizeFromMouse(AX, AY);
    FDragging := False;
    ReleaseMouseCapture;
  end;
end;

procedure TNXSplitter.RenderClient;
var
  lCenter: Integer;
  lColor: TNXColor;
begin
  inherited RenderClient;

  if FDragging or MouseEntered then
    lColor := Skin.SelectedColor
  else
    lColor := Skin.BorderColor;

  RenderFilledRect(MakeNXRect(0, 0, Width, Height), BackColor);
  RenderRect(MakeNXRect(0, 0, Width, Height), lColor);

  case GetEffectiveOrientation of
    spoVertical:
    begin
      lCenter := Width div 2;
      RenderLine(lCenter, 2, lCenter, Height - 3, lColor);
      if Width >= 5 then
      begin
        RenderLine(lCenter - 2, 4, lCenter - 2, Height - 5, lColor);
        RenderLine(lCenter + 2, 4, lCenter + 2, Height - 5, lColor);
      end;
    end;
    spoHorizontal:
    begin
      lCenter := Height div 2;
      RenderLine(2, lCenter, Width - 3, lCenter, lColor);
      if Height >= 5 then
      begin
        RenderLine(4, lCenter - 2, Width - 5, lCenter - 2, lColor);
        RenderLine(4, lCenter + 2, Width - 5, lCenter + 2, lColor);
      end;
    end;
  end;
end;

end.
