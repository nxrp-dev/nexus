(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXPackageTests;

{$mode delphi}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterNXPackageTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes, SysUtils, obNXTestContext, obNXTestSuite,
  obNXPackageDocument, obNXPackageStructure, obNXScriptEditor, obNXControls,
  obNexusScriptModel, tpNexusScript, tpVTV;

type
  TPackageTestEditor = class(TNXScriptEditor)
  public
    procedure ReferenceChoices(ANode: PVirtualNode; AChoices: TStrings);
  end;

  TPackageEditorHost = class
  private
    FForm: TNXForm;
    FEditor: TPackageTestEditor;
    FValidation: TNXPackageDocument;
    FSource: TNXMemo;
  protected
    procedure DocumentChanged(ASender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    property Editor: TPackageTestEditor read FEditor;
    property Validation: TNXPackageDocument read FValidation;
    property SourceView: TNXMemo read FSource;
  end;

procedure TPackageTestEditor.ReferenceChoices(ANode: PVirtualNode; AChoices: TStrings);
begin
  GetEditChoices(ANode, 1, AChoices);
end;

constructor TPackageEditorHost.Create;
begin
  inherited Create;
  FValidation := TNXPackageDocument.Create;
  FForm := TNXForm.Create(nil);
  FSource := TNXMemo.Create(FForm);
  FSource.ReadOnly := True;
  FEditor := TPackageTestEditor.Create(FForm);
  FEditor.OnDocumentChanged := DocumentChanged;
end;

destructor TPackageEditorHost.Destroy;
begin
  if FEditor <> nil then FEditor.OnDocumentChanged := nil;
  FForm.Free;
  FValidation.Free;
  inherited Destroy;
end;

procedure TPackageEditorHost.DocumentChanged(ASender: TObject);
begin
  FValidation.LoadSource(FEditor.Document.SourceName, FEditor.Document.SourceText);
  FValidation.Validate;
  FSource.Text := FEditor.Document.SourceText;
end;

function Root: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '../../../');
end;

function Example(const AName: string): string;
begin
  Result := Root + 'projects/nxpackage/examples/' + AName + '.nxscript';
end;

procedure TestEntityExamples(AContext: TNXTestContext);
const
  cNames: array[0..2] of string = ('Package', 'PackageIndex', 'RepositoryIndex');
var
  lDocument: TNXPackageDocument;
  lIndex: Integer;
  lPackage: TNexusScriptCompiledDefinition;
begin
  lDocument := TNXPackageDocument.Create;
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
    lPackage := lDocument.CompiledDocument.FindDefinition('Example');
    AContext.AssertEquals('NXRP.NexusScript',
      lPackage.FindProperty('Id').Value.EffectiveText,
      'Opaque package identity is preserved');
    AContext.AssertEquals(2,
      lPackage.FindProperty('Requires').Value.Items.Count,
      'Unavailable dependency is only a declaration');
  finally
    lDocument.Free;
  end;
end;

procedure TestUnsavedValidation(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
begin
  lDocument := TNXPackageDocument.Create;
  try
    lDocument.Load(Example('Package'));
    lDocument.SourceText := StringReplace(lDocument.SourceText,
      'Id: "NXRP.NexusScript";', 'Id: "";', []);
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
      lDocument.CompiledDocument.FindDefinition('Example').
        FindProperty('Id').Value.EffectiveText,
      'Validation uses the unsaved source text exactly');
  finally
    lDocument.Free;
  end;
end;

procedure TestSaveReload(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
  lFileName: string;
  lSource: TStringList;
begin
  lFileName := Root + 'output/nxpackageTests/draft.nxscript';
  ForceDirectories(ExtractFileDir(lFileName));
  lSource := TStringList.Create;
  lDocument := TNXPackageDocument.Create;
  try
    lSource.Text := 'PackageIndex Draft {}';
    lSource.SaveToFile(lFileName);
    lDocument.Load(lFileName);
    lDocument.SourceText := 'PackageIndex Edited {}';
    lDocument.Save;
    AContext.AssertFalse(lDocument.Dirty, 'Save clears dirty state');
    lDocument.SourceText := 'PackageIndex Unsaved {}';
    lDocument.Load(lFileName);
    AContext.AssertEquals('PackageIndex Edited {}', Trim(lDocument.SourceText),
      'Reload replaces the unsaved draft with saved source');
  finally
    lDocument.Free;
    lSource.Free;
  end;
end;

procedure LoadProjectionExample(ADocument: TNXPackageDocument);
begin
  ADocument.LoadSource(Example('Package'),
    'dialect "../language/nxpackage.Language.nxscript";' + LineEnding +
    'Package Example { Id: "NXRP.NexusScript"; Requires: []; }');
end;

procedure TestStructureProjection(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
  lTree: TNXPackageStructure;
  lRoot, lId, lRequires: PVirtualNode;
begin
  lDocument := TNXPackageDocument.Create;
  lTree := TNXPackageStructure.Create(nil);
  try
    LoadProjectionExample(lDocument);
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lTree.LoadDocument(lDocument.CompiledDocument);
    AContext.AssertEquals(1, lTree.RootNodeCount);
    AContext.AssertEquals(3, lTree.TotalCount);
    AContext.AssertEquals(3, lTree.VisibleCount);
    lRoot := lTree.GetFirst;
    AContext.AssertEquals('Package Example', lTree.Text[lRoot, 0]);
    AContext.AssertTrue(lTree.Expanded[lRoot]);
    lId := lTree.GetFirstChild(lRoot);
    AContext.AssertEquals('Id: NXRP.NexusScript', lTree.Text[lId, 0]);
    lRequires := lId^.NextSibling;
    while (lRequires <> nil) and (lTree.Text[lRequires, 0] <> 'Requires') do
      lRequires := lRequires^.NextSibling;
    AContext.AssertTrue(lRequires <> nil);
    AContext.AssertEquals('Requires', lTree.Text[lRequires, 0]);
    AContext.AssertTrue(lTree.Expanded[lRequires]);
    AContext.AssertTrue(lTree.GetFirstChild(lRequires) = nil);
    AContext.AssertTrue(lRequires^.Parent = lRoot);

    lTree.FocusedNode := lRequires;
    lTree.Selected[lRequires] := True;
    lDocument.LoadSource(Example('RepositoryIndex'),
      'dialect "../language/nxpackage.Language.nxscript";' + LineEnding +
      'RepositoryIndex Example {}');
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lTree.LoadDocument(lDocument.CompiledDocument);
    AContext.AssertEquals(1, lTree.TotalCount);
    AContext.AssertEquals('RepositoryIndex Example', lTree.Text[lTree.GetFirst, 0]);
    AContext.AssertTrue(lTree.FocusedNode = nil);
    AContext.AssertEquals(0, lTree.SelectedCount);

    lDocument.SourceText := 'RepositoryIndex Changed {}';
    lTree.LoadDocument(lDocument.CompiledDocument);
    AContext.AssertEquals(0, lTree.TotalCount, 'Unvalidated edits clear the old projection');
  finally
    lTree.Free;
    lDocument.Free;
  end;
end;

procedure TestStructureSnapshotLifetime(AContext: TNXTestContext);
var
  lDocument: TNXPackageDocument;
  lTree: TNXPackageStructure;
  lNode: PVirtualNode;
begin
  lDocument := TNXPackageDocument.Create;
  lTree := TNXPackageStructure.Create(nil);
  try
    LoadProjectionExample(lDocument);
    AContext.AssertTrue(lDocument.Validate, lDocument.Diagnostics.Text);
    lTree.LoadDocument(lDocument.CompiledDocument);
    FreeAndNil(lDocument);
    lNode := lTree.GetFirst;
    AContext.AssertEquals('Package Example', lTree.Text[lNode, 0]);
    lNode := lTree.GetFirstChild(lNode);
    AContext.AssertEquals('Id: NXRP.NexusScript', lTree.Text[lNode, 0]);
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
    'RepositoryIndex Other');
var
  lDocument: TNexusScriptCompiledDocument;
  lDefinition, lChild: TNexusScriptCompiledDefinition;
  lValues, lNested: TNexusScriptCompiledValue;
  lTree: TNXPackageStructure;
  lRange: TNexusScriptRange;
  lNode: PVirtualNode;
  lIndex: Integer;
begin
  lRange := Default(TNexusScriptRange);
  lDocument := TNexusScriptCompiledDocument.Create('structure-test', Now);
  lTree := TNXPackageStructure.Create(nil);
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
    lDocument.Definitions.Add(TNexusScriptCompiledDefinition.Create('RepositoryIndex', 'Other', lRange));

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

function FindEditorNode(AEditor: TNXScriptEditor; const ACaption: string): PVirtualNode;
begin
  Result := AEditor.GetFirst;
  while Result <> nil do
  begin
    if AEditor.Text[Result, 0] = ACaption then Exit;
    Result := AEditor.GetNext(Result);
  end;
end;

procedure AssertSourceView(AContext: TNXTestContext; AView: TNXMemo;
  const ASource: string);
var
  lLines: TStringList;
  lIndex: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := ASource;
    AContext.AssertTrue(AView.ReadOnly, 'The text pane is a view, not a second editor.');
    AContext.AssertEquals(lLines.Count, AView.Lines.Count);
    for lIndex := 0 to lLines.Count - 1 do
      AContext.AssertEquals(lLines[lIndex], AView.Lines[lIndex],
        'The view must retain the script line content.');
  finally
    lLines.Free;
  end;
end;

procedure TestEditorExamples(AContext: TNXTestContext);
const
  cNames: array[0..2] of string = ('Package', 'PackageIndex', 'RepositoryIndex');
  cLabels: array[0..2] of string = ('Example', 'NexusPackages', 'NexusPackages');
var
  lHost: TPackageEditorHost;
  lIndex: Integer;
begin
  lHost := TPackageEditorHost.Create;
  try
    for lIndex := Low(cNames) to High(cNames) do
    begin
      lHost.Editor.LoadFile(Example(cNames[lIndex]));
      AContext.AssertTrue(lHost.Editor.Document.Valid, lHost.Editor.Document.Diagnostics.Text);
      AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
      AContext.AssertEquals(cNames[lIndex], lHost.Validation.EntityType);
      AContext.AssertEquals(1, lHost.Editor.RootNodeCount);
      AContext.AssertEquals(cNames[lIndex], lHost.Editor.Text[lHost.Editor.GetFirst, 0]);
      AContext.AssertEquals(cLabels[lIndex], lHost.Editor.Text[lHost.Editor.GetFirst, 1]);
      AContext.AssertFalse(lHost.Editor.Document.Dirty);
      AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
      AContext.AssertTrue(Pos('dialect "../language/nxpackage.Language.nxscript";',
        lHost.SourceView.Text) > 0, 'The text view includes the dialect declaration.');
      AContext.AssertTrue(Pos('// Copyright (c) 2026 Kevin Collins.',
        lHost.SourceView.Text) > 0, 'The text view includes source comments.');
    end;
  finally
    lHost.Free;
  end;
end;

procedure TestEditorEditsAndValidation(AContext: TNXTestContext);
var
  lHost: TPackageEditorHost;
  lOriginal, lAccepted: string;
begin
  lHost := TPackageEditorHost.Create;
  try
    lHost.Editor.LoadFile(Example('Package'));
    lOriginal := lHost.Editor.Document.SourceText;
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'Id'),
      'Test:MixedCase/Identity'));
    AContext.AssertTrue(lHost.Editor.Document.Dirty);
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AContext.AssertEquals('Test:MixedCase/Identity',
      lHost.Validation.CompiledDocument.FindDefinition('Example').FindProperty('Id').Value.EffectiveText);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, '[0]'),
      '@NexusPackages.NexusScript'));
    AContext.AssertTrue(lHost.Validation.Validated, 'A dependency remains only a declaration.');
    AContext.AssertEquals('NXRP.NexusScript',
      lHost.Validation.CompiledDocument.FindDefinition('Example').FindProperty('Requires').
        Value.Items[0].ResolvedDefinition.FindProperty('Id').Value.EffectiveText);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
    lAccepted := lHost.Editor.Document.SourceText;
    AContext.AssertFalse(lHost.Editor.SetNodeSource(FindEditorNode(lHost.Editor, 'Id'), '["wrong"]'));
    AContext.AssertEquals(lAccepted, lHost.Editor.Document.SourceText, 'Rejected edits do not change source.');
    AssertSourceView(AContext, lHost.SourceView, lAccepted);
    AContext.AssertTrue(lHost.Validation.Validated);
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'Id'), ''));
    AContext.AssertFalse(lHost.Validation.Validated, 'nxpackage still rejects an empty identity.');
    AContext.AssertTrue(Pos('package-id-empty', lHost.Validation.Diagnostics.Text) > 0);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
    AContext.AssertTrue(Pos('Id: "";', lHost.SourceView.Text) > 0,
      'An invalid package identity remains visible in the source view.');
    AContext.AssertTrue(lHost.Editor.GetFirst <> nil, 'The draft remains available for correction.');
    AContext.AssertTrue(lHost.Editor.Document.Undo);
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
    AContext.AssertTrue(lHost.Editor.Document.Undo);
    AContext.AssertTrue(lHost.Editor.Document.Undo);
    AContext.AssertEquals(lOriginal, lHost.Editor.Document.SourceText);
    AContext.AssertFalse(lHost.Editor.Document.Dirty);
    AssertSourceView(AContext, lHost.SourceView, lOriginal);
  finally
    lHost.Free;
  end;
