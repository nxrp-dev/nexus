(*
  Copyright (c) 2026 Kevin Collins.
  
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  
  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.
  
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

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
    function GetResult: TNXLSApplyWorkspaceEditResultValue;
    procedure SetParams(AValue: TNXLSApplyWorkspaceEditParams);
    procedure SetResult(AValue: TNXLSApplyWorkspaceEditResultValue);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXLSApplyWorkspaceEditParams read GetParams write SetParams;
    property result: TNXLSApplyWorkspaceEditResultValue read GetResult write SetResult;
  end;

implementation

uses
  obNXClassFactory;

class function TNXLSWorkspaceApplyEditRequest.GetFactoryName: string;
begin
  Result := 'workspace/applyEdit';
end;

function TNXLSWorkspaceApplyEditRequest.GetParams: TNXLSApplyWorkspaceEditParams;
begin
  Result := TNXLSApplyWorkspaceEditParams(inherited params);
end;

function TNXLSWorkspaceApplyEditRequest.GetResult: TNXLSApplyWorkspaceEditResultValue;
begin
  Result := TNXLSApplyWorkspaceEditResultValue(inherited result);
end;

procedure TNXLSWorkspaceApplyEditRequest.SetParams(AValue: TNXLSApplyWorkspaceEditParams);
begin
  inherited params := AValue;
end;

procedure TNXLSWorkspaceApplyEditRequest.SetResult(AValue: TNXLSApplyWorkspaceEditResultValue);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceApplyEditRequest);

end.
