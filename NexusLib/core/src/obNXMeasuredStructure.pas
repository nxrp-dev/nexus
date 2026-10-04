(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXMeasuredStructure;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  TypInfo,
  Variants;

type
  TNXStructureMetrics = class(TPersistent)
  private
    FStructureName: string;
    FItemCount: QWord;
    FInitMilliseconds: QWord;
    FOperationalBytes: QWord;
    FTemporaryBuildBytes: QWord;

  published
    property StructureName: string read FStructureName write FStructureName;
    property ItemCount: QWord read FItemCount write FItemCount;
    property InitMilliseconds: QWord read FInitMilliseconds write FInitMilliseconds;
    property OperationalBytes: QWord read FOperationalBytes write FOperationalBytes;
    property TemporaryBuildBytes: QWord read FTemporaryBuildBytes write FTemporaryBuildBytes;
  end;

function NXMetricsToJSON(const AMetrics: TNXStructureMetrics): string;

implementation

function NXJSONEscape(const AText: string): string;
var
  lIndex: SizeInt;
  lChar: Char;
begin
  Result := '';

  for lIndex := 1 to Length(AText) do
  begin
    lChar := AText[lIndex];

    case lChar of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      '/': Result := Result + '\/';
      #8: Result := Result + '\b';
      #9: Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
    else
      if Ord(lChar) < 32 then
        Result := Result + '\u' + IntToHex(Ord(lChar), 4)
      else
        Result := Result + lChar;
    end;
  end;
end;

function NXVariantToJSON(const AValue: Variant): string;
var
  lKind: TVarType;
begin
  lKind := VarType(AValue) and VarTypeMask;

  case lKind of
    varEmpty, varNull:
      Result := 'null';

    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord, varInt64:
      Result := VarToStr(AValue);

    varSingle, varDouble, varCurrency:
      Result := VarToStr(AValue);

    varBoolean:
      if AValue then
        Result := 'true'
      else
        Result := 'false';

  else
    Result := '"' + NXJSONEscape(VarToStr(AValue)) + '"';
  end;
end;

function NXMetricsToJSON(const AMetrics: TNXStructureMetrics): string;
var
  lCount: Integer;
  lIndex: Integer;
  lList: PPropList;
  lName: string;
  lValue: Variant;
begin
  Result := '{}';

  if AMetrics = nil then
    Exit;

  lCount := GetPropList(AMetrics.ClassInfo, lList);

  if lCount <= 0 then
    Exit;

  try

    Result := '{';

    for lIndex := 0 to lCount - 1 do
    begin
      lName := String(lList^[lIndex]^.Name);
      lValue := GetPropValue(AMetrics, lName, True);

      if lIndex > 0 then
        Result := Result + ',';

      Result := Result + '"' + NXJSONEscape(lName) + '":' + NXVariantToJSON(lValue);
    end;

    Result := Result + '}';
  finally
    FreeMem(lList);
  end;
end;

end.
