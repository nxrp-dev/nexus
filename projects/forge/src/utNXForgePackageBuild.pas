(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit utNXForgePackageBuild;

{$mode delphi}{$H+}

interface

uses SysUtils;

function PrepareForgePackageBuild(const ASDKDirectory, AWorkDirectory: string;
  const APackageDirectories: TStringArray): string;
function PublishForgePackageBundle(const AWorkDirectory, AOutputDirectory,
  AName, AKind: string): string;
function ResolveForgePackageBundle(const ADirectory: string): string;

implementation

uses Classes, fpjson, Generics.Collections, tpNXForgePackage,
  obNXForgePackageArtifactReader, utNXForgePackageFiles
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

function ArtifactName(const AName: string): Boolean;
var
  lCharacter: Char;
begin
  Result := False;
  if AName = '' then Exit;
  for lCharacter in AName do
    if not (lCharacter in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '-']) then Exit;
  Result := SameText(ExtractFileExt(AName), '.pcp') or
    SameText(ExtractFileExt(AName), '.dll') or SameText(ExtractFileExt(AName), '.exe');
end;

function SDKArtifactPath(const ARoot, ARelative: string): string;
var
  lPath, lRoot: string;
begin
  if (ARelative = '') or (ExtractFileDrive(ARelative) <> '') or
    IsPathDelimiter(ARelative, 1) then raise Exception.Create('Invalid SDK artifact path');
  lRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARoot));
  lPath := ExpandFileName(lRoot + ARelative);
  if not SameText(Copy(lPath, 1, Length(lRoot)), lRoot) then
    raise Exception.Create('SDK artifact path escapes the SDK: ' + ARelative);
  Result := lPath;
end;

function VerifySDK(const ADirectory: string): string;
var
  lManifest: TJSONObject;
  lFiles: TJSONArray;
  lListed: TStringList;
  lIndex: Integer;
  lPath, lRequired: string;
begin
  lManifest := ReadIdentity(IncludeTrailingPathDelimiter(ADirectory) + 'sdk.json');
  lListed := TStringList.Create;
  try
    if (lManifest.Get('Format', 0) <> 2) or
      (lManifest.Get('Target', '') <> 'x86_64-win64') then
      raise Exception.Create('Requires a Format 2 Win64 package SDK');
    Result := lManifest.Get('SDKIdentity', '');
    RequireHexIdentity(Result, 64);
    lFiles := lManifest.Arrays['Artifacts'];
    for lIndex := 0 to lFiles.Count - 1 do
    begin
      lPath := SDKArtifactPath(ADirectory, lFiles.Objects[lIndex].Get('Path', ''));
      if (lListed.IndexOf(lPath) >= 0) or
        not SameText(FileHash(lPath), lFiles.Objects[lIndex].Get('SHA256', '')) then
        raise Exception.Create('SDK artifact differs from its recorded build: ' + lPath);
      lListed.Add(lPath);
    end;
    for lRequired in ['bin/ppcx64.exe', 'units/sysinitpkg.ppu', 'packages/nxrtl.pcp', 'packages/nxrtl.dll'] do
      if lListed.IndexOf(SDKArtifactPath(ADirectory, lRequired)) < 0 then
        raise Exception.Create('SDK manifest omits required artifact: ' + lRequired);
  finally
    lListed.Free;
    lManifest.Free;
  end;
end;

function ResolveForgePackageBundle(const ADirectory: string): string;
var
  lSelection, lManifest: TJSONObject;
  lFiles: TJSONArray;
  lListed, lActual: TStringList;
  lGeneration, lName, lPath: string;
  lSelected: Boolean;
  lIndex: Integer;
