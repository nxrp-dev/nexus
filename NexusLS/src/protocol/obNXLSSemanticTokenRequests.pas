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
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentSemanticTokensFullDeltaRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentSemanticTokensRangeRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
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

function TNXLSTextDocumentSemanticTokensFullRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/semanticTokens/full; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensResult.
  Result := TNXLSSemanticTokensResult.CreateValue;
end;

class function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetFactoryName: string;
begin
  Result := 'textDocument/semanticTokens/full/delta';
end;

class function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSSemanticTokensDeltaParams;
end;

function TNXLSTextDocumentSemanticTokensFullDeltaRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/semanticTokens/full/delta; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensDeltaResult.
  Result := TNXLSSemanticTokensDeltaResult.CreateValue;
end;

class function TNXLSTextDocumentSemanticTokensRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/semanticTokens/range';
end;

class function TNXLSTextDocumentSemanticTokensRangeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSSemanticTokensRangeParams;
end;

function TNXLSTextDocumentSemanticTokensRangeRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/semanticTokens/range; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensResult.
  Result := TNXLSSemanticTokensResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensFullRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensFullDeltaRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensRangeRequest);

end.
