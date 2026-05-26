unit obNXLSFileOperationRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWorkspaceWillCreateFilesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDidCreateFilesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceWillRenameFilesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDidRenameFilesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceWillDeleteFilesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDidDeleteFilesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSWorkspaceWillCreateFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/willCreateFiles';
end;

class function TNXLSWorkspaceWillCreateFilesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCreateFilesParams;
end;

function TNXLSWorkspaceWillCreateFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/willCreateFiles; required: Optional; original server: No; category: file operations; result: TNXLSWorkspaceEditResult.
  Result := TNXLSWorkspaceEditResult.CreateValue;
end;

class function TNXLSWorkspaceDidCreateFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didCreateFiles';
end;

class function TNXLSWorkspaceDidCreateFilesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCreateFilesParams;
end;

function TNXLSWorkspaceDidCreateFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/didCreateFiles; required: Optional; original server: No; category: file operations; result: nil.
  Result := nil;
end;

class function TNXLSWorkspaceWillRenameFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/willRenameFiles';
end;

class function TNXLSWorkspaceWillRenameFilesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSRenameFilesParams;
end;

function TNXLSWorkspaceWillRenameFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/willRenameFiles; required: Optional; original server: No; category: file operations; result: TNXLSWorkspaceEditResult.
  Result := TNXLSWorkspaceEditResult.CreateValue;
end;

class function TNXLSWorkspaceDidRenameFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didRenameFiles';
end;

class function TNXLSWorkspaceDidRenameFilesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSRenameFilesParams;
end;

function TNXLSWorkspaceDidRenameFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/didRenameFiles; required: Optional; original server: No; category: file operations; result: nil.
  Result := nil;
end;

class function TNXLSWorkspaceWillDeleteFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/willDeleteFiles';
end;

class function TNXLSWorkspaceWillDeleteFilesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDeleteFilesParams;
end;

function TNXLSWorkspaceWillDeleteFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/willDeleteFiles; required: Optional; original server: No; category: file operations; result: TNXLSWorkspaceEditResult.
  Result := TNXLSWorkspaceEditResult.CreateValue;
end;

class function TNXLSWorkspaceDidDeleteFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didDeleteFiles';
end;

class function TNXLSWorkspaceDidDeleteFilesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDeleteFilesParams;
end;

function TNXLSWorkspaceDidDeleteFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/didDeleteFiles; required: Optional; original server: No; category: file operations; result: nil.
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceWillCreateFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidCreateFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceWillRenameFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidRenameFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceWillDeleteFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidDeleteFilesRequest);

end.
