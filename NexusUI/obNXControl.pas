unit obNXControl;
{$mode objfpc}{$H+}

interface

uses SysUtils, Math, obNXElement, tpNXPlatform, obNXFont;

type
  TNXControl = class(TNXElement)
  private
    FFont: TNXFont;
    FMetricFont: TNXFont;
    FSkinClass: string;
  protected
    FBackColor: TNXColor;
    FForeColor: TNXColor;
    FActiveColor: TNXColor;
    CurFillColor: TNXColor;
    CurBorderColor: TNXColor;
    FFillStyle: TFillStyle;
    FCaption: string;
    FBorderStyle: TBorderStyle;
    FBorderColor: TNXColor;
    FontHeight, FontAscent, FontDescent, FontLineSkip: Integer;
    FontMonospace: Integer;

    procedure SetBackColor(InColor: TNXColor);

    function GetBorderThickness: Integer; virtual;
    function GetAbsContentRect: TNXRect; virtual;
    function GetContentRect: TNXRect; virtual;
    function GetFont: TNXFont; virtual;
    function GetFontForChildren: TNXFont; override;
    procedure SetFont(AFont: TNXFont); virtual;
    procedure UpdateFontMetrics(AFont: TNXFont); virtual;

    procedure SetBorderColor(InColor: TNXColor);

    procedure RenderRect(const Rect: TNXRect; Color: TNXColor); overload;
    procedure RenderFilledRect(const Rect: TNXRect; Color: TNXColor); overload;
    procedure RenderLine(x0, y0, x1, y1: Integer; Color: TNXColor);
    procedure RenderText(TextIn: string; x, y: Integer; Alignment: TTextAlign);
    procedure RenderClient; virtual;
  public
    procedure Render; override;
    procedure ctrl_FontChanged; virtual;

    constructor Create(AParent: TNXElement); overload; override;
    constructor Create(AParent: TNXElement; const ARect: TNXRect); overload; virtual;

    property BackColor: TNXColor read FBackColor write SetBackColor;
    property ActiveColor: TNXColor read FActiveColor write FActiveColor;
    property ForeColor: TNXColor read FForeColor write FForeColor;
    property Font: TNXFont read GetFont write SetFont;
    property BorderStyle: TBorderStyle read FBorderStyle write FBorderStyle;
    property BorderColor: TNXColor read FBorderColor write SetBorderColor;
    property AbsContentRect: TNXRect read GetAbsContentRect;
    property ContentRect: TNXRect read GetContentRect;
    property FillStyle: TFillStyle read FFillStyle write FFillStyle;
    property SkinClass: string read FSkinClass write FSkinClass;
    property Caption: string read FCaption write FCaption;
  end;

implementation

procedure TNXControl.Render;
var
  lRect: TNXRect;
  lClipRect: TNXRect;
begin
  if Visible then
  begin
    lRect := MakeNXRect(AbsLeft, AbsTop, Width, Height);

    case FFillStyle of
      FS_Filled:
        RenderFilledRect(lRect, CurFillColor);
      FS_None:
      begin
      end;
    end;

    lClipRect := AbsContentRect;
    Canvas.PushClip(lClipRect);
    try
      RenderClient;
    finally
      Canvas.PopClip;
    end;

    case FBorderStyle of
      BS_Single:
      begin
        RenderRect(lRect, CurBorderColor);
      end;
    end;
  end;
end;

function TNXControl.GetBorderThickness: Integer;
begin
  case FBorderStyle of
    BS_Single:
      Result := 1;
  else
    Result := 0;
  end;
end;

function TNXControl.GetAbsContentRect: TNXRect;
var
  lBorderThickness: Integer;
begin
  lBorderThickness := GetBorderThickness;
  Result := MakeNXRect(AbsLeft + lBorderThickness, AbsTop + lBorderThickness,
    Max(0, Width - (lBorderThickness * 2)),
    Max(0, Height - (lBorderThickness * 2)));
