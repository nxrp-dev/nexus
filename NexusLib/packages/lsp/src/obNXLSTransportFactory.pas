unit obNXLSTransportFactory;

{$mode objfpc}{$H+}

interface

uses
  obNXLSTransport;

type
  TNXLSTransportFactory = class
  public
    class function CreateTransport(const AMode: string): TNXLSTransport;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSStdIOTransport,
  obNXLSTcpIPTransport;

class function TNXLSTransportFactory.CreateTransport(const AMode: string): TNXLSTransport;
begin
  Result := TNXLSTransport(TNXClassFactory.CreateObject(AMode));
end;

end.
