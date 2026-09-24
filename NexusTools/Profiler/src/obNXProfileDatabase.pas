unit obNXProfileDatabase;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  DB,
  SQLDB,
  SQLite3Conn,
  tpNXProfileFormat;

type
  TNXProfileDatabase = class
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FCommitted: Boolean;
    FInsertModule: TSQLQuery;
    FUnloadModule: TSQLQuery;
    FInsertProcedure: TSQLQuery;
    FInsertThread: TSQLQuery;
    FInsertCall: TSQLQuery;
    FCallTraceIdParam: TParam;
    FCallThreadIdParam: TParam;
    FCallSequenceParam: TParam;
    FCallIndexParam: TParam;
    FCallFlagsParam: TParam;
    FCallProcedureIdParam: TParam;
    FCallCallerIdParam: TParam;
    FCallInclusiveTicksParam: TParam;
    FCallSelfTicksParam: TParam;
    FInsertGap: TSQLQuery;
    FInsertIssue: TSQLQuery;
    FInsertProcedureTotal: TSQLQuery;
    FInsertCallEdge: TSQLQuery;
    procedure ExecuteSQL(const ASQL: string);
    function NewStatement(const ASQL: string): TSQLQuery;
    function LastInsertId: Int64;
    procedure CreateSchema;
    procedure CreateIndexesAndViews;
    class function HexQWord(AValue: QWord): string; static;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function FindOrAddRun(const AName: string): Int64;
    function FindTrace(ARunId: Int64; const AFileName: string;
      AProcessId: DWord; ASessionId, AClockFrequency,
      AStartTimestamp: QWord; AFormatVersion, AAbiVersion: Word;
      out ATraceId: Int64; out AComplete: Boolean): Boolean;
    function AddTrace(ARunId: Int64; const AFileName: string;
      AProcessId: DWord; ASessionId, AClockFrequency,
      AStartTimestamp: QWord; AFormatVersion, AAbiVersion: Word): Int64;
    procedure AddModule(ATraceId: Int64;
      const AInfo: TNXProfileModuleInfo);
    procedure UnloadModule(ATraceId: Int64; AModuleId, AFlags: DWord;
      ATimestamp: QWord);
    procedure AddProcedure(ATraceId: Int64;
      const AInfo: TNXProfileProcedureInfo);
    procedure AddThread(ATraceId: Int64;
      const AInfo: TNXProfileThreadInfo);
    procedure AddCall(ATraceId: Int64; AThreadId: DWord;
      ASequence: QWord; ACallIndex: DWord;
      const ACall: TNXProfileCall);
    procedure AddGap(ATraceId: Int64; AThreadId, AFlags: DWord;
      ASequence, ALostEventCount, ATimestamp: QWord);
    procedure AddIssue(ATraceId: Int64; AThreadId: DWord;
      ASequence: QWord; AEventIndex: Int64; const AKind, ADetails: string);
    procedure AddProcedureTotal(ATraceId: Int64; AProcedureId: DWord;
      ACalls, ANormalReturns, AUnwindReturns, AInclusiveTicks,
      ASelfTicks, AMinTicks, AMaxTicks: QWord);
    procedure AddCallEdge(ATraceId: Int64; ACallerId, ACalleeId: DWord;
      ACalls, AInclusiveTicks: QWord);
    function LoadCheckpoint(ATraceId: Int64; out ASourceOffset: Int64;
      out AProcessedEvents, AObservedLostEvents: QWord;
      out AThreadState: TBytes; out AFinished: Boolean): Boolean;
    procedure SaveCheckpoint(ATraceId, ASourceOffset: Int64;
      AProcessedEvents, AObservedLostEvents: QWord;
      const AThreadState: TBytes; AFinished: Boolean);
    procedure FinishTrace(ATraceId: Int64; AComplete, ATruncated: Boolean;
      AEndTimestamp, ATotalLostEventCount: QWord);
    procedure CommitCheckpoint;
    procedure Commit;
  end;

implementation

constructor TNXProfileDatabase.Create(const AFileName: string);
var
  lDirectory: string;
