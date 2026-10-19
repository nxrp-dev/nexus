(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program NexusSetup;

{$mode objfpc}{$H+}
{$apptype GUI}

uses uiNXSetupMain, utNXSetupCommandLine;

begin
  if not RunSetupCommandLine then RunNexusSetup;
end.
