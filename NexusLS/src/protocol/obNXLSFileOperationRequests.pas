unit obNXLSFileOperationRequests;

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
  TNXLSWorkspaceWillCreateFilesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCreateFilesParams;
    procedure SetParams(AValue: TNXLSCreateFilesParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCreateFilesParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceDidCreateFilesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCreateFilesParams;
    procedure SetParams(AValue: TNXLSCreateFilesParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCreateFilesParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceWillRenameFilesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSRenameFilesParams;
    procedure SetParams(AValue: TNXLSRenameFilesParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSRenameFilesParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceDidRenameFilesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSRenameFilesParams;
    procedure SetParams(AValue: TNXLSRenameFilesParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSRenameFilesParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceWillDeleteFilesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDeleteFilesParams;
    procedure SetParams(AValue: TNXLSDeleteFilesParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDeleteFilesParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceDidDeleteFilesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDeleteFilesParams;
    procedure SetParams(AValue: TNXLSDeleteFilesParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDeleteFilesParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSWorkspaceWillCreateFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/willCreateFiles';
end;

class function TNXLSWorkspaceWillCreateFilesRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceEdit;
end;

class function TNXLSWorkspaceWillCreateFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSWorkspaceWillCreateFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/willCreateFiles; required: Optional; original server: No; category: file operations; result: TNXLSWorkspaceEditResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceDidCreateFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didCreateFiles';
end;

class function TNXLSWorkspaceDidCreateFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWorkspaceDidCreateFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/didCreateFiles; required: Optional; original server: No; category: file operations; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceWillRenameFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/willRenameFiles';
end;

class function TNXLSWorkspaceWillRenameFilesRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceEdit;
end;

class function TNXLSWorkspaceWillRenameFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSWorkspaceWillRenameFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/willRenameFiles; required: Optional; original server: No; category: file operations; result: TNXLSWorkspaceEditResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceDidRenameFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didRenameFiles';
end;

class function TNXLSWorkspaceDidRenameFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWorkspaceDidRenameFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/didRenameFiles; required: Optional; original server: No; category: file operations; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceWillDeleteFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/willDeleteFiles';
end;

class function TNXLSWorkspaceWillDeleteFilesRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceEdit;
end;

class function TNXLSWorkspaceWillDeleteFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSWorkspaceWillDeleteFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/willDeleteFiles; required: Optional; original server: No; category: file operations; result: TNXLSWorkspaceEditResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceDidDeleteFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didDeleteFiles';
end;

class function TNXLSWorkspaceDidDeleteFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWorkspaceDidDeleteFilesRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/didDeleteFiles; required: Optional; original server: No; category: file operations; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSWorkspaceDidRenameFilesRequest.GetParams: TNXLSRenameFilesParams;
begin
  Result := TNXLSRenameFilesParams(inherited params);
end;

procedure TNXLSWorkspaceDidRenameFilesRequest.SetParams(AValue: TNXLSRenameFilesParams);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceWillDeleteFilesRequest.GetParams: TNXLSDeleteFilesParams;
begin
  Result := TNXLSDeleteFilesParams(inherited params);
end;

procedure TNXLSWorkspaceWillDeleteFilesRequest.SetParams(AValue: TNXLSDeleteFilesParams);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceDidDeleteFilesRequest.GetParams: TNXLSDeleteFilesParams;
begin
  Result := TNXLSDeleteFilesParams(inherited params);
end;

procedure TNXLSWorkspaceDidDeleteFilesRequest.SetParams(AValue: TNXLSDeleteFilesParams);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceWillCreateFilesRequest.GetParams: TNXLSCreateFilesParams;
begin
  Result := TNXLSCreateFilesParams(inherited params);
end;

procedure TNXLSWorkspaceWillCreateFilesRequest.SetParams(AValue: TNXLSCreateFilesParams);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceWillRenameFilesRequest.GetParams: TNXLSRenameFilesParams;
begin
  Result := TNXLSRenameFilesParams(inherited params);
end;

procedure TNXLSWorkspaceWillRenameFilesRequest.SetParams(AValue: TNXLSRenameFilesParams);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceDidCreateFilesRequest.GetParams: TNXLSCreateFilesParams;
begin
  Result := TNXLSCreateFilesParams(inherited params);
end;

procedure TNXLSWorkspaceDidCreateFilesRequest.SetParams(AValue: TNXLSCreateFilesParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceWillCreateFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidCreateFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceWillRenameFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidRenameFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceWillDeleteFilesRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidDeleteFilesRequest);

end.
