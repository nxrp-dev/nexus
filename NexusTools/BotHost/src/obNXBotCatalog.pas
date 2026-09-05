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
    FAvailable: Boolean;
    FDiagnostic: UTF8String;
    FInstructions: UTF8String;
    FModel: UTF8String;
    FName: UTF8String;
    FProvider: UTF8String;
  public
    property Available: Boolean read FAvailable;
    property Diagnostic: UTF8String read FDiagnostic;
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
    function BindingAvailable(ABinding: TNXBotDeploymentBinding;
      out ADiagnostic: UTF8String): Boolean;
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
  obNexusScriptModel,
  obNexusScriptSession,
  obNexusScriptValidator;

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

function ValidationDiagnosticForDefinition(
  ADefinition: TNexusScriptCompiledDefinition;
  ADiagnostics: TNexusScriptValidationDiagnosticList): UTF8String;
var
  lDiagnostic: TNexusScriptValidationDiagnostic;
begin
  Result := '';
  for lDiagnostic in ADiagnostics do
    if (lDiagnostic.SourceRange.SourceName =
      ADefinition.SourceRange.SourceName) and
      (lDiagnostic.SourceRange.StartPosition.Offset >=
      ADefinition.SourceRange.StartPosition.Offset) and
      (lDiagnostic.SourceRange.StartPosition.Offset <=
      ADefinition.SourceRange.EndPosition.Offset) then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + UTF8String(lDiagnostic.Code + ': ' +
        lDiagnostic.MessageText);
    end;
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
var
  lEntry: TNXBotCatalogEntry;
begin
  Result := nil;
  for lEntry in FEntries do
    if lEntry.Name = AName then
      Exit(lEntry);
end;

function TNXBotCatalog.BindingAvailable(ABinding: TNXBotDeploymentBinding;
  out ADiagnostic: UTF8String): Boolean;
begin
  ADiagnostic := '';
  if not Assigned(ABinding) then
    ADiagnostic := 'No deployment binding is configured.'
  else if ABinding.XMPPJID = '' then
    ADiagnostic := 'The deployment XMPP JID is empty.'
  else if ABinding.PasswordEnvironmentVariable = '' then
    ADiagnostic := 'The password environment-variable name is empty.'
  else if ABinding.Resource = '' then
    ADiagnostic := 'The deployment resource is empty.'
  else if ABinding.Nick = '' then
    ADiagnostic := 'The deployment nickname is empty.'
  else if ABinding.CodexExecutable = '' then
    ADiagnostic := 'The Codex executable is empty.'
  else if ABinding.RuntimeDirectory = '' then
    ADiagnostic := 'The runtime directory is empty.';
  Result := ADiagnostic = '';
end;

function TNXBotCatalog.Load(const AFileName: string;
  AConfig: TNXBotControllerConfig): Boolean;
var
  lBinding: TNXBotDeploymentBinding;
  lDefinition: TNexusScriptCompiledDefinition;
  lEntry: TNXBotCatalogEntry;
  lIndex: Integer;
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
begin
  FEntries.Clear;
  FDiagnostics.Clear;
  if not Assigned(AConfig) then
  begin
    FDiagnostics.Add('Controller configuration is required.');
    Exit(False);
  end;
  lSession := TNexusScriptCompilationSession.Create;
  lValidator := TNexusScriptValidator.Create;
  try
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
      for lIndex := 0 to lValidator.Diagnostics.Count - 1 do
        FDiagnostics.Add(lValidator.Diagnostics[lIndex].Code + ': ' +
          lValidator.Diagnostics[lIndex].MessageText);
    for lIndex := 0 to
      lSession.EntryCompiler.CompiledDocument.Definitions.Count - 1 do
    begin
      lDefinition := lSession.EntryCompiler.CompiledDocument.Definitions[lIndex];
      if lDefinition.Kind <> 'Bot' then
        Continue;
      if Find(UTF8String(lDefinition.Name)) <> nil then
      begin
        FDiagnostics.Add('Duplicate bot name: ' + lDefinition.Name);
        Continue;
      end;
      lEntry := TNXBotCatalogEntry.Create;
      lEntry.FName := UTF8String(lDefinition.Name);
      lEntry.FProvider := PropertyText(lDefinition, 'Provider');
      lEntry.FModel := PropertyText(lDefinition, 'Model');
      lEntry.FInstructions := PropertyText(lDefinition, 'Instructions');
      lBinding := AConfig.Bindings.Find(lDefinition.Name);
      lEntry.FDiagnostic := ValidationDiagnosticForDefinition(lDefinition,
        lValidator.Diagnostics);
      if lEntry.FDiagnostic <> '' then
        lEntry.FAvailable := False
      else if BindingCount(AConfig, lDefinition.Name) > 1 then
        lEntry.FDiagnostic := 'Multiple deployment bindings are configured.'
      else if lEntry.FProvider <> 'Codex' then
        lEntry.FDiagnostic := 'Unsupported provider: ' + lEntry.FProvider
      else
        lEntry.FAvailable := BindingAvailable(lBinding, lEntry.FDiagnostic);
      if not lEntry.FAvailable then
        FDiagnostics.Add(lDefinition.Name + ': ' + string(lEntry.FDiagnostic));
      FEntries.Add(lEntry);
    end;
    Result := FEntries.Count > 0;
  finally
    lValidator.Free;
    lSession.Free;
  end;
end;

end.
