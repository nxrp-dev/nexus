unit tpNXProfileFormat;

{$mode objfpc}{$H+}

interface

const
  cNXProfileFormatVersion = 2;
  cNXProfileABIVersion = 1;
  cNXProfileByteOrderLE = $04030201;

  cNXProfileRecordFileHeader = 1;
  cNXProfileRecordModuleDefine = 2;
  cNXProfileRecordModuleUnload = 3;
  cNXProfileRecordProcedureDefine = 4;
  cNXProfileRecordThreadDefine = 5;
  cNXProfileRecordCallBlock = 6;
  cNXProfileRecordTraceGap = 7;
  cNXProfileRecordTraceEnd = 8;

  cNXProfileEventEnter = 1;
  cNXProfileEventLeave = 2;
  cNXProfileEventUnwind = 3;

  cNXProfileCallUnwind = $01;
  cNXProfileCallUnmatched = $02;

type
  TNXProfileEvent = packed record
    Kind: Byte;
    Flags: Byte;
    Reserved: Word;
    ProcedureId: DWord;
    Timestamp: QWord;
  end;
  TNXProfileEvents = array of TNXProfileEvent;

  TNXProfileCall = record
    Flags: Byte;
    ProcedureId: DWord;
    CallerProcedureId: DWord;
    InclusiveTicks: QWord;
    SelfTicks: QWord;
  end;
  TNXProfileCalls = array of TNXProfileCall;

  TNXProfileModuleInfo = record
    ModuleId: DWord;
    Flags: DWord;
    BuildId: QWord;
    LoadAddress: QWord;
    Timestamp: QWord;
    ImagePath: AnsiString;
  end;

  TNXProfileProcedureInfo = record
    ProcedureId: DWord;
    ModuleId: DWord;
    Flags: DWord;
    StableId: QWord;
    CodeStart: QWord;
    CodeEnd: QWord;
    SourceLine: DWord;
    SourceColumn: DWord;
    Name: AnsiString;
    UnitName: AnsiString;
    SourceFile: AnsiString;
  end;

  TNXProfileThreadInfo = record
    ThreadId: DWord;
    Flags: DWord;
    Timestamp: QWord;
    Name: AnsiString;
  end;

  TNXProfileCallBlock = record
    ThreadId: DWord;
    Sequence: QWord;
    LostEventCount: QWord;
    FirstTimestamp: QWord;
    LastTimestamp: QWord;
    Calls: TNXProfileCalls;
  end;

  TNXProfileRecord = record
    Kind: Word;
    RecordFlags: Word;
    Flags: DWord;
    ModuleInfo: TNXProfileModuleInfo;
    ProcedureInfo: TNXProfileProcedureInfo;
    ThreadInfo: TNXProfileThreadInfo;
    ModuleId: DWord;
    ThreadId: DWord;
    Sequence: QWord;
    Timestamp: QWord;
    LostEventCount: QWord;
    CallBlock: TNXProfileCallBlock;
  end;

implementation

end.
