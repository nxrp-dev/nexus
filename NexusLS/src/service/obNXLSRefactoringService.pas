unit obNXLSRefactoringService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSRefactoringService = class(TNXLSLSPService)
  public
    function Rename(AParams: TNXLSRenameParams): TNXJSONValue; virtual;
    function PrepareRename(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
  end;

implementation

uses
  obNXLSProtocolObjects;

function TNXLSRefactoringService.Rename(AParams: TNXLSRenameParams): TNXJSONValue;
begin
  Result := TNXLSWorkspaceEditResult.CreateValue;
end;

function TNXLSRefactoringService.PrepareRename(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSPrepareRenameResult.CreateValue;
end;

end.
