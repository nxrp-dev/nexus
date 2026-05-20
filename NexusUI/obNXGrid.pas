unit obNXGrid;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Math,
  tpNXEvents,
  tpNXPlatform,
  obNXControl,
  obNXFont,
  obNXScrollableControl;

type
  TNXGridCellAlign = (
    gcaLeft,
    gcaCenter,
    gcaRight
  );

  TNXGridSelectionMode = (
    gsmCell,
    gsmRow
  );

  TNXGridCellEvent = procedure(Sender: TObject; ACol, ARow: Integer) of object;

  TNXGrid = class(TNXScrollableControl)
  private
    FCells: array of string;
    FColCount: Integer;
    FColWidths: array of Integer;
    FDefaultColWidth: Integer;
    FHeaderHeight: Integer;
    FHeaders: array of string;
    FLineCount: Integer;
    FLineHeight: Integer;
    FOnCellActivate: TNXGridCellEvent;
    FOnCellSelected: TNXGridCellEvent;
    FSelectedCol: Integer;
    FSelectedLine: Integer;
    FSelectionMode: TNXGridSelectionMode;
    FShowGridLines: Boolean;
    FShowHeaders: Boolean;
    FTextAlign: TNXGridCellAlign;

    function CellIndex(ACol, ALine: Integer): Integer;
    function GetCell(ACol, ALine: Integer): string;
    function GetColWidth(ACol: Integer): Integer;
    function GetHeader(ACol: Integer): string;
    function GetTotalColWidth: Integer;
    procedure SetCell(ACol, ALine: Integer; const AValue: string);
    procedure SetColCount(AValue: Integer);
    procedure SetColWidth(ACol: Integer; AValue: Integer);
    procedure SetDefaultColWidth(AValue: Integer);
    procedure SetHeader(ACol: Integer; const AValue: string);
    procedure SetHeaderHeight(AValue: Integer);
    procedure SetLineCount(AValue: Integer);
    procedure SetLineHeight(AValue: Integer);
    procedure SetShowHeaders(AValue: Boolean);
  protected
    function CellAt(AX, AY: Integer; out ACol, ALine: Integer): Boolean; virtual;
    function CellRect(ACol, ALine: Integer): TNXRect; virtual;
    function ColLeft(ACol: Integer): Integer; virtual;
    function HeaderRect(ACol: Integer): TNXRect; virtual;
    procedure DoCellActivate(ACol, ALine: Integer); virtual;
    procedure DoCellSelected(ACol, ALine: Integer); virtual;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoMouseDoubleClick(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton); override;
    procedure DrawCell(ACol, ALine: Integer; const ARect: TNXRect); virtual;
    procedure DrawCellText(const AText: string; const ARect: TNXRect;
      AAlign: TNXGridCellAlign); virtual;
    procedure DrawHeader(ACol: Integer; const ARect: TNXRect); virtual;
    procedure RenderViewport; override;
    procedure EnsureSelectedVisible; virtual;
    procedure ResizeStorage(AColCount, ALineCount: Integer); virtual;
    procedure SetSelectedCell(ACol, ALine: Integer); virtual;
    procedure UpdateContentSize; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    procedure Clear; virtual;
    procedure ResizeGrid(AColCount, ALineCount: Integer); virtual;

    property Cells[ACol, ALine: Integer]: string read GetCell write SetCell;
    property ColCount: Integer read FColCount write SetColCount;
    property ColWidths[ACol: Integer]: Integer read GetColWidth write SetColWidth;
    property DefaultColWidth: Integer read FDefaultColWidth write SetDefaultColWidth;
    property HeaderHeight: Integer read FHeaderHeight write SetHeaderHeight;
    property Headers[ACol: Integer]: string read GetHeader write SetHeader;
    property LineCount: Integer read FLineCount write SetLineCount;
    property LineHeight: Integer read FLineHeight write SetLineHeight;
    property OnCellActivate: TNXGridCellEvent read FOnCellActivate write FOnCellActivate;
    property OnCellSelected: TNXGridCellEvent read FOnCellSelected write FOnCellSelected;
    property RowCount: Integer read FLineCount write SetLineCount;
    property RowHeight: Integer read FLineHeight write SetLineHeight;
    property SelectedCol: Integer read FSelectedCol;
    property SelectedLine: Integer read FSelectedLine;
    property SelectedRow: Integer read FSelectedLine;
    property SelectionMode: TNXGridSelectionMode read FSelectionMode write FSelectionMode;
    property ShowGridLines: Boolean read FShowGridLines write FShowGridLines;
    property ShowHeaders: Boolean read FShowHeaders write SetShowHeaders;
    property TextAlign: TNXGridCellAlign read FTextAlign write FTextAlign;
  end;

