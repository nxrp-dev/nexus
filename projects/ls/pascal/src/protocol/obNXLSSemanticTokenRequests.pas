unit obNXLSSemanticTokenRequests;

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
  TNXLSTextDocumentSemanticTokensFullRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSSemanticTokens;
    procedure SetResult(AValue: TNXLSSemanticTokens);
    function GetParams: TNXLSSemanticTokensParams;
    procedure SetParams(AValue: TNXLSSemanticTokensParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSSemanticTokens read GetResult write SetResult;
    property params: TNXLSSemanticTokensParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentSemanticTokensFullDeltaRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSSemanticTokensDelta;
    procedure SetResult(AValue: TNXLSSemanticTokensDelta);
    function GetParams: TNXLSSemanticTokensDeltaParams;
    procedure SetParams(AValue: TNXLSSemanticTokensDeltaParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSSemanticTokensDelta read GetResult write SetResult;
    property params: TNXLSSemanticTokensDeltaParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentSemanticTokensRangeRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSSemanticTokens;
    procedure SetResult(AValue: TNXLSSemanticTokens);
    function GetParams: TNXLSSemanticTokensRangeParams;
    procedure SetParams(AValue: TNXLSSemanticTokensRangeParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSSemanticTokens read GetResult write SetResult;
    property params: TNXLSSemanticTokensRangeParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentSemanticTokensFullRequest.GetFactoryName: string;
begin
  Result := 'textDocument/semanticTokens/full';
end;

class function TNXLSTextDocumentSemanticTokensFullRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentSemanticTokensFullRequest.Execute: TNXJSONRPCValue;
begin
  // Method: textDocument/semanticTokens/full; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetFactoryName: string;
begin
  Result := 'textDocument/semanticTokens/full/delta';
end;

class function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentSemanticTokensFullDeltaRequest.Execute: TNXJSONRPCValue;
begin
  // Method: textDocument/semanticTokens/full/delta; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensDeltaResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentSemanticTokensRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/semanticTokens/range';
end;

class function TNXLSTextDocumentSemanticTokensRangeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentSemanticTokensRangeRequest.Execute: TNXJSONRPCValue;
begin
  // Method: textDocument/semanticTokens/range; required: Optional; original server: No; category: semantic tokens; result: TNXLSSemanticTokensResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentSemanticTokensFullRequest.GetParams: TNXLSSemanticTokensParams;
begin
  Result := TNXLSSemanticTokensParams(inherited params);
end;

procedure TNXLSTextDocumentSemanticTokensFullRequest.SetParams(AValue: TNXLSSemanticTokensParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetParams: TNXLSSemanticTokensDeltaParams;
begin
  Result := TNXLSSemanticTokensDeltaParams(inherited params);
end;

procedure TNXLSTextDocumentSemanticTokensFullDeltaRequest.SetParams(AValue: TNXLSSemanticTokensDeltaParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentSemanticTokensRangeRequest.GetParams: TNXLSSemanticTokensRangeParams;
begin
  Result := TNXLSSemanticTokensRangeParams(inherited params);
end;

procedure TNXLSTextDocumentSemanticTokensRangeRequest.SetParams(AValue: TNXLSSemanticTokensRangeParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentSemanticTokensFullRequest.GetResult: TNXLSSemanticTokens;
begin
  Result := TNXLSSemanticTokens(inherited result);
end;

procedure TNXLSTextDocumentSemanticTokensFullRequest.SetResult(AValue: TNXLSSemanticTokens);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentSemanticTokensFullDeltaRequest.GetResult: TNXLSSemanticTokensDelta;
begin
  Result := TNXLSSemanticTokensDelta(inherited result);
end;

procedure TNXLSTextDocumentSemanticTokensFullDeltaRequest.SetResult(AValue: TNXLSSemanticTokensDelta);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentSemanticTokensRangeRequest.GetResult: TNXLSSemanticTokens;
begin
  Result := TNXLSSemanticTokens(inherited result);
end;

procedure TNXLSTextDocumentSemanticTokensRangeRequest.SetResult(AValue: TNXLSSemanticTokens);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensFullRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensFullDeltaRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSemanticTokensRangeRequest);

end.
