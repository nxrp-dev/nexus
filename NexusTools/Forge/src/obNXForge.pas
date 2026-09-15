unit obNXForge;

{$mode delphi}{$H+}

interface

uses Classes, SysUtils, Generics.Collections, obNexusScriptModel,
  obNexusScriptSession, obNXForgeProcess;

type
  ENXForge = class(Exception);

  TNXForge = class
  private
    FTargets: TNexusScriptTargetSelection;
    FOperations: TNexusScriptCompilationSession;
    FInvocations: TObjectList<TNXForgeInvocation>;
    FDiagnostic: string;
    procedure Prepare(AOperations: TNexusScriptCompiledDefinitionList;
      const AWorkingDirectory: string; AContexts: TStrings);
  public
    constructor Create(ATargets: TNexusScriptTargetSelection = nil);
    destructor Destroy; override;
    function Execute(const AInput: string;
      const AWorkingDirectory: string = ''): Boolean;
    function ExecuteDefinitions(AOperations: TNexusScriptCompiledDefinitionList;
      const AWorkingDirectory: string; AContexts: TStrings = nil): Boolean;
    property Invocations: TObjectList<TNXForgeInvocation> read FInvocations;
    property Diagnostic: string read FDiagnostic;
  end;

procedure CompileForgeDocument(ASession: TNexusScriptCompilationSession;
  const AFileName: string);
function ForgePropertyText(ADefinition: TNexusScriptCompiledDefinition;
  const AName: string): string;
function ForgeRelativePath(const ABase, APath: string): string;

implementation

uses SynMustache, obNexusScriptJSON, obNexusScriptValidator,
  obNexusScriptDefinitionView, obNexusScriptArtifactModel, tpNexusScript;

function ReadForgeText(const AFileName: string): string;
var
  lFile: TFileStream;
begin
  lFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, lFile.Size);
    if lFile.Size > 0 then lFile.ReadBuffer(Result[1], lFile.Size);
  finally
    lFile.Free;
  end;
end;

function ForgePropertyText(ADefinition: TNexusScriptCompiledDefinition;
  const AName: string): string;
var
  lProperty: TNexusScriptCompiledProperty;
begin
  lProperty := ADefinition.FindProperty(AName);
  if (lProperty = nil) or not lProperty.Value.HasEffectiveText then
    raise ENXForge.Create(ADefinition.Name + ': missing text property ' + AName);
  Result := lProperty.Value.EffectiveText;
end;

function ForgeRelativePath(const ABase, APath: string): string;
begin
  if (ExtractFileDrive(APath) <> '') or
    ((APath <> '') and IsPathDelimiter(APath, 1)) then Result := ExpandFileName(APath)
  else Result := ExpandFileName(IncludeTrailingPathDelimiter(ABase) + APath);
end;

constructor TNXForge.Create(ATargets: TNexusScriptTargetSelection);
begin
  inherited Create;
  FTargets := TNexusScriptTargetSelection.Create;
  FTargets.Assign(ATargets);
  FInvocations := TObjectList<TNXForgeInvocation>.Create(True);
end;

destructor TNXForge.Destroy;
begin
  FInvocations.Free;
  FOperations.Free;
  FTargets.Free;
  inherited Destroy;
end;

procedure CompileForgeDocument(ASession: TNexusScriptCompilationSession;
  const AFileName: string);
var
  lDocument: TNexusScriptCompiledDocument;
  lValidator: TNexusScriptValidator;
  lDiagnostic: TNexusScriptValidationDiagnostic;
  lMessage: string;
begin
  if not ASession.CompileFile(AFileName) then
    raise ENXForge.Create(ASession.LastError);
  lDocument := ASession.EntryCompiler.CompiledDocument;
  if lDocument.DialectDocument = nil then
    raise ENXForge.Create(AFileName + ': a declared dialect is required');
  lValidator := TNexusScriptValidator.Create;
  try
    if lValidator.Validate(lDocument, lDocument.DialectDocument) then Exit;
    lMessage := 'Validation failed: ' + AFileName;
    for lDiagnostic in lValidator.Diagnostics do
      lMessage := lMessage + LineEnding + Format('%s(%d,%d): %s: %s', [
        lDiagnostic.SourceRange.SourceName,
        lDiagnostic.SourceRange.StartPosition.Line,
        lDiagnostic.SourceRange.StartPosition.Column,
        lDiagnostic.Code, lDiagnostic.MessageText]);
    raise ENXForge.Create(lMessage);
  finally
    lValidator.Free;
  end;
end;

function OperationTemplatePath(ADefinition: TNexusScriptCompiledDefinition): string;
var
  lValue: TNexusScriptCompiledValue;
  lTemplate: string;
