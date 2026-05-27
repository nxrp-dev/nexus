unit obNXLSEditorService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSEditorService = class(TNXLSLSPService)
  public
    function CodeAction(AParams: TNXLSCodeActionParams): TNXJSONValue; virtual;
    function DocumentHighlight(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function Hover(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function InlayHint(AParams: TNXLSInlayHintParams): TNXJSONValue; virtual;
  end;

implementation

uses
  obNXLSProtocolObjects;

function TNXLSEditorService.CodeAction(AParams: TNXLSCodeActionParams): TNXJSONValue;
begin
  Result := TNXLSCodeActionArrayResult.CreateValue;
end;

function TNXLSEditorService.DocumentHighlight(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSDocumentHighlightArrayResult.CreateValue;
end;

function TNXLSEditorService.Hover(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSHoverResult.CreateValue;
end;

function TNXLSEditorService.InlayHint(AParams: TNXLSInlayHintParams): TNXJSONValue;
begin
  Result := TNXLSInlayHintArrayResult.CreateValue;
end;

end.
