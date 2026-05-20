unit obNXMemo;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Math,
  SysUtils,
  tpNXEvents,
  tpNXPlatform,
  obNXFont,
  obNXControl,
  obNXScrollableControl,
  obNXScrollBar;

type
  TNXMemo = class(TNXScrollableControl)
  private
    FCaretIndex: Integer;
    FFirstVisibleLine: Integer;
    FLineStarts: array of Integer;
    FMaxLength: Integer;
    FMouseSelecting: Boolean;
    FOnChange: TNotifyEvent;
    FPlaceholder: string;
    FReadOnly: Boolean;
    FSelectionAnchor: Integer;
    FText: string;
    FTextOffsetX: Integer;

    function GetHasSelection: Boolean;
    function GetLineCount: Integer;
    function GetLineStart(ALineIndex: Integer): Integer;
    function GetLineEnd(ALineIndex: Integer): Integer;
    function GetLineText(ALineIndex: Integer): string;
    function GetSelectionEnd: Integer;
    function GetSelectionStart: Integer;
    function GetSelectedText: string;
    procedure SetCaretIndex(AValue: Integer);
    procedure SetMaxLength(AValue: Integer);
    procedure SetText(const AValue: string);
  protected
    function ClampLineIndex(AValue: Integer): Integer; virtual;
    function ClampTextIndex(AValue: Integer): Integer; virtual;
    function GetCaretLineIndex: Integer; virtual;
    function GetCaretX: Integer; virtual;
    function GetIndexAtPoint(AX, AY: Integer): Integer; virtual;
    function GetLineHeight: Integer; virtual;
    function GetLineIndexFromTextIndex(AIndex: Integer): Integer; virtual;
    function GetTextAreaWidth: Integer; virtual;
    function GetTextAreaHeight: Integer; virtual;
    function GetTextIndexAtLineX(ALineIndex, AX: Integer): Integer; virtual;
    function GetTextWidth(const AText: string): Integer; virtual;
    function GetVisibleLineCount: Integer; virtual;
    function NormalizeText(const AText: string): string; virtual;
    function PreviousWordIndex(AIndex: Integer): Integer; virtual;
    function NextWordIndex(AIndex: Integer): Integer; virtual;

    procedure ChangeText(const ANewText: string; ANewCaretIndex: Integer); virtual;
    procedure ClearSelection; virtual;
    procedure CopySelectionToClipboard; virtual;
    procedure CutSelectionToClipboard; virtual;
    procedure DeleteSelection; virtual;
    procedure DeleteTextRange(AStartIndex, AEndIndex: Integer); virtual;
    procedure DoChanged; virtual;
    procedure EnsureCaretVisible; virtual;
    procedure InsertText(const AText: string); virtual;
    procedure MoveCaret(AIndex: Integer; ASelecting: Boolean); virtual;
    procedure PasteFromClipboard; virtual;
    procedure RebuildLineCache; virtual;
    procedure SelectAll; virtual;
    procedure SelectWordAt(AIndex: Integer); virtual;
    procedure SetFirstVisibleLine(AValue: Integer); virtual;
    procedure SetSelection(AAnchorIndex, ACaretIndex: Integer); virtual;
    procedure UpdateScrollBars; override;

    procedure CursorBackspace(AWordJump: Boolean); virtual;
    procedure CursorDelete(AWordJump: Boolean); virtual;
    procedure CursorDown(ASelecting: Boolean); virtual;
    procedure CursorEnd(ASelecting, ADocumentEnd: Boolean); virtual;
    procedure CursorHome(ASelecting, ADocumentHome: Boolean); virtual;
    procedure CursorLeft(ASelecting, AWordJump: Boolean); virtual;
    procedure CursorRight(ASelecting, AWordJump: Boolean); virtual;
    procedure CursorUp(ASelecting: Boolean); virtual;

    procedure RenderCaret; virtual;
    procedure RenderLineText(ALineIndex, ADrawIndex: Integer); virtual;
    procedure RenderPlaceholder; virtual;
    procedure RenderSelection; virtual;
    procedure RenderViewport; override;
  public
    constructor Create(const AParent: INXControlParent); overload; override;

    procedure AddLine(const AText: string); virtual;
    procedure Clear; virtual;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoLoseFocus; override;
    procedure DoMouseDoubleClick(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoFocus; override;
    procedure DoTextInput(const AText: string); override;

    property CaretIndex: Integer read FCaretIndex write SetCaretIndex;
    property FirstVisibleLine: Integer read FFirstVisibleLine write SetFirstVisibleLine;
    property HasSelection: Boolean read GetHasSelection;
    property LineCount: Integer read GetLineCount;
    property MaxLength: Integer read FMaxLength write SetMaxLength;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Placeholder: string read FPlaceholder write FPlaceholder;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property SelectedText: string read GetSelectedText;
    property SelectionEnd: Integer read GetSelectionEnd;
    property SelectionStart: Integer read GetSelectionStart;
    property Text: string read FText write SetText;
  end;

implementation

const
  cTextMargin = 5;
  cCaretBlinkMS = 500;

constructor TNXMemo.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  BackColor := Skin.TextBackColor;
  BorderStyle := BS_Single;
  CanFocus := True;
  FCaretIndex := 0;
  FFirstVisibleLine := 0;
  FMaxLength := 0;
  FMouseSelecting := False;
  FPlaceholder := '';
  FReadOnly := False;
  FSelectionAnchor := 0;
  FText := '';
  FTextOffsetX := 0;
  RebuildLineCache;

end;

function TNXMemo.NormalizeText(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

procedure TNXMemo.RebuildLineCache;
var
  lCount: Integer;
  lIndex: Integer;
begin
  SetLength(FLineStarts, 1);
  FLineStarts[0] := 0;
  lCount := 1;

  for lIndex := 1 to Length(FText) do
  begin
    if FText[lIndex] = #10 then
    begin
      Inc(lCount);
      SetLength(FLineStarts, lCount);
      FLineStarts[lCount - 1] := lIndex;
    end;
  end;
end;

function TNXMemo.GetHasSelection: Boolean;
begin
  Result := FCaretIndex <> FSelectionAnchor;
end;

function TNXMemo.GetLineCount: Integer;
begin
  Result := Length(FLineStarts);
end;

function TNXMemo.ClampLineIndex(AValue: Integer): Integer;
begin
  Result := EnsureRange(AValue, 0, Max(0, LineCount - 1));
end;

function TNXMemo.ClampTextIndex(AValue: Integer): Integer;
begin
  Result := EnsureRange(AValue, 0, Length(FText));
end;

function TNXMemo.GetLineStart(ALineIndex: Integer): Integer;
begin
  Result := FLineStarts[ClampLineIndex(ALineIndex)];
end;

function TNXMemo.GetLineEnd(ALineIndex: Integer): Integer;
var
  lLineIndex: Integer;
begin
  lLineIndex := ClampLineIndex(ALineIndex);

  if lLineIndex < LineCount - 1 then
    Result := FLineStarts[lLineIndex + 1] - 1
  else
    Result := Length(FText);
end;

function TNXMemo.GetLineText(ALineIndex: Integer): string;
var
  lLineEnd: Integer;
  lLineStart: Integer;
begin
  lLineStart := GetLineStart(ALineIndex);
  lLineEnd := GetLineEnd(ALineIndex);
  Result := Copy(FText, lLineStart + 1, lLineEnd - lLineStart);
end;

function TNXMemo.GetSelectionStart: Integer;
begin
  Result := Min(FCaretIndex, FSelectionAnchor);
end;

function TNXMemo.GetSelectionEnd: Integer;
begin
  Result := Max(FCaretIndex, FSelectionAnchor);
end;

function TNXMemo.GetSelectedText: string;
begin
  if HasSelection then
    Result := Copy(FText, SelectionStart + 1, SelectionEnd - SelectionStart)
  else
    Result := '';
end;

procedure TNXMemo.SetCaretIndex(AValue: Integer);
begin
  MoveCaret(AValue, False);
end;

procedure TNXMemo.SetMaxLength(AValue: Integer);
begin
  FMaxLength := Max(0, AValue);

  if (FMaxLength > 0) and (Length(FText) > FMaxLength) then
    SetText(Copy(FText, 1, FMaxLength));
end;

procedure TNXMemo.SetText(const AValue: string);
begin
  ChangeText(NormalizeText(AValue), Min(FCaretIndex, Length(AValue)));
end;

function TNXMemo.GetLineIndexFromTextIndex(AIndex: Integer): Integer;
var
  lIndex: Integer;
  lTextIndex: Integer;
begin
  lTextIndex := ClampTextIndex(AIndex);
  Result := 0;

  for lIndex := LineCount - 1 downto 0 do
  begin
    if lTextIndex >= FLineStarts[lIndex] then
    begin
      Result := lIndex;
      Exit;
    end;
  end;
end;

function TNXMemo.GetCaretLineIndex: Integer;
begin
  Result := GetLineIndexFromTextIndex(FCaretIndex);
end;

function TNXMemo.GetLineHeight: Integer;
begin
  Result := FontLineSkip;
  if Result <= 0 then
    Result := Max(1, FontHeight);
  if Result <= 0 then
    Result := 16;
end;

function TNXMemo.GetVisibleLineCount: Integer;
begin
  Result := GetTextAreaHeight div GetLineHeight;
end;

function TNXMemo.GetTextAreaWidth: Integer;
var
  lClientRect: TNXRect;
begin
  lClientRect := ContentRect;
  lClientRect := ViewportRect;
  Result := Max(0, lClientRect.w - (cTextMargin * 2));

  Result := Max(0, Result);
end;

function TNXMemo.GetTextAreaHeight: Integer;
var
  lClientRect: TNXRect;
begin
  lClientRect := ViewportRect;
  Result := Max(0, lClientRect.h);
end;

function TNXMemo.GetTextWidth(const AText: string): Integer;
var
  lFont: TNXFont;
begin
  Result := 0;

  if AText = '' then
    Exit;

  lFont := Font;
  if (lFont = nil) or (lFont.Handle = nil) or (Canvas = nil) then
    Exit;

  Result := Canvas.TextWidth(AText, lFont);
end;

function TNXMemo.GetCaretX: Integer;
var
  lLineIndex: Integer;
  lLineStart: Integer;
begin
  lLineIndex := GetCaretLineIndex;
  lLineStart := GetLineStart(lLineIndex);
  Result := GetTextWidth(Copy(FText, lLineStart + 1, FCaretIndex - lLineStart));
end;

function TNXMemo.GetTextIndexAtLineX(ALineIndex, AX: Integer): Integer;
var
  lIndex: Integer;
  lLineEnd: Integer;
  lLineStart: Integer;
  lLocalX: Integer;
  lMidpoint: Integer;
  lNextWidth: Integer;
  lPriorWidth: Integer;
  lText: string;
begin
  ALineIndex := ClampLineIndex(ALineIndex);
  lLineStart := GetLineStart(ALineIndex);
  lLineEnd := GetLineEnd(ALineIndex);
  lText := GetLineText(ALineIndex);
  lLocalX := AX + FTextOffsetX;

  if lLocalX <= 0 then
    Exit(lLineStart);

  lPriorWidth := 0;
  for lIndex := 1 to Length(lText) do
  begin
    lNextWidth := GetTextWidth(Copy(lText, 1, lIndex));
    lMidpoint := lPriorWidth + ((lNextWidth - lPriorWidth) div 2);
    if lLocalX < lMidpoint then
      Exit(lLineStart + lIndex - 1);
    lPriorWidth := lNextWidth;
  end;

  Result := lLineEnd;
end;

function TNXMemo.GetIndexAtPoint(AX, AY: Integer): Integer;
var
  lClientRect: TNXRect;
  lLineIndex: Integer;
  lLocalX: Integer;
  lLocalY: Integer;
begin
  lClientRect := ContentRect;
  lLocalX := AX - lClientRect.x - cTextMargin;
  lLocalY := AY - lClientRect.y;
  lLineIndex := FFirstVisibleLine + (lLocalY div GetLineHeight);
  lLineIndex := ClampLineIndex(lLineIndex);
  Result := GetTextIndexAtLineX(lLineIndex, lLocalX);
end;

function TNXMemo.PreviousWordIndex(AIndex: Integer): Integer;
begin
  Result := ClampTextIndex(AIndex);

  while (Result > 0) and (FText[Result] <= ' ') do
    Dec(Result);

  while (Result > 0) and (FText[Result] > ' ') do
    Dec(Result);
end;

function TNXMemo.NextWordIndex(AIndex: Integer): Integer;
begin
  Result := ClampTextIndex(AIndex);

  while (Result < Length(FText)) and (FText[Result + 1] > ' ') do
    Inc(Result);

  while (Result < Length(FText)) and (FText[Result + 1] <= ' ') do
    Inc(Result);
end;

procedure TNXMemo.ChangeText(const ANewText: string; ANewCaretIndex: Integer);
var
  lNewText: string;
begin
  lNewText := NormalizeText(ANewText);

  if (FMaxLength > 0) and (Length(lNewText) > FMaxLength) then
    lNewText := Copy(lNewText, 1, FMaxLength);

  if FText = lNewText then
  begin
    MoveCaret(ANewCaretIndex, False);
    Exit;
  end;

  FText := lNewText;
  RebuildLineCache;
  FCaretIndex := ClampTextIndex(ANewCaretIndex);
  FSelectionAnchor := FCaretIndex;
  EnsureCaretVisible;
  UpdateScrollBars;
  DoChanged;
end;

procedure TNXMemo.ClearSelection;
begin
  FSelectionAnchor := FCaretIndex;
end;

procedure TNXMemo.CopySelectionToClipboard;
begin
  if (not HasSelection) or (not Assigned(GetPlatform)) then
    Exit;

  GetPlatform.SetClipboardText(SelectedText);
end;

procedure TNXMemo.CutSelectionToClipboard;
begin
  if FReadOnly then
    Exit;

  CopySelectionToClipboard;
  DeleteSelection;
end;

procedure TNXMemo.DeleteSelection;
begin
  if HasSelection then
    DeleteTextRange(SelectionStart, SelectionEnd);
end;

procedure TNXMemo.DeleteTextRange(AStartIndex, AEndIndex: Integer);
var
  lEndIndex: Integer;
  lNewText: string;
  lStartIndex: Integer;
begin
  if FReadOnly then
    Exit;

  lStartIndex := ClampTextIndex(Min(AStartIndex, AEndIndex));
  lEndIndex := ClampTextIndex(Max(AStartIndex, AEndIndex));

  if lStartIndex = lEndIndex then
    Exit;

  lNewText := Copy(FText, 1, lStartIndex) +
    Copy(FText, lEndIndex + 1, Length(FText) - lEndIndex);
  ChangeText(lNewText, lStartIndex);
end;

procedure TNXMemo.DoChanged;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TNXMemo.SetFirstVisibleLine(AValue: Integer);
var
  lMaxFirstLine: Integer;
begin
  lMaxFirstLine := Max(0, LineCount - Max(1, GetVisibleLineCount));
  FFirstVisibleLine := EnsureRange(AValue, 0, lMaxFirstLine);

  ScrollY := FFirstVisibleLine;
end;

procedure TNXMemo.EnsureCaretVisible;
var
  lCaretLine: Integer;
  lCaretX: Integer;
  lTextAreaWidth: Integer;
  lVisibleLineCount: Integer;
begin
  lCaretLine := GetCaretLineIndex;
  lVisibleLineCount := Max(1, GetVisibleLineCount);

  if lCaretLine < FFirstVisibleLine then
    SetFirstVisibleLine(lCaretLine)
  else if lCaretLine >= FFirstVisibleLine + lVisibleLineCount then
    SetFirstVisibleLine(lCaretLine - lVisibleLineCount + 1);

  lTextAreaWidth := GetTextAreaWidth;
  lCaretX := GetCaretX;

  if lCaretX - FTextOffsetX > lTextAreaWidth then
    FTextOffsetX := lCaretX - lTextAreaWidth;

  if lCaretX - FTextOffsetX < 0 then
    FTextOffsetX := lCaretX;

  FTextOffsetX := Max(0, FTextOffsetX);
end;

procedure TNXMemo.InsertText(const AText: string);
var
  lAllowedLength: Integer;
  lInsertText: string;
  lNewCaretIndex: Integer;
  lNewText: string;
  lSelectionLength: Integer;
begin
  if FReadOnly or (AText = '') then
    Exit;

  lInsertText := NormalizeText(AText);
  lSelectionLength := SelectionEnd - SelectionStart;

  if FMaxLength > 0 then
  begin
    lAllowedLength := FMaxLength - (Length(FText) - lSelectionLength);
    if lAllowedLength <= 0 then
      Exit;
    if Length(lInsertText) > lAllowedLength then
      lInsertText := Copy(lInsertText, 1, lAllowedLength);
  end;

  if HasSelection then
  begin
    lNewCaretIndex := SelectionStart + Length(lInsertText);
    lNewText := Copy(FText, 1, SelectionStart) + lInsertText +
      Copy(FText, SelectionEnd + 1, Length(FText) - SelectionEnd);
  end
  else
  begin
    lNewCaretIndex := FCaretIndex + Length(lInsertText);
    lNewText := Copy(FText, 1, FCaretIndex) + lInsertText +
      Copy(FText, FCaretIndex + 1, Length(FText) - FCaretIndex);
  end;

  ChangeText(lNewText, lNewCaretIndex);
end;

procedure TNXMemo.MoveCaret(AIndex: Integer; ASelecting: Boolean);
begin
  FCaretIndex := ClampTextIndex(AIndex);

  if not ASelecting then
    FSelectionAnchor := FCaretIndex;

  EnsureCaretVisible;
end;

procedure TNXMemo.PasteFromClipboard;
var
  lClipboardText: string;
begin
  if FReadOnly or (not Assigned(GetPlatform)) then
    Exit;

  lClipboardText := GetPlatform.GetClipboardText;
  if lClipboardText <> '' then
    InsertText(lClipboardText);
end;

procedure TNXMemo.SelectAll;
begin
  SetSelection(0, Length(FText));
end;

procedure TNXMemo.SelectWordAt(AIndex: Integer);
var
  lEndIndex: Integer;
  lSelectWhitespace: Boolean;
  lStartIndex: Integer;
begin
  if FText = '' then
    Exit;

  AIndex := ClampTextIndex(AIndex);
  if AIndex >= Length(FText) then
    AIndex := Length(FText) - 1;

  lStartIndex := AIndex;
  lEndIndex := AIndex;
  lSelectWhitespace := FText[AIndex + 1] <= ' ';

  while (lStartIndex > 0) and ((FText[lStartIndex] <= ' ') = lSelectWhitespace) do
    Dec(lStartIndex);

  while (lEndIndex < Length(FText)) and ((FText[lEndIndex + 1] <= ' ') = lSelectWhitespace) do
    Inc(lEndIndex);

  SetSelection(lStartIndex, lEndIndex);
end;

procedure TNXMemo.SetSelection(AAnchorIndex, ACaretIndex: Integer);
begin
  FSelectionAnchor := ClampTextIndex(AAnchorIndex);
  FCaretIndex := ClampTextIndex(ACaretIndex);
  EnsureCaretVisible;
end;

procedure TNXMemo.UpdateScrollBars;
var
  lMaxScroll: Integer;
begin
  lMaxScroll := Max(0, LineCount - Max(1, GetVisibleLineCount));
  HorizontalScrollBar.Visible := False;
  HorizontalScrollBar.Max := 0;
  HorizontalScrollBar.Value := 0;
  VerticalScrollBar.Max := lMaxScroll;
  VerticalScrollBar.Visible := lMaxScroll > 0;

  if lMaxScroll = 0 then
  begin
    FFirstVisibleLine := 0;
    VerticalScrollBar.Value := 0;
    Exit;
  end;

  if FFirstVisibleLine > lMaxScroll then
    FFirstVisibleLine := lMaxScroll;

  if VerticalScrollBar.Value > lMaxScroll then
    VerticalScrollBar.Value := lMaxScroll;
end;

procedure TNXMemo.CursorBackspace(AWordJump: Boolean);
begin
  if FReadOnly then
    Exit;

  if HasSelection then
    DeleteSelection
  else if AWordJump then
    DeleteTextRange(PreviousWordIndex(FCaretIndex), FCaretIndex)
  else if FCaretIndex > 0 then
    DeleteTextRange(FCaretIndex - 1, FCaretIndex);
end;

procedure TNXMemo.CursorDelete(AWordJump: Boolean);
begin
  if FReadOnly then
    Exit;

  if HasSelection then
    DeleteSelection
  else if AWordJump then
    DeleteTextRange(FCaretIndex, NextWordIndex(FCaretIndex))
  else if FCaretIndex < Length(FText) then
    DeleteTextRange(FCaretIndex, FCaretIndex + 1);
end;

procedure TNXMemo.CursorLeft(ASelecting, AWordJump: Boolean);
begin
  if (not ASelecting) and HasSelection then
  begin
    MoveCaret(SelectionStart, False);
    Exit;
  end;

  if AWordJump then
    MoveCaret(PreviousWordIndex(FCaretIndex), ASelecting)
  else
    MoveCaret(FCaretIndex - 1, ASelecting);
end;

procedure TNXMemo.CursorRight(ASelecting, AWordJump: Boolean);
begin
  if (not ASelecting) and HasSelection then
  begin
    MoveCaret(SelectionEnd, False);
    Exit;
  end;

  if AWordJump then
    MoveCaret(NextWordIndex(FCaretIndex), ASelecting)
  else
    MoveCaret(FCaretIndex + 1, ASelecting);
end;

procedure TNXMemo.CursorUp(ASelecting: Boolean);
var
  lCaretX: Integer;
  lLineIndex: Integer;
begin
  lLineIndex := GetCaretLineIndex;
  if lLineIndex <= 0 then
    Exit;

  lCaretX := GetCaretX;
  MoveCaret(GetTextIndexAtLineX(lLineIndex - 1, lCaretX - FTextOffsetX), ASelecting);
end;

procedure TNXMemo.CursorDown(ASelecting: Boolean);
var
  lCaretX: Integer;
  lLineIndex: Integer;
begin
  lLineIndex := GetCaretLineIndex;
  if lLineIndex >= LineCount - 1 then
    Exit;

  lCaretX := GetCaretX;
  MoveCaret(GetTextIndexAtLineX(lLineIndex + 1, lCaretX - FTextOffsetX), ASelecting);
end;

procedure TNXMemo.CursorHome(ASelecting, ADocumentHome: Boolean);
begin
  if ADocumentHome then
    MoveCaret(0, ASelecting)
  else
    MoveCaret(GetLineStart(GetCaretLineIndex), ASelecting);
end;

procedure TNXMemo.CursorEnd(ASelecting, ADocumentEnd: Boolean);
begin
  if ADocumentEnd then
    MoveCaret(Length(FText), ASelecting)
  else
    MoveCaret(GetLineEnd(GetCaretLineIndex), ASelecting);
end;

procedure TNXMemo.RenderPlaceholder;
var
  lClientRect: TNXRect;
begin
  if (FText <> '') or IsFocused or (FPlaceholder = '') then
    Exit;

  lClientRect := ViewportRect;
  RenderText(FPlaceholder, lClientRect.x + cTextMargin,
    lClientRect.y + ((GetLineHeight - FontHeight) div 2), Align_Left);
end;

procedure TNXMemo.RenderSelection;
var
  lDrawIndex: Integer;
  lLineEnd: Integer;
  lLineIndex: Integer;
  lLineStart: Integer;
  lRect: TNXRect;
  lSelectionEnd: Integer;
  lSelectionStart: Integer;
  lStartX: Integer;
  lEndX: Integer;
  lTextBeforeEnd: string;
  lTextBeforeStart: string;
  lVisibleLineCount: Integer;
begin
  if not HasSelection then
    Exit;

  lSelectionStart := SelectionStart;
  lSelectionEnd := SelectionEnd;
  lVisibleLineCount := GetVisibleLineCount;

  for lDrawIndex := 0 to lVisibleLineCount - 1 do
  begin
    lLineIndex := FFirstVisibleLine + lDrawIndex;
    if lLineIndex >= LineCount then
      Break;

    lLineStart := GetLineStart(lLineIndex);
    lLineEnd := GetLineEnd(lLineIndex);

    if (lSelectionEnd <= lLineStart) or (lSelectionStart >= lLineEnd) then
      Continue;

    lTextBeforeStart := Copy(FText, lLineStart + 1,
      Max(0, Max(lSelectionStart, lLineStart) - lLineStart));
    lTextBeforeEnd := Copy(FText, lLineStart + 1,
      Max(0, Min(lSelectionEnd, lLineEnd) - lLineStart));

    lStartX := GetTextWidth(lTextBeforeStart) - FTextOffsetX;
    lEndX := GetTextWidth(lTextBeforeEnd) - FTextOffsetX;

    if lEndX <= lStartX then
      Continue;

    lRect := MakeNXRect(ViewportRect.x + cTextMargin + lStartX,
      ViewportRect.y + (lDrawIndex * GetLineHeight),
      lEndX - lStartX,
      GetLineHeight);
    RenderFilledRect(lRect, Skin.SelectedColor);
  end;
end;

procedure TNXMemo.RenderLineText(ALineIndex, ADrawIndex: Integer);
var
  lClientRect: TNXRect;
begin
  lClientRect := ViewportRect;
  RenderText(GetLineText(ALineIndex),
    lClientRect.x + cTextMargin - FTextOffsetX,
    lClientRect.y + (ADrawIndex * GetLineHeight) + ((GetLineHeight - FontHeight) div 2),
    Align_Left);
end;

procedure TNXMemo.RenderCaret;
var
  lCaretLine: Integer;
  lCaretX: Integer;
  lClientRect: TNXRect;
  lDrawIndex: Integer;
  lTop: Integer;
begin
  if (not IsFocused) or HasSelection then
    Exit;

  if (not Assigned(GetPlatform)) or
    (((GetPlatform.GetTicks div cCaretBlinkMS) mod 2) <> 0) then
    Exit;

  lCaretLine := GetCaretLineIndex;
  if (lCaretLine < FFirstVisibleLine) or
    (lCaretLine >= FFirstVisibleLine + GetVisibleLineCount) then
    Exit;

  lDrawIndex := lCaretLine - FFirstVisibleLine;
  lClientRect := ViewportRect;
  lCaretX := GetCaretX - FTextOffsetX;
  lTop := lClientRect.y + (lDrawIndex * GetLineHeight) +
    ((GetLineHeight - FontHeight) div 2);

  RenderLine(lClientRect.x + cTextMargin + lCaretX, lTop,
    lClientRect.x + cTextMargin + lCaretX, lTop + FontHeight, ForeColor);
end;

procedure TNXMemo.RenderViewport;
var
  lDrawIndex: Integer;
  lLineIndex: Integer;
  lVisibleLineCount: Integer;
begin
  FFirstVisibleLine := EnsureRange(ScrollY, 0,
    Max(0, LineCount - Max(1, GetVisibleLineCount)));

  RenderPlaceholder;
  RenderSelection;

  lVisibleLineCount := GetVisibleLineCount;
  for lDrawIndex := 0 to lVisibleLineCount - 1 do
  begin
    lLineIndex := FFirstVisibleLine + lDrawIndex;
    if lLineIndex >= LineCount then
      Break;
    RenderLineText(lLineIndex, lDrawIndex);
  end;

  RenderCaret;
end;

procedure TNXMemo.AddLine(const AText: string);
begin
  if FText = '' then
    SetText(AText)
  else
    SetText(FText + #10 + AText);
end;

procedure TNXMemo.Clear;
begin
  SetText('');
end;

procedure TNXMemo.DoFocus;
begin
  inherited DoFocus;
  if Assigned(GetPlatform) then
    GetPlatform.StartTextInput;
end;

procedure TNXMemo.DoLoseFocus;
begin
  inherited DoLoseFocus;
  FMouseSelecting := False;
  ReleaseMouseCapture;
  if Assigned(GetPlatform) then
    GetPlatform.StopTextInput;
end;

procedure TNXMemo.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  lIndex: Integer;
begin
  inherited DoMouseDown(X, Y, Button);

  if Button <> mbLeft then
    Exit;

  lIndex := GetIndexAtPoint(X, Y);
  MoveCaret(lIndex, Assigned(GetPlatform) and GetPlatform.IsShiftDown);
  FMouseSelecting := True;
  CaptureMouse;
end;

procedure TNXMemo.DoMouseDoubleClick(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited DoMouseDoubleClick(X, Y, Button);

  if Button = mbLeft then
    SelectWordAt(GetIndexAtPoint(X, Y));
end;

procedure TNXMemo.DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons);
begin
  inherited DoMouseMotion(X, Y, ButtonState);

  if FMouseSelecting and (mbLeft in ButtonState) then
    MoveCaret(GetIndexAtPoint(X, Y), True);
end;

procedure TNXMemo.DoMouseUp(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited DoMouseUp(X, Y, Button);

  if Button = mbLeft then
  begin
    FMouseSelecting := False;
    ReleaseMouseCapture;
  end;
end;

procedure TNXMemo.DoKeyDown(const AEvent: TNXKeyEventData);
var
  lControlDown: Boolean;
  lShiftDown: Boolean;
begin
  inherited DoKeyDown(AEvent);

  lControlDown := nmControl in AEvent.Modifiers;
  lShiftDown := nmShift in AEvent.Modifiers;

  if lControlDown then
  begin
    case AEvent.Key of
      nkA:
        SelectAll;
      nkC:
        CopySelectionToClipboard;
      nkX:
        CutSelectionToClipboard;
      nkV:
        PasteFromClipboard;
      nkBackspace:
        CursorBackspace(True);
      nkDelete:
        CursorDelete(True);
      nkLeft:
        CursorLeft(lShiftDown, True);
      nkRight:
        CursorRight(lShiftDown, True);
      nkHome:
        CursorHome(lShiftDown, True);
      nkEnd:
        CursorEnd(lShiftDown, True);
    end;
    Exit;
  end;

  case AEvent.Key of
    nkBackspace:
      CursorBackspace(False);
    nkDelete:
      CursorDelete(False);
    nkLeft:
      CursorLeft(lShiftDown, False);
    nkRight:
      CursorRight(lShiftDown, False);
    nkUp:
      CursorUp(lShiftDown);
    nkDown:
      CursorDown(lShiftDown);
    nkHome:
      CursorHome(lShiftDown, False);
    nkEnd:
      CursorEnd(lShiftDown, False);
    nkEnter:
      InsertText(#10);
  end;
end;

procedure TNXMemo.DoTextInput(const AText: string);
begin
  inherited DoTextInput(AText);
  InsertText(AText);
end;

end.
