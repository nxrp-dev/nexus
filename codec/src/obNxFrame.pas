{$mode objfpc}{$H+}
unit obNxFrame;

interface

uses
  SysUtils, blcksock;

type
  TNxrHeader = packed record
    Magic: array[0..3] of AnsiChar; // 'NXR1' (31 52 58 4E)
    Version: Byte;                  // =1
    MsgType: Byte;                  // 0=req,1=resp,2=notif,3=ping,4=pong
    Flags: Byte;                    // bit0=compressed
    Reserved: Byte;                 // 0
    Length: LongWord;               // LE, body bytes (post-compress if any)
    CorrId: LongWord;               // LE, 0 for notif/ping/pong
  end;

const
  C_MAGIC: array[0..3] of AnsiChar = ('N','X','R','1');

procedure ReadExact(ASock: TTCPBlockSocket; var ABuf; ASize, ATimeoutMs: Integer);
procedure WriteExact(ASock: TTCPBlockSocket; const ABuf; ASize: Integer);
function  ReadHeader(ASock: TTCPBlockSocket; out AHeader: TNxrHeader): Boolean;
procedure WriteFrame(ASock: TTCPBlockSocket; const AHeader: TNxrHeader; const ABody: TBytes);

implementation

uses
  {$IFDEF FPC}StrUtils{$ENDIF};

procedure ReadExact(ASock: TTCPBlockSocket; var ABuf; ASize, ATimeoutMs: Integer);
var lRead, lLeft: Integer;
begin
  lLeft := ASize;
  while lLeft > 0 do
  begin
    lRead := ASock.RecvBufferEx(@PByte(@ABuf)[ASize - lLeft], lLeft, ATimeoutMs);
    if lRead <= 0 then raise Exception.Create('Socket read failed/timeout');
    Dec(lLeft, lRead);
  end;
end;

procedure WriteExact(ASock: TTCPBlockSocket; const ABuf; ASize: Integer);
var lSent, lLeft: Integer;
begin
  lLeft := ASize;
  while lLeft > 0 do
  begin
    lSent := ASock.SendBuffer(@PByte(@ABuf)[ASize - lLeft], lLeft);
    if lSent <= 0 then raise Exception.Create('Socket write failed');
    Dec(lLeft, lSent);
  end;
end;

function ReadHeader(ASock: TTCPBlockSocket; out AHeader: TNxrHeader): Boolean;
begin
  Result := False;
  ReadExact(ASock, AHeader, SizeOf(AHeader), 30000);
  if (not CompareMem(@AHeader.Magic, @C_MAGIC, SizeOf(C_MAGIC))) or (AHeader.Version <> 1) then Exit(False);
  Result := True;
end;

procedure WriteFrame(ASock: TTCPBlockSocket; const AHeader: TNxrHeader; const ABody: TBytes);
begin
  WriteExact(ASock, AHeader, SizeOf(AHeader));
  if (AHeader.Length > 0) and (Length(ABody)<>0) then
    WriteExact(ASock, ABody[0], AHeader.Length);
end;

end.
