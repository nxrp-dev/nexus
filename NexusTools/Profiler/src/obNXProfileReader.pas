unit obNXProfileReader;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  tpNXProfileFormat;

type
  ENXProfileFormatError = class(Exception);

  TNXProfileReader = class
  private
    FStream: TStream;
    FFormatVersion: Word;
    FAbiVersion: Word;
    FProcessId: DWord;
    FSessionId: QWord;
    FClockFrequency: QWord;
    FStartTimestamp: QWord;
    FTruncatedTail: Boolean;
    FDataStartOffset: Int64;
    FLastCompleteOffset: Int64;
    function ReadExact(var ABuffer; ACount: LongInt): Boolean;
    function ReadEnvelope(out AKind, AFlags: Word;
      out APayloadSize: DWord): Boolean;
    function ReadPayload(APayloadSize: DWord; out AData: TBytes): Boolean;
    procedure ReadFileHeader;
    procedure ParseRecord(AKind, AFlags: Word; const AData: TBytes;
      out ARecord: TNXProfileRecord);
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    procedure ResumeAt(AOffset: Int64);
    function ReadNext(out ARecord: TNXProfileRecord): Boolean;
    property FormatVersion: Word read FFormatVersion;
    property AbiVersion: Word read FAbiVersion;
    property ProcessId: DWord read FProcessId;
    property SessionId: QWord read FSessionId;
    property ClockFrequency: QWord read FClockFrequency;
    property StartTimestamp: QWord read FStartTimestamp;
    property TruncatedTail: Boolean read FTruncatedTail;
    property LastCompleteOffset: Int64 read FLastCompleteOffset;
  end;

implementation

const
  cRecordHeaderSize = 8;
  cFileHeaderPayloadSize = 44;
  cCallSize = 25;

type
  TNXProfileRecordHeader = packed record
    Kind: Word;
    Flags: Word;
    Size: DWord;
  end;

  TNXProfileBufferReader = record
    Data: Pointer;
    Size: SizeInt;
    Position: SizeInt;
  end;

procedure RaiseFormatError(const AMessage: string);
begin
  raise ENXProfileFormatError.Create(AMessage);
end;

procedure BufferRequire(const AReader: TNXProfileBufferReader;
  ACount: SizeInt);
begin
  if (ACount < 0) or (AReader.Position > AReader.Size - ACount) then
    RaiseFormatError('NXProfile record payload is truncated');
end;

function BufferReadWord(var AReader: TNXProfileBufferReader): Word;
begin
  Result := 0;
  BufferRequire(AReader, SizeOf(Result));
  Move((PByte(AReader.Data) + AReader.Position)^, Result, SizeOf(Result));
  Inc(AReader.Position, SizeOf(Result));
end;

function BufferReadByte(var AReader: TNXProfileBufferReader): Byte;
begin
  Result := 0;
  BufferRequire(AReader, SizeOf(Result));
  Result := (PByte(AReader.Data) + AReader.Position)^;
  Inc(AReader.Position, SizeOf(Result));
end;

function BufferReadDWord(var AReader: TNXProfileBufferReader): DWord;
begin
  Result := 0;
  BufferRequire(AReader, SizeOf(Result));
  Move((PByte(AReader.Data) + AReader.Position)^, Result, SizeOf(Result));
  Inc(AReader.Position, SizeOf(Result));
end;

function BufferReadQWord(var AReader: TNXProfileBufferReader): QWord;
begin
  Result := 0;
  BufferRequire(AReader, SizeOf(Result));
  Move((PByte(AReader.Data) + AReader.Position)^, Result, SizeOf(Result));
  Inc(AReader.Position, SizeOf(Result));
end;

function BufferReadCString(var AReader: TNXProfileBufferReader): AnsiString;
var
  lStart: SizeInt;
  lCount: SizeInt;
