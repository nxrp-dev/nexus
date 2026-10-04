(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBotWorkspace;

{$mode delphi}{$H+}

interface

uses
  Generics.Collections;

type
  TNXBotWorkspaceAccess = class
  private
    FCachePath: string;
    FName: UTF8String;
    FPurpose: UTF8String;
    FRepositoryPath: string;
    FResolvedCommit: UTF8String;
  public
    function Clone: TNXBotWorkspaceAccess;
    property CachePath: string read FCachePath write FCachePath;
    property Name: UTF8String read FName write FName;
    property Purpose: UTF8String read FPurpose write FPurpose;
    property RepositoryPath: string read FRepositoryPath write FRepositoryPath;
    property ResolvedCommit: UTF8String read FResolvedCommit
      write FResolvedCommit;
  end;

  TNXBotWorkspaceAccessList = TObjectList<TNXBotWorkspaceAccess>;

implementation

function TNXBotWorkspaceAccess.Clone: TNXBotWorkspaceAccess;
begin
  Result := TNXBotWorkspaceAccess.Create;
  Result.CachePath := FCachePath;
  Result.Name := FName;
  Result.Purpose := FPurpose;
  Result.RepositoryPath := FRepositoryPath;
  Result.ResolvedCommit := FResolvedCommit;
end;

end.
