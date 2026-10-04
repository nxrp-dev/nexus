(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSRefactoringService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext;

type
  TNXLSRefactoringService = class(TNXLSLSPService)
  public
    function FillRename(AParams: TNXLSRenameParams;
      AResult: TNXLSWorkspaceEdit): Boolean; virtual;
    function FillPrepareRename(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSPrepareRenamePlaceholder): Boolean; virtual;
  end;

implementation

function TNXLSRefactoringService.FillRename(AParams: TNXLSRenameParams;
  AResult: TNXLSWorkspaceEdit): Boolean;
begin
  Result := False;
end;

function TNXLSRefactoringService.FillPrepareRename(
  AParams: TNXLSTextDocumentPositionParams;
  AResult: TNXLSPrepareRenamePlaceholder): Boolean;
begin
  Result := False;
end;

end.
