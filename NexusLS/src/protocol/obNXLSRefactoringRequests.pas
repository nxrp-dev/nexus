unit obNXLSRefactoringRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentRenameRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentPrepareRenameRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentLinkedEditingRangeRequest = class(TNXJSONRPCRequest)
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

class function TNXLSTextDocumentRenameRequest.GetFactoryName: string;
begin
  Result := 'textDocument/rename';
end;

class function TNXLSTextDocumentRenameRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSRenameParams;
end;

function TNXLSTextDocumentRenameRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Refactoring.Rename(TNXLSRenameParams(params));
end;

class function TNXLSTextDocumentPrepareRenameRequest.GetFactoryName: string;
begin
  Result := 'textDocument/prepareRename';
end;

class function TNXLSTextDocumentPrepareRenameRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentPrepareRenameRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Refactoring.PrepareRename(TNXLSTextDocumentPositionParams(params));
end;

class function TNXLSTextDocumentLinkedEditingRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/linkedEditingRange';
end;

class function TNXLSTextDocumentLinkedEditingRangeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentLinkedEditingRangeRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/linkedEditingRange; required: Optional; original server: No; category: refactoring; result: TNXLSLinkedEditingRangesResult.
  Result := TNXLSLinkedEditingRangesResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentRenameRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareRenameRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentLinkedEditingRangeRequest);

end.
