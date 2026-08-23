unit obNexusScriptValidator;

{$mode delphi}{$H+}

interface

uses
  Generics.Collections,
  tpNexusScript,
  obNexusScriptModel;

type
  TNexusScriptValidationSeverity = (nvsError);

  TNexusScriptValidationDiagnostic = class
  private
    FSeverity: TNexusScriptValidationSeverity;
    FCode: string;
    FMessageText: string;
    FSourceRange: TNexusScriptRange;
    FRelatedRanges: TList<TNexusScriptRange>;
  public
    constructor Create(const ACode, AMessageText: string;
      const ASourceRange: TNexusScriptRange);
    destructor Destroy; override;
    property Code: string read FCode;
    property Severity: TNexusScriptValidationSeverity read FSeverity;
    property MessageText: string read FMessageText;
    property SourceRange: TNexusScriptRange read FSourceRange;
    property RelatedRanges: TList<TNexusScriptRange> read FRelatedRanges;
  end;

  TNexusScriptValidationDiagnosticList =
    TObjectList<TNexusScriptValidationDiagnostic>;

  TNexusScriptValidator = class
  private
    FDiagnostics: TNexusScriptValidationDiagnosticList;
  public
    constructor Create;
    destructor Destroy; override;
    function Validate(ASubject,
      ALanguageDefinition: TNexusScriptCompiledDocument): Boolean;
    property Diagnostics: TNexusScriptValidationDiagnosticList
      read FDiagnostics;
  end;

implementation

uses
  Classes,
  SysUtils;

type
  TNSUnknownPolicy = (nupAllow, nupReject);
  TNSNamePolicy = (nnpOptional, nnpRequired, nnpForbidden);
  TNSSourceForm = (nsfText, nsfArray, nsfReference,
    nsfTextComposition, nsfInlineDefinition);
  TNSSourceForms = set of TNSSourceForm;
  TNSEffectiveCategory = (necText, necArray, necDefinition);
  TNSEffectiveCategories = set of TNSEffectiveCategory;
  TNSScalarKind = (nskNone, nskText, nskInteger, nskBoolean);
  TNSReferenceTarget = (nrtProperty, nrtDefinition);
  TNSReferenceTargets = set of TNSReferenceTarget;

  TNSArrayRule = class
  public
    Minimum: Integer;
    Maximum: Integer;
    NamePolicy: TNSNamePolicy;
    EntrySourceForms: TNSSourceForms;
    HasEntrySourceForms: Boolean;
    EntryCategories: TNSEffectiveCategories;
    HasEntryCategories: Boolean;
    DefinitionKinds: TStringList;
    AllowedValues: TStringList;
    Mixed: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  TNSReferenceRule = class
  public
    Targets: TNSReferenceTargets;
    DefinitionKinds: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TNSValueRule = class
  public
    SourceForms: TNSSourceForms;
    HasSourceForms: Boolean;
    EffectiveCategories: TNSEffectiveCategories;
    HasEffectiveCategories: Boolean;
    ScalarKind: TNSScalarKind;
    AllowedValues: TStringList;
    ArrayRule: TNSArrayRule;
    ReferenceRule: TNSReferenceRule;
    constructor Create;
    destructor Destroy; override;
  end;

  TNSPropertyRule = class
  public
    Name: string;
    Required: Boolean;
    ValueRule: TNSValueRule;
    SourceRange: TNexusScriptRange;
    destructor Destroy; override;
  end;

  TNSChildRule = class
  public
    Name: string;
    Kinds: TStringList;
    Minimum: Integer;
    Maximum: Integer;
    SourceRange: TNexusScriptRange;
    constructor Create;
    destructor Destroy; override;
  end;

  TNSPropertyRuleList = TObjectList<TNSPropertyRule>;
  TNSChildRuleList = TObjectList<TNSChildRule>;

  TNSDefinitionRule = class
  public
    KindName: string;
    RootAllowed: Boolean;
    Parents: TStringList;
    UnknownProperties: TNSUnknownPolicy;
    UnknownChildren: TNSUnknownPolicy;
    HasUnknownChildren: Boolean;
    HasChildren: Boolean;
    PropertyRules: TNSPropertyRuleList;
    ChildRules: TNSChildRuleList;
    SourceRange: TNexusScriptRange;
    constructor Create;
    destructor Destroy; override;
  end;

  TNSDefinitionRuleList = TObjectList<TNSDefinitionRule>;

  TNSLanguageRule = class
  public
    UnknownDefinitions: TNSUnknownPolicy;
    DefinitionRules: TNSDefinitionRuleList;
    constructor Create;
    destructor Destroy; override;
  end;

  TNSValidatorEngine = class
  private
    FDiagnostics: TNexusScriptValidationDiagnosticList;
    FLanguage: TNSLanguageRule;
    FVisited: TList<TNexusScriptCompiledDefinition>;
    procedure AddDiagnostic(const ACode, AMessageText: string;
      const ASourceRange: TNexusScriptRange);
    function Normalize(ADocument: TNexusScriptCompiledDocument): Boolean;
    function NormalizeDefinition(ADefinition: TNexusScriptCompiledDefinition;
      out ARule: TNSDefinitionRule): Boolean;
    function NormalizeProperty(ADefinition: TNexusScriptCompiledDefinition;
      out ARule: TNSPropertyRule): Boolean;
    function NormalizeChild(ADefinition: TNexusScriptCompiledDefinition;
      out ARule: TNSChildRule): Boolean;
    function NormalizeValue(ADefinition: TNexusScriptCompiledDefinition;
      out ARule: TNSValueRule): Boolean;
    function NormalizeArray(ADefinition: TNexusScriptCompiledDefinition;
      out ARule: TNSArrayRule): Boolean;
    function NormalizeReference(ADefinition: TNexusScriptCompiledDefinition;
      out ARule: TNSReferenceRule): Boolean;
    function FindDefinitionRule(const AKind: string): TNSDefinitionRule;
    function FindPropertyRule(ARule: TNSDefinitionRule;
      const AName: string): TNSPropertyRule;
    function FindChildRule(ARule: TNSDefinitionRule;
      const AKind: string): TNSChildRule;
    procedure ValidateDefinition(ADefinition: TNexusScriptCompiledDefinition;
      AParent: TNexusScriptCompiledDefinition; AIsRoot: Boolean);
    procedure ValidateProperty(AProperty: TNexusScriptCompiledProperty;
      ARule: TNSPropertyRule);
    procedure ValidateValue(AValue: TNexusScriptCompiledValue;
      ARule: TNSValueRule);
    procedure ValidateArray(AValue: TNexusScriptCompiledValue;
      ARule: TNSArrayRule);
    procedure ValidateReference(AValue: TNexusScriptCompiledValue;
      ARule: TNSReferenceRule);
  public
    constructor Create(ADiagnostics: TNexusScriptValidationDiagnosticList);
    destructor Destroy; override;
    function Execute(ASubject,
      ALanguageDefinition: TNexusScriptCompiledDocument): Boolean;
  end;

