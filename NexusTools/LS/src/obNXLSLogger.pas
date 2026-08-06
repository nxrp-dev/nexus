unit obNXLSLogger;

{$mode objfpc}{$H+}

interface

type
  TNXLSLogger = class
  public
    class procedure Info(const AMessage: string); static;
    class procedure Error(const AMessage: string); static;
  end;

implementation

uses
  SysUtils;

class procedure TNXLSLogger.Info(const AMessage: string);
begin
  WriteLn(StdErr, '[info] ', AMessage);
end;

class procedure TNXLSLogger.Error(const AMessage: string);
begin
  WriteLn(StdErr, '[error] ', AMessage);
end;

end.
