unit obNXGroupBox;
{$mode objfpc}{$H+}

interface

uses
  obNXControl,
  obNXPanel,
  obNXTitleBar,
  tpNXLayout,
  tpNXPlatform;

type
  TNXGroupBox = class(TNXPanel)
  private
    FContentPanel: TNXPanel;
    FTitleBar: TNXTitleBar;
  protected
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    constructor Create(const AParent: INXControlParent; const ACaption: string;
      const ARect: TNXRect); overload; override;

    property ContentPanel: TNXPanel read FContentPanel;
    property TitleBar: TNXTitleBar read FTitleBar;
  end;

implementation

constructor TNXGroupBox.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);

  FTitleBar := TNXTitleBar.Create(Self);
  FTitleBar.Align := caTop;
  FTitleBar.BackColor := Skin.TitleBarBackColor;
  FTitleBar.ParentSizeCallback(Width, Height);

  FContentPanel := TNXPanel.Create(Self);
  FContentPanel.Align := caClient;
  FContentPanel.BorderStyle := BS_None;
  FContentPanel.FillStyle := FS_None;
  FContentPanel.CanFocus := False;
end;

constructor TNXGroupBox.Create(const AParent: INXControlParent; const ACaption: string;
  const ARect: TNXRect);
begin
  Create(AParent);
  Caption := ACaption;
  FTitleBar.Caption := ACaption;
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

end.
