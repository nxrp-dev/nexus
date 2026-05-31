unit obNXLSDocumentSyncRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSDocumentSyncParams;

type
  TNXLSTextDocumentDidOpenRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentDidChangeRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentWillSaveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentWillSaveWaitUntilRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentDidSaveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentDidCloseRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentDidOpenRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didOpen';
end;

class function TNXLSTextDocumentDidOpenRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidOpenTextDocumentParams;
end;

function TNXLSTextDocumentDidOpenRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Documents.DidOpen(TNXLSDidOpenTextDocumentParams(params));
  Result := nil;
end;

class function TNXLSTextDocumentDidChangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didChange';
end;

class function TNXLSTextDocumentDidChangeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidChangeTextDocumentParams;
end;

function TNXLSTextDocumentDidChangeRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Documents.DidChange(TNXLSDidChangeTextDocumentParams(params));
  Result := nil;
end;

class function TNXLSTextDocumentWillSaveRequest.GetFactoryName: string;
begin
  Result := 'textDocument/willSave';
end;

class function TNXLSTextDocumentWillSaveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWillSaveTextDocumentParams;
end;

function TNXLSTextDocumentWillSaveRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/willSave; required: Optional; original server: No; category: document sync; result: nil.
  Result := nil;
end;

class function TNXLSTextDocumentWillSaveWaitUntilRequest.GetFactoryName: string;
begin
  Result := 'textDocument/willSaveWaitUntil';
end;

class function TNXLSTextDocumentWillSaveWaitUntilRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWillSaveTextDocumentParams;
end;

class function TNXLSTextDocumentWillSaveWaitUntilRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTextEditArray;
end;

function TNXLSTextDocumentWillSaveWaitUntilRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSTextDocumentDidSaveRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didSave';
end;

class function TNXLSTextDocumentDidSaveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidSaveTextDocumentParams;
end;

function TNXLSTextDocumentDidSaveRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Documents.DidSave(TNXLSDidSaveTextDocumentParams(params));
  Result := nil;
end;

class function TNXLSTextDocumentDidCloseRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didClose';
end;

class function TNXLSTextDocumentDidCloseRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDidCloseTextDocumentParams;
end;

function TNXLSTextDocumentDidCloseRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Documents.DidClose(TNXLSDidCloseTextDocumentParams(params));
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDidOpenRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDidChangeRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentWillSaveRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentWillSaveWaitUntilRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDidSaveRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDidCloseRequest);

end.
