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
    class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentLinkedEditingRangeRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
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

class function TNXLSTextDocumentPrepareRenameRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSPrepareRenamePlaceholder;
end;

class function TNXLSTextDocumentPrepareRenameRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
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

class function TNXLSTextDocumentLinkedEditingRangeRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSLinkedEditingRanges;
end;

class function TNXLSTextDocumentLinkedEditingRangeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentLinkedEditingRangeRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/linkedEditingRange; required: Optional; original server: No; category: refactoring; result: TNXLSLinkedEditingRangesResult.
  Result := TNXJSONNull.Create;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentRenameRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareRenameRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentLinkedEditingRangeRequest);

end.
