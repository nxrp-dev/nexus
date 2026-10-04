(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPasSource;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  tpNXPasTokens;

type
  TNXPasSourceRange = record
    StartPos: TNXPasSourcePosition;
    EndPos: TNXPasSourcePosition;
  end;

  TNXPasSourceFile = class
  private
    FDefines: TStringList;
    FFileName: string;
    FText: string;
    FURI: string;
  public
    constructor Create(const AFileName, AURI, AText: string);
    destructor Destroy; override;
    function RangeFromPositions(const AStartPos,
      AEndPos: TNXPasSourcePosition): TNXPasSourceRange;

    property Defines: TStringList read FDefines;
    property FileName: string read FFileName write FFileName;
    property URI: string read FURI write FURI;
    property Text: string read FText write FText;
  end;

  TNXPasInactiveRegion = class
  private
    FRange: TNXPasSourceRange;
  public
    property Range: TNXPasSourceRange read FRange write FRange;
  end;

  TNXPasInactiveRegionList = class(TObjectList)
  public
    function AddRegion(const ARange: TNXPasSourceRange): TNXPasInactiveRegion;
    function RegionAt(AIndex: Integer): TNXPasInactiveRegion;
  end;

implementation

uses
  SysUtils;

constructor TNXPasSourceFile.Create(const AFileName, AURI, AText: string);
begin
  inherited Create;
  FDefines := TStringList.Create;
  FDefines.CaseSensitive := False;
  FFileName := AFileName;
  FURI := AURI;
  FText := AText;
end;

destructor TNXPasSourceFile.Destroy;
begin
  FreeAndNil(FDefines);
  inherited Destroy;
end;

function TNXPasSourceFile.RangeFromPositions(const AStartPos,
  AEndPos: TNXPasSourcePosition): TNXPasSourceRange;
begin
  Result.StartPos := AStartPos;
  Result.EndPos := AEndPos;
end;

function TNXPasInactiveRegionList.AddRegion(
  const ARange: TNXPasSourceRange): TNXPasInactiveRegion;
begin
  Result := TNXPasInactiveRegion.Create;
  Result.Range := ARange;
  Add(Result);
end;

function TNXPasInactiveRegionList.RegionAt(
  AIndex: Integer): TNXPasInactiveRegion;
begin
  Result := TNXPasInactiveRegion(Items[AIndex]);
end;

end.
