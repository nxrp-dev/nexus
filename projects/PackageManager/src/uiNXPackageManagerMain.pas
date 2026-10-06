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
  obNXControls, obNXScriptEditor, obNXPackageManagerDocument;

type
  TNXPackageManagerMainForm = class(TNXForm)
  private
    FValidation: TNXPackageManagerDocument;
    FDiagnostics: TNXMemo;
    FEditor: TNXScriptEditor;
    FPathLabel: TNXLabel;
    FSource: TNXMemo;
  protected
    procedure HandleClose; override;
    function ConfirmDiscard: Boolean;
    procedure EditorChanged(ASender: TObject);
    procedure EditRejected(ASender: TObject);
    procedure OpenClicked(ASender: TObject);
    procedure ReloadClicked(ASender: TObject);
    procedure SaveClicked(ASender: TObject);
    procedure ValidateClicked(ASender: TObject);
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
  FValidation := TNXPackageManagerDocument.Create;
end;

destructor TNXPackageManagerMainForm.Destroy;
begin
  if FEditor <> nil then
  begin
    FEditor.OnDocumentChanged := nil;
    FEditor.OnEditRejected := nil;
  end;
  FValidation.Free;
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
  MinWidth := 1000;
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
  lPanel.Width := 760;
  FEditor := TNXScriptEditor.Create(lPanel);
  FEditor.Align := alClient;
  FEditor.FontDesc := 'Arial-11';
  FEditor.DefaultNodeHeight := 28;
  FEditor.Header.Height := 32;
  FEditor.Header.Columns[0].Width := 220;
  FEditor.Header.Columns[1].Width := 380;
  FEditor.Header.Columns[2].Width := 120;
  FEditor.OnDocumentChanged := @EditorChanged;
  FEditor.OnEditRejected := @EditRejected;

  FSource := TNXMemo.Create(Self);
  FSource.Align := alClient;
  FSource.ReadOnly := True;
  FSource.FontDesc := 'Courier New-10';
  RefreshDisplay;
end;

function TNXPackageManagerMainForm.ConfirmDiscard: Boolean;
begin
  if not FEditor.EndEditNode then Exit(False);
  Result := not FEditor.Document.Dirty or
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

procedure TNXPackageManagerMainForm.EditorChanged(ASender: TObject);
begin
  FValidation.LoadSource(FEditor.Document.SourceName, FEditor.Document.SourceText);
  FValidation.Validate;
  RefreshDisplay;
end;

procedure TNXPackageManagerMainForm.EditRejected(ASender: TObject);
begin
  FDiagnostics.Text := FEditor.Document.Diagnostics.Text;
end;

procedure TNXPackageManagerMainForm.OpenFile(const AFileName: string);
begin
  try
    FEditor.LoadFile(AFileName);
  except
    on E: Exception do ShowError(E.Message);
  end;
end;

procedure TNXPackageManagerMainForm.OpenClicked(ASender: TObject);
var
  lDialog: TNXFileDialog;
begin
  if not ConfirmDiscard then Exit;
  lDialog := TNXFileDialog.Create(Self);
  try
    lDialog.Filter := 'NexusScript|*.nxscript|All files|*.*';
    if FEditor.Document.SourceName <> '' then
      lDialog.InitialDir := ExtractFileDir(FEditor.Document.SourceName);
    if lDialog.RunOpenFile then
      OpenFile(lDialog.FileName);
  finally
    lDialog.Free;
  end;
end;

procedure TNXPackageManagerMainForm.ReloadClicked(ASender: TObject);
begin
  if (FEditor.Document.SourceName <> '') and ConfirmDiscard then
    OpenFile(FEditor.Document.SourceName);
end;

procedure TNXPackageManagerMainForm.SaveClicked(ASender: TObject);
begin
  if not FEditor.EndEditNode then Exit;
  try
    FEditor.Document.Save;
    RefreshDisplay;
  except
    on E: Exception do ShowError(E.Message);
  end;
end;

procedure TNXPackageManagerMainForm.ValidateClicked(ASender: TObject);
begin
  if not FEditor.EndEditNode then Exit;
  try
    if FEditor.Document.SourceName = '' then
      raise Exception.Create('No document is open');
    EditorChanged(Self);
  except
    on E: Exception do ShowError(E.Message);
  end;
end;

procedure TNXPackageManagerMainForm.RefreshDisplay;
var
  lTitle: string;
begin
  lTitle := 'NexusPackageManager';
  if FEditor.Document.SourceName <> '' then
  begin
    lTitle := lTitle + ' - ' + ExtractFileName(FEditor.Document.SourceName);
    if FEditor.Document.Dirty then lTitle := lTitle + ' *';
  end;
  WindowTitle := lTitle;
  FPathLabel.Text := FValidation.EntityType + '  ' + FEditor.Document.SourceName;
  FDiagnostics.Text := FValidation.Diagnostics.Text;
  FSource.Text := FEditor.Document.SourceText;
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