begin
  inherited Create;
  lDirectory := ExtractFileDir(ExpandFileName(AFileName));
  if (lDirectory <> '') and (not DirectoryExists(lDirectory)) then
    ForceDirectories(lDirectory);

  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FConnection.DatabaseName := AFileName;
  FConnection.Transaction := FTransaction;
  FTransaction.DataBase := FConnection;
  FConnection.Open;
  FTransaction.StartTransaction;
  ExecuteSQL('pragma foreign_keys = on');
  CreateSchema;

  FInsertModule := NewStatement(
    'insert into nxp_module(trace_id, source_module_id, flags, build_id_hex, ' +
    'load_address_hex, load_timestamp, image_path) values(:trace_id, ' +
    ':module_id, :flags, :build_id, :load_address, :timestamp, :image_path)');
  FUnloadModule := NewStatement(
    'update nxp_module set unload_flags = :flags, unload_timestamp = :timestamp ' +
    'where trace_id = :trace_id and source_module_id = :module_id');
  FInsertProcedure := NewStatement(
    'insert into nxp_procedure(trace_id, source_procedure_id, ' +
    'source_module_id, flags, stable_id_hex, code_start_hex, code_end_hex, ' +
    'source_line, source_column, name, unit_name, source_file) values(' +
    ':trace_id, :procedure_id, :module_id, :flags, :stable_id, :code_start, ' +
    ':code_end, :source_line, :source_column, :name, :unit_name, :source_file)');
  FInsertThread := NewStatement(
    'insert into nxp_thread(trace_id, source_thread_id, flags, start_timestamp, ' +
    'name) values(:trace_id, :thread_id, :flags, :timestamp, :name)');
  FInsertCall := NewStatement(
    'insert into nxp_call(trace_id, source_thread_id, block_sequence, ' +
    'call_index, flags, source_procedure_id, caller_procedure_id, ' +
    'inclusive_ticks, self_ticks) values(:trace_id, :thread_id, :sequence, ' +
    ':call_index, :flags, :procedure_id, :caller_id, :inclusive_ticks, ' +
    ':self_ticks)');
  FCallTraceIdParam := FInsertCall.ParamByName('trace_id');
  FCallThreadIdParam := FInsertCall.ParamByName('thread_id');
  FCallSequenceParam := FInsertCall.ParamByName('sequence');
  FCallIndexParam := FInsertCall.ParamByName('call_index');
  FCallFlagsParam := FInsertCall.ParamByName('flags');
  FCallProcedureIdParam := FInsertCall.ParamByName('procedure_id');
  FCallCallerIdParam := FInsertCall.ParamByName('caller_id');
  FCallInclusiveTicksParam := FInsertCall.ParamByName('inclusive_ticks');
  FCallSelfTicksParam := FInsertCall.ParamByName('self_ticks');
  FInsertGap := NewStatement(
    'insert into nxp_trace_gap(trace_id, source_thread_id, flags, sequence, ' +
    'lost_event_count, timestamp) values(:trace_id, :thread_id, :flags, ' +
    ':sequence, :lost_count, :timestamp)');
  FInsertIssue := NewStatement(
    'insert into nxp_import_issue(trace_id, source_thread_id, sequence, ' +
    'event_index, issue_kind, details) values(:trace_id, :thread_id, ' +
    ':sequence, :event_index, :kind, :details)');
  FInsertProcedureTotal := NewStatement(
    'insert into nxp_procedure_total(trace_id, source_procedure_id, calls, ' +
    'normal_returns, unwind_returns, inclusive_ticks, self_ticks, min_ticks, ' +
    'max_ticks) values(:trace_id, :procedure_id, :calls, :normal_returns, ' +
    ':unwind_returns, :inclusive_ticks, :self_ticks, :min_ticks, :max_ticks) ' +
    'on conflict(trace_id, source_procedure_id) do update set ' +
    'calls = calls + excluded.calls, ' +
    'normal_returns = normal_returns + excluded.normal_returns, ' +
    'unwind_returns = unwind_returns + excluded.unwind_returns, ' +
    'inclusive_ticks = inclusive_ticks + excluded.inclusive_ticks, ' +
    'self_ticks = self_ticks + excluded.self_ticks, ' +
    'min_ticks = min(min_ticks, excluded.min_ticks), ' +
    'max_ticks = max(max_ticks, excluded.max_ticks)');
  FInsertCallEdge := NewStatement(
    'insert into nxp_call_edge(trace_id, caller_procedure_id, ' +
    'callee_procedure_id, calls, inclusive_ticks) values(:trace_id, ' +
    ':caller_id, :callee_id, :calls, :inclusive_ticks) ' +
    'on conflict(trace_id, caller_procedure_id, callee_procedure_id) ' +
    'do update set calls = calls + excluded.calls, ' +
    'inclusive_ticks = inclusive_ticks + excluded.inclusive_ticks');
