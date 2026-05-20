unit obNXSDL2;

{$mode objfpc}{$H+}

interface

uses
  Math,
  SysUtils,
  SDL2,
  SDL2_image,
  SDL2_TTF,
  obNXPlatform,
  tpNXEvents,
  tpNXPlatform,
  tpNXWindow;

type
  TNXSDL2ClipState = record
    Enabled: Boolean;
    Rect: TSDL_Rect;
  end;

  TNXSDL2 = class(TNXPlatform)
  private
    FImagesInitialized: Boolean;
    FInitialized: Boolean;
    FRenderer: PSDL_Renderer;
    FWindow: PSDL_Window;
    FClipStack: array of TNXSDL2ClipState;
  protected
    function ToNXKey(AKey: LongInt): TNXKey; override;
    function ToNXModifiers(AModifiers: UInt32): TNXModifiers; override;
    function ToNXMouseButton(AButton: UInt8): TNXMouseButton; override;
    function ToNXMouseButtons(AButtonState: UInt32): TNXMouseButtons; override;
    procedure ToNXRect(const ANativeRect; out ADestRect: TNXRect); override;
    procedure ToNativeRect(const ASourceRect: TNXRect; out ANativeRect); override;
  public
    destructor Destroy; override;

    procedure Initialize; override;
    procedure Finalize; override;

    procedure CreateDisplay(const ATitle: AnsiString; AWidth, AHeight: Integer;
      AStartPosition: TNXWindowStartPosition = wspDefault; ALeft: Integer = 0;
      ATop: Integer = 0); override;
    procedure DestroyDisplay; override;

    function PollEvent(out AEvent: TNXEvent): Boolean; override;
    function Renderer: Pointer; override;
    function Window: Pointer; override;
    procedure Present; override;
    procedure GetDisplaySize(out AWidth, AHeight: Integer); override;
    procedure Clear(const AColor: TNXColor); override;
    procedure PushClip(const ARect: TNXRect); override;
    procedure PopClip; override;
    procedure DrawRect(const ARect: TNXRect; const AColor: TNXColor); override;
    procedure FillRect(const ARect: TNXRect; const AColor: TNXColor); override;
    procedure DrawLine(AX0, AY0, AX1, AY1: Integer; const AColor: TNXColor); override;
    procedure DrawText(const AText: string; AX, AY: Integer;
      const AColor: TNXColor; AFont: TNXFontHandle); override;
    function LoadImage(const AFileName: string): TNXImageHandle; override;
    procedure DestroyImage(AImage: TNXImageHandle); override;
    procedure DrawImage(AImage: TNXImageHandle; const ADestRect: TNXRect); override;
    procedure DrawImage(AImage: TNXImageHandle; const ASourceRect,
      ADestRect: TNXRect); override;
    function TextWidth(const AText: string; AFont: TNXFontHandle): Integer; override;
    function GetTicks: UInt32; override;
    function IsControlDown: Boolean; override;
    function IsShiftDown: Boolean; override;
    procedure InitializeFonts; override;
    procedure FinalizeFonts; override;
    function LoadFont(const AFileName: string; ASize: Integer): TNXFontHandle; override;
    procedure DestroyFont(AFont: TNXFontHandle); override;
    function GetFontMetrics(AFont: TNXFontHandle): TNXFontMetrics; override;
    function GetClipboardText: string; override;
    procedure SetClipboardText(const AText: string); override;
    procedure StartTextInput; override;
    procedure StopTextInput; override;
  end;

implementation

function TNXSDL2.ToNXKey(AKey: LongInt): TNXKey;
begin
  case AKey of
    SDLK_BACKSPACE:
      Result := nkBackspace;
    SDLK_DELETE:
      Result := nkDelete;
    SDLK_LEFT:
      Result := nkLeft;
    SDLK_RIGHT:
      Result := nkRight;
    SDLK_UP:
      Result := nkUp;
    SDLK_DOWN:
      Result := nkDown;
    SDLK_HOME:
      Result := nkHome;
    SDLK_END:
      Result := nkEnd;
    SDLK_ESCAPE:
      Result := nkEscape;
    SDLK_RETURN,
    SDLK_KP_ENTER:
      Result := nkEnter;
    SDLK_TAB:
      Result := nkTab;
    SDLK_a:
      Result := nkA;
    SDLK_c:
      Result := nkC;
    SDLK_v:
      Result := nkV;
    SDLK_x:
      Result := nkX;
  else
    Result := nkUnknown;
  end;
