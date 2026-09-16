unit obNXForgePackages;

{$mode delphi}{$H+}

interface

uses Classes, SysUtils, Generics.Collections, fpjson, obNexusScriptModel,
  obNexusScriptSession, obNXForge;

type
  TNXPackageOutput = class
  private
    FName, FPath: string;
    FDirectory: Boolean;
  public
    constructor Create(const AName, APath: string; ADirectory: Boolean);
    function Exists: Boolean;
    property Name: string read FName;
    property Path: string read FPath;
  end;

  TNXPackageRequest = class
  private
    FSession: TNexusScriptCompilationSession;
    FTargets: TNexusScriptTargetSelection;
    FDefinition: TNexusScriptCompiledDefinition;
    FKey, FRoot, FDescription, FLogPath: string;
    FOutputs: TObjectList<TNXPackageOutput>;
    FBuilding, FReady, FReused: Boolean;
    FRunner: TNXForge;
    procedure Load(const AFileName, APackageName: string);
    procedure CheckTargets;
    procedure PrepareOutputDirectories;
    procedure WriteBuildLog(const ADiagnostic: string);
    function HasEntryPoint: Boolean;
  public
    constructor Create(ATargets: TNexusScriptTargetSelection);
    destructor Destroy; override;
    function FindOutput(const AName: string): TNXPackageOutput;
    function OutputsPresent: Boolean;
    property Definition: TNexusScriptCompiledDefinition read FDefinition;
    property Root: string read FRoot;
    property Description: string read FDescription;
    property LogPath: string read FLogPath;
    property Outputs: TObjectList<TNXPackageOutput> read FOutputs;
    property Reused: Boolean read FReused;
    property Ready: Boolean read FReady;
    property Runner: TNXForge read FRunner;
  end;

  TNXForgePackages = class
  private
    FRequests: TObjectList<TNXPackageRequest>;
    FCompletionOrder: TList<TNXPackageRequest>;
    FActive: TStringList;
    FDiagnostic: string;
    FResult: TNXPackageRequest;
    function Obtain(const AFileName, APackageName: string;
      ATargets: TNexusScriptTargetSelection): TNXPackageRequest;
    procedure Build(ARequest: TNXPackageRequest);
    function ResolveOutputValues(AValue: TJSONData;
      ADependencies: TDictionary<string, TNXPackageRequest>): TJSONData;
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(const AFileName, APackageName: string;
      ATargets: TNexusScriptTargetSelection): Boolean;
    property Requests: TObjectList<TNXPackageRequest> read FRequests;
    property CompletionOrder: TList<TNXPackageRequest> read FCompletionOrder;
    property PackageResult: TNXPackageRequest read FResult;
    property Diagnostic: string read FDiagnostic;
  end;

implementation

uses jsonparser, tpNexusScript, obNexusScriptArtifactModel, obNexusScriptDefinitionView,
  obNexusScriptJSON, obNXForgeInvocation, tpNXForge;

function DefinitionArray(ADefinition: TNexusScriptCompiledDefinition;
  const AName: string): TNexusScriptCompiledValue;
var
  lProperty: TNexusScriptCompiledProperty;
begin
  Result := nil;
  lProperty := ADefinition.FindProperty(AName);
  if lProperty = nil then Exit;
  Result := lProperty.Value.ArtifactValue;
  if Result.Kind <> nsvArray then
    raise ENXForge.Create(ADefinition.Name + ': ' + AName + ' must be an array');
end;

function BooleanProperty(ADefinition: TNexusScriptCompiledDefinition;
  const AName: string): Boolean;
begin
  Result := (ADefinition.FindProperty(AName) <> nil) and
    SameText(ForgePropertyText(ADefinition, AName), 'True');
end;

function KeyPart(const AValue: string): string;
begin
  Result := IntToStr(Length(AValue)) + ':' + AValue;
end;

constructor TNXPackageOutput.Create(const AName, APath: string; ADirectory: Boolean);
begin
  inherited Create;
  FName := AName;
  FPath := APath;
  FDirectory := ADirectory;
end;

function TNXPackageOutput.Exists: Boolean;
begin
  if FDirectory then Result := DirectoryExists(FPath)
  else Result := FileExists(FPath) and not DirectoryExists(FPath);
