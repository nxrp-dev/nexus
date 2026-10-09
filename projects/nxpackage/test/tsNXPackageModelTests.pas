(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXPackageModelTests;

{$mode delphi}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterPackageModelTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes, SysUtils, obNXTestContext, obNXTestSuite, obNXPackageDocument,
  obNexusScriptEditDocument, obNexusScriptModel;

type
  TRecordingPackageProvider = class(TNXPackageSourceProvider)
  private
    FAllowedNames, FRequests, FModules: TStringList;
  protected
    procedure RecordRequest(const ASourceName: string);
  public
    constructor Create(const AEntryName, ADialectName, ALanguageName: string);
    destructor Destroy; override;
    function Exists(const ASourceName: string): Boolean; override;
    function ReadSource(const ASourceName: string; out AText: string;
      out AVersion: Integer): Boolean; override;
    function SelectFiles(const AFolderName, AFileNamePattern: string;
      ARecursive: Boolean): TStringList; override;
    procedure SetModule(const AName, AText: string);
    property Requests: TStringList read FRequests;
  end;

constructor TRecordingPackageProvider.Create(const AEntryName, ADialectName,
  ALanguageName: string);
begin
  inherited Create;
  FAllowedNames := TStringList.Create;
  FAllowedNames.Add(CanonicalName(AEntryName));
  FAllowedNames.Add(CanonicalName(ADialectName));
  FAllowedNames.Add(CanonicalName(ALanguageName));
  FRequests := TStringList.Create;
  FModules := TStringList.Create;
end;

destructor TRecordingPackageProvider.Destroy;
begin
  FModules.Free;
  FRequests.Free;
  FAllowedNames.Free;
  inherited Destroy;
end;

procedure TRecordingPackageProvider.RecordRequest(const ASourceName: string);
var
  lName: string;
begin
  lName := CanonicalName(ASourceName);
  if FAllowedNames.IndexOf(lName) < 0 then
    raise Exception.Create('Unexpected source access: ' + ASourceName);
  if FRequests.IndexOf(lName) < 0 then FRequests.Add(lName);
end;

function TRecordingPackageProvider.Exists(const ASourceName: string): Boolean;
begin
  RecordRequest(ASourceName);
  Result := (FModules.IndexOfName(CanonicalName(ASourceName)) >= 0) or inherited Exists(ASourceName);
end;

function TRecordingPackageProvider.ReadSource(const ASourceName: string;
  out AText: string; out AVersion: Integer): Boolean;
var
  lIndex: Integer;
begin
  RecordRequest(ASourceName);
  lIndex := FModules.IndexOfName(CanonicalName(ASourceName));
  if lIndex >= 0 then
  begin
    AText := FModules.ValueFromIndex[lIndex];
    AVersion := 1;
    Exit(True);
  end;
  Result := inherited ReadSource(ASourceName, AText, AVersion);
end;

procedure TRecordingPackageProvider.SetModule(const AName, AText: string);
begin
  FAllowedNames.Add(CanonicalName(AName));
  FModules.Values[CanonicalName(AName)] := AText;
end;

function TRecordingPackageProvider.SelectFiles(const AFolderName,
  AFileNamePattern: string; ARecursive: Boolean): TStringList;
begin
  Result := nil;
  raise Exception.Create('Package declarations must not cause a directory scan');
end;

function Root: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '../../../');
end;

function DialectName: string;
begin
  Result := Root + 'projects/nxpackage/language/nxpackage.Language.nxscript';
end;

function Source(const ABody: string): string;
begin
  Result := 'dialect ' + TNexusScriptEditDocument.QuoteText(DialectName) + ';' +
    LineEnding + ABody;
end;

procedure CheckSource(AContext: TNXTestContext; const ABody: string;
  AValid: Boolean; const ACode: string = '');
var
  lDocument: TNXPackageDocument;
  lSource: string;
begin
  lDocument := TNXPackageDocument.Create;
  try
    lSource := Source(ABody);
    lDocument.LoadSource(Root + 'output/nxpackageTests/model/Draft.nxscript', lSource);
    if AValid then AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text)
    else
    begin
      AContext.AssertFalse(lDocument.Validate, 'Invalid declaration was accepted: ' + ABody);
      AContext.AssertTrue(lDocument.Diagnostics.Count > 0);
      if ACode <> '' then AContext.AssertTrue(Pos(ACode, lDocument.Diagnostics.Text) > 0,
        lDocument.Diagnostics.Text);
      AContext.AssertTrue(lDocument.CompiledDocument = nil);
    end;
    AContext.AssertEquals(lSource, lDocument.SourceText, 'Validation must not rewrite the draft.');
  finally
    lDocument.Free;
  end;
