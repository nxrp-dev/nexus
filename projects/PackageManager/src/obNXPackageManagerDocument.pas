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
    function GetCompiledDocument: TNexusScriptCompiledDocument;
    function GetEntityType: string;
    procedure SetSourceText(const AValue: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const AFileName: string);
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

constructor TNXPackageManagerDocument.Create;
begin
  inherited Create;
  FProvider := TNXPackageManagerSourceProvider.Create;
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

function TNXPackageManagerDocument.GetEntityType: string;
var
  lDocument: TNexusScriptCompiledDocument;
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := '';
  lDocument := CompiledDocument;
  if lDocument = nil then Exit;
  for lDefinition in lDocument.Definitions do
    if (lDefinition.Kind = 'Package') or
      (lDefinition.Kind = 'PackageIndex') or
      (lDefinition.Kind = 'Project') then
    begin
      if (Result <> '') and (Result <> lDefinition.Kind) then
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
    FreeAndNil(FAnalysis);
    FFileName := ExpandFileName(AFileName);
    FSourceText := lSource.Text;
    FDirty := False;
    FValidated := False;
    FDiagnostics.Clear;
  finally
    lSource.Free;
  end;
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
  lProperty: TNexusScriptCompiledProperty;
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
    if lDefinition.Kind = 'Package' then
    begin
      lProperty := lDefinition.FindProperty('Id');
      if (lProperty <> nil) and
        (Trim(lProperty.Value.EffectiveText) = '') then
        AddDiagnostic('package-id-empty',
          'Package identity must not be empty', lProperty.SourceRange);
    end;
  FValidated := FDiagnostics.Count = 0;
  Result := FValidated;
end;

end.
