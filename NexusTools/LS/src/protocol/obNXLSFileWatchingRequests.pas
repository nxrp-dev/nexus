unit obNXLSFileWatchingRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSWorkspaceDidChangeWatchedFilesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidChangeWatchedFilesParams;
    procedure SetParams(AValue: TNXLSDidChangeWatchedFilesParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidChangeWatchedFilesParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didChangeWatchedFiles';
end;

class function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWorkspaceDidChangeWatchedFilesRequest.Execute: TNXJSONRPCValue;
begin
  // Method: workspace/didChangeWatchedFiles; required: Optional; original server: No; category: file watching; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetParams: TNXLSDidChangeWatchedFilesParams;
begin
  Result := TNXLSDidChangeWatchedFilesParams(inherited params);
end;

procedure TNXLSWorkspaceDidChangeWatchedFilesRequest.SetParams(AValue: TNXLSDidChangeWatchedFilesParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidChangeWatchedFilesRequest);

end.
