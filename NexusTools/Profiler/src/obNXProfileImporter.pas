unit obNXProfileImporter;

{$mode objfpc}{$H+}

interface

type
  TNXProfileImporter = class
  public
    class function ImportPath(const ADatabaseFile, AInputPath,
      ARunName: string): Integer;
  end;

implementation

uses
  Windows,
  Classes,
  Contnrs,
  SysUtils,
  tpNXProfileFormat,
  obNXProfileReader,
  obNXProfileDatabase;

type
  TNXThreadState = class
  private
    FThreadId: DWord;
    FHasSequence: Boolean;
    FNextSequence: QWord;
  public
    constructor Create(AThreadId: DWord);
    procedure BeginBlock(ASequence: QWord; out ASequenceMatches: Boolean);
    property ThreadId: DWord read FThreadId;
  end;

  TNXProcedureAggregate = class
  public
    ProcedureId: DWord;
    Calls: QWord;
    NormalReturns: QWord;
    UnwindReturns: QWord;
    InclusiveTicks: QWord;
    SelfTicks: QWord;
    MinTicks: QWord;
    MaxTicks: QWord;
    procedure AddCall(ADuration, ASelfTicks: QWord; AUnwind: Boolean);
  end;

  TNXCallEdgeAggregate = class
  public
    CallerId: DWord;
    CalleeId: DWord;
    Calls: QWord;
    InclusiveTicks: QWord;
  end;

  TNXCallMetrics = record
    Available: Boolean;
    ThreadId: DWord;
    Sequence: QWord;
    CallIndex: DWord;
    Flags: DWord;
    ProcedureId: DWord;
    CallerProcedureId: DWord;
    TotalTicks: Int64;
    DatabaseTicks: Int64;
    IssueTicks: Int64;
    ProcedureLookupTicks: Int64;
    ProcedureUpdateTicks: Int64;
    EdgeLookupTicks: Int64;
    EdgeUpdateTicks: Int64;
  end;

  TNXTraceImporter = class
  private
    FDatabase: TNXProfileDatabase;
    FTraceId: Int64;
    FThreads: TFPHashObjectList;
    FProcedureTotals: TFPHashObjectList;
    FCallEdges: TFPHashObjectList;
    FObservedLostEvents: QWord;
    FProcessedCalls: QWord;
    FCheckpointOffset: Int64;
    FBatchStartCalls: QWord;
    FBatchStartMilliseconds: QWord;
    FBatchMetricsActive: Boolean;
    FPerformanceFrequency: Int64;
    FLastCallMetrics: TNXCallMetrics;
    function ThreadState(AThreadId: DWord): TNXThreadState;
    function ProcedureTotal(AProcedureId: DWord): TNXProcedureAggregate;
    function CallEdge(ACallerId, ACalleeId: DWord): TNXCallEdgeAggregate;
    procedure ProcessCallBlock(const ABlock: TNXProfileCallBlock);
    procedure ProcessCall(AThread: TNXThreadState; ASequence: QWord;
      ACallIndex: DWord; const ACall: TNXProfileCall);
    procedure ProcessMeasuredCall(AThread: TNXThreadState; ASequence: QWord;
      ACallIndex: DWord; const ACall: TNXProfileCall);
    procedure FlushAggregates;
    procedure ClearAggregates;
    function SerializeThreadState: TBytes;
    procedure RestoreThreadState(const AData: TBytes);
    procedure BeginBatchMetrics;
    procedure ReportBatchMetrics;
    function Microseconds(ATicks: Int64): Double;
    procedure SaveCheckpoint(ASourceOffset: Int64; AFinished: Boolean);
  public
    constructor Create(ADatabase: TNXProfileDatabase);
    destructor Destroy; override;
    procedure ImportFile(ARunId: Int64; const AFileName: string);
  end;

const
  cCheckpointMagic = $5043584E;
  cCheckpointVersion = 2;
  cCheckpointInterval = Int64(64) * 1024 * 1024;

procedure WriteDWord(AStream: TStream; AValue: DWord);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure WriteQWord(AStream: TStream; AValue: QWord);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

function ReadDWord(AStream: TStream): DWord;
begin
  Result := 0;
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

function ReadQWord(AStream: TStream): QWord;
begin
  Result := 0;
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

constructor TNXThreadState.Create(AThreadId: DWord);
begin
  inherited Create;
  FThreadId := AThreadId;
