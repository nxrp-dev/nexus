unit obNXLSRefactoringService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext;

type
  TNXLSRefactoringService = class(TNXLSLSPService)
  public
    function FillRename(AParams: TNXLSRenameParams;
      AResult: TNXLSWorkspaceEdit): Boolean; virtual;
    function FillPrepareRename(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSPrepareRenamePlaceholder): Boolean; virtual;
  end;

implementation

function TNXLSRefactoringService.FillRename(AParams: TNXLSRenameParams;
  AResult: TNXLSWorkspaceEdit): Boolean;
begin
  Result := False;
end;

function TNXLSRefactoringService.FillPrepareRename(
  AParams: TNXLSTextDocumentPositionParams;
  AResult: TNXLSPrepareRenamePlaceholder): Boolean;
begin
  Result := False;
end;

end.
