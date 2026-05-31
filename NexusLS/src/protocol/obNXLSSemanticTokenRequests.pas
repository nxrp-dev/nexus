unit obNXLSSemanticTokenRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentSemanticTokensFullRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentSemanticTokensFullDeltaRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentSemanticTokensRangeRequest = class(TNXJSONRPCRequest)
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
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentSemanticTokensFullRequest.GetFactoryName: string;
begin
  Result := 'textDocument/semanticTokens/full';
end;

class function TNXLSTextDocumentSemanticTokensFullRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSSemanticTokensParams;
end;

class function TNXLSTextDocumentSemanticTokensFullRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSSemanticTokens;
end;

class function TNXLSTextDocumentSemanticTokensFullRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentSemanticTokensFullRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/semanticTokens/full; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensResult.
  Result := TNXJSONNull.Create;
end;

class function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetFactoryName: string;
begin
  Result := 'textDocument/semanticTokens/full/delta';
end;

class function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSSemanticTokensDeltaParams;
end;

class function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSSemanticTokensDelta;
end;

class function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentSemanticTokensFullDeltaRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/semanticTokens/full/delta; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensDeltaResult.
  Result := TNXJSONNull.Create;
end;

class function TNXLSTextDocumentSemanticTokensRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/semanticTokens/range';
end;

class function TNXLSTextDocumentSemanticTokensRangeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSSemanticTokensRangeParams;
end;

class function TNXLSTextDocumentSemanticTokensRangeRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSSemanticTokens;
end;

class function TNXLSTextDocumentSemanticTokensRangeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentSemanticTokensRangeRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/semanticTokens/range; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensResult.
  Result := TNXJSONNull.Create;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensFullRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensFullDeltaRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensRangeRequest);

end.
