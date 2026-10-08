(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXSetupTests;

{$mode delphi}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterSetupTests(ARegistry: TNXTestRegistry);

implementation

uses Classes, SysUtils, Generics.Collections, obNXTestContext, obNXTestSuite,
  tpNXSetup, obNXSetupModel, obNXSetupLoader, obNXSetupSelection,
  obNXSetupLocations, obNXSetupPlan, obNXSetupSourceContext,
  obNXSetupFileInstaller, obNXSetupState, obNXSetupBundle, obNXSetupSession, zipper,
  utNXSetupFiles, utNXSetupStreams, utNXSetupPaths, resource, versionresource, versiontypes, resreader, reswriter,
  obNexusScriptSourceProvider, obNexusScriptSession, obNexusScriptModel;

type
  TSetupTestProvider = class(TNexusScriptFileSourceProvider)
  private
    FText, FName: string;
  public
    constructor Create(const AText: string);
    function Exists(const ASourceName: string): Boolean; override;
    function ReadSource(const ASourceName: string; out AText: string;
      out AVersion: Integer): Boolean; override;
    property Name: string read FName;
  end;

constructor TSetupTestProvider.Create(const AText: string);
begin
  inherited Create;
  FName := ExpandFileName('projects/setup/test/fixtures/Overlay.nxscript');
  FText := 'dialect "../../language/Setup.Language.nxscript";' + AText;
end;

function TSetupTestProvider.Exists(const ASourceName: string): Boolean;
begin
  Result := SameIdentity(ASourceName, FName) or inherited Exists(ASourceName);
end;

function TSetupTestProvider.ReadSource(const ASourceName: string;
  out AText: string; out AVersion: Integer): Boolean;
begin
  if not SameIdentity(ASourceName, FName) then
    Exit(inherited ReadSource(ASourceName, AText, AVersion));
  AText := FText;
  AVersion := 1;
  Result := True;
end;

function LoadText(const AText: string): TNXSetupDocument;
var
  lProvider: TSetupTestProvider;
begin
  lProvider := TSetupTestProvider.Create(AText);
  try
    Result := TNXSetupLoader.LoadFile(lProvider.Name, lProvider);
  finally
    lProvider.Free;
  end;
end;

function LoadFixture: TNXSetupDocument;
begin
  Result := TNXSetupLoader.LoadFile(ExpandFileName('projects/setup/test/fixtures/Nexus.nxscript'));
end;

function AllFeatures(ADocument: TNXSetupDocument): TList<TNXSetupFeature>;
begin
  Result := TList<TNXSetupFeature>.Create;
  Result.AddRange(ADocument.Features);
end;

procedure TestModel(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lDependency: TNXSetupDependency;
  lSource: TNXSetupSource;
  lEntryRetained: Boolean;
begin
  lDocument := LoadFixture;
  try
    AContext.AssertEquals('NexusRP.Nexus', lDocument.Product.Id, 'Stable identity is separate from name.');
    AContext.AssertEquals('Nexus', lDocument.Product.Name, 'Product display metadata is preserved.');
    AContext.AssertEquals(7, lDocument.Features.Count, 'Owned recursive features are mapped.');
    AContext.AssertTrue(lDocument.FindFeature('Stable').Parent = lDocument.FindFeature('Compilers'),
      'Hierarchy is distinct from requirement links.');
    AContext.AssertTrue(lDocument.FindFeature('Language').Requires[1] = lDocument.FindFeature('Editor'),
      'Feature references point to native entities.');
    AContext.AssertTrue(lDocument.FindFeature('Editor').Requires[0] = lDocument.FindFeature('Language'),
      'A mutual feature cycle is retained.');
    AContext.AssertEquals(2, lDocument.FindFeature('Runtime').Shortcuts.Count, 'Features own multiple shortcuts.');
    AContext.AssertEquals(2, lDocument.Dependencies.Count, 'Both dependencies have one native identity.');
    for lDependency in lDocument.Dependencies do
      if lDependency.Declaration.Name = 'VSCode' then
      begin
        AContext.AssertTrue(lDependency.Ownership = soShared, 'VS Code is shared.');
        AContext.AssertTrue(lDependency.Acquisition.Kind = sakWeb, 'Acquisition is independent.');
        AContext.AssertTrue(lDependency.Installer.Kind = sikExe, 'Installer mechanism is independent.');
      end
      else
      begin
        AContext.AssertEquals('NexusPascal', lDependency.Declaration.Name, 'The other dependency is the extension.');
        AContext.AssertTrue(lDependency.Ownership = soOwned, 'The extension is owned.');
        AContext.AssertTrue(lDependency.Installer.Kind = sikVSIX, 'The extension uses VSIX.');
      end;
    AContext.AssertTrue(lDocument.SourceContext.Sources.Count >= 3, 'Entry, dialect, and meta-dialect source are retained.');
    lEntryRetained := False;
    for lSource in lDocument.SourceContext.Sources do
      if SameFileName(lSource.Name, lDocument.Live.SourceName) then
        lEntryRetained := Pos('Product Nexus', lSource.Text) > 0;
    AContext.AssertTrue(lEntryRetained, 'Retained entry is original authored script, not JSON.');
  finally
    lDocument.Free;
  end;
end;

procedure TestSelection(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
  lReason: string;
begin
  lDocument := LoadFixture;
  lApplicable := AllFeatures(lDocument);
  lSelection := nil;
  try
    lSelection := TNXSetupSelection.Create(lDocument, lApplicable);
    lSelection.SelectDefaults;
    AContext.AssertEquals(3, lSelection.Selected.Count, 'Defaults and required seeds close through the cycle.');
    AContext.AssertEquals(1, lSelection.Explicit.Count, 'Implicit and required membership is not a user seed.');
    AContext.AssertEquals(2, lSelection.Dependencies.Count, 'The VSIX and shared host are reachable once.');
    AContext.AssertTrue(not lSelection.SetSelected(lDocument.FindFeature('Editor'), False, lReason),
      'A required implicit selection cannot be removed.');
    AContext.AssertTrue(Pos('Language', lReason) > 0, 'The explanation identifies the dependent.');
    AContext.AssertTrue(not lSelection.SetSelected(lDocument.FindFeature('Runtime'), False, lReason),
      'A required feature cannot be removed.');
    AContext.AssertTrue(lSelection.SetSelected(lDocument.FindFeature('Language'), False, lReason),
      'Removing the only explicit cyclic seed removes its implied membership.');
    AContext.AssertEquals(1, lSelection.Selected.Count, 'Only the required runtime remains.');
    AContext.AssertEquals(0, lSelection.Dependencies.Count, 'Unreachable dependencies disappear.');
    AContext.AssertTrue(lSelection.SetSelected(lDocument.FindFeature('Editor'), True, lReason), 'Select either cycle member.');
    AContext.AssertTrue(lSelection.SetSelected(lDocument.FindFeature('Language'), True, lReason), 'Preserve another explicit seed.');
    AContext.AssertTrue(not lSelection.SetSelected(lDocument.FindFeature('Editor'), False, lReason),
      'Another explicit dependent prevents removal; failure is atomic.');
    AContext.AssertEquals(2, lSelection.Explicit.Count, 'Rejected candidates leave seeds unchanged.');
  finally
    lSelection.Free;
    lApplicable.Free;
    lDocument.Free;
  end;
end;

procedure TestExclusive(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
  lReason: string;
begin
  lDocument := LoadFixture;
  lApplicable := AllFeatures(lDocument);
  lSelection := nil;
  try
    lSelection := TNXSetupSelection.Create(lDocument, lApplicable);
    AContext.AssertTrue(lSelection.Selected.IndexOf(lDocument.FindFeature('Stable')) < 0,
      'Exclusive mode does not require exactly one child.');
    AContext.AssertTrue(lSelection.SetSelected(lDocument.FindFeature('Stable'), True, lReason), 'One child may be selected.');
    AContext.AssertTrue(not lSelection.SetSelected(lDocument.FindFeature('Development'), True, lReason),
      'Exclusive siblings cannot both be selected.');
    AContext.AssertTrue(Pos('Stable', lReason) > 0, 'The conflict names the choices.');
    AContext.AssertTrue(lSelection.SetSelected(lDocument.FindFeature('Stable'), False, lReason), 'An exclusive group may become empty.');
  finally
    lSelection.Free;
    lApplicable.Free;
    lDocument.Free;
  end;
end;

procedure TestApplicability(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
  lReason: string;
begin
  lDocument := LoadFixture;
  lApplicable := AllFeatures(lDocument);
  lSelection := nil;
  try
    lApplicable.Remove(lDocument.FindFeature('Editor'));
    lSelection := TNXSetupSelection.Create(lDocument, lApplicable);
    AContext.AssertTrue(not lSelection.SetSelected(lDocument.FindFeature('Language'), True, lReason),
      'Closure cannot silently include an inapplicable feature.');
    AContext.AssertTrue(Pos('Editor', lReason) > 0, 'The absent requirement is named.');
    AContext.AssertEquals(1, lSelection.Selected.Count, 'Failed closure leaves prior selection intact.');
  finally
    lSelection.Free;
    lApplicable.Free;
    lDocument.Free;
  end;
end;

procedure TestResolvedPlan(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
  lLocations: TNXSetupLocations;
  lPlan: TNXSetupPlan;
  lFile: TNXSetupPlannedFile;
  lRoot: string;
begin
  lDocument := LoadFixture;
  lApplicable := AllFeatures(lDocument);
  lSelection := nil;
  lPlan := nil;
  lLocations := TNXSetupLocations.Create;
  try
    lSelection := TNXSetupSelection.Create(lDocument, lApplicable);
    lSelection.SelectDefaults;
    lRoot := ExpandFileName('output/setup-plan-only');
    lLocations.Bind('ApplicationRoot', lRoot);
    lLocations.Bind('ApplicationsMenu', ExpandFileName('output/setup-menu-only'));
    lPlan := TNXSetupPlan.Build(lSelection, lLocations);
    AContext.AssertEquals(2, lPlan.Files.Count, 'Only selected owners contribute file/tree payload.');
    AContext.AssertEquals(2, lPlan.Shortcuts.Count, 'All selected-owner shortcuts contribute.');
    AContext.AssertEquals(2, lPlan.Dependencies.Count, 'Plan membership deduplicates prerequisites.');
    for lFile in lPlan.Files do
      if lFile.Payload.Kind = spkFile then
        AContext.AssertTrue(FileExists(lFile.Source), 'The Nexus README is a real source file.')
      else AContext.AssertTrue(DirectoryExists(lFile.Source), 'The NXScript language directory is real.');
    AContext.AssertEquals(ExpandFileName(lRoot + '/doc/index.html'), lPlan.Shortcuts[1].Target,
      'Derived location and shortcut path compose from the same application root.');
    AContext.AssertTrue(not DirectoryExists(lRoot), 'Plan inspection performs no machine writes.');
  finally
    lPlan.Free;
    lLocations.Free;
    lSelection.Free;
    lApplicable.Free;
    lDocument.Free;
  end;
end;

procedure TestDependencyCycles(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
begin
  lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; ' +
    'Feature A { Default: True; Requires: [@P.X, @P.Y]; } ' +
    'Dependency X { Ownership: Shared; Requires: [@P.Y]; } ' +
    'Dependency Y { Ownership: Owned; Requires: [@P.X]; } }');
  lApplicable := AllFeatures(lDocument);
  lSelection := nil;
  try
    lSelection := TNXSetupSelection.Create(lDocument, lApplicable);
    lSelection.SelectDefaults;
    AContext.AssertEquals(2, lSelection.Dependencies.Count, 'Mutual/shared dependency membership terminates and deduplicates.');
    AContext.AssertTrue(lSelection.Dependencies[0].Requires[0] = lSelection.Dependencies[1],
      'Dependency relationships remain actual object pointers.');
  finally
    lSelection.Free;
    lApplicable.Free;
    lDocument.Free;
  end;
end;

procedure TestSourceReplay(AContext: TNXTestContext);
var
  lDocument, lReplay: TNXSetupDocument;
begin
  lDocument := TNXSetupLoader.LoadFile(ExpandFileName('projects/setup/examples/Nexus.nxscript'));
  lReplay := nil;
  try
    AContext.AssertTrue(lDocument.SourceContext.Sources.Count >= 4,
      'Entry, included declaration, dialect, and language definition are retained.');
    lReplay := TNXSetupLoader.LoadFile(lDocument.Live.SourceName,
      lDocument.SourceContext, lDocument.SourceContext.Targets);
    AContext.AssertTrue(lReplay.FindFeature('Editor') <> lDocument.FindFeature('Editor'),
      'Recompiling original retained source produces independent native entities.');
    FreeAndNil(lDocument);
    AContext.AssertTrue(lReplay.FindFeature('Editor').Requires[0] = lReplay.FindFeature('Language'),
      'A replay graph survives destruction of the original model/source context.');
  finally
    lReplay.Free;
    lDocument.Free;
  end;
  lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; Feature A {} }');
  lReplay := nil;
  try
    AContext.AssertTrue(not FileExists(lDocument.Live.SourceName), 'The overlay source was never a disk file.');
    lReplay := TNXSetupLoader.LoadFile(lDocument.Live.SourceName, lDocument.SourceContext);
    FreeAndNil(lDocument);
    AContext.AssertEquals('P', lReplay.Product.Id, 'Recompilation can only read the retained original overlay.');
  finally
    lReplay.Free;
    lDocument.Free;
  end;
end;

procedure TestPrivateRequirements(AContext: TNXTestContext);
var
  lDocument, lReplay: TNXSetupDocument;
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
begin
  lDocument := LoadText('module Tools "Private.nxscript"; ' +
    'Product P { Id: P; Name: P; Version: 1; Feature Main { Default: True; ' +
    'Requires: [First: @Tools.Host, Second: @Tools.Host]; } }');
  lApplicable := AllFeatures(lDocument);
  lSelection := nil;
  lReplay := nil;
  try
    lSelection := TNXSetupSelection.Create(lDocument, lApplicable);
    lSelection.SelectDefaults;
    AContext.AssertEquals(1, lDocument.Live.Roots.Count, 'A reachable private product is not another public root.');
    AContext.AssertTrue(lDocument.FindFeature('Main').Dependencies[0] =
      lDocument.FindFeature('Main').Dependencies[1], 'Repeated imports preserve shared native dependency identity.');
    AContext.AssertEquals(2, lSelection.Dependencies.Count, 'The complete private dependency cycle is collected once.');
    lReplay := TNXSetupLoader.LoadFile(lDocument.Live.SourceName, lDocument.SourceContext);
    AContext.AssertEquals(2, lReplay.Dependencies.Count, 'The retained module source recompiles its private targets.');
  finally
    lReplay.Free;
    lSelection.Free;
    lApplicable.Free;
    lDocument.Free;
  end;
end;

procedure TestPatternReplay(AContext: TNXTestContext);
var
  lContext: TNXSetupSourceContext;
  lSession: TNexusScriptCompilationSession;
  lTargets: TNexusScriptTargetSelection;
  lEntry: string;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('Target', 'Dev');
  lContext := TNXSetupSourceContext.Create(nil, lTargets);
  lSession := nil;
  try
    lEntry := ExpandFileName('packages/nxscript/test/fixtures/include-collections/targets/Entry.nxscript');
    lSession := TNexusScriptCompilationSession.Create(lTargets, lContext);
    AContext.AssertTrue(lSession.CompileFile(lEntry), lSession.LastError);
    AContext.AssertTrue(lContext.Selections.Count > 0, 'Source context retains the compiler file selection.');
    FreeAndNil(lSession);
    lContext.Freeze;
    lSession := TNexusScriptCompilationSession.Create(lContext.Targets, lContext);
    AContext.AssertTrue(lSession.CompileFile(lEntry), lSession.LastError);
    AContext.AssertTrue(lSession.EntryCompiler.CompiledDocument.Definitions.Count > 0,
      'Frozen sources and recorded wildcard selection recompile through the common compiler.');
  finally
    lSession.Free;
    lContext.Free;
    lTargets.Free;
  end;
end;

procedure TestLocationErrors(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lLocations: TNXSetupLocations;
  lRejected: Boolean;
begin
  lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; ' +
    'Location A { Kind: Derived; Base: @P.B; } Location B { Kind: Derived; Base: @P.A; } }');
  lLocations := TNXSetupLocations.Create;
  try
    lRejected := False;
    try lLocations.Resolve(lDocument.Locations[0]);
    except on lError: ENXSetup do lRejected := Pos('concrete base', lError.Message) > 0; end;
    AContext.AssertTrue(lRejected, 'A legal reference cycle cannot supply a concrete physical path.');
    lRejected := False;
    try TNXSetupLocations.RelativePath(ExpandFileName('output/setup-plan-only'), '../outside');
    except on lError: ENXSetup do lRejected := Pos('escapes', lError.Message) > 0; end;
    AContext.AssertTrue(lRejected, 'Relative paths cannot escape the declared destination boundary.');
  finally
    lLocations.Free;
    lDocument.Free;
  end;
end;

procedure TestValidationAndFailure(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lRejected: Boolean;
begin
  lDocument := nil;
  try
    lRejected := False;
    try lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; ' +
      'Feature A { Requires: [@P.B]; } Feature B { Requires: [@P.A]; Wrong: invalid; } }');
    except on lError: ENXSetup do lRejected := Pos('Wrong', lError.Message) > 0; end;
    AContext.AssertTrue(lRejected, 'Validation checks the entire cyclic target, not only the initial back-edge.');
    lRejected := False;
    try lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; } Product Q { Id: Q; Name: Q; Version: 1; }');
    except on lError: ENXSetup do lRejected := Pos('one product', lError.Message) > 0; end;
    AContext.AssertTrue(lRejected, 'Failed native construction returns no half-owned snapshot.');
  finally
    lDocument.Free;
  end;
end;

procedure TestConflictingDefaults(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
  lRejected: Boolean;
begin
  lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; ChildMode: Exclusive; ' +
    'Feature A { Default: True; } Feature B { Default: True; } }');
  lApplicable := AllFeatures(lDocument);
  lSelection := nil;
  try
    lSelection := TNXSetupSelection.Create(lDocument, lApplicable);
    lRejected := False;
    try lSelection.SelectDefaults;
    except on lError: ENXSetup do lRejected := Pos('conflict', lError.Message) > 0; end;
    AContext.AssertTrue(lRejected, 'Conflicting defaults are reported; no priority policy is invented.');
    AContext.AssertEquals(0, lSelection.Selected.Count, 'A rejected initial candidate does not partially commit.');
  finally
    lSelection.Free;
    lApplicable.Free;
    lDocument.Free;
  end;
end;

procedure TestBranchSelection(AContext: TNXTestContext);
var
  lDocument: TNXSetupDocument;
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
  lReason: string;
begin
  lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; ' +
    'Feature A { Feature Child { Required: True; } Feature Optional {} } ' +
    'Feature B { Feature Client { Requires: [@P.A.Optional]; } } }');
  lApplicable := AllFeatures(lDocument);
  lSelection := nil;
  try
    lSelection := TNXSetupSelection.Create(lDocument, lApplicable);
    AContext.AssertEquals(0, lSelection.Selected.Count, 'Required children do not activate an unselected branch.');
    AContext.AssertTrue(lSelection.SetSelected(lDocument.FindFeature('Client'), True, lReason), lReason);
    AContext.AssertEquals(5, lSelection.Selected.Count, 'Requirements include target ancestors and required branch children.');
    AContext.AssertTrue(not lSelection.SetSelected(lDocument.FindFeature('A'), False, lReason),
      'An outside dependent prevents clearing its required branch.');
    AContext.AssertTrue(lSelection.SetSelected(lDocument.FindFeature('B'), False, lReason), lReason);
    AContext.AssertEquals(0, lSelection.Selected.Count, 'Clearing a parent clears explicit descendant seeds and their closure.');
    AContext.AssertTrue(lSelection.SetSelected(lDocument.FindFeature('A'), True, lReason), lReason);
    AContext.AssertEquals(2, lSelection.Selected.Count, 'A parent selects required children, not every optional child.');
  finally
    lSelection.Free;
    lApplicable.Free;
    lDocument.Free;
  end;
end;

procedure WriteTestFile(const AFileName, AText: string);
var
  lStream: TStringStream;
begin
  if not ForceDirectories(ExtractFileDir(AFileName)) then raise Exception.Create('Cannot prepare test payload.');
  lStream := TStringStream.Create(AText);
  try lStream.SaveToFile(AFileName); finally lStream.Free; end;
end;

function ReadTestFile(const AFileName: string): string;
var
  lStream: TStringStream;
begin
  lStream := TStringStream.Create('');
  try lStream.LoadFromFile(AFileName); Result := lStream.DataString; finally lStream.Free; end;
end;

function InstallScript(const ASource: string): string;
begin
  Result := 'Product Files { Id: "Nexus.Setup.FileTest"; Name: "File test"; Version: 1; ' +
    'Location App { Kind: ApplicationRoot; } Feature Main { Default: True; ' +
    'File Application { Source: "' + ASource + '/app.txt"; Location: @Files.App; Path: "app.txt"; } ' +
    'File Configuration { Source: "' + ASource + '/config.txt"; Location: @Files.App; Path: "config.txt"; PreserveExisting: True; KeepOnUninstall: True; } ' +
    'File Seed { Source: "' + ASource + '/config.txt"; Location: @Files.App; Path: "seed.cfg"; PreserveExisting: True; KeepOnUninstall: True; } ' +
    'Directory Data { Source: "' + ASource + '/data"; Location: @Files.App; Path: "data"; } } ' +
    'Feature Optional { File O { Source: "' + ASource + '/optional.txt"; Location: @Files.App; } } }';
end;

function FilePlan(ADocument: TNXSetupDocument; const ARoot: string): TNXSetupPlan;
var
  lApplicable: TList<TNXSetupFeature>;
  lSelection: TNXSetupSelection;
  lLocations: TNXSetupLocations;
begin
  lApplicable := AllFeatures(ADocument);
  lSelection := nil;
  lLocations := TNXSetupLocations.Create;
  try
    lSelection := TNXSetupSelection.Create(ADocument, lApplicable);
    lSelection.SelectDefaults;
    lLocations.Bind('ApplicationRoot', ARoot);
    Result := TNXSetupPlan.Build(lSelection, lLocations);
  finally
    lLocations.Free;
    lSelection.Free;
    lApplicable.Free;
  end;
end;

procedure PreparePayload(const ASource: string);
begin
  WriteTestFile(ASource + '/app.txt', 'application one' + #10);
  WriteTestFile(ASource + '/config.txt', 'initial configuration' + #10);
  WriteTestFile(ASource + '/data/sub/value.txt', 'nested payload' + #10);
  WriteTestFile(ASource + '/optional.txt', 'optional payload' + #10);
  if not ForceDirectories(ASource + '/data/empty') then raise Exception.Create('Cannot prepare empty directory.');
end;

procedure TestFileLifecycle(AContext: TNXTestContext);
var
  lWork, lRoot, lSource, lStateFile: string;
  lDocument: TNXSetupDocument;
  lPlan: TNXSetupPlan;
  lState: TNXSetupState;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lSource := StringReplace(lWork + '/source', '\', '/', [rfReplaceAll]);
  lRoot := ExpandFileName(lWork + '/installed');
  lDocument := nil;
  lPlan := nil;
  lState := nil;
  try
    PreparePayload(lSource);
    WriteTestFile(lRoot + '/config.txt', 'existing user configuration');
    WriteTestFile(lRoot + '/unrelated.txt', 'not installed');
    lDocument := LoadText(InstallScript(lSource));
    lPlan := FilePlan(lDocument, lRoot);
    lStateFile := TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot);
    AContext.AssertEquals('application one' + #10, ReadTestFile(lRoot + '/app.txt'), 'Installation copies exact bytes.');
    AContext.AssertEquals('nested payload' + #10, ReadTestFile(lRoot + '/data/sub/value.txt'), 'Directory structure is preserved.');
    AContext.AssertTrue(DirectoryExists(lRoot + '/data/empty'), 'Empty payload directories are installed.');
    AContext.AssertTrue(not FileExists(lRoot + '/optional.txt'), 'Unselected owners do not install.');
    lState := TNXSetupState.LoadFile(lStateFile);
    AContext.AssertEquals(3, lState.Files.Count, 'Evidence records only files actually installed.');
    AContext.AssertTrue(lState.FindFile(lRoot + '/config.txt') = nil, 'A preserved preexisting file is not adopted.');
    FreeAndNil(lState);
    WriteTestFile(lRoot + '/app.txt', 'locally modified application');
    WriteTestFile(lRoot + '/seed.cfg', 'user changed seeded data');
    WriteTestFile(lSource + '/app.txt', 'application two' + #10);
    TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot);
    AContext.AssertEquals('application two' + #10, ReadTestFile(lRoot + '/app.txt'), 'Upgrade replaces ordinary unversioned application payload.');
    AContext.AssertEquals('user changed seeded data', ReadTestFile(lRoot + '/seed.cfg'), 'Explicit preservation survives upgrade.');
    RemoveSetupFile(lRoot + '/app.txt');
    TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot, '', True);
    AContext.AssertEquals('application two' + #10, ReadTestFile(lRoot + '/app.txt'), 'Repair restores missing application content.');
    TNXSetupFileInstaller.Uninstall(lStateFile);
    AContext.AssertTrue(not FileExists(lRoot + '/app.txt'), 'Uninstall removes recorded application files.');
    AContext.AssertTrue(not DirectoryExists(lRoot + '/data'), 'Uninstall removes empty installer-created directories.');
    AContext.AssertEquals('existing user configuration', ReadTestFile(lRoot + '/config.txt'), 'Uninstall preserves skipped files.');
    AContext.AssertEquals('user changed seeded data', ReadTestFile(lRoot + '/seed.cfg'), 'Uninstall honors explicit retention.');
    AContext.AssertEquals('not installed', ReadTestFile(lRoot + '/unrelated.txt'), 'Uninstall never sweeps unrelated contents.');
    AContext.AssertTrue(not FileExists(lStateFile), 'Successful uninstall removes active installation evidence.');
  finally
    lState.Free;
    lPlan.Free;
    lDocument.Free;
    RemoveSetupTree(lWork);
  end;
end;

procedure TestFilePreflight(AContext: TNXTestContext);
var
  lWork, lRoot: string;
  lDocument: TNXSetupDocument;
  lPlan: TNXSetupPlan;
  lRejected: Boolean;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lRoot := ExpandFileName(lWork + '/not-created');
  lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; Location App { Kind: ApplicationRoot; } ' +
    'Feature A { Default: True; File Missing { Source: "not-present"; Location: @P.App; } } }');
  lPlan := nil;
  try
    lPlan := FilePlan(lDocument, lRoot);
    lRejected := False;
    try TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot);
    except on lError: ENXSetup do lRejected := Pos('missing', lError.Message) > 0; end;
    AContext.AssertTrue(lRejected, 'A missing payload is an explicit failure.');
    AContext.AssertTrue(not DirectoryExists(lRoot), 'Preflight failure creates no destination/state directories.');
    FreeAndNil(lPlan);
    FreeAndNil(lDocument);
    lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; Feature A { Default: True; Requires: [@P.D]; } Dependency D { Ownership: Owned; MSI Install {} } }');
    lPlan := FilePlan(lDocument, lRoot);
    lRejected := False;
    try TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot);
    except on lError: ENXSetup do lRejected := Pos('providers', lError.Message) > 0; end;
    AContext.AssertTrue(lRejected, 'Secondary providers cannot be silently treated as success.');
    AContext.AssertTrue(not DirectoryExists(lRoot), 'Unsupported selected providers fail before writes.');
  finally
    lPlan.Free;
    lDocument.Free;
    RemoveSetupTree(lWork);
  end;
end;

{$ifdef windows}
procedure TestFileRollback(AContext: TNXTestContext);
var
  lWork, lRoot, lSource: string;
  lDocument: TNXSetupDocument;
  lPlan: TNXSetupPlan;
  lLocked: TFileStream;
  lRejected: Boolean;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lRoot := ExpandFileName(lWork + '/installed');
  lSource := StringReplace(lWork + '/source', '\', '/', [rfReplaceAll]);
  lDocument := nil;
  lPlan := nil;
  lLocked := nil;
  try
    WriteTestFile(lSource + '/first.txt', 'new first');
    WriteTestFile(lSource + '/locked.txt', 'second');
    WriteTestFile(lRoot + '/first.txt', 'original first');
    lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; Location App { Kind: ApplicationRoot; } Feature A { Default: True; ' +
      'File First { Source: "' + lSource + '/first.txt"; Location: @P.App; Path: "first.txt"; } ' +
      'File Second { Source: "' + lSource + '/locked.txt"; Location: @P.App; Path: "nested/second.txt"; } } }');
    lPlan := FilePlan(lDocument, lRoot);
    lLocked := TFileStream.Create(lSource + '/locked.txt', fmOpenRead or fmShareExclusive);
    lRejected := False;
    try TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot);
    except on lError: EFOpenError do lRejected := True; end;
    AContext.AssertTrue(lRejected, 'A locked second source fails after the first replacement.');
    AContext.AssertEquals('original first', ReadTestFile(lRoot + '/first.txt'), 'Rollback restores the replaced file.');
    AContext.AssertTrue(not DirectoryExists(lRoot + '/nested'), 'Rollback removes only newly created empty payload directories.');
    AContext.AssertTrue(not FileExists(TNXSetupState.Folder(lRoot, 'P') + '/installation'), 'Failed installation publishes no success evidence.');
  finally
    lLocked.Free;
    lPlan.Free;
    lDocument.Free;
    RemoveSetupTree(lWork);
  end;
end;
{$endif}

procedure TestJournalRecovery(AContext: TNXTestContext);
var
  lWork, lRoot, lFolder, lTransaction, lTarget: string;
  lStream: TFileStream;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lRoot := ExpandFileName(lWork + '/installed');
  lFolder := TNXSetupState.Folder(lRoot, 'P');
  try
    if not ForceDirectories(lFolder) then raise Exception.Create('Cannot prepare journal fixture.');
    lTransaction := SetupWorkFolder(lFolder);
    lTarget := lRoot + '/application.txt';
    WriteTestFile(lTarget, 'interrupted replacement');
    WriteTestFile(lTransaction + '/1.backup', 'previous application');
    if not CreateDir(lRoot + '/added') then raise Exception.Create('Cannot prepare recovery directory.');
    lStream := TFileStream.Create(lFolder + '/journal', fmCreate);
    try
      WriteText(lStream, 'NXJournal1');
      WriteText(lStream, ExtractFileName(lTransaction));
      WriteNumber(lStream, 0);
      WriteNumber(lStream, 1);
      WriteText(lStream, lTarget);
      WriteText(lStream, lTarget + '.nxnew-fixture');
      WriteText(lStream, '1.backup');
      WriteNumber(lStream, 1);
      WriteText(lStream, lRoot + '/added');
    finally
      lStream.Free;
    end;
    TNXSetupFileInstaller.Recover(lFolder);
    AContext.AssertEquals('previous application', ReadTestFile(lTarget), 'Explicit recovery uses the durable journal, not the live model.');
    AContext.AssertTrue(not DirectoryExists(lRoot + '/added'), 'Recovery removes recorded newly created directories.');
    AContext.AssertTrue(not FileExists(lFolder + '/journal'), 'A recovered journal is retired.');
    TNXSetupFileInstaller.Recover(lFolder);
    AContext.AssertEquals('previous application', ReadTestFile(lTarget), 'Recovery is safe to repeat.');
  finally
    RemoveSetupTree(lWork);
  end;
end;

procedure WriteVersionFile(const AFileName: string; AMajor: Word);
var
  lResources: TResources;
  lResource: TVersionResource;
  lVersion: TFileProductVersion;
begin
  lResources := TResources.Create;
  try
    lResource := TVersionResource.Create;
    lResources.Add(lResource);
    FillChar(lVersion, SizeOf(lVersion), 0);
    lVersion[0] := AMajor;
    lResource.FixedInfo.FileVersion := lVersion;
    lResources.WriteToFile(AFileName);
  finally
    lResources.Free;
  end;
end;

procedure TestVersionPolicy(AContext: TNXTestContext);
var
  lWork, lOld, lNew, lPlain: string;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  try
    lOld := lWork + '/old.res';
    lNew := lWork + '/new.res';
    lPlain := lWork + '/plain.txt';
    WriteVersionFile(lOld, 1);
    WriteVersionFile(lNew, 2);
    WriteTestFile(lPlain, 'plain');
    AContext.AssertTrue(FileNeedsReplacement(lNew, lOld, False, False, False), 'Newer versions replace older versions.');
    AContext.AssertTrue(not FileNeedsReplacement(lOld, lNew, False, False, False), 'Older versions do not replace newer versions.');
    AContext.AssertTrue(not FileNeedsReplacement(lNew, lNew, False, False, False), 'Same-version normal installs skip replacement.');
    AContext.AssertTrue(FileNeedsReplacement(lNew, lNew, False, False, True), 'Repair can restore same-version payload.');
    AContext.AssertTrue(not FileNeedsReplacement(lPlain, lNew, False, False, False), 'Unversioned files do not replace versioned destinations.');
    AContext.AssertTrue(FileNeedsReplacement(lOld, lNew, False, True, False), 'Explicit version override permits replacement.');
    AContext.AssertTrue(not FileNeedsReplacement(lNew, lOld, True, True, True), 'Explicit preservation wins even during repair.');
  finally
    RemoveSetupTree(lWork);
  end;
end;

procedure TestExecutableBundle(AContext: TNXTestContext);
var
  lWork, lSource, lRoot, lExecutable, lStateFile, lCache: string;
  lDocument: TNXSetupDocument;
  lBundle: TNXSetupBundle;
  lPlan: TNXSetupPlan;
  lStream: TFileStream;
  lRejected: Boolean;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lSource := StringReplace(lWork + '/source', '\', '/', [rfReplaceAll]);
  lRoot := ExpandFileName(lWork + '/installed');
  lExecutable := lWork + '/Setup.exe';
  lDocument := nil;
  lBundle := nil;
  lPlan := nil;
  try
    PreparePayload(lSource);
    lDocument := LoadText(InstallScript(lSource));
    TNXSetupBundle.Build(lDocument, ParamStr(0), lExecutable);
    FreeAndNil(lDocument);
    RemoveSetupTree(lSource);
    AContext.AssertTrue(TNXSetupBundle.HasPayload(lExecutable), 'The executable ends with a discoverable reverse footer.');
    lBundle := TNXSetupBundle.OpenExecutable(lExecutable);
    lDocument := lBundle.LoadDocument;
    AContext.AssertEquals('Nexus.Setup.FileTest', lDocument.Product.Id, 'Original entry and dialect compile without the source checkout.');
    lPlan := FilePlan(lDocument, lRoot);
    lPlan.RelocateSources(lBundle.Payloads);
    lStateFile := TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot, lBundle.ArchiveFile);
    AContext.AssertEquals('application one' + #10, ReadTestFile(lRoot + '/app.txt'), 'Packaged payload installs without original files.');
    FreeAndNil(lPlan);
    FreeAndNil(lDocument);
    FreeAndNil(lBundle);
    lStream := TFileStream.Create(lExecutable, fmOpenReadWrite);
    try lStream.Position := lStream.Size - 24; WriteNumber(lStream, High(QWord)); finally lStream.Free; end;
    lRejected := False;
    try lBundle := TNXSetupBundle.OpenExecutable(lExecutable);
    except on lError: ENXSetup do lRejected := Pos('footer', lError.Message) > 0; end;
    AContext.AssertTrue(lRejected, 'An invalid archive offset is rejected.');
    RemoveSetupFile(lExecutable);
    RemoveSetupFile(lRoot + '/app.txt');
    lCache := ExtractFileDir(lStateFile) + '/payload.zip';
    lBundle := TNXSetupBundle.OpenArchive(lCache);
    lDocument := lBundle.LoadDocument;
    lPlan := FilePlan(lDocument, lRoot);
    lPlan.RelocateSources(lBundle.Payloads);
    TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot, lBundle.ArchiveFile, True);
    AContext.AssertEquals('application one' + #10, ReadTestFile(lRoot + '/app.txt'), 'Repair uses retained payload/source after the original installer is removed.');
    TNXSetupFileInstaller.Uninstall(lStateFile);
    AContext.AssertTrue(not FileExists(lRoot + '/app.txt'), 'Uninstall depends on installed evidence, not original scripts.');
  finally
    lPlan.Free;
    lDocument.Free;
    lBundle.Free;
    RemoveSetupTree(lWork);
  end;
end;

procedure TestPortableSourceContext(AContext: TNXTestContext);
var
  lWork, lEntry, lDefinitions, lExecutable, lText, lCapturedText: string;
  lDocument: TNXSetupDocument;
  lBundle: TNXSetupBundle;
  lContext: TNXSetupSourceContext;
  lFirst, lSecond: TMemoryStream;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lEntry := lWork + '/entry.nxscript';
  lDefinitions := lWork + '/definitions.nxscript';
  lExecutable := lWork + '/Setup.exe';
  lDocument := nil;
  lBundle := nil;
  lContext := nil;
  lFirst := TMemoryStream.Create;
  lSecond := TMemoryStream.Create;
  try
    lText := '// original LF, UTF-8: ' + #$C3#$A9 + #10 +
      'dialect "' + StringReplace(ExpandFileName('projects/setup/language/Setup.Language.nxscript'), '\', '/', [rfReplaceAll]) + '";' + #13#10 +
      'include "' + StringReplace(lDefinitions, '\', '/', [rfReplaceAll]) + '";' + #10;
    WriteTestFile(lEntry, lText);
    WriteTestFile(lDefinitions, 'Product P { Id: "Portable"; Name: "Portable"; Version: 1; }');
    lDocument := TNXSetupLoader.LoadFile(lEntry);
    lCapturedText := lDocument.SourceContext.Sources[0].Text;
    lDocument.SourceContext.SaveToStream(lFirst);
    lFirst.Position := 0;
    lContext := TNXSetupSourceContext.LoadFromStream(lFirst);
    lContext.SaveToStream(lSecond);
    AContext.AssertEquals(lFirst.Size, lSecond.Size, 'Source snapshot round-trip has identical length.');
    AContext.AssertTrue(CompareByte(lFirst.Memory^, lSecond.Memory^, lFirst.Size) = 0,
      'Source bytes, virtual names, target values and selection records survive unchanged.');
    TNXSetupBundle.Build(lDocument, ParamStr(0), lExecutable);
    FreeAndNil(lDocument);
    RemoveSetupFile(lEntry);
    RemoveSetupFile(lDefinitions);
    lBundle := TNXSetupBundle.OpenExecutable(lExecutable);
    lDocument := lBundle.LoadDocument;
    AContext.AssertEquals('Portable', lDocument.Product.Id, 'Absolute dialect/include identities replay from frozen sources.');
    AContext.AssertEquals(lCapturedText, lDocument.SourceContext.Sources[0].Text,
      'Recompilation preserves the source text captured by the compiler.');
  finally
    lSecond.Free;
    lFirst.Free;
    lContext.Free;
    lDocument.Free;
    lBundle.Free;
    RemoveSetupTree(lWork);
  end;
end;

procedure TestRetainedChoices(AContext: TNXTestContext);
var
  lWork, lSource, lRoot, lExtra, lExecutable, lStateFile, lReason: string;
  lDocument: TNXSetupDocument;
  lSession: TNXSetupSession;
  lState: TNXSetupState;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lSource := StringReplace(lWork + '/source', '\', '/', [rfReplaceAll]);
  lRoot := ExpandFileName(lWork + '/installed');
  lExtra := ExpandFileName(lWork + '/user-data');
  lExecutable := lWork + '/Setup.exe';
  lDocument := nil;
  lSession := nil;
  lState := nil;
  try
    PreparePayload(lSource);
    lDocument := LoadText('Product P { Id: "ChoiceTest"; Name: "Choices"; Version: 1; ' +
      'Location App { Kind: ApplicationRoot; } Location Data { Kind: UserData; } ' +
      'Feature Main { Default: True; File F { Source: "' + lSource +
      '/app.txt"; Location: @P.App; } } Feature Optional { ' +
      'File F { Source: "' + lSource + '/optional.txt"; Location: @P.App; } ' +
      'File D { Source: "' + lSource + '/optional.txt"; Location: @P.Data; } } }');
    TNXSetupBundle.Build(lDocument, ParamStr(0), lExecutable);
    FreeAndNil(lDocument);
    RemoveSetupTree(lSource);
    lSession := TNXSetupSession.OpenExecutable(lExecutable);
    lSession.Root := lRoot;
    lSession.Locations.Bind('UserData', lExtra);
    AContext.AssertTrue(lSession.Selection.SetSelected(
      lSession.Document.FindFeature('Optional'), True, lReason), lReason);
    AContext.AssertTrue(lSession.Selection.SetSelected(
      lSession.Document.FindFeature('Main'), False, lReason), lReason);
    lStateFile := lSession.Install;
    FreeAndNil(lSession);
    lState := TNXSetupState.LoadFile(lStateFile);
    AContext.AssertEquals(1, lState.Seeds.Count, 'Installed choices record explicit seeds, not fresh defaults.');
    AContext.AssertEquals(2, lState.Bindings.Count, 'Installation retains concrete scenario bindings.');
    FreeAndNil(lState);
    RemoveSetupFile(lExecutable);
    RemoveSetupFile(lRoot + '/optional.txt');
    RemoveSetupFile(lExtra + '/optional.txt');
    TNXSetupSession.Repair(lStateFile);
    AContext.AssertTrue(not FileExists(lRoot + '/app.txt'), 'Repair does not reselect a cleared default feature.');
    AContext.AssertEquals('optional payload' + #10, ReadTestFile(lRoot + '/optional.txt'), 'Repair restores a chosen optional feature.');
    AContext.AssertEquals('optional payload' + #10, ReadTestFile(lExtra + '/optional.txt'), 'Repair reuses the saved non-root location.');
    TNXSetupFileInstaller.Uninstall(lStateFile);
    AContext.AssertTrue(not FileExists(lExtra + '/optional.txt'), 'Uninstall removes recorded files at explicit locations.');
  finally
    lState.Free;
    lSession.Free;
    lDocument.Free;
    RemoveSetupTree(lWork);
  end;
end;

procedure TestArchiveBoundary(AContext: TNXTestContext);
var
  lWork, lArchive: string;
  lZip: TZipper;
  lBytes: TStringStream;
  lBundle: TNXSetupBundle;
  lRejected: Boolean;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lArchive := lWork + '/malformed.zip';
  lZip := TZipper.Create;
  lBytes := TStringStream.Create('not a payload');
  lBundle := nil;
  try
    lZip.FileName := lArchive;
    lZip.Entries.AddFileEntry(lBytes, '../outside.txt');
    lZip.ZipAllFiles;
    lRejected := False;
    try lBundle := TNXSetupBundle.OpenArchive(lArchive);
    except on lError: ENXSetup do lRejected := True; end;
    AContext.AssertTrue(lRejected, 'Archive traversal is rejected before extraction.');
    AContext.AssertTrue(not FileExists(lWork + '/outside.txt'), 'An invalid archive writes nothing outside owned extraction.');
    lZip.Entries.Clear;
    lBytes.Position := 0;
    lZip.Entries.AddFileEntry(lBytes, 'payload.zip');
    lZip.ZipAllFiles;
    lRejected := False;
    try lBundle := TNXSetupBundle.OpenArchive(lArchive);
    except on lError: ENXSetup do lRejected := True; end;
    AContext.AssertTrue(lRejected, 'An archive cannot overwrite its own extraction input.');
  finally
    lBundle.Free;
    lBytes.Free;
    lZip.Free;
    RemoveSetupTree(lWork);
  end;
end;


procedure TestDestinationSafety(AContext: TNXTestContext);
var
  lWork, lRoot, lSource: string;

  procedure RejectDestination(const AFiles, AReason: string);
  var
    lDocument: TNXSetupDocument;
    lPlan: TNXSetupPlan;
    lRejected: Boolean;
  begin
    lDocument := LoadText('Product P { Id: P; Name: P; Version: 1; Location App { Kind: ApplicationRoot; } ' +
      'Feature Main { Default: True; ' + AFiles + ' } }');
    lPlan := nil;
    try
      lPlan := FilePlan(lDocument, lRoot);
      lRejected := False;
      try TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot);
      except on lError: ENXSetup do lRejected := Pos(AReason, lError.Message) > 0; end;
      AContext.AssertTrue(lRejected, 'Unsafe destinations are diagnosed before execution.');
      AContext.AssertTrue(not DirectoryExists(lRoot), 'Rejected paths publish no destination or state.');
    finally
      lPlan.Free;
      lDocument.Free;
    end;
  end;

begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lRoot := ExpandFileName(lWork + '/installed');
  lSource := StringReplace(lWork + '/source.txt', '\', '/', [rfReplaceAll]);
  try
    WriteTestFile(lSource, 'payload');
    RejectDestination('File First { Source: "' + lSource + '"; Location: @P.App; Path: nested; } ' +
      'File Second { Source: "' + lSource + '"; Location: @P.App; Path: "nested/value.txt"; }', 'overlap');
    RejectDestination('File F { Source: "' + lSource +
      '"; Location: @P.App; Path: ".nx/setup/another-product/installation"; }', 'private');
    {$ifdef windows}
    AContext.AssertTrue(not IsAbsolutePath('C:relative'), 'Drive-relative paths are not absolute bindings.');
    AContext.AssertTrue(not IsAbsolutePath('\relative'), 'Current-drive rooted paths are not fully qualified.');
    {$endif}
  finally
    RemoveSetupTree(lWork);
  end;
end;

procedure TestRetentionUpgrade(AContext: TNXTestContext);
var
  lWork, lRoot, lSource, lStateFile: string;
  lDocument: TNXSetupDocument;
  lPlan: TNXSetupPlan;
  lState: TNXSetupState;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lSource := StringReplace(lWork + '/source', '\', '/', [rfReplaceAll]);
  lRoot := ExpandFileName(lWork + '/installed');
  lDocument := nil;
  lPlan := nil;
  lState := nil;
  try
    PreparePayload(lSource);
    WriteTestFile(lRoot + '/config.txt', 'user configuration');
    lDocument := LoadText(InstallScript(lSource));
    lPlan := FilePlan(lDocument, lRoot);
    lStateFile := TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot);
    FreeAndNil(lPlan);
    FreeAndNil(lDocument);
    lDocument := LoadText(StringReplace(InstallScript(lSource),
      'KeepOnUninstall: True', 'KeepOnUninstall: False', [rfReplaceAll]));
    lPlan := FilePlan(lDocument, lRoot);
    TNXSetupFileInstaller.Install(lDocument, lPlan, lRoot);
    lState := TNXSetupState.LoadFile(lStateFile);
    AContext.AssertTrue(not lState.FindFile(lRoot + '/seed.cfg').KeepOnUninstall,
      'Upgrade updates policy even when preservation skips an already-owned file.');
    AContext.AssertTrue(lState.FindFile(lRoot + '/config.txt') = nil, 'Skipped user files remain unowned.');
    TNXSetupFileInstaller.Uninstall(lStateFile);
    AContext.AssertTrue(not FileExists(lRoot + '/seed.cfg'), 'Updated retention policy controls removal.');
    AContext.AssertEquals('user configuration', ReadTestFile(lRoot + '/config.txt'), 'Unowned user data survives.');
  finally
    lState.Free;
    lPlan.Free;
    lDocument.Free;
    RemoveSetupTree(lWork);
  end;
end;

procedure RegisterSetupTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusSetup');
  lSuite.AddTest('NativeModelAndLifetime', @TestModel);
  lSuite.AddTest('SelectionClosure', @TestSelection);
  lSuite.AddTest('ExclusiveChildren', @TestExclusive);
  lSuite.AddTest('ExplicitApplicability', @TestApplicability);
  lSuite.AddTest('ResolvedPlan', @TestResolvedPlan);
  lSuite.AddTest('DependencyCycles', @TestDependencyCycles);
  lSuite.AddTest('RetainedSourceReplay', @TestSourceReplay);
  lSuite.AddTest('PrivateModuleRequirements', @TestPrivateRequirements);
  lSuite.AddTest('RetainedPatternReplay', @TestPatternReplay);
  lSuite.AddTest('LocationErrors', @TestLocationErrors);
  lSuite.AddTest('ValidationAndFailureCleanup', @TestValidationAndFailure);
  lSuite.AddTest('ConflictingDefaults', @TestConflictingDefaults);
  lSuite.AddTest('ParentBranchSelection', @TestBranchSelection);
  lSuite.AddTest('FileInstallUpgradeRepairUninstall', @TestFileLifecycle);
  lSuite.AddTest('FilePreflight', @TestFilePreflight);
  {$ifdef windows}lSuite.AddTest('FileRollback', @TestFileRollback);{$endif}
  lSuite.AddTest('InterruptedJournalRecovery', @TestJournalRecovery);
  lSuite.AddTest('VersionReplacementPolicy', @TestVersionPolicy);
  lSuite.AddTest('ExecutableTailAndRetainedPayload', @TestExecutableBundle);
  lSuite.AddTest('RepairRetainsChoicesAndLocations', @TestRetainedChoices);
  lSuite.AddTest('ArchiveExtractionBoundary', @TestArchiveBoundary);
  lSuite.AddTest('PortableOriginalSourceContext', @TestPortableSourceContext);
  lSuite.AddTest('DestinationPathSafety', @TestDestinationSafety);
  lSuite.AddTest('OwnedRetentionPolicyUpgrade', @TestRetentionUpgrade);
end;

end.