end;

procedure TNXThreadState.BeginBlock(ASequence: QWord;
  out ASequenceMatches: Boolean);
begin
  ASequenceMatches := (not FHasSequence) or (ASequence = FNextSequence);
  FHasSequence := True;
  FNextSequence := ASequence + 1;
end;

procedure TNXProcedureAggregate.AddCall(ADuration,
  ASelfTicks: QWord; AUnwind: Boolean);
begin
  Inc(Calls);
  if AUnwind then
    Inc(UnwindReturns)
  else
    Inc(NormalReturns);
  Inc(InclusiveTicks, ADuration);
  Inc(SelfTicks, ASelfTicks);
  if (Calls = 1) or (ADuration < MinTicks) then
    MinTicks := ADuration;
  if ADuration > MaxTicks then
    MaxTicks := ADuration;
end;

constructor TNXTraceImporter.Create(ADatabase: TNXProfileDatabase);
begin
  inherited Create;
  FDatabase := ADatabase;
  FThreads := TFPHashObjectList.Create(True);
  FProcedureTotals := TFPHashObjectList.Create(True);
  FCallEdges := TFPHashObjectList.Create(True);
  QueryPerformanceFrequency(FPerformanceFrequency);
end;

destructor TNXTraceImporter.Destroy;
begin
  FCallEdges.Free;
  FProcedureTotals.Free;
  FThreads.Free;
  inherited Destroy;
end;

function TNXTraceImporter.ThreadState(AThreadId: DWord): TNXThreadState;
var
  lKey: string;
begin
  lKey := IntToHex(AThreadId, 8);
  Result := TNXThreadState(FThreads.Find(lKey));
  if Result <> nil then
    Exit;
  Result := TNXThreadState.Create(AThreadId);
  FThreads.Add(lKey, Result);
end;

function TNXTraceImporter.ProcedureTotal(
  AProcedureId: DWord): TNXProcedureAggregate;
var
  lKey: string;
begin
  lKey := IntToHex(AProcedureId, 8);
  Result := TNXProcedureAggregate(FProcedureTotals.Find(lKey));
  if Result <> nil then
    Exit;
  Result := TNXProcedureAggregate.Create;
  Result.ProcedureId := AProcedureId;
  FProcedureTotals.Add(lKey, Result);
end;

function TNXTraceImporter.CallEdge(ACallerId,
  ACalleeId: DWord): TNXCallEdgeAggregate;
var
  lKey: string;
begin
  lKey := IntToHex(ACallerId, 8) + IntToHex(ACalleeId, 8);
  Result := TNXCallEdgeAggregate(FCallEdges.Find(lKey));
  if Result <> nil then
    Exit;
  Result := TNXCallEdgeAggregate.Create;
  Result.CallerId := ACallerId;
  Result.CalleeId := ACalleeId;
  FCallEdges.Add(lKey, Result);
end;

procedure TNXTraceImporter.ProcessCall(AThread: TNXThreadState;
  ASequence: QWord; ACallIndex: DWord; const ACall: TNXProfileCall);
var
  lTotal: TNXProcedureAggregate;
  lEdge: TNXCallEdgeAggregate;
begin
  FDatabase.AddCall(FTraceId, AThread.ThreadId, ASequence,
    ACallIndex, ACall);
  Inc(FProcessedCalls);
  if (ACall.Flags and cNXProfileCallUnmatched) <> 0 then
  begin
    FDatabase.AddIssue(FTraceId, AThread.ThreadId, ASequence,
      ACallIndex, 'unmatched_terminal',
      Format('terminal event for procedure %u has no matching enter',
      [ACall.ProcedureId]));
    Exit;
  end;
  lTotal := ProcedureTotal(ACall.ProcedureId);
  lTotal.AddCall(ACall.InclusiveTicks, ACall.SelfTicks,
    (ACall.Flags and cNXProfileCallUnwind) <> 0);
  if ACall.CallerProcedureId <> 0 then
  begin
    lEdge := CallEdge(ACall.CallerProcedureId, ACall.ProcedureId);
    Inc(lEdge.Calls);
    Inc(lEdge.InclusiveTicks, ACall.InclusiveTicks);
  end;
end;

procedure TNXTraceImporter.ProcessMeasuredCall(AThread: TNXThreadState;
  ASequence: QWord; ACallIndex: DWord; const ACall: TNXProfileCall);
