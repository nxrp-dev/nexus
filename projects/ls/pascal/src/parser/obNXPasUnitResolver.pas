(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPasUnitResolver;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXPasSearchPaths;

type
  TNXPasUnitResolver = class
  public
    function LocateUnitFile(const AUnitName: string; ALocalPaths: TStrings;
      out AFileName: string): Boolean; virtual; abstract;
  end;

  TNXPasSearchPathUnitResolver = class(TNXPasUnitResolver)
  private
    FSearchPathContext: TNXPasSearchPathContext;
  public
    constructor Create(ASearchPathContext: TNXPasSearchPathContext);
    function LocateUnitFile(const AUnitName: string; ALocalPaths: TStrings;
      out AFileName: string): Boolean; override;

    property SearchPathContext: TNXPasSearchPathContext
      read FSearchPathContext;
  end;

implementation

uses
  obNXPasUnitLocator;

constructor TNXPasSearchPathUnitResolver.Create(
  ASearchPathContext: TNXPasSearchPathContext);
begin
  inherited Create;
  FSearchPathContext := ASearchPathContext;
end;

function TNXPasSearchPathUnitResolver.LocateUnitFile(const AUnitName: string;
  ALocalPaths: TStrings; out AFileName: string): Boolean;
begin
  Result := TNXPasUnitLocator.FindUnitFile(AUnitName, ALocalPaths, AFileName);
  if Result then
    Exit;

  if FSearchPathContext = nil then
    Exit(False);

  Result := TNXPasUnitLocator.FindUnitFile(AUnitName,
    FSearchPathContext.UnitPaths, AFileName);
end;

end.
