unit obNXButton;

{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform,
  obNXElement,
  obNXControl;

type
  TNXButton = class(TNXControl)
  public
    constructor Create(AParent: TNXElement); overload; override;
    procedure Render; override;
    procedure DoMouseEnter; override;
    procedure DoMouseExit; override;
  end;

implementation

constructor TNXButton.Create(AParent: TNXElement);
begin
  inherited Create(AParent);
  BorderStyle := BS_Single;
end;

procedure TNXButton.Render;
begin
  if mbLeft in ButtonStates then
    CurFillColor := ActiveColor
  else
    CurFillColor := BackColor;
  inherited;
  RenderText(Caption, Width div 2, (Height - FontHeight) div 2,
    Align_Center);
end;

procedure TNXButton.DoMouseEnter;
begin
  inherited;
  CurBorderColor := ForeColor;
end;

procedure TNXButton.DoMouseExit;
begin
  inherited;
  CurBorderColor := BorderColor;
end;

end.
