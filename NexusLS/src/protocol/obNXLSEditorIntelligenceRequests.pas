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
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentDocumentLinkRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDocumentLinkParams;
    procedure SetParams(AValue: TNXLSDocumentLinkParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDocumentLinkParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentHoverRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentCodeLensRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCodeLensParams;
    procedure SetParams(AValue: TNXLSCodeLensParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCodeLensParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentFoldingRangeRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSFoldingRangeParams;
    procedure SetParams(AValue: TNXLSFoldingRangeParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSFoldingRangeParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentSelectionRangeRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSSelectionRangeParams;
    procedure SetParams(AValue: TNXLSSelectionRangeParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSSelectionRangeParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel;

class function TNXLSTextDocumentDocumentHighlightRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentHighlight';
end;

class function TNXLSTextDocumentDocumentHighlightRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentHighlightArray;
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

class function TNXLSTextDocumentDocumentLinkRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentLinkArray;
end;

function TNXLSTextDocumentDocumentLinkRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSTextDocumentHoverRequest.GetFactoryName: string;
begin
  Result := 'textDocument/hover';
end;

class function TNXLSTextDocumentHoverRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSHover;
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

class function TNXLSTextDocumentCodeLensRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeLensArray;
end;

function TNXLSTextDocumentCodeLensRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSTextDocumentFoldingRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/foldingRange';
end;

class function TNXLSTextDocumentFoldingRangeRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSFoldingRangeArray;
end;

function TNXLSTextDocumentFoldingRangeRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSTextDocumentSelectionRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/selectionRange';
end;

class function TNXLSTextDocumentSelectionRangeRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSSelectionRangeArray;
end;

function TNXLSTextDocumentSelectionRangeRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentHighlightRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentLinkRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentHoverRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCodeLensRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentFoldingRangeRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSelectionRangeRequest);

end.
