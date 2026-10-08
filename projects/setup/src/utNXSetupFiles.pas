(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit utNXSetupFiles;

{$mode delphi}{$H+}

interface

uses Classes;

procedure CheckRegularPath(const APath: string);
procedure CopySetupFile(const ASource, ADestination: string);
procedure CopySetupPermissions(const ASource, ADestination: string);
procedure ReplaceSetupFile(const ASource, ADestination: string);
procedure RemoveSetupFile(const AFileName: string);
procedure CollectSetupTree(const AFolder, ARelative: string; AFiles, ADirectories: TStrings);
function SetupWorkFolder(const ABase: string): string;
procedure RemoveSetupTree(const AFolder: string);
function FileNeedsReplacement(const ASource, ADestination: string;
  APreserveExisting, AIgnoreVersion, ARepair: Boolean): Boolean;

implementation

uses SysUtils, obNXSetupModel, FileInfo, resource, versiontypes,
  winpeimagereader, elfreader, machoreader
  {$ifdef windows}, Windows{$else}, BaseUnix{$endif};

procedure CheckRegularPath(const APath: string);
var
  lPath, lParent: string;
  {$ifdef windows}lAttributes: DWORD;{$else}lStat: Stat;{$endif}
begin
  lPath := ExpandFileName(APath);
  repeat
    {$ifdef windows}
    lAttributes := GetFileAttributesW(PWideChar(UnicodeString(lPath)));
    if (lAttributes <> INVALID_FILE_ATTRIBUTES) and
      ((lAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
      raise ENXSetup.Create('Setup does not follow reparse points: ' + lPath);
    {$else}
    if (fpLStat(lPath, lStat) = 0) and FPS_ISLNK(lStat.st_mode) then
      raise ENXSetup.Create('Setup does not follow symbolic links: ' + lPath);
    {$endif}
    lParent := ExtractFileDir(ExcludeTrailingPathDelimiter(lPath));
    if (lParent = '') or SameFileName(lPath, lParent) then Break;
    lPath := lParent;
  until False;
end;

procedure CopySetupFile(const ASource, ADestination: string);
var
  lInput, lOutput: TFileStream;
begin
  lInput := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    lOutput := TFileStream.Create(ADestination, fmCreate);
    try
      lOutput.CopyFrom(lInput, 0);
    finally
      lOutput.Free;
    end;
    if FileSetDate(ADestination, FileAge(ASource)) <> 0 then
      raise ENXSetup.Create('Cannot set installed file timestamp: ' + ADestination);
    CopySetupPermissions(ASource, ADestination);
  finally
    lInput.Free;
  end;
end;

procedure CopySetupPermissions(const ASource, ADestination: string);
{$ifndef windows}var lStat: Stat;{$endif}
begin
  {$ifndef windows}
  if (fpStat(ASource, lStat) <> 0) or (fpChmod(ADestination, lStat.st_mode and &777) <> 0) then
    raise ENXSetup.Create('Cannot preserve executable permissions: ' + ADestination);
  {$endif}
end;

procedure ReplaceSetupFile(const ASource, ADestination: string);
begin
  {$ifdef windows}
  if not MoveFileExW(PWideChar(UnicodeString(ASource)),
    PWideChar(UnicodeString(ADestination)), MOVEFILE_REPLACE_EXISTING) then
    RaiseLastOSError;
  {$else}
  if not RenameFile(ASource, ADestination) then RaiseLastOSError;
  {$endif}
end;

procedure RemoveSetupFile(const AFileName: string);
begin
  CheckRegularPath(AFileName);
  if FileExists(AFileName) and not SysUtils.DeleteFile(AFileName) then
    raise ENXSetup.Create('Cannot remove file: ' + AFileName);
end;

procedure CollectSetupTree(const AFolder, ARelative: string; AFiles, ADirectories: TStrings);
var
  lSearch: TSearchRec;
  lFolder, lRelative: string;
  lEntries: TStringList;
  lName: string;
begin
  lFolder := IncludeTrailingPathDelimiter(AFolder) + ARelative;
  CheckRegularPath(lFolder);
  if not DirectoryExists(lFolder) then raise ENXSetup.Create('Payload directory is missing: ' + lFolder);
  ADirectories.Add(ARelative);
  lEntries := TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(lFolder) + '*', faAnyFile, lSearch) = 0 then
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') then lEntries.Add(lSearch.Name);
      until FindNext(lSearch) <> 0;
    finally
      SysUtils.FindClose(lSearch);
    end;
    lEntries.Sort;
    for lName in lEntries do
    begin
      lRelative := IncludeTrailingPathDelimiter(ARelative) + lName;
      if ARelative = '' then lRelative := lName;
      CheckRegularPath(IncludeTrailingPathDelimiter(AFolder) + lRelative);
      if DirectoryExists(IncludeTrailingPathDelimiter(AFolder) + lRelative) then
        CollectSetupTree(AFolder, lRelative, AFiles, ADirectories)
      else AFiles.Add(lRelative);
    end;
  finally
    lEntries.Free;
  end;
end;

function SetupWorkFolder(const ABase: string): string;
var
  lGuid: TGUID;
begin
  CreateGUID(lGuid);
  Result := IncludeTrailingPathDelimiter(ABase) + 'nxsetup-' + GUIDToString(lGuid);
  CheckRegularPath(Result);
  if not CreateDir(Result) then raise ENXSetup.Create('Cannot create work directory: ' + Result);
end;

procedure RemoveSetupTree(const AFolder: string);
var
  lFiles, lDirectories: TStringList;
  lIndex: Integer;
begin
  if not DirectoryExists(AFolder) then Exit;
  lFiles := TStringList.Create;
  lDirectories := TStringList.Create;
  try
    CollectSetupTree(AFolder, '', lFiles, lDirectories);
    for lIndex := 0 to lFiles.Count - 1 do
      RemoveSetupFile(IncludeTrailingPathDelimiter(AFolder) + lFiles[lIndex]);
    for lIndex := lDirectories.Count - 1 downto 0 do
      if not RemoveDir(IncludeTrailingPathDelimiter(AFolder) + lDirectories[lIndex]) then
        raise ENXSetup.Create('Cannot remove work directory: ' + lDirectories[lIndex]);
  finally
    lDirectories.Free;
    lFiles.Free;
  end;
end;

function ReadVersion(const AFileName: string; out AVersion: QWord): Boolean;
var
  lInfo: TVersionInfo;
  lVersion: TFileProductVersion;
  lIndex: Integer;
begin
  Result := False;
  AVersion := 0;
  lInfo := TVersionInfo.Create;
  try
    try
      lInfo.Load(AFileName);
      lVersion := lInfo.FixedInfo.FileVersion;
      for lIndex := 0 to 3 do AVersion := (AVersion shl 16) or lVersion[lIndex];
      Result := True;
    except
      on lError: EVersionInfo do Result := False;
      on lError: EResourceReaderNotFoundException do Result := False;
    end;
  finally
    lInfo.Free;
  end;
end;

function FileNeedsReplacement(const ASource, ADestination: string;
  APreserveExisting, AIgnoreVersion, ARepair: Boolean): Boolean;
var
  lSourceVersion, lDestinationVersion: QWord;
  lSourceHasVersion: Boolean;
begin
  if not FileExists(ADestination) then Exit(True);
  if APreserveExisting then Exit(False);
  if AIgnoreVersion then Exit(True);
  lSourceHasVersion := ReadVersion(ASource, lSourceVersion);
  if not ReadVersion(ADestination, lDestinationVersion) then Exit(True);
  Result := lSourceHasVersion and ((lSourceVersion > lDestinationVersion) or
    (ARepair and (lSourceVersion = lDestinationVersion)));
end;

end.
