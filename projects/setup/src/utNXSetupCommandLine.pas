(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)



unit utNXSetupCommandLine;

{$mode delphi}{$H+}

interface

function RunSetupCommandLine: Boolean;

implementation

uses Classes, SysUtils, obNXSetupSession, obNXSetupFileInstaller, obNXSetupModel;

function RunSetupCommandLine: Boolean;
var
  lSession: TNXSetupSession;
  lArgument, lMessage: string;
  lLog: TStringStream;
begin
  Result := (ParamCount > 0) and (Copy(ParamStr(1), 1, 2) = '--');
  if not Result then Exit;
  lSession := nil;
  try
    try
      if (ParamCount <> 2) and
        not ((ParamCount = 4) and (ParamStr(3) = '--log')) then
        raise ENXSetup.Create('Usage: NexusSetup --install <root> | --repair <state> | --uninstall <state> | --recover <state-folder> [--log <file>]');
      lArgument := ParamStr(2);
      if ParamStr(1) = '--install' then
      begin
        lSession := TNXSetupSession.OpenExecutable(ParamStr(0));
        lSession.Root := lArgument;
        lMessage := 'Installed. State: ' + lSession.Install;
      end
      else if ParamStr(1) = '--repair' then
      begin
        TNXSetupSession.Repair(ExpandFileName(lArgument));
        lMessage := 'Repair completed.';
      end
      else if ParamStr(1) = '--uninstall' then
      begin
        TNXSetupFileInstaller.Uninstall(ExpandFileName(lArgument));
        lMessage := 'Uninstall completed.';
      end
      else if ParamStr(1) = '--recover' then
      begin
        TNXSetupFileInstaller.Recover(ExpandFileName(lArgument));
        lMessage := 'Recovery completed.';
      end
      else raise ENXSetup.Create('Unknown Setup operation: ' + ParamStr(1));
    except
      on lError: Exception do
      begin
        lMessage := lError.Message;
        ExitCode := 1;
      end;
    end;
    if (ParamCount = 4) and (ParamStr(3) = '--log') then
    begin
      lLog := TStringStream.Create(lMessage + LineEnding);
      try lLog.SaveToFile(ParamStr(4)); finally lLog.Free; end;
    end;
  finally
    lSession.Free;
  end;
end;

end.

