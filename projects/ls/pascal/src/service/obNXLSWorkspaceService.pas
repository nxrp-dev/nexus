(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSWorkspaceService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSWorkspaceService = class(TNXLSLSPService)
  public
    procedure DidChangeConfiguration(AParams: TNXLSDidChangeConfigurationParams); virtual;
    procedure DidChangeWorkspaceFolders(AParams: TNXLSDidChangeWorkspaceFoldersParams); virtual;
  end;

implementation

procedure TNXLSWorkspaceService.DidChangeConfiguration(AParams: TNXLSDidChangeConfigurationParams);
begin
end;

procedure TNXLSWorkspaceService.DidChangeWorkspaceFolders(AParams: TNXLSDidChangeWorkspaceFoldersParams);
begin
  if (AParams = nil) or (AParams.event = nil) then
    Exit;

  Model.AddWorkspaceFolders(AParams.event.added);
  Model.RemoveWorkspaceFolders(AParams.event.removed);
  Model.RebuildWorkspaceIndex;
end;

end.
