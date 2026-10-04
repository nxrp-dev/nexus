(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSFileWatchingRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSWorkspaceDidChangeWatchedFilesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDidChangeWatchedFilesParams;
    procedure SetParams(AValue: TNXLSDidChangeWatchedFilesParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDidChangeWatchedFilesParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetFactoryName: string;
begin
  Result := 'workspace/didChangeWatchedFiles';
end;

class function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWorkspaceDidChangeWatchedFilesRequest.Execute: TNXJSONRPCValue;
begin
  // Method: workspace/didChangeWatchedFiles; required: Optional; original server: No; category: file watching; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSWorkspaceDidChangeWatchedFilesRequest.GetParams: TNXLSDidChangeWatchedFilesParams;
begin
  Result := TNXLSDidChangeWatchedFilesParams(inherited params);
end;

procedure TNXLSWorkspaceDidChangeWatchedFilesRequest.SetParams(AValue: TNXLSDidChangeWatchedFilesParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDidChangeWatchedFilesRequest);

end.
