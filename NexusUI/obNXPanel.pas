unit obNXPanel;
{$mode objfpc}{$H+}

interface

uses
  Math,
  tpNXPlatform,
  obNXElement,
  obNXControl;

type
  TNXPanel = class(TNXControl)
  public
    constructor Create(AParent: TNXElement); overload; override;
    constructor Create(AParent: TNXElement; const ACaption: string;
      const ARect: TNXRect); overload; virtual;

    procedure Paint; override;
  end;

implementation

constructor TNXPanel.Create(AParent: TNXElement);
begin
  inherited Create(AParent);

  BackColor := Skin.FormBackColor;
  Left := 100;
  Top := 100;
  BorderStyle := BS_Single;
end;

constructor TNXPanel.Create(AParent: TNXElement; const ACaption: string;
  const ARect: TNXRect);
begin
  Create(AParent);
  Caption := ACaption;
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

procedure TNXPanel.Paint;
var
  lChildClipRect: TNXRect;
  lClipRect: TNXRect;
  lIndex: Integer;
begin
  if Assigned(Canvas) and Visible then
  begin
    lClipRect := MakeNXRect(AbsLeft, AbsTop, Max(0, Width), Max(0, Height));

    Canvas.PushClip(lClipRect);
    try
      Render;

      lChildClipRect := AbsContentRect;
      Canvas.PushClip(lChildClipRect);
      try
        for lIndex := 0 to Children.Count - 1 do
          Children[lIndex].Paint;
      finally
        Canvas.PopClip;
      end;
    finally
      Canvas.PopClip;
    end;
  end;
end;

end.
