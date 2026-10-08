(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupState;

{$mode delphi}{$H+}

interface

uses Classes, Generics.Collections;

type
  TNXSetupInstalledFile = class
  private
    FPath: string;
    FKeep: Boolean;
  public
    constructor Create(const APath: string; AKeep: Boolean);
    property Path: string read FPath;
    property KeepOnUninstall: Boolean read FKeep;
  end;

  { Installation evidence, not declared intent or a compiled script. }
  TNXSetupState = class
  private
    FProductId, FVersion, FRoot: string;
    FFiles: TObjectList<TNXSetupInstalledFile>;
    FDirectories: TStringList;
    FSeeds, FBindings: TStringList;
  public
    constructor Create(const AProductId, AVersion, ARoot: string);
    destructor Destroy; override;
    function FindFile(const APath: string): TNXSetupInstalledFile;
    procedure RecordFile(const APath: string; AKeep: Boolean);
    procedure SaveToStream(AStream: TStream);
    class function LoadFile(const AFileName: string): TNXSetupState; static;
    class function Folder(const ARoot, AProductId: string): string; static;
    property ProductId: string read FProductId;
    property Version: string read FVersion;
    property Root: string read FRoot;
    property Files: TObjectList<TNXSetupInstalledFile> read FFiles;
    property Directories: TStringList read FDirectories;
    property Seeds: TStringList read FSeeds;
    property Bindings: TStringList read FBindings;
  end;

implementation

uses SysUtils, sha1, utNXSetupStreams, utNXSetupFiles, obNXSetupModel;

constructor TNXSetupInstalledFile.Create(const APath: string; AKeep: Boolean);
begin
  inherited Create;
  FPath := APath;
  FKeep := AKeep;
end;

constructor TNXSetupState.Create(const AProductId, AVersion, ARoot: string);
begin
  inherited Create;
  FProductId := AProductId;
  FVersion := AVersion;
  FRoot := ExpandFileName(ARoot);
  FFiles := TObjectList<TNXSetupInstalledFile>.Create(True);
  FDirectories := TStringList.Create;
  FSeeds := TStringList.Create;
  FBindings := TStringList.Create;
end;

destructor TNXSetupState.Destroy;
begin
  FBindings.Free;
  FSeeds.Free;
  FDirectories.Free;
  FFiles.Free;
  inherited Destroy;
end;

class function TNXSetupState.Folder(const ARoot, AProductId: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ARoot)) +
    '.nx' + PathDelim + 'setup' + PathDelim + SHA1Print(SHA1String(AProductId));
end;

function TNXSetupState.FindFile(const APath: string): TNXSetupInstalledFile;
var
  lFile: TNXSetupInstalledFile;
  lPath: string;
begin
  lPath := ExpandFileName(APath);
  for lFile in FFiles do
    if SameFileName(ExpandFileName(lFile.Path), lPath) then Exit(lFile);
  Result := nil;
end;

procedure TNXSetupState.RecordFile(const APath: string; AKeep: Boolean);
var
  lFile: TNXSetupInstalledFile;
begin
  lFile := FindFile(APath);
  if lFile <> nil then lFile.FKeep := AKeep
  else FFiles.Add(TNXSetupInstalledFile.Create(APath, AKeep));
end;

procedure TNXSetupState.SaveToStream(AStream: TStream);
var
  lFile: TNXSetupInstalledFile;
  lDirectory: string;
begin
  WriteText(AStream, 'NXInstall1');
  WriteText(AStream, FProductId);
  WriteText(AStream, FVersion);
  WriteText(AStream, FRoot);
  WriteNumber(AStream, FFiles.Count);
  for lFile in FFiles do
  begin
    WriteText(AStream, lFile.Path);
    WriteNumber(AStream, Ord(lFile.KeepOnUninstall));
  end;
  WriteNumber(AStream, FDirectories.Count);
  for lDirectory in FDirectories do WriteText(AStream, lDirectory);
  WriteNumber(AStream, FSeeds.Count);
  for lDirectory in FSeeds do WriteText(AStream, lDirectory);
  WriteNumber(AStream, FBindings.Count);
  for lDirectory in FBindings do WriteText(AStream, lDirectory);
end;

class function TNXSetupState.LoadFile(const AFileName: string): TNXSetupState;
var
  lStream: TFileStream;
  lState: TNXSetupState;
  lId, lVersion, lRoot, lPath: string;
  lIndex, lCount: Integer;
  lKeep: QWord;
begin
  CheckRegularPath(AFileName);
  lStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  lState := nil;
  try
    if ReadText(lStream) <> 'NXInstall1' then raise EReadError.Create('Unknown installation state format.');
    lId := ReadText(lStream);
    lVersion := ReadText(lStream);
    lRoot := ReadText(lStream);
    lState := TNXSetupState.Create(lId, lVersion, lRoot);
    if not SameFileName(ExtractFileDir(AFileName), Folder(lRoot, lId)) then
      raise ENXSetup.Create('Installation state does not belong to this location.');
    lCount := ReadCount(lStream);
    for lIndex := 1 to lCount do
    begin
      lPath := ReadText(lStream);
      lKeep := ReadNumber(lStream);
      if (lKeep > 1) or (lState.FindFile(lPath) <> nil) then
        raise EReadError.Create('Invalid installed file record.');
      lState.RecordFile(lPath, lKeep = 1);
    end;
    lCount := ReadCount(lStream);
    for lIndex := 1 to lCount do lState.Directories.Add(ReadText(lStream));
    lCount := ReadCount(lStream);
    for lIndex := 1 to lCount do lState.Seeds.Add(ReadText(lStream));
    lCount := ReadCount(lStream);
    for lIndex := 1 to lCount do lState.Bindings.Add(ReadText(lStream));
    RequireEnd(lStream);
    Result := lState;
    lState := nil;
  finally
    lState.Free;
    lStream.Free;
  end;
end;

end.
