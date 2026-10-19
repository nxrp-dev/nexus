(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildEntry;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, obNXPersist, obNXBuildDirectories;

type
  TNXBuildEntry = class(TNXPersistObject)
  private
    FCompilerPath: string;
    FSourceFiles: TStringList;
    FOutputPath: string;
  protected
    procedure ResolvePathList(APaths: TStrings; const ARoot: string);
  public
    constructor Create; override;
    destructor Destroy; override;
    function CompileEachSource: Boolean; virtual;
    function RequiresSources: Boolean; virtual;
    function WorkingDirectory: string; virtual;
    procedure ValidateTarget(const AOS, ACPU: string); virtual;
    procedure AppendEnvironment(APaths: TNXBuildDirectories; AArguments: TStrings;
      var ASourceArgumentIndex: Integer); virtual;
    class procedure InsertPaths(AArguments, APaths: TStrings;
      const APrefix: string; var AIndex: Integer); static;
    class procedure ExpandSourceFiles(ASourceFiles, AExpanded: TStrings); static;
    class function ResolvePath(const APath, ARoot: string): string; static;
    function BuildType: string; virtual; abstract;
    function DefaultCompiler: string; virtual; abstract;
    procedure ResolvePaths(const ARoot: string); virtual;
    procedure AppendArguments(AArguments: TStrings; out ASourceArgumentIndex: Integer); virtual; abstract;
  published
    property CompilerPath: string read FCompilerPath write FCompilerPath;
    property SourceFiles: TStringList read FSourceFiles;
    property OutputPath: string read FOutputPath write FOutputPath;
  end;

implementation

constructor TNXBuildEntry.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FSourceFiles := TStringList.Create;
end;

destructor TNXBuildEntry.Destroy;
begin
  FSourceFiles.Free;
  inherited Destroy;
end;

function TNXBuildEntry.CompileEachSource: Boolean;
begin
  Result := False;
end;

function TNXBuildEntry.RequiresSources: Boolean;
begin
  Result := True;
end;

function TNXBuildEntry.WorkingDirectory: string;
begin
  Result := FOutputPath;
end;

procedure TNXBuildEntry.ValidateTarget(const AOS, ACPU: string);
begin
end;

procedure TNXBuildEntry.AppendEnvironment(APaths: TNXBuildDirectories;
  AArguments: TStrings; var ASourceArgumentIndex: Integer);
begin
end;

class procedure TNXBuildEntry.InsertPaths(AArguments, APaths: TStrings;
  const APrefix: string; var AIndex: Integer);
var
  lPath: string;
begin
  for lPath in APaths do
  begin
    AArguments.Insert(AIndex, APrefix + lPath);
    Inc(AIndex);
  end;
end;

class procedure TNXBuildEntry.ExpandSourceFiles(ASourceFiles, AExpanded: TStrings);
var
  lSource, lDirectory: string;
  lSearch: TSearchRec;
  lStart: Integer;
begin
  AExpanded.Clear;
  for lSource in ASourceFiles do
  begin
    if (Pos('*', lSource) = 0) and (Pos('?', lSource) = 0) then
    begin
      AExpanded.Add(lSource);
      Continue;
    end;
    lDirectory := ExtractFilePath(lSource);
    if (Pos('*', lDirectory) > 0) or (Pos('?', lDirectory) > 0) then
      raise Exception.CreateFmt('Source masks are supported only in filenames: %s.', [lSource]);
    lStart := AExpanded.Count;
    if FindFirst(lSource, faAnyFile, lSearch) = 0 then
    try
      repeat
        if (lSearch.Attr and faDirectory) = 0 then
          AExpanded.Add(lDirectory + lSearch.Name);
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
    if AExpanded.Count = lStart then
      raise Exception.CreateFmt('Source mask matched no files: %s.', [lSource]);
  end;
end;

class function TNXBuildEntry.ResolvePath(const APath, ARoot: string): string;
begin
  if APath = '' then
    Exit('');
  if ARoot = '' then
    Result := ExpandFileName(APath)
  else
    Result := ExpandFileName(APath, ARoot);
end;

procedure TNXBuildEntry.ResolvePathList(APaths: TStrings; const ARoot: string);
var
  lIndex: Integer;
begin
  for lIndex := 0 to APaths.Count - 1 do
    APaths[lIndex] := ResolvePath(APaths[lIndex], ARoot);
end;

procedure TNXBuildEntry.ResolvePaths(const ARoot: string);
begin
  ResolvePathList(FSourceFiles, ARoot);
  if ExtractFilePath(FCompilerPath) <> '' then
    FCompilerPath := ResolvePath(FCompilerPath, ARoot);
  if FOutputPath = '' then
    FOutputPath := ResolvePath('.', ARoot)
  else
    FOutputPath := ResolvePath(FOutputPath, ARoot);
end;

end.
