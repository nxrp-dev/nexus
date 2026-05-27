unit obNXLSCommandService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSCommandService = class(TNXLSLSPService)
  public
    function ExecuteCommand(AParams: TNXLSExecuteCommandParams): TNXJSONValue; virtual;
  end;

implementation

uses
  obNXLSProtocolObjects;

function TNXLSCommandService.ExecuteCommand(AParams: TNXLSExecuteCommandParams): TNXJSONValue;
begin
  Result := TNXLSCommandResult.CreateValue;
end;

end.
