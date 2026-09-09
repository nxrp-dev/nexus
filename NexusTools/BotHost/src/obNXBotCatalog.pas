unit obNXBotCatalog;

{$mode delphi}{$H+}

interface

uses
  Classes,
  Generics.Collections,
  obNXBotHostConfig;

type
  TNXBotCatalogWorkspace = class
  private
    FLocation: UTF8String;
    FName: UTF8String;
    FPurpose: UTF8String;
    FRef: UTF8String;
    FSource: UTF8String;
    FSourceType: UTF8String;
  public
    property Location: UTF8String read FLocation;
    property Name: UTF8String read FName;
    property Purpose: UTF8String read FPurpose;
    property Ref: UTF8String read FRef;
    property Source: UTF8String read FSource;
    property SourceType: UTF8String read FSourceType;
  end;

  TNXBotCatalogWorkspaceList = TObjectList<TNXBotCatalogWorkspace>;
  TNXBotCatalogWorkspaceReferences = TList<TNXBotCatalogWorkspace>;

  TNXBotCatalogEntry = class
  private
    FInstructions: UTF8String;
    FModel: UTF8String;
    FName: UTF8String;
    FProvider: UTF8String;
    FWorkspaces: TNXBotCatalogWorkspaceReferences;
  public
    constructor Create;
    destructor Destroy; override;
    property Instructions: UTF8String read FInstructions;
    property Model: UTF8String read FModel;
    property Name: UTF8String read FName;
    property Provider: UTF8String read FProvider;
    property Workspaces: TNXBotCatalogWorkspaceReferences read FWorkspaces;
  end;

  TNXBotCatalogEntryList = TObjectList<TNXBotCatalogEntry>;

  TNXBotCatalog = class
  private
    FDiagnostics: TStringList;
    FEntries: TNXBotCatalogEntryList;
    FWorkspaces: TNXBotCatalogWorkspaceList;
    procedure ValidateBinding(ABinding: TNXBotDeploymentBinding;
      const ABotName: string; ADiagnostics: TStrings);
  public
    constructor Create;
    destructor Destroy; override;
    function Find(const AName: UTF8String): TNXBotCatalogEntry;
    function Load(const AFileName: string;
      AConfig: TNXBotControllerConfig): Boolean;
    property Diagnostics: TStringList read FDiagnostics;
    property Entries: TNXBotCatalogEntryList read FEntries;
    property Workspaces: TNXBotCatalogWorkspaceList read FWorkspaces;
  end;

implementation

uses
  SysUtils,
  obNXBotProvider,
  obNexusScriptModel,
  obNexusScriptSession,
  obNexusScriptValidator,
  obNXXMPPJID,
  tpNexusScript;

function PropertyText(ADefinition: TNexusScriptCompiledDefinition;
  const AName: string): UTF8String;
var
  lProperty: TNexusScriptCompiledProperty;
begin
  Result := '';
  lProperty := ADefinition.FindProperty(AName);
  if Assigned(lProperty) and Assigned(lProperty.Value) and
    lProperty.Value.HasEffectiveText then
    Result := UTF8String(lProperty.Value.EffectiveText);
end;

function PropertyArray(ADefinition: TNexusScriptCompiledDefinition;
  const AName: string): TNexusScriptCompiledValue;
var
  lProperty: TNexusScriptCompiledProperty;
begin
  Result := nil;
  lProperty := ADefinition.FindProperty(AName);
  if not Assigned(lProperty) then
    Exit;
  Result := lProperty.Value;
  if Assigned(Result.EffectiveValue) then
    Result := Result.EffectiveValue;
  if Result.Kind <> nsvArray then
    Result := nil;
end;

