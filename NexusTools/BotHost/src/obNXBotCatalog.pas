unit obNXBotCatalog;

{$mode delphi}{$H+}

interface

uses
  Classes,
  Generics.Collections,
  obNXBotHostConfig;

type
  TNXBotCatalogEntry = class
  private
    FInstructions: UTF8String;
    FModel: UTF8String;
    FName: UTF8String;
    FProvider: UTF8String;
  public
    property Instructions: UTF8String read FInstructions;
    property Model: UTF8String read FModel;
    property Name: UTF8String read FName;
    property Provider: UTF8String read FProvider;
  end;

  TNXBotCatalogEntryList = TObjectList<TNXBotCatalogEntry>;

  TNXBotCatalog = class
  private
    FDiagnostics: TStringList;
    FEntries: TNXBotCatalogEntryList;
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
  end;

implementation

uses
  SysUtils,
  obNXBotProvider,
  obNexusScriptModel,
  obNexusScriptSession,
  obNexusScriptValidator,
  obNXXMPPJID;

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
end;

destructor TNXBotCatalog.Destroy;
begin
  FEntries.Free;
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
  lEntry: TNXBotCatalogEntry;
  lIndex: Integer;
  lPublished: TNXBotCatalogEntryList;
  lProviderClass: TNXBotProviderClass;
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
begin
  FDiagnostics.Clear;
  if not Assigned(AConfig) then
  begin
    FDiagnostics.Add('Controller configuration is required.');
    Exit(False);
  end;
  lCandidate := TNXBotCatalogEntryList.Create(True);
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
    for lIndex := 0 to
      lSession.EntryCompiler.CompiledDocument.Definitions.Count - 1 do
    begin
      lDefinition := lSession.EntryCompiler.CompiledDocument.Definitions[lIndex];
      if lDefinition.Kind <> 'Bot' then
        Continue;
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
    Result := True;
  finally
    lValidator.Free;
    lSession.Free;
    lCandidate.Free;
  end;
end;

end.
