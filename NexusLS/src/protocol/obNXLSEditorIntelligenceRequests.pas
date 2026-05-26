unit obNXLSEditorIntelligenceRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentDocumentHighlightRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentDocumentLinkRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentHoverRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentCodeLensRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentFoldingRangeRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentSelectionRangeRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentDocumentHighlightRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentHighlight';
end;

class function TNXLSTextDocumentDocumentHighlightRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentDocumentHighlightRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Editor.DocumentHighlight(TNXLSTextDocumentPositionParams(params));
end;

class function TNXLSTextDocumentDocumentLinkRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentLink';
end;

class function TNXLSTextDocumentDocumentLinkRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentLinkParams;
end;

function TNXLSTextDocumentDocumentLinkRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/documentLink; required: Optional; original server: No; category: editor intelligence; result: TNXLSDocumentLinkArrayResult.
  Result := TNXLSDocumentLinkArrayResult.CreateValue;
end;

class function TNXLSTextDocumentHoverRequest.GetFactoryName: string;
begin
  Result := 'textDocument/hover';
end;

class function TNXLSTextDocumentHoverRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentHoverRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Editor.Hover(TNXLSTextDocumentPositionParams(params));
end;

class function TNXLSTextDocumentCodeLensRequest.GetFactoryName: string;
begin
  Result := 'textDocument/codeLens';
end;

class function TNXLSTextDocumentCodeLensRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeLensParams;
end;

function TNXLSTextDocumentCodeLensRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/codeLens; required: Optional; original server: No; category: editor intelligence; result: TNXLSCodeLensArrayResult.
  Result := TNXLSCodeLensArrayResult.CreateValue;
end;

class function TNXLSTextDocumentFoldingRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/foldingRange';
end;

class function TNXLSTextDocumentFoldingRangeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSFoldingRangeParams;
end;

function TNXLSTextDocumentFoldingRangeRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/foldingRange; required: Optional; original server: No; category: editor intelligence; result: TNXLSFoldingRangeArrayResult.
  Result := TNXLSFoldingRangeArrayResult.CreateValue;
end;

class function TNXLSTextDocumentSelectionRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/selectionRange';
end;

class function TNXLSTextDocumentSelectionRangeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSSelectionRangeParams;
end;

function TNXLSTextDocumentSelectionRangeRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/selectionRange; required: Optional; original server: No; category: editor intelligence; result: TNXLSSelectionRangeArrayResult.
  Result := TNXLSSelectionRangeArrayResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentHighlightRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentLinkRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentHoverRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCodeLensRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentFoldingRangeRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentSelectionRangeRequest);

end.
