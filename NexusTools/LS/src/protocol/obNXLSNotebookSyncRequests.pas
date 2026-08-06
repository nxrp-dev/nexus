unit obNXLSNotebookSyncRequests;

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
  TNXLSNotebookDocumentDidOpenRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidOpenNotebookDocumentParams;
    procedure SetParams(AValue: TNXLSDidOpenNotebookDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidOpenNotebookDocumentParams read GetParams write SetParams;
  end;

  TNXLSNotebookDocumentDidChangeRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidChangeNotebookDocumentParams;
    procedure SetParams(AValue: TNXLSDidChangeNotebookDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidChangeNotebookDocumentParams read GetParams write SetParams;
  end;

  TNXLSNotebookDocumentDidSaveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSNotebookDocumentParams;
    procedure SetParams(AValue: TNXLSNotebookDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSNotebookDocumentParams read GetParams write SetParams;
  end;

  TNXLSNotebookDocumentDidCloseRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidCloseNotebookDocumentParams;
    procedure SetParams(AValue: TNXLSDidCloseNotebookDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidCloseNotebookDocumentParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSNotebookDocumentDidOpenRequest.GetFactoryName: string;
begin
  Result := 'notebookDocument/didOpen';
end;

class function TNXLSNotebookDocumentDidOpenRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSNotebookDocumentDidOpenRequest.Execute: TNXJSONRPCValue;
begin
  // Method: notebookDocument/didOpen; required: Optional; original server: No; category: notebook sync; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSNotebookDocumentDidChangeRequest.GetFactoryName: string;
begin
  Result := 'notebookDocument/didChange';
end;

class function TNXLSNotebookDocumentDidChangeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSNotebookDocumentDidChangeRequest.Execute: TNXJSONRPCValue;
begin
  // Method: notebookDocument/didChange; required: Optional; original server: No; category: notebook sync; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSNotebookDocumentDidSaveRequest.GetFactoryName: string;
begin
  Result := 'notebookDocument/didSave';
end;

class function TNXLSNotebookDocumentDidSaveRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSNotebookDocumentDidSaveRequest.Execute: TNXJSONRPCValue;
begin
  // Method: notebookDocument/didSave; required: Optional; original server: No; category: notebook sync; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSNotebookDocumentDidCloseRequest.GetFactoryName: string;
begin
  Result := 'notebookDocument/didClose';
end;

class function TNXLSNotebookDocumentDidCloseRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSNotebookDocumentDidCloseRequest.Execute: TNXJSONRPCValue;
begin
  // Method: notebookDocument/didClose; required: Optional; original server: No; category: notebook sync; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSNotebookDocumentDidChangeRequest.GetParams: TNXLSDidChangeNotebookDocumentParams;
begin
  Result := TNXLSDidChangeNotebookDocumentParams(inherited params);
end;

procedure TNXLSNotebookDocumentDidChangeRequest.SetParams(AValue: TNXLSDidChangeNotebookDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSNotebookDocumentDidOpenRequest.GetParams: TNXLSDidOpenNotebookDocumentParams;
begin
  Result := TNXLSDidOpenNotebookDocumentParams(inherited params);
end;

procedure TNXLSNotebookDocumentDidOpenRequest.SetParams(AValue: TNXLSDidOpenNotebookDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSNotebookDocumentDidSaveRequest.GetParams: TNXLSNotebookDocumentParams;
begin
  Result := TNXLSNotebookDocumentParams(inherited params);
end;

procedure TNXLSNotebookDocumentDidSaveRequest.SetParams(AValue: TNXLSNotebookDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSNotebookDocumentDidCloseRequest.GetParams: TNXLSDidCloseNotebookDocumentParams;
begin
  Result := TNXLSDidCloseNotebookDocumentParams(inherited params);
end;

procedure TNXLSNotebookDocumentDidCloseRequest.SetParams(AValue: TNXLSDidCloseNotebookDocumentParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSNotebookDocumentDidOpenRequest);
  TNXClassFactory.RegisterClass(TNXLSNotebookDocumentDidChangeRequest);
  TNXClassFactory.RegisterClass(TNXLSNotebookDocumentDidSaveRequest);
  TNXClassFactory.RegisterClass(TNXLSNotebookDocumentDidCloseRequest);

end.