end;

function TNXSDL2.ToNXModifiers(AModifiers: UInt32): TNXModifiers;
begin
  Result := [];

  if (AModifiers and KMOD_SHIFT) <> 0 then
    Include(Result, nmShift);
  if (AModifiers and KMOD_CTRL) <> 0 then
    Include(Result, nmControl);
  if (AModifiers and KMOD_ALT) <> 0 then
    Include(Result, nmAlt);
end;

destructor TNXSDL2.Destroy;
begin
  Finalize;
  inherited Destroy;
end;

procedure TNXSDL2.Initialize;
var
  lImageFlags: LongInt;
begin
  if FInitialized then
    Exit;

  if SDL_Init(SDL_INIT_EVERYTHING) <> 0 then
    raise Exception.Create('Unable to initialize SDL: ' + string(SDL_GetError));

  lImageFlags := IMG_INIT_PNG or IMG_INIT_JPG;
  if (IMG_Init(lImageFlags) and lImageFlags) <> lImageFlags then
  begin
    SDL_Quit;
    raise Exception.Create('Unable to initialize images: ' + string(IMG_GetError));
  end;

  FImagesInitialized := True;
  FInitialized := True;
end;

procedure TNXSDL2.Finalize;
begin
  DestroyDisplay;

  if not FInitialized then
    Exit;

  if FImagesInitialized then
  begin
    IMG_Quit;
    FImagesInitialized := False;
  end;

  SDL_Quit;
  FInitialized := False;
end;

procedure TNXSDL2.CreateDisplay(const ATitle: AnsiString; AWidth,
  AHeight: Integer; AStartPosition: TNXWindowStartPosition; ALeft: Integer;
  ATop: Integer);
var
  lFlags: UInt32;
  lWindowLeft: Integer;
  lWindowTop: Integer;
begin
  Initialize;

  lWindowLeft := SDL_WINDOWPOS_CENTERED;
  lWindowTop := SDL_WINDOWPOS_CENTERED;
  lFlags := SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE;

  case AStartPosition of
    wspManual:
    begin
      lWindowLeft := ALeft;
      lWindowTop := ATop;
    end;

    wspTopLeft:
    begin
      lWindowLeft := 0;
      lWindowTop := 0;
    end;

    wspMaximized:
      lFlags := lFlags or SDL_WINDOW_MAXIMIZED;
  else
    lWindowLeft := SDL_WINDOWPOS_CENTERED;
    lWindowTop := SDL_WINDOWPOS_CENTERED;
  end;

  FWindow := SDL_CreateWindow(PChar(ATitle), lWindowLeft, lWindowTop,
    AWidth, AHeight, lFlags);
  if FWindow = nil then
    raise Exception.Create('Unable to create application window: ' +
      string(SDL_GetError));

  FRenderer := SDL_CreateRenderer(FWindow, -1,
    SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);
  if FRenderer = nil then
  begin
    DestroyDisplay;
    raise Exception.Create('Unable to create application renderer: ' +
      string(SDL_GetError));
  end;
end;

procedure TNXSDL2.DestroyDisplay;
begin
  SetLength(FClipStack, 0);

  if FRenderer <> nil then
  begin
    SDL_DestroyRenderer(FRenderer);
    FRenderer := nil;
  end;

  if FWindow <> nil then
  begin
    SDL_DestroyWindow(FWindow);
    FWindow := nil;
  end;
end;

function TNXSDL2.PollEvent(out AEvent: TNXEvent): Boolean;
var
  lEvent: TSDL_Event;
  lMouseX: LongInt;
  lMouseY: LongInt;
