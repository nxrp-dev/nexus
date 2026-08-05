unit tsNXTaskParserTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXTaskParserTests(ARegistry: TNXTestRegistry);

implementation

uses
  obNXTestContext, obNXTestSuite, obNXTaskModel, obNXTaskParser, obNXTaskDump,
  tsNXTaskTestSupport;

procedure TestParseRootSample(AContext: TNXTestContext);
var
  lParser: TNXTaskParser;
  lDocument: TNXTaskDocument;
  lText: string;
begin
  lParser := TNXTaskParser.Create;
  try
    lDocument := lParser.ParseFile(NXTaskSamplePath('root.nxtask'));
    try
      lText := TNXTaskDumper.DumpDocument(lDocument, True);
      NXTaskAssertContains(AContext, lText,
        'task NexusBuild action Group targets(Debug, Release)',
        'Parse should include root task.');
      NXTaskAssertContains(AContext, lText, 'property RetryCount = integer 3',
        'Parse should preserve integer type.');
      NXTaskAssertContains(AContext, lText, 'property WarningThreshold = float 0.75',
        'Parse should preserve float type.');
    finally
      lDocument.Free;
    end;
  finally
    lParser.Free;
  end;
end;

procedure TestWindowsPathString(AContext: TNXTestContext);
var
  lParser: TNXTaskParser;
  lDocument: TNXTaskDocument;
  lText: string;
begin
  lParser := TNXTaskParser.Create;
  try
    lDocument := lParser.ParseFile(NXTaskSamplePath('windows-path-string.nxtask'));
    try
      lText := TNXTaskDumper.DumpDocument(lDocument, True);
      NXTaskAssertContains(AContext, lText,
        'property WindowsPath = string "C:\\build\\shared.nxtask"',
        'Windows paths should preserve single backslashes in quoted strings.');
    finally
      lDocument.Free;
    end;
  finally
    lParser.Free;
  end;
end;

procedure RegisterNXTaskParserTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusTask.Parser');
  lSuite.AddTest('ParseRootSample', @TestParseRootSample);
  lSuite.AddTest('WindowsPathString', @TestWindowsPathString);
end;

end.