begin
  Result := ExcludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  if not DirectoryExists(Result) then raise Exception.Create('Missing package directory: ' + Result);
  lSelected := FileExists(Result + '/current.json');
  if lSelected then
  begin
    lSelection := ReadIdentity(Result + '/current.json');
    try
      lGeneration := lSelection.Get('Generation', '');
      if (lSelection.Get('Format', 0) <> 1) or (Copy(lGeneration, 1, 11) <> 'generation-') then
        raise Exception.Create('Invalid bundle selection: ' + Result);
      RequireHexIdentity(Copy(lGeneration, 12, MaxInt), 32);
      Result := Result + PathDelim + lGeneration;
    finally
      lSelection.Free;
    end;
  end;
  if not FileExists(Result + '/bundle.json') then
  begin
    if lSelected then raise Exception.Create('Missing package bundle manifest: ' + Result);
    Exit;
  end;
  lManifest := ReadIdentity(Result + '/bundle.json');
  lListed := TStringList.Create;
  lActual := TStringList.Create;
  try
    lFiles := lManifest.Arrays['Files'];
    if (lManifest.Get('Format', 0) <> 1) or (lFiles.Count = 0) then
      raise Exception.Create('Invalid package bundle manifest: ' + Result);
    for lIndex := 0 to lFiles.Count - 1 do
    begin
      lName := lFiles.Objects[lIndex].Get('Name', '');
      if not ArtifactName(lName) or (lListed.IndexOf(lName) >= 0) then
        raise Exception.Create('Invalid or duplicate package bundle artifact: ' + lName);
      if not SameText(FileHash(Result + '/' + lName), lFiles.Objects[lIndex].Get('SHA256', '')) then
        raise Exception.Create('Package bundle artifact differs from its manifest: ' + lName);
      lListed.Add(lName);
    end;
    CollectFiles(Result, False, lActual);
    for lPath in lActual do
    begin
      lName := ExtractFileName(lPath);
      if ArtifactName(lName) and (lListed.IndexOf(lName) < 0) then
        raise Exception.Create('Unlisted package bundle artifact: ' + lName);
    end;
  finally
    lActual.Free;
    lListed.Free;
    lManifest.Free;
  end;
end;

procedure AddInput(AInputs: TStrings; const AName, APath: string);
var
  lIndex: Integer;
begin
  if not ArtifactName(AName) then raise Exception.Create('Invalid package artifact name: ' + AName);
  lIndex := AInputs.IndexOfName(AName);
  if lIndex < 0 then AInputs.Add(AName + '=' + APath)
  else if FileHash(AInputs.ValueFromIndex[lIndex]) <> FileHash(APath) then
    raise Exception.Create('Conflicting package artifacts named ' + AName);
end;

procedure AddDirectory(AInputs: TStrings; const ADirectory, AReplacing: string);
var
  lFiles: TStringList;
  lPath, lName: string;
begin
  lFiles := TStringList.Create;
  try
    CollectFiles(ResolveForgePackageBundle(ADirectory), False, lFiles);
    for lPath in lFiles do
    begin
      lName := ExtractFileName(lPath);
      if not SameText(ExtractFileExt(lName), '.pcp') and
        not SameText(ExtractFileExt(lName), '.dll') then Continue;
      if SameText(ChangeFileExt(lName, ''), AReplacing) then Continue;
      AddInput(AInputs, lName, lPath);
    end;
  finally
    lFiles.Free;
  end;
end;

procedure VerifyPackages(AInputs: TStrings; const ASDK, AOwnName, AOwnBuild: string);
var
  lPackages: TList<TNXForgePackageMetadata>;
  lMetadata, lProvider: TNXForgePackageMetadata;
  lDependency: TNXForgePackageDependency;
  lReader: TNXForgePackageArtifactReader;
  lIndex: Integer;
  lName, lImage: string;
  lFound: Boolean;
begin
  lPackages := TList<TNXForgePackageMetadata>.Create;
  try
    for lIndex := 0 to AInputs.Count - 1 do
    begin
      lName := AInputs.Names[lIndex];
      if SameText(ExtractFileExt(lName), '.dll') and
        (AInputs.IndexOfName(ChangeFileExt(lName, '.pcp')) < 0) then
        raise Exception.Create('Missing package metadata for ' + lName);
      if not SameText(ExtractFileExt(lName), '.pcp') then Continue;
      lReader := TNXForgePackageArtifactReader.Create(AInputs.ValueFromIndex[lIndex]);
      try
        lMetadata := lReader.ReadMetadata;
      finally
        lReader.Free;
      end;
      if not SameText(lMetadata.Name, ChangeFileExt(lName, '')) or (lMetadata.SDK <> ASDK) then
        raise Exception.Create('Incompatible package metadata: ' + lName);
      if SameText(lMetadata.Name, AOwnName) and (lMetadata.Build <> AOwnBuild) then
        raise Exception.Create('Package output does not match the prepared build: ' + lName);
      lImage := AInputs.Values[lMetadata.Name + '.dll'];
      if lImage = '' then raise Exception.Create('Missing package image: ' + lMetadata.Name);
      lReader := TNXForgePackageArtifactReader.Create(lImage);
      try
        lReader.CheckImage(lMetadata.Name, lMetadata.SDK, lMetadata.Build);
      finally
        lReader.Free;
      end;
      lPackages.Add(lMetadata);
    end;
    for lMetadata in lPackages do
      for lDependency in lMetadata.Requires do
      begin
        lFound := False;
        for lProvider in lPackages do
          if SameText(lProvider.Name, lDependency.Name) and (lProvider.Build = lDependency.Build) then
          begin
            lFound := True;
            Break;
          end;
        if not lFound then raise Exception.Create('Dependency build mismatch: ' +
          lMetadata.Name + ' requires ' + lDependency.Name +
          '. Build the replacement distribution in a new output directory.');
      end;
  finally
    lPackages.Free;
  end;
