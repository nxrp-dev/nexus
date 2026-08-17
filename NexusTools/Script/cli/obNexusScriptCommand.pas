unit obNexusScriptCommand;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils;

type
  ENexusScriptCommand = class(Exception);

  TNexusScriptCommand = class
  private
    class function LoadTextFile(const AFileName: string): string; static;
    class procedure WriteText(AStream: TStream; const AValue: string); static;
    class procedure WriteOutput(const AFileName, AArtifact: string;
      AStdOut: TStream); static;
    class function RenderTemplate(const AJSON,
      ATemplateFile: string): string; static;
  public
    class procedure RegisterCommandLineFlags; static;
    class procedure Execute(AStdOut: TStream); static;
  end;

implementation

uses
  obNXCommandLine,
  obNexusScriptSession,
  obNexusScriptValidator,
  obNexusScriptSchemaConsumer,
  obMetaDataModuleList,
  obMetaDataTransformations,
  obMetaDataJSON,
  obMustacheRenderer;

function ValidationFailureText(
  ADiagnostics: TNexusScriptValidationDiagnosticList): string;
var
  lDiagnostic: TNexusScriptValidationDiagnostic;
begin
  Result := 'Validation failed';
  for lDiagnostic in ADiagnostics do
    Result := Result + LineEnding + Format('%s(%d,%d): %s: %s', [
      lDiagnostic.SourceRange.SourceName,
      lDiagnostic.SourceRange.StartPosition.Line,
      lDiagnostic.SourceRange.StartPosition.Column,
      lDiagnostic.Code,
      lDiagnostic.MessageText]);
end;

class function TNexusScriptCommand.LoadTextFile(
  const AFileName: string): string;
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
    Result := string(lBytes);
  finally
    lStream.Free;
  end;
end;

class procedure TNexusScriptCommand.WriteText(AStream: TStream;
  const AValue: string);
var
  lText: UTF8String;
begin
  if AStream = nil then
    raise ENexusScriptCommand.Create('Output stream is not available.');
  lText := UTF8Encode(AValue);
  if Length(lText) > 0 then
    AStream.WriteBuffer(Pointer(lText)^, Length(lText));
end;

class procedure TNexusScriptCommand.WriteOutput(const AFileName,
  AArtifact: string; AStdOut: TStream);
var
  lDirectory: string;
  lStream: TFileStream;
begin
  if AFileName = '' then
  begin
    WriteText(AStdOut, AArtifact);
    Exit;
  end;

  lDirectory := ExtractFileDir(ExpandFileName(AFileName));
  if (lDirectory <> '') and not DirectoryExists(lDirectory) and
    not ForceDirectories(lDirectory) then
    raise ENexusScriptCommand.CreateFmt(
      'Unable to create output directory: %s', [lDirectory]);

  lStream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteText(lStream, AArtifact);
  finally
    lStream.Free;
  end;
end;

class function TNexusScriptCommand.RenderTemplate(const AJSON,
  ATemplateFile: string): string;
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

class procedure TNexusScriptCommand.RegisterCommandLineFlags;
begin
  TNXCommandLine.RegisterFlag('input', True, True, '',
    'NexusScript input file',
    'Required NexusScript source document used to produce an artifact.');
  TNXCommandLine.RegisterFlag('output', False, True, '',
    'Output artifact file',
    'Write the artifact to this file. When omitted, write to stdout.');
  TNXCommandLine.RegisterFlag('template', False, True, '',
    'Mustache template file',
    'Render the generated JSON through this Mustache template.');
  TNXCommandLine.RegisterFlag('validate', False, False, '',
    'Validate before output',
    'Validate through the input document''s explicit doctype association.');
end;

class procedure TNexusScriptCommand.Execute(AStdOut: TStream);
var
  lInputFile: string;
  lOutputFile: string;
  lTemplateFile: string;
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
  lSchemaConversion: TNexusScriptSchemaConsumer;
  lMetaData: TMetaDataModuleList;
  lTransformation: TMetaDataTransform;
  lArtifactDocument: TNexusScriptArtifactDocument;
  lArtifact: string;
begin
  lInputFile := TNXCommandLine.Value['input'];
  lOutputFile := TNXCommandLine.GetValueDefault('output', '');
  lTemplateFile := TNXCommandLine.GetValueDefault('template', '');

  if TNXCommandLine.SuppliedWithValue('validate') then
    raise ENexusScriptCommand.Create(
      'Command line flag "validate" does not accept a value.');

  lSession := TNexusScriptCompilationSession.Create;
  try
    if not lSession.CompileFile(lInputFile) then
      raise ENexusScriptCommand.Create(lSession.LastError);

    if TNXCommandLine.Supplied('validate') then
    begin
      if lSession.EntryCompiler.CompiledDocument.DoctypeDocument = nil then
        raise ENexusScriptCommand.Create(
          'Validation requires an explicit doctype association.');
      lValidator := TNexusScriptValidator.Create;
      try
        if not lValidator.Validate(
          lSession.EntryCompiler.CompiledDocument,
          lSession.EntryCompiler.CompiledDocument.DoctypeDocument) then
        begin
          raise ENexusScriptCommand.Create(
            ValidationFailureText(lValidator.Diagnostics));
        end;
      finally
        lValidator.Free;
      end;
    end;

    lMetaData := TMetaDataModuleList.Create;
    lSchemaConversion := TNexusScriptSchemaConsumer.Create;
    try
      for lArtifactDocument in lSession.ArtifactDocuments do
        if not lSchemaConversion.Consume(lArtifactDocument.SourceDocument,
          lArtifactDocument.CompiledDocument, lMetaData) then
          raise ENexusScriptCommand.CreateFmt(
            'Unable to produce an artifact from %s.',
            [lArtifactDocument.CompiledDocument.SourceName]);
      lTransformation := TMetaDataTransform.Create;
      try
        lTransformation.Transform(lMetaData);
      finally
        lTransformation.Free;
      end;
      lArtifact := MetaDataToMustacheJSON(lMetaData);
    finally
      lSchemaConversion.Free;
      lMetaData.Free;
    end;

    if lTemplateFile <> '' then
      lArtifact := RenderTemplate(lArtifact, lTemplateFile);

    WriteOutput(lOutputFile, lArtifact, AStdOut);
  finally
    lSession.Free;
  end;
end;

end.
