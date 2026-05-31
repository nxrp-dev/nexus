unit obNXLSFileWatchingRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWorkspaceDidChangeWatchedFilesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didChangeWatchedFiles';
end;

class function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidChangeWatchedFilesParams;
end;

class function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWorkspaceDidChangeWatchedFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/didChangeWatchedFiles; required: Optional; original server: No; category: file watching; result: nil.
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidChangeWatchedFilesRequest);

end.