implementation

const
  cDefaultColWidth = 96;
  cDefaultLineHeight = 22;
  cDefaultHeaderHeight = 22;
  cCellPaddingX = 4;

constructor TNXGrid.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  BorderStyle := BS_Single;
  CanFocus := True;
  FDefaultColWidth := cDefaultColWidth;
  FLineHeight := cDefaultLineHeight;
  FHeaderHeight := cDefaultHeaderHeight;
  FSelectedCol := -1;
  FSelectedLine := -1;
  FSelectionMode := gsmCell;
  FShowGridLines := True;
  FShowHeaders := True;
  FTextAlign := gcaLeft;
end;

function TNXGrid.CellIndex(ACol, ALine: Integer): Integer;
begin
  Result := ALine * FColCount + ACol;
end;

function TNXGrid.GetCell(ACol, ALine: Integer): string;
begin
  if (ACol < 0) or (ACol >= FColCount) or
    (ALine < 0) or (ALine >= FLineCount) then
    Exit('');

  Result := FCells[CellIndex(ACol, ALine)];
end;

procedure TNXGrid.SetCell(ACol, ALine: Integer; const AValue: string);
begin
  if (ACol < 0) or (ACol >= FColCount) or
    (ALine < 0) or (ALine >= FLineCount) then
    Exit;

  FCells[CellIndex(ACol, ALine)] := AValue;
end;

function TNXGrid.GetHeader(ACol: Integer): string;
begin
  if (ACol < 0) or (ACol >= FColCount) then
    Exit('');

  Result := FHeaders[ACol];
end;

procedure TNXGrid.SetHeader(ACol: Integer; const AValue: string);
begin
  if (ACol < 0) or (ACol >= FColCount) then
    Exit;

  FHeaders[ACol] := AValue;
end;

function TNXGrid.GetColWidth(ACol: Integer): Integer;
begin
  if (ACol < 0) or (ACol >= FColCount) then
    Exit(FDefaultColWidth);

  Result := FColWidths[ACol];
end;

procedure TNXGrid.SetColWidth(ACol: Integer; AValue: Integer);
begin
  if (ACol < 0) or (ACol >= FColCount) then
    Exit;

  FColWidths[ACol] := Max(8, AValue);
  UpdateContentSize;
end;

procedure TNXGrid.SetDefaultColWidth(AValue: Integer);
var
  lIndex: Integer;
  lOldDefault: Integer;
begin
  AValue := Max(8, AValue);
  if FDefaultColWidth = AValue then
    Exit;

  lOldDefault := FDefaultColWidth;
  FDefaultColWidth := AValue;

  for lIndex := 0 to FColCount - 1 do
    if FColWidths[lIndex] = lOldDefault then
      FColWidths[lIndex] := FDefaultColWidth;

  UpdateContentSize;
end;

procedure TNXGrid.SetHeaderHeight(AValue: Integer);
begin
  FHeaderHeight := Max(0, AValue);
  UpdateContentSize;
end;

procedure TNXGrid.SetLineHeight(AValue: Integer);
begin
  FLineHeight := Max(8, AValue);
  UpdateContentSize;
end;

procedure TNXGrid.SetShowHeaders(AValue: Boolean);
begin
  if FShowHeaders = AValue then
    Exit;

  FShowHeaders := AValue;
  UpdateContentSize;
end;

procedure TNXGrid.SetColCount(AValue: Integer);
begin
  ResizeStorage(Max(0, AValue), FLineCount);
end;

procedure TNXGrid.SetLineCount(AValue: Integer);
begin
  ResizeStorage(FColCount, Max(0, AValue));
end;

procedure TNXGrid.ResizeGrid(AColCount, ALineCount: Integer);
begin
  ResizeStorage(Max(0, AColCount), Max(0, ALineCount));
end;

