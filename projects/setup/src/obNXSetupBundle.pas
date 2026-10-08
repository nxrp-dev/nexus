(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupBundle;

{$mode delphi}{$H+}

interface

uses Classes, Generics.Collections, obNXSetupModel, obNXSetupSourceContext;

type
  { Owns one isolated extraction directory and the original source snapshot. }
  TNXSetupBundle = class
  private
    FFolder, FArchive: string;
    FContext: TNXSetupSourceContext;
    FPayloads: TDictionary<string, string>;
    procedure Unpack;
    constructor Create;
  public
    destructor Destroy; override;
    class procedure Build(ADocument: TNXSetupDocument;
      const ARuntime, AOutput: string); static;
    class function HasPayload(const AExecutable: string): Boolean; static;
    class function OpenExecutable(const AExecutable: string): TNXSetupBundle; static;
    class function OpenArchive(const AArchive: string): TNXSetupBundle; static;
    function LoadDocument: TNXSetupDocument;
    property ArchiveFile: string read FArchive;
    property Payloads: TDictionary<string, string> read FPayloads;
  end;

implementation

uses SysUtils, zipper, tpNXSetup, obNXSetupLoader, obNXSetupLocations,
  utNXSetupPaths, utNXSetupStreams, utNXSetupFiles;

const
  cTailMagic: array[0..7] of Char = ('N', 'X', 'S', 'T', 'A', 'I', 'L', '1');
  cTailSize = 32;

function ReadTail(AStream: TStream; out AOffset, ASize: Int64): Boolean;
var
  lMagic: array[0..7] of Char;
  lOffset, lSize, lVersion: QWord;
begin
  Result := False;
  if AStream.Size < cTailSize then Exit;
  AStream.Position := AStream.Size - SizeOf(lMagic);
  AStream.ReadBuffer(lMagic, SizeOf(lMagic));
  if CompareByte(lMagic, cTailMagic, SizeOf(lMagic)) <> 0 then Exit;
  AStream.Position := AStream.Size - cTailSize;
  lVersion := ReadNumber(AStream);
  lOffset := ReadNumber(AStream);
  lSize := ReadNumber(AStream);
  if (lVersion <> 1) or (lOffset > QWord(AStream.Size - cTailSize)) or
    (lSize <> QWord(AStream.Size - cTailSize) - lOffset) or (lSize = 0) then
    raise ENXSetup.Create('Invalid Setup executable footer.');
  AOffset := lOffset;
  ASize := lSize;
  Result := True;
end;

constructor TNXSetupBundle.Create;
begin
  inherited Create;
  FPayloads := TDictionary<string, string>.Create;
  FFolder := SetupWorkFolder(GetTempDir(False));
  FArchive := IncludeTrailingPathDelimiter(FFolder) + 'payload.zip';
end;

destructor TNXSetupBundle.Destroy;
begin
  FPayloads.Free;
  FContext.Free;
  if FFolder <> '' then RemoveSetupTree(FFolder);
  inherited Destroy;
end;

class function TNXSetupBundle.HasPayload(const AExecutable: string): Boolean;
var
  lStream: TFileStream;
  lOffset, lSize: Int64;
begin
  lStream := TFileStream.Create(AExecutable, fmOpenRead or fmShareDenyWrite);
  try Result := ReadTail(lStream, lOffset, lSize); finally lStream.Free; end;
end;

function PayloadSource(APayload: TNXSetupPayload): string;
begin
  if IsAbsolutePath(APayload.Source) then Result := ExpandFileName(APayload.Source)
  else Result := ExpandFileName(IncludeTrailingPathDelimiter(
    ExtractFileDir(APayload.Declaration.SourceRange.SourceName)) + APayload.Source);
end;

class procedure TNXSetupBundle.Build(ADocument: TNXSetupDocument;
  const ARuntime, AOutput: string);
var
  lZip: TZipper;
  lContext, lMap: TMemoryStream;
  lRuntime, lArchive, lOutput: TFileStream;
  lFeature: TNXSetupFeature;
  lPayload: TNXSetupPayload;
  lFiles, lDirectories, lSources: TStringList;
  lWork, lZipFile, lOutputFile, lSource, lMember, lRelative: string;
  lOffset, lSize: Int64;
begin
  if ADocument.SourceContext = nil then raise ENXSetup.Create('Installer construction requires original sources.');
  if SameFileName(ExpandFileName(ARuntime), ExpandFileName(AOutput)) then
    raise ENXSetup.Create('Installer output cannot replace its runtime input.');
  if HasPayload(ARuntime) then raise ENXSetup.Create('Use the unbundled Setup runtime as input.');
  CheckRegularPath(AOutput);
  lZip := TZipper.Create;
  lContext := TMemoryStream.Create;
  lMap := TMemoryStream.Create;
  lFiles := TStringList.Create;
  lDirectories := TStringList.Create;
  lSources := TStringList.Create;
  lWork := '';
  try
    lWork := SetupWorkFolder(GetTempDir(False));
    lZipFile := IncludeTrailingPathDelimiter(lWork) + 'payload.zip';
    ADocument.SourceContext.SaveToStream(lContext);
    lContext.Position := 0;
    lZip.Entries.AddFileEntry(lContext, 'source');
    for lFeature in ADocument.Features do
      for lPayload in lFeature.Files do
      begin
        lSource := PayloadSource(lPayload);
        if lSources.IndexOf(lSource) >= 0 then Continue;
        CheckRegularPath(lSource);
        lMember := 'payload/' + IntToStr(lSources.Count);
        lSources.Add(lSource);
        WriteText(lMap, lSource);
        if lPayload.Kind = spkFile then
        begin
          if not FileExists(lSource) then raise ENXSetup.Create('Payload is missing: ' + lSource);
          lMember := lMember + '/file';
          lZip.Entries.AddFileEntry(lSource, lMember);
        end
        else
        begin
          lFiles.Clear;
          lDirectories.Clear;
          CollectSetupTree(lSource, '', lFiles, lDirectories);
          for lRelative in lDirectories do
            lZip.Entries.AddFileEntry(ExcludeTrailingPathDelimiter(
              IncludeTrailingPathDelimiter(lSource) + lRelative),
              ExcludeTrailingPathDelimiter(lMember + '/' +
                StringReplace(lRelative, PathDelim, '/', [rfReplaceAll])) + '/');
          for lRelative in lFiles do
            lZip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(lSource) + lRelative,
              lMember + '/' + StringReplace(lRelative, PathDelim, '/', [rfReplaceAll]));
        end;
        WriteText(lMap, lMember);
      end;
    { Prefix the map with its format/count without materializing any payload bytes. }
    lOutput := TFileStream.Create(IncludeTrailingPathDelimiter(lWork) + 'map', fmCreate);
    try
      WriteText(lOutput, 'NXPayload1');
      WriteNumber(lOutput, lSources.Count);
      lMap.Position := 0;
      lOutput.CopyFrom(lMap, lMap.Size);
    finally
      lOutput.Free;
    end;
    lZip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(lWork) + 'map', 'map');
    lZip.FileName := lZipFile;
    lZip.ZipAllFiles;
    if not ForceDirectories(ExtractFileDir(ExpandFileName(AOutput))) then
      raise ENXSetup.Create('Cannot create installer output directory.');
    lOutputFile := IncludeTrailingPathDelimiter(lWork) + 'installer';
    lOutput := TFileStream.Create(lOutputFile, fmCreate);
    try
      lRuntime := TFileStream.Create(ARuntime, fmOpenRead or fmShareDenyWrite);
      try lOutput.CopyFrom(lRuntime, lRuntime.Size); finally lRuntime.Free; end;
      lOffset := lOutput.Position;
      lArchive := TFileStream.Create(lZipFile, fmOpenRead or fmShareDenyWrite);
      try
        lSize := lArchive.Size;
        lOutput.CopyFrom(lArchive, lSize);
      finally
        lArchive.Free;
      end;
      WriteNumber(lOutput, 1);
      WriteNumber(lOutput, lOffset);
      WriteNumber(lOutput, lSize);
      lOutput.WriteBuffer(cTailMagic, SizeOf(cTailMagic));
    finally
      lOutput.Free;
    end;
    { Stage on the destination volume, then publish the complete artifact. }
    lSource := AOutput + '.nxnew';
    if FileExists(lSource) then raise ENXSetup.Create('Installer staging file already exists: ' + lSource);
    try
      CopySetupFile(lOutputFile, lSource);
      CopySetupPermissions(ARuntime, lSource);
      ReplaceSetupFile(lSource, AOutput);
    finally
      RemoveSetupFile(lSource);
    end;
  finally
    lZip.Free;
    lSources.Free;
    lDirectories.Free;
    lFiles.Free;
    lMap.Free;
    lContext.Free;
    if lWork <> '' then RemoveSetupTree(lWork);
  end;