var
  lTotal: TNXProcedureAggregate;
  lEdge: TNXCallEdgeAggregate;
  lStart: Int64;
  lStageStart: Int64;
  lStageEnd: Int64;
begin
  FLastCallMetrics := Default(TNXCallMetrics);
  FLastCallMetrics.Available := True;
  FLastCallMetrics.ThreadId := AThread.ThreadId;
  FLastCallMetrics.Sequence := ASequence;
  FLastCallMetrics.CallIndex := ACallIndex;
  FLastCallMetrics.Flags := ACall.Flags;
  FLastCallMetrics.ProcedureId := ACall.ProcedureId;
  FLastCallMetrics.CallerProcedureId := ACall.CallerProcedureId;

  lStart := 0;
  lStageStart := 0;
  lStageEnd := 0;
  QueryPerformanceCounter(lStart);
  FDatabase.AddCall(FTraceId, AThread.ThreadId, ASequence,
    ACallIndex, ACall);
  QueryPerformanceCounter(lStageEnd);
  FLastCallMetrics.DatabaseTicks := lStageEnd - lStart;
  Inc(FProcessedCalls);
  if (ACall.Flags and cNXProfileCallUnmatched) <> 0 then
  begin
    lStageStart := lStageEnd;
    FDatabase.AddIssue(FTraceId, AThread.ThreadId, ASequence,
      ACallIndex, 'unmatched_terminal',
      Format('terminal event for procedure %u has no matching enter',
      [ACall.ProcedureId]));
    QueryPerformanceCounter(lStageEnd);
    FLastCallMetrics.IssueTicks := lStageEnd - lStageStart;
    FLastCallMetrics.TotalTicks := lStageEnd - lStart;
    Exit;
  end;

  QueryPerformanceCounter(lStageStart);
  lTotal := ProcedureTotal(ACall.ProcedureId);
  QueryPerformanceCounter(lStageEnd);
  FLastCallMetrics.ProcedureLookupTicks := lStageEnd - lStageStart;

  lStageStart := lStageEnd;
  lTotal.AddCall(ACall.InclusiveTicks, ACall.SelfTicks,
    (ACall.Flags and cNXProfileCallUnwind) <> 0);
  QueryPerformanceCounter(lStageEnd);
  FLastCallMetrics.ProcedureUpdateTicks := lStageEnd - lStageStart;

  if ACall.CallerProcedureId <> 0 then
  begin
    lStageStart := lStageEnd;
    lEdge := CallEdge(ACall.CallerProcedureId, ACall.ProcedureId);
    QueryPerformanceCounter(lStageEnd);
    FLastCallMetrics.EdgeLookupTicks := lStageEnd - lStageStart;

    lStageStart := lStageEnd;
    Inc(lEdge.Calls);
    Inc(lEdge.InclusiveTicks, ACall.InclusiveTicks);
    QueryPerformanceCounter(lStageEnd);
    FLastCallMetrics.EdgeUpdateTicks := lStageEnd - lStageStart;
  end;
  FLastCallMetrics.TotalTicks := lStageEnd - lStart;
end;

procedure TNXTraceImporter.ProcessCallBlock(
  const ABlock: TNXProfileCallBlock);
var
  lThread: TNXThreadState;
  lSequenceMatches: Boolean;
  lIndex: Integer;
begin
  lThread := ThreadState(ABlock.ThreadId);
  lThread.BeginBlock(ABlock.Sequence, lSequenceMatches);
  if not lSequenceMatches then
    FDatabase.AddIssue(FTraceId, ABlock.ThreadId, ABlock.Sequence, -1,
      'trace_discontinuity', 'call block sequence is not contiguous');
  if ABlock.LostEventCount <> 0 then
  begin
    Inc(FObservedLostEvents, ABlock.LostEventCount);
    FDatabase.AddGap(FTraceId, ABlock.ThreadId, 0, ABlock.Sequence,
      ABlock.LostEventCount, ABlock.FirstTimestamp);
  end;
  if Length(ABlock.Calls) > 0 then
  begin
    for lIndex := 0 to High(ABlock.Calls) - 1 do
      ProcessCall(lThread, ABlock.Sequence, lIndex, ABlock.Calls[lIndex]);
    lIndex := High(ABlock.Calls);
    ProcessMeasuredCall(lThread, ABlock.Sequence, lIndex,
      ABlock.Calls[lIndex]);
  end;