procedure TNXGrid.ResizeStorage(AColCount, ALineCount: Integer);
var
  lCol: Integer;
  lLine: Integer;
  lOldCells: array of string;
  lOldColCount: Integer;
  lOldColWidths: array of Integer;
  lOldHeaders: array of string;
  lOldLineCount: Integer;
begin
  if (AColCount = FColCount) and (ALineCount = FLineCount) then
    Exit;

  lOldColCount := FColCount;
  lOldLineCount := FLineCount;
  lOldCells := Copy(FCells, 0, Length(FCells));
  lOldHeaders := Copy(FHeaders, 0, Length(FHeaders));
  lOldColWidths := Copy(FColWidths, 0, Length(FColWidths));

  FColCount := AColCount;
  FLineCount := ALineCount;

  SetLength(FCells, FColCount * FLineCount);
  SetLength(FHeaders, FColCount);
  SetLength(FColWidths, FColCount);

  for lCol := 0 to FColCount - 1 do
  begin
    if lCol < lOldColCount then
    begin
      FHeaders[lCol] := lOldHeaders[lCol];
      FColWidths[lCol] := lOldColWidths[lCol];
    end
    else
      FColWidths[lCol] := FDefaultColWidth;
  end;

  for lLine := 0 to Min(FLineCount, lOldLineCount) - 1 do
    for lCol := 0 to Min(FColCount, lOldColCount) - 1 do
      FCells[CellIndex(lCol, lLine)] :=
        lOldCells[lLine * lOldColCount + lCol];

  if (FSelectedCol >= FColCount) or (FSelectedLine >= FLineCount) then
  begin
    FSelectedCol := -1;
    FSelectedLine := -1;
  end;

  UpdateContentSize;
end;

procedure TNXGrid.Clear;
var
  lIndex: Integer;
begin
  for lIndex := 0 to Length(FCells) - 1 do
    FCells[lIndex] := '';
end;

function TNXGrid.GetTotalColWidth: Integer;
var
  lIndex: Integer;
begin
  Result := 0;
  for lIndex := 0 to FColCount - 1 do
    Inc(Result, FColWidths[lIndex]);
end;

procedure TNXGrid.UpdateContentSize;
var
  lHeaderHeight: Integer;
begin
  if FShowHeaders then
    lHeaderHeight := FHeaderHeight
  else
    lHeaderHeight := 0;

  ContentWidth := GetTotalColWidth;
  ContentHeight := lHeaderHeight + FLineCount * FLineHeight;
end;

function TNXGrid.ColLeft(ACol: Integer): Integer;
var
  lIndex: Integer;
begin
  Result := 0;
  for lIndex := 0 to ACol - 1 do
    Inc(Result, FColWidths[lIndex]);
end;

function TNXGrid.CellRect(ACol, ALine: Integer): TNXRect;
var
  lHeaderHeight: Integer;
begin
  if FShowHeaders then
    lHeaderHeight := FHeaderHeight
  else
    lHeaderHeight := 0;

  Result.x := ViewportRect.x + ColLeft(ACol) - ScrollX;
  Result.y := ViewportRect.y + lHeaderHeight + ALine * FLineHeight - ScrollY;
  Result.w := GetColWidth(ACol);
  Result.h := FLineHeight;
end;

function TNXGrid.HeaderRect(ACol: Integer): TNXRect;
begin
  Result.x := ViewportRect.x + ColLeft(ACol) - ScrollX;
  Result.y := ViewportRect.y;
  Result.w := GetColWidth(ACol);
  Result.h := FHeaderHeight;
end;

function TNXGrid.CellAt(AX, AY: Integer; out ACol, ALine: Integer): Boolean;
var
  lCol: Integer;
  lContentX: Integer;
  lContentY: Integer;
  lHeaderHeight: Integer;
  lLeft: Integer;
  lViewportRect: TNXRect;
begin
  Result := False;
  ACol := -1;
  ALine := -1;

  lViewportRect := ViewportRect;
  if (AX < lViewportRect.x) or (AX >= lViewportRect.x + lViewportRect.w) or
    (AY < lViewportRect.y) or (AY >= lViewportRect.y + lViewportRect.h) then
    Exit;

  lContentX := AX - lViewportRect.x + ScrollX;
  lContentY := AY - lViewportRect.y + ScrollY;

  if FShowHeaders then
    lHeaderHeight := FHeaderHeight
  else
    lHeaderHeight := 0;

  if lContentY < lHeaderHeight then
    Exit;

  ALine := (lContentY - lHeaderHeight) div FLineHeight;
  if (ALine < 0) or (ALine >= FLineCount) then
    Exit;

  lLeft := 0;
  for lCol := 0 to FColCount - 1 do
  begin
    if (lContentX >= lLeft) and (lContentX < lLeft + FColWidths[lCol]) then
    begin
      ACol := lCol;
      Result := True;
      Exit;
    end;
    Inc(lLeft, FColWidths[lCol]);
  end;
