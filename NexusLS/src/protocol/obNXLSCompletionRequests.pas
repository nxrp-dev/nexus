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
    function GetParams: TNXLSCompletionParams;
    procedure SetParams(AValue: TNXLSCompletionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCompletionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentSignatureHelpRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSSignatureHelpParams;
    procedure SetParams(AValue: TNXLSSignatureHelpParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
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

class function TNXLSTextDocumentCompletionRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCompletionItemArray;
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

class function TNXLSTextDocumentSignatureHelpRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSSignatureHelp;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCompletionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSignatureHelpRequest);

end.
