(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupLocations;

{$mode delphi}{$H+}

interface

uses Classes, Generics.Collections, obNXSetupModel;

type
  { A platform/scenario caller supplies physical paths for semantic kinds. }
  TNXSetupLocations = class
  private
    FBindings: TDictionary<string, string>;
    function ResolvePath(ALocation: TNXSetupLocation;
      AActive: TList<TNXSetupLocation>): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Bind(const AKind, APath: string);
    procedure SaveBindings(AValues: TStrings);
    procedure LoadBindings(AValues: TStrings);
    function Resolve(ALocation: TNXSetupLocation): string;
    class function RelativePath(const ABase, APath: string): string; static;
  end;

implementation

uses SysUtils, utNXSetupPaths;

constructor TNXSetupLocations.Create;
begin
  inherited Create;
  FBindings := TDictionary<string, string>.Create;
end;

destructor TNXSetupLocations.Destroy;
begin
  FBindings.Free;
  inherited Destroy;
end;

procedure TNXSetupLocations.Bind(const AKind, APath: string);
begin
  if not IsAbsolutePath(APath) then raise ENXSetup.Create('Location binding must be absolute.');
  FBindings.AddOrSetValue(LowerCase(AKind), ExpandFileName(APath));
end;

procedure TNXSetupLocations.SaveBindings(AValues: TStrings);
var
  lKind: string;
begin
  AValues.Clear;
  for lKind in FBindings.Keys do AValues.Add(lKind + '=' + FBindings[lKind]);
end;

procedure TNXSetupLocations.LoadBindings(AValues: TStrings);
var
  lIndex: Integer;
begin
  for lIndex := 0 to AValues.Count - 1 do
    Bind(AValues.Names[lIndex], AValues.ValueFromIndex[lIndex]);
end;

class function TNXSetupLocations.RelativePath(const ABase, APath: string): string;
var
  lBase: string;
begin
  if IsAbsolutePath(APath) then
    raise ENXSetup.Create('Absolute destination representation is not specified.');
  lBase := IncludeTrailingPathDelimiter(ExpandFileName(ABase));
  Result := ExpandFileName(lBase + APath);
  if not SameFileName(ExcludeTrailingPathDelimiter(lBase), Result) and
    not SameFileName(lBase, Copy(Result, 1, Length(lBase))) then
    raise ENXSetup.Create('Relative destination escapes its logical location.');
end;

function TNXSetupLocations.ResolvePath(ALocation: TNXSetupLocation;
  AActive: TList<TNXSetupLocation>): string;
begin
  if AActive.IndexOf(ALocation) >= 0 then
    raise ENXSetup.Create('Derived location has no concrete base: ' + ALocation.Declaration.Name);
  AActive.Add(ALocation);
  try
    if SameText(ALocation.Kind, 'Derived') then
      Result := ResolvePath(ALocation.Base, AActive)
    else if not FBindings.TryGetValue(LowerCase(ALocation.Kind), Result) then
      raise ENXSetup.Create('No platform/scenario binding for ' + ALocation.Kind);
    Result := RelativePath(Result, ALocation.Path);
  finally
    AActive.Delete(AActive.Count - 1);
  end;
end;

function TNXSetupLocations.Resolve(ALocation: TNXSetupLocation): string;
var
  lActive: TList<TNXSetupLocation>;
begin
  lActive := TList<TNXSetupLocation>.Create;
  try
    Result := ResolvePath(ALocation, lActive);
  finally
    lActive.Free;
  end;
end;

end.
