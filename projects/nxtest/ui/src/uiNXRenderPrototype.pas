unit uiNXRenderPrototype;

{$mode objfpc}{$H+}

interface

procedure RunNXRenderPrototype(const ABackend: string);

implementation

uses
  Classes, SysUtils, TypInfo, fpg_base, fpg_main, fpg_form, fpg_panel,
  fpg_button, fpg_label, fpg_stylemanager, obNXSkin, obNXLuaSkin,
  obNXPascalSkin, obNXRenderPanel;

type
  TNXRenderPrototypeForm = class(TfpgForm)
  public
    procedure AfterCreate; override;
  end;

procedure TNXRenderPrototypeForm.AfterCreate;
var
  lStyle: TPanelStyle;
  lBorder: TPanelBorder;
  lPanel: TfpgPanel;
  lChild: TfpgButton;
  lLabel: TfpgLabel;
begin
  SetPosition(120, 120, 710, 520);
  WindowTitle := 'Panel render subscriptions - ' + ParamStr(2);
  BackgroundColor := $FF263747;
  lLabel := TfpgLabel.Create(Self);
  lLabel.SetPosition(18, 10, 660, 30);
  lLabel.Text := 'Same TNXRenderPanel; backend chosen by skin. Resize to test anchors.';
  if ParamStr(2) = 'upstream' then
    lLabel.Text := 'Unmodified TfpgPanel reference: background, caption, children and clipping.';
  for lStyle := Low(TPanelStyle) to High(TPanelStyle) do
    for lBorder := Low(TPanelBorder) to High(TPanelBorder) do
    begin
      if ParamStr(2) = 'upstream' then
        lPanel := TfpgPanel.Create(Self)
      else
        lPanel := TNXRenderPanel.Create(Self, fpgStyle as TNXSkin);
      lPanel.SetPosition(18 + Ord(lBorder) * 345, 48 + Ord(lStyle) * 150, 325, 130);
      lPanel.Style := lStyle;
      lPanel.BorderStyle := lBorder;
      lPanel.ParentBackgroundColor := lBorder = bsSingle;
      lPanel.BackgroundColor := $FF303038;
      lPanel.Text := GetEnumName(TypeInfo(TPanelStyle), Ord(lStyle)) + ' / ' +
        GetEnumName(TypeInfo(TPanelBorder), Ord(lBorder));
      lPanel.Layout := tlTop;
      lPanel.Alignment := taLeftJustify;
      lPanel.Margin := 8;
      lPanel.WrapText := True;
      lPanel.Enabled := not ((lStyle = bsLowered) and (lBorder = bsDouble));
      if lBorder = bsDouble then
        lPanel.Anchors := [anLeft, anRight, anTop];
      lChild := TfpgButton.Create(lPanel);
      lChild.SetPosition(12, 48, 180, 28);
      lChild.Text := 'Child: focus and click';
      lChild := TfpgButton.Create(lPanel);
      lChild.SetPosition(278, 90, 100, 28);
      lChild.Text := 'Clipped child';
    end;
end;

procedure RunNXRenderPrototype(const ABackend: string);
var
  lForm: TNXRenderPrototypeForm;
begin
  fpgApplication.Initialize;
  if ABackend = 'lua' then
    fpgStyleManager.SetStyle('NexusLua')
  else if (ABackend = 'pascal') or (ABackend = 'upstream') then
    fpgStyleManager.SetStyle('NexusPascal')
  else
    raise Exception.Create('Panel backend must be lua, pascal, or upstream.');
  fpgStyle := fpgStyleManager.Style;
  lForm := TNXRenderPrototypeForm.Create(nil);
  try
    lForm.Show;
    fpgApplication.Run;
  finally
    lForm.Free;
  end;
end;

end.
