(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program nxpackage;

{$mode objfpc}{$H+}
{$apptype GUI}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  uiNXPackageMain;

begin
  RunNXPackage;
end.