end;

function ReadSourceBytes(const AFileName: string): string;
var
  lFile: TFileStream;
begin
  Result := '';
  lFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, lFile.Size);
    if Result <> '' then lFile.ReadBuffer(Result[1], Length(Result));
  finally
    lFile.Free;
  end;
end;

procedure TestEditorSaveReload(AContext: TNXTestContext);
var
  lHost: TPackageEditorHost;
  lPath, lSource, lSaved: string;
begin
  lPath := Root + 'output/nxpackageTests/editor/Package.nxscript';
  ForceDirectories(ExtractFilePath(lPath));
  lSource := ReadSourceBytes(Example('Package'));
  lHost := TPackageEditorHost.Create;
  try
    lSource := StringReplace(lSource, '"../language/nxpackage.Language.nxscript"',
      lHost.Editor.Document.QuoteText(Root + 'projects/nxpackage/language/nxpackage.Language.nxscript'), []);
    lSource := StringReplace(lSource, 'module NexusPackages "RepositoryIndex.nxscript";',
      'module NexusPackages ' + lHost.Editor.Document.QuoteText(Example('RepositoryIndex')) + ';', []);
    lHost.Editor.LoadSource(lPath, lSource);
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'Id'), 'saved.example/Package'));
    lSaved := lHost.Editor.Document.SourceText;
    lHost.Editor.Document.Save;
    AContext.AssertFalse(lHost.Editor.Document.Dirty);
    AContext.AssertEquals(lSaved, ReadSourceBytes(lPath), 'Save writes the widget source bytes exactly.');
    AssertSourceView(AContext, lHost.SourceView, lSaved);
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'Id'), 'unsaved.example/Package'));
    AContext.AssertTrue(lHost.Editor.Document.Dirty);
    lHost.Editor.LoadFile(lPath);
    AContext.AssertEquals(lSaved, lHost.Editor.Document.SourceText);
    AssertSourceView(AContext, lHost.SourceView, lSaved);
    AContext.AssertFalse(lHost.Editor.Document.Dirty);
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AContext.AssertEquals('saved.example/Package',
      lHost.Validation.CompiledDocument.FindDefinition('Example').FindProperty('Id').Value.EffectiveText);
  finally
    lHost.Free;
  end;
