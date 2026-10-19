(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXForge;

{$mode delphi}{$H+}

interface

uses Classes, SysUtils, Generics.Collections, obNexusScriptModel,
  obNexusScriptLive, tpNexusScriptLive, obNexusScriptLanguageDefinition,
  obNXForgeProcess, obNXForgeInvocation;

type
  ENXForge = class(Exception);

  TNXForge = class
  private
    FTargets: TNexusScriptTargetSelection;
    FOnReadExternal: TNexusScriptExternalReadEvent;
    FInvocations: TObjectList<TNXForgeInvocation>;
    FDiagnostic: string;
    procedure PrepareRender(AOperation: TNexusScriptLiveDefinition;
      AInvocation: TNXForgeInvocation; const AContextJSON: string);
    procedure Prepare(AOperations: TList<TNexusScriptLiveDefinition>;
      ADocument: TNexusScriptLiveDocument; const AWorkingDirectory: string;
      ALanguage: TNexusScriptLanguageDefinition; AUseOperationDirectory: Boolean);
    function ExecuteOperations(AOperations: TList<TNexusScriptLiveDefinition>;
      ADocument: TNexusScriptLiveDocument; const AWorkingDirectory: string;
      ALanguage: TNexusScriptLanguageDefinition; AUseOperationDirectory: Boolean): Boolean;
  public
    constructor Create(ATargets: TNexusScriptTargetSelection = nil);
    destructor Destroy; override;
    function Execute(const AInput: string;
      const AWorkingDirectory: string = ''): Boolean;
    property OnReadExternal: TNexusScriptExternalReadEvent read FOnReadExternal write FOnReadExternal;
    property Invocations: TObjectList<TNXForgeInvocation> read FInvocations;
    property Diagnostic: string read FDiagnostic;
  end;

function LoadForgeDocument(const AFileName: string;
  ATargets: TNexusScriptTargetSelection = nil;
  ALanguage: TNexusScriptLanguageDefinition = nil;
  const ARequiredDialect: string = ''): TNexusScriptLiveDocument;
function ForgePropertyText(ADefinition: TNexusScriptLiveDefinition;
  const AName: string): string;
function ForgeRelativePath(const ABase, APath: string): string;

implementation

uses SynMustache, obNexusScriptJSON, obNexusScriptValidator,
  obNexusScriptSession, tpNexusScript,
  fpjson, jsonparser, tpNXForge, obNXForgeSources,
  utNXForgeFileOperations, utNXForgePaths, obNXPackageContractValidator;

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

function ForgePropertyText(ADefinition: TNexusScriptLiveDefinition;
  const AName: string): string;
var
  lProperty: TNexusScriptLiveProperty;
begin
  lProperty := ADefinition.FindProperty(AName);
  if (lProperty = nil) or (lProperty.Value.Kind <> nslvText) then
    raise ENXForge.Create(ADefinition.Name + ': missing text property ' + AName);
  Result := lProperty.Value.AsText;
end;

function ForgeRelativePath(const ABase, APath: string): string;
begin
  if (ExtractFileDrive(APath) <> '') or
    ((APath <> '') and IsPathDelimiter(APath, 1)) then Result := ExpandFileName(APath)
  else Result := ExpandFileName(IncludeTrailingPathDelimiter(ABase) + APath);
end;

function InvocationLabel(AInvocation: TNXForgeInvocation): string;
begin
  Result := AInvocation.OperationName;
  if AInvocation.TemplatePath <> '' then
    Result := Result + ' [' + AInvocation.TemplatePath + ']';
end;

procedure CollectForgeTasks(ADefinition: TNexusScriptLiveDefinition;
  AOperations: TList<TNexusScriptLiveDefinition>);
var
  lChild: TNexusScriptLiveDefinition;
begin
  if SameText(ADefinition.Kind, 'Environment') or
    SameText(ADefinition.Kind, 'PackageIndex') or
    SameText(ADefinition.Kind, 'RepositoryIndex') then
    raise ENXForge.Create(ADefinition.Kind + ' is data, not an executable task');
  if not (SameText(ADefinition.Kind, 'Group') or
    SameText(ADefinition.Kind, 'Package') or SameText(ADefinition.Kind, 'Project')) then
  begin
    AOperations.Add(ADefinition);
    Exit;
  end;
  for lChild in ADefinition.Children do
    CollectForgeTasks(lChild, AOperations);
end;

procedure NormalizeCommandBooleans(AOperation: TNexusScriptLiveDefinition;
  AContext: TJSONObject; ALanguage: TNexusScriptLanguageDefinition);
var
  lDefinitionRule: TNSDefinitionRule;
  lPropertyRule: TNSPropertyRule;
  lValue: TJSONData;
  lIndex: Integer;
begin
  lDefinitionRule := ALanguage.FindDefinitionRule(AOperation.Kind);
  if lDefinitionRule = nil then Exit;
  for lIndex := 0 to lDefinitionRule.PropertyRuleCount - 1 do
  begin
    lPropertyRule := lDefinitionRule.PropertyRules[lIndex];
    if lPropertyRule.ValueRule.ScalarKind <> nskBoolean then Continue;
    lValue := AContext.Find(lPropertyRule.Name);
    if lValue <> nil then
      AContext.Booleans[lPropertyRule.Name] := SameText(lValue.AsString, 'True');
  end;
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
  lContracts: TNXPackageContractValidator;
  lContractDiagnostics: TStringList;
begin
  if not ASession.CompileFile(AFileName) then
    raise ENXForge.Create(ASession.LastError);
  lDocument := ASession.EntryCompiler.CompiledDocument;
  if lDocument.DialectDocument = nil then
    raise ENXForge.Create(AFileName + ': a declared dialect is required');
  lValidator := TNexusScriptValidator.Create;
  try
    if lValidator.Validate(lDocument, lDocument.DialectDocument) then
    begin
      if (lDocument.DialectDocument.FindDefinition('NexusForge') = nil) and
        (lDocument.DialectDocument.FindDefinition('nxpackage') = nil) then Exit;
      lContractDiagnostics := TStringList.Create;
      lContracts := TNXPackageContractValidator.Create(ASession, lContractDiagnostics);
      try
        lContracts.Validate;
        if lContractDiagnostics.Count <> 0 then
          raise ENXForge.Create(lContractDiagnostics.Text);
        Exit;
      finally
        lContracts.Free;
        lContractDiagnostics.Free;
      end;
    end;
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

function LoadForgeDocument(const AFileName: string;
  ATargets: TNexusScriptTargetSelection;
  ALanguage: TNexusScriptLanguageDefinition;
  const ARequiredDialect: string): TNexusScriptLiveDocument;
var
  lSession: TNexusScriptCompilationSession;
  lDocument: TNexusScriptCompiledDocument;
begin
  lSession := TNexusScriptCompilationSession.Create(ATargets);
  try
    CompileForgeDocument(lSession, AFileName);
    lDocument := lSession.EntryCompiler.CompiledDocument;
    if (ARequiredDialect <> '') and
      (lDocument.DialectDocument.FindDefinition(ARequiredDialect) = nil) then
      raise ENXForge.Create('Forge input must declare the ' + ARequiredDialect + ' dialect');
    if (ALanguage <> nil) and not ALanguage.Normalize(lDocument.DialectDocument) then
      raise ENXForge.Create('Unable to normalize Forge dialect');
    Result := TNexusScriptLiveEmitter.Emit(lDocument);
  finally
    lSession.Free;
  end;
end;

function OperationFilePath(ADefinition: TNexusScriptLiveDefinition;
  const AProperty: string): string;
var
  lTemplate: string;
begin
  lTemplate := ForgePropertyText(ADefinition, AProperty);
  if lTemplate = '' then raise ENXForge.Create(ADefinition.Name + ': empty ' + AProperty);
  Result := ForgeValuePath(ADefinition.FindProperty(AProperty).Value, '', True);
end;

procedure NormalizeCommandExecutable(AOperation: TNexusScriptLiveDefinition;
  AContext: TJSONObject; const AProperty: string);
var
  lValue: TJSONData;
  lExecutable: string;
begin
  lValue := AContext.Find(AProperty);
  if lValue = nil then Exit;
  lExecutable := lValue.AsString;
  if (Pos('/', lExecutable) = 0) and (Pos('\', lExecutable) = 0) and
    not IsInternalReference(AOperation.FindProperty(AProperty).Value) then Exit;
  if (ExtractFileDrive(lExecutable) <> '') or IsPathDelimiter(lExecutable, 1) then Exit;
  AContext.Strings[AProperty] := OperationFilePath(AOperation, AProperty);
end;

procedure TNXForge.PrepareRender(AOperation: TNexusScriptLiveDefinition;
  AInvocation: TNXForgeInvocation; const AContextJSON: string);
var
  lDocument: TNexusScriptLiveDocument;
  lEmitter: TNexusScriptJSONEmitter;
  lModel, lOperation: TJSONObject;
  lEnvironment: TJSONData;
  lTemplate: string;
begin
  AInvocation.Kind := fokRender;
  AInvocation.SourcePath := OperationFilePath(AOperation, 'Source');
  AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('Output').Value,
    AInvocation.WorkingDirectory);
  lDocument := nil;
  lEmitter := TNexusScriptJSONEmitter.Create;
  try
    lDocument := LoadForgeDocument(AInvocation.SourcePath, FTargets);
    lDocument.OnReadExternal := FOnReadExternal;
    lEmitter.AddLiveDocument(lDocument);
    lModel := GetJSON(lEmitter.JSON) as TJSONObject;
    try
      lOperation := GetJSON(AContextJSON) as TJSONObject;
      try
        lEnvironment := lOperation.Find('Environment');
        if lEnvironment <> nil then
        begin
          if lModel.Find('Environment') <> nil then
            raise ENXForge.Create('Render source collides with explicit Environment context');
          lModel.Add('Environment', lEnvironment.Clone);
        end;
        lTemplate := ReadForgeText(AInvocation.TemplatePath);
        AInvocation.ArtifactText := string(TSynMustache.Parse(UTF8String(lTemplate)).
          RenderJSON(UTF8String(lModel.AsJSON)));
      finally
        lOperation.Free;
      end;
    finally
      lModel.Free;
    end;
  finally
    lEmitter.Free;
    lDocument.Free;
  end;
end;

procedure WriteForgeArtifact(AInvocation: TNXForgeInvocation);
var
  lFile: TFileStream;
begin
  AInvocation.Started := True;
  try
    lFile := TFileStream.Create(AInvocation.OutputPath, fmCreate);
    try
      if AInvocation.ArtifactText <> '' then
        lFile.WriteBuffer(AInvocation.ArtifactText[1], Length(AInvocation.ArtifactText));
    finally
      lFile.Free;
    end;
    AInvocation.Completed := True;
  except
    on E: Exception do AInvocation.Diagnostic := E.Message;
  end;
end;

procedure TNXForge.Prepare(AOperations: TList<TNexusScriptLiveDefinition>;
  ADocument: TNexusScriptLiveDocument; const AWorkingDirectory: string;
  ALanguage: TNexusScriptLanguageDefinition; AUseOperationDirectory: Boolean);
var
  lOperation: TNexusScriptLiveDefinition;
  lInvocation: TNXForgeInvocation;
  lEmitter: TNexusScriptJSONEmitter;
  lTemplate, lJSON: string;
  lIndex: Integer;
  lContext: TJSONObject;
  lSource: TJSONData;
begin
  lEmitter := TNexusScriptJSONEmitter.Create;
  try
    for lIndex := 0 to AOperations.Count - 1 do
    begin
      lOperation := AOperations[lIndex];
      lInvocation := TNXForgeInvocation.Create;
      FInvocations.Add(lInvocation);
      lInvocation.OperationName := lOperation.Name;
      lInvocation.WorkingDirectory := AWorkingDirectory;
      if AUseOperationDirectory then
        lInvocation.WorkingDirectory := ExtractFileDir(lOperation.SourceRange.SourceName);
      try
        if not IsForgeFileOperation(lOperation.Kind) then
          lInvocation.TemplatePath := OperationFilePath(lOperation, 'Template');
        lJSON := lEmitter.RenderDefinition(lOperation, ADocument);
        if SameText(lOperation.Kind, 'Render') then
          PrepareRender(lOperation, lInvocation, lJSON)
        else if IsForgeFileOperation(lOperation.Kind) then
          PrepareForgeFileOperation(lOperation, lInvocation)
        else
        begin
          lTemplate := ReadForgeText(lInvocation.TemplatePath);
          lContext := GetJSON(lJSON) as TJSONObject;
          try
            NormalizeCommandBooleans(lOperation, lContext, ALanguage);
            NormalizeCommandExecutable(lOperation, lContext, 'Executable');
            NormalizeCommandExecutable(lOperation, lContext, 'Compiler');
            if lContext.Find('EntryPoint') <> nil then
              lContext.Strings['EntryPoint'] := OperationFilePath(lOperation, 'EntryPoint');
            if lContext.Find('WorkingDirectory') <> nil then
            begin
              lInvocation.WorkingDirectory := ForgeValuePath(
                lOperation.FindProperty('WorkingDirectory').Value, lInvocation.WorkingDirectory);
              lContext.Strings['WorkingDirectory'] := lInvocation.WorkingDirectory;
            end;
            NormalizeForgeCommandPaths(lOperation, lContext, lInvocation.WorkingDirectory);
            lJSON := lContext.AsJSON;
            lSource := lContext.Find('Source');
            if (lSource <> nil) and (lSource.JSONType = jtArray) then
            begin
              TSynMustache.Parse(UTF8String(lTemplate));
              if Trim(lTemplate) = '' then raise ENXForge.Create('Empty command');
              lInvocation.CommandTemplate := lTemplate;
              lInvocation.CommandContext := lJSON;
              lInvocation.SourceDirectory := ExtractFileDir(lOperation.SourceRange.SourceName);
            end
            else
            begin
              lInvocation.Command := Trim(string(TSynMustache.Parse(UTF8String(lTemplate)).
                RenderJSON(UTF8String(lJSON))));
              if lInvocation.Command = '' then raise ENXForge.Create('Empty command');
            end;
          finally
            lContext.Free;
          end;
        end;
      except
        on E: Exception do
        begin
          lInvocation.Diagnostic := InvocationLabel(lInvocation) +
            ' source [' + lInvocation.SourcePath + ']: ' + E.Message;
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
  lDocument: TNexusScriptLiveDocument;
  lLanguage: TNexusScriptLanguageDefinition;
  lDirectory: string;
  lOperations: TList<TNexusScriptLiveDefinition>;
  lDefinition, lTaskRoot: TNexusScriptLiveDefinition;
begin
  Result := False;
  FDiagnostic := '';
  FInvocations.Clear;
  lDocument := nil;
  lLanguage := TNexusScriptLanguageDefinition.Create;
  lOperations := TList<TNexusScriptLiveDefinition>.Create;
  try
    try
      lDocument := LoadForgeDocument(AInput, FTargets, lLanguage, 'NexusForge');
      lDocument.OnReadExternal := FOnReadExternal;
      lDirectory := ExtractFilePath(ExpandFileName(AInput));
      if AWorkingDirectory <> '' then
        lDirectory := ForgeRelativePath(lDirectory, AWorkingDirectory);
      lTaskRoot := nil;
      for lDefinition in lDocument.Roots do
        if not (SameText(lDefinition.Kind, 'Environment') or
          SameText(lDefinition.Kind, 'PackageIndex') or
          SameText(lDefinition.Kind, 'RepositoryIndex')) then
        begin
          if lTaskRoot <> nil then
            raise ENXForge.Create('Forge document must have one executable root; use Group for multiple tasks');
          lTaskRoot := lDefinition;
        end;
      if lTaskRoot = nil then
        raise ENXForge.Create('Forge document has no executable root');
      CollectForgeTasks(lTaskRoot, lOperations);
      Result := ExecuteOperations(lOperations, lDocument,
        lDirectory, lLanguage, AWorkingDirectory = '');
    except
      on E: Exception do FDiagnostic := E.Message;
    end;
  finally
    lOperations.Free;
    lLanguage.Free;
    lDocument.Free;
  end;
end;

procedure ResolveCommandSources(AInvocation: TNXForgeInvocation);
var
  lContext: TJSONObject;
  lSources: TNXForgeSources;
begin
  if AInvocation.CommandContext = '' then Exit;
  lContext := GetJSON(AInvocation.CommandContext) as TJSONObject;
  lSources := TNXForgeSources.Create;
  try
    lSources.Resolve(lContext, AInvocation.SourceDirectory);
    AInvocation.Command := Trim(string(TSynMustache.Parse(UTF8String(
      AInvocation.CommandTemplate)).RenderJSON(UTF8String(lContext.AsJSON))));
    if AInvocation.Command = '' then raise ENXForge.Create('Empty command');
  finally
    lSources.Free;
    lContext.Free;
  end;
end;

function TNXForge.ExecuteOperations(AOperations: TList<TNexusScriptLiveDefinition>;
  ADocument: TNexusScriptLiveDocument; const AWorkingDirectory: string;
  ALanguage: TNexusScriptLanguageDefinition; AUseOperationDirectory: Boolean): Boolean;
var
  lInvocation: TNXForgeInvocation;
begin
  Result := False;
  FDiagnostic := '';
  FInvocations.Clear;
  try
    Prepare(AOperations, ADocument, AWorkingDirectory, ALanguage, AUseOperationDirectory);
    for lInvocation in FInvocations do
    begin
      if lInvocation.Kind = fokRender then WriteForgeArtifact(lInvocation)
      else if lInvocation.Kind <> fokCommand then
        ExecuteForgeFileOperation(lInvocation)
      else
      begin
        try
          ResolveCommandSources(lInvocation);
          ExecuteForgeProcess(lInvocation);
        except
          on E: Exception do lInvocation.Diagnostic := E.Message;
        end;
      end;
      if not lInvocation.Succeeded then
      begin
        FDiagnostic := InvocationLabel(lInvocation) + ': ';
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
