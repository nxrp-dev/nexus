unit obNXPanel;
{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform,
  obNXControl;

type
  TNXPanel = class(TNXControl)
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    constructor Create(const AParent: INXControlParent; const ACaption: string;
      const ARect: TNXRect); overload; virtual;
  end;

implementation

constructor TNXPanel.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  BackColor := Skin.FormBackColor;
  Left := 100;
  Top := 100;
  BorderStyle := BS_Single;
end;

constructor TNXPanel.Create(const AParent: INXControlParent; const ACaption: string;
  const ARect: TNXRect);
begin
  Create(AParent);
  Caption := ACaption;
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

end.