end;

procedure CheckWithIndex(AContext: TNXTestContext; const ABody, AIndexBody: string;
  AValid: Boolean; const ACode: string = ''; const AOtherIndexBody: string = '');
var
  lDocument: TNXPackageDocument;
  lProvider: TRecordingPackageProvider;
  lEntryName, lIndexName, lOtherName, lSource: string;
  lValid: Boolean;
begin
  lEntryName := Root + 'output/nxpackageTests/model/Package.nxscript';
  lIndexName := Root + 'output/nxpackageTests/model/Index.nxscript';
  lProvider := TRecordingPackageProvider.Create(lEntryName, DialectName,
    Root + 'packages/nexus-packages/nxscript/language/Language.nxscript');
  lDocument := TNXPackageDocument.Create(lProvider);
  try
    lProvider.SetModule(lIndexName, Source(AIndexBody));
    lSource := 'module I ' + TNexusScriptEditDocument.QuoteText(lIndexName) + ';' + LineEnding;
    if AOtherIndexBody <> '' then
    begin
      lOtherName := Root + 'output/nxpackageTests/model/OtherIndex.nxscript';
      lProvider.SetModule(lOtherName, Source(AOtherIndexBody));
      lSource := lSource + 'module J ' + TNexusScriptEditDocument.QuoteText(lOtherName) + ';' + LineEnding;
    end;
    lSource := Source(lSource + ABody);
    lDocument.LoadSource(lEntryName, lSource);
    lValid := lDocument.Validate;
    if AValid then AContext.AssertTrue(lValid, lDocument.Diagnostics.Text)
    else AContext.AssertFalse(lValid, lDocument.Diagnostics.Text);
    if ACode <> '' then
      AContext.AssertTrue(Pos(ACode, lDocument.Diagnostics.Text) > 0, lDocument.Diagnostics.Text);
    AContext.AssertEquals(lSource, lDocument.SourceText, 'Binding does not rewrite source.');
    if AValid then AContext.AssertEquals('Package', lDocument.EntityType);
  finally
    lDocument.Free;
  end;
end;

procedure TestRequirements(AContext: TNXTestContext);
const
  cIndex = 'PackageIndex I { TrustedRepository Repo { Source: "https://offline.invalid/repo.git"; } ' +
    'LocalPackage Local { Id: "NXRP.Local"; Descriptor: "missing/Package.nxscript"; } ' +
    'ExternalPackage External { Id: "External.P"; Repository: @I.Repo; } }';
begin
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; }', True);
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: []; }', True);
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Local, @I.External]; }', cIndex, True);
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [Alias: @I.Local]; }', cIndex, True);
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: ["Unknown.P"]; }', False, 'NSV2405');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Local.Id]; }', cIndex, False, 'NSV2406');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Repo]; }', cIndex, False, 'NSV2408');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Missing]; }', cIndex, False, 'NXS5001');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Local]; }', cIndex,
    False, 'package-index-ambiguous', 'PackageIndex J {}');
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: [' +
    'LocalPackage L { Id: "NXRP.L"; Descriptor: "L.nxscript"; }]; }', False, 'NSV2405');
end;

procedure TestImportedIndexValidation(AContext: TNXTestContext);
begin
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.L]; }',
    'PackageIndex I { LocalPackage L { Id: "NXRP.L"; } }', False, 'NSV2101');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.L]; }',
    'PackageIndex I { LocalPackage L { Id: " "; Descriptor: "L.nxscript"; } }', False, 'package-entry-id-empty');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.E]; }',
    'PackageIndex I { TrustedRepository R { Source: " "; } ' +
    'ExternalPackage E { Id: "External.P"; Repository: @I.R; } }', False, 'package-repository-source-empty');
end;