begin
  AEvent.EventType := nxeNone;
  Result := SDL_PollEvent(@lEvent) > 0;
  if not Result then
    Exit;

  case lEvent.Type_ of
    SDL_QUITEV:
      AEvent.EventType := nxeQuit;

    SDL_WINDOWEVENT:
    begin
      case lEvent.window.event of
        SDL_WINDOWEVENT_SIZE_CHANGED,
        SDL_WINDOWEVENT_RESIZED:
        begin
          AEvent.EventType := nxeWindowResized;
          AEvent.Window.Width := lEvent.window.data1;
          AEvent.Window.Height := lEvent.window.data2;
        end;
        SDL_WINDOWEVENT_EXPOSED:
          AEvent.EventType := nxeWindowExposed;
      end;
    end;

    SDL_KEYDOWN:
    begin
      AEvent.EventType := nxeKeyDown;
      AEvent.Key.Key := ToNXKey(lEvent.key.keysym.sym);
      AEvent.Key.Modifiers := ToNXModifiers(lEvent.key.keysym.mod_);
      AEvent.Key.Repeat_ := lEvent.key.repeat_ <> 0;
    end;

    SDL_KEYUP:
    begin
      AEvent.EventType := nxeKeyUp;
      AEvent.Key.Key := ToNXKey(lEvent.key.keysym.sym);
      AEvent.Key.Modifiers := ToNXModifiers(lEvent.key.keysym.mod_);
      AEvent.Key.Repeat_ := lEvent.key.repeat_ <> 0;
    end;

    SDL_MOUSEMOTION:
    begin
      AEvent.EventType := nxeMouseMotion;
      AEvent.Mouse.X := lEvent.motion.X;
      AEvent.Mouse.Y := lEvent.motion.Y;
      AEvent.Mouse.ButtonState := ToNXMouseButtons(lEvent.motion.state);
    end;

    SDL_MOUSEBUTTONDOWN:
    begin
      AEvent.EventType := nxeMouseDown;
      AEvent.Mouse.X := lEvent.button.X;
      AEvent.Mouse.Y := lEvent.button.Y;
      AEvent.Mouse.Button := ToNXMouseButton(lEvent.button.button);
    end;

    SDL_MOUSEBUTTONUP:
    begin
      AEvent.EventType := nxeMouseUp;
      AEvent.Mouse.X := lEvent.button.X;
      AEvent.Mouse.Y := lEvent.button.Y;
      AEvent.Mouse.Button := ToNXMouseButton(lEvent.button.button);
    end;

    SDL_MOUSEWHEEL:
    begin
      SDL_GetMouseState(@lMouseX, @lMouseY);
      AEvent.EventType := nxeMouseWheel;
      AEvent.Mouse.X := lMouseX;
      AEvent.Mouse.Y := lMouseY;
      AEvent.Mouse.WheelDeltaX := lEvent.wheel.x;
      AEvent.Mouse.WheelDeltaY := lEvent.wheel.y;
      if lEvent.wheel.direction = SDL_MOUSEWHEEL_FLIPPED then
      begin
        AEvent.Mouse.WheelDeltaX := -AEvent.Mouse.WheelDeltaX;
        AEvent.Mouse.WheelDeltaY := -AEvent.Mouse.WheelDeltaY;
      end;
    end;

    SDL_TEXTINPUT:
    begin
      AEvent.EventType := nxeTextInput;
      AEvent.Text := StrPas(@lEvent.text.Text[0]);
    end;
  end;
end;

function TNXSDL2.Renderer: Pointer;
begin
  Result := FRenderer;
end;

function TNXSDL2.Window: Pointer;
begin
  Result := FWindow;
end;

procedure TNXSDL2.Present;
begin
  if FRenderer <> nil then
    SDL_RenderPresent(FRenderer);
end;

procedure TNXSDL2.GetDisplaySize(out AWidth, AHeight: Integer);
var
  lHeight: LongInt;
  lWidth: LongInt;