const
  cUnbounded = -1;

constructor TNexusScriptValidationDiagnostic.Create(const ACode,
  AMessageText: string; const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FSeverity := nvsError;
  FCode := ACode;
  FMessageText := AMessageText;
  FSourceRange := ASourceRange;
  FRelatedRanges := TList<TNexusScriptRange>.Create;
end;

destructor TNexusScriptValidationDiagnostic.Destroy;
begin
  FRelatedRanges.Free;
  inherited Destroy;
end;

constructor TNexusScriptValidator.Create;
begin
  inherited Create;
  FDiagnostics := TNexusScriptValidationDiagnosticList.Create(True);
end;

destructor TNexusScriptValidator.Destroy;
begin
  FDiagnostics.Free;
  inherited Destroy;
end;

function TNexusScriptValidator.Validate(ASubject,
  ALanguageDefinition: TNexusScriptCompiledDocument): Boolean;
var
  lEngine: TNSValidatorEngine;
begin
  FDiagnostics.Clear;
  lEngine := TNSValidatorEngine.Create(FDiagnostics);
  try
    Result := lEngine.Execute(ASubject, ALanguageDefinition);
  finally
    lEngine.Free;
  end;
end;

constructor TNSArrayRule.Create;
begin
  inherited Create;
  Maximum := cUnbounded;
  NamePolicy := nnpOptional;
  Mixed := True;
  DefinitionKinds := TStringList.Create;
  DefinitionKinds.CaseSensitive := False;
  AllowedValues := TStringList.Create;
  AllowedValues.CaseSensitive := False;
end;

destructor TNSArrayRule.Destroy;
begin
  AllowedValues.Free;
  DefinitionKinds.Free;
  inherited Destroy;
end;

constructor TNSReferenceRule.Create;
begin
  inherited Create;
  DefinitionKinds := TStringList.Create;
  DefinitionKinds.CaseSensitive := False;
end;

destructor TNSReferenceRule.Destroy;
begin
  DefinitionKinds.Free;
  inherited Destroy;
end;

constructor TNSValueRule.Create;
begin
  inherited Create;
  AllowedValues := TStringList.Create;
  AllowedValues.CaseSensitive := False;
end;

destructor TNSValueRule.Destroy;
begin
  ReferenceRule.Free;
  ArrayRule.Free;
  AllowedValues.Free;
  inherited Destroy;
end;

destructor TNSPropertyRule.Destroy;
begin
  ValueRule.Free;
  inherited Destroy;
end;

constructor TNSChildRule.Create;
begin
  inherited Create;
  Maximum := cUnbounded;
  Kinds := TStringList.Create;
  Kinds.CaseSensitive := False;
end;

destructor TNSChildRule.Destroy;
begin
  Kinds.Free;
  inherited Destroy;
end;

constructor TNSDefinitionRule.Create;
begin
  inherited Create;
  Parents := TStringList.Create;
  Parents.CaseSensitive := False;
  UnknownProperties := nupReject;
  UnknownChildren := nupAllow;
  PropertyRules := TNSPropertyRuleList.Create(True);
  ChildRules := TNSChildRuleList.Create(True);
end;

destructor TNSDefinitionRule.Destroy;
begin
  ChildRules.Free;
  PropertyRules.Free;
  Parents.Free;
  inherited Destroy;
end;

constructor TNSLanguageRule.Create;
begin
  inherited Create;
  UnknownDefinitions := nupReject;
  DefinitionRules := TNSDefinitionRuleList.Create(True);
end;

destructor TNSLanguageRule.Destroy;
begin
  DefinitionRules.Free;
  inherited Destroy;
end;

constructor TNSValidatorEngine.Create(
  ADiagnostics: TNexusScriptValidationDiagnosticList);
begin
  inherited Create;
  FDiagnostics := ADiagnostics;
  FVisited := TList<TNexusScriptCompiledDefinition>.Create;
end;

destructor TNSValidatorEngine.Destroy;
begin
  FVisited.Free;
  FLanguage.Free;
  inherited Destroy;
end;

procedure TNSValidatorEngine.AddDiagnostic(const ACode, AMessageText: string;
  const ASourceRange: TNexusScriptRange);
begin
  FDiagnostics.Add(TNexusScriptValidationDiagnostic.Create(ACode,
    AMessageText, ASourceRange));
end;

function EffectiveValue(AValue: TNexusScriptCompiledValue): TNexusScriptCompiledValue;
begin
  Result := AValue;
  if (AValue <> nil) and (AValue.EffectiveValue <> nil) then
    Result := AValue.EffectiveValue;
end;

function PropertyText(ADefinition: TNexusScriptCompiledDefinition;
  const AName: string; out AText: string): Boolean;
var
  lProperty: TNexusScriptCompiledProperty;
  lValue: TNexusScriptCompiledValue;
begin
  Result := False;
  AText := '';
  lProperty := ADefinition.FindProperty(AName);
  if lProperty = nil then
    Exit;
  lValue := EffectiveValue(lProperty.Value);
  if not lValue.HasEffectiveText then
    Exit;
  AText := lValue.EffectiveText;
  Result := True;
end;

function PropertyArray(ADefinition: TNexusScriptCompiledDefinition;
  const AName: string): TNexusScriptCompiledValue;
var
  lProperty: TNexusScriptCompiledProperty;
begin
  Result := nil;
  lProperty := ADefinition.FindProperty(AName);
  if lProperty = nil then
    Exit;
  Result := EffectiveValue(lProperty.Value);
  if (Result = nil) or (Result.Kind <> nsvArray) then
    Result := nil;
end;

function ParseBoolean(const AText: string; out AValue: Boolean): Boolean;
begin
  Result := True;
  if SameText(AText, 'True') then
    AValue := True
  else if SameText(AText, 'False') then
    AValue := False
  else
    Result := False;
end;

function ParseNonNegativeInteger(const AText: string;
  out AValue: Integer): Boolean;
var
  lCode: Integer;
begin
  Val(AText, AValue, lCode);
  Result := (lCode = 0) and (AValue >= 0) and (IntToStr(AValue) = AText);
end;

function ParseInteger(const AText: string; out AValue: Integer): Boolean;
var
  lCode: Integer;
begin
  Val(AText, AValue, lCode);
  Result := (lCode = 0) and ((IntToStr(AValue) = AText) or
    ((AValue = 0) and (AText = '-0')));
end;

function NameIsAllowed(const AName, AAllowedNames: string): Boolean;
var
  lNames: TStringList;
begin
  lNames := TStringList.Create;
  try
    lNames.Delimiter := '|';
    lNames.StrictDelimiter := True;
    lNames.DelimitedText := AAllowedNames;
    lNames.CaseSensitive := False;
    Result := lNames.IndexOf(AName) >= 0;
  finally
    lNames.Free;
  end;
end;

function HasOnlyMembers(ADefinition: TNexusScriptCompiledDefinition;
  const AProperties, AChildren: string): Boolean;
var
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  for lProperty in ADefinition.Properties do
    if not NameIsAllowed(lProperty.Name, AProperties) then Exit(False);
  for lChild in ADefinition.Children do
    if not NameIsAllowed(lChild.Name, AChildren) then Exit(False);
  Result := True;
end;

function ParseUnknownPolicy(const AText: string;
  out AValue: TNSUnknownPolicy): Boolean;
begin
  Result := True;
  if SameText(AText, 'Allow') then
    AValue := nupAllow
  else if SameText(AText, 'Reject') then
    AValue := nupReject
  else
    Result := False;
end;

function AddTextItems(AValue: TNexusScriptCompiledValue;
  ATarget: TStringList): Boolean;
var
  lItem: TNexusScriptCompiledValue;
  lValue: TNexusScriptCompiledValue;
begin
  Result := AValue <> nil;
  if not Result then
    Exit;
  for lItem in AValue.Items do
  begin
    lValue := EffectiveValue(lItem);
    if not lValue.HasEffectiveText then
      Exit(False);
    if ATarget.IndexOf(lValue.EffectiveText) < 0 then
      ATarget.Add(lValue.EffectiveText);
  end;
end;

function SourceFormOf(AValue: TNexusScriptCompiledValue): TNSSourceForm;
begin
  case AValue.Kind of
    nsvArray: Result := nsfArray;
    nsvReference: Result := nsfReference;
    nsvTextComposition: Result := nsfTextComposition;
    nsvDefinition: Result := nsfInlineDefinition;
  else
    Result := nsfText;
  end;
end;

function EffectiveCategoryOf(
  AValue: TNexusScriptCompiledValue): TNSEffectiveCategory;
var
  lValue: TNexusScriptCompiledValue;
begin
  if AValue.StructuralDefinition <> nil then
    Exit(necDefinition);
  lValue := EffectiveValue(AValue);
  if lValue.StructuralDefinition <> nil then
    Exit(necDefinition);
  if lValue.Kind = nsvArray then
    Exit(necArray);
  if (AValue.ResolvedDefinition <> nil) and not AValue.HasEffectiveText then
    Exit(necDefinition);
  Result := necText;
end;

function ParseSourceForms(AValue: TNexusScriptCompiledValue;
  out AForms: TNSSourceForms): Boolean;
var
  lItem: TNexusScriptCompiledValue;
  lText: string;
begin
  AForms := [];
  Result := AValue <> nil;
  if not Result then
    Exit;
  for lItem in AValue.Items do
  begin
    if not EffectiveValue(lItem).HasEffectiveText then
      Exit(False);
    lText := EffectiveValue(lItem).EffectiveText;
    if SameText(lText, 'Text') then Include(AForms, nsfText)
    else if SameText(lText, 'Array') then Include(AForms, nsfArray)
    else if SameText(lText, 'Reference') then Include(AForms, nsfReference)
    else if SameText(lText, 'TextComposition') then Include(AForms, nsfTextComposition)
    else if SameText(lText, 'InlineDefinition') then Include(AForms, nsfInlineDefinition)
    else Exit(False);
  end;
  Result := AForms <> [];
end;

function ParseCategories(AValue: TNexusScriptCompiledValue;
  out ACategories: TNSEffectiveCategories): Boolean;
var
  lItem: TNexusScriptCompiledValue;
  lText: string;
begin
  ACategories := [];
  Result := AValue <> nil;
  if not Result then
    Exit;
  for lItem in AValue.Items do
  begin
    if not EffectiveValue(lItem).HasEffectiveText then
      Exit(False);
    lText := EffectiveValue(lItem).EffectiveText;
    if SameText(lText, 'Text') then Include(ACategories, necText)
    else if SameText(lText, 'Array') then Include(ACategories, necArray)
    else if SameText(lText, 'Definition') then Include(ACategories, necDefinition)
    else Exit(False);
  end;
  Result := ACategories <> [];
end;

function StructuralDefinition(AValue: TNexusScriptCompiledValue):
  TNexusScriptCompiledDefinition;
begin
  Result := AValue.StructuralDefinition;
  if (Result = nil) and (AValue.EffectiveValue <> nil) then
    Result := AValue.EffectiveValue.StructuralDefinition;
end;

function TNSValidatorEngine.NormalizeArray(
  ADefinition: TNexusScriptCompiledDefinition;
  out ARule: TNSArrayRule): Boolean;
var
  lText: string;
  lValue: Integer;
  lBoolean: Boolean;
begin
  Result := False;
  ARule := TNSArrayRule.Create;
  if not HasOnlyMembers(ADefinition,
    'Minimum|Maximum|Names|EntrySourceForms|EntryEffectiveCategories|DefinitionKinds|AllowedValues|Mixed',
    '') then Exit;
  if PropertyText(ADefinition, 'Minimum', lText) then
  begin
    if not ParseNonNegativeInteger(lText, lValue) then
      Exit;
    ARule.Minimum := lValue;
  end;
  if PropertyText(ADefinition, 'Maximum', lText) then
  begin
    if SameText(lText, 'Unbounded') then
      ARule.Maximum := cUnbounded
    else
    begin
      if not ParseNonNegativeInteger(lText, lValue) then
        Exit;
      ARule.Maximum := lValue;
    end;
  end;
  if (ARule.Maximum <> cUnbounded) and (ARule.Minimum > ARule.Maximum) then
    Exit;
  if PropertyText(ADefinition, 'Names', lText) then
  begin
    if SameText(lText, 'Required') then ARule.NamePolicy := nnpRequired
    else if SameText(lText, 'Optional') then ARule.NamePolicy := nnpOptional
    else if SameText(lText, 'Forbidden') then ARule.NamePolicy := nnpForbidden
    else Exit;
  end;
  if ADefinition.FindProperty('EntrySourceForms') <> nil then
  begin
    ARule.HasEntrySourceForms := ParseSourceForms(
      PropertyArray(ADefinition, 'EntrySourceForms'), ARule.EntrySourceForms);
    if not ARule.HasEntrySourceForms then Exit;
  end;
  if ADefinition.FindProperty('EntryEffectiveCategories') <> nil then
  begin
    ARule.HasEntryCategories := ParseCategories(
      PropertyArray(ADefinition, 'EntryEffectiveCategories'),
      ARule.EntryCategories);
    if not ARule.HasEntryCategories then Exit;
  end;
  if ADefinition.FindProperty('DefinitionKinds') <> nil then
    if not AddTextItems(PropertyArray(ADefinition, 'DefinitionKinds'),
      ARule.DefinitionKinds) then Exit;
  if ADefinition.FindProperty('AllowedValues') <> nil then
  begin
    if not AddTextItems(PropertyArray(ADefinition, 'AllowedValues'),
      ARule.AllowedValues) then Exit;
    if ARule.AllowedValues.Count = 0 then Exit;
  end;
  if PropertyText(ADefinition, 'Mixed', lText) then
  begin
    if not ParseBoolean(lText, lBoolean) then Exit;
    ARule.Mixed := lBoolean;
  end;
  Result := True;
end;

function TNSValidatorEngine.NormalizeReference(
  ADefinition: TNexusScriptCompiledDefinition;
  out ARule: TNSReferenceRule): Boolean;
var
  lArray: TNexusScriptCompiledValue;
  lItem: TNexusScriptCompiledValue;
  lText: string;
begin
  Result := False;
  ARule := TNSReferenceRule.Create;
  if not HasOnlyMembers(ADefinition, 'Targets|DefinitionKinds', '') then Exit;
  lArray := PropertyArray(ADefinition, 'Targets');
  if lArray = nil then Exit;
  for lItem in lArray.Items do
  begin
    if not EffectiveValue(lItem).HasEffectiveText then Exit;
    lText := EffectiveValue(lItem).EffectiveText;
    if SameText(lText, 'Property') then Include(ARule.Targets, nrtProperty)
    else if SameText(lText, 'Definition') then Include(ARule.Targets, nrtDefinition)
    else Exit;
  end;
  if ARule.Targets = [] then Exit;
  if ADefinition.FindProperty('DefinitionKinds') <> nil then
    if not AddTextItems(PropertyArray(ADefinition, 'DefinitionKinds'),
      ARule.DefinitionKinds) then Exit;
  Result := True;
end;

function TNSValidatorEngine.NormalizeValue(
  ADefinition: TNexusScriptCompiledDefinition;
  out ARule: TNSValueRule): Boolean;
var
  lText: string;
begin
  Result := False;
  ARule := TNSValueRule.Create;
  if not HasOnlyMembers(ADefinition,
    'SourceForms|EffectiveCategories|Scalar|AllowedValues',
    'Array|Reference') then Exit;
  if (ADefinition.FindChild('Array') <> nil) and
    not SameText(ADefinition.FindChild('Array').Kind, 'Array') then Exit;
  if (ADefinition.FindChild('Reference') <> nil) and
    not SameText(ADefinition.FindChild('Reference').Kind, 'Reference') then Exit;
  if ADefinition.FindProperty('SourceForms') <> nil then
  begin
    ARule.HasSourceForms := ParseSourceForms(
      PropertyArray(ADefinition, 'SourceForms'), ARule.SourceForms);
    if not ARule.HasSourceForms then Exit;
  end;
  if ADefinition.FindProperty('EffectiveCategories') <> nil then
  begin
    ARule.HasEffectiveCategories := ParseCategories(
      PropertyArray(ADefinition, 'EffectiveCategories'),
      ARule.EffectiveCategories);
    if not ARule.HasEffectiveCategories then Exit;
  end;
  if PropertyText(ADefinition, 'Scalar', lText) then
  begin
    if SameText(lText, 'Text') then ARule.ScalarKind := nskText
    else if SameText(lText, 'Integer') then ARule.ScalarKind := nskInteger
    else if SameText(lText, 'Boolean') then ARule.ScalarKind := nskBoolean
    else Exit;
  end;
  if ADefinition.FindProperty('AllowedValues') <> nil then
  begin
    if not AddTextItems(PropertyArray(ADefinition, 'AllowedValues'),
      ARule.AllowedValues) then Exit;
    if ARule.AllowedValues.Count = 0 then Exit;
  end;
  if ADefinition.FindChild('Array') <> nil then
    if not NormalizeArray(ADefinition.FindChild('Array'), ARule.ArrayRule) then Exit;
  if ADefinition.FindChild('Reference') <> nil then
    if not NormalizeReference(ADefinition.FindChild('Reference'),
      ARule.ReferenceRule) then Exit;
  Result := True;
end;

function TNSValidatorEngine.NormalizeProperty(
  ADefinition: TNexusScriptCompiledDefinition;
  out ARule: TNSPropertyRule): Boolean;
var
  lText: string;
  lBoolean: Boolean;
begin
  Result := False;
  ARule := TNSPropertyRule.Create;
  if not HasOnlyMembers(ADefinition, 'Required', 'Value') then Exit;
  if (ADefinition.FindChild('Value') <> nil) and
    not SameText(ADefinition.FindChild('Value').Kind, 'Value') then Exit;
  ARule.Name := ADefinition.Name;
  ARule.SourceRange := ADefinition.SourceRange;
  if PropertyText(ADefinition, 'Required', lText) then
  begin
    if not ParseBoolean(lText, lBoolean) then Exit;
    ARule.Required := lBoolean;
  end;
  if ADefinition.FindChild('Value') <> nil then
    if not NormalizeValue(ADefinition.FindChild('Value'), ARule.ValueRule) then Exit;
  Result := True;
end;

function TNSValidatorEngine.NormalizeChild(
  ADefinition: TNexusScriptCompiledDefinition;
  out ARule: TNSChildRule): Boolean;
var
  lText: string;
  lValue: Integer;
begin
  Result := False;
  ARule := TNSChildRule.Create;
  if not HasOnlyMembers(ADefinition, 'Kinds|Minimum|Maximum', '') then Exit;
  ARule.Name := ADefinition.Name;
  ARule.SourceRange := ADefinition.SourceRange;
  if not AddTextItems(PropertyArray(ADefinition, 'Kinds'), ARule.Kinds) or
    (ARule.Kinds.Count = 0) then Exit;
  if PropertyText(ADefinition, 'Minimum', lText) then
  begin
    if not ParseNonNegativeInteger(lText, lValue) then Exit;
    ARule.Minimum := lValue;
  end;
  if PropertyText(ADefinition, 'Maximum', lText) then
  begin
    if SameText(lText, 'Unbounded') then ARule.Maximum := cUnbounded
    else begin
      if not ParseNonNegativeInteger(lText, lValue) then Exit;
      ARule.Maximum := lValue;
    end;
  end;
  if (ARule.Maximum <> cUnbounded) and (ARule.Minimum > ARule.Maximum) then Exit;
  Result := True;
end;

function TNSValidatorEngine.NormalizeDefinition(
  ADefinition: TNexusScriptCompiledDefinition;
  out ARule: TNSDefinitionRule): Boolean;
var
  lText: string;
  lBoolean: Boolean;
  lArray: TNexusScriptCompiledValue;
  lItem: TNexusScriptCompiledValue;
  lDefinition: TNexusScriptCompiledDefinition;
  lPropertyRule: TNSPropertyRule;
  lChildRule: TNSChildRule;
  lIndex: Integer;
  lOtherIndex: Integer;
  lEffectiveName: string;
begin
  Result := False;
  ARule := TNSDefinitionRule.Create;
  if not HasOnlyMembers(ADefinition,
    'Root|Parents|UnknownProperties|UnknownChildren|Properties|Children', '') then Exit;
  ARule.KindName := ADefinition.Name;
  ARule.SourceRange := ADefinition.SourceRange;
  if PropertyText(ADefinition, 'Root', lText) then
  begin
    if not ParseBoolean(lText, lBoolean) then Exit;
    ARule.RootAllowed := lBoolean;
  end;
  if ADefinition.FindProperty('Parents') <> nil then
    if not AddTextItems(PropertyArray(ADefinition, 'Parents'), ARule.Parents) then Exit;
  if PropertyText(ADefinition, 'UnknownProperties', lText) then
    if not ParseUnknownPolicy(lText, ARule.UnknownProperties) then Exit;
  if PropertyText(ADefinition, 'UnknownChildren', lText) then
  begin
    ARule.HasUnknownChildren := True;
    if not ParseUnknownPolicy(lText, ARule.UnknownChildren) then Exit;
  end;
  lArray := PropertyArray(ADefinition, 'Properties');
  if lArray <> nil then
    for lItem in lArray.Items do
    begin
      lDefinition := StructuralDefinition(lItem);
      if (lDefinition = nil) or not SameText(lDefinition.Kind, 'Property') then Exit;
      lPropertyRule := nil;
      if not NormalizeProperty(lDefinition, lPropertyRule) then
      begin
        lPropertyRule.Free;
        Exit;
      end;
      lEffectiveName := lItem.EffectiveName;
      if lEffectiveName <> '' then lPropertyRule.Name := lEffectiveName;
      if FindPropertyRule(ARule, lPropertyRule.Name) <> nil then
      begin
        lPropertyRule.Free;
        Exit;
      end;
      ARule.PropertyRules.Add(lPropertyRule);
    end;
  lArray := PropertyArray(ADefinition, 'Children');
  ARule.HasChildren := lArray <> nil;
  if ARule.HasChildren and not ARule.HasUnknownChildren then
    ARule.UnknownChildren := nupReject;
  if lArray <> nil then
    for lItem in lArray.Items do
    begin
      lDefinition := StructuralDefinition(lItem);
      if (lDefinition = nil) or not SameText(lDefinition.Kind, 'Child') then Exit;
      lChildRule := nil;
      if not NormalizeChild(lDefinition, lChildRule) then
      begin
        lChildRule.Free;
        Exit;
      end;
      lEffectiveName := lItem.EffectiveName;
      if lEffectiveName <> '' then lChildRule.Name := lEffectiveName;
      for lIndex := 0 to ARule.ChildRules.Count - 1 do
        for lOtherIndex := 0 to lChildRule.Kinds.Count - 1 do
          if ARule.ChildRules[lIndex].Kinds.IndexOf(
            lChildRule.Kinds[lOtherIndex]) >= 0 then
          begin
            lChildRule.Free;
            Exit;
          end;
      ARule.ChildRules.Add(lChildRule);
    end;
  Result := True;
end;

function TNSValidatorEngine.Normalize(
  ADocument: TNexusScriptCompiledDocument): Boolean;
var
  lLanguageDefinition: TNexusScriptCompiledDefinition;
  lDefinition: TNexusScriptCompiledDefinition;
  lArray: TNexusScriptCompiledValue;
  lItem: TNexusScriptCompiledValue;
  lRule: TNSDefinitionRule;
  lChildRule: TNSChildRule;
  lPropertyRule: TNSPropertyRule;
  lText: string;
  lIndex: Integer;
  lRuleName: string;
begin
  Result := False;
  FLanguage.Free;
  FLanguage := TNSLanguageRule.Create;
  if (ADocument = nil) or (ADocument.Definitions.Count <> 1) then
  begin
    AddDiagnostic('NSV1001', 'Language definition must contain exactly one root Language definition.',
      Default(TNexusScriptRange));
    Exit;
  end;
  lLanguageDefinition := ADocument.Definitions[0];
  if not SameText(lLanguageDefinition.Kind, 'Language') then
  begin
    AddDiagnostic('NSV1002', 'Language definition root must have kind Language.',
      lLanguageDefinition.SourceRange);
    Exit;
  end;
  if not HasOnlyMembers(lLanguageDefinition,
    'UnknownDefinitions|Definitions', '') then
  begin
    AddDiagnostic('NSV1010', 'Language contains an unknown member.',
      lLanguageDefinition.SourceRange);
    Exit;
  end;
  if PropertyText(lLanguageDefinition, 'UnknownDefinitions', lText) then
    if not ParseUnknownPolicy(lText, FLanguage.UnknownDefinitions) then
    begin
      AddDiagnostic('NSV1003', 'UnknownDefinitions must be Allow or Reject.',
        lLanguageDefinition.FindProperty('UnknownDefinitions').SourceRange);
      Exit;
    end;
  lArray := PropertyArray(lLanguageDefinition, 'Definitions');
  if lArray = nil then
  begin
    AddDiagnostic('NSV1004', 'Language requires a Definitions array.',
      lLanguageDefinition.SourceRange);
    Exit;
  end;
  for lItem in lArray.Items do
  begin
    lDefinition := StructuralDefinition(lItem);
    if (lDefinition = nil) or not SameText(lDefinition.Kind, 'Definition') then
    begin
      AddDiagnostic('NSV1005', 'Definitions entries must be Definition values.',
        lItem.SourceRange);
      Exit;
    end;
    lRuleName := lItem.EffectiveName;
    if lRuleName = '' then lRuleName := lDefinition.Name;
    if FindDefinitionRule(lRuleName) <> nil then
    begin
      AddDiagnostic('NSV1006', 'Duplicate definition rule ' + lRuleName + '.',
        lDefinition.SourceRange);
      Exit;
    end;
    lRule := nil;
    if not NormalizeDefinition(lDefinition, lRule) then
    begin
      lRule.Free;
      AddDiagnostic('NSV1007', 'Invalid definition rule ' + lDefinition.Name + '.',
        lDefinition.SourceRange);
      Exit;
    end;
    lRule.KindName := lRuleName;
    FLanguage.DefinitionRules.Add(lRule);
  end;
  for lRule in FLanguage.DefinitionRules do
  begin
    for lIndex := 0 to lRule.Parents.Count - 1 do
      if FindDefinitionRule(lRule.Parents[lIndex]) = nil then
      begin
        AddDiagnostic('NSV1008', 'Unknown parent kind ' + lRule.Parents[lIndex] + '.',
          lRule.SourceRange);
        Exit;
      end;
    for lChildRule in lRule.ChildRules do
      for lIndex := 0 to lChildRule.Kinds.Count - 1 do
        if FindDefinitionRule(lChildRule.Kinds[lIndex]) = nil then
        begin
          AddDiagnostic('NSV1011', 'Unknown child kind ' +
            lChildRule.Kinds[lIndex] + '.', lChildRule.SourceRange);
          Exit;
        end;
    for lPropertyRule in lRule.PropertyRules do
    begin
      if (lPropertyRule.ValueRule <> nil) and
        (lPropertyRule.ValueRule.ArrayRule <> nil) then
        for lIndex := 0 to
          lPropertyRule.ValueRule.ArrayRule.DefinitionKinds.Count - 1 do
          if FindDefinitionRule(
            lPropertyRule.ValueRule.ArrayRule.DefinitionKinds[lIndex]) = nil then
          begin
            AddDiagnostic('NSV1012', 'Unknown array definition kind ' +
              lPropertyRule.ValueRule.ArrayRule.DefinitionKinds[lIndex] + '.',
              lPropertyRule.SourceRange);
            Exit;
          end;
      if (lPropertyRule.ValueRule <> nil) and
        (lPropertyRule.ValueRule.ReferenceRule <> nil) then
        for lIndex := 0 to
          lPropertyRule.ValueRule.ReferenceRule.DefinitionKinds.Count - 1 do
          if FindDefinitionRule(
            lPropertyRule.ValueRule.ReferenceRule.DefinitionKinds[lIndex]) = nil then
          begin
            AddDiagnostic('NSV1013', 'Unknown reference definition kind ' +
              lPropertyRule.ValueRule.ReferenceRule.DefinitionKinds[lIndex] + '.',
              lPropertyRule.SourceRange);
            Exit;
          end;
    end;
  end;
  Result := True;
end;

function TNSValidatorEngine.FindDefinitionRule(
  const AKind: string): TNSDefinitionRule;
var
  lRule: TNSDefinitionRule;
begin
  Result := nil;
  if FLanguage = nil then Exit;
  for lRule in FLanguage.DefinitionRules do
    if SameText(lRule.KindName, AKind) then Exit(lRule);
end;

function TNSValidatorEngine.FindPropertyRule(ARule: TNSDefinitionRule;
  const AName: string): TNSPropertyRule;
var
  lRule: TNSPropertyRule;
begin
  Result := nil;
  for lRule in ARule.PropertyRules do
    if SameText(lRule.Name, AName) then Exit(lRule);
end;

function TNSValidatorEngine.FindChildRule(ARule: TNSDefinitionRule;
  const AKind: string): TNSChildRule;
var
  lRule: TNSChildRule;
begin
  Result := nil;
  for lRule in ARule.ChildRules do
    if lRule.Kinds.IndexOf(AKind) >= 0 then Exit(lRule);
end;

procedure TNSValidatorEngine.ValidateReference(AValue: TNexusScriptCompiledValue;
  ARule: TNSReferenceRule);
begin
  if (AValue.ResolvedProperty <> nil) and not (nrtProperty in ARule.Targets) then
    AddDiagnostic('NSV3001', 'Reference target must not be a property.',
      AValue.SourceRange)
  else if (AValue.ResolvedDefinition <> nil) and
    not (nrtDefinition in ARule.Targets) then
    AddDiagnostic('NSV3002', 'Reference target must not be a definition.',
      AValue.SourceRange)
  else if (AValue.ResolvedDefinition <> nil) and
    (ARule.DefinitionKinds.Count > 0) and
    (ARule.DefinitionKinds.IndexOf(AValue.ResolvedDefinition.Kind) < 0) then
    AddDiagnostic('NSV3003', 'Referenced definition kind ' +
      AValue.ResolvedDefinition.Kind + ' is not allowed.', AValue.SourceRange);
end;

procedure TNSValidatorEngine.ValidateArray(AValue: TNexusScriptCompiledValue;
  ARule: TNSArrayRule);
var
  lArray: TNexusScriptCompiledValue;
  lItem: TNexusScriptCompiledValue;
  lCategory: TNSEffectiveCategory;
  lFirstCategory: TNSEffectiveCategory;
  lHasFirstCategory: Boolean;
  lDefinition: TNexusScriptCompiledDefinition;
begin
  lArray := EffectiveValue(AValue);
  if (lArray = nil) or (lArray.Kind <> nsvArray) then Exit;
  if lArray.Items.Count < ARule.Minimum then
    AddDiagnostic('NSV2401', 'Array has fewer than ' + IntToStr(ARule.Minimum) +
      ' entries.', AValue.SourceRange);
  if (ARule.Maximum <> cUnbounded) and
    (lArray.Items.Count > ARule.Maximum) then
    AddDiagnostic('NSV2402', 'Array has more than ' + IntToStr(ARule.Maximum) +
      ' entries.', AValue.SourceRange);
  lHasFirstCategory := False;
  for lItem in lArray.Items do
  begin
    if (ARule.NamePolicy = nnpRequired) and (lItem.EffectiveName = '') then
      AddDiagnostic('NSV2403', 'Array entry requires an effective name.',
        lItem.SourceRange);
    if (ARule.NamePolicy = nnpForbidden) and (lItem.EffectiveName <> '') then
      AddDiagnostic('NSV2404', 'Array entry must be unnamed.', lItem.SourceRange);
    if ARule.HasEntrySourceForms and
      not (SourceFormOf(lItem) in ARule.EntrySourceForms) then
      AddDiagnostic('NSV2405', 'Array entry source form is not allowed.',
        lItem.SourceRange);
    lCategory := EffectiveCategoryOf(lItem);
    if ARule.HasEntryCategories and not (lCategory in ARule.EntryCategories) then
      AddDiagnostic('NSV2406', 'Array entry effective category is not allowed.',
        lItem.SourceRange);
    if ARule.AllowedValues.Count > 0 then
    begin
      if not EffectiveValue(lItem).HasEffectiveText then
        AddDiagnostic('NSV2409', 'Array entry must have an allowed scalar value.',
          lItem.SourceRange)
      else if ARule.AllowedValues.IndexOf(
        EffectiveValue(lItem).EffectiveText) < 0 then
        AddDiagnostic('NSV2409', 'Array entry value ' +
          EffectiveValue(lItem).EffectiveText + ' is not allowed.',
          lItem.SourceRange);
    end;
    if not ARule.Mixed then
    begin
      if not lHasFirstCategory then
      begin
        lFirstCategory := lCategory;
        lHasFirstCategory := True;
      end
      else if lCategory <> lFirstCategory then
        AddDiagnostic('NSV2407', 'Mixed array entry categories are not allowed.',
          lItem.SourceRange);
    end;
    lDefinition := StructuralDefinition(lItem);
    if (lDefinition <> nil) and (ARule.DefinitionKinds.Count > 0) and
      (ARule.DefinitionKinds.IndexOf(lDefinition.Kind) < 0) then
      AddDiagnostic('NSV2408', 'Array definition kind ' + lDefinition.Kind +
        ' is not allowed.', lItem.SourceRange);
  end;
end;

procedure TNSValidatorEngine.ValidateValue(AValue: TNexusScriptCompiledValue;
  ARule: TNSValueRule);
var
  lText: string;
  lInteger: Integer;
  lBoolean: Boolean;
begin
  if ARule.HasSourceForms and not (SourceFormOf(AValue) in ARule.SourceForms) then
    AddDiagnostic('NSV2301', 'Value source form is not allowed.', AValue.SourceRange);
  if ARule.HasEffectiveCategories and
    not (EffectiveCategoryOf(AValue) in ARule.EffectiveCategories) then
    AddDiagnostic('NSV2302', 'Value effective category is not allowed.',
      AValue.SourceRange);
  if ARule.ScalarKind <> nskNone then
  begin
    if not EffectiveValue(AValue).HasEffectiveText then
      AddDiagnostic('NSV2303', 'Value must have effective text.', AValue.SourceRange)
    else
    begin
      lText := EffectiveValue(AValue).EffectiveText;
      if (ARule.ScalarKind = nskInteger) and
        not ParseInteger(lText, lInteger) then
        AddDiagnostic('NSV2304', 'Value must be an Integer.', AValue.SourceRange)
      else if (ARule.ScalarKind = nskBoolean) and
        not ParseBoolean(lText, lBoolean) then
        AddDiagnostic('NSV2305', 'Value must be True or False.', AValue.SourceRange);
    end;
  end;
  if ARule.AllowedValues.Count > 0 then
  begin
    if not EffectiveValue(AValue).HasEffectiveText then
      AddDiagnostic('NSV2306', 'Value must have an allowed scalar value.',
        AValue.SourceRange)
    else if ARule.AllowedValues.IndexOf(
      EffectiveValue(AValue).EffectiveText) < 0 then
      AddDiagnostic('NSV2306', 'Value ' + EffectiveValue(AValue).EffectiveText +
        ' is not allowed.', AValue.SourceRange);
  end;
  if ARule.ArrayRule <> nil then ValidateArray(AValue, ARule.ArrayRule);
  if (ARule.ReferenceRule <> nil) and (AValue.Kind = nsvReference) then
    ValidateReference(AValue, ARule.ReferenceRule);
end;

procedure TNSValidatorEngine.ValidateProperty(
  AProperty: TNexusScriptCompiledProperty; ARule: TNSPropertyRule);
begin
  if ARule.ValueRule <> nil then ValidateValue(AProperty.Value, ARule.ValueRule);
end;

procedure TNSValidatorEngine.ValidateDefinition(
  ADefinition: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition; AIsRoot: Boolean);
var
  lRule: TNSDefinitionRule;
  lParentRule: TNSDefinitionRule;
  lPropertyRule: TNSPropertyRule;
  lProperty: TNexusScriptCompiledProperty;
  lChildRule: TNSChildRule;
  lChild: TNexusScriptCompiledDefinition;
  lItem: TNexusScriptCompiledValue;
  lArray: TNexusScriptCompiledValue;
  lContained: TList<TNexusScriptCompiledDefinition>;
  lCount: Integer;
begin
  if FVisited.IndexOf(ADefinition) >= 0 then Exit;
  FVisited.Add(ADefinition);
  lRule := FindDefinitionRule(ADefinition.Kind);
  if lRule = nil then
  begin
    if FLanguage.UnknownDefinitions = nupReject then
      AddDiagnostic('NSV2001', 'Unknown definition kind ' + ADefinition.Kind + '.',
        ADefinition.SourceRange);
    Exit;
  end;
  if AIsRoot and not lRule.RootAllowed then
    AddDiagnostic('NSV2002', 'Definition kind ' + ADefinition.Kind +
      ' is not allowed at document root.', ADefinition.SourceRange);
  if (AParent <> nil) and (lRule.Parents.Count > 0) and
    (lRule.Parents.IndexOf(AParent.Kind) < 0) then
    AddDiagnostic('NSV2003', 'Definition kind ' + ADefinition.Kind +
      ' is not allowed under ' + AParent.Kind + '.', ADefinition.SourceRange);
  if AParent <> nil then
  begin
    lParentRule := FindDefinitionRule(AParent.Kind);
    if lParentRule <> nil then
    begin
      lChildRule := FindChildRule(lParentRule, ADefinition.Kind);
      if (lChildRule = nil) and
        (lParentRule.HasChildren or lParentRule.HasUnknownChildren) and
        (lParentRule.UnknownChildren = nupReject) then
        AddDiagnostic('NSV2004', 'Parent kind ' + AParent.Kind +
          ' does not allow child kind ' + ADefinition.Kind + '.',
          ADefinition.SourceRange);
    end;
  end;
  for lPropertyRule in lRule.PropertyRules do
    if lPropertyRule.Required and
      (ADefinition.FindProperty(lPropertyRule.Name) = nil) then
      AddDiagnostic('NSV2101', 'Missing required property ' +
        lPropertyRule.Name + '.', ADefinition.SourceRange);
  for lProperty in ADefinition.Properties do
  begin
    lPropertyRule := FindPropertyRule(lRule, lProperty.Name);
    if lPropertyRule = nil then
    begin
      if lRule.UnknownProperties = nupReject then
        AddDiagnostic('NSV2102', 'Unknown property ' + lProperty.Name + '.',
          lProperty.SourceRange);
    end
    else
      ValidateProperty(lProperty, lPropertyRule);
  end;
  lContained := TList<TNexusScriptCompiledDefinition>.Create;
  try
    for lChild in ADefinition.Children do lContained.Add(lChild);
    for lProperty in ADefinition.Properties do
    begin
      lArray := EffectiveValue(lProperty.Value);
      if (lArray <> nil) and (lArray.Kind = nsvArray) then
        for lItem in lArray.Items do
        begin
          lChild := StructuralDefinition(lItem);
          if (lChild <> nil) and (lContained.IndexOf(lChild) < 0) then
            lContained.Add(lChild);
        end;
    end;
    for lChildRule in lRule.ChildRules do
    begin
      lCount := 0;
      for lChild in lContained do
        if lChildRule.Kinds.IndexOf(lChild.Kind) >= 0 then Inc(lCount);
      if lCount < lChildRule.Minimum then
        AddDiagnostic('NSV2201', 'Child rule ' + lChildRule.Name +
          ' requires at least ' + IntToStr(lChildRule.Minimum) + '.',
          ADefinition.SourceRange);
      if (lChildRule.Maximum <> cUnbounded) and (lCount > lChildRule.Maximum) then
        AddDiagnostic('NSV2202', 'Child rule ' + lChildRule.Name +
          ' allows at most ' + IntToStr(lChildRule.Maximum) + '.',
          ADefinition.SourceRange);
    end;
    for lChild in lContained do ValidateDefinition(lChild, ADefinition, False);
  finally
    lContained.Free;
  end;
end;

function TNSValidatorEngine.Execute(ASubject,
  ALanguageDefinition: TNexusScriptCompiledDocument): Boolean;
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := Normalize(ALanguageDefinition);
  if not Result then Exit;
  if ASubject = nil then
  begin
    AddDiagnostic('NSV1009', 'Subject document is required.',
      Default(TNexusScriptRange));
    Exit(False);
  end;
  FVisited.Clear;
  for lDefinition in ASubject.Definitions do
    ValidateDefinition(lDefinition, nil, True);
  Result := FDiagnostics.Count = 0;
end;

end.