procedure TestReferenceProvenance(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
  lPackage, lRecord, lRepository: TNexusScriptCompiledDefinition;
  lRequires: TNexusScriptCompiledValue;
  lValid: Boolean;
begin
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.Load(Root + 'projects/nxpackage/examples/Package.nxscript');
    lValid := lDocument.Validate;
    AContext.AssertTrue(lValid, lDocument.Diagnostics.Text);
    AContext.AssertEquals('Package', lDocument.EntityType);
    lPackage := lDocument.CompiledDocument.FindDefinition('Example');
    lRequires := lPackage.FindProperty('Requires').Value;
    lRecord := lRequires.Items[0].ResolvedDefinition;
    AContext.AssertEquals('LocalPackage', lRecord.Kind);
    AContext.AssertEquals('NXRP.NexusLib', lRecord.FindProperty('Id').Value.EffectiveText);
    AContext.AssertEquals('RepositoryIndex', lRecord.Parent.Kind);
    lRecord := lRequires.Items[1].ResolvedDefinition;
    AContext.AssertEquals('ExternalPackage', lRecord.Kind);
    AContext.AssertEquals('SQLite.SQLite', lRecord.FindProperty('Id').Value.EffectiveText);
    lRepository := lRecord.FindProperty('Repository').Value.ResolvedDefinition;
    AContext.AssertEquals('TrustedRepository', lRepository.Kind);
    AContext.AssertEquals('<canonical source-control address of nexus-packages-ext>',
      lRepository.FindProperty('Source').Value.EffectiveText);
    AContext.AssertEquals('RepositoryIndex', lRepository.Parent.Kind);
  finally
    lDocument.Free;
  end;
end;

procedure TestMetadata(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
  lPackage: TNexusScriptCompiledDefinition;
begin
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.Load(Root + 'projects/nxpackage/examples/Package.nxscript');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lPackage := lDocument.CompiledDocument.FindDefinition('Example');
    AContext.AssertEquals('NXRP.NexusScript', lPackage.FindProperty('Id').Value.EffectiveText);
    AContext.AssertEquals('1.0', lPackage.FindProperty('Version').Value.EffectiveText);
    AContext.AssertEquals('Kevin Collins', lPackage.FindProperty('Author').Value.EffectiveText);
    AContext.AssertEquals('Illustrative NexusScript package descriptor.',
      lPackage.FindProperty('Description').Value.EffectiveText);
    AContext.AssertEquals('MPL-2.0-no-copyleft-exception',
      lPackage.FindProperty('License').Value.EffectiveText);
    lDocument.SourceText := Source('Package DifferentLabel { Id: "NXRP.NexusScript"; ' +
      'Version: "an unordered release label"; License: "another license label"; }');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertEquals('NXRP.NexusScript',
      lDocument.CompiledDocument.Definitions[0].FindProperty('Id').Value.EffectiveText);
  finally
    lDocument.Free;
  end;
end;

procedure TestOpaqueIdentities(AContext: TNXTestContext);
const
  cIds: array[0..5] of string = ('NXRP.NexusScript', 'NXRP.NexusScript.Win64',
    'NxRp.MixedCase', 'FreePascal.FPC', 'NXRP.FPC', ' opaque:unchanged ');
var
  lDocument: TNXPackageDocument;
  lId: string;
begin
  lDocument := TNXPackageDocument.Create;
  try
    for lId in cIds do
    begin
      lDocument.LoadSource(Root + 'output/nxpackageTests/model/Identity.nxscript',
        Source('Package UnrelatedLabel { Id: ' + TNexusScriptEditDocument.QuoteText(lId) + '; }'));
      AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
      AContext.AssertEquals(lId,
        lDocument.CompiledDocument.Definitions[0].FindProperty('Id').Value.EffectiveText);
    end;
  finally
    lDocument.Free;
  end;
end;

// Retained unchanged at the owner's request; this earlier fixture is paused.
procedure TestDependencies(AContext: TNXTestContext);
begin
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; }', True);
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: []; }', True);
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: ["Unknown.P", "SQLite.SQLite"]; }', True);
  CheckSource(AContext, 'Package Base { Id: "NXRP.Base"; Requires: ["Unknown.P"]; } ' +
    'Package P { Id: "NXRP.P"; Requires: @Base.Requires; }', True);
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: [""]; }', False, 'package-requires-empty');
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: ["   "]; }', False, 'package-requires-empty');
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: "Unknown.P"; }', False, 'NSV2302');
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: [alias: "Unknown.P"]; }', False, 'NSV2404');
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Requires: [' +
    'Dependency D { Id: "Unknown.P"; Repository: "https://untrusted.invalid"; }]; }', False);
