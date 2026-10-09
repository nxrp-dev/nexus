(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXProfileDatabase;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  DB,
  SQLite3Dyn,
  obNXSQLiteConnection,
  obNXSQLiteDataSet,
  tpNXProfileFormat;

type
  TNXProfileDatabase = class
  private
    FConnection: TNXSQLiteConnection;
    FCommitted: Boolean;
    FInsertModule: Psqlite3_stmt;
    FInsertModuleParams: TParams;
    FUnloadModule: Psqlite3_stmt;
    FUnloadModuleParams: TParams;
    FInsertProcedure: Psqlite3_stmt;
    FInsertProcedureParams: TParams;
    FInsertThread: Psqlite3_stmt;
    FInsertThreadParams: TParams;
    FInsertCall: Psqlite3_stmt;
    FInsertCallParams: TParams;
    FCallTraceIdParam: TParam;
    FCallThreadIdParam: TParam;
    FCallSequenceParam: TParam;
    FCallIndexParam: TParam;
    FCallFlagsParam: TParam;
    FCallProcedureIdParam: TParam;
    FCallCallerIdParam: TParam;
    FCallInclusiveTicksParam: TParam;
    FCallSelfTicksParam: TParam;
    FInsertGap: Psqlite3_stmt;
    FInsertGapParams: TParams;
    FInsertIssue: Psqlite3_stmt;
    FInsertIssueParams: TParams;
    FInsertProcedureTotal: Psqlite3_stmt;
    FInsertProcedureTotalParams: TParams;
    FInsertCallEdge: Psqlite3_stmt;
    FInsertCallEdgeParams: TParams;
    procedure ExecuteSQL(const ASQL: string);
    function NewStatement(const ASQL: string): TNXSQLiteDataSet;
    function PrepareStatement(out AParams: TParams; const ASQL: string): Psqlite3_stmt;
    procedure ExecuteStatement(AStatement: Psqlite3_stmt; AParams: TParams);
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

  FConnection := TNXSQLiteConnection.Create(nil);
  FConnection.DatabaseName := AFileName;
  FConnection.Open;
  ExecuteSQL('pragma foreign_keys = on');
  FConnection.StartTransaction;
  CreateSchema;

  FInsertModule := PrepareStatement(FInsertModuleParams,
    'insert into nxp_module(trace_id, source_module_id, flags, build_id_hex, ' +
    'load_address_hex, load_timestamp, image_path) values(:trace_id, ' +
    ':module_id, :flags, :build_id, :load_address, :timestamp, :image_path)');
  FUnloadModule := PrepareStatement(FUnloadModuleParams,
    'update nxp_module set unload_flags = :flags, unload_timestamp = :timestamp ' +
    'where trace_id = :trace_id and source_module_id = :module_id');
  FInsertProcedure := PrepareStatement(FInsertProcedureParams,
    'insert into nxp_procedure(trace_id, source_procedure_id, ' +
    'source_module_id, flags, stable_id_hex, code_start_hex, code_end_hex, ' +
    'source_line, source_column, name, unit_name, source_file) values(' +
    ':trace_id, :procedure_id, :module_id, :flags, :stable_id, :code_start, ' +
    ':code_end, :source_line, :source_column, :name, :unit_name, :source_file)');
  FInsertThread := PrepareStatement(FInsertThreadParams,
    'insert into nxp_thread(trace_id, source_thread_id, flags, start_timestamp, ' +
    'name) values(:trace_id, :thread_id, :flags, :timestamp, :name)');
  FInsertCall := PrepareStatement(FInsertCallParams,
    'insert into nxp_call(trace_id, source_thread_id, block_sequence, ' +
    'call_index, flags, source_procedure_id, caller_procedure_id, ' +
    'inclusive_ticks, self_ticks) values(:trace_id, :thread_id, :sequence, ' +
    ':call_index, :flags, :procedure_id, :caller_id, :inclusive_ticks, ' +
    ':self_ticks)');
  FCallTraceIdParam := FInsertCallParams.ParamByName('trace_id');
  FCallThreadIdParam := FInsertCallParams.ParamByName('thread_id');
  FCallSequenceParam := FInsertCallParams.ParamByName('sequence');
  FCallIndexParam := FInsertCallParams.ParamByName('call_index');
  FCallFlagsParam := FInsertCallParams.ParamByName('flags');
  FCallProcedureIdParam := FInsertCallParams.ParamByName('procedure_id');
  FCallCallerIdParam := FInsertCallParams.ParamByName('caller_id');
  FCallInclusiveTicksParam := FInsertCallParams.ParamByName('inclusive_ticks');
  FCallSelfTicksParam := FInsertCallParams.ParamByName('self_ticks');
  FInsertGap := PrepareStatement(FInsertGapParams,
    'insert into nxp_trace_gap(trace_id, source_thread_id, flags, sequence, ' +
    'lost_event_count, timestamp) values(:trace_id, :thread_id, :flags, ' +
    ':sequence, :lost_count, :timestamp)');
  FInsertIssue := PrepareStatement(FInsertIssueParams,
    'insert into nxp_import_issue(trace_id, source_thread_id, sequence, ' +
    'event_index, issue_kind, details) values(:trace_id, :thread_id, ' +
    ':sequence, :event_index, :kind, :details)');
  FInsertProcedureTotal := PrepareStatement(FInsertProcedureTotalParams,
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
  FInsertCallEdge := PrepareStatement(FInsertCallEdgeParams,
    'insert into nxp_call_edge(trace_id, caller_procedure_id, ' +
    'callee_procedure_id, calls, inclusive_ticks) values(:trace_id, ' +
    ':caller_id, :callee_id, :calls, :inclusive_ticks) ' +
    'on conflict(trace_id, caller_procedure_id, callee_procedure_id) ' +
    'do update set calls = calls + excluded.calls, ' +
    'inclusive_ticks = inclusive_ticks + excluded.inclusive_ticks');
end;

destructor TNXProfileDatabase.Destroy;
begin
  if FInsertCallEdge <> nil then sqlite3_finalize(FInsertCallEdge);
  FInsertCallEdgeParams.Free;
  if FInsertProcedureTotal <> nil then sqlite3_finalize(FInsertProcedureTotal);
  FInsertProcedureTotalParams.Free;
  if FInsertIssue <> nil then sqlite3_finalize(FInsertIssue);
  FInsertIssueParams.Free;
  if FInsertGap <> nil then sqlite3_finalize(FInsertGap);
  FInsertGapParams.Free;
  if FInsertCall <> nil then sqlite3_finalize(FInsertCall);
  FInsertCallParams.Free;
  if FInsertThread <> nil then sqlite3_finalize(FInsertThread);
  FInsertThreadParams.Free;
  if FInsertProcedure <> nil then sqlite3_finalize(FInsertProcedure);
  FInsertProcedureParams.Free;
  if FUnloadModule <> nil then sqlite3_finalize(FUnloadModule);
  FUnloadModuleParams.Free;
  if FInsertModule <> nil then sqlite3_finalize(FInsertModule);
  FInsertModuleParams.Free;
  if (FConnection <> nil) and FConnection.InTransaction and (not FCommitted) then
    FConnection.Rollback;
  FConnection.Free;
  inherited Destroy;
end;

procedure TNXProfileDatabase.ExecuteSQL(const ASQL: string);
begin
  FConnection.Execute(ASQL);
end;

function TNXProfileDatabase.NewStatement(const ASQL: string): TNXSQLiteDataSet;
begin
  Result := TNXSQLiteDataSet.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := ASQL;
end;

function TNXProfileDatabase.PrepareStatement(out AParams: TParams;
  const ASQL: string): Psqlite3_stmt;
begin
  AParams := TParams.Create(nil);
  AParams.ParseSQL(ASQL, True);
  Result := FConnection.Prepare(ASQL);
end;

procedure TNXProfileDatabase.ExecuteStatement(AStatement: Psqlite3_stmt;
  AParams: TParams);
begin
  try
    FConnection.BindParams(AStatement, AParams);
    FConnection.CheckResult(sqlite3_step(AStatement), 'execute profiler statement');
  finally
    sqlite3_reset(AStatement);
  end;
end;

function TNXProfileDatabase.LastInsertId: Int64;
begin
  Result := sqlite3_last_insert_rowid(FConnection.Handle);
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
  lQuery: TNXSQLiteDataSet;
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
  lQuery: TNXSQLiteDataSet;
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
  lQuery: TNXSQLiteDataSet;
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
  FInsertModuleParams.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertModuleParams.ParamByName('module_id').AsLargeInt := AInfo.ModuleId;
  FInsertModuleParams.ParamByName('flags').AsLargeInt := AInfo.Flags;
  FInsertModuleParams.ParamByName('build_id').AsString := HexQWord(AInfo.BuildId);
  FInsertModuleParams.ParamByName('load_address').AsString := HexQWord(AInfo.LoadAddress);
  FInsertModuleParams.ParamByName('timestamp').AsLargeInt := Int64(AInfo.Timestamp);
  FInsertModuleParams.ParamByName('image_path').AsString := AInfo.ImagePath;
  ExecuteStatement(FInsertModule, FInsertModuleParams);
end;

procedure TNXProfileDatabase.UnloadModule(ATraceId: Int64;
  AModuleId, AFlags: DWord; ATimestamp: QWord);
begin
  FUnloadModuleParams.ParamByName('trace_id').AsLargeInt := ATraceId;
  FUnloadModuleParams.ParamByName('module_id').AsLargeInt := AModuleId;
  FUnloadModuleParams.ParamByName('flags').AsLargeInt := AFlags;
  FUnloadModuleParams.ParamByName('timestamp').AsLargeInt := Int64(ATimestamp);
  ExecuteStatement(FUnloadModule, FUnloadModuleParams);
end;

procedure TNXProfileDatabase.AddProcedure(ATraceId: Int64;
  const AInfo: TNXProfileProcedureInfo);
begin
  FInsertProcedureParams.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertProcedureParams.ParamByName('procedure_id').AsLargeInt := AInfo.ProcedureId;
  FInsertProcedureParams.ParamByName('module_id').AsLargeInt := AInfo.ModuleId;
  FInsertProcedureParams.ParamByName('flags').AsLargeInt := AInfo.Flags;
  FInsertProcedureParams.ParamByName('stable_id').AsString := HexQWord(AInfo.StableId);
  FInsertProcedureParams.ParamByName('code_start').AsString := HexQWord(AInfo.CodeStart);
  FInsertProcedureParams.ParamByName('code_end').AsString := HexQWord(AInfo.CodeEnd);
  FInsertProcedureParams.ParamByName('source_line').AsLargeInt := AInfo.SourceLine;
  FInsertProcedureParams.ParamByName('source_column').AsLargeInt := AInfo.SourceColumn;
  FInsertProcedureParams.ParamByName('name').AsString := AInfo.Name;
  FInsertProcedureParams.ParamByName('unit_name').AsString := AInfo.UnitName;
  FInsertProcedureParams.ParamByName('source_file').AsString := AInfo.SourceFile;
  ExecuteStatement(FInsertProcedure, FInsertProcedureParams);
end;

procedure TNXProfileDatabase.AddThread(ATraceId: Int64;
  const AInfo: TNXProfileThreadInfo);
begin
  FInsertThreadParams.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertThreadParams.ParamByName('thread_id').AsLargeInt := AInfo.ThreadId;
  FInsertThreadParams.ParamByName('flags').AsLargeInt := AInfo.Flags;
  FInsertThreadParams.ParamByName('timestamp').AsLargeInt := Int64(AInfo.Timestamp);
  FInsertThreadParams.ParamByName('name').AsString := AInfo.Name;
  ExecuteStatement(FInsertThread, FInsertThreadParams);
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
  ExecuteStatement(FInsertCall, FInsertCallParams);
end;

procedure TNXProfileDatabase.AddGap(ATraceId: Int64;
  AThreadId, AFlags: DWord; ASequence, ALostEventCount,
  ATimestamp: QWord);
begin
  FInsertGapParams.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertGapParams.ParamByName('thread_id').AsLargeInt := AThreadId;
  FInsertGapParams.ParamByName('flags').AsLargeInt := AFlags;
  FInsertGapParams.ParamByName('sequence').AsLargeInt := Int64(ASequence);
  FInsertGapParams.ParamByName('lost_count').AsLargeInt := Int64(ALostEventCount);
  FInsertGapParams.ParamByName('timestamp').AsLargeInt := Int64(ATimestamp);
  ExecuteStatement(FInsertGap, FInsertGapParams);
end;

procedure TNXProfileDatabase.AddIssue(ATraceId: Int64;
  AThreadId: DWord; ASequence: QWord; AEventIndex: Int64;
  const AKind, ADetails: string);
begin
  FInsertIssueParams.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertIssueParams.ParamByName('thread_id').AsLargeInt := AThreadId;
  FInsertIssueParams.ParamByName('sequence').AsLargeInt := Int64(ASequence);
  FInsertIssueParams.ParamByName('event_index').AsLargeInt := AEventIndex;
  FInsertIssueParams.ParamByName('kind').AsString := AKind;
  FInsertIssueParams.ParamByName('details').AsString := ADetails;
  ExecuteStatement(FInsertIssue, FInsertIssueParams);
end;

procedure TNXProfileDatabase.AddProcedureTotal(ATraceId: Int64;
  AProcedureId: DWord; ACalls, ANormalReturns, AUnwindReturns,
  AInclusiveTicks, ASelfTicks, AMinTicks, AMaxTicks: QWord);
begin
  FInsertProcedureTotalParams.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertProcedureTotalParams.ParamByName('procedure_id').AsLargeInt := AProcedureId;
  FInsertProcedureTotalParams.ParamByName('calls').AsLargeInt := Int64(ACalls);
  FInsertProcedureTotalParams.ParamByName('normal_returns').AsLargeInt := Int64(ANormalReturns);
  FInsertProcedureTotalParams.ParamByName('unwind_returns').AsLargeInt := Int64(AUnwindReturns);
  FInsertProcedureTotalParams.ParamByName('inclusive_ticks').AsLargeInt := Int64(AInclusiveTicks);
  FInsertProcedureTotalParams.ParamByName('self_ticks').AsLargeInt := Int64(ASelfTicks);
  FInsertProcedureTotalParams.ParamByName('min_ticks').AsLargeInt := Int64(AMinTicks);
  FInsertProcedureTotalParams.ParamByName('max_ticks').AsLargeInt := Int64(AMaxTicks);
  ExecuteStatement(FInsertProcedureTotal, FInsertProcedureTotalParams);
end;

procedure TNXProfileDatabase.AddCallEdge(ATraceId: Int64;
  ACallerId, ACalleeId: DWord; ACalls, AInclusiveTicks: QWord);
begin
  FInsertCallEdgeParams.ParamByName('trace_id').AsLargeInt := ATraceId;
  FInsertCallEdgeParams.ParamByName('caller_id').AsLargeInt := ACallerId;
  FInsertCallEdgeParams.ParamByName('callee_id').AsLargeInt := ACalleeId;
  FInsertCallEdgeParams.ParamByName('calls').AsLargeInt := Int64(ACalls);
  FInsertCallEdgeParams.ParamByName('inclusive_ticks').AsLargeInt := Int64(AInclusiveTicks);
  ExecuteStatement(FInsertCallEdge, FInsertCallEdgeParams);
end;

function TNXProfileDatabase.LoadCheckpoint(ATraceId: Int64;
  out ASourceOffset: Int64; out AProcessedEvents,
  AObservedLostEvents: QWord; out AThreadState: TBytes;
  out AFinished: Boolean): Boolean;
var
  lQuery: TNXSQLiteDataSet;
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
  lQuery: TNXSQLiteDataSet;
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
  lQuery: TNXSQLiteDataSet;
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
  FConnection.Commit;
  FCommitted := True;
end;

procedure TNXProfileDatabase.CommitCheckpoint;
begin
  FConnection.Commit;
  FConnection.StartTransaction;
end;

end.
