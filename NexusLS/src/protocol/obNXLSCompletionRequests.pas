unit obNXLSCompletionRequests;

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
  TNXLSTextDocumentCompletionRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCompletionItemArray;
    procedure SetResult(AValue: TNXLSCompletionItemArray);
    function GetParams: TNXLSCompletionParams;
    procedure SetParams(AValue: TNXLSCompletionParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSCompletionItemArray read GetResult write SetResult;
    property params: TNXLSCompletionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentSignatureHelpRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSSignatureHelp;
    procedure SetResult(AValue: TNXLSSignatureHelp);
    function GetParams: TNXLSSignatureHelpParams;
    procedure SetParams(AValue: TNXLSSignatureHelpParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSSignatureHelp read GetResult write SetResult;
    property params: TNXLSSignatureHelpParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel;

class function TNXLSTextDocumentCompletionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/completion';
end;

function TNXLSTextDocumentCompletionRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSCompletionItemArray;
begin
  lResult := TNXLSCompletionItemArray(PrepareResult);
  TNXLSLSPModel.Current.Completion.FillCompletionItems(
    TNXLSCompletionParams(params), lResult);
  Result := lResult;
end;

class function TNXLSTextDocumentSignatureHelpRequest.GetFactoryName: string;
begin
  Result := 'textDocument/signatureHelp';
end;

class function TNXLSTextDocumentSignatureHelpRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentSignatureHelpRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSSignatureHelp;
begin
  lResult := TNXLSSignatureHelp(PrepareResult);
  if TNXLSLSPModel.Current.Completion.FillSignatureHelp(
    TNXLSSignatureHelpParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

function TNXLSTextDocumentCompletionRequest.GetParams: TNXLSCompletionParams;
begin
  Result := TNXLSCompletionParams(inherited params);
end;

procedure TNXLSTextDocumentCompletionRequest.SetParams(AValue: TNXLSCompletionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentSignatureHelpRequest.GetParams: TNXLSSignatureHelpParams;
begin
  Result := TNXLSSignatureHelpParams(inherited params);
end;

procedure TNXLSTextDocumentSignatureHelpRequest.SetParams(AValue: TNXLSSignatureHelpParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentCompletionRequest.GetResult: TNXLSCompletionItemArray;
begin
  Result := TNXLSCompletionItemArray(inherited result);
end;

procedure TNXLSTextDocumentCompletionRequest.SetResult(AValue: TNXLSCompletionItemArray);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentSignatureHelpRequest.GetResult: TNXLSSignatureHelp;
begin
  Result := TNXLSSignatureHelp(inherited result);
end;

procedure TNXLSTextDocumentSignatureHelpRequest.SetResult(AValue: TNXLSSignatureHelp);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCompletionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSignatureHelpRequest);

end.
