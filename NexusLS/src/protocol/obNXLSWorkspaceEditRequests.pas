unit obNXLSWorkspaceEditRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSDocumentSyncParams,
  obNXLSProtocolBase,
  obNXLSProtocolObjects,
  obNXLSProtocolParams;

type
  TNXLSWorkspaceApplyEditRequest = class(TNXJSONRPCOutboundCommand)
  private
    function GetParams: TNXLSApplyWorkspaceEditParams;
    procedure SetParams(AValue: TNXLSApplyWorkspaceEditParams);
  public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONCommandResultClass; override;
  published
    property params: TNXLSApplyWorkspaceEditParams read GetParams write SetParams;
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

function TNXLSWorkspaceApplyEditRequest.GetParams: TNXLSApplyWorkspaceEditParams;
begin
  Result := TNXLSApplyWorkspaceEditParams(inherited params);
end;

procedure TNXLSWorkspaceApplyEditRequest.SetParams(AValue: TNXLSApplyWorkspaceEditParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceApplyEditRequest);

end.