end;

constructor TNXPackageRequest.Create(ATargets: TNexusScriptTargetSelection);
begin
  inherited Create;
  FTargets := TNexusScriptTargetSelection.Create;
  FTargets.Assign(ATargets);
  FOutputs := TObjectList<TNXPackageOutput>.Create(True);
  FSession := TNexusScriptCompilationSession.Create(FTargets);
end;

destructor TNXPackageRequest.Destroy;
begin
  FRunner.Free;
  FOutputs.Free;
  FSession.Free;
  FTargets.Free;
  inherited Destroy;
end;

procedure TNXPackageRequest.CheckTargets;
var
  lArray, lAllowed: TNexusScriptCompiledValue;
  lItem, lValue: TNexusScriptCompiledValue;
  lDimension: TNexusScriptCompiledDefinition;
  lSelected: TNexusScriptSelectedTarget;
  lNames, lKeyParts: TStringList;
  lIndex: Integer;
  lFound: Boolean;
begin
  lNames := TStringList.Create;
  lKeyParts := TStringList.Create;
  try
    FDescription := FDefinition.Name;
    lArray := DefinitionArray(FDefinition, 'Targets');
    if lArray <> nil then
      for lItem in lArray.Items do
      begin
        lDimension := lItem.StructuralDefinition;
        if (lDimension = nil) or not SameText(lDimension.Kind, 'Dimension') then
          raise ENXForge.Create('Expected Dimension in package Targets');
        if lNames.IndexOf(lDimension.Name) >= 0 then
          raise ENXForge.Create('Duplicate target dimension ' + lDimension.Name);
        lNames.Add(lDimension.Name);
        lSelected := FTargets.Find(lDimension.Name);
        FDescription := FDescription + ' ' + lDimension.Name + '=';
        if lSelected = nil then
        begin
          FDescription := FDescription + '<unspecified>';
          if BooleanProperty(lDimension, 'Required') then
            raise ENXForge.Create(FDefinition.Name + ': required target ' + lDimension.Name);
          Continue;
        end;
        FDescription := FDescription + lSelected.Value;
        lAllowed := DefinitionArray(lDimension, 'Allowed');
        if lAllowed <> nil then
        begin
          lFound := False;
          for lValue in lAllowed.Items do
            lFound := lFound or (lValue.EffectiveText = lSelected.Value);
          if not lFound then
            raise ENXForge.Create('Disallowed target ' + lSelected.Name + '=' + lSelected.Value);
        end;
      end;
    for lIndex := 0 to FTargets.Count - 1 do
    begin
      lSelected := FTargets[lIndex];
      if lNames.IndexOf(lSelected.Name) < 0 then
        raise ENXForge.Create(FDefinition.Name + ': undeclared target ' + lSelected.Name);
      lKeyParts.Add(KeyPart(LowerCase(lSelected.Name)) + KeyPart(lSelected.Value));
    end;
    lKeyParts.Sort;
    FKey := KeyPart(FDefinition.SourceRange.SourceName);
    {$IFDEF WINDOWS} FKey := LowerCase(FKey); {$ENDIF}
    FKey := FKey + KeyPart(LowerCase(FDefinition.Name));
    for lIndex := 0 to lKeyParts.Count - 1 do FKey := FKey + KeyPart(lKeyParts[lIndex]);
  finally
    lKeyParts.Free;
    lNames.Free;
  end;
end;

procedure TNXPackageRequest.Load(const AFileName, APackageName: string);
var
  lView: TNexusScriptDefinitionView;
  lDefinition: TNexusScriptCompiledDefinition;
  lArray: TNexusScriptCompiledValue;
  lItem: TNexusScriptCompiledValue;
  lPath: string;
  lOutput: TNXPackageOutput;
