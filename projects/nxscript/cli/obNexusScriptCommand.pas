(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNexusScriptCommand;

{$mode delphi}{$H+}

interface

uses
  Classes;

type
  TNexusScriptCommand = class
  public
    class procedure RegisterCommandLineFlags; static;
    class procedure Execute(AStdOut: TStream); static;
  end;

implementation

uses
  SysUtils,
  obNXCommandLine,
  obNexusScriptModel,
  obNexusScriptSession,
  obNexusScriptValidator,
  obNexusScriptArtifactModel,
  obNexusScriptArtifactContext,
  obNexusScriptEmitter,
  obNexusScriptEmitterFactory,
  obNexusScriptJSON,
  obNexusScriptManifest,
  SynMustache;

procedure WriteText(AStream: TStream; const AValue: string);
var
  lBytes: RawByteString;
begin
  lBytes := UTF8Encode(AValue);
  if Length(lBytes) > 0 then
    AStream.WriteBuffer(Pointer(lBytes)^, Length(lBytes));
end;

procedure WriteOutput(const AFileName, AArtifact: string; AStdOut: TStream);
var
  lStream: TFileStream;
begin
  if AFileName = '' then
  begin
    WriteText(AStdOut, AArtifact);
    Exit;
  end;
  ForceDirectories(ExtractFileDir(ExpandFileName(AFileName)));
  lStream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteText(lStream, AArtifact);
  finally
    lStream.Free;
  end;
end;

function LoadTextFile(const AFileName: string): string;
var
  lStream: TFileStream;
  lBytes: RawByteString;
begin
  if not FileExists(AFileName) then
    raise ENexusScriptCommand.CreateFmt('File not found: %s', [AFileName]);
  lStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(lBytes, lStream.Size);
    if Length(lBytes) > 0 then
      lStream.ReadBuffer(Pointer(lBytes)^, Length(lBytes));
    Result := UTF8Decode(lBytes);
  finally
    lStream.Free;
  end;
end;

function RenderTemplate(const AJSON, ATemplateFile: string): string;
var
  lTemplate: UTF8String;
begin
  lTemplate := UTF8Encode(LoadTextFile(ATemplateFile));
  Result := UTF8Decode(TSynMustache.Parse(lTemplate).
    RenderJSON(UTF8Encode(AJSON)));
end;

procedure ValidateDocument(ADocument: TNexusScriptCompiledDocument);
var
  lValidator: TNexusScriptValidator;
  lDiagnostic: TNexusScriptValidationDiagnostic;
  lMessage: string;
begin
  if ADocument.DialectDocument = nil then
    Exit;
  lValidator := TNexusScriptValidator.Create;
  try
    if lValidator.Validate(ADocument, ADocument.DialectDocument) then
      Exit;
    lMessage := 'Validation failed';
    for lDiagnostic in lValidator.Diagnostics do
      lMessage := lMessage + LineEnding + Format('%s(%d,%d): %s: %s', [
        lDiagnostic.SourceRange.SourceName,
        lDiagnostic.SourceRange.StartPosition.Line,
        lDiagnostic.SourceRange.StartPosition.Column,
        lDiagnostic.Code, lDiagnostic.MessageText]);
    raise ENexusScriptCommand.Create(lMessage);
  finally
    lValidator.Free;
  end;
end;

class procedure TNexusScriptCommand.RegisterCommandLineFlags;
begin
  TNXCommandLine.RegisterFlag('input', False, True, '',
    'NexusScript input file',
    'NexusScript source document. Required except in manifest mode.');
  TNXCommandLine.RegisterFlag('output', False, True, '',
    'Output artifact file',
    'Write the artifact to this file. When omitted, write to stdout.');
  TNXCommandLine.RegisterFlag('format', False, True, 'json',
    'Output artifact format',
    'Create the artifact with the registered emitter named by this value.');
  TNXCommandLine.RegisterFlag('template', False, True, '',
    'Mustache template file',
    'Render the generated JSON through this Mustache template.');
  TNXCommandLine.RegisterFlag('manifest', False, True, '',
    'NexusScript template manifest',
    'Compile declared models and render each template against their JSON.');
  TNXCommandLine.RegisterFlag('dialect-root', False, True, '',
    'Shared NexusScript dialect root',
    'Resolve relative dialects from this directory after the source directory.');
  TNXCommandLine.RegisterFlag('validate', False, False, '',
    'Validate before output',
    'Apply each input model''s declared dialect before output.');
end;

class procedure TNexusScriptCommand.Execute(AStdOut: TStream);
var
  lInputFile: string;
  lOutputFile: string;
  lTemplateFile: string;
  lManifestFile: string;
  lDialectRoot: string;
  lFormat: string;
  lSession: TNexusScriptCompilationSession;
  lArtifactContext: TNexusScriptArtifactContext;
  lEmitter: TNexusScriptEmitter;
  lArtifactDocument: TNexusScriptArtifactDocument;
  lArtifact: string;
begin
  lInputFile := TNXCommandLine.GetValueDefault('input', '');
  lOutputFile := TNXCommandLine.GetValueDefault('output', '');
  lTemplateFile := TNXCommandLine.GetValueDefault('template', '');
  lManifestFile := TNXCommandLine.GetValueDefault('manifest', '');
  lDialectRoot := TNXCommandLine.GetValueDefault('dialect-root', '');
  lFormat := LowerCase(TNXCommandLine.GetValueDefault('format', 'json'));
  if (lTemplateFile <> '') and (lManifestFile <> '') then
    raise ENexusScriptCommand.Create(
      'Command line flags "template" and "manifest" are mutually exclusive.');
  if (lManifestFile <> '') and (lOutputFile = '') then
    raise ENexusScriptCommand.Create(
      'NexusScript manifest rendering requires an output directory.');
  if (lManifestFile <> '') and (lInputFile <> '') then
    raise ENexusScriptCommand.Create(
      'Command line flags "input" and "manifest" are mutually exclusive.');
  if (lManifestFile <> '') and TNXCommandLine.Supplied('format') then
    raise ENexusScriptCommand.Create(
      'Command line flags "format" and "manifest" are mutually exclusive.');
  if (lTemplateFile <> '') and (lFormat <> 'json') then
    raise ENexusScriptCommand.Create(
      'Template rendering requires the json emitter.');
  if (lManifestFile = '') and (lInputFile = '') then
    raise ENexusScriptCommand.Create(
      'NexusScript input is required outside manifest mode.');
  if TNXCommandLine.SuppliedWithValue('validate') then
    raise ENexusScriptCommand.Create(
      'Command line flag "validate" does not accept a value.');
  if lManifestFile <> '' then
  begin
    TNexusScriptManifest.Render(lManifestFile, lOutputFile, lDialectRoot,
      TNXCommandLine.Supplied('validate'));
    Exit;
  end;
  lEmitter := TNexusScriptEmitterFactory.CreateEmitter(lFormat);
  lSession := nil;
  lArtifactContext := nil;
  try
    lSession := TNexusScriptCompilationSession.Create;
    lSession.DialectRoot := lDialectRoot;
    if not lSession.CompileFile(lInputFile) then
      raise ENexusScriptCommand.Create(lSession.LastError);
    if TNXCommandLine.Supplied('validate') then
      ValidateDocument(lSession.EntryCompiler.CompiledDocument);
    lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
    lArtifactContext.Build;
    for lArtifactDocument in lArtifactContext.ArtifactDocuments do
      lEmitter.AddDocument(lArtifactDocument.CompiledDocument);
    if lTemplateFile <> '' then
    begin
      lArtifact := TNexusScriptJSONEmitter(lEmitter).JSON;
      lArtifact := RenderTemplate(lArtifact, lTemplateFile);
      WriteOutput(lOutputFile, lArtifact, AStdOut);
    end
    else
      if lOutputFile <> '' then
        lEmitter.WriteArtifact(lOutputFile)
      else
        lEmitter.WriteArtifact(AStdOut);
  finally
    lArtifactContext.Free;
    lSession.Free;
    lEmitter.Free;
  end;
end;

end.
