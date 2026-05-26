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

function TNXLSWorkspaceApplyEditRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/applyEdit; required: Client-side; original server: No; category: workspace edit; result: TNXLSApplyWorkspaceEditResult.
  Result := TNXLSApplyWorkspaceEditResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceApplyEditRequest);

end.
