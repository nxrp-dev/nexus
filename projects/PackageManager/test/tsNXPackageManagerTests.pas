(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXPackageManagerTests;

{$mode delphi}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterPackageManagerTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes, SysUtils, obNXTestContext, obNXTestSuite,
  obNXPackageManagerDocument, obNXPackageManagerStructure,
  obNexusScriptModel, tpNexusScript, tpVTV;

function Root: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '../../../');
end;

function Example(const AName: string): string;
begin
  Result := Root + 'projects/PackageManager/examples/' + AName + '.nxscript';
end;

procedure TestEntityExamples(AContext: TNXTestContext);
const
  cNames: array[0..2] of string = ('Package', 'PackageIndex', 'Project');
var
  lDocument: TNXPackageManagerDocument;
  lIndex: Integer;
  lPackage: TNexusScriptCompiledDefinition;
begin
  lDocument := TNXPackageManagerDocument.Create;
  try
    for lIndex := Low(cNames) to High(cNames) do
    begin
      lDocument.Load(Example(cNames[lIndex]));
      AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
      AContext.AssertEquals(cNames[lIndex], lDocument.EntityType,
        'Example identifies its entity type');
      AContext.AssertTrue(lDocument.CompiledDocument <> nil,
        'Validated definitions remain inspectable');
    end;
    lDocument.Load(Example('Package'));
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lPackage := lDocument.CompiledDocument.Definitions[0];
    AContext.AssertEquals('example.org/tools/Example',
      lPackage.FindProperty('Id').Value.EffectiveText,
      'Opaque package identity is preserved');
    AContext.AssertEquals(1,
      lPackage.FindProperty('Requires').Value.Items.Count,
      'Unavailable dependency is only a declaration');
  finally
    lDocument.Free;
  end;
end;

procedure TestUnsavedValidation(AContext: TNXTestContext);
var
  lDocument: TNXPackageManagerDocument;
begin
  lDocument := TNXPackageManagerDocument.Create;
  try
    lDocument.Load(Example('Package'));
    lDocument.SourceText := StringReplace(lDocument.SourceText,
      'Id: "example.org/tools/Example";', 'Id: "";', []);
    AContext.AssertTrue(lDocument.Dirty, 'Editor draft is unsaved');
    AContext.AssertFalse(lDocument.Validate, 'Empty identity is invalid');
    AContext.AssertTrue(Pos('package-id-empty', lDocument.Diagnostics.Text) > 0,
      'Semantic diagnostic identifies the source problem');
    AContext.AssertTrue(Pos('Package.nxscript(', lDocument.Diagnostics.Text) > 0,
      'Diagnostic includes a source location');
    AContext.AssertTrue(lDocument.CompiledDocument = nil,
      'Invalid draft has no current validated projection');

    lDocument.SourceText := StringReplace(lDocument.SourceText,
      'Id: "";', 'Id: "Example:MixedCase";', []);
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    AContext.AssertEquals('Example:MixedCase',
      lDocument.CompiledDocument.Definitions[0].
        FindProperty('Id').Value.EffectiveText,
      'Validation uses the unsaved source text exactly');
  finally
    lDocument.Free;
  end;
end;

procedure TestSaveReload(AContext: TNXTestContext);
var
  lDocument: TNXPackageManagerDocument;
  lFileName: string;
  lSource: TStringList;
begin
  lFileName := Root + 'output/NexusPackageManagerTests/draft.nxscript';
  ForceDirectories(ExtractFileDir(lFileName));
  lSource := TStringList.Create;
  lDocument := TNXPackageManagerDocument.Create;
  try
    lSource.Text := 'Project Draft {}';
    lSource.SaveToFile(lFileName);
    lDocument.Load(lFileName);
    lDocument.SourceText := 'Project Edited {}';
    lDocument.Save;
    AContext.AssertFalse(lDocument.Dirty, 'Save clears dirty state');
    lDocument.SourceText := 'Project Unsaved {}';
    lDocument.Load(lFileName);
    AContext.AssertEquals('Project Edited {}', Trim(lDocument.SourceText),
      'Reload replaces the unsaved draft with saved source');
  finally
    lDocument.Free;
    lSource.Free;
  end;
end;

procedure TestStructureProjection(AContext: TNXTestContext);
var
  lDocument: TNXPackageManagerDocument;
  lTree: TNXPackageManagerStructure;
  lRoot, lId, lRequires, lItem: PVirtualNode;
begin
  lDocument := TNXPackageManagerDocument.Create;
  lTree := TNXPackageManagerStructure.Create(nil);
  try
    lDocument.Load(Example('Package'));
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lTree.LoadDocument(lDocument.CompiledDocument);
    AContext.AssertEquals(1, lTree.RootNodeCount);
    AContext.AssertEquals(4, lTree.TotalCount);
    AContext.AssertEquals(4, lTree.VisibleCount);
    lRoot := lTree.GetFirst;
    AContext.AssertEquals('Package Example', lTree.Text[lRoot, 0]);
    AContext.AssertTrue(lTree.Expanded[lRoot]);
    lId := lTree.GetFirstChild(lRoot);
    AContext.AssertEquals('Id: example.org/tools/Example', lTree.Text[lId, 0]);
    lRequires := lId^.NextSibling;
    AContext.AssertEquals('Requires', lTree.Text[lRequires, 0]);
    AContext.AssertTrue(lTree.Expanded[lRequires]);
    lItem := lTree.GetFirstChild(lRequires);
    AContext.AssertEquals('[0]: example.org/runtime/Other', lTree.Text[lItem, 0]);
    AContext.AssertTrue(lItem^.Parent = lRequires);

    lTree.FocusedNode := lItem;
    lTree.Selected[lItem] := True;
    lDocument.Load(Example('Project'));
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lTree.LoadDocument(lDocument.CompiledDocument);
    AContext.AssertEquals(1, lTree.TotalCount);
    AContext.AssertEquals('Project Example', lTree.Text[lTree.GetFirst, 0]);
    AContext.AssertTrue(lTree.FocusedNode = nil);
    AContext.AssertEquals(0, lTree.SelectedCount);

    lDocument.SourceText := 'Project Changed {}';
    lTree.LoadDocument(lDocument.CompiledDocument);
    AContext.AssertEquals(0, lTree.TotalCount, 'Unvalidated edits clear the old projection');
  finally
    lTree.Free;
    lDocument.Free;
  end;
