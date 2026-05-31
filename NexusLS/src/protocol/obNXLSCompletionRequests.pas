unit obNXLSCompletionRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentCompletionRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentSignatureHelpRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentCompletionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/completion';
end;

class function TNXLSTextDocumentCompletionRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCompletionParams;
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

class function TNXLSTextDocumentSignatureHelpRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSSignatureHelpParams;
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
begin
  Result := TNXLSLSPModel.Current.Completion.SignatureHelp(TNXLSSignatureHelpParams(params));
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCompletionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSignatureHelpRequest);

end.