end;

procedure TNXTraceImporter.FlushAggregates;
var
  lIndex: Integer;
  lTotal: TNXProcedureAggregate;
  lEdge: TNXCallEdgeAggregate;
begin
  for lIndex := 0 to FProcedureTotals.Count - 1 do
  begin
    lTotal := TNXProcedureAggregate(FProcedureTotals[lIndex]);
    FDatabase.AddProcedureTotal(FTraceId, lTotal.ProcedureId,
      lTotal.Calls, lTotal.NormalReturns, lTotal.UnwindReturns,
      lTotal.InclusiveTicks, lTotal.SelfTicks, lTotal.MinTicks,
      lTotal.MaxTicks);
  end;
  for lIndex := 0 to FCallEdges.Count - 1 do
  begin
    lEdge := TNXCallEdgeAggregate(FCallEdges[lIndex]);
    FDatabase.AddCallEdge(FTraceId, lEdge.CallerId, lEdge.CalleeId,
      lEdge.Calls, lEdge.InclusiveTicks);
  end;
end;

procedure TNXTraceImporter.ClearAggregates;
begin
  FProcedureTotals.Clear;
  FCallEdges.Clear;
end;

function TNXTraceImporter.SerializeThreadState: TBytes;
var
  lStream: TMemoryStream;
  lIndex: Integer;
  lThread: TNXThreadState;
begin
  Result := nil;
  lStream := TMemoryStream.Create;
  try
    WriteDWord(lStream, cCheckpointMagic);
    WriteDWord(lStream, cCheckpointVersion);
    WriteDWord(lStream, FThreads.Count);
    for lIndex := 0 to FThreads.Count - 1 do
    begin
      lThread := TNXThreadState(FThreads[lIndex]);
      WriteDWord(lStream, lThread.FThreadId);
      WriteDWord(lStream, Ord(lThread.FHasSequence));
      WriteQWord(lStream, lThread.FNextSequence);
    end;
    SetLength(Result, lStream.Size);
    if lStream.Size > 0 then
      Move(lStream.Memory^, Result[0], lStream.Size);
  finally
    lStream.Free;
  end;
end;

procedure TNXTraceImporter.RestoreThreadState(const AData: TBytes);
var
  lStream: TMemoryStream;
  lThreadCount: DWord;
  lIndex: DWord;
  lThread: TNXThreadState;
begin
  lStream := TMemoryStream.Create;
  try
    if Length(AData) > 0 then
      lStream.WriteBuffer(AData[0], Length(AData));
    lStream.Position := 0;
    if ReadDWord(lStream) <> cCheckpointMagic then
      raise EStreamError.Create('Nexus profile checkpoint magic is invalid');
    if ReadDWord(lStream) <> cCheckpointVersion then
      raise EStreamError.Create('Nexus profile checkpoint version is unsupported');
    FThreads.Clear;
    lThreadCount := ReadDWord(lStream);
    if lThreadCount > 0 then
      for lIndex := 0 to lThreadCount - 1 do
      begin
        lThread := TNXThreadState.Create(ReadDWord(lStream));
        lThread.FHasSequence := ReadDWord(lStream) <> 0;
        lThread.FNextSequence := ReadQWord(lStream);
        FThreads.Add(IntToHex(lThread.FThreadId, 8), lThread);
      end;
    if lStream.Position <> lStream.Size then
      raise EStreamError.Create('Nexus profile checkpoint has trailing data');
  finally
    lStream.Free;
  end;
end;

procedure TNXTraceImporter.SaveCheckpoint(ASourceOffset: Int64;
  AFinished: Boolean);
var
  lThreadState: TBytes;
begin
  FlushAggregates;
  lThreadState := SerializeThreadState;
  FDatabase.SaveCheckpoint(FTraceId, ASourceOffset, FProcessedCalls,
    FObservedLostEvents, lThreadState, AFinished);
  FDatabase.CommitCheckpoint;
  ClearAggregates;
  FCheckpointOffset := ASourceOffset;
  ReportBatchMetrics;
end;

procedure TNXTraceImporter.BeginBatchMetrics;
begin
  FBatchStartCalls := FProcessedCalls;
  FBatchStartMilliseconds := GetTickCount64;
  FBatchMetricsActive := True;
  FLastCallMetrics := Default(TNXCallMetrics);
