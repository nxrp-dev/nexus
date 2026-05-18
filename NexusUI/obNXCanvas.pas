unit obNXCanvas;

{$mode objfpc}{$H+}

interface

uses
  Math,
  obNXFont,
  obNXPlatform,
  tpNXPlatform;

type
  TNXCanvas = class
  private
    FPlatform: TNXPlatform;

    procedure DrawNineSlicePart(AImage: TNXImageHandle; const ASourceRect,
      ADestRect: TNXRect);
  public
    constructor Create(APlatform: TNXPlatform);

    procedure Clear(const AColor: TNXColor);
    procedure Present;
    procedure PushClip(const ARect: TNXRect);
    procedure PopClip;
    procedure DrawRect(const ARect: TNXRect; const AColor: TNXColor);
    procedure FillRect(const ARect: TNXRect; const AColor: TNXColor);
    procedure DrawLine(AX0, AY0, AX1, AY1: Integer; const AColor: TNXColor);
    procedure DrawText(const AText: string; AX, AY: Integer;
      const AColor: TNXColor; AFont: TNXFont);
    function LoadImage(const AFileName: string): TNXImageHandle;
    procedure DestroyImage(AImage: TNXImageHandle);
    procedure DrawImage(AImage: TNXImageHandle; const ADestRect: TNXRect); overload;
    procedure DrawImage(AImage: TNXImageHandle; const ASourceRect,
      ADestRect: TNXRect); overload;
    procedure DrawNineSlice(AImage: TNXImageHandle; const ASourceRect: TNXRect;
      ALeft, ATop, ARight, ABottom: Integer; const ADestRect: TNXRect);
    function TextWidth(const AText: string; AFont: TNXFont): Integer;

    property Platform: TNXPlatform read FPlatform;
  end;

implementation

constructor TNXCanvas.Create(APlatform: TNXPlatform);
begin
  inherited Create;
  FPlatform := APlatform;
end;

procedure TNXCanvas.Clear(const AColor: TNXColor);
begin
  FPlatform.Clear(AColor);
end;

procedure TNXCanvas.Present;
begin
  FPlatform.Present;
end;

procedure TNXCanvas.PushClip(const ARect: TNXRect);
begin
  FPlatform.PushClip(ARect);
end;

procedure TNXCanvas.PopClip;
begin
  FPlatform.PopClip;
end;

procedure TNXCanvas.DrawRect(const ARect: TNXRect; const AColor: TNXColor);
begin
  FPlatform.DrawRect(ARect, AColor);
end;

procedure TNXCanvas.FillRect(const ARect: TNXRect; const AColor: TNXColor);
begin
  FPlatform.FillRect(ARect, AColor);
end;

procedure TNXCanvas.DrawLine(AX0, AY0, AX1, AY1: Integer;
  const AColor: TNXColor);
begin
  FPlatform.DrawLine(AX0, AY0, AX1, AY1, AColor);
end;

procedure TNXCanvas.DrawText(const AText: string; AX, AY: Integer;
  const AColor: TNXColor; AFont: TNXFont);
begin
  if AFont = nil then
    Exit;

  FPlatform.DrawText(AText, AX, AY, AColor, AFont.Handle);
end;

function TNXCanvas.LoadImage(const AFileName: string): TNXImageHandle;
begin
  Result := FPlatform.LoadImage(AFileName);
end;

procedure TNXCanvas.DestroyImage(AImage: TNXImageHandle);
begin
  FPlatform.DestroyImage(AImage);
end;

procedure TNXCanvas.DrawImage(AImage: TNXImageHandle; const ADestRect: TNXRect);
begin
  FPlatform.DrawImage(AImage, ADestRect);
end;

procedure TNXCanvas.DrawImage(AImage: TNXImageHandle; const ASourceRect,
  ADestRect: TNXRect);
begin
  FPlatform.DrawImage(AImage, ASourceRect, ADestRect);
end;

procedure TNXCanvas.DrawNineSlicePart(AImage: TNXImageHandle;
  const ASourceRect, ADestRect: TNXRect);
begin
  if (ASourceRect.w <= 0) or (ASourceRect.h <= 0) or
    (ADestRect.w <= 0) or (ADestRect.h <= 0) then
    Exit;

  DrawImage(AImage, ASourceRect, ADestRect);
end;

procedure TNXCanvas.DrawNineSlice(AImage: TNXImageHandle;
  const ASourceRect: TNXRect; ALeft, ATop, ARight, ABottom: Integer;
  const ADestRect: TNXRect);
