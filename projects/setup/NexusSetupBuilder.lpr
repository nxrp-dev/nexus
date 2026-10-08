(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)



program NexusSetupBuilder;

{$mode delphi}{$H+}

uses SysUtils, obNXSetupLoader, obNXSetupModel, obNXSetupBundle,
  obNexusScriptModel;

procedure BuildInstaller;
var
  lDocument: TNXSetupDocument;
  lTargets: TNexusScriptTargetSelection;
  lIndex, lEquals: Integer;
  lArgument: string;
begin
  if ParamCount < 3 then
    raise ENXSetup.Create('Usage: NexusSetupBuilder <script> <runtime> <output> [Target=Value ...]');
  lTargets := TNexusScriptTargetSelection.Create;
  lDocument := nil;
  try
    for lIndex := 4 to ParamCount do
    begin
      lArgument := ParamStr(lIndex);
      lEquals := Pos('=', lArgument);
      if (lEquals < 2) or (lEquals = Length(lArgument)) then
        raise ENXSetup.Create('Invalid target selection: ' + lArgument);
      lTargets.Add(Copy(lArgument, 1, lEquals - 1), Copy(lArgument, lEquals + 1, MaxInt));
    end;
    lDocument := TNXSetupLoader.LoadFile(ExpandFileName(ParamStr(1)), nil, lTargets);
    TNXSetupBundle.Build(lDocument, ExpandFileName(ParamStr(2)), ExpandFileName(ParamStr(3)));
    WriteLn('Installer created: ', ExpandFileName(ParamStr(3)));
  finally
    lDocument.Free;
    lTargets.Free;
  end;
end;

begin
  try
    BuildInstaller;
  except
    on lError: Exception do
    begin
      WriteLn(StdErr, lError.Message);
      ExitCode := 1;
    end;
  end;
end.

