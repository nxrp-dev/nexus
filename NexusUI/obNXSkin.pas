unit obNXSkin;

{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform;

type
  TNXSkin = class
  private
    FActiveColor: TNXColor;
    FBackColor: TNXColor;
    FBorderColor: TNXColor;
    FForeColor: TNXColor;
    FFormBackColor: TNXColor;
    FFullTransColor: TNXColor;
    FSelectedColor: TNXColor;
    FTextBackColor: TNXColor;
    FTitleBarBackColor: TNXColor;
    FUnselectedTitleBarBackColor: TNXColor;
  public
    constructor Create;

    property ActiveColor: TNXColor read FActiveColor write FActiveColor;
    property BackColor: TNXColor read FBackColor write FBackColor;
    property BorderColor: TNXColor read FBorderColor write FBorderColor;
    property ForeColor: TNXColor read FForeColor write FForeColor;
    property FormBackColor: TNXColor read FFormBackColor write FFormBackColor;
    property FullTransColor: TNXColor read FFullTransColor write FFullTransColor;
    property SelectedColor: TNXColor read FSelectedColor write FSelectedColor;
    property TextBackColor: TNXColor read FTextBackColor write FTextBackColor;
    property TitleBarBackColor: TNXColor read FTitleBarBackColor write FTitleBarBackColor;
    property UnselectedTitleBarBackColor: TNXColor read FUnselectedTitleBarBackColor write FUnselectedTitleBarBackColor;
  end;

implementation

constructor TNXSkin.Create;
begin
  inherited Create;
  FBackColor := MakeNXColor(48, 48, 48, 255);
  FTextBackColor := MakeNXColor(24, 24, 24, 255);
  FForeColor := MakeNXColor(190, 190, 190, 255);
  FBorderColor := MakeNXColor(64, 64, 64, 255);
  FFormBackColor := MakeNXColor(32, 32, 32, 255);
  FTitleBarBackColor := MakeNXColor(24, 24, 64, 255);
  FUnselectedTitleBarBackColor := MakeNXColor(24, 24, 24, 255);
  FSelectedColor := MakeNXColor(24, 24, 64, 255);
  FActiveColor := MakeNXColor(24, 24, 64, 255);
  FFullTransColor := MakeNXColor(0, 0, 0, 0);
end;

end.
