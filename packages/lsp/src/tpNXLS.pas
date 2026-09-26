unit tpNXLS;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  obNXJSONRPCMessages;

type
  ENXLSException = class(Exception);

const
  cNXLSModeStdIO = 'stdio';
  cNXLSModeTcpIP = 'tcpip';
  cNXLSRequestFailed = -32803;

procedure NXLSRaiseNotImplemented(const AFeature: string);

implementation

procedure NXLSRaiseNotImplemented(const AFeature: string);
begin
  raise ENXJSONRPC.CreateCode(cNXLSRequestFailed, AFeature + ' is not implemented.');
end;

end.