begin
  Result := '';
  lStart := AReader.Position;
  while (AReader.Position < AReader.Size) and
    ((PByte(AReader.Data) + AReader.Position)^ <> 0) do
    Inc(AReader.Position);
  if AReader.Position >= AReader.Size then
    RaiseFormatError('NXProfile string has no terminator inside its record');
  lCount := AReader.Position - lStart;
  SetLength(Result, lCount);
  if lCount > 0 then
    Move((PByte(AReader.Data) + lStart)^, Result[1], lCount);
  Inc(AReader.Position);
end;

procedure BufferFinished(const AReader: TNXProfileBufferReader);
begin
  if AReader.Position <> AReader.Size then
    RaiseFormatError('NXProfile record contains unexpected trailing data');
end;

constructor TNXProfileReader.Create(const AFileName: string);
begin
  inherited Create;
  FStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  ReadFileHeader;
end;

destructor TNXProfileReader.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TNXProfileReader.ReadExact(var ABuffer; ACount: LongInt): Boolean;
var
  lDone: LongInt;
  lReadCount: LongInt;
begin
  lDone := 0;
  while lDone < ACount do
  begin
    lReadCount := FStream.Read((PByte(@ABuffer) + lDone)^, ACount - lDone);
    if lReadCount <= 0 then
      Exit(False);
    Inc(lDone, lReadCount);
  end;
  Result := True;
end;

function TNXProfileReader.ReadEnvelope(out AKind, AFlags: Word;
  out APayloadSize: DWord): Boolean;
var
  lHeader: TNXProfileRecordHeader;
begin
  lHeader := Default(TNXProfileRecordHeader);
  if FStream.Position >= FStream.Size then
    Exit(False);
  if not ReadExact(lHeader, SizeOf(lHeader)) then
  begin
    FTruncatedTail := True;
    Exit(False);
  end;
  if lHeader.Size < cRecordHeaderSize then
    RaiseFormatError('NXProfile record size is smaller than its header');
  AKind := lHeader.Kind;
  AFlags := lHeader.Flags;
  APayloadSize := lHeader.Size - cRecordHeaderSize;
  if QWord(APayloadSize) > QWord(FStream.Size - FStream.Position) then
  begin
    FTruncatedTail := True;
    FStream.Position := FStream.Size;
    Exit(False);
  end;
  Result := True;
end;

function TNXProfileReader.ReadPayload(APayloadSize: DWord;
  out AData: TBytes): Boolean;
begin
  AData := nil;
  SetLength(AData, APayloadSize);
  if APayloadSize = 0 then
    Exit(True);
  Result := ReadExact(AData[0], APayloadSize);
end;

procedure TNXProfileReader.ReadFileHeader;
var
  lKind: Word;
  lFlags: Word;
  lPayloadSize: DWord;
  lData: TBytes;
  lReader: TNXProfileBufferReader;
  lMagic: array[0..3] of AnsiChar;
  lByteOrder: DWord;
  lReserved: DWord;
