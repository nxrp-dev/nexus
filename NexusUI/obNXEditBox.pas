unit obNXEditBox;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Math,
  SysUtils,
  tpNXEvents,
  tpNXPlatform,
  obNXFont,
  obNXElement,
  obNXControl;

type
  TNXEditBox = class(TNXControl)
  private
    FCaretIndex: Integer;
    FMouseSelecting: Boolean;
    FOnChange: TNotifyEvent;
    FPasswordChar: Char;
    FPlaceholder: string;
    FReadOnly: Boolean;
    FSelectionAnchor: Integer;
    FText: string;
    FTextOffsetX: Integer;
    FMaxLength: Integer;

    function GetDisplayText: string;
    function GetHasSelection: Boolean;
    function GetPlaceholderText: string;
    function GetSelectionEnd: Integer;
    function GetSelectionStart: Integer;
    procedure SetCaretIndex(AValue: Integer);
    procedure SetMaxLength(AValue: Integer);
    procedure SetSelectionAnchor(AValue: Integer);
    procedure SetText(const AValue: string);
  protected
    function ClampTextIndex(AValue: Integer): Integer; virtual;
    function GetCaretX: Integer; virtual;
    function GetTextAreaWidth: Integer; virtual;
    function GetTextIndexAtX(AX: Integer): Integer; virtual;
    function GetTextWidth(const AText: string): Integer; virtual;
    function IsControlDown: Boolean; virtual;
    function IsShiftDown: Boolean; virtual;
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
    procedure SelectAll; virtual;
    procedure SetSelection(AAnchorIndex, ACaretIndex: Integer); virtual;

    procedure CursorBackspace; virtual;
    procedure CursorDelete; virtual;
    procedure CursorEnd(ASelecting: Boolean); virtual;
    procedure CursorHome(ASelecting: Boolean); virtual;
    procedure CursorInsert(const AText: string); virtual;
    procedure CursorLeft(ASelecting, AWordJump: Boolean); virtual;
    procedure CursorRight(ASelecting, AWordJump: Boolean); virtual;

    procedure RenderCaret; virtual;
    procedure RenderSelection; virtual;
    procedure RenderTextValue; virtual;
    procedure RenderClient; override;
  public
    constructor Create(AParent: TNXElement); overload; override;

    procedure DoSelected; override;
    procedure DoLostSelected; override;
    procedure DoMouseDoubleClick(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure DoMouseUp(X, Y: Integer; Button: TNXMouseButton); override;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoTextInput(const AText: string); override;

    property CaretIndex: Integer read FCaretIndex write SetCaretIndex;
    property HasSelection: Boolean read GetHasSelection;
    property MaxLength: Integer read FMaxLength write SetMaxLength;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property PasswordChar: Char read FPasswordChar write FPasswordChar;
    property Placeholder: string read FPlaceholder write FPlaceholder;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property SelectionEnd: Integer read GetSelectionEnd;
    property SelectionStart: Integer read GetSelectionStart;
    property Text: string read FText write SetText;
  end;

implementation

const
  cTextMargin = 5;
  cCaretBlinkMS = 500;

constructor TNXEditBox.Create(AParent: TNXElement);
begin
  inherited Create(AParent);
  BackColor := Skin.TextBackColor;
  BorderStyle := BS_Single;
  FCaretIndex := 0;
  FMaxLength := 0;
  FMouseSelecting := False;
  FPasswordChar := #0;
  FPlaceholder := '';
  FReadOnly := False;
  FSelectionAnchor := 0;
  FText := '';
  FTextOffsetX := 0;
end;

function TNXEditBox.ClampTextIndex(AValue: Integer): Integer;
begin
  Result := EnsureRange(AValue, 0, Length(FText));
end;

function TNXEditBox.GetDisplayText: string;
begin
  if FPasswordChar = #0 then
    Result := FText
  else
    Result := StringOfChar(FPasswordChar, Length(FText));
end;

function TNXEditBox.GetHasSelection: Boolean;
begin
  Result := FCaretIndex <> FSelectionAnchor;
end;

function TNXEditBox.GetPlaceholderText: string;
begin
  Result := FPlaceholder;
end;

function TNXEditBox.GetSelectionStart: Integer;
begin
  Result := Min(FCaretIndex, FSelectionAnchor);
end;

function TNXEditBox.GetSelectionEnd: Integer;
begin
  Result := Max(FCaretIndex, FSelectionAnchor);
end;

procedure TNXEditBox.SetCaretIndex(AValue: Integer);
begin
  MoveCaret(AValue, False);
end;

procedure TNXEditBox.SetMaxLength(AValue: Integer);
begin
  FMaxLength := Max(0, AValue);

  if (FMaxLength > 0) and (Length(FText) > FMaxLength) then
    SetText(Copy(FText, 1, FMaxLength));
end;

procedure TNXEditBox.SetSelectionAnchor(AValue: Integer);
begin
  FSelectionAnchor := ClampTextIndex(AValue);
end;

procedure TNXEditBox.SetText(const AValue: string);
begin
  ChangeText(AValue, Min(FCaretIndex, Length(AValue)));
end;

function TNXEditBox.GetCaretX: Integer;
var
  lClientRect: TNXRect;
begin
  lClientRect := ContentRect;
  Result := lClientRect.x + cTextMargin - FTextOffsetX +
    GetTextWidth(Copy(GetDisplayText, 1, FCaretIndex));
end;

function TNXEditBox.GetTextAreaWidth: Integer;
var
  lClientRect: TNXRect;
begin
  lClientRect := ContentRect;
  Result := Max(0, lClientRect.w - (cTextMargin * 2));
end;

function TNXEditBox.GetTextIndexAtX(AX: Integer): Integer;
var
  lDisplayText: string;
  lClientRect: TNXRect;
  lIndex: Integer;
  lLocalX: Integer;
  lMidpoint: Integer;
  lNextWidth: Integer;
  lPriorWidth: Integer;
begin
  lDisplayText := GetDisplayText;
  lClientRect := ContentRect;
  lLocalX := AX - lClientRect.x - cTextMargin + FTextOffsetX;

  if lLocalX <= 0 then
    Exit(0);

  lPriorWidth := 0;
  for lIndex := 1 to Length(lDisplayText) do
  begin
    lNextWidth := GetTextWidth(Copy(lDisplayText, 1, lIndex));
    lMidpoint := lPriorWidth + ((lNextWidth - lPriorWidth) div 2);
    if lLocalX < lMidpoint then
      Exit(lIndex - 1);
    lPriorWidth := lNextWidth;
  end;

  Result := Length(FText);
end;

function TNXEditBox.GetTextWidth(const AText: string): Integer;
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

function TNXEditBox.IsControlDown: Boolean;
begin
  Result := Assigned(GetPlatform) and GetPlatform.IsControlDown;
end;

function TNXEditBox.IsShiftDown: Boolean;
begin
  Result := Assigned(GetPlatform) and GetPlatform.IsShiftDown;
end;

function TNXEditBox.PreviousWordIndex(AIndex: Integer): Integer;
begin
  Result := ClampTextIndex(AIndex);

  while (Result > 0) and (FText[Result] <= ' ') do
    Dec(Result);

  while (Result > 0) and (FText[Result] > ' ') do
    Dec(Result);
end;

function TNXEditBox.NextWordIndex(AIndex: Integer): Integer;
begin
  Result := ClampTextIndex(AIndex);

  while (Result < Length(FText)) and (FText[Result + 1] > ' ') do
    Inc(Result);

  while (Result < Length(FText)) and (FText[Result + 1] <= ' ') do
    Inc(Result);
end;

procedure TNXEditBox.ChangeText(const ANewText: string; ANewCaretIndex: Integer);
var
  lNewText: string;
begin
  lNewText := ANewText;

  if (FMaxLength > 0) and (Length(lNewText) > FMaxLength) then
    lNewText := Copy(lNewText, 1, FMaxLength);

  if FText = lNewText then
  begin
    MoveCaret(ANewCaretIndex, False);
    Exit;
  end;

  FText := lNewText;
  FCaretIndex := ClampTextIndex(ANewCaretIndex);
  FSelectionAnchor := FCaretIndex;
  EnsureCaretVisible;
  DoChanged;
end;

procedure TNXEditBox.ClearSelection;
begin
  FSelectionAnchor := FCaretIndex;
end;

procedure TNXEditBox.CopySelectionToClipboard;
var
  lText: string;
begin
  if (not HasSelection) or (not Assigned(GetPlatform)) then
    Exit;

  lText := Copy(FText, SelectionStart + 1, SelectionEnd - SelectionStart);
  GetPlatform.SetClipboardText(lText);
end;

procedure TNXEditBox.CutSelectionToClipboard;
begin
  if FReadOnly then
    Exit;

  CopySelectionToClipboard;
  DeleteSelection;
end;

procedure TNXEditBox.DeleteSelection;
begin
  if not HasSelection then
    Exit;

  DeleteTextRange(SelectionStart, SelectionEnd);
end;

procedure TNXEditBox.DeleteTextRange(AStartIndex, AEndIndex: Integer);
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

procedure TNXEditBox.DoChanged;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TNXEditBox.EnsureCaretVisible;
var
  lCaretTextWidth: Integer;
  lTextAreaWidth: Integer;
begin
  lTextAreaWidth := GetTextAreaWidth;
  lCaretTextWidth := GetTextWidth(Copy(GetDisplayText, 1, FCaretIndex));

  if lCaretTextWidth - FTextOffsetX > lTextAreaWidth then
    FTextOffsetX := lCaretTextWidth - lTextAreaWidth;

  if lCaretTextWidth - FTextOffsetX < 0 then
    FTextOffsetX := lCaretTextWidth;

  FTextOffsetX := Max(0, FTextOffsetX);
end;

procedure TNXEditBox.InsertText(const AText: string);
var
  lAllowedLength: Integer;
  lInsertText: string;
  lNewText: string;
  lSelectionLength: Integer;
begin
  if FReadOnly or (AText = '') then
    Exit;

  lInsertText := AText;
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
    lNewText := Copy(FText, 1, SelectionStart) + lInsertText +
      Copy(FText, SelectionEnd + 1, Length(FText) - SelectionEnd)
  else
    lNewText := Copy(FText, 1, FCaretIndex) + lInsertText +
      Copy(FText, FCaretIndex + 1, Length(FText) - FCaretIndex);

  ChangeText(lNewText, SelectionStart + Length(lInsertText));
end;

procedure TNXEditBox.MoveCaret(AIndex: Integer; ASelecting: Boolean);
begin
  FCaretIndex := ClampTextIndex(AIndex);

  if not ASelecting then
    FSelectionAnchor := FCaretIndex;

  EnsureCaretVisible;
end;

procedure TNXEditBox.PasteFromClipboard;
var
  lClipboardText: string;
begin
  if FReadOnly or (not Assigned(GetPlatform)) then
    Exit;

  lClipboardText := GetPlatform.GetClipboardText;
  if lClipboardText <> '' then
    InsertText(lClipboardText);
end;

procedure TNXEditBox.SelectAll;
begin
  SetSelection(0, Length(FText));
end;

procedure TNXEditBox.SetSelection(AAnchorIndex, ACaretIndex: Integer);
begin
  FSelectionAnchor := ClampTextIndex(AAnchorIndex);
  FCaretIndex := ClampTextIndex(ACaretIndex);
  EnsureCaretVisible;
end;

procedure TNXEditBox.CursorBackspace;
begin
  if FReadOnly then
    Exit;

  if HasSelection then
    DeleteSelection
  else if FCaretIndex > 0 then
    DeleteTextRange(FCaretIndex - 1, FCaretIndex);
end;

procedure TNXEditBox.CursorDelete;
begin
  if FReadOnly then
    Exit;

  if HasSelection then
    DeleteSelection
  else if FCaretIndex < Length(FText) then
    DeleteTextRange(FCaretIndex, FCaretIndex + 1);
end;

procedure TNXEditBox.CursorEnd(ASelecting: Boolean);
begin
  MoveCaret(Length(FText), ASelecting);
end;

procedure TNXEditBox.CursorHome(ASelecting: Boolean);
begin
  MoveCaret(0, ASelecting);
end;

procedure TNXEditBox.CursorInsert(const AText: string);
begin
  InsertText(AText);
end;

procedure TNXEditBox.CursorLeft(ASelecting, AWordJump: Boolean);
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

procedure TNXEditBox.CursorRight(ASelecting, AWordJump: Boolean);
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

procedure TNXEditBox.RenderCaret;
var
  lCaretX: Integer;
  lClientRect: TNXRect;
  lTop: Integer;
begin
  if (not IsSelected) or HasSelection then
    Exit;

  if (not Assigned(GetPlatform)) or
    (((GetPlatform.GetTicks div cCaretBlinkMS) mod 2) <> 0) then
    Exit;

  lCaretX := AbsLeft + GetCaretX;
  lClientRect := ContentRect;
  lTop := AbsTop + lClientRect.y + ((lClientRect.h - FontHeight) div 2);
  RenderLine(lCaretX, lTop, lCaretX, lTop + FontHeight, ForeColor);
end;

procedure TNXEditBox.RenderSelection;
var
  lClientRect: TNXRect;
  lDisplayText: string;
  lRect: TNXRect;
  lSelectionLeft: Integer;
  lSelectionWidth: Integer;
begin
  if (not IsSelected) or (not HasSelection) then
    Exit;

  lDisplayText := GetDisplayText;
  lClientRect := ContentRect;
  lSelectionLeft := lClientRect.x + cTextMargin - FTextOffsetX +
    GetTextWidth(Copy(lDisplayText, 1, SelectionStart));
  lSelectionWidth := GetTextWidth(Copy(lDisplayText, SelectionStart + 1,
    SelectionEnd - SelectionStart));

  lRect.x := AbsLeft + lSelectionLeft;
  lRect.y := AbsTop + lClientRect.y + ((lClientRect.h - FontHeight) div 2);
  lRect.w := lSelectionWidth;
  lRect.h := FontHeight;
  RenderFilledRect(lRect, Skin.SelectedColor);
end;

procedure TNXEditBox.RenderTextValue;
var
  lClientRect: TNXRect;
  lDisplayText: string;
  lTextY: Integer;
begin
  if (FText = '') and (not IsSelected) then
    lDisplayText := GetPlaceholderText
  else
    lDisplayText := GetDisplayText;

  lClientRect := ContentRect;
  lTextY := lClientRect.y + ((lClientRect.h - FontHeight) div 2);
  RenderText(lDisplayText, lClientRect.x + cTextMargin - FTextOffsetX,
    lTextY, Align_Left);
end;

procedure TNXEditBox.RenderClient;
var
  lFont: TNXFont;
begin
  lFont := Font;
  if lFont = nil then
    Exit;

  EnsureCaretVisible;
  RenderSelection;
  RenderTextValue;
  RenderCaret;
end;

procedure TNXEditBox.DoSelected;
begin
  inherited;
  CurFillColor := BackColor;
  if Assigned(GetPlatform) then
    GetPlatform.StartTextInput;
  EnsureCaretVisible;
end;

procedure TNXEditBox.DoLostSelected;
begin
  inherited;
  CurFillColor := BackColor;
  FMouseSelecting := False;
  ReleaseMouseCapture;
  ClearSelection;
  if Assigned(GetPlatform) then
    GetPlatform.StopTextInput;
end;

procedure TNXEditBox.DoMouseDoubleClick(X, Y: Integer; Button: TNXMouseButton);
var
  lClickedIndex: Integer;
  lEndIndex: Integer;
  lStartIndex: Integer;
  lSelectWhitespace: Boolean;
begin
  inherited DoMouseDoubleClick(X, Y, Button);

  if Button <> mbLeft then
    Exit;

  lClickedIndex := GetTextIndexAtX(X);
  if Length(FText) = 0 then
    Exit;

  lClickedIndex := EnsureRange(lClickedIndex, 0, Length(FText) - 1);
  lSelectWhitespace := FText[lClickedIndex + 1] <= ' ';

  lStartIndex := lClickedIndex;
  while (lStartIndex > 0) and
    ((FText[lStartIndex] <= ' ') = lSelectWhitespace) do
    Dec(lStartIndex);

  lEndIndex := lClickedIndex;
  while (lEndIndex < Length(FText)) and
    ((FText[lEndIndex + 1] <= ' ') = lSelectWhitespace) do
    Inc(lEndIndex);

  FMouseSelecting := False;
  ReleaseMouseCapture;
  SetSelection(lStartIndex, lEndIndex);
end;

procedure TNXEditBox.DoMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  lIndex: Integer;
begin
  inherited DoMouseDown(X, Y, Button);

  if Button <> mbLeft then
    Exit;

  lIndex := GetTextIndexAtX(X);
  FMouseSelecting := True;
  CaptureMouse;

  if IsShiftDown then
    MoveCaret(lIndex, True)
  else
    SetSelection(lIndex, lIndex);
end;

procedure TNXEditBox.DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons);
begin
  inherited DoMouseMotion(X, Y, ButtonState);

  if FMouseSelecting and (mbLeft in ButtonState) then
    MoveCaret(GetTextIndexAtX(X), True)
  else if FMouseSelecting then
  begin
    FMouseSelecting := False;
    ReleaseMouseCapture;
  end;