end;

procedure TNXTraceImporter.ReportBatchMetrics;
var
  lBatchRecords: QWord;
  lBatchMilliseconds: QWord;
  lMicrosecondsPerRecord: Double;
begin
  if not FBatchMetricsActive then
    Exit;
  lBatchRecords := FProcessedCalls - FBatchStartCalls;
  lBatchMilliseconds := GetTickCount64 - FBatchStartMilliseconds;
  if lBatchRecords = 0 then
    WriteLn(Format(
      'Import metrics: total records=%d; batch records=0; batch time=%d ms; time per record=n/a',
      [FProcessedCalls, lBatchMilliseconds]))
  else
  begin
    lMicrosecondsPerRecord := lBatchMilliseconds * 1000.0 / lBatchRecords;
    WriteLn(Format(
      'Import metrics: total records=%d; batch records=%d; batch time=%d ms; time per record=%.3f us',
      [FProcessedCalls, lBatchRecords, lBatchMilliseconds,
       lMicrosecondsPerRecord]));
  end;
  if FLastCallMetrics.Available then
    WriteLn(Format(
      'Last record metrics: thread=%u; sequence=%u; index=%u; flags=%u; procedure=%u; caller=%u; total=%.3f us; database=%.3f us; issue=%.3f us; procedure lookup=%.3f us; procedure update=%.3f us; edge lookup=%.3f us; edge update=%.3f us',
      [FLastCallMetrics.ThreadId, FLastCallMetrics.Sequence,
       FLastCallMetrics.CallIndex, FLastCallMetrics.Flags,
       FLastCallMetrics.ProcedureId, FLastCallMetrics.CallerProcedureId,
       Microseconds(FLastCallMetrics.TotalTicks),
       Microseconds(FLastCallMetrics.DatabaseTicks),
       Microseconds(FLastCallMetrics.IssueTicks),
       Microseconds(FLastCallMetrics.ProcedureLookupTicks),
       Microseconds(FLastCallMetrics.ProcedureUpdateTicks),
       Microseconds(FLastCallMetrics.EdgeLookupTicks),
       Microseconds(FLastCallMetrics.EdgeUpdateTicks)]));
  BeginBatchMetrics;
end;

function TNXTraceImporter.Microseconds(ATicks: Int64): Double;
begin
  Result := ATicks * 1000000.0 / FPerformanceFrequency;
end;

procedure TNXTraceImporter.ImportFile(ARunId: Int64;
  const AFileName: string);
var
  lReader: TNXProfileReader;
  lRecord: TNXProfileRecord;
  lExpandedFileName: string;
  lExistingTrace: Boolean;
  lExistingComplete: Boolean;
  lCheckpointFinished: Boolean;
  lCheckpointState: TBytes;
  lCheckpointCalls: QWord;
  lCheckpointLostEvents: QWord;
  lCheckpointOffset: Int64;
  lTraceComplete: Boolean;
  lEndTimestamp: QWord;
  lTotalLost: QWord;
