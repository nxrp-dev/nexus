unit obNXLSWorkspaceEditRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXLSProtocolObjects,
  obNXLSProtocolParams;

type
  TNXLSWorkspaceApplyEditRequest = class(TNXJSONRPCOutboundCommand)
  private
    Fparams: TNXLSApplyWorkspaceEditParams;
  public
    class function GetFactoryName: string; override;
    class function GetResultClass: TNXJSONCommandResultClass; override;
  published
    property params: TNXLSApplyWorkspaceEditParams read Fparams write Fparams;
  end;

implementation

uses
  obNXClassFactory;

class function TNXLSWorkspaceApplyEditRequest.GetFactoryName: string;
begin
  Result := 'workspace/applyEdit';
end;

class function TNXLSWorkspaceApplyEditRequest.GetResultClass: TNXJSONCommandResultClass;
begin
  Result := TNXLSApplyWorkspaceEditResultValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceApplyEditRequest);

end.
