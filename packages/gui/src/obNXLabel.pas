unit obNXLabel;

{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform,
  obNXControl;

type
  TNXLabel = class(TNXControl)
  private
    FTextA: TTextAlign;
    FVertA: TVertAlign;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    procedure Render; override;

    property TextA: TTextAlign read FTextA write FTextA;
    property VertA: TVertAlign read FVertA write FVertA;
  end;

implementation

constructor TNXLabel.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FillStyle := FS_None;
  CanFocus := False;
  TextA := Align_Left;
  VertA := VAlign_Top;
end;

procedure TNXLabel.Render;
var
  lLeftPoint: Integer;
  lTopPoint: Integer;
begin
  case TextA of
    Align_Left:
      lLeftPoint := 0;
    Align_Right:
      lLeftPoint := Width;
    Align_Center:
      lLeftPoint := Width div 2;
  end;

  case VertA of
    VAlign_Top:
      lTopPoint := 0;
    VAlign_Bottom:
      lTopPoint := Height - FontHeight;
    VAlign_Center:
      lTopPoint := (Height - FontHeight) div 2;
  end;

  RenderText(Caption, lLeftPoint, lTopPoint, TextA);
end;

end.
