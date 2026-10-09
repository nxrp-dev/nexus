(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

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
