program NexusProfilerImportTests;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  SQLDB,
  SQLite3Conn,
  tpNXProfileFormat,
  obNXProfileReader,
  obNXProfileImporter;

const
  cCheckpointPadding = Int64(64) * 1024 * 1024;

type
  TRecordHeader = packed record
    Kind: Word;
    Flags: Word;
    Size: DWord;
  end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure WriteByte(AStream: TStream; AValue: Byte);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure WriteWord(AStream: TStream; AValue: Word);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure WriteDWord(AStream: TStream; AValue: DWord);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure WriteQWord(AStream: TStream; AValue: QWord);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure WriteCString(AStream: TStream; const AValue: AnsiString);
begin
  if AValue <> '' then
    AStream.WriteBuffer(AValue[1], Length(AValue));
  WriteByte(AStream, 0);
end;

procedure WriteHeader(AStream: TStream; AKind: Word; APayloadSize: DWord);
var
  lHeader: TRecordHeader;
begin
  lHeader.Kind := AKind;
  lHeader.Flags := 0;
  lHeader.Size := APayloadSize + SizeOf(lHeader);
  AStream.WriteBuffer(lHeader, SizeOf(lHeader));
end;

procedure WriteFileHeader(AStream: TStream);
const
  cMagic: array[0..3] of AnsiChar = ('N', 'X', 'P', 'F');
begin
  WriteHeader(AStream, cNXProfileRecordFileHeader, 44);
  AStream.WriteBuffer(cMagic, SizeOf(cMagic));
  WriteWord(AStream, cNXProfileFormatVersion);
  WriteWord(AStream, cNXProfileABIVersion);
  WriteDWord(AStream, cNXProfileByteOrderLE);
  WriteDWord(AStream, 1234);
  WriteDWord(AStream, 0);
  WriteQWord(AStream, $1122334455667788);
  WriteQWord(AStream, 1000);
  WriteQWord(AStream, 90);
end;

procedure WriteModule(AStream: TStream);
const
  cImage = 'synthetic.exe';
begin
  WriteHeader(AStream, cNXProfileRecordModuleDefine, 32 + Length(cImage) + 1);
  WriteDWord(AStream, 1);
  WriteDWord(AStream, 0);
  WriteQWord(AStream, (QWord($AABBCCDD) shl 32) or $EEFF0011);
  WriteQWord(AStream, $0000000140000000);
  WriteQWord(AStream, 90);
  WriteCString(AStream, cImage);
end;

procedure WriteProcedure(AStream: TStream; AId: DWord; AStableId: QWord;
  ACodeStart: QWord; const AName: AnsiString);
const
  cUnitName = 'SyntheticUnit';
  cSourceFile = 'synthetic.pas';
var
  lPayloadSize: DWord;
begin
  lPayloadSize := 48 + Length(AName) + 1 + Length(cUnitName) + 1 +
    Length(cSourceFile) + 1;
  WriteHeader(AStream, cNXProfileRecordProcedureDefine, lPayloadSize);
  WriteDWord(AStream, AId);
  WriteDWord(AStream, 1);
  WriteDWord(AStream, 0);
  WriteDWord(AStream, 0);
  WriteQWord(AStream, AStableId);
  WriteQWord(AStream, ACodeStart);
  WriteQWord(AStream, ACodeStart + $20);
  WriteDWord(AStream, 10 + AId);
  WriteDWord(AStream, 1);
  WriteCString(AStream, AName);
  WriteCString(AStream, cUnitName);
  WriteCString(AStream, cSourceFile);
end;

procedure WriteThread(AStream: TStream);
const
  cName = 'main';
begin
  WriteHeader(AStream, cNXProfileRecordThreadDefine, 16 + Length(cName) + 1);
  WriteDWord(AStream, 7);
  WriteDWord(AStream, 0);
  WriteQWord(AStream, 90);
  WriteCString(AStream, cName);
end;

procedure SetCall(out ACall: TNXProfileCall; AFlags: Byte;
  AProcedureId, ACallerProcedureId: DWord;
  AInclusiveTicks, ASelfTicks: QWord);
