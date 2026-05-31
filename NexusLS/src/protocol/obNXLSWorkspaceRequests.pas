unit obNXLSWorkspaceRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWorkspaceWorkspaceFoldersRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDidChangeWorkspaceFoldersRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSWorkspaceWorkspaceFoldersRequest.GetFactoryName: string;
begin
  Result := 'workspace/workspaceFolders';
end;

class function TNXLSWorkspaceWorkspaceFoldersRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceFolderArray;
end;

function TNXLSWorkspaceWorkspaceFoldersRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSWorkspaceDidChangeWorkspaceFoldersRequest.GetFactoryName: string;
begin
  Result := 'workspace/didChangeWorkspaceFolders';
end;

class function TNXLSWorkspaceDidChangeWorkspaceFoldersRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidChangeWorkspaceFoldersParams;
end;

class function TNXLSWorkspaceDidChangeWorkspaceFoldersRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWorkspaceDidChangeWorkspaceFoldersRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Workspace.DidChangeWorkspaceFolders(TNXLSDidChangeWorkspaceFoldersParams(params));
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceWorkspaceFoldersRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidChangeWorkspaceFoldersRequest);

end.
