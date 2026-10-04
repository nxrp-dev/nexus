(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPasProject;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  obNXPasSource;

type
  TNXPasProject = class
  private
    FName: string;
    FRootPath: string;
    FSourceFiles: TObjectList;
    FUnitPaths: TStringList;
    function GetSourceFile(AIndex: Integer): TNXPasSourceFile;
  public
    constructor Create;
    destructor Destroy; override;

    function AddSourceFile(const AFileName, AURI, AText: string): TNXPasSourceFile;
    function SourceFileCount: Integer;

    property Name: string read FName write FName;
    property RootPath: string read FRootPath write FRootPath;
    property SourceFiles[AIndex: Integer]: TNXPasSourceFile read GetSourceFile;
    property UnitPaths: TStringList read FUnitPaths;
  end;

implementation

uses
  SysUtils;

constructor TNXPasProject.Create;
begin
  inherited Create;
  FSourceFiles := TObjectList.Create(True);
  FUnitPaths := TStringList.Create;
end;

destructor TNXPasProject.Destroy;
begin
  FreeAndNil(FUnitPaths);
  FreeAndNil(FSourceFiles);
  inherited Destroy;
end;

function TNXPasProject.GetSourceFile(AIndex: Integer): TNXPasSourceFile;
begin
  Result := TNXPasSourceFile(FSourceFiles[AIndex]);
end;

function TNXPasProject.AddSourceFile(const AFileName, AURI,
  AText: string): TNXPasSourceFile;
begin
  Result := TNXPasSourceFile.Create(AFileName, AURI, AText);
  FSourceFiles.Add(Result);
end;

function TNXPasProject.SourceFileCount: Integer;
begin
  Result := FSourceFiles.Count;
end;

end.
