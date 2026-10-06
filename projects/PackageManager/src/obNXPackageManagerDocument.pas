(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPackageManagerDocument;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, obNexusScriptAnalysis, obNexusScriptModel,
  obNexusScriptSourceProvider, tpNexusScript;

type
  TNXPackageManagerSourceProvider = class(TNexusScriptFileSourceProvider)
  private
    FEntryName: string;
    FEntryText: string;
  public
    procedure SetEntry(const AName, AText: string);
    function Exists(const ASourceName: string): Boolean; override;
    function ReadSource(const ASourceName: string; out AText: string;
      out AVersion: Integer): Boolean; override;
  end;

  TNXPackageManagerDocument = class
  private
    FAnalysis: TNexusScriptAnalysis;
    FDiagnostics: TStringList;
    FDirty: Boolean;
    FFileName: string;
    FProvider: TNXPackageManagerSourceProvider;
    FSourceText: string;
    FValidated: Boolean;
    procedure AddDiagnostic(const ACode, AMessage: string;
      const ARange: TNexusScriptRange);
  protected
    procedure CheckText(ADefinition: TNexusScriptCompiledDefinition;
      const AName, ACode, AMessage: string);
    procedure CheckDescriptor(ADefinition: TNexusScriptCompiledDefinition);
    procedure CheckPackageIndex(ADefinition: TNexusScriptCompiledDefinition);
    procedure CheckRequirements(ADefinition: TNexusScriptCompiledDefinition);
    procedure CheckRepository(ARecord, AIndex: TNexusScriptCompiledDefinition);
    function RecordBelongsToIndex(ARecord, AIndex: TNexusScriptCompiledDefinition): Boolean;
    function RequirementIndex(const ARange: TNexusScriptRange): TNexusScriptCompiledDefinition;
    procedure ValidateImportedIndex(ADefinition: TNexusScriptCompiledDefinition);
    function GetCompiledDocument: TNexusScriptCompiledDocument;
    function GetEntityType: string;
    procedure SetSourceText(const AValue: string);
  public
    // The document owns AProvider when supplied, otherwise it creates its own.
    constructor Create(AProvider: TNXPackageManagerSourceProvider = nil);
    destructor Destroy; override;
    procedure Load(const AFileName: string);
    procedure LoadSource(const AFileName, ASourceText: string);
    procedure Save;
    function Validate: Boolean;
    property CompiledDocument: TNexusScriptCompiledDocument
      read GetCompiledDocument;
    property Diagnostics: TStringList read FDiagnostics;
    property Dirty: Boolean read FDirty;
    property EntityType: string read GetEntityType;
    property FileName: string read FFileName;
    property SourceText: string read FSourceText write SetSourceText;
    property Validated: Boolean read FValidated;
  end;

implementation

uses
  obNexusScriptCompiler, obNexusScriptLanguageDefinition,
  obNexusScriptValidator;

procedure TNXPackageManagerSourceProvider.SetEntry(const AName, AText: string);
begin
  FEntryName := CanonicalName(AName);
  FEntryText := AText;
end;

function TNXPackageManagerSourceProvider.Exists(
  const ASourceName: string): Boolean;
begin
  Result := ((FEntryName <> '') and SameIdentity(ASourceName, FEntryName)) or
    inherited Exists(ASourceName);
end;

function TNXPackageManagerSourceProvider.ReadSource(
  const ASourceName: string; out AText: string;
  out AVersion: Integer): Boolean;
begin
  if (FEntryName <> '') and SameIdentity(ASourceName, FEntryName) then
  begin
    AText := FEntryText;
    AVersion := 1;
    Exit(True);
  end;
  Result := inherited ReadSource(ASourceName, AText, AVersion);
end;

constructor TNXPackageManagerDocument.Create(AProvider: TNXPackageManagerSourceProvider);
begin
  inherited Create;
  FProvider := AProvider;
  if FProvider = nil then FProvider := TNXPackageManagerSourceProvider.Create;
  FDiagnostics := TStringList.Create;
end;

destructor TNXPackageManagerDocument.Destroy;
begin
  FAnalysis.Free;
  FDiagnostics.Free;
  FProvider.Free;
  inherited Destroy;
end;

procedure TNXPackageManagerDocument.AddDiagnostic(const ACode,
  AMessage: string; const ARange: TNexusScriptRange);
begin
  FDiagnostics.Add(Format('%s(%d,%d): %s: %s', [
    ARange.SourceName, ARange.StartPosition.Line,
    ARange.StartPosition.Column, ACode, AMessage]));
end;

function TNXPackageManagerDocument.GetCompiledDocument:
  TNexusScriptCompiledDocument;
begin
  Result := nil;
  if FValidated and (FAnalysis <> nil) and
    (FAnalysis.EntryCompiler <> nil) then
    Result := FAnalysis.EntryCompiler.CompiledDocument;
end;

procedure TNXPackageManagerDocument.CheckText(
  ADefinition: TNexusScriptCompiledDefinition; const AName, ACode, AMessage: string);
var
  lProperty: TNexusScriptCompiledProperty;
begin
  lProperty := ADefinition.FindProperty(AName);
  if (lProperty <> nil) and (Trim(lProperty.Value.EffectiveText) = '') then
    AddDiagnostic(ACode, AMessage, lProperty.SourceRange);
end;

function TNXPackageManagerDocument.RecordBelongsToIndex(
  ARecord, AIndex: TNexusScriptCompiledDefinition): Boolean;
var
  lRecord: TNexusScriptCompiledDefinition;
begin
  Result := False;
  if (ARecord = nil) or (AIndex = nil) or (ARecord.Parent = nil) then Exit;
  if not SameText(ARecord.Parent.Kind, 'PackageIndex') or
    not FProvider.SameIdentity(ARecord.Parent.SourceRange.SourceName, AIndex.SourceRange.SourceName) or
    (ARecord.Parent.SourceRange.StartPosition.Offset <> AIndex.SourceRange.StartPosition.Offset) then Exit;
  { Imports retain source identity even when their compiled objects are copied. }
  for lRecord in AIndex.Children do
    if SameText(lRecord.Kind, ARecord.Kind) and
      FProvider.SameIdentity(lRecord.SourceRange.SourceName, ARecord.SourceRange.SourceName) and
      (lRecord.SourceRange.StartPosition.Offset = ARecord.SourceRange.StartPosition.Offset) then Exit(True);
end;

function TNXPackageManagerDocument.RequirementIndex(
  const ARange: TNexusScriptRange): TNexusScriptCompiledDefinition;
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := nil;
  for lDefinition in FAnalysis.EntryCompiler.CompiledDocument.Definitions do
    if lDefinition.ImportedRoot and SameText(lDefinition.Kind, 'PackageIndex') then
    begin
      if Result <> nil then
      begin
        AddDiagnostic('package-index-ambiguous',
          'Requirements need one explicitly imported PackageIndex, not multiple catalogs',
          ARange);
        Exit(nil);
      end;
      Result := lDefinition;
    end;
  if Result = nil then
    AddDiagnostic('package-index-required', 'Requirements need an explicitly imported PackageIndex', ARange);
end;

procedure TNXPackageManagerDocument.CheckRequirements(
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
  for lItem in lItems.Items do
  begin
    lRecord := lItem.ResolvedDefinition;
    if (lItem.Kind <> nsvReference) or (lItem.ResolvedProperty <> nil) or
      not RecordBelongsToIndex(lRecord, lIndex) then
      AddDiagnostic('package-requires-record',
        'Requirement must reference a package record declared by the imported PackageIndex',
        lItem.SourceRange);
  end;
end;

procedure TNXPackageManagerDocument.CheckRepository(
  ARecord, AIndex: TNexusScriptCompiledDefinition);
var
  lProperty: TNexusScriptCompiledProperty;
begin
  lProperty := ARecord.FindProperty('Repository');
  if lProperty = nil then Exit;
  if (lProperty.Value.ResolvedProperty <> nil) or
    not RecordBelongsToIndex(lProperty.Value.ResolvedDefinition, AIndex) then
    AddDiagnostic('package-repository-owner',
      'Repository must reference a TrustedRepository declared by this PackageIndex',
      lProperty.SourceRange);
end;

procedure TNXPackageManagerDocument.ValidateImportedIndex(
  ADefinition: TNexusScriptCompiledDefinition);
var
  lCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
  lDiagnostic: TNexusScriptValidationDiagnostic;
  lIndex: TNexusScriptCompiledDefinition;
begin
  lCompiler := FAnalysis.Session.FindCompiler(ADefinition.SourceRange.SourceName);
  if lCompiler = nil then
  begin
    AddDiagnostic('package-index-source', 'Imported index source is not in the compilation session',
      ADefinition.SourceRange);
    Exit;
  end;
  lValidator := TNexusScriptValidator.Create;
  try
    lValidator.Validate(lCompiler.CompiledDocument,
      FAnalysis.EntryCompiler.CompiledDocument.DialectDocument);
    for lDiagnostic in lValidator.Diagnostics do
      AddDiagnostic(lDiagnostic.Code, lDiagnostic.MessageText, lDiagnostic.SourceRange);
    if lValidator.Diagnostics.Count <> 0 then Exit;
    lIndex := lCompiler.CompiledDocument.FindDefinition(ADefinition.Name);
    CheckPackageIndex(lIndex);
  finally
    lValidator.Free;
  end;
end;

procedure TNXPackageManagerDocument.CheckDescriptor(
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

procedure TNXPackageManagerDocument.CheckPackageIndex(
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

function TNXPackageManagerDocument.GetEntityType: string;
var
  lDocument: TNexusScriptCompiledDocument;
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := '';
  lDocument := CompiledDocument;
  if lDocument = nil then Exit;
  for lDefinition in lDocument.Definitions do
    if not lDefinition.ImportedRoot and (SameText(lDefinition.Kind, 'Package') or
      SameText(lDefinition.Kind, 'PackageIndex') or SameText(lDefinition.Kind, 'Project')) then
    begin
      if (Result <> '') and not SameText(Result, lDefinition.Kind) then
        Exit('Mixed');
      Result := lDefinition.Kind;
    end;
end;

procedure TNXPackageManagerDocument.SetSourceText(const AValue: string);
begin
  if FSourceText = AValue then Exit;
  FSourceText := AValue;
  FDirty := True;
  FValidated := False;
  FDiagnostics.Clear;
end;

procedure TNXPackageManagerDocument.Load(const AFileName: string);
var
  lSource: TStringList;
begin
  lSource := TStringList.Create;
  try
    lSource.LoadFromFile(AFileName);
    LoadSource(AFileName, lSource.Text);
  finally
    lSource.Free;
  end;
end;

procedure TNXPackageManagerDocument.LoadSource(const AFileName,
  ASourceText: string);
begin
  FreeAndNil(FAnalysis);
  FFileName := ExpandFileName(AFileName);
  FSourceText := ASourceText;
  FDirty := False;
  FValidated := False;
  FDiagnostics.Clear;
end;

procedure TNXPackageManagerDocument.Save;
var
  lFile: TFileStream;
begin
  if FFileName = '' then
    raise Exception.Create('No document is open');
  lFile := TFileStream.Create(FFileName, fmCreate);
  try
    if FSourceText <> '' then
      lFile.WriteBuffer(FSourceText[1], Length(FSourceText));
    FDirty := False;
  finally
    lFile.Free;
  end;
end;

function TNXPackageManagerDocument.Validate: Boolean;
var
  lCompiler: TNexusScriptCompiler;
  lDefinition: TNexusScriptCompiledDefinition;
  lDiagnostic: TNexusScriptDiagnostic;
  lValidationDiagnostic: TNexusScriptValidationDiagnostic;
  lIndex: Integer;
begin
  Result := False;
  FValidated := False;
  FDiagnostics.Clear;
  if FFileName = '' then
    raise Exception.Create('No document is open');
  FreeAndNil(FAnalysis);
  FProvider.SetEntry(FFileName, FSourceText);
  FAnalysis := TNexusScriptAnalysis.Create(FFileName, 1, FProvider);
  FAnalysis.Execute;
  for lDiagnostic in FAnalysis.Session.Diagnostics do
    AddDiagnostic(lDiagnostic.Code, lDiagnostic.MessageText,
      lDiagnostic.SourceRange);
  for lIndex := 0 to FAnalysis.Session.AttemptedCompilerCount - 1 do
  begin
    lCompiler := FAnalysis.Session.AttemptedCompilers[lIndex];
    for lDiagnostic in lCompiler.Diagnostics do
      AddDiagnostic(lDiagnostic.Code, lDiagnostic.MessageText,
        lDiagnostic.SourceRange);
  end;
  if not FAnalysis.Succeeded then
  begin
    if FDiagnostics.Count = 0 then
      FDiagnostics.Add(FAnalysis.Session.LastError);
    Exit;
  end;
  if FAnalysis.EntryCompiler.CompiledDocument.DialectDocument = nil then
  begin
    FDiagnostics.Add('A PackageManager dialect declaration is required');
    Exit;
  end;
  for lIndex := 0 to FAnalysis.Language.DiagnosticCount - 1 do
    AddDiagnostic(FAnalysis.Language.Diagnostics[lIndex].Code,
      FAnalysis.Language.Diagnostics[lIndex].MessageText,
      FAnalysis.Language.Diagnostics[lIndex].SourceRange);
  for lValidationDiagnostic in FAnalysis.Validator.Diagnostics do
    AddDiagnostic(lValidationDiagnostic.Code,
      lValidationDiagnostic.MessageText,
      lValidationDiagnostic.SourceRange);
  if FDiagnostics.Count <> 0 then Exit;
  for lDefinition in FAnalysis.EntryCompiler.CompiledDocument.Definitions do
    if lDefinition.ImportedRoot then
    begin
      if SameText(lDefinition.Kind, 'PackageIndex') then ValidateImportedIndex(lDefinition);
    end
    else if SameText(lDefinition.Kind, 'Package') then
    begin
      CheckText(lDefinition, 'Id', 'package-id-empty', 'Package identity must not be empty');
      CheckRequirements(lDefinition);
    end
    else if SameText(lDefinition.Kind, 'PackageIndex') then CheckPackageIndex(lDefinition);
  FValidated := FDiagnostics.Count = 0;
  Result := FValidated;
end;

end.
