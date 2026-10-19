(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit tsNXForgeContractTests;

{$mode delphi}{$H+}

interface

uses obNXTestSuite;

procedure RegisterForgeContractTests(ASuite: TNXTestSuite);

implementation

uses Classes, SysUtils, obNXTestContext, obNXForge, obNXForgeInvocation,
  obNexusScriptModel, obNexusScriptSession;

function Root: string;
begin
  Result := IncludeTrailingPathDelimiter(GetCurrentDir);
  if not FileExists(Result + 'projects/forge/language/Forge.nxscript') then
    raise Exception.Create('Run NexusForgeTests from the Nexus repository root.');
end;

function NewDirectory: string;
var
  lId: TGUID;
begin
  CreateGUID(lId);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'ForgeComposition/tests/' + GUIDToString(lId) + '/';
  ForceDirectories(Result);
end;

procedure Save(const APath, AText: string);
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(APath, fmCreate);
  try
    if AText <> '' then lStream.WriteBuffer(AText[1], Length(AText));
  finally
    lStream.Free;
  end;
end;

function DocumentText(const ABody: string): string;
begin
  Result := 'dialect "' + StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/language/Forge.nxscript"; ' + ABody;
end;

procedure TestContractOrder(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := NewDirectory;
  Save(lDirectory + 'Build.nxscript', DocumentText(
    'Project Application { Id: "NXRP.Application"; Outputs: ["complete.txt"]; ' +
    'Package Dependency { Id: "NXRP.Dependency"; UnitPaths: ["generated"]; ' +
    'WriteTextFile Generate { Path: "generated.txt"; Text: "contents"; } ' +
    'Group Verify { CopyFile Copy { Source: "generated.txt"; Destination: "verified.txt"; } ' +
    'CompareFiles Validate { Left: "generated.txt"; Right: "verified.txt"; } } } ' +
    'CopyFile Complete { Source: "verified.txt"; Destination: "complete.txt"; } }'));
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(4, lForge.Invocations.Count, 'One shared ordered list');
    AContext.AssertEquals('Generate', lForge.Invocations[0].OperationName);
    AContext.AssertEquals('Validate', lForge.Invocations[2].OperationName);
    AContext.AssertEquals('Complete', lForge.Invocations[3].OperationName);
    AContext.AssertTrue(FileExists(lDirectory + 'complete.txt'), 'Parent follows package verification');
  finally
    lForge.Free;
  end;
end;

procedure TestContractFailure(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := NewDirectory;
  Save(lDirectory + 'Build.nxscript', DocumentText(
    'Project Application { Id: "NXRP.Application"; ' +
    'Package Dependency { Id: "NXRP.Dependency"; ' +
    'WriteTextFile One { Path: "one.txt"; Text: "one"; } ' +
    'WriteTextFile Two { Path: "two.txt"; Text: "two"; } ' +
    'CompareFiles Verify { Left: "one.txt"; Right: "two.txt"; } ' +
    'WriteTextFile Inner { Path: "inner.txt"; Text: "must not run"; } } ' +
    'WriteTextFile Outer { Path: "outer.txt"; Text: "must not run"; } }'));
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Validation fails the enclosing build');
    AContext.AssertTrue(Pos('Verify', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AContext.AssertFalse(lForge.Invocations[3].Started, 'Package stops');
    AContext.AssertFalse(lForge.Invocations[4].Started, 'Project stops');
    AContext.AssertFalse(FileExists(lDirectory + 'outer.txt'), 'No success artifact');
  finally
    lForge.Free;
  end;
end;

procedure TestContractInspection(AContext: TNXTestContext);
var
  lDirectory: string;
  lSession: TNexusScriptCompilationSession;
  lDefinition: TNexusScriptCompiledDefinition;
begin
  lDirectory := NewDirectory;
  Save(lDirectory + 'Build.nxscript', DocumentText(
    'Package Library { Id: "NXRP.Library"; Outputs: ["future.dll"]; ' +
    'IncludePaths: ["generated"]; UnitPaths: ["units"]; LibraryPaths: ["native"]; ' +
    'FPC Compile { Template: "not-created.mustache"; Source: ["future.pas"]; ' +
    'EntryPoint: "future.pas"; } }'));
  lSession := TNexusScriptCompilationSession.Create;
  try
    CompileForgeDocument(lSession, lDirectory + 'Build.nxscript');
    lDefinition := lSession.EntryCompiler.CompiledDocument.FindDefinition('Library');
    AContext.AssertEquals('NXRP.Library', ForgePropertyText(lDefinition, 'Id'));
    AContext.AssertEquals('future.dll', lDefinition.FindProperty('Outputs').Value.SemanticValue.Items[0].EffectiveText);
    AContext.AssertEquals(1, lDefinition.Children.Count, 'Build remains available without preparing or executing');
    AContext.AssertFalse(FileExists(lDirectory + 'future.dll'), 'Inspection has no side effects');
  finally
    lSession.Free;
  end;
end;

procedure TestContractRules(AContext: TNXTestContext);
const
  cInvalid: array[0..6] of string = (
    'Project P { Id: "P"; IncludePaths: ["private"]; }',
    'Project P { Id: "P"; UnitPaths: ["private"]; }',
    'Project P { Id: "P"; LibraryPaths: ["private"]; }',
    'Package P { Id: "P"; Outputs: "file"; }',
    'Package P { Id: "P"; Requires: ["unresolved identity"]; }',
    'Package P { Id: " "; }',
    'Project P { Outputs: []; }');
var
  lDirectory, lBody: string;
  lForge: TNXForge;
  lInvocation: TNXForgeInvocation;
begin
  lDirectory := NewDirectory;
  lForge := TNXForge.Create;
  try
    for lBody in cInvalid do
    begin
      Save(lDirectory + 'Build.nxscript', DocumentText(lBody));
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), lBody);
      for lInvocation in lForge.Invocations do
        AContext.AssertFalse(lInvocation.Started, 'Invalid contract prevents execution');
    end;
    Save(lDirectory + 'Build.nxscript', DocumentText('Project P { Id: "P"; Outputs: []; }'));
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(0, lForge.Invocations.Count, 'No implicit Pascal compilation');
  finally
    lForge.Free;
  end;
end;

procedure TestImportedPackage(AContext: TNXTestContext);
var
  lDirectory, lTemplates: string;
  lForge: TNXForge;
begin
  lDirectory := NewDirectory;
  lTemplates := StringReplace(Root, '\', '/', [rfReplaceAll]) + 'projects/forge/templates/';
  ForceDirectories(lDirectory + 'library');
  Save(lDirectory + 'library/Index.nxscript', DocumentText(
    'PackageIndex Catalog { LocalPackage Support { Id: "Support"; Descriptor: "Support.nxscript"; } }'));
  Save(lDirectory + 'library/Package.nxscript', DocumentText(
    'module Catalog "Index.nxscript"; ' +
    'Package Library { Id: "NXRP.Library"; Requires: [@Catalog.Support]; ' +
    'UnitPaths: ["units"]; IncludePaths: ["include"]; ' +
    'Outputs: [Header: "include/value.inc"]; ' +
    'WriteTextFile Header { Path: @Library.Outputs.Header; Text: "const TheValue = 42;"; } ' +
    'WriteTextFile UnitSource { Path: "units/GeneratedUnit.pas"; ' +
    'Text: "unit GeneratedUnit; interface {$i value.inc} implementation end."; } }'));
  Save(lDirectory + 'main.pas', 'program main; uses GeneratedUnit; begin if TheValue <> 42 then Halt(7); end.');
  Save(lDirectory + 'Build.nxscript', DocumentText(
    'module Library "library/Package.nxscript"; ' +
    'Project Application { Id: "NXRP.Application"; Outputs: [Binary: "main.exe"]; ' +
    'Package Prepare (Library) {} ' +
    'FPC Compile { Template: "' + lTemplates + 'FPC.mustache"; ' +
    'Source: ["main.pas"]; EntryPoint: "main.pas"; Output: @Application.Outputs.Binary; ' +
    'UnitPaths: @Library.UnitPaths; IncludePaths: @Library.IncludePaths; } ' +
    'Run Verify { Template: "' + lTemplates + 'Run.mustache"; Executable: @Application.Outputs.Binary; } }'));
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(4, lForge.Invocations.Count, 'Imported definition executes only through explicit composition');
    AContext.AssertTrue(FileExists(lDirectory + 'library/units/GeneratedUnit.pas'), 'Package child retains its source directory');
    AContext.AssertTrue(Pos(ExpandFileName(lDirectory + 'library/units'), lForge.Invocations[2].Command) > 0,
      'Exported unit paths retain package origin');
    AContext.AssertEquals(0, lForge.Invocations[3].ExitStatus, 'Program consumed generated unit and include');
    Save(lDirectory + 'library/Index.nxscript', DocumentText(
      'PackageIndex Catalog { LocalPackage Support { Id: "Support"; Descriptor: "https://invalid/support"; } }'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Composed package retains its catalog validation');
    AContext.AssertTrue(Pos('package-descriptor-relative', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AContext.AssertEquals(0, lForge.Invocations.Count, 'Invalid imported package contract blocks preparation');
  finally
    lForge.Free;
  end;
end;

procedure TestContractTargets(AContext: TNXTestContext);
var
  lDirectory: string;
  lTargets: TNexusScriptTargetSelection;
  lForge: TNXForge;
begin
  lDirectory := NewDirectory;
  Save(lDirectory + 'Build.nxscript', DocumentText(
    'Project App Mode[One] { Id: "One"; WriteTextFile Selected { Path: "one.txt"; Text: "one"; } } ' +
    'Project App Mode[Two] { Id: "Two"; WriteTextFile Inactive { Path: "two.txt"; Text: "two"; } }'));
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('Mode', 'One');
  lForge := TNXForge.Create(lTargets);
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(1, lForge.Invocations.Count, 'Only the selected project executes');
    AContext.AssertTrue(FileExists(lDirectory + 'one.txt'), 'Selected output exists');
    AContext.AssertFalse(FileExists(lDirectory + 'two.txt'), 'Inactive project stays inactive');
  finally
    lForge.Free;
    lTargets.Free;
  end;
end;

procedure TestContractRequirements(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := NewDirectory;
  Save(lDirectory + 'Index.nxscript', DocumentText(
    'PackageIndex Catalog { LocalPackage Lib { Id: "NXRP.Lib"; Descriptor: "missing/Package.nxscript"; } }'));
  Save(lDirectory + 'Build.nxscript', DocumentText(
    'module Catalog "Index.nxscript"; ' +
    'Project Application { Id: "NXRP.App"; Requires: [@Catalog.Lib]; ' +
    'Package Library { Id: "NXRP.Library"; Requires: [@Catalog.Lib]; } ' +
    'WriteTextFile Done { Path: "done.txt"; Text: "done"; } }'));
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(1, lForge.Invocations.Count, 'Catalog reference does not acquire or build anything');
    Save(lDirectory + 'Index.nxscript', DocumentText(
      'PackageIndex Catalog { LocalPackage Lib { Id: "NXRP.Lib"; Descriptor: "https://invalid/Package.nxscript"; } }'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Invalid imported catalog blocks execution');
    AContext.AssertTrue(Pos('package-descriptor-relative', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AContext.AssertEquals(0, lForge.Invocations.Count, 'Common contract validation happens before preparation');
  finally
    lForge.Free;
  end;
end;

procedure TestUnrelatedDialect(AContext: TNXTestContext);
var
  lDirectory: string;
  lSession: TNexusScriptCompilationSession;
begin
  lDirectory := NewDirectory;
  Save(lDirectory + 'DataLanguage.nxscript',
    'Language Data { Definitions: [Definition Package { Root: True; ' +
    'Properties: [Property Requires { Value Value { EffectiveCategories: [Array]; ' +
    'Array Array { EntryEffectiveCategories: [Text]; } } }]; }]; }');
  Save(lDirectory + 'Data.nxscript', 'dialect "DataLanguage.nxscript"; ' +
    'Package Data { Requires: ["ordinary data, not package requirements"]; }');
  lSession := TNexusScriptCompilationSession.Create;
  try
    CompileForgeDocument(lSession, lDirectory + 'Data.nxscript');
    AContext.AssertTrue(lSession.EntryCompiler.CompiledDocument.FindDefinition('Data') <> nil,
      'Generic render-source inspection respects the source dialect');
  finally
    lSession.Free;
  end;
end;
procedure RegisterForgeContractTests(ASuite: TNXTestSuite);
begin
  ASuite.AddTest('ImportedPackage', @TestImportedPackage);
  ASuite.AddTest('ContractTargets', @TestContractTargets);
  ASuite.AddTest('ContractRequirements', @TestContractRequirements);
  ASuite.AddTest('UnrelatedDialect', @TestUnrelatedDialect);
  ASuite.AddTest('ContractOrder', @TestContractOrder);
  ASuite.AddTest('ContractFailure', @TestContractFailure);
  ASuite.AddTest('ContractInspection', @TestContractInspection);
  ASuite.AddTest('ContractRules', @TestContractRules);
end;

end.
