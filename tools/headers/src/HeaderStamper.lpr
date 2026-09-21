program HeaderStamper;

{$mode objfpc}{$H+}

uses
  SysUtils,
  Classes;

type
  TSourceKind = (
    skPascal,
    skCpp,
    skJavaScript,
    skLua,
    skPythonShell,
    skXml,
    skCss,
    skSql,
    skMarkdown,
    skMustache,
    skNexusScript,
    skUnknown
  );

var
  GRoot: string = '';
  GLicenseFile: string = '';
  GDryRun: Boolean = False;

function TrimQuotes(const S: string): string;
begin
  Result := S;
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function PathClean(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '/', PathDelim, [rfReplaceAll]);
end;

function SourceKindFromExt(const AExt: string): TSourceKind;
begin
  case LowerCase(AExt) of
    '.pas', '.pp', '.inc', '.lpr', '.lpi', '.lpk': Result := skPascal;
    '.c', '.h', '.hpp', '.hh', '.cc', '.cpp', '.cxx': Result := skCpp;
    '.js', '.ts', '.jsx', '.tsx': Result := skJavaScript;
    '.lua': Result := skLua;
    '.py', '.sh', '.bash', '.zsh', '.pl', '.rb', '.php': Result := skPythonShell;
    '.xml', '.xaml', '.html', '.htm', '.svg': Result := skXml;
    '.css', '.scss', '.sass': Result := skCss;
    '.sql': Result := skSql;
    '.md', '.markdown': Result := skMarkdown;
    '.mustache', '.mst': Result := skMustache;
    '.nxscript': Result := skNexusScript;
  else
    Result := skUnknown;
  end;
end;

function SourceKindName(const K: TSourceKind): string;
begin
  case K of
    skPascal: Result := 'Pascal';
    skCpp: Result := 'C/C++';
    skJavaScript: Result := 'JavaScript/TypeScript';
    skLua: Result := 'Lua';
    skPythonShell: Result := 'Python/Shell';
    skXml: Result := 'XML/HTML';
    skCss: Result := 'CSS';
    skSql: Result := 'SQL';
    skMarkdown: Result := 'Markdown';
    skMustache: Result := 'Mustache';
    skNexusScript: Result := 'NexusScript';
  else
    Result := 'Unknown';
  end;
end;

function FileContainsLicenseHeader(const FileName: string): Boolean;
var
  S: TStringList;
  I: Integer;
begin
  Result := False;
  if not FileExists(FileName) then
    Exit;

  S := TStringList.Create;
  try
    S.LoadFromFile(FileName);
    for I := 0 to S.Count - 1 do
      if Pos('Copyright', S[I]) > 0 then
      begin
        Result := True;
        Break;
      end;
  finally
    S.Free;
  end;
end;

function HeaderForKind(const K: TSourceKind): string;
var
  Lines: TStringList;
  I: Integer;
  S: string;
