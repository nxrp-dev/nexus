unit obNXLSNotebookSyncRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSNotebookDocumentDidOpenRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSNotebookDocumentDidChangeRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSNotebookDocumentDidSaveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSNotebookDocumentDidCloseRequest = class(TNXJSONRPCRequest)
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

class function TNXLSNotebookDocumentDidOpenRequest.GetFactoryName: string;
begin
  Result := 'notebookDocument/didOpen';
end;

class function TNXLSNotebookDocumentDidOpenRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidOpenNotebookDocumentParams;
end;

class function TNXLSNotebookDocumentDidOpenRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSNotebookDocumentDidOpenRequest.Execute: TNXJSONValue;
begin
  // Method: notebookDocument/didOpen; required: Optional; original server: No; category: notebook sync; result: nil.
  Result := nil;
end;

class function TNXLSNotebookDocumentDidChangeRequest.GetFactoryName: string;
begin
  Result := 'notebookDocument/didChange';
end;

class function TNXLSNotebookDocumentDidChangeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidChangeNotebookDocumentParams;
end;

class function TNXLSNotebookDocumentDidChangeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSNotebookDocumentDidChangeRequest.Execute: TNXJSONValue;
begin
  // Method: notebookDocument/didChange; required: Optional; original server: No; category: notebook sync; result: nil.
  Result := nil;
end;

class function TNXLSNotebookDocumentDidSaveRequest.GetFactoryName: string;
begin
  Result := 'notebookDocument/didSave';
end;

class function TNXLSNotebookDocumentDidSaveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSNotebookDocumentParams;
end;

class function TNXLSNotebookDocumentDidSaveRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSNotebookDocumentDidSaveRequest.Execute: TNXJSONValue;
begin
  // Method: notebookDocument/didSave; required: Optional; original server: No; category: notebook sync; result: nil.
  Result := nil;
end;

class function TNXLSNotebookDocumentDidCloseRequest.GetFactoryName: string;
begin
  Result := 'notebookDocument/didClose';
end;

class function TNXLSNotebookDocumentDidCloseRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidCloseNotebookDocumentParams;
end;

class function TNXLSNotebookDocumentDidCloseRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSNotebookDocumentDidCloseRequest.Execute: TNXJSONValue;
begin
  // Method: notebookDocument/didClose; required: Optional; original server: No; category: notebook sync; result: nil.
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSNotebookDocumentDidOpenRequest);
  TNXClassFactory.RegisterClass(TNXLSNotebookDocumentDidChangeRequest);
  TNXClassFactory.RegisterClass(TNXLSNotebookDocumentDidSaveRequest);
  TNXClassFactory.RegisterClass(TNXLSNotebookDocumentDidCloseRequest);

end.
