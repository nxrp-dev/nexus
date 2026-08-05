unit tsNXTaskTargetTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXTaskTargetTests(ARegistry: TNXTestRegistry);

implementation

uses
  SysUtils, obNXTestContext, obNXTestSuite, obNXTaskModel, obNXTaskResolver,
  obNXTaskTargets, obNXTaskExecutor, tsNXTaskTestSupport;

procedure TestDebugProjectionSkipsReleaseOnlyTask(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lDocument: TNXTaskDocument;
  lText: string;
begin
  lResolver := TNXTaskResolver.Create;
  try
    lDocument := lResolver.MaterializeFile(NXTaskSamplePath('root.nxtask'));
    try
      lText := TNXTaskTargetInspector.Inspect(lDocument, 'Debug');
      AContext.AssertFalse(Pos('Package Group', lText) > 0,
        'Release-only package should not appear in Debug projection.');
    finally
      lDocument.Free;
    end;
  finally
    lResolver.Free;
  end;
end;

procedure TestParentExcludesChild(AContext: TNXTestContext);
var
  lResolver: TNXTaskResolver;
  lExecutor: TNXTaskExecutor;
  lDocument: TNXTaskDocument;
  lText: string;
begin
  lResolver := TNXTaskResolver.Create;
  lExecutor := TNXTaskExecutor.Create;
  try
    lDocument := lResolver.MaterializeFile(
      NXTaskSamplePath('parent-excludes-child.nxtask'));
    try
      lText := TNXTaskTargetInspector.Inspect(lDocument, 'Test');
      AContext.AssertFalse(Pos('Child Trace', lText) > 0,
        'Child must not be evaluated when parent excludes target.');
      lText := lExecutor.Execute(lDocument, 'Test',
        ExtractFileDir(NXTaskSamplePath('parent-excludes-child.nxtask')));
      AContext.AssertFalse(Pos('must not run', lText) > 0,
        'Child action must not run when parent excludes target.');
    finally
      lDocument.Free;
    end;
  finally
    lExecutor.Free;
    lResolver.Free;
  end;
end;

procedure RegisterNXTaskTargetTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusTask.Targets');
  lSuite.AddTest('DebugProjectionSkipsReleaseOnlyTask',
    @TestDebugProjectionSkipsReleaseOnlyTask);
  lSuite.AddTest('ParentExcludesChild', @TestParentExcludesChild);
end;

end.
