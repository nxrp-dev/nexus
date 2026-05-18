unit obNXCanvas;

{$mode objfpc}{$H+}

interface

uses
  obNXFont,
  obNXPlatform,
  tpNXPlatform;

type
  TNXCanvas = class
  private
    FPlatform: TNXPlatform;
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

function TNXCanvas.TextWidth(const AText: string; AFont: TNXFont): Integer;
begin
  Result := 0;
  if AFont = nil then
    Exit;

  Result := FPlatform.TextWidth(AText, AFont.Handle);
end;

end.
