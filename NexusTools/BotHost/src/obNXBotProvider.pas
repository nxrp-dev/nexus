unit obNXBotProvider;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  obNXBotHostConfig,
  tpNXBotControl,
  tpNXBotHost;

type
  ENXBotProviderRegistry = class(Exception);

  TNXBotProviderStateEvent = procedure(ASender: TObject;
    AState: TNXBotProviderState; const ADetail: UTF8String) of object;
  TNXBotProviderTextEvent = procedure(ASender: TObject;
    const AText: UTF8String) of object;
  TNXBotProviderPromptEvent = procedure(ASender: TObject;
    APrompt: TNXBotPrompt; const AText: UTF8String) of object;
  TNXBotControlEvent = function(ASender: TObject;
    const AOperation: TNXBotControlOperation;
    const AAuthorization: TNXBotAuthorization;
    ACompletion: TNXBotControlCompletion; out AToken: QWord): Boolean of object;

  TNXBotProvider = class;
  TNXBotProviderClass = class of TNXBotProvider;

  TNXBotProvider = class
  private
    FConfiguration: TNXBotHostConfig;
    FInstructions: UTF8String;
    FOnBotControl: TNXBotControlEvent;
    FOnDiagnostic: TNXBotProviderTextEvent;
    FOnFinalAnswer: TNXBotProviderPromptEvent;
    FOnPromptFailed: TNXBotProviderPromptEvent;
    FOnState: TNXBotProviderStateEvent;
    FState: TNXBotProviderState;
  protected
    procedure Diagnostic(const AText: UTF8String);
    procedure FinalAnswer(APrompt: TNXBotPrompt; const AText: UTF8String);
    procedure PromptFailed(APrompt: TNXBotPrompt; const AText: UTF8String);
    procedure SetState(AState: TNXBotProviderState;
      const ADetail: UTF8String = '');
    property Configuration: TNXBotHostConfig read FConfiguration;
    property Instructions: UTF8String read FInstructions;
    property OnBotControlHandler: TNXBotControlEvent read FOnBotControl;
  public
    constructor Create; virtual;
    class function ProviderName: UTF8String; virtual; abstract;
    class procedure ValidateDeployment(ABinding: TNXBotDeploymentBinding;
      const ABotName: string; ADiagnostics: TStrings); virtual;
    procedure Configure(AConfiguration: TNXBotHostConfig;
      const AInstructions: UTF8String); virtual;
    function Start: Boolean; virtual; abstract;
    function Stop: Boolean; virtual; abstract;
    procedure Shutdown; virtual; abstract;
    function SubmitPrompt(APrompt: TNXBotPrompt): Boolean; virtual; abstract;
    function CancelPrompts(const AReason: UTF8String): Boolean; virtual; abstract;
    function CancelRoomPrompts(const ARoomJID,
      AReason: UTF8String): Boolean; virtual; abstract;

    property State: TNXBotProviderState read FState;
    property OnBotControl: TNXBotControlEvent read FOnBotControl
      write FOnBotControl;
    property OnDiagnostic: TNXBotProviderTextEvent read FOnDiagnostic
      write FOnDiagnostic;
    property OnFinalAnswer: TNXBotProviderPromptEvent read FOnFinalAnswer
      write FOnFinalAnswer;
    property OnPromptFailed: TNXBotProviderPromptEvent read FOnPromptFailed
      write FOnPromptFailed;
    property OnState: TNXBotProviderStateEvent read FOnState write FOnState;
  end;

  TNXBotProviderRegistry = class
  private
    class var FProviders: TStringList;
    class function NormalizeName(const AName: UTF8String): string;
  public
    class constructor Create;
    class destructor Destroy;
    class procedure RegisterProvider(AProviderClass: TNXBotProviderClass);
    class function Registered(const AName: UTF8String): Boolean;
    class function FindProvider(const AName: UTF8String): TNXBotProviderClass;
    class function CreateProvider(const AName: UTF8String): TNXBotProvider;
  end;

implementation

constructor TNXBotProvider.Create;
begin
  inherited Create;
  FState := bpsStopped;
end;

class procedure TNXBotProvider.ValidateDeployment(
  ABinding: TNXBotDeploymentBinding; const ABotName: string;
  ADiagnostics: TStrings);
begin
end;

procedure TNXBotProvider.Configure(AConfiguration: TNXBotHostConfig;
  const AInstructions: UTF8String);
begin
  if not Assigned(AConfiguration) then
    raise Exception.Create('Bot provider configuration is required.');
  FConfiguration := AConfiguration;
  FInstructions := AInstructions;
end;

procedure TNXBotProvider.Diagnostic(const AText: UTF8String);
begin
  if Assigned(FOnDiagnostic) then
    FOnDiagnostic(Self, AText);
end;

procedure TNXBotProvider.FinalAnswer(APrompt: TNXBotPrompt;
  const AText: UTF8String);
begin
  if Assigned(FOnFinalAnswer) then
    FOnFinalAnswer(Self, APrompt, AText);
end;

procedure TNXBotProvider.PromptFailed(APrompt: TNXBotPrompt;
  const AText: UTF8String);
begin
  if Assigned(FOnPromptFailed) then
    FOnPromptFailed(Self, APrompt, AText);
end;

procedure TNXBotProvider.SetState(AState: TNXBotProviderState;
  const ADetail: UTF8String);
begin
  FState := AState;
  if Assigned(FOnState) then
    FOnState(Self, AState, ADetail);
end;

class constructor TNXBotProviderRegistry.Create;
begin
  FProviders := TStringList.Create;
  FProviders.CaseSensitive := True;
  FProviders.Sorted := True;
  FProviders.Duplicates := dupError;
end;

class destructor TNXBotProviderRegistry.Destroy;
begin
  FreeAndNil(FProviders);
end;

class function TNXBotProviderRegistry.NormalizeName(
  const AName: UTF8String): string;
begin
  Result := Trim(string(AName));
  if Result = '' then
    raise ENXBotProviderRegistry.Create('Bot provider name cannot be blank.');
end;

class procedure TNXBotProviderRegistry.RegisterProvider(
  AProviderClass: TNXBotProviderClass);
var
  lIndex: Integer;
  lName: string;
begin
  if not Assigned(AProviderClass) then
    raise ENXBotProviderRegistry.Create('Cannot register a nil bot provider class.');
  lName := NormalizeName(AProviderClass.ProviderName);
  if FProviders.Find(lName, lIndex) then
    raise ENXBotProviderRegistry.CreateFmt(
      'Bot provider "%s" is already registered.', [lName]);
  FProviders.AddObject(lName, TObject(AProviderClass));
end;

class function TNXBotProviderRegistry.Registered(
  const AName: UTF8String): Boolean;
var
  lIndex: Integer;
begin
  Result := FProviders.Find(NormalizeName(AName), lIndex);
end;

class function TNXBotProviderRegistry.FindProvider(
  const AName: UTF8String): TNXBotProviderClass;
var
  lIndex: Integer;
  lName: string;
begin
  lName := NormalizeName(AName);
  if not FProviders.Find(lName, lIndex) then
    raise ENXBotProviderRegistry.CreateFmt(
      'Bot provider "%s" is not registered.', [lName]);
  Result := TNXBotProviderClass(FProviders.Objects[lIndex]);
end;

class function TNXBotProviderRegistry.CreateProvider(
  const AName: UTF8String): TNXBotProvider;
begin
  Result := FindProvider(AName).Create;
end;

end.
