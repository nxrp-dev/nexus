unit obNXControls;

{$mode objfpc}{$H+}

interface

uses
  fpg_button,
  fpg_dialogs,
  fpg_edit,
  fpg_form,
  fpg_label,
  fpg_memo,
  fpg_panel;

type
  TNXButton = class(TfpgButton);
  TNXEditBox = class(TfpgEdit);
  TNXFileDialog = class(TfpgFileDialog);
  TNXForm = class(TfpgForm);
  TNXGroupBox = class(TfpgGroupBox);
  TNXLabel = class(TfpgLabel);
  TNXMemo = class(TfpgMemo);
  TNXPanel = class(TfpgPanel);

implementation

end.
