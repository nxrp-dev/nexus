unit obNXSplitPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Math,
  SysUtils,
  tpNXPlatform,
  obNXControl;

type
  TNXSplitPanel = class;

  TNXSplitOrientation = (
    soVertical,
    soHorizontal
  );

  TNXSplitMode = (
    smPixels,
    smPercent
  );

  TNXSplitPanelPane = class(TNXControl)
  public
    constructor Create(const AParent: INXControlParent); overload; override;
  end;

  TNXSplitPanelSplitter = class(TNXControl)
  private
    FOwner: TNXSplitPanel;
  public
    constructor Create(const AParent: INXControlParent; AOwner: TNXSplitPanel); reintroduce; virtual;
    procedure Render; override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(X, Y: Integer; Button: TNXMouseButton); override;
  end;

  TNXSplitPanel = class(TNXControl)
  private
    FPaneA: TNXSplitPanelPane;
    FPaneB: TNXSplitPanelPane;
    FSplitter: TNXSplitPanelSplitter;
    FOrientation: TNXSplitOrientation;
    FSplitMode: TNXSplitMode;
    FSplitPosition: Integer;
    FSplitPercent: Double;
    FSplitterSize: Integer;
    FMinPaneASize: Integer;
    FMinPaneBSize: Integer;
    FDragging: Boolean;
    FOnChange: TNotifyEvent;

    function GetAvailableSize: Integer;
    function GetEffectiveSplitPosition: Integer;
    function GetLocalSplitterRect: TNXRect;
    function PointInSplitter(AX, AY: Integer): Boolean;
    procedure SetOrientation(AValue: TNXSplitOrientation);
    procedure SetSplitMode(AValue: TNXSplitMode);
    procedure SetSplitPosition(AValue: Integer);
    procedure SetSplitPercent(AValue: Double);
    procedure SetSplitterSize(AValue: Integer);
    procedure SetMinPaneASize(AValue: Integer);
    procedure SetMinPaneBSize(AValue: Integer);
    procedure SetSplitFromMouse(AX, AY: Integer);
  protected
    procedure DoResize; override;
    procedure RenderClient; override;
    procedure LayoutPanes; virtual;
    procedure Change; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    procedure ParentSizeCallback(NewW, NewH: Integer); override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseExit; override;

    property PaneA: TNXSplitPanelPane read FPaneA;
    property PaneB: TNXSplitPanelPane read FPaneB;
    property Orientation: TNXSplitOrientation read FOrientation write SetOrientation;
    property SplitMode: TNXSplitMode read FSplitMode write SetSplitMode;
    property SplitPosition: Integer read FSplitPosition write SetSplitPosition;
    property SplitPercent: Double read FSplitPercent write SetSplitPercent;
    property SplitterSize: Integer read FSplitterSize write SetSplitterSize;
    property MinPaneASize: Integer read FMinPaneASize write SetMinPaneASize;
    property MinPaneBSize: Integer read FMinPaneBSize write SetMinPaneBSize;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

constructor TNXSplitPanelPane.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  Left := 0;
  Top := 0;
  Width := 50;
  Height := 50;
  FillStyle := FS_Filled;
  BorderStyle := BS_None;
  CanFocus := False;
end;

constructor TNXSplitPanelSplitter.Create(const AParent: INXControlParent; AOwner: TNXSplitPanel);
begin
  inherited Create(AParent);
  FOwner := AOwner;
  BorderStyle := BS_None;
  FillStyle := FS_Filled;
  CanFocus := False;
end;

procedure TNXSplitPanelSplitter.Render;
begin
  if Assigned(FOwner) and FOwner.FDragging then
    CurFillColor := Skin.SelectedColor
  else
    CurFillColor := Skin.BorderColor;

  inherited Render;
end;

procedure TNXSplitPanelSplitter.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited DoMouseDown(X, Y, Button);

  if (Button = mbLeft) and Assigned(FOwner) then
  begin
    FOwner.FDragging := True;
    CaptureMouse;
    FOwner.SetSplitFromMouse(Left + X, Top + Y);
  end;
end;

procedure TNXSplitPanelSplitter.DoMouseMotion(X, Y: Integer;
  ButtonState: TNXMouseButtons);
begin
  inherited DoMouseMotion(X, Y, ButtonState);

  if not Assigned(FOwner) or not FOwner.FDragging then
    Exit;

  if not (mbLeft in ButtonState) then
  begin
    FOwner.FDragging := False;
    ReleaseMouseCapture;
    Exit;
  end;

  FOwner.SetSplitFromMouse(Left + X, Top + Y);
