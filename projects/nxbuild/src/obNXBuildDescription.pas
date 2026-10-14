(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildDescription;

{$mode objfpc}{$H+}

interface

uses obNXPersist, obNXBuildEntry;

type
  TNXBuildDescription = class(TNXPersistObject)
  private
    FKind: string;
    FFileName: string;
    FRootDirectory: string;
    FSourceRoot: string;
    FOutputRoot: string;
    FBuilds: TNXPersistList;
  public
    constructor Create; override;
    destructor Destroy; override;
    function ResolvePath(const APath: string): string;
    procedure ResolvePaths;
    property Kind: string read FKind write FKind;
    property FileName: string read FFileName write FFileName;
  published
    property RootDirectory: string read FRootDirectory write FRootDirectory;
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property OutputRoot: string read FOutputRoot write FOutputRoot;
    property Builds: TNXPersistList read FBuilds;
  end;

implementation

constructor TNXBuildDescription.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FBuilds := TNXPersistList.Create;
end;

destructor TNXBuildDescription.Destroy;
begin
  FBuilds.Free;
  inherited Destroy;
end;

function TNXBuildDescription.ResolvePath(const APath: string): string;
begin
  Result := TNXBuildEntry.ResolvePath(APath, FRootDirectory);
end;

procedure TNXBuildDescription.ResolvePaths;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FBuilds.Count - 1 do
    (FBuilds[lIndex] as TNXBuildEntry).ResolvePaths(FRootDirectory);
end;

end.