end;

procedure TestStructureSnapshotLifetime(AContext: TNXTestContext);
var
  lDocument: TNXPackageManagerDocument;
  lTree: TNXPackageManagerStructure;
  lNode: PVirtualNode;
begin
  lDocument := TNXPackageManagerDocument.Create;
  lTree := TNXPackageManagerStructure.Create(nil);
  try
    lDocument.Load(Example('Package'));
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lTree.LoadDocument(lDocument.CompiledDocument);
    FreeAndNil(lDocument);
    lNode := lTree.GetFirst;
    AContext.AssertEquals('Package Example', lTree.Text[lNode, 0]);
    lNode := lTree.GetFirstChild(lNode);
    AContext.AssertEquals('Id: example.org/tools/Example', lTree.Text[lNode, 0]);
    lTree.LoadDocument(nil);
    AContext.AssertEquals(0, lTree.TotalCount);
    AContext.AssertEquals(0, lTree.VisibleCount);
  finally
    lTree.Free;
    lDocument.Free;
  end;
end;

function CompiledText(const AText: string): TNexusScriptCompiledValue;
begin
  Result := TNexusScriptCompiledValue.Create(nsvText, Default(TNexusScriptRange));
  Result.EffectiveText := AText;
  Result.HasEffectiveText := True;
end;

procedure TestStructureNestedContent(AContext: TNXTestContext);
const
  cCaptions: array[0..8] of string = ('Package Parent', 'Title: Alpha',
    'Rows', '[0]: one', '[1]', '[0]: deep', 'Section Child', 'Count: 7',
    'Project Other');
var
  lDocument: TNexusScriptCompiledDocument;
  lDefinition, lChild: TNexusScriptCompiledDefinition;
  lValues, lNested: TNexusScriptCompiledValue;
  lTree: TNXPackageManagerStructure;
  lRange: TNexusScriptRange;
  lNode: PVirtualNode;
  lIndex: Integer;
begin
  lRange := Default(TNexusScriptRange);
  lDocument := TNexusScriptCompiledDocument.Create('structure-test', Now);
  lTree := TNXPackageManagerStructure.Create(nil);
  try
    lDefinition := TNexusScriptCompiledDefinition.Create('Package', 'Parent', lRange);
    lDocument.Definitions.Add(lDefinition);
    lDefinition.Properties.Add(TNexusScriptCompiledProperty.Create(
      'Title', CompiledText('Alpha'), lRange));
    lValues := TNexusScriptCompiledValue.Create(nsvArray, lRange);
    lDefinition.Properties.Add(TNexusScriptCompiledProperty.Create('Rows', lValues, lRange));
    lValues.Items.Add(CompiledText('one'));
    lNested := TNexusScriptCompiledValue.Create(nsvArray, lRange);
    lValues.Items.Add(lNested);
    lNested.Items.Add(CompiledText('deep'));
    lChild := TNexusScriptCompiledDefinition.Create('Section', 'Child', lRange);
    lChild.Parent := lDefinition;
    lDefinition.Children.Add(lChild);
    lChild.Properties.Add(TNexusScriptCompiledProperty.Create('Count', CompiledText('7'), lRange));
    lDocument.Definitions.Add(TNexusScriptCompiledDefinition.Create('Project', 'Other', lRange));

    lTree.LoadDocument(lDocument);
    AContext.AssertEquals(2, lTree.RootNodeCount);
    AContext.AssertEquals(9, lTree.TotalCount);
    AContext.AssertEquals(9, lTree.VisibleCount);
    lNode := lTree.GetFirst;
    for lIndex := Low(cCaptions) to High(cCaptions) do
    begin
      AContext.AssertTrue(lNode <> nil);
      AContext.AssertEquals(cCaptions[lIndex], lTree.Text[lNode, 0]);
      lNode := lTree.GetNext(lNode);
    end;
    AContext.AssertTrue(lNode = nil);
  finally
    lTree.Free;
    lDocument.Free;
  end;
end;

procedure RegisterPackageManagerTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusPackageManager');
  lSuite.AddTest('EntityExamples', @TestEntityExamples);
  lSuite.AddTest('UnsavedValidation', @TestUnsavedValidation);
  lSuite.AddTest('SaveReload', @TestSaveReload);
  lSuite.AddTest('StructureProjection', @TestStructureProjection);
  lSuite.AddTest('StructureSnapshotLifetime', @TestStructureSnapshotLifetime);
  lSuite.AddTest('StructureNestedContent', @TestStructureNestedContent);
end;

end.