end;

function TNXControl.GetContentRect: TNXRect;
var
  lBorderThickness: Integer;
begin
  lBorderThickness := GetBorderThickness;
  Result := MakeNXRect(lBorderThickness, lBorderThickness,
    Max(0, Width - (lBorderThickness * 2)),
    Max(0, Height - (lBorderThickness * 2)));
end;

procedure TNXControl.SetBackColor(InColor: TNXColor);
begin
  FBackColor := InColor;
  CurFillColor := InColor;
end;

function TNXControl.GetFont: TNXFont;
begin
  Result := FFont;

  if (Result = nil) and (Parent <> nil) then
    Result := Parent.FontForChildren;

  if FMetricFont <> Result then
    UpdateFontMetrics(Result);
end;

function TNXControl.GetFontForChildren: TNXFont;
begin
  Result := Font;
end;

procedure TNXControl.SetFont(AFont: TNXFont);
begin
  FFont := AFont;
  UpdateFontMetrics(Font);
  ctrl_FontChanged;
end;

procedure TNXControl.UpdateFontMetrics(AFont: TNXFont);
begin
  FMetricFont := AFont;

  if AFont = nil then
  begin
    FontHeight := 0;
    FontAscent := 0;
    FontDescent := 0;
    FontLineSkip := 0;
    FontMonospace := 0;
    Exit;
  end;

  FontHeight := AFont.Height;
  FontAscent := AFont.Ascent;
  FontDescent := AFont.Descent;
  FontLineSkip := AFont.LineSkip;
  FontMonospace := Ord(AFont.IsMonospace);
end;

procedure TNXControl.SetBorderColor(InColor: TNXColor);
begin
  FBorderColor := InColor;
  CurBorderColor := InColor;
end;

procedure TNXControl.RenderRect(const Rect: TNXRect; Color: TNXColor);
begin
  Canvas.DrawRect(Rect, Color);
end;

procedure TNXControl.RenderFilledRect(const Rect: TNXRect; Color: TNXColor);
begin
  Canvas.FillRect(Rect, Color);
end;

procedure TNXControl.RenderLine(x0, y0, x1, y1: Integer; Color: TNXColor);
begin
  Canvas.DrawLine(x0, y0, x1, y1, Color);
end;

procedure TNXControl.RenderText(TextIn: string; x, y: Integer;
  Alignment: TTextAlign);
var
  lNXFont: TNXFont;
  lTextX: Integer;
  lTextWidth: Integer;
begin
  if (not(TextIn <> '')) then
    Exit;

  lNXFont := Font;
  if not Assigned(lNXFont) then
    raise Exception.Create('RenderText called on [' + TextIn + '] but no Font Set');

  lTextWidth := Canvas.TextWidth(TextIn, lNXFont);

  case Alignment of
    Align_Left:
      lTextX := AbsLeft + x;
    Align_Center:
      lTextX := AbsLeft + x - (lTextWidth div 2);
    Align_Right:
      lTextX := AbsLeft + x - lTextWidth;
  end;

  Canvas.DrawText(TextIn, lTextX, AbsTop + y, FForeColor, lNXFont);
end;

procedure TNXControl.RenderClient;
begin

end;

procedure TNXControl.ctrl_FontChanged;
begin

end;

constructor TNXControl.Create(AParent: TNXElement);
begin
  inherited Create(AParent);
  ForeColor := Skin.ForeColor;
  BackColor := Skin.BackColor;
  Width := 256;
  Height := 256;
  Visible := True;
  BorderStyle := BS_None;
  BorderColor := Skin.BorderColor;
  ActiveColor := Skin.ActiveColor;
  FillStyle := FS_Filled;
  SkinClass := '';
end;

constructor TNXControl.Create(AParent: TNXElement; const ARect: TNXRect);
begin
  Create(AParent);
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

end.
