unit tsNXSkinTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXSkinTests(ARegistry: TNXTestRegistry);

implementation

uses
  SysUtils,
  fpg_base,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptSession,
  obNexusScriptValidator,
  obNXSkin,
  obNXTestContext,
  obNXTestSuite,
  tpNXSkin;

function EmptyRange: TNexusScriptRange;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.SourceName := 'test.skin.nxscript';
end;

procedure AddTextProperty(ADefinition: TNexusScriptCompiledDefinition;
  const AName, AValue: string);
var
  lValue: TNexusScriptCompiledValue;
begin
  lValue := TNexusScriptCompiledValue.Create(nsvText, EmptyRange);
  lValue.EffectiveText := AValue;
  lValue.HasEffectiveText := True;
  ADefinition.Properties.Add(TNexusScriptCompiledProperty.Create(AName,
    lValue, EmptyRange));
end;

function BuildValidDocument: TNexusScriptCompiledDocument;
var
  lDefinition: TNexusScriptCompiledDefinition;
  lRole: TNXSkinColorRole;
begin
  Result := TNexusScriptCompiledDocument.Create('test.skin.nxscript', Now);
  lDefinition := TNexusScriptCompiledDefinition.Create('Skin', 'Test',
    EmptyRange);
  Result.Definitions.Add(lDefinition);
  AddTextProperty(lDefinition, 'Version', '1');
  for lRole := Low(TNXSkinColorRole) to High(TNXSkinColorRole) do
    AddTextProperty(lDefinition, cNXSkinColorNames[lRole],
      '#' + IntToHex(LongWord(cNXSkinDefaultColors[lRole]), 8));
end;

function SkinFixturePath: string;
begin
  Result := ExpandFileName('fixtures\NexusDark.Skin.nxscript');
  if not FileExists(Result) then
    Result := ExpandFileName(
      'packages\gui\test\fixtures\NexusDark.Skin.nxscript');
end;

function ValidationFailure(AValidator: TNexusScriptValidator): string;
begin
  if AValidator.Diagnostics.Count = 0 then
    Result := 'no diagnostic'
  else
    Result := AValidator.Diagnostics[0].Code + ': ' +
      AValidator.Diagnostics[0].MessageText;
end;

procedure TestDefaultPalette(AContext: TNXTestContext);
begin
  AContext.AssertEquals('FF31363B',
    IntToHex(LongWord(cNXSkinDefaultColors[scrWindowBackground]), 8),
    'Window background mismatch.');
  AContext.AssertEquals('FF3DAEE9',
    IntToHex(LongWord(cNXSkinDefaultColors[scrFocus]), 8),
    'Focus color mismatch.');
  AContext.AssertEquals('FFFFFFFF',
    IntToHex(LongWord(cNXSkinDefaultColors[scrSelectionText]), 8),
    'Selection text mismatch.');
end;

procedure TestReadCompletePalette(AContext: TNXTestContext);
var
  lColors: TNXSkinColors;
  lDocument: TNexusScriptCompiledDocument;
  lError: string;
begin
  lDocument := BuildValidDocument;
  try
    AContext.AssertTrue(TNXSkin.TryReadColors(lDocument, lColors, lError),
      lError);
    AContext.AssertEquals('FF2A8BC4',
      IntToHex(LongWord(lColors[scrProgressBottom]), 8),
      'Progress color mismatch.');
  finally
    lDocument.Free;
  end;
end;

procedure TestCompileAndValidateFixture(AContext: TNXTestContext);
var
  lColors: TNXSkinColors;
  lDocument: TNexusScriptCompiledDocument;
  lError: string;
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(SkinFixturePath),
      'Skin fixture should compile: ' + lSession.LastError);
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(lDocument.DialectDocument <> nil,
      'Skin fixture should retain its compiled dialect.');
    AContext.AssertTrue(lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'Skin fixture should satisfy its dialect: ' +
      ValidationFailure(lValidator));
    AContext.AssertTrue(TNXSkin.TryReadColors(lDocument, lColors, lError),
      lError);
  finally
    lValidator.Free;
    lSession.Free;
  end;
end;

procedure TestRejectMalformedColor(AContext: TNXTestContext);
var
  lColors: TNXSkinColors;
  lDocument: TNexusScriptCompiledDocument;
  lError: string;
begin
  lDocument := BuildValidDocument;
  try
    lDocument.Definitions[0].FindProperty('ButtonBorder').Value.EffectiveText :=
      'not-a-color';
    AContext.AssertTrue(not TNXSkin.TryReadColors(lDocument, lColors,
      lError), 'Malformed color should fail.');
    AContext.AssertTrue(Pos('ButtonBorder', lError) > 0,
      'Malformed color error should identify the role.');
  finally
    lDocument.Free;
  end;
end;

procedure TestRejectUnsupportedVersion(AContext: TNXTestContext);
var
  lColors: TNXSkinColors;
  lDocument: TNexusScriptCompiledDocument;
  lError: string;
begin
  lDocument := BuildValidDocument;
  try
    lDocument.Definitions[0].FindProperty('Version').Value.EffectiveText := '2';
    AContext.AssertTrue(not TNXSkin.TryReadColors(lDocument, lColors,
      lError), 'Unsupported version should fail.');
    AContext.AssertTrue(Pos('Unsupported skin version', lError) > 0,
      'Unsupported version error mismatch.');
  finally
    lDocument.Free;
  end;
end;

procedure TestRejectMissingColor(AContext: TNXTestContext);
var
  lColors: TNXSkinColors;
  lDefinition: TNexusScriptCompiledDefinition;
  lDocument: TNexusScriptCompiledDocument;
  lError: string;
  lIndex: Integer;
begin
  lDocument := BuildValidDocument;
  try
    lDefinition := lDocument.Definitions[0];
    for lIndex := 0 to lDefinition.Properties.Count - 1 do
      if lDefinition.Properties[lIndex].Name = 'TabBorder' then
      begin
        lDefinition.Properties.Delete(lIndex);
        Break;
      end;
    AContext.AssertTrue(not TNXSkin.TryReadColors(lDocument, lColors,
      lError), 'Missing color should fail.');
    AContext.AssertTrue(Pos('TabBorder', lError) > 0,
      'Missing color error should identify the role.');
  finally
    lDocument.Free;
  end;
end;

procedure RegisterNXSkinTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusUI.Skin');
  lSuite.AddTest('DefaultPalette', @TestDefaultPalette);
  lSuite.AddTest('ReadCompletePalette', @TestReadCompletePalette);
  lSuite.AddTest('CompileAndValidateFixture', @TestCompileAndValidateFixture);
  lSuite.AddTest('RejectMalformedColor', @TestRejectMalformedColor);
  lSuite.AddTest('RejectUnsupportedVersion', @TestRejectUnsupportedVersion);
  lSuite.AddTest('RejectMissingColor', @TestRejectMissingColor);
end;

end.
