(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit utNXForgePackageSDK;

{$mode delphi}{$H+}

interface

function WriteForgePackageSDKOptions(const ABootstrapDirectory,
  AOutputDirectory: string): string;
function WriteForgePackageSDKManifest(const ADirectory: string): string;

implementation

uses Classes, SysUtils, fpjson, jsonparser, fpsha256,
  obNXForgeInvocation, obNXForgeProcess, obNXForgePackageArtifactReader, utNXForgePackageFiles;

function RelativePath(const ARoot, APath: string): string;
begin
  Result := StringReplace(Copy(APath,
    Length(IncludeTrailingPathDelimiter(ARoot)) + 1, MaxInt), '\', '/', [rfReplaceAll]);
end;

procedure AddDirectoryHashes(const ADirectory: string; AParts: TStrings);
var
  lFiles: TStringList;
  lFile: string;
begin
  lFiles := TStringList.Create;
  try
    lFiles.CaseSensitive := True;
    CollectFiles(ADirectory, True, lFiles);
    lFiles.Sort;
    for lFile in lFiles do
      AParts.Add('/' + RelativePath(ADirectory, lFile) + ':' + FileHash(lFile));
  finally
    lFiles.Free;
  end;
end;

function SDKIdentity(const ABootstrap, ASDK: string): string;
var
  lParts: TStringList;
  lStream: TStringStream;
  lText: string;
begin
  lParts := TStringList.Create;
  try
    lParts.LineBreak := #10;
    lParts.Add(FileHash(ASDK + 'bin/ppcx64.exe'));
    lParts.Add('x86_64-win64;-O2;-Ur;-Xs');
    AddDirectoryHashes(ASDK + 'work/rtl-units', lParts);
    AddDirectoryHashes(ABootstrap + 'seed/rtl', lParts);
    lParts.Add(FileHash(ABootstrap + 'seed/build-options.cfg'));
    lText := lParts.Text;
    Delete(lText, Length(lText), 1); // The fingerprint has separators, no trailing LF.
    lStream := TStringStream.Create(lText);
    try
      Result := UpperCase(TSHA256.StreamHexa(lStream));
    finally
      lStream.Free;
    end;
  finally
    lParts.Free;
  end;
end;

function WriteForgePackageSDKOptions(const ABootstrapDirectory,
  AOutputDirectory: string): string;
var
  lSDK, lWork, lIdentity, lBuild: string;
  lRecord: TJSONObject;
begin
  // Bounded to the standard Win64 package SDK layout and release settings.
  lSDK := IncludeTrailingPathDelimiter(ExpandFileName(AOutputDirectory));
  lWork := lSDK + 'work/';
  lIdentity := SDKIdentity(IncludeTrailingPathDelimiter(ABootstrapDirectory), lSDK);
  lBuild := NewPackageBuildIdentity;
  lRecord := TJSONObject.Create;
  try
    lRecord.Add('SDK', lIdentity);
    lRecord.Add('Build', UpperCase(lBuild));
    WriteText(lWork + 'identity.json', lRecord.AsJSON + #10);
    WriteText(lWork + 'foundation.cfg', '-Fj' + lIdentity + #10 + '-Fk' + UpperCase(lBuild) + #10);
    // Package search must precede -FP, which loads metadata while parsing options.
    WriteText(lWork + 'startup.cfg', '-Fj' + lIdentity + #10 + '-Fp' +
      StringReplace(lSDK, '\', '/', [rfReplaceAll]) + 'packages' + #10 + '-FPnxrtl' + #10);
  finally
    lRecord.Free;
  end;
  Result := 'Package SDK identity: ' + lIdentity + LineEnding;
end;

procedure CheckPackage(const AFileName, ASDK, ABuild: string; AImage: Boolean);
var
  lReader: TNXForgePackageArtifactReader;
begin
  lReader := TNXForgePackageArtifactReader.Create(AFileName);
  try
    if AImage then lReader.CheckImage('nxrtl', ASDK, ABuild)
    else lReader.CheckMetadata('nxrtl', ASDK, ABuild);
  finally
    lReader.Free;
  end;
end;

function CompilerVersion(const ASDK: string): string;
var
  lInvocation: TNXForgeInvocation;
begin
  lInvocation := TNXForgeInvocation.Create;
  try
    lInvocation.WorkingDirectory := ASDK;
    lInvocation.Command := '"' + ASDK + 'bin/ppcx64.exe" -iV';
    ExecuteForgeProcess(lInvocation);
    if not lInvocation.Succeeded then
      raise Exception.CreateFmt('Cannot read the SDK compiler version (exit %d): %s%s',
        [lInvocation.ExitStatus, lInvocation.Diagnostic, lInvocation.StdErr]);
    Result := Trim(lInvocation.StdOut);
    if Result = '' then raise Exception.Create('Empty SDK compiler version');
  finally
    lInvocation.Free;
  end;
end;

function WriteForgePackageSDKManifest(const ADirectory: string): string;
var
  lSDK, lFile: string;
  lIdentity, lManifest, lArtifact: TJSONObject;
  lArtifacts: TJSONArray;
  lFiles: TStringList;
begin
  lSDK := IncludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  lIdentity := ReadIdentity(lSDK + 'work/identity.json');
  try
    RequireHexIdentity(lIdentity.Get('SDK', ''), 64);
    RequireHexIdentity(lIdentity.Get('Build', ''), 32);
    CheckPackage(lSDK + 'packages/nxrtl.nxpl', lIdentity.Get('SDK', ''), lIdentity.Get('Build', ''), False);
    CheckPackage(lSDK + 'packages/nxrtl.nxpl', lIdentity.Get('SDK', ''), lIdentity.Get('Build', ''), True);
    lManifest := TJSONObject.Create;
    try
      lManifest.Add('Format', 2);
      lManifest.Add('Target', 'x86_64-win64');
      lManifest.Add('Experimental', True);
      lManifest.Add('Foundation', 'nxrtl');
      lManifest.Add('CompilerVersion', CompilerVersion(lSDK));
      lManifest.Add('SmartLink', False);
      lManifest.Add('SDKIdentity', lIdentity.Get('SDK', ''));
      lArtifacts := TJSONArray.Create;
      lManifest.Add('Artifacts', lArtifacts);
      lFiles := TStringList.Create;
      try
        lFiles.CaseSensitive := True;
        CollectFiles(lSDK + 'units', False, lFiles);
        CollectFiles(lSDK + 'packages', False, lFiles);
        lFiles.Sort;
        lFiles.Insert(0, lSDK + 'bin/ppcx64.exe');
        for lFile in lFiles do
        begin
          lArtifact := TJSONObject.Create;
          lArtifacts.Add(lArtifact);
          lArtifact.Add('Path', RelativePath(lSDK, lFile));
          lArtifact.Add('SHA256', FileHash(lFile));
        end;
      finally
        lFiles.Free;
      end;
      WriteText(lSDK + 'sdk.json', lManifest.AsJSON + #10);
    finally
      lManifest.Free;
    end;
  finally
    lIdentity.Free;
  end;
  Result := 'Package SDK ready: ' + lSDK + LineEnding;
end;

end.
