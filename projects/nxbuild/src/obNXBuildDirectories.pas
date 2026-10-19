(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildDirectories;

{$mode objfpc}{$H+}

interface

uses Classes, obNXPersist;

type
  TNXBuildDirectories = class(TNXPersistObject)
  private
    FSources: TStringList;
    FHeaders: TStringList;
    FObjects: TStringList;
    FLibraries: TStringList;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure ResolvePaths(const ARoot: string);
    procedure Include(ADirectories: TNXBuildDirectories);
  published
    property Sources: TStringList read FSources;
    property Headers: TStringList read FHeaders;
    property Objects: TStringList read FObjects;
    property Libraries: TStringList read FLibraries;
  end;

implementation

uses SysUtils;

procedure IncludePaths(ADestination, ASource: TStrings);
var
  lPath, lExisting: string;
  lFound: Boolean;
begin
  for lPath in ASource do
  begin
    lFound := False;
    for lExisting in ADestination do
      if SameFileName(lPath, lExisting) then
      begin
        lFound := True;
        Break;
      end;
    if not lFound then ADestination.Add(lPath);
  end;
end;

constructor TNXBuildDirectories.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FSources := TStringList.Create;
  FHeaders := TStringList.Create;
  FObjects := TStringList.Create;
  FLibraries := TStringList.Create;
end;

destructor TNXBuildDirectories.Destroy;
begin
  FLibraries.Free;
  FObjects.Free;
  FHeaders.Free;
  FSources.Free;
  inherited Destroy;
end;

procedure ResolveDirectoryPaths(APaths: TStrings; const ARoot: string);
var
  lIndex: Integer;
begin
  for lIndex := 0 to APaths.Count - 1 do
  begin
    if Trim(APaths[lIndex]) = '' then
      raise Exception.Create('Published directories must not be empty.');
    APaths[lIndex] := ExcludeTrailingPathDelimiter(ExpandFileName(APaths[lIndex], ARoot));
  end;
end;

procedure TNXBuildDirectories.ResolvePaths(const ARoot: string);
begin
  ResolveDirectoryPaths(FSources, ARoot);
  ResolveDirectoryPaths(FHeaders, ARoot);
  ResolveDirectoryPaths(FObjects, ARoot);
  ResolveDirectoryPaths(FLibraries, ARoot);
end;

procedure TNXBuildDirectories.Include(ADirectories: TNXBuildDirectories);
begin
  IncludePaths(FSources, ADirectories.Sources);
  IncludePaths(FHeaders, ADirectories.Headers);
  IncludePaths(FObjects, ADirectories.Objects);
  IncludePaths(FLibraries, ADirectories.Libraries);
end;

end.
