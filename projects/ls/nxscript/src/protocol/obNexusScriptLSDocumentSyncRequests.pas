unit obNexusScriptLSDocumentSyncRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSDocumentSyncParams;

type
  TNexusScriptLSDidOpenRequest = class(TNXJSONRPCRequest)
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

  TNexusScriptLSDidChangeRequest = class(TNXJSONRPCRequest)
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

  TNexusScriptLSDidSaveRequest = class(TNXJSONRPCRequest)
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

  TNexusScriptLSDidCloseRequest = class(TNXJSONRPCRequest)
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
  obNexusScriptLSModel;

class function TNexusScriptLSDidOpenRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didOpen';
end;

class function TNexusScriptLSDidOpenRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNexusScriptLSDidOpenRequest.Execute: TNXJSONRPCValue;
begin
  TNexusScriptLSModel.Current.OpenDocument(params.textDocument.uri.Value,
    params.textDocument.languageId.Value, params.textDocument.version.Value,
    params.textDocument.text.Value);
  Result := nil;
end;

class function TNexusScriptLSDidChangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didChange';
end;

class function TNexusScriptLSDidChangeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNexusScriptLSDidChangeRequest.Execute: TNXJSONRPCValue;
begin
  if params.contentChanges.Count > 0 then
    TNexusScriptLSModel.Current.ChangeDocument(params.textDocument.uri.Value,
      params.textDocument.version.Value,
      TNXLSContentChange(params.contentChanges[0]).text.Value);
  Result := nil;
end;

class function TNexusScriptLSDidSaveRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didSave';
end;

class function TNexusScriptLSDidSaveRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNexusScriptLSDidSaveRequest.Execute: TNXJSONRPCValue;
begin
  TNexusScriptLSModel.Current.SaveDocument(params.textDocument.uri.Value);
  Result := nil;
end;

class function TNexusScriptLSDidCloseRequest.GetFactoryName: string;
begin
  Result := 'textDocument/didClose';
end;

class function TNexusScriptLSDidCloseRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNexusScriptLSDidCloseRequest.Execute: TNXJSONRPCValue;
begin
  TNexusScriptLSModel.Current.CloseDocument(params.textDocument.uri.Value);
  Result := nil;
end;

function TNexusScriptLSDidOpenRequest.GetParams: TNXLSDidOpenTextDocumentParams;
begin
  Result := TNXLSDidOpenTextDocumentParams(inherited params);
end;

procedure TNexusScriptLSDidOpenRequest.SetParams(
  AValue: TNXLSDidOpenTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSDidChangeRequest.GetParams:
  TNXLSDidChangeTextDocumentParams;
begin
  Result := TNXLSDidChangeTextDocumentParams(inherited params);
end;

procedure TNexusScriptLSDidChangeRequest.SetParams(
  AValue: TNXLSDidChangeTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSDidSaveRequest.GetParams: TNXLSDidSaveTextDocumentParams;
begin
  Result := TNXLSDidSaveTextDocumentParams(inherited params);
end;

procedure TNexusScriptLSDidSaveRequest.SetParams(
  AValue: TNXLSDidSaveTextDocumentParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSDidCloseRequest.GetParams:
  TNXLSDidCloseTextDocumentParams;
begin
  Result := TNXLSDidCloseTextDocumentParams(inherited params);
end;

procedure TNexusScriptLSDidCloseRequest.SetParams(
  AValue: TNXLSDidCloseTextDocumentParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNexusScriptLSDidOpenRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSDidChangeRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSDidSaveRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSDidCloseRequest);

end.
