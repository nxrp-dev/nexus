(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program NexusSetupUITests;

{$mode objfpc}{$H+}

uses fpg_main, fpg_stylemanager, obNXSkin,
  obNXTestRegistry, obNXTestSuite, obNXTestResult, tsNXSetupUITests;

var
  lRegistry: TNXTestRegistry;
  lResult: TNXTestResult;
  lTest, lPassed, lFailed: Integer;
begin
  fpgApplication.Initialize;
  fpgStyleManager.SetStyle('Nexus');
  fpgStyle := fpgStyleManager.Style;
  lRegistry := TNXTestRegistry.Create;
  lPassed := 0;
  lFailed := 0;
  try
    RegisterSetupUITests(lRegistry);
    for lTest := 0 to lRegistry.Suites[0].TestCount - 1 do
    begin
      lResult := lRegistry.Suites[0].Tests[lTest].Execute(lRegistry.Suites[0].Name);
      try
        if lResult.Status = tsPassed then Inc(lPassed) else Inc(lFailed);
        WriteLn(lResult.StatusText, ' ', lResult.TestId, ' ', lResult.Message, ' ', lResult.ErrorMessage);
      finally
        lResult.Free;
      end;
    end;
    WriteLn(lPassed, ' passed; ', lFailed, ' failed/errors/skipped');
    if (lFailed <> 0) or (lPassed = 0) then ExitCode := 1;
  finally
    lRegistry.Free;
  end;
end.
