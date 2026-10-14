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
  {$IFDEF MSWINDOWS}, Windows{$ENDIF}{$IFDEF UNIX}, BaseUnix{$ENDIF};

function ArtifactName(const AName: string): Boolean;
var
  lCharacter: Char;
begin
  Result := False;
  if (AName = '') or (AName = '.') or (AName = '..') then Exit;
  for lCharacter in AName do
    if not (lCharacter in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '-']) then Exit;
  Result := SameText(ExtractFileExt(AName), '.nxp') or
    SameText(ExtractFileExt(AName), '.dll') or SameText(ExtractFileExt(AName), '.exe') or
    (ExtractFileExt(AName) = '.so') or (ExtractFileExt(AName) = '');
end;

function PackageImageName(const AName, ATarget: string): string;
begin
  if ATarget = 'x86_64-linux-gnu' then Result := 'lib' + AName + '.so'
  else Result := AName + '.dll';
end;

function SDKArtifactPath(const ARoot, ARelative: string): string;
var
  lPath, lRoot: string;
begin
  if (ARelative = '') or (ExtractFileDrive(ARelative) <> '') or
    IsPathDelimiter(ARelative, 1) then raise Exception.Create('Invalid SDK artifact path');
  lRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARoot));
  lPath := ExpandFileName(lRoot + ARelative);
  {$IFDEF MSWINDOWS}
  if not SameText(Copy(lPath, 1, Length(lRoot)), lRoot) then
  {$ELSE}
  if Copy(lPath, 1, Length(lRoot)) <> lRoot then
  {$ENDIF}
    raise Exception.Create('SDK artifact path escapes the SDK: ' + ARelative);
  Result := lPath;
end;

function VerifySDK(const ADirectory: string; out ATarget: string): string;
var
  lManifest: TJSONObject;
  lFiles: TJSONArray;
  lListed: TStringList;
  lIndex: Integer;
  lPath, lRequired, lCompiler, lArtifacts, lPathKey, lHashKey: string;
begin
  lManifest := ReadIdentity(IncludeTrailingPathDelimiter(ADirectory) + 'sdk.json');
  lListed := TStringList.Create;
  try
    ATarget := lManifest.Get('Target', lManifest.Get('target', ''));
    if ATarget = 'x86_64-linux-gnu' then
    begin
      if lManifest.Get('format', 0) <> 2 then raise Exception.Create('Requires a Format 2 Linux package SDK');
      Result := lManifest.Get('sdk_identity', '');
      lCompiler := 'bin/ppcx64';
      lArtifacts := 'artifacts';
      lPathKey := 'path';
      lHashKey := 'sha256';
    end
    else
    begin
      if (ATarget <> 'x86_64-win64') or (lManifest.Get('Format', 0) <> 2) then
        raise Exception.Create('Requires a Format 2 Win64 or Linux x86-64 package SDK');
      Result := lManifest.Get('SDKIdentity', '');
      lCompiler := 'bin/ppcx64.exe';
      lArtifacts := 'Artifacts';
      lPathKey := 'Path';
      lHashKey := 'SHA256';
    end;
    RequireHexIdentity(Result, 64);
    lFiles := lManifest.Arrays[lArtifacts];
    for lIndex := 0 to lFiles.Count - 1 do
    begin
      lPath := SDKArtifactPath(ADirectory, lFiles.Objects[lIndex].Get(lPathKey, ''));
      if (lListed.IndexOf(lPath) >= 0) or
        not SameText(FileHash(lPath), lFiles.Objects[lIndex].Get(lHashKey, '')) then
        raise Exception.Create('SDK artifact differs from its recorded build: ' + lPath);
      lListed.Add(lPath);
    end;
    for lRequired in [lCompiler, 'units/sysinitpkg.nxu', 'packages/nxrtl.nxp',
      'packages/' + PackageImageName('nxrtl', ATarget)] do
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
      if not SameText(ExtractFileExt(lName), '.nxp') and
        not SameText(ExtractFileExt(lName), '.dll') and (ExtractFileExt(lName) <> '.so') then Continue;
      if SameText(ChangeFileExt(lName, ''), AReplacing) or
        SameText(lName, 'lib' + AReplacing + '.so') then Continue;
      AddInput(AInputs, lName, lPath);
    end;
  finally
    lFiles.Free;
  end;
