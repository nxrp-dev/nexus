unit obNXLSEditorIntelligenceRequests;

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
  TNXLSTextDocumentDocumentHighlightRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSDocumentHighlightArray;
    procedure SetResult(AValue: TNXLSDocumentHighlightArray);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSDocumentHighlightArray read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentDocumentLinkRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSDocumentLinkArray;
    procedure SetResult(AValue: TNXLSDocumentLinkArray);
    function GetParams: TNXLSDocumentLinkParams;
    procedure SetParams(AValue: TNXLSDocumentLinkParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSDocumentLinkArray read GetResult write SetResult;
    property params: TNXLSDocumentLinkParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentHoverRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSHover;
    procedure SetResult(AValue: TNXLSHover);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSHover read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentCodeLensRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCodeLensArray;
    procedure SetResult(AValue: TNXLSCodeLensArray);
    function GetParams: TNXLSCodeLensParams;
    procedure SetParams(AValue: TNXLSCodeLensParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSCodeLensArray read GetResult write SetResult;
    property params: TNXLSCodeLensParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentFoldingRangeRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSFoldingRangeArray;
    procedure SetResult(AValue: TNXLSFoldingRangeArray);
    function GetParams: TNXLSFoldingRangeParams;
    procedure SetParams(AValue: TNXLSFoldingRangeParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSFoldingRangeArray read GetResult write SetResult;
    property params: TNXLSFoldingRangeParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentSelectionRangeRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSSelectionRangeArray;
    procedure SetResult(AValue: TNXLSSelectionRangeArray);
    function GetParams: TNXLSSelectionRangeParams;
    procedure SetParams(AValue: TNXLSSelectionRangeParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSSelectionRangeArray read GetResult write SetResult;
    property params: TNXLSSelectionRangeParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  tpNXLS;

class function TNXLSTextDocumentDocumentHighlightRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentHighlight';
end;

function TNXLSTextDocumentDocumentHighlightRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSDocumentHighlightArray;
begin
  lResult := TNXLSDocumentHighlightArray(PrepareResult);
  TNXLSLSPModel.Current.Editor.FillDocumentHighlights(
    TNXLSTextDocumentPositionParams(params), lResult);
  Result := lResult;
end;

class function TNXLSTextDocumentDocumentLinkRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentLink';
end;

function TNXLSTextDocumentDocumentLinkRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentHoverRequest.GetFactoryName: string;
begin
  Result := 'textDocument/hover';
end;

class function TNXLSTextDocumentHoverRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentHoverRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSHover;
begin
  lResult := TNXLSHover(PrepareResult);
  if TNXLSLSPModel.Current.Editor.FillHover(
    TNXLSTextDocumentPositionParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSTextDocumentCodeLensRequest.GetFactoryName: string;
begin
  Result := 'textDocument/codeLens';
end;

function TNXLSTextDocumentCodeLensRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentFoldingRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/foldingRange';
end;

function TNXLSTextDocumentFoldingRangeRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentSelectionRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/selectionRange';
end;

function TNXLSTextDocumentSelectionRangeRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentCodeLensRequest.GetParams: TNXLSCodeLensParams;
begin
  Result := TNXLSCodeLensParams(inherited params);
end;

procedure TNXLSTextDocumentCodeLensRequest.SetParams(AValue: TNXLSCodeLensParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentHoverRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentHoverRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentFoldingRangeRequest.GetParams: TNXLSFoldingRangeParams;
begin
  Result := TNXLSFoldingRangeParams(inherited params);
end;

procedure TNXLSTextDocumentFoldingRangeRequest.SetParams(AValue: TNXLSFoldingRangeParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDocumentLinkRequest.GetParams: TNXLSDocumentLinkParams;
begin
  Result := TNXLSDocumentLinkParams(inherited params);
end;

procedure TNXLSTextDocumentDocumentLinkRequest.SetParams(AValue: TNXLSDocumentLinkParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDocumentHighlightRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentDocumentHighlightRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentSelectionRangeRequest.GetParams: TNXLSSelectionRangeParams;
begin
  Result := TNXLSSelectionRangeParams(inherited params);
end;

procedure TNXLSTextDocumentSelectionRangeRequest.SetParams(AValue: TNXLSSelectionRangeParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDocumentHighlightRequest.GetResult: TNXLSDocumentHighlightArray;
begin
  Result := TNXLSDocumentHighlightArray(inherited result);
end;

procedure TNXLSTextDocumentDocumentHighlightRequest.SetResult(AValue: TNXLSDocumentHighlightArray);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentDocumentLinkRequest.GetResult: TNXLSDocumentLinkArray;
begin
  Result := TNXLSDocumentLinkArray(inherited result);
end;

procedure TNXLSTextDocumentDocumentLinkRequest.SetResult(AValue: TNXLSDocumentLinkArray);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentHoverRequest.GetResult: TNXLSHover;
begin
  Result := TNXLSHover(inherited result);
end;

procedure TNXLSTextDocumentHoverRequest.SetResult(AValue: TNXLSHover);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentCodeLensRequest.GetResult: TNXLSCodeLensArray;
begin
  Result := TNXLSCodeLensArray(inherited result);
end;

procedure TNXLSTextDocumentCodeLensRequest.SetResult(AValue: TNXLSCodeLensArray);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentFoldingRangeRequest.GetResult: TNXLSFoldingRangeArray;
begin
  Result := TNXLSFoldingRangeArray(inherited result);
end;

procedure TNXLSTextDocumentFoldingRangeRequest.SetResult(AValue: TNXLSFoldingRangeArray);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentSelectionRangeRequest.GetResult: TNXLSSelectionRangeArray;
begin
  Result := TNXLSSelectionRangeArray(inherited result);
end;

procedure TNXLSTextDocumentSelectionRangeRequest.SetResult(AValue: TNXLSSelectionRangeArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentHighlightRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentLinkRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentHoverRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCodeLensRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentFoldingRangeRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSelectionRangeRequest);

end.