end;

procedure TestPackageBoundary(AContext: TNXTestContext);
const
  cForbidden: array[0..9] of string = ('TargetOS', 'TargetCPU', 'Compiler', 'Output',
    'Source', 'Order', 'Repository', 'Discovery', 'AutoResolve', 'Hash');
var
  lName: string;
begin
  CheckSource(AContext, 'Package P {}', False, 'NSV2101');
  CheckSource(AContext, 'Package P { Id: "   "; }', False, 'package-id-empty');
  CheckSource(AContext, 'package P { Id: "   "; }', False, 'package-id-empty');
  CheckSource(AContext, 'Package P { Id: []; }', False, 'NSV2302');
  for lName in cForbidden do
    CheckSource(AContext, 'Package P { Id: "NXRP.P"; ' + lName + ': "forbidden"; }', False, 'NSV2102');
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; Version: []; }', False, 'NSV2302');
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; ' +
    'LocalPackage E { Id: "Unknown.P"; Descriptor: "P.nxscript"; } }', False, 'NSV2003');
end;

procedure TestIndexDeclarations(AContext: TNXTestContext);
begin
  CheckSource(AContext, 'PackageIndex I {}', True);
  CheckSource(AContext, 'PackageIndex I { TrustedRepository R { Source: "https://offline.invalid/repo.git"; } ' +
    'LocalPackage Label { Id: "NXRP.P"; Descriptor: "missing/P.nxscript"; Version: "1"; Description: "Catalog"; } ' +
    'ExternalPackage Other { Id: "External.P"; Repository: @I.R; Version: "opaque"; } }', True);
end;

procedure TestIndexValidation(AContext: TNXTestContext);
const
  cInvalidPaths: array[0..7] of string = ('/absolute/P.nxscript', '\\server\P.nxscript',
    'C:\P.nxscript', 'https://untrusted.invalid/P.nxscript', '*.nxscript', 'folder/', '.', '..');
var
  lPath: string;
begin
  CheckSource(AContext, 'PackageIndex I { Discovery: []; }', False, 'NSV2102');
  CheckSource(AContext, 'PackageIndex I { TrustedRepository R { Source: ""; } }',
    False, 'package-repository-source-empty');
  CheckSource(AContext, 'packageindex I { trustedrepository R { Source: " "; } }',
    False, 'package-repository-source-empty');
  CheckSource(AContext, 'PackageIndex I { LocalPackage E { Descriptor: "P.nxscript"; } }', False, 'NSV2101');
  CheckSource(AContext, 'PackageIndex I { LocalPackage E { Id: "NXRP.P"; } }', False, 'NSV2101');
  CheckSource(AContext, 'PackageIndex I { LocalPackage E { Id: " "; Descriptor: "P.nxscript"; } }',
    False, 'package-entry-id-empty');
  CheckSource(AContext, 'PackageIndex I { LocalPackage E { Id: "NXRP.P"; Descriptor: " "; } }',
    False, 'package-descriptor-empty');
  for lPath in cInvalidPaths do
    CheckSource(AContext, 'PackageIndex I { LocalPackage E { Id: "NXRP.P"; Descriptor: ' +
      TNexusScriptEditDocument.QuoteText(lPath) + '; } }', False, 'package-descriptor-relative');
  CheckSource(AContext, 'PackageIndex I { Requires: []; }', False, 'NSV2102');
  CheckSource(AContext, 'PackageIndex I { LocalPackage E { Id: "NXRP.P"; Descriptor: "P.nxscript"; ' +
    'Repository: "https://untrusted.invalid"; } }', False, 'NSV2102');
  CheckSource(AContext, 'LocalPackage E { Id: "NXRP.P"; Descriptor: "P.nxscript"; }', False, 'NSV2002');
  CheckSource(AContext, 'PackageIndex I { Package P { Id: "NXRP.P"; } }', False, 'NSV2004');
  CheckSource(AContext, 'PackageIndex I { PackageEntry E { Id: "NXRP.P"; Descriptor: "P.nxscript"; } }',
    False, 'NSV2001');
  CheckSource(AContext, 'PackageIndex I { LocalPackage E { Id: "NXRP.P"; Descriptor: "P.nxscript"; ' +
    'Author: "not catalog metadata"; } }', False, 'NSV2102');
end;

