(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXBuildDependencyTests;

{$mode objfpc}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterNXBuildDependencyTests(ARegistry: TNXTestRegistry);
function NXBuildRunDependencyTool: Integer;

implementation

uses Classes, SysUtils, obNXTestContext, obNXTestSuite,
  obNXBuildDescription, obNXBuildDescriptionLoader, obNXBuildPlanner,
  obNXBuildExecutor, obNXFPCBuildOptions, obNexusScriptModel;

type
  TNXDependencyFixture = class
  private
    FRoot: string;
  public
    constructor Create;
    destructor Destroy; override;
    function Path(const ARelative: string): string;
    procedure Write(const ARelative, AText: string);
    procedure Project(const AName, ABody: string);
    function Load(ATargets: TNexusScriptTargetSelection = nil): TNXBuildDescription;
  end;

function Quote(const AText: string): string;
begin
  Result := '"' + StringReplace(AText, '\', '/', [rfReplaceAll]) + '"';
end;

procedure RemoveFixtureDirectory(const ADirectory: string);
var
  lSearch: TSearchRec;
  lPath: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, lSearch) = 0 then
  try
    repeat
      if (lSearch.Name = '.') or (lSearch.Name = '..') then Continue;
      lPath := IncludeTrailingPathDelimiter(ADirectory) + lSearch.Name;
      if (lSearch.Attr and faDirectory) <> 0 then RemoveFixtureDirectory(lPath)
      else DeleteFile(lPath);
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;
  RemoveDir(ADirectory);
end;

constructor TNXDependencyFixture.Create;
var
  lGuid: TGUID;
begin
  inherited Create;
  CreateGUID(lGuid);
  FRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    'dependency-fixtures/' + GUIDToString(lGuid);
  Write('Projects.nxscript', 'ProjectIndex Projects {' +
    ' ProjectReference Shared { Id: "Shared"; Descriptor: "providers/Shared.nxproject"; }' +
    ' ProjectReference Left { Id: "Left"; Descriptor: "providers/Left.nxproject"; }' +
    ' ProjectReference Right { Id: "Right"; Descriptor: "providers/Right.nxproject"; }' +
    ' ProjectReference Missing { Id: "Missing"; Descriptor: "missing.nxproject"; } }');
end;

destructor TNXDependencyFixture.Destroy;
begin
  RemoveFixtureDirectory(FRoot);
  inherited Destroy;
end;

function TNXDependencyFixture.Path(const ARelative: string): string;
begin
  Result := ExpandFileName(ARelative, FRoot);
end;

procedure TNXDependencyFixture.Write(const ARelative, AText: string);
var
  lText: TStringList;
begin
  ForceDirectories(ExtractFileDir(Path(ARelative)));
  lText := TStringList.Create;
  try
    lText.Add('dialect ' + Quote(ExpandFileName(
      'projects/nxbuild/language/nxbuild.Language.nxscript')) + ';');
    lText.Add(AText);
    lText.SaveToFile(Path(ARelative));
  finally
    lText.Free;
  end;
end;

procedure TNXDependencyFixture.Project(const AName, ABody: string);
var
  lRelative, lIndex: string;
begin
  if AName = 'Root' then
  begin
    lRelative := 'Root.nxproject';
    lIndex := 'Projects.nxscript';
  end
  else
  begin
    lRelative := 'providers/' + AName + '.nxproject';
    lIndex := '../Projects.nxscript';
  end;
  Write(lRelative, 'module Projects ' + Quote(lIndex) + '; Project ' + AName +
    ' { Id: ' + Quote(AName) + '; ' + ABody + ' }');
end;

function TNXDependencyFixture.Load(ATargets: TNexusScriptTargetSelection): TNXBuildDescription;
var
  lLoader: TNXBuildDescriptionLoader;
begin
  lLoader := TNXBuildDescriptionLoader.Create;
  try
    Result := lLoader.LoadDescription(Path('Root.nxproject'), ATargets);
  finally
    lLoader.Free;
  end;
end;

procedure TestSourceOnlyProject(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    lFixture.Project('Root', 'Publishes Directories { Sources: ["future/source"]; Headers: ["future/headers"]; Objects: ["future/objects"]; Libraries: ["future/libraries"]; }');
    lDescription := lFixture.Load;
    try
      lPlan := lPlanner.CreatePlan(lDescription);
      try
        AContext.AssertEquals(0, lPlan.Steps.Count);
        AContext.AssertEquals(1, lPlan.Projects.Count);
        AContext.AssertEquals(lFixture.Path('future/source'), lPlan.Projects[0].Directories.Sources[0]);
        AContext.AssertEquals(1, lPlan.Projects[0].Directories.Headers.Count);
        AContext.AssertEquals(1, lPlan.Projects[0].Directories.Objects.Count);
        AContext.AssertEquals(1, lPlan.Projects[0].Directories.Libraries.Count);
        AContext.AssertFalse(DirectoryExists(lFixture.Path('future')));
      finally
        lPlan.Free;
      end;
    finally
      lDescription.Free;
    end;
  finally
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestTransitiveDiamond(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    lFixture.Project('Shared', 'Publishes Directories { Sources: ["shared/source"]; Headers: ["shared/headers"]; Objects: ["shared/objects"]; Libraries: ["shared/libs"]; }');
    lFixture.Project('Left', 'Requires: [@Projects.Shared]; Publishes Directories { Sources: ["left"]; }');
    lFixture.Project('Right', 'Requires: [@Projects.Shared]; Publishes Directories { Sources: ["right"]; }');
    lFixture.Project('Root', 'Requires: [@Projects.Left, @Projects.Right];');
    lDescription := lFixture.Load;
    try
      lPlan := lPlanner.CreatePlan(lDescription);
      try
        AContext.AssertEquals(4, lPlan.Projects.Count);
        AContext.AssertEquals('Shared', lPlan.Projects[0].Id);
        AContext.AssertEquals('Left', lPlan.Projects[1].Id);
        AContext.AssertEquals('Right', lPlan.Projects[2].Id);
        AContext.AssertEquals('Root', lPlan.Projects[3].Id);
        AContext.AssertEquals(3, lPlan.Projects[3].Directories.Sources.Count);
        AContext.AssertEquals(1, lPlan.Projects[3].Directories.Headers.Count);
        AContext.AssertEquals(1, lPlan.Projects[3].Directories.Objects.Count);
        AContext.AssertEquals(1, lPlan.Projects[3].Directories.Libraries.Count);
        AContext.AssertEquals(lFixture.Path('providers/shared/headers'),
          lPlan.Projects[3].Directories.Headers[0]);
      finally
        lPlan.Free;
      end;
    finally
      lDescription.Free;
    end;
  finally
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestMissingAndCyclicRequirements(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lError: string;
  lCycle: Boolean;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    for lCycle in [False, True] do
    begin
      if lCycle then
      begin
        lFixture.Project('Left', 'Requires: [@Projects.Right];');
        lFixture.Project('Right', 'Requires: [@Projects.Left];');
        lFixture.Project('Root', 'Requires: [@Projects.Left];');
      end
      else lFixture.Project('Root', 'Requires: [@Projects.Missing];');
      lDescription := lFixture.Load;
      try
        lError := '';
        try
          lPlan := lPlanner.CreatePlan(lDescription);
          lPlan.Free;
        except
          on E: Exception do lError := E.Message;
        end;
        AContext.AssertTrue(lError <> '', 'Invalid dependency graph was accepted.');
        if lCycle then AContext.AssertTrue(Pos('Root -> Left -> Right -> Left', lError) > 0, lError)
        else
        begin
          AContext.AssertTrue(Pos('Missing', lError) > 0, lError);
          AContext.AssertTrue(Pos(lFixture.Path('missing.nxproject'), lError) > 0, lError);
        end;
      finally
        lDescription.Free;
      end;
    end;
  finally
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestInheritedCompilerArguments(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lSources, lHeaders, lObjects, lLibraries: string;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    lFixture.Project('Shared', 'Publishes Directories { Sources: ["units"]; Headers: ["headers"]; Objects: ["objects"]; Libraries: ["libraries"]; }');
    lFixture.Project('Root', 'Requires: [@Projects.Shared];' +
      ' FPC Pascal { CompilerPath: ' + Quote(ParamStr(0)) + '; SourceFiles: ["missing.pas"]; RequiredPackages: [nxrtl]; }' +
      ' LLVM Native { CompilerPath: ' + Quote(ParamStr(0)) + '; SourceFiles: ["missing.c"]; Libraries: ["native"]; }');
    lSources := lFixture.Path('providers/units');
    lHeaders := lFixture.Path('providers/headers');
    lObjects := lFixture.Path('providers/objects');
    lLibraries := lFixture.Path('providers/libraries');
    lDescription := lFixture.Load;
    try
      lPlan := lPlanner.CreatePlan(lDescription);
      try
        AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-Fu' + lSources) >= 0);
        AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-Fi' + lHeaders) >= 0);
        AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-I' + lHeaders) >= 0);
        AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-Fo' + lObjects) >= 0);
        AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-Fl' + lLibraries) >= 0);
        AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-FPnxrtl') >= 0);
        AContext.AssertEquals(-1, lPlan.Steps[0].Arguments.IndexOf('-FPShared'));
        AContext.AssertTrue(lPlan.Steps[1].Arguments.IndexOf('-I' + lHeaders) >= 0);
        AContext.AssertTrue(lPlan.Steps[1].Arguments.IndexOf('-L' + lLibraries) >= 0);
        AContext.AssertEquals('-lnative', lPlan.Steps[1].Arguments[lPlan.Steps[1].SourceArgumentIndex]);
        AContext.AssertEquals(0, (lDescription.Builds[0] as TNXFPCBuildOptions).Files.UnitPaths.Count,
          'Planning must not mutate authored option collections.');
      finally
        lPlan.Free;
      end;
    finally
      lDescription.Free;
    end;
  finally
    lPlanner.Free;
    lFixture.Free;
  end;
end;

function NXBuildRunDependencyTool: Integer;
var
  lText: TStringList;
begin
  if (ParamStr(3) <> '-') and not FileExists(ParamStr(3)) then Exit(91);
  lText := TStringList.Create;
  try
    if FileExists(ParamStr(2)) then lText.LoadFromFile(ParamStr(2));
    lText.Add('executed');
    lText.SaveToFile(ParamStr(2));
    Result := StrToInt(ParamStr(4));
  finally
    lText.Free;
  end;
end;

procedure TestProducerOrderAndFailure(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lExecutor: TNXBuildExecutor;
  lPlan: TNXBuildPlan;
  lCode: Integer;
  lProducer, lConsumer: string;
  lExecutions: TStringList;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  lExecutor := TNXBuildExecutor.Create;
  try
    lProducer := lFixture.Path('output/producer.done');
    lConsumer := lFixture.Path('output/consumer.done');
    for lCode in [0, 23] do
    begin
      DeleteFile(lProducer);
      DeleteFile(lConsumer);
      lFixture.Project('Shared', 'Process Produce { Executable: ' + Quote(ParamStr(0)) +
        '; OutputPath: ' + Quote(lFixture.Path('output')) + '; Arguments: ["--nxbuild-dependency-tool", ' +
        Quote(lProducer) + ', "-", ' + Quote(IntToStr(lCode)) + ']; }');
      lFixture.Project('Left', 'Requires: [@Projects.Shared];');
      lFixture.Project('Right', 'Requires: [@Projects.Shared];');
      lFixture.Project('Root', 'Requires: [@Projects.Left, @Projects.Right]; Process Consume { Executable: ' +
        Quote(ParamStr(0)) + '; OutputPath: ' + Quote(lFixture.Path('output')) +
        '; Arguments: ["--nxbuild-dependency-tool", ' + Quote(lConsumer) + ', ' + Quote(lProducer) + ', "0"]; }');
      lDescription := lFixture.Load;
      try
        lPlan := lPlanner.CreatePlan(lDescription);
        try
          AContext.AssertFalse(FileExists(lProducer));
          AContext.AssertFalse(FileExists(lConsumer));
          AContext.AssertEquals(2, lPlan.Steps.Count);
          AContext.AssertEquals('Shared', lPlan.Steps[0].ProjectId);
          AContext.AssertEquals(lCode, lExecutor.Execute(lPlan));
          AContext.AssertTrue(FileExists(lProducer));
          lExecutions := TStringList.Create;
          try
            lExecutions.LoadFromFile(lProducer);
            AContext.AssertEquals(1, lExecutions.Count,
              'The shared diamond producer must execute exactly once.');
          finally
            lExecutions.Free;
          end;
          AContext.AssertEquals(Ord(lCode = 0), Ord(FileExists(lConsumer)));
        finally
          lPlan.Free;
        end;
      finally
        lDescription.Free;
      end;
    end;
  finally
    lExecutor.Free;
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestTargetSelectedPublisherPaths(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lTargets: TNexusScriptTargetSelection;
  lOS: string;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  lTargets := TNexusScriptTargetSelection.Create;
  try
    lFixture.Project('Shared', 'RootDirectory: "..";' +
      ' Publishes Directories TargetOS[linux] { Sources: ["linux path"]; }' +
      ' Publishes Directories TargetOS[win64] { Sources: ["windows path"]; }');
    lFixture.Project('Root', 'Requires: [@Projects.Shared];');
    for lOS in ['linux', 'win64'] do
    begin
      lTargets.SetValue('TargetOS', lOS);
      lDescription := lFixture.Load(lTargets);
      try
        lPlan := lPlanner.CreatePlan(lDescription);
      finally
        lDescription.Free;
      end;
      try
        if lOS = 'linux' then
          AContext.AssertEquals(lFixture.Path('linux path'), lPlan.Projects[1].Directories.Sources[0])
        else
          AContext.AssertEquals(lFixture.Path('windows path'), lPlan.Projects[1].Directories.Sources[0]);
      finally
        lPlan.Free;
      end;
    end;
  finally
    lTargets.Free;
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestPublisherChange(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lConsumer: TStringList;
  lOriginal, lDirectory: string;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  lConsumer := TStringList.Create;
  try
    lFixture.Project('Root', 'Requires: [@Projects.Shared];');
    lConsumer.LoadFromFile(lFixture.Path('Root.nxproject'));
    lOriginal := lConsumer.Text;
    for lDirectory in ['original', 'relocated'] do
    begin
      lFixture.Project('Shared', 'Publishes Directories { Sources: [' + Quote(lDirectory) + ']; }');
      lDescription := lFixture.Load;
      try
        lPlan := lPlanner.CreatePlan(lDescription);
        try
          AContext.AssertEquals(lFixture.Path('providers/' + lDirectory),
            lPlan.Projects[1].Directories.Sources[0]);
        finally
          lPlan.Free;
        end;
        lPlan := lPlanner.CreatePlan(lDescription);
        try
          AContext.AssertEquals(1, lPlan.Projects[1].Directories.Sources.Count);
        finally
          lPlan.Free;
        end;
      finally
        lDescription.Free;
      end;
      lConsumer.LoadFromFile(lFixture.Path('Root.nxproject'));
      AContext.AssertEquals(lOriginal, lConsumer.Text);
    end;
  finally
    lConsumer.Free;
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestInvalidProjectReference(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lInvalidRecord, lError: string;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    lFixture.Write('providers/Shared.nxproject', 'Project Shared { Id: "Other"; }');
    lFixture.Project('Root', 'Requires: [@Projects.Shared];');
    lDescription := lFixture.Load;
    try
      lError := '';
      try
        lPlan := lPlanner.CreatePlan(lDescription);
        lPlan.Free;
      except
        on E: Exception do lError := E.Message;
      end;
      AContext.AssertTrue(Pos('resolves to project "Other"', lError) > 0, lError);
    finally
      lDescription.Free;
    end;
    for lInvalidRecord in ['Id: "Shared";', 'Descriptor: "providers/Shared.nxproject";'] do
    begin
      lFixture.Write('Projects.nxscript', 'ProjectIndex Projects { ProjectReference Shared { ' + lInvalidRecord + ' } }');
      lError := '';
      try
        lDescription := lFixture.Load;
        lDescription.Free;
      except
        on E: Exception do lError := E.Message;
      end;
      AContext.AssertTrue(Pos('requires Id and Descriptor', lError) > 0, lError);
      AContext.AssertTrue(Pos('Projects.nxscript', lError) > 0, lError);
    end;
  finally
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestGeneratedToolPlan(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lTool: string;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    lTool := lFixture.Path('tools/future-tool');
    lFixture.Project('Shared', 'Process ProduceTool { Executable: ' + Quote(ParamStr(0)) +
      '; OutputPath: ' + Quote(lFixture.Path('tools')) + '; }');
    lFixture.Project('Root', 'Requires: [@Projects.Shared]; Process UseTool { Executable: ' +
      Quote(lTool) + '; OutputPath: ' + Quote(lFixture.Path('output')) + '; }');
    lDescription := lFixture.Load;
    try
      lPlan := lPlanner.CreatePlan(lDescription);
      try
        AContext.AssertEquals(2, lPlan.Steps.Count);
        AContext.AssertEquals(lTool, lPlan.Steps[1].Executable);
        AContext.AssertFalse(DirectoryExists(lFixture.Path('tools')));
      finally
        lPlan.Free;
      end;
    finally
      lDescription.Free;
    end;
  finally
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestValidationWithoutInstalledTools(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lError, lTool: string;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    lTool := lFixture.Path('not-installed/compiler');
    lFixture.Project('Root', 'Process NativeTool { Executable: ' + Quote(lTool) +
      '; OutputPath: ' + Quote(lFixture.Path('output')) + '; }');
    lDescription := lFixture.Load;
    try
      lPlan := lPlanner.CreatePlan(lDescription, False);
      try
        AContext.AssertEquals(1, lPlan.Steps.Count);
        AContext.AssertEquals(lTool, lPlan.Steps[0].Executable);
        AContext.AssertFalse(DirectoryExists(lFixture.Path('output')));
      finally
        lPlan.Free;
      end;
      lError := '';
      try
        lPlan := lPlanner.CreatePlan(lDescription);
        lPlan.Free;
      except
        on E: Exception do lError := E.Message;
      end;
      AContext.AssertTrue(Pos('tool not found', lError) > 0, lError);
    finally
      lDescription.Free;
    end;
  finally
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure TestActualPlatformPublications(AContext: TNXTestContext);
var
  lLoader: TNXBuildDescriptionLoader;
  lDescription: TNXBuildDescription;
  lTargets: TNexusScriptTargetSelection;
  lName, lOS, lFolder, lPlatform: string;
begin
  lLoader := TNXBuildDescriptionLoader.Create;
  lTargets := TNexusScriptTargetSelection.Create;
  try
    for lOS in ['linux', 'win32', 'win64', 'android', 'darwin', 'ios', 'iphonesim'] do
    begin
      lTargets.SetValue('TargetOS', lOS);
      if lOS = 'win32' then lTargets.SetValue('TargetCPU', 'i386')
      else if (lOS = 'win64') or (lOS = 'linux') then lTargets.SetValue('TargetCPU', 'x86_64')
      else lTargets.SetValue('TargetCPU', 'aarch64');
      if Pos('win', lOS) = 1 then lPlatform := 'win' else lPlatform := 'unix';
      for lName in ['fcl-base', 'fcl-process'] do
      begin
        lFolder := ExpandFileName('packages/nexus-packages/' + lName);
        lDescription := lLoader.LoadDescription(lFolder + '/Project.nxproject', lTargets);
        try
          AContext.AssertEquals(1, lDescription.Publishes.Sources.Count);
          AContext.AssertEquals(lFolder + '/src', lDescription.Publishes.Sources[0]);
          AContext.AssertTrue(lDescription.Publishes.Headers.IndexOf(lFolder + '/src/' + lPlatform) >= 0,
            lName + ' must publish the selected platform includes for ' + lOS);
          if lPlatform = 'win' then
            AContext.AssertEquals(-1, lDescription.Publishes.Headers.IndexOf(lFolder + '/src/unix'))
          else
            AContext.AssertEquals(-1, lDescription.Publishes.Headers.IndexOf(lFolder + '/src/win'));
        finally
          lDescription.Free;
        end;
      end;
    end;
  finally
    lTargets.Free;
    lLoader.Free;
  end;
end;

procedure TestConflictingCompilerTargets(AContext: TNXTestContext);
var
  lFixture: TNXDependencyFixture;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lTargets: TNexusScriptTargetSelection;
  lBody, lError: string;
begin
  lFixture := TNXDependencyFixture.Create;
  lPlanner := TNXBuildPlanner.Create;
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('TargetOS', 'linux');
  lTargets.Add('TargetCPU', 'x86_64');
  try
    for lBody in [
      'FPC Pascal { SourceFiles: ["missing.pas"]; Target Platform { OperatingSystem: "win64"; } }',
      'LLVM Native { SourceFiles: ["missing.c"]; Target: "aarch64-unknown-linux-gnu"; }',
      'LLVM Native { SourceFiles: ["missing.c"]; Target: "x86_64-unknown-linux-android"; }'] do
    begin
      lFixture.Project('Root', lBody);
      lDescription := lFixture.Load(lTargets);
      try
        lError := '';
        try
          lPlan := lPlanner.CreatePlan(lDescription, False);
          lPlan.Free;
        except
          on E: Exception do lError := E.Message;
        end;
        AContext.AssertTrue(Pos('conflicts with selected Target', lError) > 0, lError);
        AContext.AssertTrue(Pos('Project "Root"', lError) > 0, lError);
      finally
        lDescription.Free;
      end;
    end;
  finally
    lTargets.Free;
    lPlanner.Free;
    lFixture.Free;
  end;
end;

procedure RegisterNXBuildDependencyTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NXBuild.Dependencies');
  lSuite.AddTest('SourceOnly', @TestSourceOnlyProject);
  lSuite.AddTest('TransitiveDiamond', @TestTransitiveDiamond);
  lSuite.AddTest('MissingAndCycle', @TestMissingAndCyclicRequirements);
  lSuite.AddTest('CompilerArguments', @TestInheritedCompilerArguments);
  lSuite.AddTest('ProducerOrderAndFailure', @TestProducerOrderAndFailure);
  lSuite.AddTest('TargetSelectedPublisherPaths', @TestTargetSelectedPublisherPaths);
  lSuite.AddTest('PublisherChange', @TestPublisherChange);
  lSuite.AddTest('InvalidProjectReference', @TestInvalidProjectReference);
  lSuite.AddTest('GeneratedToolPlan', @TestGeneratedToolPlan);
  lSuite.AddTest('ValidationWithoutInstalledTools', @TestValidationWithoutInstalledTools);
  lSuite.AddTest('ActualPlatformPublications', @TestActualPlatformPublications);
  lSuite.AddTest('ConflictingCompilerTargets', @TestConflictingCompilerTargets);
end;

end.
