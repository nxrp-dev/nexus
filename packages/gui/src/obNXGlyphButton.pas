unit obNXGlyphButton;

{$mode objfpc}{$H+}

interface

uses
  Math,
  tpNXPlatform,
  obNXButton,
  obNXControl;

type
  TNXGlyphButton = class(TNXButton)
  private
    FFileName: string;
    FFullSrc: Boolean;
    FGlyph: TNXImageHandle;
    FGlyphMargin: Integer;
    FNormalAlpha: Integer;
    FDisabledAlpha: Integer;
    FOwnsGlyph: Boolean;
    FSrcRect: TNXRect;
    FStretch: Boolean;

    procedure ClearGlyph;
    function GetImageAlpha: Integer;
    procedure LoadGlyphFromFile;
    procedure SetDisabledAlpha(AValue: Integer);
    procedure SetFullSrc(AValue: Boolean);
    procedure SetGlyph(AValue: TNXImageHandle);
    procedure SetGlyphMargin(AValue: Integer);
    procedure SetImageAlpha(AValue: Integer);
    procedure SetSrcRect(const AValue: TNXRect);
    procedure SetStretch(AValue: Boolean);
  protected
    function GetGlyphDestRect: TNXRect; virtual;
    procedure RenderGlyph; virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;

    procedure ChildAddedCallback; override;
    procedure LoadFromFile(const AFileName: string);
    procedure Render; override;

    property DisabledAlpha: Integer read FDisabledAlpha write SetDisabledAlpha;
    property FullSrc: Boolean read FFullSrc write SetFullSrc;
    property Glyph: TNXImageHandle read FGlyph write SetGlyph;
    property GlyphMargin: Integer read FGlyphMargin write SetGlyphMargin;
    property ImageAlpha: Integer read GetImageAlpha write SetImageAlpha;
    property SrcRect: TNXRect read FSrcRect write SetSrcRect;
    property Stretch: Boolean read FStretch write SetStretch;
  end;

implementation

constructor TNXGlyphButton.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  Caption := '';
  Width := 24;
  Height := 24;
  FFullSrc := True;
  FGlyphMargin := 3;
  FNormalAlpha := 255;
  FDisabledAlpha := 96;
  FOwnsGlyph := False;
  FStretch := False;
end;

destructor TNXGlyphButton.Destroy;
begin
  ClearGlyph;
  inherited Destroy;
end;

procedure TNXGlyphButton.ChildAddedCallback;
begin
  inherited ChildAddedCallback;
  if (FFileName <> '') and (FGlyph = nil) and Assigned(Canvas) then
    LoadGlyphFromFile;
end;

procedure TNXGlyphButton.ClearGlyph;
begin
  if FOwnsGlyph and (FGlyph <> nil) and Assigned(Canvas) then
    Canvas.DestroyImage(FGlyph);

  FGlyph := nil;
  FOwnsGlyph := False;
end;

function TNXGlyphButton.GetGlyphDestRect: TNXRect;
var
  lContentRect: TNXRect;
  lHeight: Integer;
  lWidth: Integer;
begin
  lContentRect := ContentRect;
  lContentRect.x := lContentRect.x + FGlyphMargin;
  lContentRect.y := lContentRect.y + FGlyphMargin;
  lContentRect.w := Max(0, lContentRect.w - (FGlyphMargin * 2));
  lContentRect.h := Max(0, lContentRect.h - (FGlyphMargin * 2));

  if FStretch then
  begin
    Result := lContentRect;
    Exit;
  end;

  if FFullSrc then
  begin
    Canvas.GetImageSize(FGlyph, lWidth, lHeight);
  end
  else
  begin
    lWidth := FSrcRect.w;
    lHeight := FSrcRect.h;
  end;

  lWidth := Min(lWidth, lContentRect.w);
  lHeight := Min(lHeight, lContentRect.h);

  Result := MakeNXRect(
    lContentRect.x + ((lContentRect.w - lWidth) div 2),
    lContentRect.y + ((lContentRect.h - lHeight) div 2),
    lWidth,
    lHeight
  );
end;

function TNXGlyphButton.GetImageAlpha: Integer;
begin
  Result := FNormalAlpha;
end;

procedure TNXGlyphButton.LoadFromFile(const AFileName: string);
begin
  FFileName := AFileName;
  if Assigned(Canvas) then
    LoadGlyphFromFile;
end;

procedure TNXGlyphButton.LoadGlyphFromFile;
begin
  if (FFileName = '') or (not Assigned(Canvas)) then
    Exit;

  ClearGlyph;
  FGlyph := Canvas.LoadImage(FFileName);
  FOwnsGlyph := True;
end;

procedure TNXGlyphButton.Render;
begin
  inherited Render;
  RenderGlyph;
end;

procedure TNXGlyphButton.RenderGlyph;
var
  lAlpha: Integer;
  lDestRect: TNXRect;
begin
  if (FGlyph = nil) or (not Assigned(Canvas)) then
    Exit;

  lDestRect := LocalRectToAbs(GetGlyphDestRect);
  if (lDestRect.w <= 0) or (lDestRect.h <= 0) then
    Exit;

  if Enabled then
    lAlpha := FNormalAlpha
  else
    lAlpha := FDisabledAlpha;

  if FFullSrc then
    Canvas.DrawImage(FGlyph, lDestRect, lAlpha)
  else
    Canvas.DrawImage(FGlyph, FSrcRect, lDestRect, lAlpha);
end;

procedure TNXGlyphButton.SetDisabledAlpha(AValue: Integer);
begin
  FDisabledAlpha := EnsureRange(AValue, 0, 255);
end;

procedure TNXGlyphButton.SetFullSrc(AValue: Boolean);
begin
  FFullSrc := AValue;
end;

procedure TNXGlyphButton.SetGlyph(AValue: TNXImageHandle);
begin
  ClearGlyph;
  FGlyph := AValue;
  FOwnsGlyph := False;
end;

procedure TNXGlyphButton.SetGlyphMargin(AValue: Integer);
begin
  FGlyphMargin := Max(0, AValue);
end;

procedure TNXGlyphButton.SetImageAlpha(AValue: Integer);
begin
  FNormalAlpha := EnsureRange(AValue, 0, 255);
end;

procedure TNXGlyphButton.SetSrcRect(const AValue: TNXRect);
begin
  FSrcRect := AValue;
end;

procedure TNXGlyphButton.SetStretch(AValue: Boolean);
begin
  FStretch := AValue;
end;

end.