end;

function MemberPath(const ABase, AMember: string): string;
var
  lMember: string;
  lParts: TStringList;
  lPart: string;
begin
  lMember := StringReplace(AMember, '\', '/', [rfReplaceAll]);
  if (lMember <> 'source') and (lMember <> 'map') and
    (Copy(lMember, 1, 8) <> 'payload/') then
    raise ENXSetup.Create('Unknown installer archive member: ' + AMember);
  if (lMember = '') or (lMember[1] = '/') or (Pos(':', lMember) > 0) then
    raise ENXSetup.Create('Invalid archive member: ' + AMember);
  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := '/';
    lParts.DelimitedText := lMember;
    for lPart in lParts do
      if (lPart = '..') or (lPart = '.') then raise ENXSetup.Create('Archive member escapes payload.');
  finally
    lParts.Free;
  end;
  Result := TNXSetupLocations.RelativePath(ABase,
    StringReplace(lMember, '/', PathDelim, [rfReplaceAll]));
end;

procedure TNXSetupBundle.Unpack;
var
  lZip: TUnZipper;
  lStream: TFileStream;
  lIndex, lCount: Integer;
  lMember, lPath, lOriginal: string;
  lSeen: TStringList;
begin
  lZip := TUnZipper.Create;
  lSeen := TStringList.Create;
  try
    lZip.FileName := FArchive;
    lZip.Examine;
    for lIndex := 0 to lZip.Entries.Count - 1 do
    begin
      lPath := MemberPath(FFolder, lZip.Entries[lIndex].ArchiveFileName);
      if lZip.Entries[lIndex].IsLink then raise ENXSetup.Create('Installer archive contains a symbolic link.');
      if lSeen.IndexOf(lPath) >= 0 then raise ENXSetup.Create('Installer archive has duplicate members.');
      lSeen.Add(lPath);
    end;
    lZip.OutputPath := FFolder;
    lZip.UnZipAllFiles;
    lStream := TFileStream.Create(IncludeTrailingPathDelimiter(FFolder) + 'source',
      fmOpenRead or fmShareDenyWrite);
    try
      FContext := TNXSetupSourceContext.LoadFromStream(lStream);
    finally
      lStream.Free;
    end;
    lStream := TFileStream.Create(IncludeTrailingPathDelimiter(FFolder) + 'map',
      fmOpenRead or fmShareDenyWrite);
    try
      if ReadText(lStream) <> 'NXPayload1' then raise EReadError.Create('Unknown Setup payload map.');
      lCount := ReadCount(lStream);
      for lIndex := 1 to lCount do
      begin
        lOriginal := ReadText(lStream);
        lMember := ReadText(lStream);
        if Pos('payload/', lMember) <> 1 then raise EReadError.Create('Invalid payload location.');
        lPath := MemberPath(FFolder, lMember);
        if not FileExists(lPath) and not DirectoryExists(lPath) then
          raise ENXSetup.Create('Mapped payload is missing: ' + lMember);
        FPayloads.Add(lOriginal, lPath);
      end;
      RequireEnd(lStream);
    finally
      lStream.Free;
    end;
  finally
    lSeen.Free;
    lZip.Free;
  end;
end;

class function TNXSetupBundle.OpenExecutable(const AExecutable: string): TNXSetupBundle;
var
  lBundle: TNXSetupBundle;
  lInput, lOutput: TFileStream;
  lOffset, lSize: Int64;
begin
  lBundle := TNXSetupBundle.Create;
  try
    lInput := TFileStream.Create(AExecutable, fmOpenRead or fmShareDenyWrite);
    try
      if not ReadTail(lInput, lOffset, lSize) then raise ENXSetup.Create('Executable has no Setup payload.');
      lInput.Position := lOffset;
      lOutput := TFileStream.Create(lBundle.FArchive, fmCreate);
      try lOutput.CopyFrom(lInput, lSize); finally lOutput.Free; end;
    finally
      lInput.Free;
    end;
    lBundle.Unpack;
    Result := lBundle;
    lBundle := nil;
  finally
    lBundle.Free;
  end;
end;

class function TNXSetupBundle.OpenArchive(const AArchive: string): TNXSetupBundle;
var
  lBundle: TNXSetupBundle;
begin
  lBundle := TNXSetupBundle.Create;
  try
    CopySetupFile(AArchive, lBundle.FArchive);
    lBundle.Unpack;
    Result := lBundle;
    lBundle := nil;
  finally
    lBundle.Free;
  end;
end;

function TNXSetupBundle.LoadDocument: TNXSetupDocument;
begin
  Result := TNXSetupLoader.LoadFile(FContext.EntryName, FContext, FContext.Targets);
end;

end.