var
  lDestBottom: Integer;
  lDestCenterHeight: Integer;
  lDestCenterWidth: Integer;
  lDestLeft: Integer;
  lDestRight: Integer;
  lDestTop: Integer;
  lSourceBottom: Integer;
  lSourceCenterHeight: Integer;
  lSourceCenterWidth: Integer;
  lSourceLeft: Integer;
  lSourceRight: Integer;
  lSourceTop: Integer;
begin
  if (AImage = nil) or (ASourceRect.w <= 0) or (ASourceRect.h <= 0) or
    (ADestRect.w <= 0) or (ADestRect.h <= 0) then
    Exit;

  lSourceLeft := EnsureRange(ALeft, 0, ASourceRect.w);
  lSourceRight := EnsureRange(ARight, 0, ASourceRect.w - lSourceLeft);
  lSourceTop := EnsureRange(ATop, 0, ASourceRect.h);
  lSourceBottom := EnsureRange(ABottom, 0, ASourceRect.h - lSourceTop);

  lDestLeft := Min(lSourceLeft, ADestRect.w);
  lDestRight := Min(lSourceRight, Max(0, ADestRect.w - lDestLeft));
  lDestTop := Min(lSourceTop, ADestRect.h);
  lDestBottom := Min(lSourceBottom, Max(0, ADestRect.h - lDestTop));

  lSourceCenterWidth := ASourceRect.w - lSourceLeft - lSourceRight;
  lSourceCenterHeight := ASourceRect.h - lSourceTop - lSourceBottom;
  lDestCenterWidth := ADestRect.w - lDestLeft - lDestRight;
  lDestCenterHeight := ADestRect.h - lDestTop - lDestBottom;

  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x, ASourceRect.y, lSourceLeft, lSourceTop),
    MakeNXRect(ADestRect.x, ADestRect.y, lDestLeft, lDestTop));
  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x + lSourceLeft, ASourceRect.y,
      lSourceCenterWidth, lSourceTop),
    MakeNXRect(ADestRect.x + lDestLeft, ADestRect.y,
      lDestCenterWidth, lDestTop));
  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x + ASourceRect.w - lSourceRight, ASourceRect.y,
      lSourceRight, lSourceTop),
    MakeNXRect(ADestRect.x + ADestRect.w - lDestRight, ADestRect.y,
      lDestRight, lDestTop));

  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x, ASourceRect.y + lSourceTop,
      lSourceLeft, lSourceCenterHeight),
    MakeNXRect(ADestRect.x, ADestRect.y + lDestTop,
      lDestLeft, lDestCenterHeight));
  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x + lSourceLeft, ASourceRect.y + lSourceTop,
      lSourceCenterWidth, lSourceCenterHeight),
    MakeNXRect(ADestRect.x + lDestLeft, ADestRect.y + lDestTop,
      lDestCenterWidth, lDestCenterHeight));
  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x + ASourceRect.w - lSourceRight,
      ASourceRect.y + lSourceTop, lSourceRight, lSourceCenterHeight),
    MakeNXRect(ADestRect.x + ADestRect.w - lDestRight,
      ADestRect.y + lDestTop, lDestRight, lDestCenterHeight));

  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x, ASourceRect.y + ASourceRect.h - lSourceBottom,
      lSourceLeft, lSourceBottom),
    MakeNXRect(ADestRect.x, ADestRect.y + ADestRect.h - lDestBottom,
      lDestLeft, lDestBottom));
  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x + lSourceLeft,
      ASourceRect.y + ASourceRect.h - lSourceBottom,
      lSourceCenterWidth, lSourceBottom),
    MakeNXRect(ADestRect.x + lDestLeft,
      ADestRect.y + ADestRect.h - lDestBottom,
      lDestCenterWidth, lDestBottom));
  DrawNineSlicePart(AImage,
    MakeNXRect(ASourceRect.x + ASourceRect.w - lSourceRight,
      ASourceRect.y + ASourceRect.h - lSourceBottom,
      lSourceRight, lSourceBottom),
    MakeNXRect(ADestRect.x + ADestRect.w - lDestRight,
      ADestRect.y + ADestRect.h - lDestBottom,
      lDestRight, lDestBottom));
end;

function TNXCanvas.TextWidth(const AText: string; AFont: TNXFont): Integer;
begin
  Result := 0;
  if AFont = nil then
    Exit;

  Result := FPlatform.TextWidth(AText, AFont.Handle);
end;

end.
