unit obNXLSCommandRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWorkspaceExecuteCommandRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSWorkspaceExecuteCommandRequest.GetFactoryName: string;
begin
  Result := 'workspace/executeCommand';
end;

class function TNXLSWorkspaceExecuteCommandRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSExecuteCommandParams;
end;

function TNXLSWorkspaceExecuteCommandRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Commands.ExecuteCommand(TNXLSExecuteCommandParams(params));
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceExecuteCommandRequest);

end.
