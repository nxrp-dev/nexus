unit obNXLSCommandLine;

{$mode objfpc}{$H+}

interface

uses
  tpNXLS;

type
  TNXLSCommandLine = class
  private
    class function NormalizeName(const AName: string): string; static;
    class function GetValue(const AName: string; const ADefault: string): string; static;
  public
    class function Mode: TNXLSCommunicationMode; static;
    class function Host: string; static;
    class function Port: Word; static;
  end;

implementation

uses
  SysUtils;

class function TNXLSCommandLine.NormalizeName(const AName: string): string;
var
  lResult: string;
begin
  lResult := AName;
  while (Length(lResult) > 0) and (lResult[1] in ['/', '-']) do
    Delete(lResult, 1, 1);
  Result := LowerCase(lResult);
end;

class function TNXLSCommandLine.GetValue(const AName: string; const ADefault: string): string;
var
  lIndex: Integer;
  lArgument: string;
  lName: string;
  lValue: string;
  lPosition: SizeInt;
begin
  Result := ADefault;
  for lIndex := 1 to ParamCount do
  begin
    lArgument := ParamStr(lIndex);
    lPosition := Pos('=', lArgument);
    if lPosition <= 0 then
      Continue;

    lName := NormalizeName(Copy(lArgument, 1, lPosition - 1));
    lValue := Copy(lArgument, lPosition + 1, MaxInt);

    if lName = LowerCase(AName) then
      Exit(lValue);
  end;
end;

class function TNXLSCommandLine.Mode: TNXLSCommunicationMode;
var
  lMode: string;
begin
  lMode := LowerCase(GetValue('mode', 'std'));

  if (lMode = 'std') or (lMode = 'stdio') then
    Exit(cmStdIO);

  if (lMode = 'tcp') or (lMode = 'tcpip') then
    Exit(cmTcpIP);

  raise ENXLSException.CreateFmt('Unknown communication mode "%s".', [lMode]);
end;

class function TNXLSCommandLine.Host: string;
begin
  Result := GetValue('host', '127.0.0.1');
end;

class function TNXLSCommandLine.Port: Word;
var
  lValue: Integer;
begin
  lValue := StrToIntDef(GetValue('port', '2087'), 2087);
  if (lValue < 1) or (lValue > 65535) then
    raise ENXLSException.CreateFmt('Invalid TCP/IP port "%d".', [lValue]);
  Result := lValue;
end;

end.