begin
  lMagic[0] := #0;
  lMagic[1] := #0;
  lMagic[2] := #0;
  lMagic[3] := #0;
  if not ReadEnvelope(lKind, lFlags, lPayloadSize) then
    RaiseFormatError('NXProfile file header is missing or truncated');
  if (lKind <> cNXProfileRecordFileHeader) or
     (lPayloadSize <> cFileHeaderPayloadSize) then
    RaiseFormatError('NXProfile file header is invalid');
  if not ReadPayload(lPayloadSize, lData) then
    RaiseFormatError('NXProfile file header is truncated');
  lReader.Data := @lData[0];
  lReader.Size := Length(lData);
  lReader.Position := 0;
  BufferRequire(lReader, SizeOf(lMagic));
  Move(PByte(lReader.Data)^, lMagic, SizeOf(lMagic));
  Inc(lReader.Position, SizeOf(lMagic));
  if (lMagic[0] <> 'N') or (lMagic[1] <> 'X') or
     (lMagic[2] <> 'P') or (lMagic[3] <> 'F') then
    RaiseFormatError('NXProfile file magic is invalid');
  FFormatVersion := BufferReadWord(lReader);
  FAbiVersion := BufferReadWord(lReader);
  lByteOrder := BufferReadDWord(lReader);
  FProcessId := BufferReadDWord(lReader);
  lReserved := BufferReadDWord(lReader);
  FSessionId := BufferReadQWord(lReader);
  FClockFrequency := BufferReadQWord(lReader);
  FStartTimestamp := BufferReadQWord(lReader);
  BufferFinished(lReader);
  if lByteOrder <> cNXProfileByteOrderLE then
    RaiseFormatError('NXProfile byte order is unsupported');
  if FFormatVersion <> cNXProfileFormatVersion then
    RaiseFormatError(Format('Unsupported NXProfile format version %d',
      [FFormatVersion]));
  if FAbiVersion <> cNXProfileABIVersion then
    RaiseFormatError(Format('Unsupported NXProfile ABI version %d',
      [FAbiVersion]));
  if (lFlags <> 0) or (lReserved <> 0) then
    RaiseFormatError('NXProfile file header contains unsupported flags');
  FDataStartOffset := FStream.Position;
  FLastCompleteOffset := FStream.Position;
end;

procedure TNXProfileReader.ResumeAt(AOffset: Int64);
begin
  if (AOffset < FDataStartOffset) or (AOffset > FStream.Size) then
    RaiseFormatError('NXProfile resume offset is outside the trace');
  FStream.Position := AOffset;
  FLastCompleteOffset := AOffset;
  FTruncatedTail := False;
end;

procedure TNXProfileReader.ParseRecord(AKind, AFlags: Word;
  const AData: TBytes; out ARecord: TNXProfileRecord);
var
  lReader: TNXProfileBufferReader;
  lCount: DWord;
  lIndex: DWord;
  lReserved: DWord;