end;

function PrepareForgePackageBuild(const ASDKDirectory, AWorkDirectory: string;
  const APackageDirectories: TStringArray): string;
var
  lSDK, lWork, lIdentity, lBuild, lDirectory, lOptions: string;
  lInputs, lDirectories, lExisting: TStringList;
  lRecord, lFile: TJSONObject;
  lFiles: TJSONArray;
  lIndex: Integer;
begin
  lSDK := ExcludeTrailingPathDelimiter(ExpandFileName(ASDKDirectory));
  lWork := ExcludeTrailingPathDelimiter(ExpandFileName(AWorkDirectory));
  lIdentity := VerifySDK(lSDK);
  lInputs := TStringList.Create;
  lDirectories := TStringList.Create;
  lExisting := TStringList.Create;
  lRecord := TJSONObject.Create;
  try
    lDirectories.Add(ResolveForgePackageBundle(lSDK + '/packages'));
    for lDirectory in APackageDirectories do lDirectories.Add(ResolveForgePackageBundle(lDirectory));
    for lDirectory in lDirectories do AddDirectory(lInputs, lDirectory, '');
    VerifyPackages(lInputs, lIdentity, '', '');
    if DirectoryExists(lWork) then
    begin
      CollectFiles(lWork, True, lExisting);
      if lExisting.Count <> 0 then raise Exception.Create('Package work directory must be empty: ' + lWork);
    end;
    lBuild := NewPackageBuildIdentity;
    lOptions := '-Fj' + lIdentity + #10 + '-Fk' + lBuild + #10 + '-Fu' + lSDK + '/units' + #10;
    for lDirectory in lDirectories do
      lOptions := lOptions + '-Fp' + lDirectory + #10 + '-Fl' + lDirectory + #10;
    lRecord.Add('Format', 1);
    lRecord.Add('SDK', lIdentity);
    lRecord.Add('Build', lBuild);
    lFiles := TJSONArray.Create;
    lRecord.Add('Inputs', lFiles);
    for lIndex := 0 to lInputs.Count - 1 do
    begin
      lFile := TJSONObject.Create;
      lFiles.Add(lFile);
      lFile.Add('Name', lInputs.Names[lIndex]);
      lFile.Add('Path', lInputs.ValueFromIndex[lIndex]);
      lFile.Add('SHA256', FileHash(lInputs.ValueFromIndex[lIndex]));
    end;
    if not ForceDirectories(lWork) then raise Exception.Create('Cannot create package work directory: ' + lWork);
    WriteText(lWork + '/package.cfg', lOptions);
    WriteText(lWork + '/package-build.json', lRecord.AsJSON + #10);
  finally
    lRecord.Free;
    lExisting.Free;
    lDirectories.Free;
    lInputs.Free;
  end;
  Result := 'Prepared package build: ' + lBuild + LineEnding;
end;

procedure CopyArtifact(const ASource, ADestination: string);
var
  lSource, lDestination: TFileStream;
begin
  lSource := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    lDestination := TFileStream.Create(ADestination, fmCreate);
    try
      lDestination.CopyFrom(lSource, 0);
    finally
      lDestination.Free;
    end;
  finally
    lSource.Free;
  end;
end;

procedure SelectGeneration(const ADirectory, AGeneration: string);
var
  lPending, lCurrent: string;
begin
  lPending := ADirectory + '/' + AGeneration + '.json';
  lCurrent := ADirectory + '/current.json';
  WriteText(lPending, '{"Format":1,"Generation":"' + AGeneration + '"}' + #10);
  {$IFDEF MSWINDOWS}
  if not MoveFileExW(PWideChar(UnicodeString(lPending)), PWideChar(UnicodeString(lCurrent)),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;
  {$ELSE}
  if not RenameFile(lPending, lCurrent) then RaiseLastOSError;
  {$ENDIF}
end;

function PublishForgePackageBundle(const AWorkDirectory, AOutputDirectory,
  AName, AKind: string): string;
var
  lWork, lOutput, lSDK, lBuild, lName, lPath, lGeneration, lDirectory, lOwnName: string;
  lInputs: TStringList;
  lRecord, lManifest, lFile: TJSONObject;
  lFiles, lPublished: TJSONArray;
  lIndex: Integer;
  lPackage: Boolean;
begin
  if not ArtifactName(AName + '.pcp') or (AName = '.') or (AName = '..') then
    raise Exception.Create('Invalid package/application name: ' + AName);
  lPackage := SameText(AKind, 'Package');
  if not lPackage and not SameText(AKind, 'Console') and not SameText(AKind, 'GUI') then
    raise Exception.Create('Package bundle Kind must be Package, Console or GUI');
  lWork := ExcludeTrailingPathDelimiter(ExpandFileName(AWorkDirectory));
  lOutput := ExcludeTrailingPathDelimiter(ExpandFileName(AOutputDirectory));
  lRecord := ReadIdentity(lWork + '/package-build.json');
  lInputs := TStringList.Create;
  lManifest := TJSONObject.Create;
  try
    if lRecord.Get('Format', 0) <> 1 then raise Exception.Create('Invalid prepared package build');
    lSDK := lRecord.Get('SDK', '');
    lBuild := lRecord.Get('Build', '');
    RequireHexIdentity(lSDK, 64);
    RequireHexIdentity(lBuild, 32);
    lOwnName := '';
    if lPackage then lOwnName := AName;
    lFiles := lRecord.Arrays['Inputs'];
    for lIndex := 0 to lFiles.Count - 1 do
    begin
      lName := lFiles.Objects[lIndex].Get('Name', '');
      lPath := lFiles.Objects[lIndex].Get('Path', '');
      if FileHash(lPath) <> lFiles.Objects[lIndex].Get('SHA256', '') then
        raise Exception.Create('Package input changed during compilation: ' + lPath);
      if not SameText(ChangeFileExt(lName, ''), lOwnName) then AddInput(lInputs, lName, lPath);
    end;
    if lPackage then
    begin
      if FileExists(lOutput + '/current.json') then AddDirectory(lInputs, lOutput, AName);
      AddInput(lInputs, AName + '.pcp', lWork + '/' + AName + '.pcp');
      AddInput(lInputs, AName + '.dll', lWork + '/' + AName + '.dll');
    end
    else AddInput(lInputs, AName + '.exe', lWork + '/' + AName + '.exe');
    VerifyPackages(lInputs, lSDK, lOwnName, lBuild);
    lGeneration := 'generation-' + LowerCase(NewPackageBuildIdentity);
    lDirectory := lOutput + '/' + lGeneration;
    if not ForceDirectories(lDirectory) then raise Exception.Create('Cannot create package generation: ' + lDirectory);
    lManifest.Add('Format', 1);
    lManifest.Add('SDK', lSDK);
    lPublished := TJSONArray.Create;
    lManifest.Add('Files', lPublished);
    lInputs.Sort;
    for lIndex := 0 to lInputs.Count - 1 do
    begin
      lName := lInputs.Names[lIndex];
      if not lPackage and SameText(ExtractFileExt(lName), '.pcp') then Continue;
      lPath := lDirectory + '/' + lName;
      CopyArtifact(lInputs.ValueFromIndex[lIndex], lPath);
      lFile := TJSONObject.Create;
      lPublished.Add(lFile);
      lFile.Add('Name', lName);
      lFile.Add('SHA256', FileHash(lPath));
    end;
    WriteText(lDirectory + '/bundle.json', lManifest.AsJSON + #10);
    SelectGeneration(lOutput, lGeneration);
  finally
    lManifest.Free;
    lInputs.Free;
    lRecord.Free;
  end;
  Result := 'Published ' + AKind + ' ' + AName + ': ' + lDirectory + LineEnding;
end;

end.
