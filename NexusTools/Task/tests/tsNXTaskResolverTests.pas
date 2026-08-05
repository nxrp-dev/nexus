unit tsNXTaskResolverTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXTaskResolverTests(ARegistry: TNXTestRegistry);

implementation

uses
  SysUtils, obNXTestContext, obNXTestSuite, obNXTaskModel, obNXTaskResolver,
  obNXTaskDump, obNXTaskExecutor, tsNXTaskTestSupport;

procedure TestExternalExpansionAndDeclarationContext(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lText: string;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('root.nxtask'));
    try
      lText := TNXTaskDumper.DumpDocument(lDocument, False);
      NXTaskAssertContains(AContext, lText, 'property Mode = string "ObjFPC"',
        'External node expansion should add properties.');
      NXTaskAssertContains(AContext, lText, 'property Output = string "artifacts"',
        'Expanded local reference should use declaration context.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestExpansionPreservesTaskOrder(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lExecutor: TNXTaskExecutor;
  lDocument: TNXTaskDocument;
  lText: string;
  lFirstPos: Integer;
  lExpandedPos: Integer;
  lLastPos: Integer;
begin
  lResolver := TNXTaskResolver.Create;
  lExecutor := TNXTaskExecutor.Create;
  try
    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('ordered-expansion.nxtask'));
    try
      lText := lExecutor.Execute(lDocument, 'Debug',
        ExtractFileDir(NXTaskSamplePath('ordered-expansion.nxtask')));
      lFirstPos := Pos('trace First "first"', lText);
      lExpandedPos := Pos('trace Expanded "expanded"', lText);
      lLastPos := Pos('trace Last "last"', lText);
      AContext.AssertTrue((lFirstPos > 0) and (lExpandedPos > 0) and
        (lLastPos > 0) and (lFirstPos < lExpandedPos) and
        (lExpandedPos < lLastPos),
        'Expanded task should preserve declaration order.');
    finally
      lDocument.Free;
    end;
  finally
    lExecutor.Free;
    lResolver.Free;
  end;
end;

