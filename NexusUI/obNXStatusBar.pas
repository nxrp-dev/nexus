unit obNXStatusBar;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Math,
  fgl,
  tpNXPlatform,
  obNXControl;

type
  TNXStatusBar = class;

  TNXStatusBarPanel = class
  private
    FOwner: TNXStatusBar;
    FText: string;
    FWidth: Integer;
    FTextAlign: TTextAlign;
    FVisible: Boolean;
    procedure SetText(const AValue: string);
    procedure SetWidth(AValue: Integer);
    procedure SetTextAlign(AValue: TTextAlign);
    procedure SetVisible(AValue: Boolean);
  public
    constructor Create(AOwner: TNXStatusBar);

    property Text: string read FText write SetText;
    property Width: Integer read FWidth write SetWidth;
    property TextAlign: TTextAlign read FTextAlign write SetTextAlign;
    property Visible: Boolean read FVisible write SetVisible;
  end;

  TNXStatusBarPanelList = specialize TFPGObjectList<TNXStatusBarPanel>;

  TNXStatusBar = class(TNXControl)
  private
    FPanels: TNXStatusBarPanelList;
    FSimpleText: string;
    FSimplePanel: Boolean;
    FAutoSizeToParent: Boolean;
    FStretchLastPanel: Boolean;
    FOnChange: TNotifyEvent;

    function GetPanelCount: Integer;
    function GetPanel(AIndex: Integer): TNXStatusBarPanel;
    procedure SetSimpleText(const AValue: string);
    procedure SetSimplePanel(AValue: Boolean);
    procedure SetAutoSizeToParent(AValue: Boolean);
    procedure SetStretchLastPanel(AValue: Boolean);
  protected
    procedure DoResize; override;
    procedure RenderClient; override;
    procedure LayoutToParent; virtual;
    procedure Change; virtual;
    procedure PanelChanged(APanel: TNXStatusBarPanel); virtual;
    procedure RenderPanel(const ARect: TNXRect; const AText: string; ATextAlign: TTextAlign); virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;

    function AddPanel(const AText: string = ''; AWidth: Integer = 100): TNXStatusBarPanel;
    procedure ClearPanels;
    procedure ParentSizeCallback(NewW, NewH: Integer); override;

    property PanelCount: Integer read GetPanelCount;
    property Panels[AIndex: Integer]: TNXStatusBarPanel read GetPanel;
    property SimpleText: string read FSimpleText write SetSimpleText;
    property SimplePanel: Boolean read FSimplePanel write SetSimplePanel;
    property AutoSizeToParent: Boolean read FAutoSizeToParent write SetAutoSizeToParent;
    property StretchLastPanel: Boolean read FStretchLastPanel write SetStretchLastPanel;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

constructor TNXStatusBarPanel.Create(AOwner: TNXStatusBar);
begin
  inherited Create;
  FOwner := AOwner;
  FText := '';
  FWidth := 100;
  FTextAlign := Align_Left;
  FVisible := True;
end;

procedure TNXStatusBarPanel.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;

  FText := AValue;

  if Assigned(FOwner) then
    FOwner.PanelChanged(Self);
end;

procedure TNXStatusBarPanel.SetWidth(AValue: Integer);
begin
  AValue := Max(0, AValue);

  if FWidth = AValue then
    Exit;

  FWidth := AValue;

  if Assigned(FOwner) then
    FOwner.PanelChanged(Self);
end;

procedure TNXStatusBarPanel.SetTextAlign(AValue: TTextAlign);
begin
  if FTextAlign = AValue then
    Exit;

  FTextAlign := AValue;

  if Assigned(FOwner) then
    FOwner.PanelChanged(Self);
end;

procedure TNXStatusBarPanel.SetVisible(AValue: Boolean);
begin
  if FVisible = AValue then
    Exit;

  FVisible := AValue;

  if Assigned(FOwner) then
    FOwner.PanelChanged(Self);
end;

constructor TNXStatusBar.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  FPanels := TNXStatusBarPanelList.Create(True);
  FSimpleText := '';
  FSimplePanel := True;
  FAutoSizeToParent := True;
  FStretchLastPanel := True;

  Height := GUI_TitleBarHeight;
  FillStyle := FS_Filled;
  BorderStyle := BS_Single;
  BackColor := Skin.BackColor;
  ForeColor := Skin.ForeColor;
  Selectable := False;

  LayoutToParent;
end;

destructor TNXStatusBar.Destroy;
begin
  FreeAndNil(FPanels);
  inherited Destroy;
end;

function TNXStatusBar.GetPanelCount: Integer;
begin
  Result := FPanels.Count;
end;

function TNXStatusBar.GetPanel(AIndex: Integer): TNXStatusBarPanel;
begin
  Result := FPanels[AIndex];
end;