end;

procedure TestMetadataEditor(AContext: TNXTestContext);
const
  cNames: array[0..4] of string = ('Version', 'Author', 'Description', 'License', 'Requires');
var
  lHost: TPackageEditorHost;
  lChoices: TStringList;
  lName: string;
  lOffset: Integer;
begin
  lHost := TPackageEditorHost.Create;
  lChoices := TStringList.Create;
  try
    lHost.Editor.LoadSource(Example('Package'),
      'dialect "../language/nxpackage.Language.nxscript";' + LineEnding +
      'Package P { Id: "NXRP.P"; }');
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    lHost.Editor.GetPropertyChoices(lHost.Editor.GetFirst, lChoices);
    AContext.AssertEquals(5, lChoices.Count);
    for lName in cNames do AContext.AssertTrue(lChoices.IndexOf(lName) >= 0, lName);
    lHost.Editor.GetDefinitionChoices(lHost.Editor.GetFirst, lChoices);
    AContext.AssertEquals(0, lChoices.Count, 'Packages cannot declare child package/repository records.');
    lHost.Editor.Document.GetDefinitionKinds(-1, lChoices);
    AContext.AssertEquals(3, lChoices.Count);
    AContext.AssertTrue(lChoices.IndexOf('Package') >= 0);
    AContext.AssertTrue(lChoices.IndexOf('PackageIndex') >= 0);
    AContext.AssertTrue(lChoices.IndexOf('RepositoryIndex') >= 0);
    AContext.AssertTrue(lChoices.IndexOf('Project') < 0);
    AContext.AssertTrue(lChoices.IndexOf('LocalPackage') < 0);
    AContext.AssertTrue(lChoices.IndexOf('ExternalPackage') < 0);
    AContext.AssertTrue(lChoices.IndexOf('TrustedRepository') < 0);
    AContext.AssertTrue(lChoices.IndexOf('ContentHash') < 0);
    lOffset := lHost.Editor.Document.SourceDocument.Definitions[0].SourceRange.StartPosition.Offset;
    for lName in cNames do
      if lName = 'Requires' then
        AContext.AssertTrue(lHost.Editor.Document.SetProperty(lOffset, lName, '[]'))
      else AContext.AssertTrue(lHost.Editor.Document.SetProperty(lOffset, lName, '"optional metadata"'));
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
    AContext.AssertFalse(lHost.Editor.CanRemove(FindEditorNode(lHost.Editor, 'Id')));
    AContext.AssertTrue(lHost.Editor.Remove(FindEditorNode(lHost.Editor, 'Version')));
    AContext.AssertEquals('NXRP.P',
      lHost.Validation.CompiledDocument.Definitions[0].FindProperty('Id').Value.EffectiveText);
    AContext.AssertTrue(lHost.Editor.Document.Undo);
    AContext.AssertTrue(FindEditorNode(lHost.Editor, 'Version') <> nil);
    AContext.AssertTrue(lHost.Editor.Document.Redo);
    AContext.AssertTrue(FindEditorNode(lHost.Editor, 'Version') = nil);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
  finally
    lChoices.Free;
    lHost.Free;
  end;
