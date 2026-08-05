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