end;

procedure TNXGrid.EnsureSelectedVisible;
var
  lCellLeft: Integer;
  lCellRight: Integer;
  lCellTop: Integer;
  lCellBottom: Integer;
  lHeaderHeight: Integer;
  lVisibleHeight: Integer;
begin
  if (FSelectedCol < 0) or (FSelectedLine < 0) then
    Exit;

  if FShowHeaders then
    lHeaderHeight := FHeaderHeight
  else
    lHeaderHeight := 0;

  lVisibleHeight := Max(0, ViewportHeight - lHeaderHeight);

  lCellLeft := ColLeft(FSelectedCol);
  lCellRight := lCellLeft + GetColWidth(FSelectedCol);
  lCellTop := FSelectedLine * FLineHeight;
  lCellBottom := lCellTop + FLineHeight;

  if lCellLeft < ScrollX then
    ScrollX := lCellLeft
  else if lCellRight > ScrollX + ViewportWidth then
    ScrollX := lCellRight - ViewportWidth;

  if lCellTop < ScrollY then
    ScrollY := lCellTop
  else if lCellBottom > ScrollY + lVisibleHeight then
    ScrollY := lCellBottom - lVisibleHeight;
end;

procedure TNXGrid.SetSelectedCell(ACol, ALine: Integer);
begin
  if (ACol < 0) or (ACol >= FColCount) or
    (ALine < 0) or (ALine >= FLineCount) then
    Exit;

  if (FSelectedCol = ACol) and (FSelectedLine = ALine) then
    Exit;

  FSelectedCol := ACol;
  FSelectedLine := ALine;
  EnsureSelectedVisible;
  DoCellSelected(ACol, ALine);
end;

procedure TNXGrid.DoCellSelected(ACol, ALine: Integer);
begin
  if Assigned(FOnCellSelected) then
    FOnCellSelected(Self, ACol, ALine);
end;

procedure TNXGrid.DoCellActivate(ACol, ALine: Integer);
begin
  if Assigned(FOnCellActivate) then
    FOnCellActivate(Self, ACol, ALine);
end;

procedure TNXGrid.DoMouseDown(AX, AY: Integer; AButton: TNXMouseButton);
var
  lCol: Integer;
  lLine: Integer;
begin
  inherited DoMouseDown(AX, AY, AButton);

  if AButton <> mbLeft then
    Exit;

  if CellAt(AX, AY, lCol, lLine) then
    SetSelectedCell(lCol, lLine);
end;

procedure TNXGrid.DoMouseDoubleClick(AX, AY: Integer; AButton: TNXMouseButton);
var
  lCol: Integer;
  lLine: Integer;
begin
  inherited DoMouseDoubleClick(AX, AY, AButton);

  if AButton <> mbLeft then
    Exit;

  if CellAt(AX, AY, lCol, lLine) then
    DoCellActivate(lCol, lLine);
end;

procedure TNXGrid.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lCol: Integer;
  lLine: Integer;
begin
  inherited DoKeyDown(AEvent);

  if (FColCount = 0) or (FLineCount = 0) then
    Exit;

  lCol := FSelectedCol;
  lLine := FSelectedLine;
  if lCol < 0 then
    lCol := 0;
  if lLine < 0 then
    lLine := 0;

  case AEvent.Key of
    nkLeft:
      lCol := Max(0, lCol - 1);
    nkRight:
      lCol := Min(FColCount - 1, lCol + 1);
    nkUp:
      lLine := Max(0, lLine - 1);
    nkDown:
      lLine := Min(FLineCount - 1, lLine + 1);
    nkHome:
      lCol := 0;
    nkEnd:
      lCol := FColCount - 1;
    nkEnter:
    begin
      if (FSelectedCol >= 0) and (FSelectedLine >= 0) then
        DoCellActivate(FSelectedCol, FSelectedLine);
      Exit;
    end;
  else
    Exit;
  end;

  SetSelectedCell(lCol, lLine);