begin
  ACall := Default(TNXProfileCall);
  ACall.Flags := AFlags;
  ACall.ProcedureId := AProcedureId;
  ACall.CallerProcedureId := ACallerProcedureId;
  ACall.InclusiveTicks := AInclusiveTicks;
  ACall.SelfTicks := ASelfTicks;
end;

procedure WriteCalls(AStream: TStream);
var
  lCalls: array[0..2] of TNXProfileCall;
  lIndex: Integer;
begin
  SetCall(lCalls[0], 0, 2, 1, 40, 40);
  SetCall(lCalls[1], cNXProfileCallUnwind, 3, 1, 20, 20);
  SetCall(lCalls[2], 0, 1, 0, 100, 40);
  WriteHeader(AStream, cNXProfileRecordCallBlock,
    40 + Length(lCalls) * 25);
  WriteDWord(AStream, 7);
  WriteDWord(AStream, Length(lCalls));
  WriteQWord(AStream, 0);
  WriteQWord(AStream, 0);
  WriteQWord(AStream, 100);
  WriteQWord(AStream, 200);
  for lIndex := 0 to High(lCalls) do
  begin
    WriteByte(AStream, lCalls[lIndex].Flags);
    WriteDWord(AStream, lCalls[lIndex].ProcedureId);
    WriteDWord(AStream, lCalls[lIndex].CallerProcedureId);
    WriteQWord(AStream, lCalls[lIndex].InclusiveTicks);
    WriteQWord(AStream, lCalls[lIndex].SelfTicks);
  end;
end;

procedure WriteCallBlock(AStream: TStream; ASequence: QWord;
  const ACalls: array of TNXProfileCall);
var
  lIndex: Integer;
begin
  WriteHeader(AStream, cNXProfileRecordCallBlock,
    40 + Length(ACalls) * 25);
  WriteDWord(AStream, 7);
  WriteDWord(AStream, Length(ACalls));
  WriteQWord(AStream, ASequence);
  WriteQWord(AStream, 0);
  WriteQWord(AStream, 100 + ASequence * 100);
  WriteQWord(AStream, 199 + ASequence * 100);
  for lIndex := 0 to High(ACalls) do
  begin
    WriteByte(AStream, ACalls[lIndex].Flags);
    WriteDWord(AStream, ACalls[lIndex].ProcedureId);
    WriteDWord(AStream, ACalls[lIndex].CallerProcedureId);
    WriteQWord(AStream, ACalls[lIndex].InclusiveTicks);
    WriteQWord(AStream, ACalls[lIndex].SelfTicks);
  end;
end;

procedure WriteCheckpointPadding(AStream: TStream);
begin
  WriteHeader(AStream, 999, cCheckpointPadding);
  AStream.Position := AStream.Position + cCheckpointPadding - 1;
  WriteByte(AStream, 0);
end;

procedure WriteResumeFirstBlock(AStream: TStream);
var
  lCalls: array of TNXProfileCall;
begin
  lCalls := nil;
  SetLength(lCalls, 1);
  SetCall(lCalls[0], 0, 2, 1, 10, 10);
  WriteCallBlock(AStream, 0, lCalls);
end;

procedure WriteResumeSecondBlock(AStream: TStream);
var
  lCalls: array[0..1] of TNXProfileCall;
begin
  SetCall(lCalls[0], 0, 2, 1, 20, 20);
  SetCall(lCalls[1], 0, 1, 0, 100, 70);
  WriteCallBlock(AStream, 1, lCalls);
end;

procedure WriteInvalidCallBlock(AStream: TStream);
begin
  WriteHeader(AStream, cNXProfileRecordCallBlock, 1);
  WriteByte(AStream, 0);
end;

procedure WriteTraceEnd(AStream: TStream);
begin
  WriteHeader(AStream, cNXProfileRecordTraceEnd, 16);
  WriteQWord(AStream, 210);
  WriteQWord(AStream, 0);
end;

procedure CreateSyntheticTrace(const AFileName: string);
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteFileHeader(lStream);
    WriteModule(lStream);
    WriteProcedure(lStream, 1, $1001, $140001000, 'Main');
    WriteProcedure(lStream, 2, $1002, $140002000, 'Hot');
    WriteProcedure(lStream, 3, $1003, $140003000, 'Raises');
    WriteThread(lStream);
    WriteCalls(lStream);
    WriteTraceEnd(lStream);
  finally
    lStream.Free;
  end;
