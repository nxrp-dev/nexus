unit obNXPascalSkin;

{$mode objfpc}{$H+}

interface

uses obNXSkin;

type
  TNXPascalSkin = class(TNXSkin)
  public
    constructor Create; override;
  end;

implementation

uses obNXPanelRender, fpg_stylemanager;

constructor TNXPascalSkin.Create;
begin
  inherited Create;
  RegisterRenderer(cNXPanelFrame, TNXPanelFrameRenderer.Create(Colors));
end;

initialization
  fpgStyleManager.RegisterClass('NexusPascal', TNXPascalSkin);

end.
