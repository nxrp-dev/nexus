(*
  Copyright (c) 2026 Kevin Collins.
  
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  
  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.
  
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXForge;

{$mode delphi}{$H+}

interface

uses Classes, SysUtils, Generics.Collections, obNexusScriptModel,
  obNexusScriptSession, obNXForgeProcess, obNXForgeInvocation;

type
  ENXForge = class(Exception);

  TNXForge = class
  private
    FTargets: TNexusScriptTargetSelection;
    FOperations: TNexusScriptCompilationSession;
    FInvocations: TObjectList<TNXForgeInvocation>;
    FDiagnostic: string;
    procedure PrepareRender(AOperation: TNexusScriptCompiledDefinition;
      AInvocation: TNXForgeInvocation; const AContextJSON: string);
    procedure Prepare(AOperations: TNexusScriptCompiledDefinitionList;
      ADocument: TNexusScriptCompiledDocument; const AWorkingDirectory: string;
      AContexts: TStrings; AUseOperationDirectory: Boolean);
  public
    constructor Create(ATargets: TNexusScriptTargetSelection = nil);
    destructor Destroy; override;
    function Execute(const AInput: string;
      const AWorkingDirectory: string = ''): Boolean;
    function ExecuteDefinitions(AOperations: TNexusScriptCompiledDefinitionList;
      ADocument: TNexusScriptCompiledDocument; const AWorkingDirectory: string;
      AContexts: TStrings = nil; AUseOperationDirectory: Boolean = False): Boolean;
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
  obNexusScriptDefinitionView,
  obNexusScriptLanguageDefinition, tpNexusScript,
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

function InvocationLabel(AInvocation: TNXForgeInvocation): string;
begin
  Result := AInvocation.OperationName;
  if AInvocation.TemplatePath <> '' then
    Result := Result + ' [' + AInvocation.TemplatePath + ']';
end;

procedure CollectForgeTasks(ADefinition: TNexusScriptCompiledDefinition;
  AOperations: TNexusScriptCompiledDefinitionList);
var
  lChild: TNexusScriptCompiledDefinition;
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

procedure NormalizeCommandBooleans(AOperation: TNexusScriptCompiledDefinition;
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

function OperationFilePath(ADefinition: TNexusScriptCompiledDefinition;
  const AProperty: string): string;
var
  lTemplate: string;
begin
  lTemplate := ForgePropertyText(ADefinition, AProperty);
  if lTemplate = '' then raise ENXForge.Create(ADefinition.Name + ': empty ' + AProperty);
  Result := ForgeValuePath(ADefinition.FindProperty(AProperty).Value, '', True);
end;

procedure NormalizeCommandExecutable(AOperation: TNexusScriptCompiledDefinition;
  AContext: TJSONObject; const AProperty: string);
var
  lValue: TJSONData;
  lExecutable: string;
begin
  lValue := AContext.Find(AProperty);
  if lValue = nil then Exit;
  lExecutable := lValue.AsString;
  if (Pos('/', lExecutable) = 0) and (Pos('\', lExecutable) = 0) and
    (AOperation.FindProperty(AProperty).Value.Kind <> nsvReference) then Exit;
  if (ExtractFileDrive(lExecutable) <> '') or IsPathDelimiter(lExecutable, 1) then Exit;
  AContext.Strings[AProperty] := OperationFilePath(AOperation, AProperty);
end;

procedure TNXForge.PrepareRender(AOperation: TNexusScriptCompiledDefinition;
  AInvocation: TNXForgeInvocation; const AContextJSON: string);
var
  lSession: TNexusScriptCompilationSession;
  lEmitter: TNexusScriptJSONEmitter;
  lModel, lOperation: TJSONObject;
  lEnvironment: TJSONData;
  lTemplate: string;
begin
  AInvocation.Kind := fokRender;
  AInvocation.SourcePath := OperationFilePath(AOperation, 'Source');
  AInvocation.OutputPath := ForgeValuePath(AOperation.FindProperty('Output').Value,
    AInvocation.WorkingDirectory);
  lSession := TNexusScriptCompilationSession.Create(FTargets);
  lEmitter := TNexusScriptJSONEmitter.Create;
  try
    CompileForgeDocument(lSession, AInvocation.SourcePath);
    lEmitter.AddDocument(lSession.EntryCompiler.CompiledDocument);
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
    lSession.Free;
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

procedure TNXForge.Prepare(AOperations: TNexusScriptCompiledDefinitionList;
  ADocument: TNexusScriptCompiledDocument; const AWorkingDirectory: string;
  AContexts: TStrings; AUseOperationDirectory: Boolean);
var
  lOperation: TNexusScriptCompiledDefinition;
  lInvocation: TNXForgeInvocation;
  lEmitter: TNexusScriptJSONEmitter;
  lTemplate, lJSON: string;
  lIndex: Integer;
  lContext: TJSONObject;
  lSource: TJSONData;
  lLanguage: TNexusScriptLanguageDefinition;
begin
  if (AContexts <> nil) and (AContexts.Count <> AOperations.Count) then
    raise ENXForge.Create('Operation context count mismatch');
  lEmitter := TNexusScriptJSONEmitter.Create;
  lLanguage := TNexusScriptLanguageDefinition.Create;
  try
    if not lLanguage.Normalize(ADocument.DialectDocument) then
      raise ENXForge.Create('Unable to normalize Forge dialect');
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
        if AContexts <> nil then lJSON := AContexts[lIndex]
        else lJSON := lEmitter.RenderDefinition(lOperation, ADocument);
        if SameText(lOperation.Kind, 'Render') then
          PrepareRender(lOperation, lInvocation, lJSON)
        else if IsForgeFileOperation(lOperation.Kind) then
          PrepareForgeFileOperation(lOperation, lInvocation)
        else
        begin
          lTemplate := ReadForgeText(lInvocation.TemplatePath);
          lContext := GetJSON(lJSON) as TJSONObject;
          try
            NormalizeCommandBooleans(lOperation, lContext, lLanguage);
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
    lLanguage.Free;
    lEmitter.Free;
  end;
end;

function TNXForge.Execute(const AInput: string;
  const AWorkingDirectory: string): Boolean;
var
  lView: TNexusScriptDefinitionView;
  lDirectory: string;
  lOperations: TNexusScriptCompiledDefinitionList;
  lDefinition, lTaskRoot: TNexusScriptCompiledDefinition;
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
      if FOperations.EntryCompiler.CompiledDocument.DialectDocument.
        FindDefinition('NexusForge') = nil then
        raise ENXForge.Create('Forge input must declare the NexusForge dialect');
      lView.AddDocument(FOperations.EntryCompiler.CompiledDocument);
      lDirectory := ExtractFilePath(ExpandFileName(AInput));
      if AWorkingDirectory <> '' then
        lDirectory := ForgeRelativePath(lDirectory, AWorkingDirectory);
      lTaskRoot := nil;
      for lDefinition in lView.Roots do
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
      Result := ExecuteDefinitions(lOperations, FOperations.EntryCompiler.CompiledDocument,
        lDirectory, nil, AWorkingDirectory = '');
    except
      on E: Exception do FDiagnostic := E.Message;
    end;
  finally
    lOperations.Free;
    lView.Free;
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

function TNXForge.ExecuteDefinitions(AOperations: TNexusScriptCompiledDefinitionList;
  ADocument: TNexusScriptCompiledDocument; const AWorkingDirectory: string;
  AContexts: TStrings; AUseOperationDirectory: Boolean): Boolean;
var
  lInvocation: TNXForgeInvocation;
begin
  Result := False;
  FDiagnostic := '';
  FInvocations.Clear;
  try
    Prepare(AOperations, ADocument, AWorkingDirectory, AContexts, AUseOperationDirectory);
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