end;

procedure CheckIndexEditor(AContext: TNXTestContext; const AExample: string);
var
  lHost: TPackageEditorHost;
  lChoices: TStringList;
  lRootOffset, lEntryOffset: Integer;
begin
  lHost := TPackageEditorHost.Create;
  lChoices := TStringList.Create;
  try
    lHost.Editor.LoadFile(Example(AExample));
    lHost.Editor.GetDefinitionChoices(lHost.Editor.GetFirst, lChoices);
    AContext.AssertEquals(3, lChoices.Count);
    AContext.AssertTrue(lChoices.IndexOf('LocalPackage') >= 0);
    AContext.AssertTrue(lChoices.IndexOf('ExternalPackage') >= 0);
    AContext.AssertTrue(lChoices.IndexOf('TrustedRepository') >= 0);
    lHost.Editor.GetDefinitionChoices(FindEditorNode(lHost.Editor, 'LocalPackage'), lChoices);
    AContext.AssertEquals(1, lChoices.Count);
    AContext.AssertEquals('ContentHash', lChoices[0]);
    lEntryOffset := lHost.Editor.Document.SourceDocument.Definitions[0].Children[1].SourceRange.StartPosition.Offset;
    AContext.AssertTrue(lHost.Editor.Document.AddDefinition(lEntryOffset, 'ContentHash', 'Advertised',
      'Algorithm: "synthetic"; Digest: "synthetic-data";'));
    lHost.Editor.GetDefinitionChoices(FindEditorNode(lHost.Editor, 'LocalPackage'), lChoices);
    AContext.AssertEquals(0, lChoices.Count, 'A second hash is not offered.');
    AContext.AssertFalse(lHost.Editor.CanRemove(FindEditorNode(lHost.Editor, 'Algorithm')));
    AContext.AssertFalse(lHost.Editor.CanRemove(FindEditorNode(lHost.Editor, 'Digest')));
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'Digest'), 'changed synthetic data'));
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AContext.AssertTrue(lHost.Editor.Remove(FindEditorNode(lHost.Editor, 'ContentHash')));
    AContext.AssertEquals('NXRP.NexusScript',
      lHost.Validation.CompiledDocument.Definitions[0].FindChild('NexusScript').FindProperty('Id').Value.EffectiveText);
    lRootOffset := lHost.Editor.Document.SourceDocument.Definitions[0].SourceRange.StartPosition.Offset;
    AContext.AssertTrue(lHost.Editor.Document.AddDefinition(lRootOffset, 'LocalPackage', 'UnrelatedLabel',
      'Id: "FreePascal.FPC"; Descriptor: "unavailable/FPC.nxscript";'));
    AContext.AssertFalse(lHost.Editor.CanRemove(FindEditorNode(lHost.Editor, 'Descriptor')));
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'Source'),
      'https://offline.invalid/nexus-packages-ext'));
    AContext.AssertTrue(lHost.Editor.Document.AddDefinition(lRootOffset, 'TrustedRepository', 'Sister',
      'Source: "https://offline.invalid/sister.git";'));
    AContext.AssertTrue(lHost.Editor.Document.AddDefinition(lRootOffset, 'ExternalPackage', 'Additional',
      'Id: "External.Additional"; Repository: @NexusPackages.Sister;'));
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AContext.AssertEquals(7, lHost.Validation.CompiledDocument.Definitions[0].Children.Count);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
    AContext.AssertTrue(lHost.Editor.Document.Undo);
    AContext.AssertEquals(6, lHost.Validation.CompiledDocument.Definitions[0].Children.Count);
    AContext.AssertTrue(lHost.Editor.Document.Redo);
    AContext.AssertEquals(7, lHost.Validation.CompiledDocument.Definitions[0].Children.Count);
    lHost.Editor.LoadFile(Example('ExternalRepositoryIndex'));
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AContext.AssertEquals('SQLite.SQLite',
      lHost.Validation.CompiledDocument.Definitions[0].Children[0].FindProperty('Id').Value.EffectiveText);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
  finally
    lChoices.Free;
    lHost.Free;
  end;
