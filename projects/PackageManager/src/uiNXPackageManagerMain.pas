(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit uiNXPackageManagerMain;

{$mode objfpc}{$H+}

interface

procedure RunNexusPackageManager;

implementation

uses
  Classes, SysUtils, fpg_base, fpg_form, fpg_main, fpg_dialogs,
  obNXControls, obNXPackageManagerStructure, obNXPackageManagerDocument;

type
  TNXPackageManagerMainForm = class(TNXForm)
  private
    FDocument: TNXPackageManagerDocument;
    FDiagnostics: TNXMemo;
    FEditor: TNXMemo;
    FLoading: Boolean;
    FPathLabel: TNXLabel;
    FStructure: TNXPackageManagerStructure;
  protected
    procedure HandleClose; override;
    function ConfirmDiscard: Boolean;
    procedure EditorChanged(Sender: TObject);
    procedure OpenClicked(Sender: TObject);
    procedure ReloadClicked(Sender: TObject);
    procedure SaveClicked(Sender: TObject);
    procedure ValidateClicked(Sender: TObject);
    procedure RefreshDisplay;
    procedure ShowError(const AMessage: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterCreate; override;
    procedure OpenFile(const AFileName: string);
  end;

constructor TNXPackageManagerMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDocument := TNXPackageManagerDocument.Create;
end;

destructor TNXPackageManagerMainForm.Destroy;
begin
  FDocument.Free;
  inherited Destroy;
end;

procedure TNXPackageManagerMainForm.AfterCreate;
var
  lBar: TNXPanel;
  lButton: TNXButton;
  lPanel: TNXPanel;
begin
  inherited AfterCreate;
  WindowTitle := 'NexusPackageManager';
  WindowPosition := wpScreenCenter;
  Width := 1200;
  Height := 760;
  MinWidth := 760;
  MinHeight := 480;

  lBar := TNXPanel.Create(Self);
  lBar.Align := alTop;
  lBar.Width := Width;
  lBar.Height := 44;

  lButton := TNXButton.Create(lBar);
  lButton.Left := 8;
  lButton.Top := 8;
  lButton.Width := 76;
  lButton.Height := 28;
  lButton.Text := 'Open';
  lButton.OnClick := @OpenClicked;

  lButton := TNXButton.Create(lBar);
  lButton.Left := 92;
  lButton.Top := 8;
  lButton.Width := 76;
  lButton.Height := 28;
  lButton.Text := 'Save';
  lButton.OnClick := @SaveClicked;

  lButton := TNXButton.Create(lBar);
  lButton.Left := 176;
  lButton.Top := 8;
  lButton.Width := 76;
  lButton.Height := 28;
  lButton.Text := 'Reload';
  lButton.OnClick := @ReloadClicked;

  lButton := TNXButton.Create(lBar);
  lButton.Left := 260;
  lButton.Top := 8;
  lButton.Width := 90;
  lButton.Height := 28;
  lButton.Text := 'Validate';
  lButton.OnClick := @ValidateClicked;

  FPathLabel := TNXLabel.Create(lBar);
  FPathLabel.Left := 362;
  FPathLabel.Top := 10;
  FPathLabel.Width := 810;
  FPathLabel.Height := 24;
  FPathLabel.Anchors := [anLeft, anRight, anTop];

  lPanel := TNXPanel.Create(Self);
  lPanel.Align := alBottom;
  lPanel.Height := 180;
  FDiagnostics := TNXMemo.Create(lPanel);
  FDiagnostics.Align := alClient;
  FDiagnostics.ReadOnly := True;

  lPanel := TNXPanel.Create(Self);
  lPanel.Align := alLeft;
  lPanel.Width := 560;
  FEditor := TNXMemo.Create(lPanel);
  FEditor.Align := alClient;
  FEditor.OnChange := @EditorChanged;

  FStructure := TNXPackageManagerStructure.Create(Self);
  FStructure.Align := alClient;
  FStructure.Header.Columns[0].Width := 520;
  RefreshDisplay;
end;

function TNXPackageManagerMainForm.ConfirmDiscard: Boolean;
begin
  Result := not FDocument.Dirty or
    (TfpgMessageDialog.Question('Unsaved changes',
      'Discard the unsaved source changes?') = mbYes);
end;

procedure TNXPackageManagerMainForm.HandleClose;
begin
  if ConfirmDiscard then inherited HandleClose;
end;

procedure TNXPackageManagerMainForm.ShowError(const AMessage: string);
begin
  TfpgMessageDialog.Critical('NexusPackageManager', AMessage);
end;

procedure TNXPackageManagerMainForm.EditorChanged(Sender: TObject);
begin
  if FLoading then Exit;
  FDocument.SourceText := FEditor.Text;
  RefreshDisplay;
end;

procedure TNXPackageManagerMainForm.OpenFile(const AFileName: string);
begin
  try
    FDocument.Load(AFileName);
    FLoading := True;
    try
      FEditor.Text := FDocument.SourceText;
    finally
      FLoading := False;
    end;
    FDocument.Validate;
    RefreshDisplay;
  except
    on E: Exception do ShowError(E.Message);
  end;
end;

procedure TNXPackageManagerMainForm.OpenClicked(Sender: TObject);
var
  lDialog: TNXFileDialog;
begin
  if not ConfirmDiscard then Exit;
  lDialog := TNXFileDialog.Create(Self);
  try
    lDialog.Filter := 'NexusScript|*.nxscript|All files|*.*';
    if FDocument.FileName <> '' then
      lDialog.InitialDir := ExtractFileDir(FDocument.FileName);
    if lDialog.RunOpenFile then
      OpenFile(lDialog.FileName);
  finally
    lDialog.Free;
  end;
end;

procedure TNXPackageManagerMainForm.ReloadClicked(Sender: TObject);
begin
  if (FDocument.FileName <> '') and ConfirmDiscard then
    OpenFile(FDocument.FileName);
end;

procedure TNXPackageManagerMainForm.SaveClicked(Sender: TObject);
begin
  try
    FDocument.Save;
    RefreshDisplay;
  except
    on E: Exception do ShowError(E.Message);
  end;
end;

procedure TNXPackageManagerMainForm.ValidateClicked(Sender: TObject);
begin
  try
    FDocument.Validate;
    RefreshDisplay;
  except
    on E: Exception do ShowError(E.Message);
  end;
end;

procedure TNXPackageManagerMainForm.RefreshDisplay;
var
  lTitle: string;
begin
  lTitle := 'NexusPackageManager';
  if FDocument.FileName <> '' then
  begin
    lTitle := lTitle + ' - ' + ExtractFileName(FDocument.FileName);
    if FDocument.Dirty then lTitle := lTitle + ' *';
  end;
  WindowTitle := lTitle;
  FPathLabel.Text := FDocument.EntityType + '  ' + FDocument.FileName;
  FDiagnostics.Text := FDocument.Diagnostics.Text;
  FStructure.LoadDocument(FDocument.CompiledDocument);
end;

procedure RunNexusPackageManager;
var
  lMainForm: TNXPackageManagerMainForm;
begin
  fpgApplication.Initialize;
  fpgApplication.AppTitle := 'NexusPackageManager';
  lMainForm := TNXPackageManagerMainForm.Create(nil);
  try
    if ParamCount > 0 then lMainForm.OpenFile(ParamStr(1));
    lMainForm.Show;
    fpgApplication.Run;
  finally
    lMainForm.Free;
  end;
end;

end.
