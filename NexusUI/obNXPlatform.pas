unit obNXPlatform;

{$mode objfpc}{$H+}

interface

uses
  tpNXEvents,
  tpNXPlatform,
  tpNXWindow;

type
  TNXPlatform = class
  protected
    function ToNXKey(AKey: LongInt): TNXKey; virtual; abstract;
    function ToNXModifiers(AModifiers: UInt32): TNXModifiers; virtual; abstract;
    function ToNXMouseButton(AButton: UInt8): TNXMouseButton; virtual; abstract;
    function ToNXMouseButtons(AButtonState: UInt32): TNXMouseButtons; virtual; abstract;
    procedure ToNXRect(const ANativeRect; out ADestRect: TNXRect); virtual; abstract;
    procedure ToNativeRect(const ASourceRect: TNXRect; out ANativeRect); virtual; abstract;
  public
    procedure Initialize; virtual; abstract;
    procedure Finalize; virtual; abstract;
    procedure CreateDisplay(const ATitle: AnsiString; AWidth, AHeight: Integer;
      AStartPosition: TNXWindowStartPosition = wspDefault; ALeft: Integer = 0;
      ATop: Integer = 0); virtual; abstract;
    procedure DestroyDisplay; virtual; abstract;
    function PollEvent(out AEvent: TNXEvent): Boolean; virtual; abstract;
    function Renderer: Pointer; virtual; abstract;
    function Window: Pointer; virtual; abstract;
    procedure Present; virtual; abstract;
    procedure GetDisplaySize(out AWidth, AHeight: Integer); virtual; abstract;
    procedure Clear(const AColor: TNXColor); virtual; abstract;
    procedure PushClip(const ARect: TNXRect); virtual; abstract;
    procedure PopClip; virtual; abstract;
    procedure DrawRect(const ARect: TNXRect; const AColor: TNXColor); virtual; abstract;
    procedure FillRect(const ARect: TNXRect; const AColor: TNXColor); virtual; abstract;
    procedure DrawLine(AX0, AY0, AX1, AY1: Integer; const AColor: TNXColor); virtual; abstract;
    procedure DrawText(const AText: string; AX, AY: Integer;
      const AColor: TNXColor; AFont: TNXFontHandle); virtual; abstract;
    function LoadImage(const AFileName: string): TNXImageHandle; virtual; abstract;
    procedure DestroyImage(AImage: TNXImageHandle); virtual; abstract;
    procedure DrawImage(AImage: TNXImageHandle; const ADestRect: TNXRect); virtual; abstract;
    procedure DrawImage(AImage: TNXImageHandle; const ASourceRect,
      ADestRect: TNXRect); virtual; abstract;
    function TextWidth(const AText: string; AFont: TNXFontHandle): Integer; virtual; abstract;
    function GetTicks: UInt32; virtual; abstract;
    function IsControlDown: Boolean; virtual; abstract;
    function IsShiftDown: Boolean; virtual; abstract;
    procedure InitializeFonts; virtual; abstract;
    procedure FinalizeFonts; virtual; abstract;
    function LoadFont(const AFileName: string; ASize: Integer): TNXFontHandle; virtual; abstract;
    procedure DestroyFont(AFont: TNXFontHandle); virtual; abstract;
    function GetFontMetrics(AFont: TNXFontHandle): TNXFontMetrics; virtual; abstract;
    function GetClipboardText: string; virtual; abstract;
    procedure SetClipboardText(const AText: string); virtual; abstract;
    procedure StartTextInput; virtual; abstract;
    procedure StopTextInput; virtual; abstract;
  end;

implementation

end.
