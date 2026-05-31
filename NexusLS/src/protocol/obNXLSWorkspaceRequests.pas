unit obNXLSWorkspaceRequests;

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
  TNXLSWorkspaceWorkspaceFoldersRequest = class(TNXJSONRPCRequest)
  private
    function GetResult: TNXLSWorkspaceFolderArray;
    procedure SetResult(AValue: TNXLSWorkspaceFolderArray);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSWorkspaceFolderArray read GetResult write SetResult;
  end;

  TNXLSWorkspaceDidChangeWorkspaceFoldersRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidChangeWorkspaceFoldersParams;
    procedure SetParams(AValue: TNXLSDidChangeWorkspaceFoldersParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDidChangeWorkspaceFoldersParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  tpNXLS;

class function TNXLSWorkspaceWorkspaceFoldersRequest.GetFactoryName: string;
begin
  Result := 'workspace/workspaceFolders';
end;

function TNXLSWorkspaceWorkspaceFoldersRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceDidChangeWorkspaceFoldersRequest.GetFactoryName: string;
begin
  Result := 'workspace/didChangeWorkspaceFolders';
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

function TNXLSWorkspaceDidChangeWorkspaceFoldersRequest.GetParams: TNXLSDidChangeWorkspaceFoldersParams;
begin
  Result := TNXLSDidChangeWorkspaceFoldersParams(inherited params);
end;

procedure TNXLSWorkspaceDidChangeWorkspaceFoldersRequest.SetParams(AValue: TNXLSDidChangeWorkspaceFoldersParams);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceWorkspaceFoldersRequest.GetResult: TNXLSWorkspaceFolderArray;
begin
  Result := TNXLSWorkspaceFolderArray(inherited result);
end;

procedure TNXLSWorkspaceWorkspaceFoldersRequest.SetResult(AValue: TNXLSWorkspaceFolderArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceWorkspaceFoldersRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidChangeWorkspaceFoldersRequest);

end.
