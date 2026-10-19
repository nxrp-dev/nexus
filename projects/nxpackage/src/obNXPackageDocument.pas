(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPackageDocument;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, obNexusScriptAnalysis, obNexusScriptModel,
  obNexusScriptSourceProvider, tpNexusScript;

type
  TNXPackageSourceProvider = class(TNexusScriptFileSourceProvider)
  private
    FEntryName: string;
    FEntryText: string;
  public
    procedure SetEntry(const AName, AText: string);
    function Exists(const ASourceName: string): Boolean; override;
    function ReadSource(const ASourceName: string; out AText: string;
      out AVersion: Integer): Boolean; override;
  end;

  TNXPackageDocument = class
  private
    FAnalysis: TNexusScriptAnalysis;
    FDiagnostics: TStringList;
    FDirty: Boolean;
    FFileName: string;
    FProvider: TNXPackageSourceProvider;
    FProjectTargets: TNexusScriptTargetSelection;
    FSourceText: string;
    FValidated: Boolean;
    procedure AddDiagnostic(const ACode, AMessage: string;
      const ARange: TNexusScriptRange);
  protected
    function GetCompiledDocument: TNexusScriptCompiledDocument;
    function GetEntityType: string;
    procedure SetSourceText(const AValue: string);
  public
    // The document owns AProvider when supplied, otherwise it creates its own.
    constructor Create(AProvider: TNXPackageSourceProvider = nil);
    destructor Destroy; override;
    procedure Load(const AFileName: string);
    procedure LoadSource(const AFileName, ASourceText: string);
    procedure Save;
    procedure SetTarget(const AName, AValue: string);
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
  obNexusScriptValidator, obNXPackageContractValidator,
  obNXBuildDescription, obNXBuildDescriptionLoader, obNXBuildPlanner;

procedure TNXPackageSourceProvider.SetEntry(const AName, AText: string);
begin
  FEntryName := CanonicalName(AName);
  FEntryText := AText;
end;

function TNXPackageSourceProvider.Exists(
  const ASourceName: string): Boolean;
begin
  Result := ((FEntryName <> '') and SameIdentity(ASourceName, FEntryName)) or
    inherited Exists(ASourceName);
end;

function TNXPackageSourceProvider.ReadSource(
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

constructor TNXPackageDocument.Create(AProvider: TNXPackageSourceProvider);
begin
  inherited Create;
  FProvider := AProvider;
  if FProvider = nil then FProvider := TNXPackageSourceProvider.Create;
  FDiagnostics := TStringList.Create;
  FProjectTargets := TNexusScriptTargetSelection.Create;
  FProjectTargets.Add('TargetOS', {$I %FPCTARGETOS%});
  FProjectTargets.Add('TargetCPU', {$I %FPCTARGETCPU%});
end;

destructor TNXPackageDocument.Destroy;
begin
  FAnalysis.Free;
  FProjectTargets.Free;
  FDiagnostics.Free;
  FProvider.Free;
  inherited Destroy;
end;

procedure TNXPackageDocument.AddDiagnostic(const ACode,
  AMessage: string; const ARange: TNexusScriptRange);
begin
  FDiagnostics.Add(Format('%s(%d,%d): %s: %s', [
    ARange.SourceName, ARange.StartPosition.Line,
    ARange.StartPosition.Column, ACode, AMessage]));
end;

function TNXPackageDocument.GetCompiledDocument:
  TNexusScriptCompiledDocument;
begin
  Result := nil;
  if FValidated and (FAnalysis <> nil) and
    (FAnalysis.EntryCompiler <> nil) then
    Result := FAnalysis.EntryCompiler.CompiledDocument;
end;

function TNXPackageDocument.GetEntityType: string;
var
  lDocument: TNexusScriptCompiledDocument;
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := '';
  lDocument := CompiledDocument;
  if lDocument = nil then Exit;
  for lDefinition in lDocument.Definitions do
    if not lDefinition.ImportedRoot and
      (SameText(lDefinition.Kind, 'Package') or
      SameText(lDefinition.Kind, 'Project') or SameText(lDefinition.Kind, 'PackageIndex') or
      SameText(lDefinition.Kind, 'RepositoryIndex') or SameText(lDefinition.Kind, 'ProjectIndex')) then
    begin
      if (Result <> '') and not SameText(Result, lDefinition.Kind) then
        Exit('Mixed');
      Result := lDefinition.Kind;
    end;
end;

procedure TNXPackageDocument.SetSourceText(const AValue: string);
begin
  if FSourceText = AValue then Exit;
  FSourceText := AValue;
  FDirty := True;
  FValidated := False;
  FDiagnostics.Clear;
end;

procedure TNXPackageDocument.Load(const AFileName: string);
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

procedure TNXPackageDocument.LoadSource(const AFileName,
  ASourceText: string);
begin
  FreeAndNil(FAnalysis);
  FFileName := ExpandFileName(AFileName);
  FSourceText := ASourceText;
  FDirty := False;
  FValidated := False;
  FDiagnostics.Clear;
end;

procedure TNXPackageDocument.Save;
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

procedure TNXPackageDocument.SetTarget(const AName, AValue: string);
begin
  FProjectTargets.SetValue(AName, AValue);
  FValidated := False;
  FDiagnostics.Clear;
end;

function TNXPackageDocument.Validate: Boolean;
var
  lCompiler: TNexusScriptCompiler;
  lContracts: TNXPackageContractValidator;
  lDiagnostic: TNexusScriptDiagnostic;
  lValidationDiagnostic: TNexusScriptValidationDiagnostic;
  lIndex, lProjectCount, lIndexCount: Integer;
  lTargets: TNexusScriptTargetSelection;
  lDefinition: TNexusScriptCompiledDefinition;
  lLoader: TNXBuildDescriptionLoader;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
begin
  Result := False;
  FValidated := False;
  FDiagnostics.Clear;
  if FFileName = '' then
    raise Exception.Create('No document is open');
  FreeAndNil(FAnalysis);
  FProvider.SetEntry(FFileName, FSourceText);
  lTargets := nil;
  if SameText(ExtractFileExt(FFileName), '.nxproject') then lTargets := FProjectTargets;
  FAnalysis := TNexusScriptAnalysis.Create(FFileName, 1, FProvider, lTargets);
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
    FDiagnostics.Add('A NexusScript dialect declaration is required');
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
  if FAnalysis.EntryCompiler.CompiledDocument.DialectDocument.FindDefinition('nxbuild') <> nil then
  begin
    lProjectCount := 0;
    lIndexCount := 0;
    for lDefinition in FAnalysis.EntryCompiler.CompiledDocument.Definitions do
      if not lDefinition.ImportedRoot then
      begin
        if SameText(lDefinition.Kind, 'Project') then Inc(lProjectCount);
        if SameText(lDefinition.Kind, 'ProjectIndex') then Inc(lIndexCount);
      end;
    if (lProjectCount + lIndexCount) <> 1 then
    begin
      FDiagnostics.Add('Exactly one Project or ProjectIndex root is required.');
      Exit;
    end;
    if lProjectCount = 1 then
    begin
      lLoader := TNXBuildDescriptionLoader.Create;
      lPlanner := TNXBuildPlanner.Create;
      lDescription := nil;
      try
        try
          lDescription := lLoader.LoadAnalysis(FAnalysis, lTargets);
          lPlan := lPlanner.CreatePlan(lDescription, False);
          lPlan.Free;
        except
          on E: Exception do FDiagnostics.Add(E.Message);
        end;
      finally
        lDescription.Free;
        lPlanner.Free;
        lLoader.Free;
      end;
    end;
    FValidated := FDiagnostics.Count = 0;
    Exit(FValidated);
  end;
  lContracts := TNXPackageContractValidator.Create(FAnalysis.Session, FDiagnostics);
  try
    lContracts.Validate;
  finally
    lContracts.Free;
  end;
  FValidated := FDiagnostics.Count = 0;
  Result := FValidated;
end;

end.
