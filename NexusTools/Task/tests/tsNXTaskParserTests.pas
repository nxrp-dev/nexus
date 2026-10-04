(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

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
