unit obNXLSDocumentSyncRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  obNXLSProtocolBase,
  obNXLSDocumentSyncParams;

type
  TNXLSTextDocumentDidOpenRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidOpenTextDocumentParams;
    procedure SetParams(AValue: TNXLSDidOpenTextDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidOpenTextDocumentParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentDidChangeRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidChangeTextDocumentParams;
    procedure SetParams(AValue: TNXLSDidChangeTextDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidChangeTextDocumentParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentWillSaveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSWillSaveTextDocumentParams;
    procedure SetParams(AValue: TNXLSWillSaveTextDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSWillSaveTextDocumentParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentWillSaveWaitUntilRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSTextEditArray;
    procedure SetResult(AValue: TNXLSTextEditArray);
    function GetParams: TNXLSWillSaveTextDocumentParams;
    procedure SetParams(AValue: TNXLSWillSaveTextDocumentParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSTextEditArray read GetResult write SetResult;
    property params: TNXLSWillSaveTextDocumentParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentDidSaveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidSaveTextDocumentParams;
    procedure SetParams(AValue: TNXLSDidSaveTextDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidSaveTextDocumentParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentDidCloseRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidCloseTextDocumentParams;
    procedure SetParams(AValue: TNXLSDidCloseTextDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidCloseTextDocumentParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  tpNXLS;

class function TNXLSTextDocumentDidOpenRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didOpen';
end;

class function TNXLSTextDocumentDidOpenRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSTextDocumentDidOpenRequest.Execute: TNXJSONRPCValue;
begin
  TNXLSLSPModel.Current.Documents.DidOpen(TNXLSDidOpenTextDocumentParams(params));
  Result := nil;
end;

class function TNXLSTextDocumentDidChangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didChange';
end;

class function TNXLSTextDocumentDidChangeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSTextDocumentDidChangeRequest.Execute: TNXJSONRPCValue;
begin
  TNXLSLSPModel.Current.Documents.DidChange(TNXLSDidChangeTextDocumentParams(params));
  Result := nil;
end;

class function TNXLSTextDocumentWillSaveRequest.GetFactoryName: string;
begin
  Result := 'textDocument/willSave';
end;

class function TNXLSTextDocumentWillSaveRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSTextDocumentWillSaveRequest.Execute: TNXJSONRPCValue;
begin
  // Method: textDocument/willSave; required: Optional; original server: No; category: document sync; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentWillSaveWaitUntilRequest.GetFactoryName: string;
begin
  Result := 'textDocument/willSaveWaitUntil';
end;

function TNXLSTextDocumentWillSaveWaitUntilRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentDidSaveRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didSave';
end;

class function TNXLSTextDocumentDidSaveRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSTextDocumentDidSaveRequest.Execute: TNXJSONRPCValue;
begin
  TNXLSLSPModel.Current.Documents.DidSave(TNXLSDidSaveTextDocumentParams(params));
  Result := nil;
end;

class function TNXLSTextDocumentDidCloseRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didClose';
end;

class function TNXLSTextDocumentDidCloseRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSTextDocumentDidCloseRequest.Execute: TNXJSONRPCValue;
begin
  TNXLSLSPModel.Current.Documents.DidClose(TNXLSDidCloseTextDocumentParams(params));
  Result := nil;
end;

function TNXLSTextDocumentDidChangeRequest.GetParams: TNXLSDidChangeTextDocumentParams;
begin
  Result := TNXLSDidChangeTextDocumentParams(inherited params);
end;

procedure TNXLSTextDocumentDidChangeRequest.SetParams(AValue: TNXLSDidChangeTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentWillSaveWaitUntilRequest.GetParams: TNXLSWillSaveTextDocumentParams;
begin
  Result := TNXLSWillSaveTextDocumentParams(inherited params);
end;

procedure TNXLSTextDocumentWillSaveWaitUntilRequest.SetParams(AValue: TNXLSWillSaveTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDidSaveRequest.GetParams: TNXLSDidSaveTextDocumentParams;
begin
  Result := TNXLSDidSaveTextDocumentParams(inherited params);
end;

procedure TNXLSTextDocumentDidSaveRequest.SetParams(AValue: TNXLSDidSaveTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentWillSaveRequest.GetParams: TNXLSWillSaveTextDocumentParams;
begin
  Result := TNXLSWillSaveTextDocumentParams(inherited params);
end;

procedure TNXLSTextDocumentWillSaveRequest.SetParams(AValue: TNXLSWillSaveTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDidOpenRequest.GetParams: TNXLSDidOpenTextDocumentParams;
begin
  Result := TNXLSDidOpenTextDocumentParams(inherited params);
end;

procedure TNXLSTextDocumentDidOpenRequest.SetParams(AValue: TNXLSDidOpenTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDidCloseRequest.GetParams: TNXLSDidCloseTextDocumentParams;
begin
  Result := TNXLSDidCloseTextDocumentParams(inherited params);
end;

procedure TNXLSTextDocumentDidCloseRequest.SetParams(AValue: TNXLSDidCloseTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentWillSaveWaitUntilRequest.GetResult: TNXLSTextEditArray;
begin
  Result := TNXLSTextEditArray(inherited result);
end;

procedure TNXLSTextDocumentWillSaveWaitUntilRequest.SetResult(AValue: TNXLSTextEditArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDidOpenRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDidChangeRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentWillSaveRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentWillSaveWaitUntilRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDidSaveRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDidCloseRequest);

end.
