(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXTaskValidationTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXTaskValidationTests(ARegistry: TNXTestRegistry);

implementation

uses
  obNXTestContext, obNXTestSuite, obNXTaskModel, obNXTaskParser,
  obNXTaskValidation, tsNXTaskTestSupport;

procedure TestDuplicateDeclarations(AContext: TNXTestContext);
var
  lParser: TNXTaskParser;
  lValidator: TNXTaskValidator;
  lDocument: TNXTaskDocument;
begin
  lParser := TNXTaskParser.Create;
  lValidator := TNXTaskValidator.Create;
  try
    lDocument := lParser.ParseFile(NXTaskSamplePath('errors\duplicates.nxtask'));
    try
      lValidator.ValidateDocument(lDocument);
      AContext.AssertTrue(lDocument.Diagnostics.HasErrors,
        'Duplicate sample should produce diagnostics.');
    finally
      lDocument.Free;
    end;
  finally
    lValidator.Free;
    lParser.Free;
  end;
end;

procedure RegisterNXTaskValidationTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusTask.Validation');
  lSuite.AddTest('DuplicateDeclarations', @TestDuplicateDeclarations);
end;

end.