end;

procedure VerifyPackages(AInputs: TStrings; const ASDK, ATarget, AOwnName, AOwnBuild,
  AExecutable: string);
var
  lPackages: TList<TNXForgePackageMetadata>;
  lMetadata, lProvider, lImageMetadata: TNXForgePackageMetadata;
  lDependency: TNXForgePackageDependency;
  lReader: TNXForgePackageArtifactReader;
  lIndex: Integer;
  lName, lImage, lOwner: string;
  lFound: Boolean;

  procedure CheckImageDependencies(const AImage: TNXForgePackageMetadata;
    const AMetadata: TNXForgePackageMetadata);
  var
    lRequired, lDeclared: TNXForgePackageDependency;
    lMatched: Boolean;
  begin
    for lRequired in AImage.Requires do
    begin
      lMatched := False;
      for lDeclared in AMetadata.Requires do
        if SameText(lRequired.Name, lDeclared.Name) and (lRequired.Build = lDeclared.Build) then
          lMatched := True;
      if not lMatched then raise Exception.Create('PCP and ELF dependency identities differ: ' + AMetadata.Name);
    end;
  end;
begin
  lPackages := TList<TNXForgePackageMetadata>.Create;
  try
    for lIndex := 0 to AInputs.Count - 1 do
    begin
      lName := AInputs.Names[lIndex];
      if SameText(ExtractFileExt(lName), '.dll') and
        (AInputs.IndexOfName(ChangeFileExt(lName, '.nxp')) < 0) then
        raise Exception.Create('Missing package metadata for ' + lName);
      if ExtractFileExt(lName) = '.so' then
      begin
        lOwner := Copy(ChangeFileExt(lName, ''), 4, MaxInt);
        if (Copy(lName, 1, 3) <> 'lib') or (AInputs.IndexOfName(lOwner + '.nxp') < 0) then
          raise Exception.Create('Missing package metadata for ' + lName);
      end;
      if not SameText(ExtractFileExt(lName), '.nxp') then Continue;
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
      lImage := AInputs.Values[PackageImageName(ChangeFileExt(lName, ''), ATarget)];
      if lImage = '' then raise Exception.Create('Missing package image: ' + lMetadata.Name);
      lReader := TNXForgePackageArtifactReader.Create(lImage);
      try
        if ATarget = 'x86_64-linux-gnu' then
        begin
          lImageMetadata := lReader.ReadELFImage;
          if not SameText(lImageMetadata.Name, lMetadata.Name) or
            (lImageMetadata.SDK <> lMetadata.SDK) or (lImageMetadata.Build <> lMetadata.Build) then
            raise Exception.Create('PCP and ELF identities differ: ' + lName);
          CheckImageDependencies(lImageMetadata, lMetadata);
        end
        else lReader.CheckImage(lMetadata.Name, lMetadata.SDK, lMetadata.Build);
      finally
        lReader.Free;
      end;
      lPackages.Add(lMetadata);
    end;
    if (ATarget = 'x86_64-linux-gnu') and (AExecutable <> '') then
    begin
      lReader := TNXForgePackageArtifactReader.Create(AExecutable);
      try
        lMetadata := lReader.ReadELFImage;
      finally
        lReader.Free;
      end;
      if (lMetadata.SDK <> ASDK) or (lMetadata.Build <> AOwnBuild) then
        raise Exception.Create('Executable identity differs from the prepared build');
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
  lSDK, lWork, lIdentity, lBuild, lDirectory, lOptions, lTarget: string;
  lInputs, lDirectories, lExisting: TStringList;
  lRecord, lFile: TJSONObject;
  lFiles: TJSONArray;
  lIndex: Integer;