begin
  ARecord := Default(TNXProfileRecord);
  ARecord.Kind := AKind;
  ARecord.RecordFlags := AFlags;
  if Length(AData) = 0 then
    lReader.Data := nil
  else
    lReader.Data := @AData[0];
  lReader.Size := Length(AData);
  lReader.Position := 0;
  case AKind of
    cNXProfileRecordModuleDefine:
      begin
        ARecord.ModuleInfo.ModuleId := BufferReadDWord(lReader);
        ARecord.ModuleInfo.Flags := BufferReadDWord(lReader);
        ARecord.ModuleInfo.BuildId := BufferReadQWord(lReader);
        ARecord.ModuleInfo.LoadAddress := BufferReadQWord(lReader);
        ARecord.ModuleInfo.Timestamp := BufferReadQWord(lReader);
        ARecord.ModuleInfo.ImagePath := BufferReadCString(lReader);
      end;
    cNXProfileRecordModuleUnload:
      begin
        ARecord.ModuleId := BufferReadDWord(lReader);
        ARecord.Flags := BufferReadDWord(lReader);
        ARecord.Timestamp := BufferReadQWord(lReader);
      end;
    cNXProfileRecordProcedureDefine:
      begin
        ARecord.ProcedureInfo.ProcedureId := BufferReadDWord(lReader);
        ARecord.ProcedureInfo.ModuleId := BufferReadDWord(lReader);
        ARecord.ProcedureInfo.Flags := BufferReadDWord(lReader);
        lReserved := BufferReadDWord(lReader);
        if lReserved <> 0 then
          RaiseFormatError('NXProfile procedure record has unsupported data');
        ARecord.ProcedureInfo.StableId := BufferReadQWord(lReader);
        ARecord.ProcedureInfo.CodeStart := BufferReadQWord(lReader);
        ARecord.ProcedureInfo.CodeEnd := BufferReadQWord(lReader);
        ARecord.ProcedureInfo.SourceLine := BufferReadDWord(lReader);
        ARecord.ProcedureInfo.SourceColumn := BufferReadDWord(lReader);
        ARecord.ProcedureInfo.Name := BufferReadCString(lReader);
        ARecord.ProcedureInfo.UnitName := BufferReadCString(lReader);
        ARecord.ProcedureInfo.SourceFile := BufferReadCString(lReader);
      end;
    cNXProfileRecordThreadDefine:
      begin
        ARecord.ThreadInfo.ThreadId := BufferReadDWord(lReader);
        ARecord.ThreadInfo.Flags := BufferReadDWord(lReader);
        ARecord.ThreadInfo.Timestamp := BufferReadQWord(lReader);
        ARecord.ThreadInfo.Name := BufferReadCString(lReader);
      end;
    cNXProfileRecordCallBlock:
      begin
        ARecord.CallBlock.ThreadId := BufferReadDWord(lReader);
        lCount := BufferReadDWord(lReader);
        ARecord.CallBlock.Sequence := BufferReadQWord(lReader);
        ARecord.CallBlock.LostEventCount := BufferReadQWord(lReader);
        ARecord.CallBlock.FirstTimestamp := BufferReadQWord(lReader);
        ARecord.CallBlock.LastTimestamp := BufferReadQWord(lReader);
        if QWord(lCount) * cCallSize >
           QWord(lReader.Size - lReader.Position) then
          RaiseFormatError('NXProfile call count exceeds its record');
        SetLength(ARecord.CallBlock.Calls, lCount);
        if lCount > 0 then
          for lIndex := 0 to lCount - 1 do
          begin
            ARecord.CallBlock.Calls[lIndex].Flags := BufferReadByte(lReader);
            ARecord.CallBlock.Calls[lIndex].ProcedureId :=
              BufferReadDWord(lReader);
            ARecord.CallBlock.Calls[lIndex].CallerProcedureId :=
              BufferReadDWord(lReader);
            ARecord.CallBlock.Calls[lIndex].InclusiveTicks :=
              BufferReadQWord(lReader);
            ARecord.CallBlock.Calls[lIndex].SelfTicks :=
              BufferReadQWord(lReader);
          end;
      end;
    cNXProfileRecordTraceGap:
      begin
        ARecord.ThreadId := BufferReadDWord(lReader);
        ARecord.Flags := BufferReadDWord(lReader);
        ARecord.Sequence := BufferReadQWord(lReader);
        ARecord.LostEventCount := BufferReadQWord(lReader);
        ARecord.Timestamp := BufferReadQWord(lReader);
      end;
    cNXProfileRecordTraceEnd:
      begin
        ARecord.Timestamp := BufferReadQWord(lReader);
        ARecord.LostEventCount := BufferReadQWord(lReader);
      end;
  else
    RaiseFormatError('Internal NXProfile record dispatch error');
  end;
  BufferFinished(lReader);
end;

function TNXProfileReader.ReadNext(out ARecord: TNXProfileRecord): Boolean;
var
  lKind: Word;
  lFlags: Word;
  lPayloadSize: DWord;
  lData: TBytes;
begin
  ARecord := Default(TNXProfileRecord);
  while ReadEnvelope(lKind, lFlags, lPayloadSize) do
  begin
    if not ReadPayload(lPayloadSize, lData) then
    begin
      FTruncatedTail := True;
      Exit(False);
    end;
    if lKind in [cNXProfileRecordModuleDefine,
      cNXProfileRecordModuleUnload, cNXProfileRecordProcedureDefine,
      cNXProfileRecordThreadDefine, cNXProfileRecordCallBlock,
      cNXProfileRecordTraceGap, cNXProfileRecordTraceEnd] then
    begin
      ParseRecord(lKind, lFlags, lData, ARecord);
      FLastCompleteOffset := FStream.Position;
      Exit(True);
    end;
    FLastCompleteOffset := FStream.Position;
  end;
  Result := False;
end;

end.