begin
  CompileForgeDocument(FSession, AFileName);
  lView := TNexusScriptDefinitionView.Create;
  try
    lView.AddDocument(FSession.EntryCompiler.CompiledDocument);
    for lDefinition in lView.Roots do
      if SameText(lDefinition.Kind, 'Package') and
        ((APackageName = '') or SameText(lDefinition.Name, APackageName)) then
      begin
        if FDefinition <> nil then raise ENXForge.Create('Select a package by name');
        FDefinition := lDefinition;
      end;
    if FDefinition = nil then raise ENXForge.Create('Package not found: ' + APackageName);
    FRoot := ExtractFileDir(FDefinition.SourceRange.SourceName);
    CheckTargets;
    lArray := DefinitionArray(FDefinition, 'Outputs');
    if (lArray = nil) or (lArray.Items.Count = 0) then
      raise ENXForge.Create(FDefinition.Name + ': at least one output is required');
    for lItem in lArray.Items do
    begin
      lDefinition := lItem.StructuralDefinition;
      if (lDefinition = nil) or not SameText(lDefinition.Kind, 'Output') then
        raise ENXForge.Create('Expected Output definition');
      if FindOutput(lDefinition.Name) <> nil then
        raise ENXForge.Create('Duplicate output ' + lDefinition.Name);
      lPath := ForgePropertyText(lDefinition, 'Path');
      if lPath = '' then raise ENXForge.Create('Empty output path: ' + lDefinition.Name);
      FOutputs.Add(TNXPackageOutput.Create(lDefinition.Name,
        ForgeRelativePath(FRoot, lPath), BooleanProperty(lDefinition, 'Directory')));
    end;
    FLogPath := IncludeTrailingPathDelimiter(ExtractFileDir(FOutputs[0].Path)) + 'build.log';
    for lOutput in FOutputs do
      if SameFileName(lOutput.Path, FLogPath) then
        raise ENXForge.Create('Package output conflicts with diagnostic log: ' + FLogPath);
  finally
    lView.Free;
  end;
end;

function TNXPackageRequest.FindOutput(const AName: string): TNXPackageOutput;
var
  lOutput: TNXPackageOutput;
begin
  for lOutput in FOutputs do
    if SameText(lOutput.Name, AName) then Exit(lOutput);
  Result := nil;
end;

function TNXPackageRequest.OutputsPresent: Boolean;
var
  lOutput: TNXPackageOutput;
begin
  for lOutput in FOutputs do if not lOutput.Exists then Exit(False);
  Result := FOutputs.Count > 0;
end;

procedure TNXPackageRequest.PrepareOutputDirectories;
var
  lOutput: TNXPackageOutput;
  lDirectory: string;
begin
  for lOutput in FOutputs do
  begin
    // Prepare containers, not directory artifacts whose existence means ready.
    lDirectory := ExtractFileDir(lOutput.Path);
    if not ForceDirectories(lDirectory) then
      raise ENXForge.Create('Unable to create package output directory: ' + lDirectory);
  end;
end;

procedure TNXPackageRequest.WriteBuildLog(const ADiagnostic: string);
var
  lText: TStringList;
  lInvocation: TNXForgeInvocation;
begin
  lText := TStringList.Create;
  try
    lText.Add('Package: ' + FDescription);
    lText.Add('Root: ' + FRoot);
    if FRunner <> nil then
      for lInvocation in FRunner.Invocations do
      begin
        lText.Add('');
        lText.Add('Operation: ' + lInvocation.OperationName);
        lText.Add('Template: ' + lInvocation.TemplatePath);
        lText.Add('Working directory: ' + lInvocation.WorkingDirectory);
        if lInvocation.Kind = fokRender then
        begin
          lText.Add('Source: ' + lInvocation.SourcePath);
          lText.Add('Output: ' + lInvocation.OutputPath);
        end
        else lText.Add('Command: ' + lInvocation.Command);
        lText.Add('Started: ' + BoolToStr(lInvocation.Started, True));
        lText.Add('Completed: ' + BoolToStr(lInvocation.Completed, True));
        if lInvocation.Exited then
          lText.Add('Exit status: ' + IntToStr(lInvocation.ExitStatus));
        lText.Add('Stdout:');
        lText.Add(lInvocation.StdOut);
        lText.Add('Stderr:');
        lText.Add(lInvocation.StdErr);
        if lInvocation.Diagnostic <> '' then lText.Add('Diagnostic: ' + lInvocation.Diagnostic);
      end;
    lText.Add('');
    if ADiagnostic = '' then lText.Add('Build succeeded')
    else lText.Add('Build failed: ' + ADiagnostic);
    try
      lText.SaveToFile(FLogPath);
    except
      on E: Exception do
        raise ENXForge.Create(ADiagnostic + LineEnding +
          'Unable to write build log ' + FLogPath + ': ' + E.Message);
    end;
  finally
    lText.Free;
  end;