end;

procedure TNXEditBox.DoMouseUp(X, Y: Integer; Button: TNXMouseButton);
begin
  inherited DoMouseUp(X, Y, Button);

  if Button = mbLeft then
  begin
    FMouseSelecting := False;
    ReleaseMouseCapture;
  end;
end;

procedure TNXEditBox.DoKeyDown(const AEvent: TNXKeyEventData);
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
        DeleteTextRange(PreviousWordIndex(FCaretIndex), FCaretIndex);
      nkDelete:
        DeleteTextRange(FCaretIndex, NextWordIndex(FCaretIndex));
      nkLeft:
        CursorLeft(lShiftDown, True);
      nkRight:
        CursorRight(lShiftDown, True);
      nkHome:
        CursorHome(lShiftDown);
      nkEnd:
        CursorEnd(lShiftDown);
    end;
    Exit;
  end;

  case AEvent.Key of
    nkLeft:
      CursorLeft(lShiftDown, False);
    nkRight:
      CursorRight(lShiftDown, False);
    nkBackspace:
      CursorBackspace;
    nkDelete:
      CursorDelete;
    nkHome:
      CursorHome(lShiftDown);
    nkEnd:
      CursorEnd(lShiftDown);
  end;
end;

procedure TNXEditBox.DoTextInput(const AText: string);
begin
  inherited DoTextInput(AText);
  CursorInsert(AText);
end;

end.