procedure TestRepositoryReferences(AContext: TNXTestContext);
const
  cPrefix = 'PackageIndex I { TrustedRepository R { Source: "https://offline.invalid/canonical.git"; } ';
begin
  CheckSource(AContext, cPrefix + 'ExternalPackage E { Id: "External.P"; Repository: @I.R; } }', True);
  CheckSource(AContext, cPrefix + 'ExternalPackage E { Id: "External.P"; } }', False, 'NSV2101');
  CheckSource(AContext, cPrefix + 'ExternalPackage E { Id: "External.P"; Repository: "repo"; } }', False, 'NSV2301');
  CheckSource(AContext, cPrefix + 'ExternalPackage E { Id: "External.P"; Repository: [@I.R]; } }', False, 'NSV2301');
  CheckSource(AContext, cPrefix + 'ExternalPackage E { Id: "External.P"; Repository: @I.R.Source; } }', False);
  CheckSource(AContext, cPrefix + 'LocalPackage L { Id: "NXRP.L"; Descriptor: "L.nxscript"; } ' +
    'ExternalPackage E { Id: "External.P"; Repository: @I.L; } }', False, 'NSV3003');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; }',
    'module J ' + TNexusScriptEditDocument.QuoteText(
      Root + 'output/nxpackageTests/model/OtherIndex.nxscript') + '; ' +
    'PackageIndex I { ExternalPackage E { Id: "External.P"; Repository: @J.R; } }',
    False, 'package-repository-owner', 'PackageIndex J { TrustedRepository R { Source: "repo"; } }');
end;

procedure TestContentHash(AContext: TNXTestContext);
const
  cEntry = 'PackageIndex I { LocalPackage E { Id: "NXRP.P"; Descriptor: "P.nxscript"; ';
var
  lDocument: TNXPackageDocument;
  lEntry, lHash: TNexusScriptCompiledDefinition;
begin
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.Load(Root + 'projects/nxpackage/test/fixtures/IndexWithHash.nxscript');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lEntry := lDocument.CompiledDocument.Definitions[0].Children[0];
    lHash := lEntry.Children[0];
    AContext.AssertEquals('SQLite.SQLite', lEntry.FindProperty('Id').Value.EffectiveText);
    AContext.AssertEquals('synthetic-test-algorithm', lHash.FindProperty('Algorithm').Value.EffectiveText);
    AContext.AssertEquals('synthetic-test-digest', lHash.FindProperty('Digest').Value.EffectiveText);
  finally
    lDocument.Free;
  end;
  CheckSource(AContext, cEntry + 'ContentHash H { Algorithm: "synthetic"; Digest: "data"; } } }', True);
  CheckSource(AContext, cEntry + 'ContentHash H { Digest: "data"; } } }', False, 'NSV2101');
  CheckSource(AContext, cEntry + 'ContentHash H { Algorithm: "synthetic"; } } }', False, 'NSV2101');
  CheckSource(AContext, cEntry + 'ContentHash H { Algorithm: " "; Digest: "data"; } } }',
    False, 'package-hash-algorithm-empty');
  CheckSource(AContext, cEntry + 'ContentHash H { Algorithm: "synthetic"; Digest: " "; } } }',
    False, 'package-hash-digest-empty');
  CheckSource(AContext, cEntry + 'ContentHash H { Algorithm: "synthetic"; Digest: "one"; } ' +
    'ContentHash Other { Algorithm: "synthetic"; Digest: "two"; } } }', False, 'NSV2202');
  CheckSource(AContext, 'ContentHash H { Algorithm: "synthetic"; Digest: "data"; }', False, 'NSV2002');
  CheckSource(AContext, 'PackageIndex I { ContentHash H { Algorithm: "synthetic"; Digest: "data"; } }',
    False, 'NSV2003');
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; ' +
    'ContentHash H { Algorithm: "synthetic"; Digest: "data"; } }', False, 'NSV2003');
end;

