unit obNXLSWorkspaceEditRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWorkspaceApplyEditRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSWorkspaceApplyEditRequest.GetFactoryName: string;
begin
  Result := 'workspace/applyEdit';
end;

class function TNXLSWorkspaceApplyEditRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSApplyWorkspaceEditParams;
end;

class function TNXLSWorkspaceApplyEditRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSApplyWorkspaceEditResultValue;
end;

function TNXLSWorkspaceApplyEditRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSApplyWorkspaceEditResultValue;
begin
  lResult := TNXLSApplyWorkspaceEditResultValue(PrepareResult);
  lResult.applied.Value := False;
  lResult.Assigned := True;
  Result := lResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceApplyEditRequest);

end.