begin
  lSDK := ExcludeTrailingPathDelimiter(ExpandFileName(ASDKDirectory));
  lWork := ExcludeTrailingPathDelimiter(ExpandFileName(AWorkDirectory));
  lIdentity := VerifySDK(lSDK, lTarget);
  lInputs := TStringList.Create;
  lDirectories := TStringList.Create;
  lExisting := TStringList.Create;
  lRecord := TJSONObject.Create;
  try
    lDirectories.Add(ResolveForgePackageBundle(lSDK + '/packages'));
    for lDirectory in APackageDirectories do lDirectories.Add(ResolveForgePackageBundle(lDirectory));
    for lDirectory in lDirectories do AddDirectory(lInputs, lDirectory, '');
    VerifyPackages(lInputs, lIdentity, lTarget, '', '', '');
    if DirectoryExists(lWork) then
    begin
      CollectFiles(lWork, True, lExisting);
      if lExisting.Count <> 0 then raise Exception.Create('Package work directory must be empty: ' + lWork);
    end;
    lBuild := NewPackageBuildIdentity;
    lOptions := '-Fj' + lIdentity + #10 + '-Fk' + lBuild + #10 + '-Fu' + lSDK + '/units' + #10;
    for lDirectory in lDirectories do
    begin
      lOptions := lOptions + '-Fp' + lDirectory + #10 + '-Fl' + lDirectory + #10;
      if lTarget = 'x86_64-linux-gnu' then
      begin
        if Pos('"', lDirectory) <> 0 then raise Exception.Create('Package directory cannot contain a double quote');
        lOptions := lOptions + '-k-rpath-link' + #10 + '-k"' + lDirectory + '"' + #10;
      end;
    end;
    lRecord.Add('Format', 1);
    lRecord.Add('Target', lTarget);
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
  {$IFDEF UNIX}lStat: Stat;{$ENDIF}
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
  {$IFDEF UNIX}
  if fpStat(ASource, lStat) <> 0 then RaiseLastOSError;
  if fpChmod(ADestination, lStat.st_mode and $FFF) <> 0 then RaiseLastOSError;
  {$ENDIF}
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
  lWork, lOutput, lSDK, lBuild, lName, lPath, lGeneration, lDirectory, lOwnName,
    lTarget, lExecutable, lOwnImage: string;
  lInputs: TStringList;
  lRecord, lManifest, lFile: TJSONObject;
  lFiles, lPublished: TJSONArray;
  lIndex: Integer;
  lPackage: Boolean;
begin
  if not ArtifactName(AName + '.nxp') or (AName = '.') or (AName = '..') then
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
    lTarget := lRecord.Get('Target', '');
    if (lTarget <> 'x86_64-win64') and (lTarget <> 'x86_64-linux-gnu') then
      raise Exception.Create('Unsupported prepared package target');
    RequireHexIdentity(lSDK, 64);
    RequireHexIdentity(lBuild, 32);
    lOwnName := '';
    lOwnImage := '';
    lExecutable := '';
    if lPackage then lOwnName := AName;
    if lPackage then lOwnImage := PackageImageName(AName, lTarget);
    lFiles := lRecord.Arrays['Inputs'];
    for lIndex := 0 to lFiles.Count - 1 do
    begin
      lName := lFiles.Objects[lIndex].Get('Name', '');
      lPath := lFiles.Objects[lIndex].Get('Path', '');
      if FileHash(lPath) <> lFiles.Objects[lIndex].Get('SHA256', '') then
        raise Exception.Create('Package input changed during compilation: ' + lPath);
      if not SameText(ChangeFileExt(lName, ''), lOwnName) and
        not SameText(lName, lOwnImage) then AddInput(lInputs, lName, lPath);
    end;
    if lPackage then
    begin
      if FileExists(lOutput + '/current.json') then AddDirectory(lInputs, lOutput, AName);
      AddInput(lInputs, AName + '.nxp', lWork + '/' + AName + '.nxp');
      AddInput(lInputs, lOwnImage, lWork + '/' + lOwnImage);
    end
    else
    begin
      lName := AName;
      if lTarget = 'x86_64-win64' then lName := lName + '.exe';
      lExecutable := lWork + '/' + lName;
      AddInput(lInputs, lName, lExecutable);
    end;
    VerifyPackages(lInputs, lSDK, lTarget, lOwnName, lBuild, lExecutable);
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
      if not lPackage and SameText(ExtractFileExt(lName), '.nxp') then Continue;
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