procedure TestDiagnosticsResetBetweenMaterializeOperations(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('missing-file.nxtask'));
    try
      AContext.AssertTrue(lResolver.Diagnostics.HasErrors,
        'Missing file should produce resolver diagnostics.');
    finally
      lDocument.Free;
    end;

    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('missing-file.nxtask'));
    try
      NXTaskAssertDiagnostic(AContext, lResolver.Diagnostics,
        'NXTask.Load.FileNotFound',
        'Cached missing file should still produce resolver diagnostics.');
    finally
      lDocument.Free;
    end;

    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('root.nxtask'));
    try
      AContext.AssertFalse(lResolver.Diagnostics.HasErrors,
        'Valid materialization should not retain previous diagnostics.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestMissingScalarReferenceRemainsReference(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lText: string;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(
      NXTaskSamplePath('errors\missing-scalar-reference.nxtask'));
    try
      AContext.AssertTrue(lResolver.Diagnostics.HasErrors,
        'Missing scalar reference should produce diagnostics.');
      lText := TNXTaskDumper.DumpDocument(lDocument, False);
      NXTaskAssertContains(AContext, lText,
        'property Value = reference [Root.Missing.Value]',
        'Failed scalar reference should remain visible in materialized dump.');
      AContext.AssertFalse(Pos('property Value = string ""', lText) > 0,
        'Failed scalar reference must not become an empty string.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestCyclicScalarReferenceRemainsReference(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lText: string;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(
      NXTaskSamplePath('errors\value-cycle.nxtask'));
    try
      AContext.AssertTrue(lResolver.Diagnostics.HasErrors,
        'Cyclic scalar reference should produce diagnostics.');
      lText := TNXTaskDumper.DumpDocument(lDocument, False);
      NXTaskAssertContains(AContext, lText,
        'property Value = reference [Root.B.Value]',
        'Cyclic scalar reference should remain visible in materialized dump.');
      AContext.AssertFalse(Pos('property Value = string ""', lText) > 0,
        'Cyclic scalar reference must not become an empty string.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestMissingScalarReferenceUsesReferenceRange(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lDiagnostic: TNXTaskDiagnostic;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(
      NXTaskSamplePath('errors\missing-scalar-reference.nxtask'));
    try
      lDiagnostic := NXTaskFindDiagnostic(lResolver.Diagnostics,
        'NXTask.Resolve.MissingNode');
      AContext.AssertTrue(lDiagnostic <> nil,
        'Missing scalar node should produce a diagnostic.');
      AContext.AssertEquals(3, lDiagnostic.Range.Line,
        'Missing scalar reference diagnostic should point to the reference line.');
      AContext.AssertTrue(lDiagnostic.Range.Column > 1,
        'Missing scalar reference diagnostic should not point to column 1.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestMissingExpansionReferenceUsesReferenceRange(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lDiagnostic: TNXTaskDiagnostic;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(
      NXTaskSamplePath('errors\missing-node-expansion.nxtask'));
    try
      lDiagnostic := NXTaskFindDiagnostic(lResolver.Diagnostics,
        'NXTask.Resolve.MissingNode');
      AContext.AssertTrue(lDiagnostic <> nil,
        'Missing node expansion should produce a diagnostic.');
      AContext.AssertEquals(2, lDiagnostic.Range.Line,
        'Missing node expansion diagnostic should point to the expansion line.');
      AContext.AssertTrue(lDiagnostic.Range.Column > 1,
        'Missing node expansion diagnostic should not point to column 1.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestScalarCycleDiagnosticShowsFullChain(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lDiagnostic: TNXTaskDiagnostic;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(
      NXTaskSamplePath('errors\value-cycle.nxtask'));
    try
      lDiagnostic := NXTaskFindDiagnostic(lResolver.Diagnostics,
        'NXTask.Resolve.ValueCycle');
      AContext.AssertTrue(lDiagnostic <> nil,
        'Scalar cycle should produce a diagnostic.');
      NXTaskAssertContains(AContext, lDiagnostic.Message, 'Root.B.Value',
        'Scalar cycle diagnostic should include the intermediate reference.');
      NXTaskAssertContains(AContext, lDiagnostic.Message, 'Root.A.Value',
        'Scalar cycle diagnostic should include the repeated reference.');
      NXTaskAssertContains(AContext, lDiagnostic.Message, ' -> ',
        'Scalar cycle diagnostic should show the chain order.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestNodeCycleDiagnosticShowsFullChain(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lDiagnostic: TNXTaskDiagnostic;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(
      NXTaskSamplePath('errors\node-cycle.nxtask'));
    try
      lDiagnostic := NXTaskFindDiagnostic(lResolver.Diagnostics,
        'NXTask.Resolve.NodeCycle');
      AContext.AssertTrue(lDiagnostic <> nil,
        'Node cycle should produce a diagnostic.');
      NXTaskAssertContains(AContext, lDiagnostic.Message, 'Root.B',
        'Node cycle diagnostic should include the intermediate expansion.');
      NXTaskAssertContains(AContext, lDiagnostic.Message, 'Root.A',
        'Node cycle diagnostic should include the repeated expansion.');
      NXTaskAssertContains(AContext, lDiagnostic.Message, ' -> ',
        'Node cycle diagnostic should show the chain order.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestExternalScalarCycleUsesDeclarationRelativeIdentity(
  AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lDiagnostic: TNXTaskDiagnostic;
  lRootFile: string;
  lSharedFile: string;
begin
  lRootFile := NXTaskSamplePath('errors\cross-file-cycle\root\root.nxtask');
  lSharedFile := ExpandFileName(IncludeTrailingPathDelimiter(ExtractFileDir(lRootFile)) +
    '..\shared\values.nxtask');

  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(lRootFile);
    try
      lDiagnostic := NXTaskFindDiagnostic(lResolver.Diagnostics,
        'NXTask.Resolve.ValueCycle');
      AContext.AssertTrue(lDiagnostic <> nil,
        'Cross-file scalar cycle should produce a diagnostic.');
      NXTaskAssertContains(AContext, lDiagnostic.Message, lRootFile,
        'Cycle diagnostic should include the declaring root file.');
      NXTaskAssertContains(AContext, lDiagnostic.Message, lSharedFile,
        'Cycle diagnostic should include the declaration-relative shared file.');
      AContext.AssertFalse(Pos(ExpandFileName('..\shared\values.nxtask'),
        lDiagnostic.Message) > 0,
        'Cycle diagnostic should not use process-relative external paths.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure RegisterNXTaskResolverTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusTask.Resolver');
  lSuite.AddTest('ExternalExpansionAndDeclarationContext',
    @TestExternalExpansionAndDeclarationContext);
  lSuite.AddTest('ExpansionPreservesTaskOrder', @TestExpansionPreservesTaskOrder);
  lSuite.AddTest('DiagnosticsResetBetweenMaterializeOperations',
    @TestDiagnosticsResetBetweenMaterializeOperations);
  lSuite.AddTest('MissingScalarReferenceRemainsReference',
    @TestMissingScalarReferenceRemainsReference);
  lSuite.AddTest('CyclicScalarReferenceRemainsReference',
    @TestCyclicScalarReferenceRemainsReference);
  lSuite.AddTest('MissingScalarReferenceUsesReferenceRange',
    @TestMissingScalarReferenceUsesReferenceRange);
  lSuite.AddTest('MissingExpansionReferenceUsesReferenceRange',
    @TestMissingExpansionReferenceUsesReferenceRange);
  lSuite.AddTest('ScalarCycleDiagnosticShowsFullChain',
    @TestScalarCycleDiagnosticShowsFullChain);
  lSuite.AddTest('NodeCycleDiagnosticShowsFullChain',
    @TestNodeCycleDiagnosticShowsFullChain);
  lSuite.AddTest('ExternalScalarCycleUsesDeclarationRelativeIdentity',
    @TestExternalScalarCycleUsesDeclarationRelativeIdentity);
end;

end.