begin
  lExpandedFileName := ExpandFileName(AFileName);
  lReader := TNXProfileReader.Create(AFileName);
  try
    lExistingTrace := FDatabase.FindTrace(ARunId, lExpandedFileName,
      lReader.ProcessId, lReader.SessionId, lReader.ClockFrequency,
      lReader.StartTimestamp, lReader.FormatVersion, lReader.AbiVersion,
      FTraceId, lExistingComplete);
    if lExistingTrace then
    begin
      if FDatabase.LoadCheckpoint(FTraceId, lCheckpointOffset,
        lCheckpointCalls, lCheckpointLostEvents, lCheckpointState,
        lCheckpointFinished) then
      begin
        if lCheckpointFinished then
          Exit;
        RestoreThreadState(lCheckpointState);
        FProcessedCalls := lCheckpointCalls;
        FObservedLostEvents := lCheckpointLostEvents;
        FCheckpointOffset := lCheckpointOffset;
        lReader.ResumeAt(lCheckpointOffset);
      end
      else if lExistingComplete then
        Exit
      else
        raise EStreamError.CreateFmt(
          'Trace %s has no resumable import checkpoint', [lExpandedFileName]);
    end
    else
    begin
      FTraceId := FDatabase.AddTrace(ARunId, lExpandedFileName,
        lReader.ProcessId, lReader.SessionId, lReader.ClockFrequency,
        lReader.StartTimestamp, lReader.FormatVersion, lReader.AbiVersion);
      FCheckpointOffset := lReader.LastCompleteOffset;
      SaveCheckpoint(FCheckpointOffset, False);
    end;
    lTraceComplete := False;
    lEndTimestamp := 0;
    lTotalLost := 0;
    BeginBatchMetrics;
    while lReader.ReadNext(lRecord) do
    begin
      case lRecord.Kind of
        cNXProfileRecordModuleDefine:
          FDatabase.AddModule(FTraceId, lRecord.ModuleInfo);
        cNXProfileRecordModuleUnload:
          FDatabase.UnloadModule(FTraceId, lRecord.ModuleId,
            lRecord.Flags, lRecord.Timestamp);
        cNXProfileRecordProcedureDefine:
          FDatabase.AddProcedure(FTraceId, lRecord.ProcedureInfo);
        cNXProfileRecordThreadDefine:
          FDatabase.AddThread(FTraceId, lRecord.ThreadInfo);
        cNXProfileRecordCallBlock:
          ProcessCallBlock(lRecord.CallBlock);
        cNXProfileRecordTraceGap:
          begin
            FDatabase.AddGap(FTraceId, lRecord.ThreadId, lRecord.Flags,
              lRecord.Sequence, lRecord.LostEventCount, lRecord.Timestamp);
            Inc(FObservedLostEvents, lRecord.LostEventCount);
          end;
        cNXProfileRecordTraceEnd:
          begin
            lTraceComplete := True;
            lEndTimestamp := lRecord.Timestamp;
            lTotalLost := lRecord.LostEventCount;
          end;
      end;
      if (lRecord.Kind <> cNXProfileRecordTraceEnd) and
         (lReader.LastCompleteOffset - FCheckpointOffset >=
          cCheckpointInterval) then
        SaveCheckpoint(lReader.LastCompleteOffset, False);
    end;
    if not lTraceComplete then
      lTotalLost := FObservedLostEvents;
    FDatabase.FinishTrace(FTraceId, lTraceComplete,
      lReader.TruncatedTail, lEndTimestamp, lTotalLost);
    SaveCheckpoint(lReader.LastCompleteOffset, True);
  finally
    lReader.Free;
  end;
end;

procedure CollectProfileFiles(const APath: string; AFiles: TStrings);
var
  lSearch: TSearchRec;
  lName: string;
begin
  if FileExists(APath) then
  begin
    if SameText(ExtractFileExt(APath), '.nxp') then
      AFiles.Add(ExpandFileName(APath));
    Exit;
  end;
  if not DirectoryExists(APath) then
    raise EFOpenError.CreateFmt('Input path does not exist: %s', [APath]);
  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*',
    faAnyFile, lSearch) = 0 then
  try
    repeat
      lName := lSearch.Name;
      if (lName = '.') or (lName = '..') then
        Continue;
      lName := IncludeTrailingPathDelimiter(APath) + lName;
      if (lSearch.Attr and faDirectory) <> 0 then
        CollectProfileFiles(lName, AFiles)
      else if SameText(ExtractFileExt(lName), '.nxp') then
        AFiles.Add(ExpandFileName(lName));
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;
end;

class function TNXProfileImporter.ImportPath(const ADatabaseFile,
  AInputPath, ARunName: string): Integer;
var
  lFiles: TStringList;
  lDatabase: TNXProfileDatabase;
  lImporter: TNXTraceImporter;
  lRunId: Int64;
  lIndex: Integer;
begin
  lFiles := TStringList.Create;
  try
    CollectProfileFiles(AInputPath, lFiles);
    lFiles.Sort;
    if lFiles.Count = 0 then
      raise EFOpenError.CreateFmt('No .nxp files found under %s',
        [AInputPath]);
    lDatabase := TNXProfileDatabase.Create(ADatabaseFile);
    try
      lRunId := lDatabase.FindOrAddRun(ARunName);
      for lIndex := 0 to lFiles.Count - 1 do
      begin
        lImporter := TNXTraceImporter.Create(lDatabase);
        try
          lImporter.ImportFile(lRunId, lFiles[lIndex]);
        finally
          lImporter.Free;
        end;
      end;
      lDatabase.Commit;
      Result := lFiles.Count;
    finally
      lDatabase.Free;
    end;
  finally
    lFiles.Free;
  end;
end;

end.
