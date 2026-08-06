program nexusls;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  tpNXLS,
  obNXLSLogger,
  obNXCommandLine,
  obNXLSTransport,
  obNXLSTransportFactory,
  obNXLSServer;

procedure RegisterCommandLineFlags;
begin
  TNXCommandLine.RegisterFlag('mode', False, True, 'std', 'Communication transport mode', 'Use /mode=std for stdio transport or /mode=tcp for TCP/IP transport.');
  TNXCommandLine.RegisterFlag('host', False, True, '127.0.0.1', 'TCP/IP host address', 'Used when /mode=tcp or /mode=tcpip.');
  TNXCommandLine.RegisterFlag('port', False, True, '2087', 'TCP/IP port', 'Used when /mode=tcp or /mode=tcpip.');
end;

function GetCommunicationMode: string;
var
  lMode: string;
begin
  lMode := LowerCase(TNXCommandLine.GetValueDefault('mode', 'std'));

  if (lMode = 'std') or (lMode = 'stdio') then
    Exit(cNXLSModeStdIO);

  if (lMode = 'tcp') or (lMode = 'tcpip') then
    Exit(cNXLSModeTcpIP);

  raise ENXLSException.CreateFmt('Unknown communication mode "%s".', [lMode]);
end;

var
  lMode: string;
  lTransport: TNXLSTransport;
  lServer: TNXLSServer;

begin
  try
    RegisterCommandLineFlags;
    TNXCommandLine.AllowUnknownFlags := False;
    TNXCommandLine.Parse;
    TNXCommandLine.Validate;

    lMode := GetCommunicationMode;
    lTransport := TNXLSTransportFactory.CreateTransport(lMode);
    lServer := TNXLSServer.Create(lTransport);
    try
      lServer.Execute;
    finally
      lServer.Free;
    end;
  except
    on E: Exception do
    begin
      TNXLSLogger.Error(E.Message);
      Halt(1);
    end;
  end;
end.
