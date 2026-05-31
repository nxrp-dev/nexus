unit obNXLSRefactoringRequests;

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
  TNXLSTextDocumentRenameRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSWorkspaceEditResult;
    procedure SetResult(AValue: TNXLSWorkspaceEditResult);
    function GetParams: TNXLSRenameParams;
    procedure SetParams(AValue: TNXLSRenameParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSWorkspaceEditResult read GetResult write SetResult;
    property params: TNXLSRenameParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentPrepareRenameRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSPrepareRenamePlaceholder;
    procedure SetResult(AValue: TNXLSPrepareRenamePlaceholder);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSPrepareRenamePlaceholder read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentLinkedEditingRangeRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSLinkedEditingRanges;
    procedure SetResult(AValue: TNXLSLinkedEditingRanges);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSLinkedEditingRanges read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  tpNXLS;

class function TNXLSTextDocumentRenameRequest.GetFactoryName: string;
begin
  Result := 'textDocument/rename';
end;

class function TNXLSTextDocumentRenameRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentRenameRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSWorkspaceEditResult;
begin
  lResult := TNXLSWorkspaceEditResult(PrepareResult);
  if TNXLSLSPModel.Current.Refactoring.FillRename(TNXLSRenameParams(params),
    lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSTextDocumentPrepareRenameRequest.GetFactoryName: string;
begin
  Result := 'textDocument/prepareRename';
end;

class function TNXLSTextDocumentPrepareRenameRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentPrepareRenameRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSPrepareRenamePlaceholder;
begin
  lResult := TNXLSPrepareRenamePlaceholder(PrepareResult);
  if TNXLSLSPModel.Current.Refactoring.FillPrepareRename(
    TNXLSTextDocumentPositionParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSTextDocumentLinkedEditingRangeRequest.GetFactoryName: string;
begin
  Result := 'textDocument/linkedEditingRange';
end;

class function TNXLSTextDocumentLinkedEditingRangeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentLinkedEditingRangeRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/linkedEditingRange; required: Optional; original server: No; category: refactoring; result: TNXLSLinkedEditingRangesResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentRenameRequest.GetParams: TNXLSRenameParams;
begin
  Result := TNXLSRenameParams(inherited params);
end;

procedure TNXLSTextDocumentRenameRequest.SetParams(AValue: TNXLSRenameParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentLinkedEditingRangeRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentLinkedEditingRangeRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentPrepareRenameRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentPrepareRenameRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentRenameRequest.GetResult: TNXLSWorkspaceEditResult;
begin
  Result := TNXLSWorkspaceEditResult(inherited result);
end;

procedure TNXLSTextDocumentRenameRequest.SetResult(AValue: TNXLSWorkspaceEditResult);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentPrepareRenameRequest.GetResult: TNXLSPrepareRenamePlaceholder;
begin
  Result := TNXLSPrepareRenamePlaceholder(inherited result);
end;

procedure TNXLSTextDocumentPrepareRenameRequest.SetResult(AValue: TNXLSPrepareRenamePlaceholder);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentLinkedEditingRangeRequest.GetResult: TNXLSLinkedEditingRanges;
begin
  Result := TNXLSLinkedEditingRanges(inherited result);
end;

procedure TNXLSTextDocumentLinkedEditingRangeRequest.SetResult(AValue: TNXLSLinkedEditingRanges);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentRenameRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareRenameRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentLinkedEditingRangeRequest);

end.