end;

procedure TNXSplitPanelSplitter.DoMouseUp(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited DoMouseUp(X, Y, Button);

  if Assigned(FOwner) and FOwner.FDragging and (Button = mbLeft) then
  begin
    FOwner.FDragging := False;
    ReleaseMouseCapture;
    FOwner.SetSplitFromMouse(Left + X, Top + Y);
  end;
end;

constructor TNXSplitPanel.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  FOrientation := soVertical;
  FSplitMode := smPercent;
  FSplitPosition := 100;
  FSplitPercent := 0.5;
  FSplitterSize := 6;
  FMinPaneASize := 24;
  FMinPaneBSize := 24;
  FDragging := False;

  BackColor := Skin.FormBackColor;
  BorderStyle := BS_Single;

  FPaneA := TNXSplitPanelPane.Create(Self);
  FPaneB := TNXSplitPanelPane.Create(Self);
  FSplitter := TNXSplitPanelSplitter.Create(Self, Self);

  LayoutPanes;
end;

function TNXSplitPanel.GetAvailableSize: Integer;
var
  lContentRect: TNXRect;
begin
  lContentRect := ContentRect;

  case FOrientation of
    soVertical:
      Result := Max(0, lContentRect.w - FSplitterSize);
    soHorizontal:
      Result := Max(0, lContentRect.h - FSplitterSize);
  end;
end;

function TNXSplitPanel.GetEffectiveSplitPosition: Integer;
var
  lAvailableSize: Integer;
  lPosition: Integer;
begin
  lAvailableSize := GetAvailableSize;

  case FSplitMode of
    smPixels:
      lPosition := FSplitPosition;
    smPercent:
      lPosition := Round(lAvailableSize * FSplitPercent);
  else
    lPosition := FSplitPosition;
  end;

  Result := Max(FMinPaneASize, lPosition);
  Result := Min(Max(0, lAvailableSize - FMinPaneBSize), Result);
end;

function TNXSplitPanel.GetLocalSplitterRect: TNXRect;
var
  lContentRect: TNXRect;
  lSplitPosition: Integer;
begin
  lContentRect := ContentRect;
  lSplitPosition := GetEffectiveSplitPosition;

  case FOrientation of
    soVertical:
      Result := MakeNXRect(
        lContentRect.x + lSplitPosition,
        lContentRect.y,
        FSplitterSize,
        lContentRect.h
      );
    soHorizontal:
      Result := MakeNXRect(
        lContentRect.x,
        lContentRect.y + lSplitPosition,
        lContentRect.w,
        FSplitterSize
      );
  end;
end;

function TNXSplitPanel.PointInSplitter(AX, AY: Integer): Boolean;
var
  lRect: TNXRect;
begin
  lRect := GetLocalSplitterRect;
  Result :=
    (AX >= lRect.x) and
    (AX < lRect.x + lRect.w) and
    (AY >= lRect.y) and
    (AY < lRect.y + lRect.h);
end;

procedure TNXSplitPanel.SetOrientation(AValue: TNXSplitOrientation);
begin
  if FOrientation = AValue then
    Exit;

  FOrientation := AValue;
  LayoutPanes;
  Change;
end;

procedure TNXSplitPanel.SetSplitMode(AValue: TNXSplitMode);
begin
  if FSplitMode = AValue then
    Exit;

  if AValue = smPixels then
    FSplitPosition := GetEffectiveSplitPosition
  else if GetAvailableSize > 0 then
    FSplitPercent := GetEffectiveSplitPosition / GetAvailableSize;

  FSplitMode := AValue;
  LayoutPanes;
  Change;
end;

procedure TNXSplitPanel.SetSplitPosition(AValue: Integer);
var
  lAvailableSize: Integer;
begin
  lAvailableSize := GetAvailableSize;

  FSplitPosition := Max(FMinPaneASize, AValue);
  FSplitPosition := Min(Max(0, lAvailableSize - FMinPaneBSize), FSplitPosition);

  if lAvailableSize > 0 then
    FSplitPercent := FSplitPosition / lAvailableSize;

  LayoutPanes;
  Change;
end;

procedure TNXSplitPanel.SetSplitPercent(AValue: Double);
begin
  FSplitPercent := Max(0.0, AValue);
  FSplitPercent := Min(1.0, FSplitPercent);
  FSplitMode := smPercent;

  FSplitPosition := GetEffectiveSplitPosition;

  LayoutPanes;
  Change;
end;

procedure TNXSplitPanel.SetSplitterSize(AValue: Integer);
begin
  FSplitterSize := Max(1, AValue);
  LayoutPanes;
  Change;
end;

procedure TNXSplitPanel.SetMinPaneASize(AValue: Integer);
begin
  FMinPaneASize := Max(0, AValue);
  LayoutPanes;
end;

procedure TNXSplitPanel.SetMinPaneBSize(AValue: Integer);
begin
  FMinPaneBSize := Max(0, AValue);
  LayoutPanes;
end;

procedure TNXSplitPanel.SetSplitFromMouse(AX, AY: Integer);
var
  lContentRect: TNXRect;
begin
  lContentRect := ContentRect;

  case FOrientation of
    soVertical:
      SplitPosition := AX - lContentRect.x - (FSplitterSize div 2);
    soHorizontal:
      SplitPosition := AY - lContentRect.y - (FSplitterSize div 2);
  end;
end;

procedure TNXSplitPanel.DoResize;
begin
  inherited DoResize;
  LayoutPanes;
end;

procedure TNXSplitPanel.RenderClient;
begin
  inherited RenderClient;
end;

procedure TNXSplitPanel.LayoutPanes;
var
  lContentRect: TNXRect;
  lSplitterRect: TNXRect;
  lSplitPosition: Integer;
begin
  if (FPaneA = nil) or (FPaneB = nil) or (FSplitter = nil) then
    Exit;

  lContentRect := ContentRect;
  lSplitPosition := GetEffectiveSplitPosition;
  lSplitterRect := GetLocalSplitterRect;

  case FOrientation of
    soVertical:
    begin
      FPaneA.Left := lContentRect.x;
      FPaneA.Top := lContentRect.y;
      FPaneA.Width := lSplitPosition;
      FPaneA.Height := lContentRect.h;

      FPaneB.Left := lContentRect.x + lSplitPosition + FSplitterSize;
      FPaneB.Top := lContentRect.y;
      FPaneB.Width := Max(0, lContentRect.w - lSplitPosition - FSplitterSize);
      FPaneB.Height := lContentRect.h;
    end;
    soHorizontal:
    begin
      FPaneA.Left := lContentRect.x;
      FPaneA.Top := lContentRect.y;
      FPaneA.Width := lContentRect.w;
      FPaneA.Height := lSplitPosition;

      FPaneB.Left := lContentRect.x;
      FPaneB.Top := lContentRect.y + lSplitPosition + FSplitterSize;
      FPaneB.Width := lContentRect.w;
      FPaneB.Height := Max(0, lContentRect.h - lSplitPosition - FSplitterSize);
    end;
  end;

  FSplitter.Left := lSplitterRect.x;
  FSplitter.Top := lSplitterRect.y;
  FSplitter.Width := lSplitterRect.w;
  FSplitter.Height := lSplitterRect.h;
end;

procedure TNXSplitPanel.Change;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TNXSplitPanel.ParentSizeCallback(NewW, NewH: Integer);
begin
  inherited ParentSizeCallback(NewW, NewH);
  LayoutPanes;
end;

procedure TNXSplitPanel.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited DoMouseDown(X, Y, Button);

  if (Button = mbLeft) and PointInSplitter(X, Y) then
  begin
    FDragging := True;
    CaptureMouse;
    SetSplitFromMouse(X, Y);
  end;
end;

procedure TNXSplitPanel.DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons);
begin
  inherited DoMouseMotion(X, Y, ButtonState);

  if not FDragging then
    Exit;

  if not (mbLeft in ButtonState) then
  begin
    FDragging := False;
    ReleaseMouseCapture;
    Exit;
  end;

  SetSplitFromMouse(X, Y);
end;

procedure TNXSplitPanel.DoMouseUp(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited DoMouseUp(X, Y, Button);

  if FDragging and (Button = mbLeft) then
  begin
    FDragging := False;
    ReleaseMouseCapture;
    SetSplitFromMouse(X, Y);
  end;
end;

procedure TNXSplitPanel.DoMouseExit;
begin
  inherited DoMouseExit;

  if FDragging and not HasMouseCapture then
    FDragging := False;
end;

end.