end;

destructor TNXProfileDatabase.Destroy;
begin
  FInsertCallEdge.Free;
  FInsertProcedureTotal.Free;
  FInsertIssue.Free;
  FInsertGap.Free;
  FInsertCall.Free;
  FInsertThread.Free;
  FInsertProcedure.Free;
  FUnloadModule.Free;
  FInsertModule.Free;
  if (FTransaction <> nil) and FTransaction.Active and (not FCommitted) then
    FTransaction.Rollback;
  FTransaction.Free;
  FConnection.Free;
  inherited Destroy;
end;

procedure TNXProfileDatabase.ExecuteSQL(const ASQL: string);
begin
  FConnection.ExecuteDirect(ASQL);
end;

function TNXProfileDatabase.NewStatement(const ASQL: string): TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConnection;
  Result.Transaction := FTransaction;
  Result.SQL.Text := ASQL;
  Result.Prepare;
end;

function TNXProfileDatabase.LastInsertId: Int64;
var
  lQuery: TSQLQuery;
begin
  lQuery := TSQLQuery.Create(nil);
  try
    lQuery.DataBase := FConnection;
    lQuery.Transaction := FTransaction;
    lQuery.SQL.Text := 'select last_insert_rowid() as id';
    lQuery.Open;
    Result := lQuery.FieldByName('id').AsLargeInt;
  finally
    lQuery.Free;
  end;
end;

class function TNXProfileDatabase.HexQWord(AValue: QWord): string;
begin
  Result := IntToHex(AValue, 16);
end;

