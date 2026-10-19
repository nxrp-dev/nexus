// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXProjectDocumentTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterNXProjectDocumentTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, SysUtils, obNXTestContext, obNXTestSuite, obNXPackageDocument;

function Dialect: string;
begin
  Result := 'dialect "' + StringReplace(ExpandFileName(
    'projects/nxbuild/language/nxbuild.Language.nxscript'), '\', '/', [rfReplaceAll]) + '"; ';
end;

function NewFolder: string;
var lGuid: TGUID;
begin
  CreateGUID(lGuid);
  Result := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    'document-fixtures/' + GUIDToString(lGuid);
  ForceDirectories(Result);
end;

procedure TestUnsavedSourceProject(AContext: TNXTestContext);
var lDocument: TNXPackageDocument; lFolder, lFileName: string;
begin
  lFolder := NewFolder;
  lFileName := lFolder + '/Unsaved.nxproject';
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.LoadSource(lFileName, Dialect + 'Project Unsaved { Id: "Tests.Unsaved";' +
      ' Publishes Directories { Sources: ["src"]; Headers: ["include"]; } }');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertEquals('Project', lDocument.EntityType);
    AContext.AssertTrue(lDocument.CompiledDocument.FindDefinition('Unsaved') <> nil);
    AContext.AssertFalse(FileExists(lFileName));
    AContext.AssertFalse(DirectoryExists(lFolder + '/src'));
  finally lDocument.Free; RemoveDir(lFolder); end;
end;

procedure TestGraphWithoutExecution(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
  lCatalog: TStringList;
  lFolder, lText: string;
begin
  lFolder := NewFolder;
  lCatalog := TStringList.Create;
  lDocument := TNXPackageDocument.Create;
  try
    lCatalog.Text := Dialect + 'ProjectIndex Projects {' +
      ' ProjectReference Missing { Id: "Tests.Missing"; Descriptor: "missing.nxproject"; } }';
    lCatalog.SaveToFile(lFolder + '/Projects.nxscript');
    lText := Dialect + 'Project Current { Id: "Tests.Current"; ' +
      ' FPC Compiler { CompilerPath: "not-installed/compiler"; SourceFiles: ["future.pas"]; OutputPath: "future-output"; } }';
    lDocument.LoadSource(lFolder + '/Current.nxproject', lText);
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertFalse(DirectoryExists(lFolder + '/future-output'));
    lDocument.SourceText := Dialect + 'module Projects "Projects.nxscript";' +
      'Project Current { Id: "Tests.Current"; Requires: [@Projects.Missing]; }';
    AContext.AssertFalse(lDocument.Validate);
    AContext.AssertTrue(Pos('Tests.Missing', lDocument.Diagnostics.Text) > 0, lDocument.Diagnostics.Text);
    AContext.AssertTrue(Pos('missing.nxproject', lDocument.Diagnostics.Text) > 0, lDocument.Diagnostics.Text);
  finally
    lDocument.Free; lCatalog.Free;
    DeleteFile(lFolder + '/Projects.nxscript'); RemoveDir(lFolder);
  end;
end;

procedure TestProjectTargetSelection(AContext: TNXTestContext);
var lDocument: TNXPackageDocument; lFolder: string;
begin
  lFolder := NewFolder;
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.LoadSource(lFolder + '/Windows.nxproject', Dialect +
      'Project Windows TargetOS[win64] { Id: "Tests.Windows"; }');
    lDocument.SetTarget('TargetOS', 'linux');
    AContext.AssertFalse(lDocument.Validate);
    lDocument.SetTarget('TargetOS', 'win64');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lDocument.SetTarget('TargetOS', 'linux');
    AContext.AssertFalse(lDocument.Validated);
    AContext.AssertTrue(lDocument.CompiledDocument = nil);
  finally lDocument.Free; RemoveDir(lFolder); end;
end;

procedure TestProjectCatalog(AContext: TNXTestContext);
var lDocument: TNXPackageDocument; lFolder: string;
begin
  lFolder := NewFolder;
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.LoadSource(lFolder + '/Projects.nxscript', Dialect + 'ProjectIndex Projects {' +
      ' ProjectReference Core { Id: "Tests.Core"; Descriptor: "Core.nxproject"; } }');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertEquals('ProjectIndex', lDocument.EntityType);
  finally lDocument.Free; RemoveDir(lFolder); end;
end;

procedure RegisterNXProjectDocumentTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NXProject.Document');
  lSuite.AddTest('UnsavedSourceProject', @TestUnsavedSourceProject);
  lSuite.AddTest('GraphWithoutExecution', @TestGraphWithoutExecution);
  lSuite.AddTest('TargetSelection', @TestProjectTargetSelection);
  lSuite.AddTest('Catalog', @TestProjectCatalog);
end;
end.
