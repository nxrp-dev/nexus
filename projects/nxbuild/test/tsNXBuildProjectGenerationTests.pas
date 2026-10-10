(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXBuildProjectGenerationTests;

{$mode objfpc}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterNXBuildProjectGenerationTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes, SysUtils, fpjson, obNXTestContext, obNXTestSuite,
  obNXLSProjectProtocol, obNXLSProjectService, obNXBuildProjectLoader,
  obNXPascalProject, obNXFPCBuildOptions;

function NXBuildGeneratedFolder(const AName: string): string;
begin
  Result := ExpandFileName('output/nxbuildTests/generated/' + AName);
end;

function NXBuildGenerateProject(const AName, AFolder, ABuildTool: string;
  const AImportFile: string = ''): TNXLSProjectCreateResult;
var
  lParams: TNXLSProjectCreateParams;
  lSource: TStringList;
  lFile: TNXLSProjectFile;
  lIndex: Integer;
begin
  lParams := TNXLSProjectCreateParams.Create;
  lSource := TStringList.Create;
  Result := TNXLSProjectCreateResult.Create;
  try
    try
      lParams.projectName.Value := AName;
      lParams.targetDir.Value := NXBuildGeneratedFolder(AFolder);
      lParams.buildTool.Value := ABuildTool;
      if AImportFile <> '' then
      begin
        lParams.kind.Value := 'lazarus';
        lParams.lpiFile.Value := AImportFile;
      end;
      TNXLSProjectService.FillCreateNexusProject(lParams, Result);
      for lIndex := 0 to Result.files.Count - 1 do
      begin
        lFile := Result.files[lIndex] as TNXLSProjectFile;
        ForceDirectories(ExtractFileDir(lFile.path.Value));
        lSource.Text := lFile.content.Value;
        lSource.SaveToFile(lFile.path.Value);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    lSource.Free;
    lParams.Free;
  end;
end;

function NXBuildLoadGenerated(AResult: TNXLSProjectCreateResult): TNXPascalProject;
var
  lLoader: TNXBuildProjectLoader;
  lFile: TNXLSProjectFile;
begin
  lFile := AResult.files[0] as TNXLSProjectFile;
  if not SameText(ExtractFileExt(lFile.path.Value), '.nxproject') then
    raise Exception.Create('The generator must emit a .nxproject descriptor.');
  lLoader := TNXBuildProjectLoader.Create;
  try
    Result := lLoader.LoadProject(lFile.path.Value);
  finally
    lLoader.Free;
  end;
end;

procedure TestGeneratedFPC(AContext: TNXTestContext);
var
  lResult: TNXLSProjectCreateResult;
  lProject: TNXPascalProject;
  lRoot: string;
begin
  lResult := NXBuildGenerateProject('NewFPC', 'fpc', 'fpc');
  try
    AContext.AssertEquals(2, lResult.files.Count);
    AContext.AssertEquals(0,
      Pos('$(', (lResult.files[0] as TNXLSProjectFile).content.Value),
      'Generated NexusScript must use native references.');
    lProject := NXBuildLoadGenerated(lResult);
    try
      lRoot := NXBuildGeneratedFolder('fpc');
      AContext.AssertEquals('NewFPC', lProject.Name);
      AContext.AssertEquals(Ord(pbtFPC), Ord(lProject.BuildTool));
      AContext.AssertEquals(Ord(ppkProgram), Ord(lProject.ProjectKind));
      AContext.AssertEquals(lRoot, lProject.ProjectRoot);
      AContext.AssertEquals('src', lProject.SourceRoot);
      AContext.AssertEquals('output', lProject.OutputRoot);
      AContext.AssertEquals(lProject.ResolvePath('src/NewFPC.lpr'), lProject.BuildFile);
      AContext.AssertEquals(lProject.BuildFile, lProject.FPCBuildOptions.InputFile);
      AContext.AssertEquals(lProject.ResolvePath('src'),
        lProject.FPCBuildOptions.Files.UnitPaths[0]);
      AContext.AssertEquals(lProject.ResolvePath('output/units'),
        lProject.FPCBuildOptions.Files.UnitOutputPath);
      AContext.AssertEquals(lProject.ResolvePath('output'),
        lProject.FPCBuildOptions.Files.ExecutableOutputPath);
      AContext.AssertEquals('objfpc', lProject.TargetPlatform.FPCMode);
      AContext.AssertEquals(Ord(flmObjFPC), Ord(lProject.FPCBuildOptions.Language.Mode));
    finally
      lProject.Free;
    end;
  finally
    lResult.Free;
  end;
end;

procedure TestGeneratedLazarus(AContext: TNXTestContext);
var
  lResult: TNXLSProjectCreateResult;
  lProject: TNXPascalProject;
begin
  lResult := NXBuildGenerateProject('NewLazarus', 'lazarus', 'lazarus');
  try
    AContext.AssertEquals(3, lResult.files.Count);
    lProject := NXBuildLoadGenerated(lResult);
    try
      AContext.AssertEquals(Ord(pbtLazarus), Ord(lProject.BuildTool));
      AContext.AssertEquals(Ord(ppkLazarusProject), Ord(lProject.ProjectKind));
      AContext.AssertEquals(lProject.ResolvePath('NewLazarus.lpi'), lProject.BuildFile);
      AContext.AssertEquals(lProject.BuildFile, lProject.FPCBuildOptions.InputFile);
      AContext.AssertTrue(FileExists(lProject.BuildFile));
    finally
      lProject.Free;
    end;
  finally
    lResult.Free;
  end;
end;

procedure TestImportedLazarus(AContext: TNXTestContext);
var
  lResult: TNXLSProjectCreateResult;
  lProject: TNXPascalProject;
  lLPIFile: string;
begin
  lLPIFile := ExpandFileName('projects/nxbuild/examples/Hello.lpi');
  lResult := NXBuildGenerateProject('ImportedHello', 'import', 'lazarus', lLPIFile);
  try
    AContext.AssertEquals(1, lResult.files.Count);
    lProject := NXBuildLoadGenerated(lResult);
    try
      AContext.AssertEquals('ImportedHello', lProject.Name);
      AContext.AssertEquals(Ord(pbtLazarus), Ord(lProject.BuildTool));
      AContext.AssertEquals(Ord(ppkLazarusProject), Ord(lProject.ProjectKind));
      AContext.AssertEquals(lLPIFile, lProject.BuildFile);
      AContext.AssertEquals(NXBuildGeneratedFolder('import'), lProject.ProjectRoot);
      AContext.AssertEquals('output', lProject.OutputRoot);
      AContext.AssertEquals(0, lProject.FPCBuildOptions.Files.UnitPaths.Count);
    finally
      lProject.Free;
    end;
  finally
    lResult.Free;
  end;
end;

procedure TestGeneratedQuotedNames(AContext: TNXTestContext);
var
  lResult: TNXLSProjectCreateResult;
  lProject: TNXPascalProject;
begin
  lResult := NXBuildGenerateProject('007-game', 'caret^ and spaces', 'fpc');
  try
    lProject := NXBuildLoadGenerated(lResult);
    try
      AContext.AssertEquals('007-game', lProject.Name);
      AContext.AssertEquals(NXBuildGeneratedFolder('caret^ and spaces'),
        lProject.ProjectRoot);
      AContext.AssertEquals(lProject.ResolvePath('src/007-game.lpr'),
        lProject.BuildFile);
    finally
      lProject.Free;
    end;
  finally
    lResult.Free;
  end;
end;

procedure TestGeneratedWireRoundTrip(AContext: TNXTestContext);
var
  lResult, lReloaded: TNXLSProjectCreateResult;
  lJSON: TJSONData;
  lBefore, lAfter: TNXLSProjectFile;
begin
  lResult := NXBuildGenerateProject('WireProject', 'wire^ and spaces', 'fpc');
  lReloaded := TNXLSProjectCreateResult.Create;
  lJSON := nil;
  try
    lJSON := lResult.ToJSONData;
    lReloaded.FromJSONData(lJSON);
    AContext.AssertEquals(lResult.files.Count, lReloaded.files.Count);
    lBefore := lResult.files[0] as TNXLSProjectFile;
    lAfter := lReloaded.files[0] as TNXLSProjectFile;
    AContext.AssertEquals(lBefore.path.Value, lAfter.path.Value);
    AContext.AssertEquals(lBefore.content.Value, lAfter.content.Value);
    AContext.AssertTrue(Pos('dialect ', lAfter.content.Value) = 1);
  finally
    lJSON.Free;
    lReloaded.Free;
    lResult.Free;
  end;
end;

procedure RegisterNXBuildProjectGenerationTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NXBuild.ProjectGeneration');
  lSuite.AddTest('FPC', @TestGeneratedFPC);
  lSuite.AddTest('Lazarus', @TestGeneratedLazarus);
  lSuite.AddTest('LazarusImport', @TestImportedLazarus);
  lSuite.AddTest('QuotedNamesAndPaths', @TestGeneratedQuotedNames);
  lSuite.AddTest('WireRoundTrip', @TestGeneratedWireRoundTrip);
end;

end.