begin
  Lines := TStringList.Create;
  try
    case K of
      skPascal:
      begin
        Lines.Add('(*');
        Lines.Add(' * Copyright (c) 2026 Kevin Collins.');
        Lines.Add(' *');
        Lines.Add(' * Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add(' * You may obtain a copy of the License at:');
        Lines.Add(' * https://mozilla.org/MPL/2.0/');
        Lines.Add(' *');
        Lines.Add(' * Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add(' * This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add(' * Secondary License through the MPL secondary-license mechanism.');
        Lines.Add(' *');
        Lines.Add(' * This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add(' * as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add(' *');
        Lines.Add(' * SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
        Lines.Add(' *)');
      end;

      skCpp:
      begin
        Lines.Add('/*');
        Lines.Add(' * Copyright (c) 2026 Kevin Collins.');
        Lines.Add(' *');
        Lines.Add(' * Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add(' * You may obtain a copy of the License at:');
        Lines.Add(' * https://mozilla.org/MPL/2.0/');
        Lines.Add(' *');
        Lines.Add(' * Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add(' * This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add(' * Secondary License through the MPL secondary-license mechanism.');
        Lines.Add(' *');
        Lines.Add(' * This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add(' * as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add(' *');
        Lines.Add(' * SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
        Lines.Add(' */');
      end;

      skJavaScript:
      begin
        Lines.Add('/*');
        Lines.Add(' * Copyright (c) 2026 Kevin Collins.');
        Lines.Add(' *');
        Lines.Add(' * Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add(' * You may obtain a copy of the License at:');
        Lines.Add(' * https://mozilla.org/MPL/2.0/');
        Lines.Add(' *');
        Lines.Add(' * Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add(' * This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add(' * Secondary License through the MPL secondary-license mechanism.');
        Lines.Add(' *');
        Lines.Add(' * This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add(' * as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add(' *');
        Lines.Add(' * SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
        Lines.Add(' */');
      end;

      skLua:
      begin
        Lines.Add('-- Copyright (c) 2026 Kevin Collins.');
        Lines.Add('--');
        Lines.Add('-- Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add('-- You may obtain a copy of the License at:');
        Lines.Add('-- https://mozilla.org/MPL/2.0/');
        Lines.Add('--');
        Lines.Add('-- Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add('-- This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add('-- Secondary License through the MPL secondary-license mechanism.');
        Lines.Add('--');
        Lines.Add('-- This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add('-- as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add('--');
        Lines.Add('-- SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
      end;

      skPythonShell:
      begin
        Lines.Add('# Copyright (c) 2026 Kevin Collins.');
        Lines.Add('#');
        Lines.Add('# Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add('# You may obtain a copy of the License at:');
        Lines.Add('# https://mozilla.org/MPL/2.0/');
        Lines.Add('#');
        Lines.Add('# Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add('# This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add('# Secondary License through the MPL secondary-license mechanism.');
        Lines.Add('#');
        Lines.Add('# This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add('# as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add('#');
        Lines.Add('# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
      end;

      skXml:
      begin
        Lines.Add('<!--');
        Lines.Add('  Copyright (c) 2026 Kevin Collins.');
        Lines.Add('  ');
        Lines.Add('  Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add('  You may obtain a copy of the License at:');
        Lines.Add('  https://mozilla.org/MPL/2.0/');
        Lines.Add('  ');
        Lines.Add('  Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add('  This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add('  Secondary License through the MPL secondary-license mechanism.');
        Lines.Add('  ');
        Lines.Add('  This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add('  as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add('  ');
        Lines.Add('  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
        Lines.Add('-->');
      end;

      skCss:
      begin
        Lines.Add('/*');
        Lines.Add(' * Copyright (c) 2026 Kevin Collins.');
        Lines.Add(' *');
        Lines.Add(' * Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add(' * You may obtain a copy of the License at:');
        Lines.Add(' * https://mozilla.org/MPL/2.0/');
        Lines.Add(' *');
        Lines.Add(' * Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add(' * This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add(' * Secondary License through the MPL secondary-license mechanism.');
        Lines.Add(' *');
        Lines.Add(' * This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add(' * as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add(' *');
        Lines.Add(' * SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
        Lines.Add(' */');
      end;

      skSql:
      begin
        Lines.Add('-- Copyright (c) 2026 Kevin Collins.');
        Lines.Add('--');
        Lines.Add('-- Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add('-- You may obtain a copy of the License at:');
        Lines.Add('-- https://mozilla.org/MPL/2.0/');
        Lines.Add('--');
        Lines.Add('-- Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add('-- This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add('-- Secondary License through the MPL secondary-license mechanism.');
        Lines.Add('--');
        Lines.Add('-- This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add('-- as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add('--');
        Lines.Add('-- SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
      end;

      skMarkdown:
      begin
        Lines.Add('<!--');
        Lines.Add('Copyright (c) 2026 Kevin Collins.');
        Lines.Add('');
        Lines.Add('Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add('You may obtain a copy of the License at:');
        Lines.Add('https://mozilla.org/MPL/2.0/');
        Lines.Add('');
        Lines.Add('Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add('This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add('Secondary License through the MPL secondary-license mechanism.');
        Lines.Add('');
        Lines.Add('This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add('as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add('');
        Lines.Add('SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
        Lines.Add('-->');
      end;

      skMustache:
      begin
        Lines.Add('{{!');
        Lines.Add('Copyright (c) 2026 Kevin Collins.');
        Lines.Add('');
        Lines.Add('Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add('You may obtain a copy of the License at:');
        Lines.Add('https://mozilla.org/MPL/2.0/');
        Lines.Add('');
        Lines.Add('Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add('This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add('Secondary License through the MPL secondary-license mechanism.');
        Lines.Add('');
        Lines.Add('This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add('as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add('');
        Lines.Add('SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
        Lines.Add('}}');
      end;

      skNexusScript:
      begin
        Lines.Add('// Copyright (c) 2026 Kevin Collins.');
        Lines.Add('//');
        Lines.Add('// Licensed under the Mozilla Public License, Version 2.0.');
        Lines.Add('// You may obtain a copy of the License at:');
        Lines.Add('// https://mozilla.org/MPL/2.0/');
        Lines.Add('//');
        Lines.Add('// Modifications to this Source Code Form remain subject to MPL-2.0.');
        Lines.Add('// This code may not be relicensed under the GPL, LGPL, AGPL, or other');
        Lines.Add('// Secondary License through the MPL secondary-license mechanism.');
        Lines.Add('//');
        Lines.Add('// This Source Code Form is "Incompatible With Secondary Licenses",');
        Lines.Add('// as defined by the Mozilla Public License, v. 2.0.');
        Lines.Add('//');
        Lines.Add('// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception');
      end;
    end;

    Lines.Add('');
    Result := '';
    for I := 0 to Lines.Count - 1 do
      Result := Result + Lines[I] + LineEnding;
  finally
    Lines.Free;
  end;
end;

procedure StampFile(const FileName: string; const Kind: TSourceKind);
var
  Content: string;
  Header: string;
  OutFile: string;
  SL: TStringList;
  InputName: string;
begin
  if FileContainsLicenseHeader(FileName) then
    Exit;

  Header := HeaderForKind(Kind);
  SL := TStringList.Create;
  try
    if FileExists(FileName) then
    begin
      SL.LoadFromFile(FileName);
      if SL.Count > 0 then
        SL.Insert(0, '');
      SL.Insert(0, Header);
      OutFile := FileName + '.new';
      SL.SaveToFile(OutFile);
      if not GDryRun then
      begin
        DeleteFile(FileName);
        RenameFile(OutFile, FileName);
      end
      else
        DeleteFile(OutFile);
    end;
  finally
    SL.Free;
  end;
end;

procedure ScanFolder(const DirName: string);
var
  SearchRec: TSearchRec;
  FileName: string;
  NewDir: string;
  Kind: TSourceKind;
  Ext: string;
begin
  if FindFirst(DirName + PathDelim + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if ((SearchRec.Attr and faDirectory) <> 0) and
         (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and
         (SearchRec.Name <> '.git') and (SearchRec.Name <> '.svn') then
      begin
        NewDir := DirName + PathDelim + SearchRec.Name;
        ScanFolder(NewDir);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  if FindFirst(DirName + PathDelim + '*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if ((SearchRec.Attr and faDirectory) = 0) then
      begin
        FileName := DirName + PathDelim + SearchRec.Name;
        Ext := ExtractFileExt(FileName);
        Kind := SourceKindFromExt(Ext);
        if Kind = skUnknown then
          Continue;
        if not FileContainsLicenseHeader(FileName) then
        begin
          WriteLn('Stamping ' + FileName + ' [' + SourceKindName(Kind) + ']');
          if not GDryRun then
            StampFile(FileName, Kind)
          else
            WriteLn('DRYRUN ' + FileName);
        end;
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

procedure PrintUsage;
begin
  WriteLn('Usage: HeaderStamper <folder> [--dry-run]');
  WriteLn('Example: HeaderStamper C:\gitdev\nexus --dry-run');
end;

begin
  if ParamCount = 0 then
  begin
    PrintUsage;
    Halt(1);
  end;

  GRoot := ExpandFileName(TrimQuotes(ParamStr(1)));
  if not DirectoryExists(GRoot) then
  begin
    WriteLn('Folder does not exist: ' + GRoot);
    Halt(2);
  end;

  if ParamCount >= 2 then
  begin
    if ParamStr(2) = '--dry-run' then
      GDryRun := True;
  end;

  WriteLn('Scanning: ' + GRoot);
  ScanFolder(GRoot);
end.