begin
  AWidth := 0;
  AHeight := 0;

  if FWindow = nil then
    Exit;

  SDL_GetWindowSize(FWindow, @lWidth, @lHeight);
  AWidth := lWidth;
  AHeight := lHeight;
end;

procedure TNXSDL2.Clear(const AColor: TNXColor);
begin
  if FRenderer = nil then
    Exit;

  SDL_SetRenderDrawColor(FRenderer, AColor.r, AColor.g, AColor.b, AColor.a);
  SDL_RenderClear(FRenderer);
end;

procedure TNXSDL2.PushClip(const ARect: TNXRect);
var
  lBottom: Integer;
  lClipStackLength: Integer;
  lClipState: TNXSDL2ClipState;
  lLeft: Integer;
  lRect: TSDL_Rect;
  lRight: Integer;
  lTop: Integer;
begin
  if FRenderer = nil then
    Exit;

  lClipState.Enabled := SDL_RenderIsClipEnabled(FRenderer) = SDL_TRUE;
  SDL_RenderGetClipRect(FRenderer, @lClipState.Rect);

  lClipStackLength := Length(FClipStack);
  SetLength(FClipStack, lClipStackLength + 1);
  FClipStack[lClipStackLength] := lClipState;

  ToNativeRect(ARect, lRect);
  if lClipState.Enabled then
  begin
    lLeft := Max(lClipState.Rect.x, lRect.x);
    lTop := Max(lClipState.Rect.y, lRect.y);
    lRight := Min(lClipState.Rect.x + lClipState.Rect.w, lRect.x + lRect.w);
    lBottom := Min(lClipState.Rect.y + lClipState.Rect.h, lRect.y + lRect.h);

    lRect.x := lLeft;
    lRect.y := lTop;
    lRect.w := Max(0, lRight - lLeft);
    lRect.h := Max(0, lBottom - lTop);
  end;

  SDL_RenderSetClipRect(FRenderer, @lRect);
end;

procedure TNXSDL2.PopClip;
var
  lClipStackLength: Integer;
  lClipState: TNXSDL2ClipState;
begin
  if FRenderer = nil then
    Exit;

  lClipStackLength := Length(FClipStack);
  if lClipStackLength = 0 then
  begin
    SDL_RenderSetClipRect(FRenderer, nil);
    Exit;
  end;

  lClipState := FClipStack[lClipStackLength - 1];
  SetLength(FClipStack, lClipStackLength - 1);

  if lClipState.Enabled then
    SDL_RenderSetClipRect(FRenderer, @lClipState.Rect)
  else
    SDL_RenderSetClipRect(FRenderer, nil);
end;

procedure TNXSDL2.DrawRect(const ARect: TNXRect; const AColor: TNXColor);
var
  lRect: TSDL_Rect;
begin
  if FRenderer = nil then
    Exit;

  ToNativeRect(ARect, lRect);
  SDL_SetRenderDrawColor(FRenderer, AColor.r, AColor.g, AColor.b, AColor.a);
  SDL_RenderDrawRect(FRenderer, @lRect);
end;

procedure TNXSDL2.FillRect(const ARect: TNXRect; const AColor: TNXColor);
var
  lRect: TSDL_Rect;
begin
  if FRenderer = nil then
    Exit;

  ToNativeRect(ARect, lRect);
  SDL_SetRenderDrawColor(FRenderer, AColor.r, AColor.g, AColor.b, AColor.a);
  SDL_RenderFillRect(FRenderer, @lRect);
end;

procedure TNXSDL2.DrawLine(AX0, AY0, AX1, AY1: Integer;
  const AColor: TNXColor);
begin
  if FRenderer = nil then
    Exit;

  SDL_SetRenderDrawColor(FRenderer, AColor.r, AColor.g, AColor.b, AColor.a);
  SDL_RenderDrawLine(FRenderer, AX0, AY0, AX1, AY1);
end;

procedure TNXSDL2.DrawText(const AText: string; AX, AY: Integer;
  const AColor: TNXColor; AFont: TNXFontHandle);
