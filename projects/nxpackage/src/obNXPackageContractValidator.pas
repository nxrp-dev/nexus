(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit obNXPackageContractValidator;

{ Shared, read-only contract checks. No execution or dependency acquisition. }
{$mode delphi}{$H+}

interface

uses Classes, obNexusScriptModel, obNexusScriptSession, tpNexusScript;

type
  TNXPackageContractValidator = class
  private
    FSession: TNexusScriptCompilationSession;
    FDiagnostics: TStrings;
    FValidatedIndexes: TStringList;
    procedure AddDiagnostic(const ACode, AMessage: string; const ARange: TNexusScriptRange);
    procedure CheckText(ADefinition: TNexusScriptCompiledDefinition; const AName, ACode, AMessage: string);
    procedure CheckDescriptor(ADefinition: TNexusScriptCompiledDefinition);
    procedure CheckIndex(ADefinition: TNexusScriptCompiledDefinition);
    procedure CheckRequirements(ADefinition: TNexusScriptCompiledDefinition);
    procedure CheckRepository(ARecord, AIndex: TNexusScriptCompiledDefinition);
    function RecordBelongsToIndex(ARecord, AIndex: TNexusScriptCompiledDefinition): Boolean;
    function RequirementIndex(const ARange: TNexusScriptRange): TNexusScriptCompiledDefinition;
    procedure ValidateImportedIndex(ADefinition: TNexusScriptCompiledDefinition);
    procedure CheckDefinition(ADefinition: TNexusScriptCompiledDefinition);
    function IsIndex(ADefinition: TNexusScriptCompiledDefinition): Boolean;
  public
    // Borrows the compiled session and diagnostic list; does not read build artifacts.
    constructor Create(ASession: TNexusScriptCompilationSession; ADiagnostics: TStrings);
    destructor Destroy; override;
    procedure Validate;
  end;

implementation

uses SysUtils, obNexusScriptCompiler, obNexusScriptValidator,
  obNexusScriptDefinitionView;

constructor TNXPackageContractValidator.Create(ASession: TNexusScriptCompilationSession;
  ADiagnostics: TStrings);
begin
  inherited Create;
  FSession := ASession;
  FDiagnostics := ADiagnostics;
  FValidatedIndexes := TStringList.Create;
  FValidatedIndexes.CaseSensitive := True;
end;

destructor TNXPackageContractValidator.Destroy;
begin
  FValidatedIndexes.Free;
  inherited Destroy;
end;

procedure TNXPackageContractValidator.AddDiagnostic(const ACode, AMessage: string;
  const ARange: TNexusScriptRange);
begin
  FDiagnostics.Add(Format('%s(%d,%d): %s: %s', [ARange.SourceName,
    ARange.StartPosition.Line, ARange.StartPosition.Column, ACode, AMessage]));
end;

procedure TNXPackageContractValidator.CheckText(
  ADefinition: TNexusScriptCompiledDefinition; const AName, ACode, AMessage: string);
var
  lProperty: TNexusScriptCompiledProperty;
begin
  lProperty := ADefinition.FindProperty(AName);
  if (lProperty <> nil) and (Trim(lProperty.Value.EffectiveText) = '') then
    AddDiagnostic(ACode, AMessage, lProperty.SourceRange);
end;

function TNXPackageContractValidator.RecordBelongsToIndex(
  ARecord, AIndex: TNexusScriptCompiledDefinition): Boolean;
var
  lRecord: TNexusScriptCompiledDefinition;
begin
  Result := False;
  if (ARecord = nil) or (AIndex = nil) then Exit;
  { Imported reference targets can be detached copies. Membership is established
    against the index's declarations by their retained source identity. }
  for lRecord in AIndex.Children do
    if SameText(lRecord.Kind, ARecord.Kind) and
      FSession.SourceProvider.SameIdentity(lRecord.SourceRange.SourceName, ARecord.SourceRange.SourceName) and
      (lRecord.SourceRange.StartPosition.Offset = ARecord.SourceRange.StartPosition.Offset) then Exit(True);
end;

function TNXPackageContractValidator.RequirementIndex(
  const ARange: TNexusScriptRange): TNexusScriptCompiledDefinition;
var
  lDefinition: TNexusScriptCompiledDefinition;
  lCompiler: TNexusScriptCompiler;
begin
  Result := nil;
  lCompiler := FSession.FindCompiler(ARange.SourceName);
  if lCompiler = nil then lCompiler := FSession.EntryCompiler;
  for lDefinition in lCompiler.CompiledDocument.Definitions do
    if lDefinition.ImportedRoot and IsIndex(lDefinition) then
    begin
      if Result <> nil then
      begin
        AddDiagnostic('package-index-ambiguous',
          'Requirements need one explicitly imported PackageIndex or RepositoryIndex, not multiple catalogs',
          ARange);
        Exit(nil);
      end;
      Result := lDefinition;
    end;
  if Result = nil then
    AddDiagnostic('package-index-required', 'Requirements need an explicitly imported PackageIndex or RepositoryIndex', ARange);
end;

procedure TNXPackageContractValidator.CheckRequirements(
  ADefinition: TNexusScriptCompiledDefinition);
var
  lProperty: TNexusScriptCompiledProperty;
  lItems, lItem: TNexusScriptCompiledValue;
  lIndex, lRecord: TNexusScriptCompiledDefinition;
begin
  lProperty := ADefinition.FindProperty('Requires');
  if lProperty = nil then Exit;
  lItems := lProperty.Value;
  while lItems.EffectiveValue <> nil do lItems := lItems.EffectiveValue;
  if lItems.Items.Count = 0 then Exit;
  lIndex := RequirementIndex(lProperty.SourceRange);
  if lIndex = nil then Exit;
  ValidateImportedIndex(lIndex);
  for lItem in lItems.Items do
  begin
    lRecord := lItem.ResolvedDefinition;
    if (lItem.Kind <> nsvReference) or (lItem.ResolvedProperty <> nil) or
      not RecordBelongsToIndex(lRecord, lIndex) then
      AddDiagnostic('package-requires-record',
        'Requirement must reference a package record declared by the imported index',
        lItem.SourceRange);
  end;
end;

procedure TNXPackageContractValidator.CheckRepository(
  ARecord, AIndex: TNexusScriptCompiledDefinition);
var
  lProperty: TNexusScriptCompiledProperty;
begin
  lProperty := ARecord.FindProperty('Repository');
  if lProperty = nil then Exit;
  if (lProperty.Value.ResolvedProperty <> nil) or
    not RecordBelongsToIndex(lProperty.Value.ResolvedDefinition, AIndex) then
    AddDiagnostic('package-repository-owner',
      'Repository must reference a TrustedRepository declared by this index',
      lProperty.SourceRange);
end;

procedure TNXPackageContractValidator.ValidateImportedIndex(
  ADefinition: TNexusScriptCompiledDefinition);
var
  lCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
  lDiagnostic: TNexusScriptValidationDiagnostic;
  lIndex: TNexusScriptCompiledDefinition;
  lKey: string;
begin
  lKey := FSession.SourceProvider.CanonicalName(ADefinition.SourceRange.SourceName) +
    '#' + IntToStr(ADefinition.SourceRange.StartPosition.Offset);
  if FValidatedIndexes.IndexOf(lKey) >= 0 then Exit;
  FValidatedIndexes.Add(lKey);
  lCompiler := FSession.FindCompiler(ADefinition.SourceRange.SourceName);
  if lCompiler = nil then
  begin
    AddDiagnostic('package-index-source', 'Imported index source is not in the compilation session',
      ADefinition.SourceRange);
    Exit;
  end;
  lValidator := TNexusScriptValidator.Create;
  try
    lValidator.Validate(lCompiler.CompiledDocument,
      FSession.EntryCompiler.CompiledDocument.DialectDocument);
    for lDiagnostic in lValidator.Diagnostics do
      AddDiagnostic(lDiagnostic.Code, lDiagnostic.MessageText, lDiagnostic.SourceRange);
    if lValidator.Diagnostics.Count <> 0 then Exit;
    lIndex := lCompiler.CompiledDocument.FindDefinition(ADefinition.Name);
    CheckIndex(lIndex);
  finally
    lValidator.Free;
  end;
end;

procedure TNXPackageContractValidator.CheckDescriptor(
  ADefinition: TNexusScriptCompiledDefinition);
var
  lProperty: TNexusScriptCompiledProperty;
  lPath, lFileName: string;
begin
  lProperty := ADefinition.FindProperty('Descriptor');
  if lProperty = nil then Exit;
  lPath := lProperty.Value.EffectiveText;
  if Trim(lPath) = '' then
  begin
    AddDiagnostic('package-descriptor-empty', 'Descriptor location must not be empty',
      lProperty.SourceRange);
    Exit;
  end;
  lFileName := Copy(lPath, LastDelimiter('/\', lPath) + 1, Length(lPath));
  if (lPath[1] in ['/', '\']) or (Pos(':', lPath) > 0) or
    (Pos('*', lPath) > 0) or (Pos('?', lPath) > 0) or
    (lFileName = '') or (lFileName = '.') or (lFileName = '..') then
    AddDiagnostic('package-descriptor-relative',
      'Descriptor must be a relative file location in this repository, not a URL or search mask',
      lProperty.SourceRange);
end;

procedure TNXPackageContractValidator.CheckIndex(
  ADefinition: TNexusScriptCompiledDefinition);
var
  lEntry, lHash: TNexusScriptCompiledDefinition;
begin
  for lEntry in ADefinition.Children do
  begin
    if SameText(lEntry.Kind, 'TrustedRepository') then
    begin
      CheckText(lEntry, 'Source', 'package-repository-source-empty',
        'Canonical repository source must not be empty');
      Continue;
    end;
    CheckText(lEntry, 'Id', 'package-entry-id-empty', 'Catalog identity must not be empty');
    if SameText(lEntry.Kind, 'ExternalPackage') then CheckRepository(lEntry, ADefinition)
    else CheckDescriptor(lEntry);
    for lHash in lEntry.Children do
    begin
      CheckText(lHash, 'Algorithm', 'package-hash-algorithm-empty', 'Hash algorithm must not be empty');
      CheckText(lHash, 'Digest', 'package-hash-digest-empty', 'Hash digest must not be empty');
    end;
  end;
end;

function TNXPackageContractValidator.IsIndex(
  ADefinition: TNexusScriptCompiledDefinition): Boolean;
begin
  Result := SameText(ADefinition.Kind, 'PackageIndex') or
    SameText(ADefinition.Kind, 'RepositoryIndex');
end;

procedure TNXPackageContractValidator.CheckDefinition(ADefinition: TNexusScriptCompiledDefinition);
var
  lChild: TNexusScriptCompiledDefinition;
begin
  if SameText(ADefinition.Kind, 'Package') or SameText(ADefinition.Kind, 'Project') then
  begin
    CheckText(ADefinition, 'Id', 'package-id-empty', ADefinition.Kind + ' identity must not be empty');
    CheckRequirements(ADefinition);
  end
  else if IsIndex(ADefinition) then
  begin
    CheckIndex(ADefinition);
    Exit;
  end;
  for lChild in ADefinition.Children do CheckDefinition(lChild);
end;

procedure TNXPackageContractValidator.Validate;
var
  lDefinition: TNexusScriptCompiledDefinition;
  lView: TNexusScriptDefinitionView;
begin
  FValidatedIndexes.Clear;
  for lDefinition in FSession.EntryCompiler.CompiledDocument.Definitions do
    if lDefinition.ImportedRoot and IsIndex(lDefinition) then
      ValidateImportedIndex(lDefinition);
  lView := TNexusScriptDefinitionView.Create;
  try
    lView.AddDocument(FSession.EntryCompiler.CompiledDocument);
    for lDefinition in lView.Roots do CheckDefinition(lDefinition);
  finally
    lView.Free;
  end;
end;

end.
