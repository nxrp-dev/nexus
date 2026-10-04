(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXTaskAllTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXTaskTests(ARegistry: TNXTestRegistry);

implementation

uses
  tsNXTaskParserTests, tsNXTaskValidationTests, tsNXTaskResolverTests,
  tsNXTaskTargetTests, tsNXTaskExecutionTests;

procedure RegisterNXTaskTests(ARegistry: TNXTestRegistry);
begin
  RegisterNXTaskParserTests(ARegistry);
  RegisterNXTaskValidationTests(ARegistry);
  RegisterNXTaskResolverTests(ARegistry);
  RegisterNXTaskTargetTests(ARegistry);
  RegisterNXTaskExecutionTests(ARegistry);
end;

end.
