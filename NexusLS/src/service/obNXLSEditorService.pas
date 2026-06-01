unit obNXLSEditorService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext;

type
  TNXLSEditorService = class(TNXLSLSPService)
  public
    procedure FillCodeActions(AParams: TNXLSCodeActionParams;
      AResult: TNXLSCodeActionArray); virtual;
    procedure FillDocumentHighlights(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSDocumentHighlightArray); virtual;
    function FillHover(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSHover): Boolean; virtual;
    procedure FillInlayHints(AParams: TNXLSInlayHintParams;
      AResult: TNXLSInlayHintArray); virtual;
  end;

implementation

procedure TNXLSEditorService.FillCodeActions(AParams: TNXLSCodeActionParams;
  AResult: TNXLSCodeActionArray);
begin
  if AResult <> nil then
    AResult.Assigned := True;
end;

procedure TNXLSEditorService.FillDocumentHighlights(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSDocumentHighlightArray);
begin
  if AResult <> nil then
    AResult.Assigned := True;
end;

function TNXLSEditorService.FillHover(AParams: TNXLSTextDocumentPositionParams;
  AResult: TNXLSHover): Boolean;
begin
  Result := False;
end;

procedure TNXLSEditorService.FillInlayHints(AParams: TNXLSInlayHintParams;
  AResult: TNXLSInlayHintArray);
begin
  if AResult <> nil then
    AResult.Assigned := True;
end;

end.