end;

procedure TNXGrid.DrawCellText(const AText: string; const ARect: TNXRect;
  AAlign: TNXGridCellAlign);
var
  lFont: TNXFont;
  lTextWidth: Integer;
  lTextX: Integer;
  lTextY: Integer;
begin
  if AText = '' then
    Exit;

  lFont := Font;
  if not Assigned(lFont) then
    Exit;

  lTextWidth := Canvas.TextWidth(AText, lFont);
  case AAlign of
    gcaCenter:
      lTextX := ARect.x + (ARect.w div 2) - (lTextWidth div 2);
    gcaRight:
      lTextX := ARect.x + ARect.w - lTextWidth - cCellPaddingX;
  else
    lTextX := ARect.x + cCellPaddingX;
  end;

  lTextY := ARect.y + Max(0, (ARect.h - FontHeight) div 2);
  Canvas.DrawText(AText, AbsLeft + lTextX, AbsTop + lTextY, ForeColor, lFont);
end;

procedure TNXGrid.DrawHeader(ACol: Integer; const ARect: TNXRect);
begin
  RenderFilledRect(ARect, Skin.BackColor);
  DrawCellText(Headers[ACol], ARect, gcaLeft);

  if FShowGridLines then
  begin
    RenderLine(ARect.x, ARect.y + ARect.h - 1,
      ARect.x + ARect.w, ARect.y + ARect.h - 1, Skin.BorderColor);
    RenderLine(ARect.x + ARect.w - 1, ARect.y,
      ARect.x + ARect.w - 1, ARect.y + ARect.h, Skin.BorderColor);
  end;
end;

procedure TNXGrid.DrawCell(ACol, ALine: Integer; const ARect: TNXRect);
var
  lSelected: Boolean;
begin
  lSelected := (FSelectedLine = ALine) and
    ((FSelectionMode = gsmRow) or (FSelectedCol = ACol));

  if lSelected then
    RenderFilledRect(ARect, Skin.SelectedColor)
  else
    RenderFilledRect(ARect, Skin.TextBackColor);

  DrawCellText(Cells[ACol, ALine], ARect, FTextAlign);

  if FShowGridLines then
  begin
    RenderLine(ARect.x, ARect.y + ARect.h - 1,
      ARect.x + ARect.w, ARect.y + ARect.h - 1, Skin.BorderColor);
    RenderLine(ARect.x + ARect.w - 1, ARect.y,
      ARect.x + ARect.w - 1, ARect.y + ARect.h, Skin.BorderColor);
  end;
end;

procedure TNXGrid.RenderViewport;
var
  lCol: Integer;
  lFirstLine: Integer;
  lHeaderHeight: Integer;
  lLastLine: Integer;
  lLine: Integer;
  lRect: TNXRect;
  lViewportBottom: Integer;
  lViewportRight: Integer;
begin
  UpdateContentSize;

  if FShowHeaders then
    lHeaderHeight := FHeaderHeight
  else
    lHeaderHeight := 0;

  lViewportRight := ViewportRect.x + ViewportWidth;
  lViewportBottom := ViewportRect.y + ViewportHeight;

  if FShowHeaders then
    for lCol := 0 to FColCount - 1 do
    begin
      lRect := HeaderRect(lCol);
      if (lRect.x + lRect.w <= ViewportRect.x) or
        (lRect.x >= lViewportRight) then
        Continue;
      DrawHeader(lCol, lRect);
    end;

  if FLineHeight <= 0 then
    Exit;

  lFirstLine := Max(0, ScrollY div FLineHeight);
  lLastLine := Min(FLineCount - 1,
    (ScrollY + ViewportHeight - lHeaderHeight) div FLineHeight + 1);

  for lLine := lFirstLine to lLastLine do
    for lCol := 0 to FColCount - 1 do
    begin
      lRect := CellRect(lCol, lLine);
      if (lRect.x + lRect.w <= ViewportRect.x) or
        (lRect.x >= lViewportRight) or
        (lRect.y + lRect.h <= ViewportRect.y + lHeaderHeight) or
        (lRect.y >= lViewportBottom) then
        Continue;
      DrawCell(lCol, lLine, lRect);
    end;
end;

end.
