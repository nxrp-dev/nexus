(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsSampleTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry, obNXTestSuite, obNXTestContext;

procedure RegisterSampleTests(ARegistry: TNXTestRegistry);

implementation

procedure TestPassingString(AContext: TNXTestContext);
begin
  AContext.AssertEquals('Nexus', 'Nexus', 'Strings should match.');
end;

procedure TestPassingInteger(AContext: TNXTestContext);
begin
  AContext.AssertEquals(42, 40 + 2, 'Integers should match.');
end;

procedure TestFailingValue(AContext: TNXTestContext);
begin
  AContext.AssertEquals('expected', 'actual', 'This sample failure is intentional.');
end;

procedure TestSkipped(AContext: TNXTestContext);
begin
  AContext.Skip('This sample skip is intentional.');
end;

procedure RegisterSampleTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('Sample');
  lSuite.AddTest('PassingString', @TestPassingString);
  lSuite.AddTest('PassingInteger', @TestPassingInteger);
  lSuite.AddTest('FailingValue', @TestFailingValue);
  lSuite.AddTest('Skipped', @TestSkipped);
end;

end.