begin
  lTemplate := ForgePropertyText(ADefinition, 'Template');
  if lTemplate = '' then raise ENXForge.Create(ADefinition.Name + ': empty Template');
  lValue := ADefinition.FindProperty('Template').Value;
  while True do
  begin
    lValue := lValue.ArtifactValue;
    if lValue.Kind <> nsvReference then Break;
    if lValue.ResolvedProperty <> nil then lValue := lValue.ResolvedProperty.Value
    else if lValue.ResolvedValue <> nil then lValue := lValue.ResolvedValue
    else Break;
  end;
  Result := ForgeRelativePath(ExtractFilePath(lValue.SourceRange.SourceName), lTemplate);
end;

procedure TNXForge.Prepare(AOperations: TNexusScriptCompiledDefinitionList;
  const AWorkingDirectory: string; AContexts: TStrings);
var
  lOperation: TNexusScriptCompiledDefinition;
  lInvocation: TNXForgeInvocation;
  lEmitter: TNexusScriptJSONEmitter;
  lTemplate, lJSON: string;
  lIndex: Integer;
begin
  if (AContexts <> nil) and (AContexts.Count <> AOperations.Count) then
    raise ENXForge.Create('Operation context count mismatch');
  lEmitter := TNexusScriptJSONEmitter.Create;
  try
    for lIndex := 0 to AOperations.Count - 1 do
    begin
      lOperation := AOperations[lIndex];
      lInvocation := TNXForgeInvocation.Create;
      FInvocations.Add(lInvocation);
      lInvocation.OperationName := lOperation.Name;
      lInvocation.WorkingDirectory := AWorkingDirectory;
      try
        lInvocation.TemplatePath := OperationTemplatePath(lOperation);
        lTemplate := ReadForgeText(lInvocation.TemplatePath);
        if AContexts <> nil then lJSON := AContexts[lIndex]
        else lJSON := lEmitter.RenderDefinition(lOperation);
        lInvocation.Command := Trim(string(TSynMustache.Parse(UTF8String(lTemplate)).
          RenderJSON(UTF8String(lJSON))));
        if lInvocation.Command = '' then raise ENXForge.Create('Empty command');
      except
        on E: Exception do
        begin
          lInvocation.Diagnostic := lInvocation.OperationName + ' [' +
            lInvocation.TemplatePath + ']: ' + E.Message;
          raise ENXForge.Create(lInvocation.Diagnostic);
        end;
      end;
    end;
  finally
    lEmitter.Free;
  end;
end;

function TNXForge.Execute(const AInput: string;
  const AWorkingDirectory: string): Boolean;
var
  lView: TNexusScriptDefinitionView;
  lDirectory: string;
  lOperations: TNexusScriptCompiledDefinitionList;
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := False;
  FDiagnostic := '';
  FInvocations.Clear;
  FreeAndNil(FOperations);
  FOperations := TNexusScriptCompilationSession.Create(FTargets);
  lView := TNexusScriptDefinitionView.Create;
  lOperations := TNexusScriptCompiledDefinitionList.Create(False);
  try
    try
      CompileForgeDocument(FOperations, AInput);
      lView.AddDocument(FOperations.EntryCompiler.CompiledDocument);
      lDirectory := ExtractFilePath(ExpandFileName(AInput));
      if AWorkingDirectory <> '' then
        lDirectory := ForgeRelativePath(lDirectory, AWorkingDirectory);
      for lDefinition in lView.Roots do
        if not SameText(lDefinition.Kind, 'Environment') then lOperations.Add(lDefinition);
      Result := ExecuteDefinitions(lOperations, lDirectory);
    except
      on E: Exception do FDiagnostic := E.Message;
    end;
  finally
    lOperations.Free;
    lView.Free;
  end;
end;

function TNXForge.ExecuteDefinitions(AOperations: TNexusScriptCompiledDefinitionList;
  const AWorkingDirectory: string; AContexts: TStrings): Boolean;
var
  lInvocation: TNXForgeInvocation;
begin
  Result := False;
  FDiagnostic := '';
  FInvocations.Clear;
  try
    Prepare(AOperations, AWorkingDirectory, AContexts);
    for lInvocation in FInvocations do
    begin
      ExecuteForgeProcess(lInvocation);
      if not lInvocation.Succeeded then
      begin
        FDiagnostic := lInvocation.OperationName + ' [' +
          lInvocation.TemplatePath + ']: ';
        if lInvocation.Diagnostic <> '' then
          FDiagnostic := FDiagnostic + lInvocation.Diagnostic
        else FDiagnostic := FDiagnostic + 'exit ' + IntToStr(lInvocation.ExitStatus);
        Exit;
      end;
    end;
    Result := True;
  except
    on E: Exception do FDiagnostic := E.Message;
  end;
end;

end.