procedure TestRepositoryRoles(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
  lIndex, lEntry: TNexusScriptCompiledDefinition;
begin
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.Load(Root + 'projects/nxpackage/examples/PackageIndex.nxscript');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lIndex := lDocument.CompiledDocument.Definitions[0];
    AContext.AssertEquals(4, lIndex.Children.Count);
    AContext.AssertEquals('<canonical source-control address of nexus-packages-ext>',
      lIndex.FindChild('ExternalPackages').FindProperty('Source').Value.EffectiveText);
    AContext.AssertEquals('NXRP.NexusScript', lIndex.FindChild('NexusScript').FindProperty('Id').Value.EffectiveText);
    AContext.AssertEquals('ExternalPackage', lIndex.FindChild('SQLite').Kind);
    lDocument.Load(Root + 'projects/nxpackage/examples/ExternalRepositoryIndex.nxscript');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lIndex := lDocument.CompiledDocument.Definitions[0];
    AContext.AssertEquals('RepositoryIndex', lDocument.EntityType);
    AContext.AssertEquals(1, lIndex.Children.Count, 'There is no reciprocal trust declaration.');
    lEntry := lIndex.Children[0];
    AContext.AssertEquals('LocalPackage', lEntry.Kind, 'Local means housed here, not authored by us.');
    AContext.AssertEquals('SQLite.SQLite', lEntry.FindProperty('Id').Value.EffectiveText);
    AContext.AssertEquals('ExternalPackage.nxscript', lEntry.FindProperty('Descriptor').Value.EffectiveText);
    lDocument.Load(Root + 'projects/nxpackage/examples/ExternalPackage.nxscript');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertEquals('SQLite.SQLite',
      lDocument.CompiledDocument.Definitions[0].FindProperty('Id').Value.EffectiveText);
    AContext.AssertEquals('External author (illustrative)',
      lDocument.CompiledDocument.Definitions[0].FindProperty('Author').Value.EffectiveText);
  finally
    lDocument.Free;
  end;
end;

procedure CheckNoImplicitReads(AContext: TNXTestContext; const AKind: string);
var
  lProvider: TRecordingPackageProvider;
  lDocument: TNXPackageDocument;
  lEntryName, lIndexName, lIndexSource: string;
begin
  lEntryName := Root + 'output/nxpackageTests/model/Offline.nxscript';
  lIndexName := Root + 'output/nxpackageTests/model/OfflineIndex.nxscript';
  lProvider := TRecordingPackageProvider.Create(lEntryName, DialectName,
    Root + 'packages/nexus-packages/nxscript/language/Language.nxscript');
  lDocument := TNXPackageDocument.Create(lProvider);
  try
    lIndexSource := Source(AKind + ' I { ' +
      'TrustedRepository R { Source: "https://unreachable.invalid/nexus-packages-ext"; } ' +
      'LocalPackage L { Id: "Unknown.P"; Descriptor: "missing/P.nxscript"; } ' +
      'ExternalPackage E { Id: "External.P"; Repository: @I.R; } }');
    lDocument.LoadSource(lEntryName, lIndexSource);
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertEquals(3, lProvider.Requests.Count, 'Only entry and two dialect sources are accessed.');
    lProvider.SetModule(lIndexName, lIndexSource);
    lDocument.LoadSource(lEntryName, Source('module I ' +
      TNexusScriptEditDocument.QuoteText(lIndexName) + '; ' +
      'Package Offline { Id: "NXRP.P"; Requires: [@I.L, @I.E]; }'));
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertEquals(4, lProvider.Requests.Count, 'The explicitly imported index is the only additional source.');
  finally
    lDocument.Free;
  end;
end;

procedure TestNoImplicitReads(AContext: TNXTestContext);
begin
  CheckNoImplicitReads(AContext, 'PackageIndex');
end;

procedure TestRepositoryNoImplicitReads(AContext: TNXTestContext);
begin
  CheckNoImplicitReads(AContext, 'RepositoryIndex');
end;

procedure TestRootBoundary(AContext: TNXTestContext);
begin
  CheckSource(AContext, 'Package P { Id: "NXRP.P"; }', True);
  CheckSource(AContext, 'PackageIndex I {}', True);
  CheckSource(AContext, 'RepositoryIndex I {}', True);
  CheckSource(AContext, 'Project P {}', False, 'NSV2001');
  CheckSource(AContext, 'PackageIndex I { RepositoryIndex R {} }', False);
  CheckSource(AContext, 'RepositoryIndex I { PackageIndex P {} }', False);
end;

procedure TestRepositoryIndex(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
begin
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.Load(Root + 'projects/nxpackage/examples/RepositoryIndex.nxscript');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertEquals('RepositoryIndex', lDocument.EntityType);
    AContext.AssertEquals(4, lDocument.CompiledDocument.Definitions[0].Children.Count);
  finally
    lDocument.Free;
  end;
  CheckSource(AContext, 'RepositoryIndex I { LocalPackage P { Id: "NXRP.P"; } }',
    False, 'NSV2101');
  CheckSource(AContext, 'RepositoryIndex I { LocalPackage P { Id: " "; Descriptor: "P.nxscript"; } }',
    False, 'package-entry-id-empty');
  CheckSource(AContext, 'RepositoryIndex I { LocalPackage P { Id: "NXRP.P"; Descriptor: "/P.nxscript"; } }',
    False, 'package-descriptor-relative');
  CheckSource(AContext, 'RepositoryIndex I { TrustedRepository R { Source: " "; } }',
    False, 'package-repository-source-empty');
  CheckSource(AContext, 'RepositoryIndex I { LocalPackage P { Id: "NXRP.P"; Descriptor: "P.nxscript"; ' +
    'ContentHash H { Algorithm: "synthetic"; Digest: "data"; } } }', True);
  CheckSource(AContext, 'RepositoryIndex I { LocalPackage P { Id: "NXRP.P"; Descriptor: "P.nxscript"; ' +
    'ContentHash H { Algorithm: "synthetic"; Digest: " "; } } }', False, 'package-hash-digest-empty');
  CheckSource(AContext, 'RepositoryIndex I { Requires: []; }', False, 'NSV2102');
  CheckSource(AContext, 'RepositoryIndex I { Package P { Id: "NXRP.P"; } }', False, 'NSV2004');
end;

procedure TestRepositoryRequirements(AContext: TNXTestContext);
const
  cIndex = 'RepositoryIndex I { TrustedRepository Repo { Source: "https://offline.invalid/repo.git"; } ' +
    'LocalPackage Local { Id: "NXRP.Local"; Descriptor: "missing/Package.nxscript"; } ' +
    'ExternalPackage External { Id: "External.P"; Repository: @I.Repo; } }';
begin
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Local, @I.External]; }', cIndex, True);
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Local.Id]; }', cIndex, False, 'NSV2406');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Repo]; }', cIndex, False, 'NSV2408');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Local]; }', cIndex,
    False, 'package-index-ambiguous', 'PackageIndex J {}');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.Local]; }', cIndex,
    False, 'package-index-ambiguous', 'RepositoryIndex J {}');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; Requires: [@I.L]; }',
    'RepositoryIndex I { LocalPackage L { Id: "NXRP.L"; } }', False, 'NSV2101');
  CheckWithIndex(AContext, 'Package P { Id: "NXRP.P"; }',
    'module J ' + TNexusScriptEditDocument.QuoteText(
      Root + 'output/nxpackageTests/model/OtherIndex.nxscript') + '; ' +
    'RepositoryIndex I { ExternalPackage E { Id: "External.P"; Repository: @J.R; } }',
    False, 'package-repository-owner', 'RepositoryIndex J { TrustedRepository R { Source: "repo"; } }');