end;

procedure CreateInterruptedTrace(const AFileName: string);
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteFileHeader(lStream);
    WriteModule(lStream);
    WriteProcedure(lStream, 1, $2001, $140003000, 'Outer');
    WriteProcedure(lStream, 2, $2002, $140004000, 'Inner');
    WriteThread(lStream);
    WriteCheckpointPadding(lStream);
    WriteResumeFirstBlock(lStream);
    WriteInvalidCallBlock(lStream);
  finally
    lStream.Free;
  end;
end;

function Scalar(AConnection: TSQLite3Connection;
  ATransaction: TSQLTransaction; const ASQL: string): Int64;
var
  lQuery: TSQLQuery;
begin
  lQuery := TSQLQuery.Create(nil);
  try
    lQuery.DataBase := AConnection;
    lQuery.Transaction := ATransaction;
    lQuery.SQL.Text := ASQL;
    lQuery.Open;
    Result := lQuery.Fields[0].AsLargeInt;
  finally
    lQuery.Free;
  end;
end;

function DatabaseScalar(const AFileName, ASQL: string): Int64;
var
  lConnection: TSQLite3Connection;
  lTransaction: TSQLTransaction;
begin
  lConnection := TSQLite3Connection.Create(nil);
  lTransaction := TSQLTransaction.Create(nil);
  try
    lConnection.DatabaseName := AFileName;
    lConnection.Transaction := lTransaction;
    lTransaction.DataBase := lConnection;
    lConnection.Open;
    lTransaction.StartTransaction;
    Result := Scalar(lConnection, lTransaction, ASQL);
    lTransaction.Commit;
  finally
    lTransaction.Free;
    lConnection.Free;
  end;
end;

procedure RepairInterruptedTrace(const AFileName: string;
  ACheckpointOffset: Int64);
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFileName, fmOpenWrite);
  try
    lStream.Size := ACheckpointOffset;
    lStream.Position := ACheckpointOffset;
    WriteResumeSecondBlock(lStream);
    WriteTraceEnd(lStream);
  finally
    lStream.Free;
  end;
end;

procedure VerifyDatabase(const AFileName: string);
var
  lConnection: TSQLite3Connection;
  lTransaction: TSQLTransaction;
begin
  lConnection := TSQLite3Connection.Create(nil);
  lTransaction := TSQLTransaction.Create(nil);
  try
    lConnection.DatabaseName := AFileName;
    lConnection.Transaction := lTransaction;
    lTransaction.DataBase := lConnection;
    lConnection.Open;
    lTransaction.StartTransaction;
    Check(Scalar(lConnection, lTransaction,
      'select count(*) from nxp_call') = 3, 'completed call count is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select count(*) from nxp_import_issue') = 0, 'unexpected import issue');
    Check(Scalar(lConnection, lTransaction,
      'select inclusive_ticks from nxp_procedure_total where source_procedure_id = 1') = 100,
      'Main inclusive time is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select self_ticks from nxp_procedure_total where source_procedure_id = 1') = 40,
      'Main self time is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select inclusive_ticks from nxp_procedure_total where source_procedure_id = 2') = 40,
      'Hot inclusive time is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select unwind_returns from nxp_procedure_total where source_procedure_id = 3') = 1,
      'unwind count is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select count(*) from nxp_call_edge') = 2, 'call edge count is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select count(*) from v_nxp_hotspots') = 3, 'hotspot view is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select complete from nxp_trace') = 1, 'trace should be complete');
    lTransaction.Commit;
  finally
    lTransaction.Free;
    lConnection.Free;
  end;
end;

procedure VerifyResumedDatabase(const AFileName: string);
var
  lConnection: TSQLite3Connection;
  lTransaction: TSQLTransaction;
