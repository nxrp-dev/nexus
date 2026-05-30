unit tpNXPlatform;

interface

uses
  Math;

type
  TNXColor = record
    r: integer;
    g: integer;
    b: integer;
    a: integer;
  end;

  TNXRect = record
    x: Integer;
    y: Integer;
    w: Integer;
    h: Integer;
  end;

  TNXPoint = record
    x: Integer;
    y: Integer;
  end;

  TNXImageHandle = Pointer;
  TNXFontHandle = Pointer;

  TNXFontMetrics = record
    Height: Integer;
    Ascent: Integer;
    Descent: Integer;
    LineSkip: Integer;
    IsMonospace: Boolean;
  end;

type
  TTextAlign = (Align_Left, Align_Center, Align_Right);
  TVertAlign = (VAlign_Top, VAlign_Center, VAlign_Bottom);
  TDirection = (Dir_Horizontal, Dir_Vertical);
  TBorderStyle = (BS_None, BS_Single);
  TFillStyle = (FS_None, FS_Filled);
  TNXMouseButton = (
    mbNone,
    mbLeft,
    mbMiddle,
    mbRight,
    mbX1,
    mbX2
  );
  TNXMouseButtons = set of TNXMouseButton;

const
  GUI_TitleBarHeight = 25;
  GUI_ScrollbarSize = 11;

function MakeNXColor(ARed, AGreen, ABlue, AAlpha: Integer): TNXColor;
function MakeNXPoint(AX, AY: Integer): TNXPoint;
function MakeNXRect(AX, AY, AWidth, AHeight: Integer): TNXRect;
function NXRectRight(const ARect: TNXRect): Integer;
function NXRectBottom(const ARect: TNXRect): Integer;
function NXRectIsEmpty(const ARect: TNXRect): Boolean;
function NXRectContainsPoint(const ARect: TNXRect; AX, AY: Integer): Boolean;
function NXRectIntersect(const ALeft, ARight: TNXRect): TNXRect;

implementation

function MakeNXColor(ARed, AGreen, ABlue, AAlpha: Integer): TNXColor;
begin
  Result.r := ARed;
  Result.g := AGreen;
  Result.b := ABlue;
  Result.a := AAlpha;
end;

function MakeNXPoint(AX, AY: Integer): TNXPoint;
begin
  Result.x := AX;
  Result.y := AY;
end;

function MakeNXRect(AX, AY, AWidth, AHeight: Integer): TNXRect;
begin
  Result.x := AX;
  Result.y := AY;
  Result.w := AWidth;
  Result.h := AHeight;
end;

function NXRectRight(const ARect: TNXRect): Integer;
begin
  Result := ARect.x + ARect.w;
end;

function NXRectBottom(const ARect: TNXRect): Integer;
begin
  Result := ARect.y + ARect.h;
end;

function NXRectIsEmpty(const ARect: TNXRect): Boolean;
begin
  Result := (ARect.w <= 0) or (ARect.h <= 0);
end;

function NXRectContainsPoint(const ARect: TNXRect; AX, AY: Integer): Boolean;
begin
  Result := (not NXRectIsEmpty(ARect)) and
    (AX >= ARect.x) and (AX < NXRectRight(ARect)) and
    (AY >= ARect.y) and (AY < NXRectBottom(ARect));
end;

function NXRectIntersect(const ALeft, ARight: TNXRect): TNXRect;
var
  lBottom: Integer;
  lLeft: Integer;
  lRight: Integer;
  lTop: Integer;
begin
  lLeft := Max(ALeft.x, ARight.x);
  lTop := Max(ALeft.y, ARight.y);
  lRight := Min(NXRectRight(ALeft), NXRectRight(ARight));
  lBottom := Min(NXRectBottom(ALeft), NXRectBottom(ARight));
  Result := MakeNXRect(lLeft, lTop, Max(0, lRight - lLeft),
    Max(0, lBottom - lTop));
end;

end.
