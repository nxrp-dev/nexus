(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit utNXBuildTargets;
{$mode objfpc}{$H+}
interface
uses obNexusScriptModel;
procedure AddNXBuildTargets(const AText: string; ATargets: TNexusScriptTargetSelection);
implementation
uses Classes, SysUtils;
procedure AddNXBuildTargets(const AText: string; ATargets: TNexusScriptTargetSelection);
var
  lParts: TStringList;
  lPart, lName, lValue: string;
  lColon: Integer;
begin
  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := ',';
    lParts.DelimitedText := AText;
    for lPart in lParts do
    begin
      lColon := Pos(':', lPart);
      lName := Trim(Copy(lPart, 1, lColon - 1));
      lValue := Copy(lPart, lColon + 1, MaxInt);
      if (lColon <= 1) or (lName = '') or (Trim(lValue) = '') then
        raise Exception.Create('Target selections require Name:Value.');
      ATargets.Add(lName, lValue);
    end;
  finally
    lParts.Free;
  end;
end;
end.