var
  lColor: TSDL_Color;
  lFont: PTTF_Font;
  lHeight: LongInt;
  lRect: TSDL_Rect;
  lSurface: PSDL_Surface;
  lTexture: PSDL_Texture;
  lWidth: LongInt;
begin
  if (FRenderer = nil) or (AText = '') or (AFont = nil) then
    Exit;

  lFont := PTTF_Font(AFont);
  lWidth := 0;
  lHeight := 0;
  TTF_SizeUTF8(lFont, PChar(AText), @lWidth, @lHeight);

  lRect.x := AX;
  lRect.y := AY;
  lRect.w := lWidth;
  lRect.h := lHeight;

  lColor.r := AColor.r;
  lColor.g := AColor.g;
  lColor.b := AColor.b;
  lColor.a := AColor.a;

  lSurface := TTF_RenderUTF8_Blended(lFont, PChar(AText), lColor);
  if lSurface = nil then
    Exit;

  try
    lTexture := SDL_CreateTextureFromSurface(FRenderer, lSurface);
  finally
    SDL_FreeSurface(lSurface);
  end;

  if lTexture = nil then
    Exit;

  try
    SDL_RenderCopy(FRenderer, lTexture, nil, @lRect);
  finally
    SDL_DestroyTexture(lTexture);
  end;
end;

function TNXSDL2.LoadImage(const AFileName: string): TNXImageHandle;
begin
  Result := nil;
  if (FRenderer = nil) or (AFileName = '') then
    Exit;

  Result := IMG_LoadTexture(FRenderer, PChar(AFileName));
  if Result = nil then
    raise Exception.Create('Unable to load image "' + AFileName + '": ' +
      string(SDL_GetError));
end;

procedure TNXSDL2.DestroyImage(AImage: TNXImageHandle);
begin
  if AImage <> nil then
    SDL_DestroyTexture(PSDL_Texture(AImage));
end;

procedure TNXSDL2.DrawImage(AImage: TNXImageHandle; const ADestRect: TNXRect);
var
  lDestRect: TSDL_Rect;
begin
  if (FRenderer = nil) or (AImage = nil) then
    Exit;

  ToNativeRect(ADestRect, lDestRect);
  SDL_RenderCopy(FRenderer, PSDL_Texture(AImage), nil, @lDestRect);
end;

procedure TNXSDL2.DrawImage(AImage: TNXImageHandle; const ASourceRect,
  ADestRect: TNXRect);
var
  lDestRect: TSDL_Rect;
  lSourceRect: TSDL_Rect;
begin
  if (FRenderer = nil) or (AImage = nil) then
    Exit;

  ToNativeRect(ASourceRect, lSourceRect);
  ToNativeRect(ADestRect, lDestRect);
  SDL_RenderCopy(FRenderer, PSDL_Texture(AImage), @lSourceRect, @lDestRect);
end;

function TNXSDL2.TextWidth(const AText: string; AFont: TNXFontHandle): Integer;
var
  lFont: PTTF_Font;
  lHeight: LongInt;
  lWidth: LongInt;
begin
  Result := 0;

  if (AText = '') or (AFont = nil) then
    Exit;

  lFont := PTTF_Font(AFont);
  lWidth := 0;
  lHeight := 0;
  TTF_SizeUTF8(lFont, PChar(AText), @lWidth, @lHeight);
  Result := lWidth;
end;

function TNXSDL2.GetTicks: UInt32;
begin
  Result := SDL_GetTicks;
end;

function TNXSDL2.IsControlDown: Boolean;
begin
  Result := (SDL_GetModState and KMOD_CTRL) <> 0;
end;

function TNXSDL2.IsShiftDown: Boolean;
begin
  Result := (SDL_GetModState and KMOD_SHIFT) <> 0;
end;

procedure TNXSDL2.InitializeFonts;
begin
  if TTF_WasInit <> 0 then
    Exit;

  if TTF_Init <> 0 then
    raise Exception.Create('Unable to initialize fonts: ' + string(TTF_GetError));
end;