end;

procedure TestIndexEditor(AContext: TNXTestContext);
begin
  CheckIndexEditor(AContext, 'PackageIndex');
end;

procedure TestRepositoryIndexEditor(AContext: TNXTestContext);
begin
  CheckIndexEditor(AContext, 'RepositoryIndex');
end;

procedure TestReferenceEditorChoices(AContext: TNXTestContext);
var
  lHost: TPackageEditorHost;
  lChoices: TStringList;
  lArrayOffset: Integer;
begin
  lHost := TPackageEditorHost.Create;
  lChoices := TStringList.Create;
  try
    lHost.Editor.LoadFile(Example('Package'));
    lHost.Editor.ReferenceChoices(FindEditorNode(lHost.Editor, '[0]'), lChoices);
    AContext.AssertEquals(3, lChoices.Count);
    AContext.AssertTrue(lChoices.IndexOf('@NexusPackages.NexusLib') >= 0);
    AContext.AssertTrue(lChoices.IndexOf('@NexusPackages.SQLite') >= 0);
    AContext.AssertTrue(lChoices.IndexOf('@NexusPackages.NexusScript') >= 0);
    AContext.AssertTrue(lChoices.IndexOf('@NexusPackages.NexusLib.Id') < 0);
    AContext.AssertTrue(lChoices.IndexOf('@NexusPackages.ExternalPackages') < 0);
    lHost.Editor.GetSourceForms(FindEditorNode(lHost.Editor, '[0]'), lChoices);
    AContext.AssertEquals(1, lChoices.Count);
    AContext.AssertEquals('Reference', lChoices[0]);
    lArrayOffset := lHost.Editor.Document.SourceDocument.Definitions[0].FindProperty('Requires').
      Value.SourceRange.StartPosition.Offset;
    AContext.AssertTrue(lHost.Editor.Document.RemoveArrayItem(lArrayOffset, 1));
    AContext.AssertTrue(lHost.Editor.Document.AddArrayItem(lArrayOffset, '@NexusPackages.NexusScript'));
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AContext.AssertFalse(lHost.Editor.Document.AddArrayItem(lArrayOffset, '"plain ID"'));
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
    AContext.AssertTrue(lHost.Editor.Document.Undo);
    AContext.AssertTrue(lHost.Editor.Document.Redo);
    lHost.Editor.LoadFile(Example('PackageIndex'));
    lHost.Editor.ReferenceChoices(FindEditorNode(lHost.Editor, 'Repository'), lChoices);
    AContext.AssertEquals(1, lChoices.Count);
    AContext.AssertEquals('@NexusPackages.ExternalPackages', lChoices[0]);
    lHost.Editor.GetSourceForms(FindEditorNode(lHost.Editor, 'Repository'), lChoices);
    AContext.AssertEquals(1, lChoices.Count);
    AContext.AssertEquals('Reference', lChoices[0]);
  finally
    lChoices.Free;
    lHost.Free;
  end;
