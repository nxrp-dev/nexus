unit obNXLSConfigurationRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWorkspaceConfigurationRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDidChangeConfigurationRequest = class(TNXJSONRPCRequest)
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

class function TNXLSWorkspaceConfigurationRequest.GetFactoryName: string;
begin
  Result := 'workspace/configuration';
end;

class function TNXLSWorkspaceConfigurationRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSConfigurationParams;
end;

function TNXLSWorkspaceConfigurationRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/configuration; required: Client-side; original server: No; category: configuration; result: TNXLSConfigurationArrayResult.
  Result := TNXLSConfigurationArrayResult.CreateValue;
end;

class function TNXLSWorkspaceDidChangeConfigurationRequest.GetFactoryName: string;
begin
  Result := 'workspace/didChangeConfiguration';
end;

class function TNXLSWorkspaceDidChangeConfigurationRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidChangeConfigurationParams;
end;

function TNXLSWorkspaceDidChangeConfigurationRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Workspace.DidChangeConfiguration(TNXLSDidChangeConfigurationParams(params));
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceConfigurationRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidChangeConfigurationRequest);

end.