procedure TNXStatusBar.SetSimpleText(const AValue: string);
begin
  if FSimpleText = AValue then
    Exit;

  FSimpleText := AValue;
  Change;
end;

procedure TNXStatusBar.SetSimplePanel(AValue: Boolean);
begin
  if FSimplePanel = AValue then
    Exit;

  FSimplePanel := AValue;
  Change;
end;

procedure TNXStatusBar.SetAutoSizeToParent(AValue: Boolean);
begin
  if FAutoSizeToParent = AValue then
    Exit;

  FAutoSizeToParent := AValue;
  LayoutToParent;
  Change;
end;

procedure TNXStatusBar.SetStretchLastPanel(AValue: Boolean);
begin
  if FStretchLastPanel = AValue then
    Exit;

  FStretchLastPanel := AValue;
  Change;
end;

procedure TNXStatusBar.DoResize;
begin
  inherited DoResize;
end;

procedure TNXStatusBar.RenderClient;
var
  lContentRect: TNXRect;
  lIndex: Integer;
  lLeft: Integer;
  lPanel: TNXStatusBarPanel;
  lPanelRight: Integer;
  lPanelWidth: Integer;
  lRemainingWidth: Integer;
  lRect: TNXRect;
begin
  inherited RenderClient;

  lContentRect := ContentRect;

  if FSimplePanel or (FPanels.Count = 0) then
  begin
    RenderPanel(lContentRect, FSimpleText, Align_Left);
    Exit;
  end;

  lLeft := lContentRect.x;

  for lIndex := 0 to FPanels.Count - 1 do
  begin
    lPanel := FPanels[lIndex];

    if not lPanel.Visible then
      Continue;

    lPanelWidth := lPanel.Width;

    if FStretchLastPanel then
    begin
      lRemainingWidth := lContentRect.x + lContentRect.w - lLeft;
      lPanelRight := lIndex + 1;

      while (lPanelRight < FPanels.Count) and (not FPanels[lPanelRight].Visible) do
        Inc(lPanelRight);

      if lPanelRight >= FPanels.Count then
        lPanelWidth := Max(0, lRemainingWidth);
    end;

    if lPanelWidth <= 0 then
      Continue;

    lRect := MakeNXRect(lLeft, lContentRect.y, lPanelWidth, lContentRect.h);
    RenderPanel(lRect, lPanel.Text, lPanel.TextAlign);

    Inc(lLeft, lPanelWidth);

    if lLeft >= lContentRect.x + lContentRect.w then
      Break;
  end;
end;

procedure TNXStatusBar.LayoutToParent;
var
  lTop: Integer;
begin
  if (not FAutoSizeToParent) or (Parent = nil) then
    Exit;

  Left := 0;
  if Width <> Parent.Width then
    Width := Parent.Width;

  lTop := Max(0, Parent.Height - Height);
  if Top <> lTop then
    Top := lTop;
end;

procedure TNXStatusBar.Change;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TNXStatusBar.PanelChanged(APanel: TNXStatusBarPanel);
begin
  Change;
end;

procedure TNXStatusBar.RenderPanel(const ARect: TNXRect; const AText: string;
  ATextAlign: TTextAlign);
var
  lAbsRect: TNXRect;
  lTextWidth: Integer;
  lTextX: Integer;
  lTextY: Integer;
begin
  lAbsRect := MakeNXRect(
    AbsLeft + ARect.x,
    AbsTop + ARect.y,
    ARect.w,
    ARect.h
  );

  RenderFilledRect(lAbsRect, BackColor);
  RenderRect(lAbsRect, BorderColor);

  if AText = '' then
    Exit;

  lTextWidth := 0;
  if Assigned(Canvas) and Assigned(Font) then
    lTextWidth := Canvas.TextWidth(AText, Font);

  case ATextAlign of
    Align_Left:
      lTextX := ARect.x + 6;
    Align_Right:
      lTextX := ARect.x + ARect.w - lTextWidth - 6;
    Align_Center:
      lTextX := ARect.x + (ARect.w div 2) - (lTextWidth div 2);
  else
    lTextX := ARect.x + 6;
  end;

  lTextY := ARect.y + ((ARect.h - FontHeight) div 2);
  RenderText(AText, lTextX, lTextY, Align_Left);
end;

function TNXStatusBar.AddPanel(const AText: string; AWidth: Integer): TNXStatusBarPanel;
begin
  Result := TNXStatusBarPanel.Create(Self);
  Result.Text := AText;
  Result.Width := AWidth;

  FPanels.Add(Result);

  if FPanels.Count = 1 then
    FSimplePanel := False;

  Change;
end;

procedure TNXStatusBar.ClearPanels;
begin
  FPanels.Clear;
  Change;
end;

procedure TNXStatusBar.ParentSizeCallback(NewW, NewH: Integer);
begin
  inherited ParentSizeCallback(NewW, NewH);
  LayoutToParent;
end;

end.