end;

procedure TestIndexEditorSaveReload(AContext: TNXTestContext);
var
  lHost: TPackageEditorHost;
  lSource, lSaved, lPath: string;
begin
  lHost := TPackageEditorHost.Create;
  try
    lPath := Root + 'output/nxpackageTests/editor/Index.nxscript';
    ForceDirectories(ExtractFilePath(lPath));
    lSource := ReadSourceBytes(Root + 'projects/nxpackage/test/fixtures/IndexWithHash.nxscript');
    lSource := StringReplace(lSource, '"../../language/nxpackage.Language.nxscript"',
      lHost.Editor.Document.QuoteText(Root + 'projects/nxpackage/language/nxpackage.Language.nxscript'), []);
    lHost.Editor.LoadSource(lPath, lSource);
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'Digest'), 'edited synthetic digest'));
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'Descriptor'),
      'https://not-an-entry-source.invalid/Package.nxscript'));
    AContext.AssertFalse(lHost.Validation.Validated);
    AContext.AssertTrue(Pos('package-descriptor-relative', lHost.Validation.Diagnostics.Text) > 0);
    AssertSourceView(AContext, lHost.SourceView, lHost.Editor.Document.SourceText);
    AContext.AssertTrue(lHost.Editor.Document.Undo);
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    lSaved := lHost.Editor.Document.SourceText;
    lHost.Editor.Document.Save;
    AContext.AssertEquals(lSaved, ReadSourceBytes(lPath));
    AContext.AssertFalse(lHost.Editor.Document.Dirty);
    AContext.AssertTrue(lHost.Editor.SetNodeValue(FindEditorNode(lHost.Editor, 'LocalPackage'), 'DifferentLabel'));
    AContext.AssertEquals('SQLite.SQLite',
      lHost.Validation.CompiledDocument.Definitions[0].Children[0].FindProperty('Id').Value.EffectiveText);
    lHost.Editor.LoadFile(lPath);
    AContext.AssertEquals(lSaved, lHost.Editor.Document.SourceText);
    AContext.AssertTrue(lHost.Validation.Validated, lHost.Validation.Diagnostics.Text);
    AssertSourceView(AContext, lHost.SourceView, lSaved);
  finally
    lHost.Free;
  end;
end;

procedure RegisterNXPackageTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('nxpackage');
  lSuite.AddTest('EntityExamples', @TestEntityExamples);
  lSuite.AddTest('UnsavedValidation', @TestUnsavedValidation);
  lSuite.AddTest('SaveReload', @TestSaveReload);
  lSuite.AddTest('StructureProjection', @TestStructureProjection);
  lSuite.AddTest('StructureSnapshotLifetime', @TestStructureSnapshotLifetime);
  lSuite.AddTest('StructureNestedContent', @TestStructureNestedContent);
  lSuite.AddTest('EditorEntityExamples', @TestEditorExamples);
  lSuite.AddTest('EditorEditsAndValidation', @TestEditorEditsAndValidation);
  lSuite.AddTest('EditorSaveReload', @TestEditorSaveReload);
  lSuite.AddTest('MetadataEditor', @TestMetadataEditor);
  lSuite.AddTest('IndexEditor', @TestIndexEditor);
  lSuite.AddTest('RepositoryIndexEditor', @TestRepositoryIndexEditor);
  lSuite.AddTest('ReferenceEditorChoices', @TestReferenceEditorChoices);
  lSuite.AddTest('IndexEditorSaveReload', @TestIndexEditorSaveReload);
end;

end.
