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
  obNexusScriptJSON,
  obNexusScriptManifest,
  obMustacheRenderer;

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
  lJSONFile: string;
  lOutputFile: string;
begin
  if not FileExists(ATemplateFile) then
    raise ENexusScriptCommand.CreateFmt('File not found: %s', [ATemplateFile]);
  lJSONFile := GetTempFileName(GetTempDir, 'nsj');
  lOutputFile := GetTempFileName(GetTempDir, 'nso');
  try
    WriteOutput(lJSONFile, AJSON, nil);
    RenderMustacheFile(lJSONFile, ATemplateFile, lOutputFile);
    Result := LoadTextFile(lOutputFile);
  finally
    DeleteFile(lOutputFile);
    DeleteFile(lJSONFile);
  end;
end;

procedure ValidateDocument(ADocument: TNexusScriptCompiledDocument);
var
  lValidator: TNexusScriptValidator;
  lDiagnostic: TNexusScriptValidationDiagnostic;
  lMessage: string;
begin
  if ADocument.DoctypeDocument = nil then
    Exit;
  lValidator := TNexusScriptValidator.Create;
  try
    if lValidator.Validate(ADocument, ADocument.DoctypeDocument) then
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
  TNXCommandLine.RegisterFlag('template', False, True, '',
    'Mustache template file',
    'Render the generated JSON through this Mustache template.');
  TNXCommandLine.RegisterFlag('manifest', False, True, '',
    'NexusScript template manifest',
    'Compile declared models and render each template against their JSON.');
  TNXCommandLine.RegisterFlag('validate', False, False, '',
    'Validate before output',
    'Apply each input model''s declared doctype before output.');
end;

class procedure TNexusScriptCommand.Execute(AStdOut: TStream);
var
  lInputFile: string;
  lOutputFile: string;
  lTemplateFile: string;
  lManifestFile: string;
  lSession: TNexusScriptCompilationSession;
  lArtifactContext: TNexusScriptArtifactContext;
  lJSONEmitter: TNexusScriptJSONEmitter;
  lArtifactDocument: TNexusScriptArtifactDocument;
  lArtifact: string;
begin
  lInputFile := TNXCommandLine.GetValueDefault('input', '');
  lOutputFile := TNXCommandLine.GetValueDefault('output', '');
  lTemplateFile := TNXCommandLine.GetValueDefault('template', '');
  lManifestFile := TNXCommandLine.GetValueDefault('manifest', '');
  if (lTemplateFile <> '') and (lManifestFile <> '') then
    raise ENexusScriptCommand.Create(
      'Command line flags "template" and "manifest" are mutually exclusive.');
  if (lManifestFile <> '') and (lOutputFile = '') then
    raise ENexusScriptCommand.Create(
      'NexusScript manifest rendering requires an output directory.');
  if (lManifestFile <> '') and (lInputFile <> '') then
    raise ENexusScriptCommand.Create(
      'Command line flags "input" and "manifest" are mutually exclusive.');
  if (lManifestFile = '') and (lInputFile = '') then
    raise ENexusScriptCommand.Create(
      'NexusScript input is required outside manifest mode.');
  if TNXCommandLine.SuppliedWithValue('validate') then
    raise ENexusScriptCommand.Create(
      'Command line flag "validate" does not accept a value.');
  if lManifestFile <> '' then
  begin
    TNexusScriptManifest.Render(lManifestFile, lOutputFile,
      TNXCommandLine.Supplied('validate'));
    Exit;
  end;
  lSession := TNexusScriptCompilationSession.Create;
  lArtifactContext := nil;
  try
    if not lSession.CompileFile(lInputFile) then
      raise ENexusScriptCommand.Create(lSession.LastError);
    if TNXCommandLine.Supplied('validate') then
      ValidateDocument(lSession.EntryCompiler.CompiledDocument);
    lJSONEmitter := TNexusScriptJSONEmitter.Create;
    try
      lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
      lArtifactContext.Build;
      for lArtifactDocument in lArtifactContext.ArtifactDocuments do
        lJSONEmitter.AddDocument(lArtifactDocument.CompiledDocument);
      lArtifact := lJSONEmitter.JSON;
    finally
      lJSONEmitter.Free;
    end;
    if lTemplateFile <> '' then
      lArtifact := RenderTemplate(lArtifact, lTemplateFile);
    WriteOutput(lOutputFile, lArtifact, AStdOut);
  finally
    lArtifactContext.Free;
    lSession.Free;
  end;
end;

end.