procedure TNXSDL2.FinalizeFonts;
begin
  if TTF_WasInit <> 0 then
    TTF_Quit;
end;

function TNXSDL2.LoadFont(const AFileName: string; ASize: Integer): TNXFontHandle;
begin
  Result := TTF_OpenFont(PChar(AFileName), ASize);
  if Result = nil then
    raise Exception.Create('Unable to load font "' + AFileName + '": ' +
      string(TTF_GetError));
end;

procedure TNXSDL2.DestroyFont(AFont: TNXFontHandle);
begin
  if AFont <> nil then
    TTF_CloseFont(PTTF_Font(AFont));
end;

function TNXSDL2.GetFontMetrics(AFont: TNXFontHandle): TNXFontMetrics;
var
  lFont: PTTF_Font;
begin
  Result.Height := 0;
  Result.Ascent := 0;
  Result.Descent := 0;
  Result.LineSkip := 0;
  Result.IsMonospace := False;

  if AFont = nil then
    Exit;

  lFont := PTTF_Font(AFont);
  Result.Height := TTF_FontHeight(lFont);
  Result.Ascent := TTF_FontAscent(lFont);
  Result.Descent := TTF_FontDescent(lFont);
  Result.LineSkip := TTF_FontLineSkip(lFont);
  Result.IsMonospace := TTF_FontFaceIsFixedWidth(lFont) <> 0;
end;

function TNXSDL2.ToNXMouseButton(AButton: UInt8): TNXMouseButton;
begin
  case AButton of
    SDL_BUTTON_LEFT:
      Result := mbLeft;
    SDL_BUTTON_MIDDLE:
      Result := mbMiddle;
    SDL_BUTTON_RIGHT:
      Result := mbRight;
    SDL_BUTTON_X1:
      Result := mbX1;
    SDL_BUTTON_X2:
      Result := mbX2;
  else
    Result := mbNone;
  end;
end;

function TNXSDL2.ToNXMouseButtons(AButtonState: UInt32): TNXMouseButtons;
begin
  Result := [];

  if (AButtonState and SDL_BUTTON_LMASK) <> 0 then
    Include(Result, mbLeft);
  if (AButtonState and SDL_BUTTON_MMASK) <> 0 then
    Include(Result, mbMiddle);
  if (AButtonState and SDL_BUTTON_RMASK) <> 0 then
    Include(Result, mbRight);
  if (AButtonState and SDL_BUTTON_X1MASK) <> 0 then
    Include(Result, mbX1);
  if (AButtonState and SDL_BUTTON_X2MASK) <> 0 then
    Include(Result, mbX2);
end;

function TNXSDL2.GetClipboardText: string;
var
  lClipboardText: PChar;
begin
  Result := '';

  lClipboardText := SDL_GetClipboardText;
  if lClipboardText = nil then
    Exit;

  try
    Result := StrPas(lClipboardText);
  finally
    SDL_free(lClipboardText);
  end;
end;

procedure TNXSDL2.SetClipboardText(const AText: string);
begin
  SDL_SetClipboardText(PChar(AText));
end;

procedure TNXSDL2.StartTextInput;
begin
  SDL_StartTextInput;
end;

procedure TNXSDL2.StopTextInput;
begin
  SDL_StopTextInput;
end;

procedure TNXSDL2.ToNXRect(const ANativeRect; out ADestRect: TNXRect);
var
  lSourceRect: TSDL_Rect absolute ANativeRect;
begin
  ADestRect.x := lSourceRect.x;
  ADestRect.y := lSourceRect.y;
  ADestRect.w := lSourceRect.w;
  ADestRect.h := lSourceRect.h;
end;

procedure TNXSDL2.ToNativeRect(const ASourceRect: TNXRect; out ANativeRect);
var
  lDestRect: TSDL_Rect absolute ANativeRect;
begin
  lDestRect.x := ASourceRect.x;
  lDestRect.y := ASourceRect.y;
  lDestRect.w := ASourceRect.w;
  lDestRect.h := ASourceRect.h;
end;

end.