end;

constructor TNXForgePackages.Create;
begin
  inherited Create;
  FRequests := TObjectList<TNXPackageRequest>.Create(True);
  FCompletionOrder := TList<TNXPackageRequest>.Create;
  FActive := TStringList.Create;
end;

destructor TNXForgePackages.Destroy;
begin
  FActive.Free;
  FCompletionOrder.Free;
  FRequests.Free;
  inherited Destroy;
end;

function TNXPackageRequest.HasEntryPoint: Boolean;
var
  lOperation: TNexusScriptCompiledDefinition;
begin
  for lOperation in FDefinition.Children do
    if lOperation.FindProperty('EntryPoint') <> nil then Exit(True);
  Result := False;
end;

function TNXForgePackages.Obtain(const AFileName, APackageName: string;
  ATargets: TNexusScriptTargetSelection): TNXPackageRequest;
var
  lRequest, lExisting: TNXPackageRequest;
  lOutput: TNXPackageOutput;
begin
  lRequest := TNXPackageRequest.Create(ATargets);
  try
    lRequest.Load(AFileName, APackageName);
    for lExisting in FRequests do
      if lExisting.FKey = lRequest.FKey then
      begin
        if lExisting.FBuilding then
          raise ENXForge.Create('Package build cycle: ' + FActive.Text + lRequest.Description);
        if lExisting.FReady and lExisting.OutputsPresent then Exit(lExisting);
        raise ENXForge.Create('Previously built package output disappeared: ' + APackageName);
      end;
    FRequests.Add(lRequest);
    Result := lRequest;
    lRequest := nil;
  finally
    lRequest.Free;
  end;
  if Result.OutputsPresent and not Result.HasEntryPoint then
  begin
    Result.FReady := True;
    Result.FReused := True;
    FCompletionOrder.Add(Result);
    Exit;
  end;
  Result.FBuilding := True;
  FActive.Add(Result.Description);
  try
    // Logging stays outside artifact readiness and never creates a directory artifact.
    Result.PrepareOutputDirectories;
    try
      Build(Result);
      if not Result.OutputsPresent then
        for lOutput in Result.Outputs do
          if not lOutput.Exists then
            raise ENXForge.Create(Result.Definition.Name + ': missing output ' +
              lOutput.Name + ': ' + lOutput.Path);
    except
      on E: Exception do
      begin
        Result.WriteBuildLog(E.Message);
        raise;
      end;
    end;
    Result.WriteBuildLog('');
    Result.FReady := True;
  finally
    FActive.Delete(FActive.Count - 1);
    Result.FBuilding := False;
    FCompletionOrder.Add(Result);
  end;
end;

function TNXForgePackages.ResolveOutputValues(AValue: TJSONData;
  ADependencies: TDictionary<string, TNXPackageRequest>): TJSONData;
var
  lKind, lRequirement, lOutputName: TJSONData;
  lIndex: Integer;
  lRequest: TNXPackageRequest;
  lOutput: TNXPackageOutput;
  lChild: TJSONData;
begin
  Result := AValue;
  if AValue.JSONType = jtObject then
  begin
    lKind := AValue.FindPath('_nx.Kind');
    if (lKind <> nil) and SameText(lKind.AsString, 'PackageOutput') then
    begin
      lRequirement := AValue.FindPath('Requirement');
      lOutputName := AValue.FindPath('Output');
      if (lRequirement = nil) or (lOutputName = nil) then
        raise ENXForge.Create('PackageOutput requires Requirement and Output');
      if not ADependencies.TryGetValue(LowerCase(lRequirement.AsString), lRequest) then
        raise ENXForge.Create('Unknown requirement ' + lRequirement.AsString);
      lOutput := lRequest.FindOutput(lOutputName.AsString);
      if lOutput = nil then raise ENXForge.Create('Unknown package output ' + lOutputName.AsString);
      Exit(TJSONString.Create(lOutput.Path));
    end;
  end;
  if not (AValue.JSONType in [jtObject, jtArray]) then Exit;
  for lIndex := 0 to AValue.Count - 1 do
  begin
    if (AValue is TJSONObject) and (TJSONObject(AValue).Names[lIndex] = '_nx') then Continue;
    lChild := ResolveOutputValues(AValue.Items[lIndex], ADependencies);
    if lChild <> AValue.Items[lIndex] then AValue.Items[lIndex] := lChild;
  end;
