unit obNXLSConfigurationRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSWorkspaceConfigurationRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSConfigurationParams;
    procedure SetParams(AValue: TNXLSConfigurationParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSConfigurationParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceDidChangeConfigurationRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidChangeConfigurationParams;
    procedure SetParams(AValue: TNXLSDidChangeConfigurationParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDidChangeConfigurationParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  tpNXLS;

class function TNXLSWorkspaceConfigurationRequest.GetFactoryName: string;
begin
  Result := 'workspace/configuration';
end;

class function TNXLSWorkspaceConfigurationRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSConfigurationArray;
end;

function TNXLSWorkspaceConfigurationRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceDidChangeConfigurationRequest.GetFactoryName: string;
begin
  Result := 'workspace/didChangeConfiguration';
end;

class function TNXLSWorkspaceDidChangeConfigurationRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWorkspaceDidChangeConfigurationRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Workspace.DidChangeConfiguration(TNXLSDidChangeConfigurationParams(params));
  Result := nil;
end;

function TNXLSWorkspaceDidChangeConfigurationRequest.GetParams: TNXLSDidChangeConfigurationParams;
begin
  Result := TNXLSDidChangeConfigurationParams(inherited params);
end;

procedure TNXLSWorkspaceDidChangeConfigurationRequest.SetParams(AValue: TNXLSDidChangeConfigurationParams);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceConfigurationRequest.GetParams: TNXLSConfigurationParams;
begin
  Result := TNXLSConfigurationParams(inherited params);
end;

procedure TNXLSWorkspaceConfigurationRequest.SetParams(AValue: TNXLSConfigurationParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceConfigurationRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidChangeConfigurationRequest);

end.