end;

procedure RegisterPackageModelTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('PackageModel');
  lSuite.AddTest('Metadata', @TestMetadata);
  lSuite.AddTest('OpaqueIdentities', @TestOpaqueIdentities);
  // TestDependencies remains paused and is deliberately not executed.
  lSuite.AddTest('Requirements', @TestRequirements);
  lSuite.AddTest('ImportedIndexValidation', @TestImportedIndexValidation);
  lSuite.AddTest('ReferenceProvenance', @TestReferenceProvenance);
  lSuite.AddTest('RepositoryReferences', @TestRepositoryReferences);
  lSuite.AddTest('PackageBoundary', @TestPackageBoundary);
  lSuite.AddTest('IndexDeclarations', @TestIndexDeclarations);
  lSuite.AddTest('IndexValidation', @TestIndexValidation);
  lSuite.AddTest('ContentHash', @TestContentHash);
  lSuite.AddTest('RepositoryRoles', @TestRepositoryRoles);
  lSuite.AddTest('NoImplicitReads', @TestNoImplicitReads);
  lSuite.AddTest('RepositoryNoImplicitReads', @TestRepositoryNoImplicitReads);
  lSuite.AddTest('RootBoundary', @TestRootBoundary);
  lSuite.AddTest('RepositoryIndex', @TestRepositoryIndex);
  lSuite.AddTest('RepositoryRequirements', @TestRepositoryRequirements);
end;

end.
