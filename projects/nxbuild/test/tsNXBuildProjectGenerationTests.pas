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
  obNXLSProjectProtocol, obNXLSProjectService, obNXBuildDescriptionLoader,
  obNXBuildDescription, obNXFPCBuildOptions;

function NXBuildGeneratedFolder(const AName: string): string;
begin
  Result := ExpandFileName('output/nxbuildTests/generated/' + AName);
end;

function NXBuildGenerateProject(const AName, AFolder: string): TNXLSProjectCreateResult;
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
      lParams.buildTool.Value := 'fpc';
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

function NXBuildLoadGenerated(AResult: TNXLSProjectCreateResult): TNXBuildDescription;
var
  lLoader: TNXBuildDescriptionLoader;
  lFile: TNXLSProjectFile;
begin
  lFile := AResult.files[0] as TNXLSProjectFile;
  if not SameText(ExtractFileExt(lFile.path.Value), '.nxproject') then
    raise Exception.Create('The generator must emit a .nxproject descriptor.');
  lLoader := TNXBuildDescriptionLoader.Create;
  try
    Result := lLoader.LoadDescription(lFile.path.Value);
  finally
    lLoader.Free;
  end;
end;

procedure TestGeneratedFPC(AContext: TNXTestContext);
var
  lResult: TNXLSProjectCreateResult;
  lDescription: TNXBuildDescription;
  lRoot: string;
begin
  lResult := NXBuildGenerateProject('NewFPC', 'fpc');
  try
    AContext.AssertEquals(2, lResult.files.Count);
    AContext.AssertEquals(0,
      Pos('$(', (lResult.files[0] as TNXLSProjectFile).content.Value),
      'Generated NexusScript must use native references.');
    lDescription := NXBuildLoadGenerated(lResult);
    try
      lRoot := NXBuildGeneratedFolder('fpc');
      AContext.AssertEquals('NewFPC', lDescription.Name);
      AContext.AssertEquals('Project', lDescription.Kind);
      AContext.AssertEquals(1, lDescription.Builds.Count);
      AContext.AssertEquals(lRoot, lDescription.RootDirectory);
      AContext.AssertEquals('src', lDescription.SourceRoot);
      AContext.AssertEquals('output', lDescription.OutputRoot);
      AContext.AssertEquals(lDescription.ResolvePath('src/NewFPC.lpr'), (lDescription.Builds[0] as TNXFPCBuildOptions).SourceFiles[0]);
      AContext.AssertEquals(lDescription.ResolvePath('src'),
        (lDescription.Builds[0] as TNXFPCBuildOptions).Files.UnitPaths[0]);
      AContext.AssertEquals(lDescription.ResolvePath('output'),
        (lDescription.Builds[0] as TNXFPCBuildOptions).OutputPath);
      AContext.AssertEquals(Ord(flmObjFPC), Ord((lDescription.Builds[0] as TNXFPCBuildOptions).Language.Mode));
    finally
      lDescription.Free;
    end;
  finally
    lResult.Free;
  end;
end;

procedure TestGeneratedQuotedNames(AContext: TNXTestContext);
var
  lResult: TNXLSProjectCreateResult;
  lDescription: TNXBuildDescription;
begin
  lResult := NXBuildGenerateProject('007-game', 'caret^ and spaces');
  try
    lDescription := NXBuildLoadGenerated(lResult);
    try
      AContext.AssertEquals('007-game', lDescription.Name);
      AContext.AssertEquals(NXBuildGeneratedFolder('caret^ and spaces'),
        lDescription.RootDirectory);
      AContext.AssertEquals(lDescription.ResolvePath('src/007-game.lpr'),
        (lDescription.Builds[0] as TNXFPCBuildOptions).SourceFiles[0]);
    finally
      lDescription.Free;
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
  lResult := NXBuildGenerateProject('WireProject', 'wire^ and spaces');
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
  lSuite.AddTest('QuotedNamesAndPaths', @TestGeneratedQuotedNames);
  lSuite.AddTest('WireRoundTrip', @TestGeneratedWireRoundTrip);
end;

end.