end;

procedure TNXForgePackages.Build(ARequest: TNXPackageRequest);
var
  lRequires, lSelections: TNexusScriptCompiledValue;
  lItem, lSelection: TNexusScriptCompiledValue;
  lRequirement, lPackage, lChild: TNexusScriptCompiledDefinition;
  lTargets: TNexusScriptTargetSelection;
  lDependencies: TDictionary<string, TNXPackageRequest>;
  lContexts: TStringList;
  lOperations: TNexusScriptCompiledDefinitionList;
  lDependency: TNXPackageRequest;
  lEmitter: TNexusScriptJSONEmitter;
  lJSON: TJSONObject;
  lPackageName: string;
begin
  lDependencies := TDictionary<string, TNXPackageRequest>.Create;
  lContexts := TStringList.Create;
  lOperations := TNexusScriptCompiledDefinitionList.Create(False);
  lEmitter := TNexusScriptJSONEmitter.Create;
  try
    lRequires := DefinitionArray(ARequest.Definition, 'Requires');
    if lRequires <> nil then
      for lItem in lRequires.Items do
      begin
        lRequirement := lItem.StructuralDefinition;
        if (lRequirement = nil) or not SameText(lRequirement.Kind, 'Requirement') then
          raise ENXForge.Create('Expected Requirement definition');
        if lDependencies.ContainsKey(LowerCase(lRequirement.Name)) then
          raise ENXForge.Create('Duplicate requirement ' + lRequirement.Name);
        lPackage := lRequirement.FindProperty('Package').Value.ResolvedDefinition;
        if (lPackage = nil) or not SameText(lPackage.Kind, 'Package') then
          raise ENXForge.Create('Requirement must reference a Package definition');
        lTargets := TNexusScriptTargetSelection.Create;
        try
          lSelections := DefinitionArray(lRequirement, 'Targets');
          if lSelections <> nil then
            for lSelection in lSelections.Items do
              lTargets.Add(lSelection.StructuralDefinition.Name,
                ForgePropertyText(lSelection.StructuralDefinition, 'Value'));
          lPackageName := lPackage.Name;
          if lPackage.SourceDefinition <> nil then lPackageName := lPackage.SourceDefinition.Name;
          lDependency := Obtain(lPackage.SourceRange.SourceName, lPackageName, lTargets);
          lDependencies.Add(LowerCase(lRequirement.Name), lDependency);
        finally
          lTargets.Free;
        end;
      end;
    for lChild in ARequest.Definition.Children do
      if not SameText(lChild.Kind, 'PackageOutput') then
      begin
        lOperations.Add(lChild);
        lJSON := GetJSON(lEmitter.RenderDefinition(lChild, ARequest.FSession.EntryCompiler.CompiledDocument)) as TJSONObject;
        try
          ResolveOutputValues(lJSON, lDependencies);
          lContexts.Add(lJSON.AsJSON);
        finally
          lJSON.Free;
        end;
      end;
    ARequest.FRunner := TNXForge.Create(ARequest.FTargets);
    if not ARequest.FRunner.ExecuteDefinitions(lOperations,
      ARequest.FSession.EntryCompiler.CompiledDocument, ARequest.Root, lContexts) then
      raise ENXForge.Create(ARequest.Definition.Name + ': ' + ARequest.FRunner.Diagnostic);
  finally
    lEmitter.Free;
    lOperations.Free;
    lContexts.Free;
    lDependencies.Free;
  end;
end;

function TNXForgePackages.Execute(const AFileName, APackageName: string;
  ATargets: TNexusScriptTargetSelection): Boolean;
begin
  Result := False;
  FResult := nil;
  FDiagnostic := '';
  FCompletionOrder.Clear;
  FRequests.Clear;
  FActive.Clear;
  try
    FResult := Obtain(ExpandFileName(AFileName), APackageName, ATargets);
    Result := True;
  except
    on E: Exception do FDiagnostic := E.Message;
  end;
end;

end.
