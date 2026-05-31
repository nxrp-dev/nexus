unit obNXLSSymbolRequests;

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
  TNXLSTextDocumentDocumentSymbolRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXJSONArray;
    procedure SetResult(AValue: TNXJSONArray);
    function GetParams: TNXLSDocumentSymbolParams;
    procedure SetParams(AValue: TNXLSDocumentSymbolParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXJSONArray read GetResult write SetResult;
    property params: TNXLSDocumentSymbolParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceSymbolRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXJSONArray;
    procedure SetResult(AValue: TNXJSONArray);
    function GetParams: TNXLSWorkspaceSymbolParams;
    procedure SetParams(AValue: TNXLSWorkspaceSymbolParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXJSONArray read GetResult write SetResult;
    property params: TNXLSWorkspaceSymbolParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel;

class function TNXLSTextDocumentDocumentSymbolRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentSymbol';
end;

function TNXLSTextDocumentDocumentSymbolRequest.Execute: TNXJSONValue;
var
  lResult: TNXJSONArray;
begin
  lResult := TNXJSONArray(PrepareResult);
  TNXLSLSPModel.Current.Symbols.FillDocumentSymbols(
    TNXLSDocumentSymbolParams(params), lResult);
  Result := lResult;
end;

class function TNXLSWorkspaceSymbolRequest.GetFactoryName: string;
begin
  Result := 'workspace/symbol';
end;

function TNXLSWorkspaceSymbolRequest.Execute: TNXJSONValue;
var
  lResult: TNXJSONArray;
begin
  lResult := TNXJSONArray(PrepareResult);
  TNXLSLSPModel.Current.Symbols.FillWorkspaceSymbols(
    TNXLSWorkspaceSymbolParams(params), lResult);
  Result := lResult;
end;

function TNXLSWorkspaceSymbolRequest.GetParams: TNXLSWorkspaceSymbolParams;
begin
  Result := TNXLSWorkspaceSymbolParams(inherited params);
end;

procedure TNXLSWorkspaceSymbolRequest.SetParams(AValue: TNXLSWorkspaceSymbolParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDocumentSymbolRequest.GetParams: TNXLSDocumentSymbolParams;
begin
  Result := TNXLSDocumentSymbolParams(inherited params);
end;

procedure TNXLSTextDocumentDocumentSymbolRequest.SetParams(AValue: TNXLSDocumentSymbolParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDocumentSymbolRequest.GetResult: TNXJSONArray;
begin
  Result := TNXJSONArray(inherited result);
end;

procedure TNXLSTextDocumentDocumentSymbolRequest.SetResult(AValue: TNXJSONArray);
begin
  inherited result := AValue;
end;

function TNXLSWorkspaceSymbolRequest.GetResult: TNXJSONArray;
begin
  Result := TNXJSONArray(inherited result);
end;

procedure TNXLSWorkspaceSymbolRequest.SetResult(AValue: TNXJSONArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentSymbolRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSymbolRequest);

end.
