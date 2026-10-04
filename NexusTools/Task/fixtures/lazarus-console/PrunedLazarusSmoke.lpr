(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program PrunedLazarusSmoke;

{$mode objfpc}{$H+}

uses
  Interfaces,
  Forms,
  StdCtrls;

var
  lForm: TForm;
  lButton: TButton;

begin
  Application.Initialize;

  lForm := TForm.Create(nil);
  try
    lForm.Caption := 'Pruned Lazarus Smoke';

    lButton := TButton.Create(lForm);
    lButton.Parent := lForm;
    lButton.Caption := 'Smoke';

    WriteLn('pruned lazarus lcl smoke');
  finally
    lForm.Free;
  end;
end.