function PathIsAbsolute(const AValue: string): Boolean;
begin
  {$IFDEF Windows}
  Result := ((Length(AValue) >= 3) and (AValue[2] = ':') and
    (AValue[3] in ['\', '/'])) or
    ((Length(AValue) >= 2) and (AValue[1] in ['\', '/']) and
    (AValue[2] in ['\', '/']));
  {$ELSE}
  Result := (AValue <> '') and (AValue[1] = '/');
  {$ENDIF}
end;

constructor TNXBotCatalogEntry.Create;
begin
  inherited Create;
  FWorkspaces := TNXBotCatalogWorkspaceReferences.Create;
end;

destructor TNXBotCatalogEntry.Destroy;
begin
  FWorkspaces.Free;
  inherited Destroy;
end;

function FindEntry(AEntries: TNXBotCatalogEntryList;
  const AName: UTF8String): TNXBotCatalogEntry;
var
  lEntry: TNXBotCatalogEntry;
begin
  Result := nil;
  for lEntry in AEntries do
    if lEntry.Name = AName then
      Exit(lEntry);
end;

function BindingCount(AConfig: TNXBotControllerConfig;
  const AName: string): Integer;
var
  lIndex: Integer;
begin
  Result := 0;
  for lIndex := 0 to AConfig.Bindings.Count - 1 do
    if AConfig.Bindings.Binding(lIndex).BotName = AName then
      Inc(Result);
end;

constructor TNXBotCatalog.Create;
begin
  inherited Create;
  FDiagnostics := TStringList.Create;
  FEntries := TNXBotCatalogEntryList.Create(True);
  FWorkspaces := TNXBotCatalogWorkspaceList.Create(True);
end;

destructor TNXBotCatalog.Destroy;
begin
  FEntries.Free;
  FWorkspaces.Free;
  FDiagnostics.Free;
  inherited Destroy;
end;

function TNXBotCatalog.Find(const AName: UTF8String): TNXBotCatalogEntry;
begin
  Result := FindEntry(FEntries, AName);
end;

procedure TNXBotCatalog.ValidateBinding(ABinding: TNXBotDeploymentBinding;
  const ABotName: string; ADiagnostics: TStrings);
var
  lJID: TNXXMPPJID;
begin
  if not Assigned(ABinding) then
  begin
    ADiagnostics.Add('Missing deployment binding for bot ' + ABotName + '.');
    Exit;
  end;
  if ABinding.XMPPJID = '' then
    ADiagnostics.Add('Missing deployment field XMPPJID for bot ' + ABotName + '.')
  else
  begin
    try
      lJID := TNXXMPPJID.Create(UTF8String(ABinding.XMPPJID));
      lJID.Free;
    except
      on E: Exception do
        ADiagnostics.Add('Invalid deployment field XMPPJID for bot ' +
          ABotName + ': ' + E.Message);
    end;
  end;
  if ABinding.Password = '' then
    ADiagnostics.Add('Missing deployment field Password ' +
      'for bot ' + ABotName + '.');
  if ABinding.Resource = '' then
    ADiagnostics.Add('Missing deployment field Resource for bot ' +
      ABotName + '.');
  if ABinding.Nick = '' then
    ADiagnostics.Add('Missing deployment field Nick for bot ' + ABotName + '.');
  if ABinding.CAFile = '' then
    ADiagnostics.Add('Missing deployment field CAFile for bot ' + ABotName + '.');
  if ABinding.ExchangeDirectory = '' then
    ADiagnostics.Add('Missing deployment field ExchangeDirectory for bot ' +
      ABotName + '.');
  if ABinding.ExchangeDirectory <> '' then
    try
      ABinding.ValidateFileExchange;
    except
      on E: Exception do
        ADiagnostics.Add('Invalid file exchange deployment for bot ' +
          ABotName + ': ' + E.Message);
    end;
  if (ABinding.EndpointHost = '') <> (ABinding.EndpointPort = 0) then
    ADiagnostics.Add('Deployment endpoint for bot ' + ABotName +
      ' requires both host and port.');
  if (ABinding.EndpointPort < 0) or
    (ABinding.EndpointPort > High(Word)) then
    ADiagnostics.Add('Invalid deployment field EndpointPort for bot ' +
      ABotName + '.');
end;

function TNXBotCatalog.Load(const AFileName: string;
  AConfig: TNXBotControllerConfig): Boolean;
var
  lBinding: TNXBotDeploymentBinding;
  lCandidate: TNXBotCatalogEntryList;
  lDefinition: TNexusScriptCompiledDefinition;
  lBotItem: TNexusScriptCompiledValue;
  lBotValue: TNexusScriptCompiledValue;
  lEntry: TNXBotCatalogEntry;
  lIndex: Integer;
  lPublished: TNXBotCatalogEntryList;
  lPublishedWorkspaces: TNXBotCatalogWorkspaceList;
  lProviderClass: TNXBotProviderClass;
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
  lWorkspace: TNXBotCatalogWorkspace;
  lWorkspaceCandidate: TNXBotCatalogWorkspaceList;
  lWorkspaceDefinition: TNexusScriptCompiledDefinition;
  lWorkspaceItem: TNexusScriptCompiledValue;
  lWorkspaceValue: TNexusScriptCompiledValue;
begin
  FDiagnostics.Clear;
  if not Assigned(AConfig) then
  begin
    FDiagnostics.Add('Controller configuration is required.');
    Exit(False);
  end;
  lCandidate := TNXBotCatalogEntryList.Create(True);
  lWorkspaceCandidate := TNXBotCatalogWorkspaceList.Create(True);
  lSession := nil;
  lValidator := nil;
  try
    lSession := TNexusScriptCompilationSession.Create;
    lValidator := TNexusScriptValidator.Create;
    if not lSession.CompileFile(AFileName) then
    begin
      FDiagnostics.Add(lSession.LastError);
      Exit(False);
    end;
    if not Assigned(lSession.EntryCompiler.CompiledDocument.DoctypeDocument)
      then
    begin
      FDiagnostics.Add('The bot catalog must declare its language definition.');
      Exit(False);
    end;
    if not lValidator.Validate(lSession.EntryCompiler.CompiledDocument,
      lSession.EntryCompiler.CompiledDocument.DoctypeDocument) then
    begin
      for lIndex := 0 to lValidator.Diagnostics.Count - 1 do
        FDiagnostics.Add(lValidator.Diagnostics[lIndex].Code + ': ' +
          lValidator.Diagnostics[lIndex].MessageText);
      Exit(False);
    end;
    if (lSession.EntryCompiler.CompiledDocument.Definitions.Count <> 1) or
      (lSession.EntryCompiler.CompiledDocument.Definitions[0].Kind <>
      'BotCatalog') then
    begin
      FDiagnostics.Add('The bot catalog must contain exactly one BotCatalog root.');
      Exit(False);
    end;
    lDefinition := lSession.EntryCompiler.CompiledDocument.Definitions[0];
    lWorkspaceValue := PropertyArray(lDefinition, 'Workspaces');
    if Assigned(lWorkspaceValue) then
      for lWorkspaceItem in lWorkspaceValue.Items do
      begin
        lWorkspaceDefinition := lWorkspaceItem.StructuralDefinition;
        lWorkspace := TNXBotCatalogWorkspace.Create;
        lWorkspace.FName := UTF8String(lWorkspaceDefinition.Name);
        lWorkspace.FPurpose := PropertyText(lWorkspaceDefinition, 'Purpose');
        lWorkspace.FSourceType := PropertyText(lWorkspaceDefinition,
          'SourceType');
        lWorkspace.FSource := PropertyText(lWorkspaceDefinition, 'Source');
        lWorkspace.FRef := PropertyText(lWorkspaceDefinition, 'Ref');
        lWorkspace.FLocation := PropertyText(lWorkspaceDefinition, 'Location');
        if not PathIsAbsolute(string(lWorkspace.FLocation)) then
          FDiagnostics.Add('Workspace ' + lWorkspaceDefinition.Name +
            ' Location must be absolute.');
        lWorkspaceCandidate.Add(lWorkspace);
      end;
    lBotValue := PropertyArray(lDefinition, 'Bots');
    for lBotItem in lBotValue.Items do
    begin
      lDefinition := lBotItem.StructuralDefinition;
      if FindEntry(lCandidate, UTF8String(lDefinition.Name)) <> nil then
      begin
        FDiagnostics.Add('Duplicate bot name: ' + lDefinition.Name);
        Continue;
      end;
      lEntry := TNXBotCatalogEntry.Create;
      lEntry.FName := UTF8String(lDefinition.Name);
      lEntry.FProvider := PropertyText(lDefinition, 'Provider');
      lEntry.FModel := PropertyText(lDefinition, 'Model');
      lEntry.FInstructions := PropertyText(lDefinition, 'Instructions');
      lWorkspaceValue := PropertyArray(lDefinition, 'Workspaces');
      if Assigned(lWorkspaceValue) then
      begin
        for lWorkspaceItem in lWorkspaceValue.Items do
        begin
          for lWorkspace in lWorkspaceCandidate do
            if lWorkspace.Name = UTF8String(
              lWorkspaceItem.OriginalDefinitionName) then
            begin
              lEntry.FWorkspaces.Add(lWorkspace);
              Break;
            end;
        end;
      end;
      lCandidate.Add(lEntry);
      lBinding := AConfig.Bindings.Find(lDefinition.Name);
      if BindingCount(AConfig, lDefinition.Name) > 1 then
        FDiagnostics.Add('Multiple deployment bindings are configured for bot ' +
          lDefinition.Name + '.')
      else
      begin
        ValidateBinding(lBinding, lDefinition.Name, FDiagnostics);
        try
          lProviderClass := TNXBotProviderRegistry.FindProvider(lEntry.Provider);
          lProviderClass.ValidateDeployment(lBinding, lDefinition.Name,
            FDiagnostics);
        except
          on E: ENXBotProviderRegistry do
            FDiagnostics.Add('Bot ' + lDefinition.Name + ': ' + E.Message);
        end;
      end;
    end;
    if FDiagnostics.Count > 0 then
      Exit(False);
    lPublished := FEntries;
    FEntries := lCandidate;
    lCandidate := lPublished;
    lPublishedWorkspaces := FWorkspaces;
    FWorkspaces := lWorkspaceCandidate;
    lWorkspaceCandidate := lPublishedWorkspaces;
    Result := True;
  finally
    lValidator.Free;
    lSession.Free;
    lCandidate.Free;
    lWorkspaceCandidate.Free;
  end;
end;

end.