begin
  lConnection := TSQLite3Connection.Create(nil);
  lTransaction := TSQLTransaction.Create(nil);
  try
    lConnection.DatabaseName := AFileName;
    lConnection.Transaction := lTransaction;
    lTransaction.DataBase := lConnection;
    lConnection.Open;
    lTransaction.StartTransaction;
    Check(Scalar(lConnection, lTransaction,
      'select count(*) from nxp_run') = 1, 'resume created another run');
    Check(Scalar(lConnection, lTransaction,
      'select count(*) from nxp_trace') = 1, 'resume created another trace');
    Check(Scalar(lConnection, lTransaction,
      'select count(*) from nxp_call') = 3, 'resume duplicated or lost calls');
    Check(Scalar(lConnection, lTransaction,
      'select calls from nxp_procedure_total where source_procedure_id = 2') = 2,
      'checkpointed procedure totals were not merged');
    Check(Scalar(lConnection, lTransaction,
      'select inclusive_ticks from nxp_procedure_total where source_procedure_id = 2') = 30,
      'checkpointed procedure duration is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select self_ticks from nxp_procedure_total where source_procedure_id = 1') = 70,
      'restored parent child time is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select calls from nxp_call_edge where caller_procedure_id = 1 and ' +
      'callee_procedure_id = 2') = 2, 'checkpointed call edge was not merged');
    Check(Scalar(lConnection, lTransaction,
      'select processed_events from nxp_import_checkpoint') = 3,
      'checkpoint call count is wrong');
    Check(Scalar(lConnection, lTransaction,
      'select finished from nxp_import_checkpoint') = 1,
      'final checkpoint is not marked finished');
    Check(Scalar(lConnection, lTransaction,
      'select count(*) from nxp_import_issue') = 0,
      'resume produced an import issue');
    lTransaction.Commit;
  finally
    lTransaction.Free;
    lConnection.Free;
  end;
end;

procedure TestResumableImport(const ATraceFile, ADatabaseFile: string);
var
  lCheckpointOffset: Int64;
  lFailed: Boolean;
begin
  DeleteFile(ATraceFile);
  DeleteFile(ADatabaseFile);
  CreateInterruptedTrace(ATraceFile);
  lFailed := False;
  try
    TNXProfileImporter.ImportPath(ADatabaseFile, ATraceFile, 'resume test');
  except
    on ENXProfileFormatError do
      lFailed := True;
  end;
  Check(lFailed, 'the interrupted import did not fail at the invalid record');
  Check(DatabaseScalar(ADatabaseFile,
    'select finished from nxp_import_checkpoint') = 0,
    'interrupted import did not retain an unfinished checkpoint');
  Check(DatabaseScalar(ADatabaseFile,
    'select count(*) from nxp_call') = 1,
    'checkpoint did not commit the first call block');
  lCheckpointOffset := DatabaseScalar(ADatabaseFile,
    'select source_offset from nxp_import_checkpoint');
  RepairInterruptedTrace(ATraceFile, lCheckpointOffset);
  Check(TNXProfileImporter.ImportPath(ADatabaseFile, ATraceFile,
    'resume test') = 1, 'resumed import file count is wrong');
  VerifyResumedDatabase(ADatabaseFile);
  Check(TNXProfileImporter.ImportPath(ADatabaseFile, ATraceFile,
    'resume test') = 1, 'finished import file count is wrong');
  VerifyResumedDatabase(ADatabaseFile);
end;

var
  lTraceFile: string;
  lDatabaseFile: string;
  lResumeTraceFile: string;
  lResumeDatabaseFile: string;
begin
  lTraceFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nexus-profiler-import-synthetic.nxp';
  lDatabaseFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nexus-profiler-import-synthetic.sqlite';
  lResumeTraceFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nexus-profiler-import-resume.nxp';
  lResumeDatabaseFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nexus-profiler-import-resume.sqlite';
  DeleteFile(lTraceFile);
  DeleteFile(lDatabaseFile);
  DeleteFile(lResumeTraceFile);
  DeleteFile(lResumeDatabaseFile);
  try
    CreateSyntheticTrace(lTraceFile);
    Check(TNXProfileImporter.ImportPath(lDatabaseFile, lTraceFile,
      'synthetic test') = 1, 'imported file count is wrong');
    VerifyDatabase(lDatabaseFile);
    TestResumableImport(lResumeTraceFile, lResumeDatabaseFile);
    WriteLn('Nexus profiler importer tests passed');
  finally
    DeleteFile(lTraceFile);
    DeleteFile(lDatabaseFile);
    DeleteFile(lResumeTraceFile);
    DeleteFile(lResumeDatabaseFile);
  end;
end.