procedure TNXProfileDatabase.CreateSchema;
begin
  ExecuteSQL('pragma user_version = 3');
  ExecuteSQL('create table if not exists nxp_run (' +
    'id integer primary key, name text not null, imported_at text not null)');
  ExecuteSQL('create table if not exists nxp_trace (' +
    'id integer primary key, run_id integer not null, file_name text not null, ' +
    'process_id integer not null, session_id_hex text not null, ' +
    'clock_frequency integer not null, start_timestamp integer not null, ' +
    'format_version integer not null, abi_version integer not null, ' +
    'complete integer not null default 0, truncated_tail integer not null default 0, ' +
    'end_timestamp integer, total_lost_events integer not null default 0, ' +
    'foreign key(run_id) references nxp_run(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_module (' +
    'id integer primary key, trace_id integer not null, ' +
    'source_module_id integer not null, flags integer not null, ' +
    'build_id_hex text not null, load_address_hex text not null, ' +
    'load_timestamp integer not null, image_path text not null, ' +
    'unload_flags integer, unload_timestamp integer, ' +
    'unique(trace_id, source_module_id), ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_procedure (' +
    'id integer primary key, trace_id integer not null, ' +
    'source_procedure_id integer not null, source_module_id integer not null, ' +
    'flags integer not null, stable_id_hex text not null, ' +
    'code_start_hex text not null, code_end_hex text not null, ' +
    'source_line integer not null, source_column integer not null, ' +
    'name text not null, unit_name text not null, source_file text not null, ' +
    'unique(trace_id, source_procedure_id), ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_thread (' +
    'id integer primary key, trace_id integer not null, ' +
    'source_thread_id integer not null, flags integer not null, ' +
    'start_timestamp integer not null, name text not null, ' +
    'unique(trace_id, source_thread_id), ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_call (' +
    'id integer primary key, trace_id integer not null, ' +
    'source_thread_id integer not null, block_sequence integer not null, ' +
    'call_index integer not null, flags integer not null, ' +
    'source_procedure_id integer not null, caller_procedure_id integer not null, ' +
    'inclusive_ticks integer not null, self_ticks integer not null, ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_trace_gap (' +
    'id integer primary key, trace_id integer not null, ' +
    'source_thread_id integer not null, flags integer not null, ' +
    'sequence integer not null, lost_event_count integer not null, ' +
    'timestamp integer not null, ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_import_issue (' +
    'id integer primary key, trace_id integer not null, ' +
    'source_thread_id integer not null, sequence integer not null, ' +
    'event_index integer not null, issue_kind text not null, details text not null, ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_procedure_total (' +
    'trace_id integer not null, source_procedure_id integer not null, ' +
    'calls integer not null, normal_returns integer not null, ' +
    'unwind_returns integer not null, inclusive_ticks integer not null, ' +
    'self_ticks integer not null, min_ticks integer not null, max_ticks integer not null, ' +
    'primary key(trace_id, source_procedure_id), ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_call_edge (' +
    'trace_id integer not null, caller_procedure_id integer not null, ' +
    'callee_procedure_id integer not null, calls integer not null, ' +
    'inclusive_ticks integer not null, ' +
    'primary key(trace_id, caller_procedure_id, callee_procedure_id), ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
  ExecuteSQL('create table if not exists nxp_import_checkpoint (' +
    'trace_id integer primary key, source_offset integer not null, ' +
    'processed_events integer not null, observed_lost_events integer not null, ' +
    'thread_state blob not null, finished integer not null, updated_at text not null, ' +
    'foreign key(trace_id) references nxp_trace(id) on delete cascade)');
end;

procedure TNXProfileDatabase.CreateIndexesAndViews;
begin
  ExecuteSQL('create index if not exists idx_nxp_trace_run on nxp_trace(run_id)');
  ExecuteSQL('create index if not exists idx_nxp_procedure_trace on nxp_procedure(trace_id)');
  ExecuteSQL('create index if not exists idx_nxp_procedure_stable on nxp_procedure(stable_id_hex)');
  ExecuteSQL('create index if not exists idx_nxp_call_trace_thread on ' +
    'nxp_call(trace_id, source_thread_id, block_sequence, call_index)');
  ExecuteSQL('create index if not exists idx_nxp_total_self on ' +
    'nxp_procedure_total(trace_id, self_ticks desc)');
  ExecuteSQL('create view if not exists v_nxp_procedure_totals as ' +
    'select r.id as run_id, r.name as run_name, t.id as trace_id, t.file_name, ' +
    't.process_id, p.source_procedure_id, p.stable_id_hex, p.name, p.unit_name, ' +
    'p.source_file, p.source_line, a.calls, a.normal_returns, a.unwind_returns, ' +
    'a.inclusive_ticks, a.self_ticks, a.min_ticks, a.max_ticks, ' +
    'cast(a.inclusive_ticks as real) / t.clock_frequency as inclusive_seconds, ' +
    'cast(a.self_ticks as real) / t.clock_frequency as self_seconds ' +
    'from nxp_procedure_total a join nxp_trace t on t.id = a.trace_id ' +
    'join nxp_run r on r.id = t.run_id left join nxp_procedure p on ' +
    'p.trace_id = a.trace_id and p.source_procedure_id = a.source_procedure_id');
  ExecuteSQL('create view if not exists v_nxp_hotspots as ' +
    'select r.id as run_id, r.name as run_name, p.stable_id_hex, p.name, ' +
    'p.unit_name, p.source_file, p.source_line, sum(a.calls) as calls, ' +
    'sum(a.normal_returns) as normal_returns, sum(a.unwind_returns) as unwind_returns, ' +
    'sum(cast(a.inclusive_ticks as real) / t.clock_frequency) as inclusive_seconds, ' +
    'sum(cast(a.self_ticks as real) / t.clock_frequency) as self_seconds ' +
    'from nxp_procedure_total a join nxp_trace t on t.id = a.trace_id ' +
    'join nxp_run r on r.id = t.run_id left join nxp_procedure p on ' +
    'p.trace_id = a.trace_id and p.source_procedure_id = a.source_procedure_id ' +
    'group by r.id, p.stable_id_hex, p.name, p.unit_name, ' +
    'p.source_file, p.source_line');
  ExecuteSQL('create view if not exists v_nxp_call_edges as ' +
    'select r.id as run_id, r.name as run_name, e.trace_id, ' +
    'caller.stable_id_hex as caller_stable_id_hex, caller.name as caller_name, ' +
    'callee.stable_id_hex as callee_stable_id_hex, callee.name as callee_name, ' +
    'e.calls, e.inclusive_ticks, ' +
    'cast(e.inclusive_ticks as real) / t.clock_frequency as inclusive_seconds ' +
    'from nxp_call_edge e join nxp_trace t on t.id = e.trace_id ' +
    'join nxp_run r on r.id = t.run_id left join nxp_procedure caller on ' +
    'caller.trace_id = e.trace_id and caller.source_procedure_id = e.caller_procedure_id ' +
    'left join nxp_procedure callee on callee.trace_id = e.trace_id and ' +
    'callee.source_procedure_id = e.callee_procedure_id');
  ExecuteSQL('create view if not exists v_nxp_trace_summary as ' +
    'select r.id as run_id, r.name as run_name, t.id as trace_id, t.file_name, ' +
    't.process_id, t.complete, t.truncated_tail, t.total_lost_events, ' +
    '(select count(*) from nxp_call c where c.trace_id = t.id) as call_count, ' +
    '(select count(*) from nxp_import_issue i where i.trace_id = t.id) as issue_count ' +
    'from nxp_trace t join nxp_run r on r.id = t.run_id');
end;
function TNXProfileDatabase.FindOrAddRun(const AName: string): Int64;
var
  lQuery: TSQLQuery;
begin
  lQuery := NewStatement(
    'select id from nxp_run where name = :name order by id limit 1');
  try
    lQuery.ParamByName('name').AsString := AName;
    lQuery.Open;
    if not lQuery.EOF then
      Exit(lQuery.FieldByName('id').AsLargeInt);
  finally
    lQuery.Free;
  end;

  lQuery := NewStatement(
    'insert into nxp_run(name, imported_at) values(:name, :imported_at)');
  try
    lQuery.ParamByName('name').AsString := AName;
    lQuery.ParamByName('imported_at').AsString :=
      FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    lQuery.ExecSQL;
    Result := LastInsertId;
  finally
    lQuery.Free;
  end;
end;

function TNXProfileDatabase.FindTrace(ARunId: Int64;
  const AFileName: string; AProcessId: DWord; ASessionId,
  AClockFrequency, AStartTimestamp: QWord; AFormatVersion,
  AAbiVersion: Word; out ATraceId: Int64;
  out AComplete: Boolean): Boolean;
var
  lQuery: TSQLQuery;
begin
  ATraceId := 0;
  AComplete := False;
  lQuery := NewStatement(
    'select id, complete from nxp_trace where run_id = :run_id and ' +
    'file_name = :file_name and process_id = :process_id and ' +
    'session_id_hex = :session_id and clock_frequency = :frequency and ' +
    'start_timestamp = :start_timestamp and format_version = :format_version ' +
    'and abi_version = :abi_version order by id limit 1');
  try
    lQuery.ParamByName('run_id').AsLargeInt := ARunId;
    lQuery.ParamByName('file_name').AsString := AFileName;
    lQuery.ParamByName('process_id').AsLargeInt := AProcessId;
    lQuery.ParamByName('session_id').AsString := HexQWord(ASessionId);
    lQuery.ParamByName('frequency').AsLargeInt := Int64(AClockFrequency);
    lQuery.ParamByName('start_timestamp').AsLargeInt := Int64(AStartTimestamp);
    lQuery.ParamByName('format_version').AsInteger := AFormatVersion;
    lQuery.ParamByName('abi_version').AsInteger := AAbiVersion;
    lQuery.Open;
    Result := not lQuery.EOF;
    if Result then
    begin
      ATraceId := lQuery.FieldByName('id').AsLargeInt;
      AComplete := lQuery.FieldByName('complete').AsInteger <> 0;
    end;
  finally
    lQuery.Free;
  end;
end;

function TNXProfileDatabase.AddTrace(ARunId: Int64;
  const AFileName: string; AProcessId: DWord; ASessionId,
  AClockFrequency, AStartTimestamp: QWord; AFormatVersion,
  AAbiVersion: Word): Int64;
var
  lQuery: TSQLQuery;
begin
  lQuery := NewStatement(
    'insert into nxp_trace(run_id, file_name, process_id, session_id_hex, ' +
    'clock_frequency, start_timestamp, format_version, abi_version) values(' +
    ':run_id, :file_name, :process_id, :session_id, :frequency, ' +
    ':start_timestamp, :format_version, :abi_version)');
  try
    lQuery.ParamByName('run_id').AsLargeInt := ARunId;
    lQuery.ParamByName('file_name').AsString := AFileName;
    lQuery.ParamByName('process_id').AsLargeInt := AProcessId;
    lQuery.ParamByName('session_id').AsString := HexQWord(ASessionId);
    lQuery.ParamByName('frequency').AsLargeInt := Int64(AClockFrequency);
    lQuery.ParamByName('start_timestamp').AsLargeInt := Int64(AStartTimestamp);
    lQuery.ParamByName('format_version').AsInteger := AFormatVersion;
    lQuery.ParamByName('abi_version').AsInteger := AAbiVersion;
    lQuery.ExecSQL;
    Result := LastInsertId;
  finally
    lQuery.Free;
  end;
end;

procedure TNXProfileDatabase.AddModule(ATraceId: Int64;
  const AInfo: TNXProfileModuleInfo);
begin
  FInsertModule.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertModule.ParamByName('module_id').AsLargeInt := AInfo.ModuleId;
  FInsertModule.ParamByName('flags').AsLargeInt := AInfo.Flags;
  FInsertModule.ParamByName('build_id').AsString := HexQWord(AInfo.BuildId);
  FInsertModule.ParamByName('load_address').AsString := HexQWord(AInfo.LoadAddress);
  FInsertModule.ParamByName('timestamp').AsLargeInt := Int64(AInfo.Timestamp);
  FInsertModule.ParamByName('image_path').AsString := AInfo.ImagePath;
  FInsertModule.ExecSQL;
end;

procedure TNXProfileDatabase.UnloadModule(ATraceId: Int64;
  AModuleId, AFlags: DWord; ATimestamp: QWord);
begin
  FUnloadModule.ParamByName('trace_id').AsLargeInt := ATraceId;
  FUnloadModule.ParamByName('module_id').AsLargeInt := AModuleId;
  FUnloadModule.ParamByName('flags').AsLargeInt := AFlags;
  FUnloadModule.ParamByName('timestamp').AsLargeInt := Int64(ATimestamp);
  FUnloadModule.ExecSQL;
end;

procedure TNXProfileDatabase.AddProcedure(ATraceId: Int64;
  const AInfo: TNXProfileProcedureInfo);
begin
  FInsertProcedure.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertProcedure.ParamByName('procedure_id').AsLargeInt := AInfo.ProcedureId;
  FInsertProcedure.ParamByName('module_id').AsLargeInt := AInfo.ModuleId;
  FInsertProcedure.ParamByName('flags').AsLargeInt := AInfo.Flags;
  FInsertProcedure.ParamByName('stable_id').AsString := HexQWord(AInfo.StableId);
  FInsertProcedure.ParamByName('code_start').AsString := HexQWord(AInfo.CodeStart);
  FInsertProcedure.ParamByName('code_end').AsString := HexQWord(AInfo.CodeEnd);
  FInsertProcedure.ParamByName('source_line').AsLargeInt := AInfo.SourceLine;
  FInsertProcedure.ParamByName('source_column').AsLargeInt := AInfo.SourceColumn;
  FInsertProcedure.ParamByName('name').AsString := AInfo.Name;
  FInsertProcedure.ParamByName('unit_name').AsString := AInfo.UnitName;
  FInsertProcedure.ParamByName('source_file').AsString := AInfo.SourceFile;
  FInsertProcedure.ExecSQL;
end;

procedure TNXProfileDatabase.AddThread(ATraceId: Int64;
  const AInfo: TNXProfileThreadInfo);
begin
  FInsertThread.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertThread.ParamByName('thread_id').AsLargeInt := AInfo.ThreadId;
  FInsertThread.ParamByName('flags').AsLargeInt := AInfo.Flags;
  FInsertThread.ParamByName('timestamp').AsLargeInt := Int64(AInfo.Timestamp);
  FInsertThread.ParamByName('name').AsString := AInfo.Name;
  FInsertThread.ExecSQL;
end;

procedure TNXProfileDatabase.AddCall(ATraceId: Int64;
  AThreadId: DWord; ASequence: QWord; ACallIndex: DWord;
  const ACall: TNXProfileCall);
begin
  FCallTraceIdParam.AsLargeInt := ATraceId;
  FCallThreadIdParam.AsLargeInt := AThreadId;
  FCallSequenceParam.AsLargeInt := Int64(ASequence);
  FCallIndexParam.AsLargeInt := ACallIndex;
  FCallFlagsParam.AsInteger := ACall.Flags;
  FCallProcedureIdParam.AsLargeInt := ACall.ProcedureId;
  FCallCallerIdParam.AsLargeInt := ACall.CallerProcedureId;
  FCallInclusiveTicksParam.AsLargeInt := Int64(ACall.InclusiveTicks);
  FCallSelfTicksParam.AsLargeInt := Int64(ACall.SelfTicks);
  FInsertCall.ExecSQL;
end;

procedure TNXProfileDatabase.AddGap(ATraceId: Int64;
  AThreadId, AFlags: DWord; ASequence, ALostEventCount,
  ATimestamp: QWord);
begin
  FInsertGap.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertGap.ParamByName('thread_id').AsLargeInt := AThreadId;
  FInsertGap.ParamByName('flags').AsLargeInt := AFlags;
  FInsertGap.ParamByName('sequence').AsLargeInt := Int64(ASequence);
  FInsertGap.ParamByName('lost_count').AsLargeInt := Int64(ALostEventCount);
  FInsertGap.ParamByName('timestamp').AsLargeInt := Int64(ATimestamp);
  FInsertGap.ExecSQL;
end;

procedure TNXProfileDatabase.AddIssue(ATraceId: Int64;
  AThreadId: DWord; ASequence: QWord; AEventIndex: Int64;
  const AKind, ADetails: string);
begin
  FInsertIssue.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertIssue.ParamByName('thread_id').AsLargeInt := AThreadId;
  FInsertIssue.ParamByName('sequence').AsLargeInt := Int64(ASequence);
  FInsertIssue.ParamByName('event_index').AsLargeInt := AEventIndex;
  FInsertIssue.ParamByName('kind').AsString := AKind;
  FInsertIssue.ParamByName('details').AsString := ADetails;
  FInsertIssue.ExecSQL;
end;

procedure TNXProfileDatabase.AddProcedureTotal(ATraceId: Int64;
  AProcedureId: DWord; ACalls, ANormalReturns, AUnwindReturns,
  AInclusiveTicks, ASelfTicks, AMinTicks, AMaxTicks: QWord);
begin
  FInsertProcedureTotal.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertProcedureTotal.ParamByName('procedure_id').AsLargeInt := AProcedureId;
  FInsertProcedureTotal.ParamByName('calls').AsLargeInt := Int64(ACalls);
  FInsertProcedureTotal.ParamByName('normal_returns').AsLargeInt := Int64(ANormalReturns);
  FInsertProcedureTotal.ParamByName('unwind_returns').AsLargeInt := Int64(AUnwindReturns);
  FInsertProcedureTotal.ParamByName('inclusive_ticks').AsLargeInt := Int64(AInclusiveTicks);
  FInsertProcedureTotal.ParamByName('self_ticks').AsLargeInt := Int64(ASelfTicks);
  FInsertProcedureTotal.ParamByName('min_ticks').AsLargeInt := Int64(AMinTicks);
  FInsertProcedureTotal.ParamByName('max_ticks').AsLargeInt := Int64(AMaxTicks);
  FInsertProcedureTotal.ExecSQL;
end;

procedure TNXProfileDatabase.AddCallEdge(ATraceId: Int64;
  ACallerId, ACalleeId: DWord; ACalls, AInclusiveTicks: QWord);
begin
  FInsertCallEdge.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertCallEdge.ParamByName('caller_id').AsLargeInt := ACallerId;
  FInsertCallEdge.ParamByName('callee_id').AsLargeInt := ACalleeId;
  FInsertCallEdge.ParamByName('calls').AsLargeInt := Int64(ACalls);
  FInsertCallEdge.ParamByName('inclusive_ticks').AsLargeInt := Int64(AInclusiveTicks);
  FInsertCallEdge.ExecSQL;
end;

function TNXProfileDatabase.LoadCheckpoint(ATraceId: Int64;
  out ASourceOffset: Int64; out AProcessedEvents,
  AObservedLostEvents: QWord; out AThreadState: TBytes;
  out AFinished: Boolean): Boolean;
var
  lQuery: TSQLQuery;
  lStream: TMemoryStream;
begin
  ASourceOffset := 0;
  AProcessedEvents := 0;
  AObservedLostEvents := 0;
  AThreadState := nil;
  AFinished := False;
  lQuery := NewStatement(
    'select source_offset, processed_events, observed_lost_events, ' +
    'thread_state, finished from nxp_import_checkpoint where trace_id = :trace_id');
  try
    lQuery.ParamByName('trace_id').AsLargeInt := ATraceId;
    lQuery.Open;
    Result := not lQuery.EOF;
    if not Result then
      Exit;
    ASourceOffset := lQuery.FieldByName('source_offset').AsLargeInt;
    AProcessedEvents := QWord(
      lQuery.FieldByName('processed_events').AsLargeInt);
    AObservedLostEvents := QWord(
      lQuery.FieldByName('observed_lost_events').AsLargeInt);
    AFinished := lQuery.FieldByName('finished').AsInteger <> 0;
    lStream := TMemoryStream.Create;
    try
      TBlobField(lQuery.FieldByName('thread_state')).SaveToStream(lStream);
      SetLength(AThreadState, lStream.Size);
      if lStream.Size > 0 then
        Move(lStream.Memory^, AThreadState[0], lStream.Size);
    finally
      lStream.Free;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TNXProfileDatabase.SaveCheckpoint(ATraceId,
  ASourceOffset: Int64; AProcessedEvents,
  AObservedLostEvents: QWord; const AThreadState: TBytes;
  AFinished: Boolean);
var
  lQuery: TSQLQuery;
begin
  lQuery := NewStatement(
    'insert into nxp_import_checkpoint(trace_id, source_offset, ' +
    'processed_events, observed_lost_events, thread_state, finished, updated_at) ' +
    'values(:trace_id, :source_offset, :processed_events, :observed_lost_events, ' +
    ':thread_state, :finished, :updated_at) ' +
    'on conflict(trace_id) do update set ' +
    'source_offset = excluded.source_offset, ' +
    'processed_events = excluded.processed_events, ' +
    'observed_lost_events = excluded.observed_lost_events, ' +
    'thread_state = excluded.thread_state, finished = excluded.finished, ' +
    'updated_at = excluded.updated_at');
  try
    lQuery.ParamByName('trace_id').AsLargeInt := ATraceId;
    lQuery.ParamByName('source_offset').AsLargeInt := ASourceOffset;
    lQuery.ParamByName('processed_events').AsLargeInt := Int64(AProcessedEvents);
    lQuery.ParamByName('observed_lost_events').AsLargeInt :=
      Int64(AObservedLostEvents);
    lQuery.ParamByName('thread_state').AsBlob := AThreadState;
    lQuery.ParamByName('finished').AsInteger := Ord(AFinished);
    lQuery.ParamByName('updated_at').AsString :=
      FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
end;

procedure TNXProfileDatabase.FinishTrace(ATraceId: Int64;
  AComplete, ATruncated: Boolean; AEndTimestamp,
  ATotalLostEventCount: QWord);
var
  lQuery: TSQLQuery;
begin
  lQuery := NewStatement(
    'update nxp_trace set complete = :complete, truncated_tail = :truncated, ' +
    'end_timestamp = :end_timestamp, total_lost_events = :lost_count where id = :id');
  try
    lQuery.ParamByName('complete').AsInteger := Ord(AComplete);
    lQuery.ParamByName('truncated').AsInteger := Ord(ATruncated);
    lQuery.ParamByName('end_timestamp').AsLargeInt := Int64(AEndTimestamp);
    lQuery.ParamByName('lost_count').AsLargeInt := Int64(ATotalLostEventCount);
    lQuery.ParamByName('id').AsLargeInt := ATraceId;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
end;

procedure TNXProfileDatabase.Commit;
begin
  CreateIndexesAndViews;
  FTransaction.Commit;
  FCommitted := True;
end;

procedure TNXProfileDatabase.CommitCheckpoint;
begin
  FTransaction.Commit;
  FTransaction.StartTransaction;
end;

end.
