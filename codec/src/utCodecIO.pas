unit utCodecIO;

{$IFDEF FPC}{$MODE ObjFPC}{$H+}{$ENDIF}

interface

uses
  Classes, SysUtils;

procedure WriteInt32(const AStream: TStream; const AValue: LongInt);
function  ReadInt32(const AStream: TStream): LongInt;

procedure WriteInt64(const AStream: TStream; const AValue: Int64);
function  ReadInt64(const AStream: TStream): Int64;

procedure WriteInt(const AStream: TStream; const AValue: Int64);
function  ReadInt(const AStream: TStream): Int64;

procedure WriteCount(const AStream: TStream; const AValue: Int64);
function  ReadCount(const AStream: TStream): Int64;

implementation

{$I tpPlatform.inc}

procedure WriteLE(const AStream: TStream; const AData; const ASize: Integer);
var
  lBuf: array[0..7] of Byte;
  lI: Integer;
begin
  Move(AData, lBuf[0], ASize);
  {$IFDEF ENDIAN_BIG}
  for lI := 0 to (ASize div 2) - 1 do
  begin
    lBuf[lI] := lBuf[lI] xor lBuf[ASize-1-lI];
    lBuf[ASize-1-lI] := lBuf[lI] xor lBuf[ASize-1-lI];
    lBuf[lI] := lBuf[lI] xor lBuf[ASize-1-lI];
  end;
  {$ENDIF}
  AStream.WriteBuffer(lBuf[0], ASize);
end;

procedure ReadLE(const AStream: TStream; var AData; const ASize: Integer);
var
  lBuf: array[0..7] of Byte;
  lI: Integer;
begin
  AStream.ReadBuffer(lBuf[0], ASize);
  {$IFDEF ENDIAN_BIG}
  for lI := 0 to (ASize div 2) - 1 do
  begin
    lBuf[lI] := lBuf[lI] xor lBuf[ASize-1-lI];
    lBuf[ASize-1-lI] := lBuf[lI] xor lBuf[ASize-1-lI];
    lBuf[lI] := lBuf[lI] xor lBuf[ASize-1-lI];
  end;
  {$ENDIF}
  Move(lBuf[0], AData, ASize);
end;

procedure WriteInt32(const AStream: TStream; const AValue: LongInt);
begin
  WriteLE(AStream, AValue, 4);
end;

function ReadInt32(const AStream: TStream): LongInt;
var lV: LongInt;
begin
  ReadLE(AStream, lV, 4);
  Result := lV;
end;

procedure WriteInt64(const AStream: TStream; const AValue: Int64);
begin
  WriteLE(AStream, AValue, 8);
end;

function ReadInt64(const AStream: TStream): Int64;
var lV: Int64;
begin
  ReadLE(AStream, lV, 8);
  Result := lV;
end;

procedure WriteInt(const AStream: TStream; const AValue: Int64);
begin
  {$IFDEF NX_INT_BYTES = 4}
  if (AValue < Low(LongInt)) or (AValue > High(LongInt)) then
    raise Exception.Create('Value out of range for 32-bit Int');
  WriteInt32(AStream, LongInt(AValue));
  {$ELSE}
  WriteInt64(AStream, AValue);
  {$IFEND}
end;

function ReadInt(const AStream: TStream): Int64;
begin
  {$IFDEF NX_INT_BYTES = 4}
  Result := ReadInt32(AStream);
  {$ELSE}
  Result := ReadInt64(AStream);
  {$IFEND}
end;

procedure WriteCount(const AStream: TStream; const AValue: Int64);
begin
  WriteInt(AStream, AValue);
end;

function ReadCount(const AStream: TStream): Int64;
begin
  Result := ReadInt(AStream);
end;

end.
