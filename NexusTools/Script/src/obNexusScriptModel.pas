unit obNexusScriptModel;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  tpNexusScript;

type
  TNexusScriptDiagnostic = class
  private
    FCode: string;
    FMessageText: string;
    FSourceRange: TNexusScriptRange;
  public
    constructor Create(const ACode, AMessageText: string;
      const ASourceRange: TNexusScriptRange);
    property Code: string read FCode;
    property MessageText: string read FMessageText;
    property SourceRange: TNexusScriptRange read FSourceRange;
  end;

  TNexusScriptSourceValue = class;
  TNexusScriptSourceDefinition = class;
  TNexusScriptCompiledValue = class;
  TNexusScriptCompiledDefinition = class;
  TNexusScriptCompiledProperty = class;

  TNexusScriptSourceValueList = TObjectList<TNexusScriptSourceValue>;
  TNexusScriptSourceDefinitionList = TObjectList<TNexusScriptSourceDefinition>;
  TNexusScriptCompiledValueList = TObjectList<TNexusScriptCompiledValue>;
  TNexusScriptCompiledDefinitionList = TObjectList<TNexusScriptCompiledDefinition>;
  TNexusScriptCompiledPropertyList = TObjectList<TNexusScriptCompiledProperty>;
  TNexusScriptDiagnosticList = TObjectList<TNexusScriptDiagnostic>;

  TNexusScriptSourceValue = class
  private
    FKind: TNexusScriptValueKind;
    FText: string;
    FItems: TNexusScriptSourceValueList;
    FSourceRange: TNexusScriptRange;
    FEntryName: string;
    FInlineDefinition: TNexusScriptSourceDefinition;
  public
    constructor Create(AKind: TNexusScriptValueKind;
      const ASourceRange: TNexusScriptRange);
    destructor Destroy; override;
    function FindNamedItem(const AName: string): TNexusScriptSourceValue;
    property Kind: TNexusScriptValueKind read FKind;
    property Text: string read FText write FText;
    property Items: TNexusScriptSourceValueList read FItems;
    property SourceRange: TNexusScriptRange read FSourceRange;
    property EntryName: string read FEntryName write FEntryName;
    property InlineDefinition: TNexusScriptSourceDefinition
      read FInlineDefinition write FInlineDefinition;
  end;

  TNexusScriptSourceProperty = class
  private
    FName: string;
    FValue: TNexusScriptSourceValue;
    FSourceRange: TNexusScriptRange;
  public
    constructor Create(const AName: string; AValue: TNexusScriptSourceValue;
      const ASourceRange: TNexusScriptRange);
    destructor Destroy; override;
    property Name: string read FName;
    property Value: TNexusScriptSourceValue read FValue;
    property SourceRange: TNexusScriptRange read FSourceRange;
  end;

  TNexusScriptSourcePropertyList = TObjectList<TNexusScriptSourceProperty>;

  TNexusScriptSourceDefinition = class
  private
    FKind: string;
    FName: string;
    FProperties: TNexusScriptSourcePropertyList;
    FChildren: TNexusScriptSourceDefinitionList;
    FCompositionSelectors: TStringList;
    FParent: TNexusScriptSourceDefinition;
    FSourceRange: TNexusScriptRange;
  public
    constructor Create(const AKind, AName: string;
      const ASourceRange: TNexusScriptRange);
    destructor Destroy; override;
    function FindProperty(const AName: string): TNexusScriptSourceProperty;
    function FindChild(const AName: string): TNexusScriptSourceDefinition;
    property Kind: string read FKind;
    property Name: string read FName;
    property Properties: TNexusScriptSourcePropertyList read FProperties;
    property Children: TNexusScriptSourceDefinitionList read FChildren;
    property CompositionSelectors: TStringList read FCompositionSelectors;
    property Parent: TNexusScriptSourceDefinition read FParent write FParent;
    property SourceRange: TNexusScriptRange read FSourceRange;
  end;

  TNexusScriptSourceModule = class
  private
    FAliasName: string;
    FRootSelector: string;
    FPath: string;
    FSourceRange: TNexusScriptRange;
  public
    property AliasName: string read FAliasName write FAliasName;
    property RootSelector: string read FRootSelector write FRootSelector;
    property Path: string read FPath write FPath;
    property SourceRange: TNexusScriptRange read FSourceRange write FSourceRange;
  end;

  TNexusScriptSourceModuleList = TObjectList<TNexusScriptSourceModule>;

  TNexusScriptSourceDoctype = class
  private
    FPath: string;
    FSourceRange: TNexusScriptRange;
  public
    property Path: string read FPath write FPath;
    property SourceRange: TNexusScriptRange read FSourceRange write FSourceRange;
  end;

  TNexusScriptSourceInclude = class
  private
    FPath: string;
    FSourceRange: TNexusScriptRange;
  public
    property Path: string read FPath write FPath;
    property SourceRange: TNexusScriptRange read FSourceRange write FSourceRange;
  end;

  TNexusScriptSourceIncludeList = TObjectList<TNexusScriptSourceInclude>;

  TNexusScriptSourceDocument = class
  private
    FSourceName: string;
    FDefinitions: TNexusScriptSourceDefinitionList;
    FModules: TNexusScriptSourceModuleList;
    FIncludes: TNexusScriptSourceIncludeList;
    FDoctype: TNexusScriptSourceDoctype;
    procedure SetDoctype(AValue: TNexusScriptSourceDoctype);
  public
    constructor Create(const ASourceName: string);
    destructor Destroy; override;
    function FindDefinition(const AName: string): TNexusScriptSourceDefinition;
    property SourceName: string read FSourceName;
    property Definitions: TNexusScriptSourceDefinitionList read FDefinitions;
    property Modules: TNexusScriptSourceModuleList read FModules;
    property Includes: TNexusScriptSourceIncludeList read FIncludes;
    property Doctype: TNexusScriptSourceDoctype read FDoctype write SetDoctype;
  end;

  TNexusScriptCompiledValue = class
  private
    FKind: TNexusScriptValueKind;
    FSourceText: string;
    FItems: TNexusScriptCompiledValueList;
    FSourceRange: TNexusScriptRange;
    FResolvedDefinition: TNexusScriptCompiledDefinition;
    FResolvedProperty: TNexusScriptCompiledProperty;
    FEffectiveText: string;
    FHasEffectiveText: Boolean;
    FStructuralDefinition: TNexusScriptCompiledDefinition;
    FEntryName: string;
    FEffectiveName: string;
    FOriginalDefinitionName: string;
    FInlineSourceDefinition: TNexusScriptSourceDefinition;
    FResolvedValue: TNexusScriptCompiledValue;
    FEffectiveValue: TNexusScriptCompiledValue;
    FCompositionContributors: TNexusScriptCompiledValueList;
    FEvaluated: Boolean;
  public
    constructor Create(AKind: TNexusScriptValueKind;
      const ASourceRange: TNexusScriptRange);
    destructor Destroy; override;
    function FindNamedItem(const AName: string): TNexusScriptCompiledValue;
    property Kind: TNexusScriptValueKind read FKind write FKind;
    property SourceText: string read FSourceText write FSourceText;
    property Items: TNexusScriptCompiledValueList read FItems;
    property SourceRange: TNexusScriptRange read FSourceRange;
    property ResolvedDefinition: TNexusScriptCompiledDefinition
      read FResolvedDefinition write FResolvedDefinition;
    property ResolvedProperty: TNexusScriptCompiledProperty
      read FResolvedProperty write FResolvedProperty;
    property EffectiveText: string read FEffectiveText write FEffectiveText;
    property HasEffectiveText: Boolean read FHasEffectiveText write FHasEffectiveText;
    property StructuralDefinition: TNexusScriptCompiledDefinition
      read FStructuralDefinition write FStructuralDefinition;
    property EntryName: string read FEntryName write FEntryName;
    property EffectiveName: string read FEffectiveName write FEffectiveName;
    property OriginalDefinitionName: string read FOriginalDefinitionName
      write FOriginalDefinitionName;
    property InlineSourceDefinition: TNexusScriptSourceDefinition
      read FInlineSourceDefinition write FInlineSourceDefinition;
    property ResolvedValue: TNexusScriptCompiledValue
      read FResolvedValue write FResolvedValue;
    property EffectiveValue: TNexusScriptCompiledValue
      read FEffectiveValue write FEffectiveValue;
    property CompositionContributors: TNexusScriptCompiledValueList
      read FCompositionContributors;
    property Evaluated: Boolean read FEvaluated write FEvaluated;
  end;

  TNexusScriptCompiledProperty = class
  private
    FName: string;
    FValue: TNexusScriptCompiledValue;
    FSourceRange: TNexusScriptRange;
    FResolving: Boolean;
  public
    constructor Create(const AName: string; AValue: TNexusScriptCompiledValue;
      const ASourceRange: TNexusScriptRange);
    destructor Destroy; override;
    property Name: string read FName;
    property Value: TNexusScriptCompiledValue read FValue;
    property SourceRange: TNexusScriptRange read FSourceRange;
    property Resolving: Boolean read FResolving write FResolving;
  end;

  TNexusScriptCompiledDefinition = class
  private
    FKind: string;
    FName: string;
    FProperties: TNexusScriptCompiledPropertyList;
    FChildren: TNexusScriptCompiledDefinitionList;
    FParent: TNexusScriptCompiledDefinition;
    FSourceRange: TNexusScriptRange;
    FComposing: Boolean;
    FComposed: Boolean;
    FModuleAlias: Boolean;
  public
    constructor Create(const AKind, AName: string;
      const ASourceRange: TNexusScriptRange);
    destructor Destroy; override;
    function FindProperty(const AName: string): TNexusScriptCompiledProperty;
    function FindChild(const AName: string): TNexusScriptCompiledDefinition;
    property Kind: string read FKind;
    property Name: string read FName;
    property Properties: TNexusScriptCompiledPropertyList read FProperties;
    property Children: TNexusScriptCompiledDefinitionList read FChildren;
    property Parent: TNexusScriptCompiledDefinition read FParent write FParent;
    property SourceRange: TNexusScriptRange read FSourceRange;
    property Composing: Boolean read FComposing write FComposing;
    property Composed: Boolean read FComposed write FComposed;
    property ModuleAlias: Boolean read FModuleAlias write FModuleAlias;
  end;

  TNexusScriptCompiledDocument = class
  private
    FSourceName: string;
    FDefinitions: TNexusScriptCompiledDefinitionList;
    FDoctypePath: string;
    FDoctypeSourceRange: TNexusScriptRange;
    FDoctypeSourceName: string;
    FDoctypeDocument: TNexusScriptCompiledDocument;
  public
    constructor Create(const ASourceName: string);
    destructor Destroy; override;
    function FindDefinition(const AName: string): TNexusScriptCompiledDefinition;
    procedure SetDoctype(const APath, ASourceName: string;
      const ASourceRange: TNexusScriptRange;
      ADocument: TNexusScriptCompiledDocument);
    property SourceName: string read FSourceName;
    property Definitions: TNexusScriptCompiledDefinitionList read FDefinitions;
    property DoctypePath: string read FDoctypePath;
    property DoctypeSourceRange: TNexusScriptRange read FDoctypeSourceRange;
    property DoctypeSourceName: string read FDoctypeSourceName;
    property DoctypeDocument: TNexusScriptCompiledDocument read FDoctypeDocument;
  end;

implementation

constructor TNexusScriptDiagnostic.Create(const ACode, AMessageText: string;
  const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FCode := ACode;
  FMessageText := AMessageText;
  FSourceRange := ASourceRange;
end;

constructor TNexusScriptSourceValue.Create(AKind: TNexusScriptValueKind;
  const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FKind := AKind;
  FSourceRange := ASourceRange;
  FItems := TNexusScriptSourceValueList.Create(True);
end;

destructor TNexusScriptSourceValue.Destroy;
begin
  FInlineDefinition.Free;
  FItems.Free;
  inherited Destroy;
end;

function TNexusScriptSourceValue.FindNamedItem(
  const AName: string): TNexusScriptSourceValue;
var
  lItem: TNexusScriptSourceValue;
begin
  Result := nil;
  for lItem in FItems do
    if SameText(lItem.EntryName, AName) then
      Exit(lItem);
end;

constructor TNexusScriptSourceProperty.Create(const AName: string;
  AValue: TNexusScriptSourceValue; const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FName := AName;
  FValue := AValue;
  FSourceRange := ASourceRange;
end;

destructor TNexusScriptSourceProperty.Destroy;
begin
  FValue.Free;
  inherited Destroy;
end;

constructor TNexusScriptSourceDefinition.Create(const AKind, AName: string;
  const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FKind := AKind;
  FName := AName;
  FSourceRange := ASourceRange;
  FProperties := TNexusScriptSourcePropertyList.Create(True);
  FChildren := TNexusScriptSourceDefinitionList.Create(True);
  FCompositionSelectors := TStringList.Create;
end;

destructor TNexusScriptSourceDefinition.Destroy;
begin
  FCompositionSelectors.Free;
  FChildren.Free;
  FProperties.Free;
  inherited Destroy;
end;

function TNexusScriptSourceDefinition.FindProperty(
  const AName: string): TNexusScriptSourceProperty;
var
  lProperty: TNexusScriptSourceProperty;
begin
  Result := nil;
  for lProperty in FProperties do
    if SameText(lProperty.Name, AName) then
      Exit(lProperty);
end;

function TNexusScriptSourceDefinition.FindChild(
  const AName: string): TNexusScriptSourceDefinition;
var
  lDefinition: TNexusScriptSourceDefinition;
begin
  Result := nil;
  for lDefinition in FChildren do
    if SameText(lDefinition.Name, AName) then
      Exit(lDefinition);
end;

constructor TNexusScriptSourceDocument.Create(const ASourceName: string);
begin
  inherited Create;
  FSourceName := ASourceName;
  FDefinitions := TNexusScriptSourceDefinitionList.Create(True);
  FModules := TNexusScriptSourceModuleList.Create(True);
  FIncludes := TNexusScriptSourceIncludeList.Create(True);
end;

destructor TNexusScriptSourceDocument.Destroy;
begin
  FDoctype.Free;
  FIncludes.Free;
  FModules.Free;
  FDefinitions.Free;
  inherited Destroy;
end;

procedure TNexusScriptSourceDocument.SetDoctype(
  AValue: TNexusScriptSourceDoctype);
begin
  if FDoctype = AValue then Exit;
  FDoctype.Free;
  FDoctype := AValue;
end;

function TNexusScriptSourceDocument.FindDefinition(
  const AName: string): TNexusScriptSourceDefinition;
var
  lDefinition: TNexusScriptSourceDefinition;
begin
  Result := nil;
  for lDefinition in FDefinitions do
    if SameText(lDefinition.Name, AName) then
      Exit(lDefinition);
end;

constructor TNexusScriptCompiledValue.Create(AKind: TNexusScriptValueKind;
  const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FKind := AKind;
  FSourceRange := ASourceRange;
  FItems := TNexusScriptCompiledValueList.Create(True);
  FCompositionContributors := TNexusScriptCompiledValueList.Create(True);
end;

destructor TNexusScriptCompiledValue.Destroy;
begin
  FEffectiveValue.Free;
  FCompositionContributors.Free;
  FStructuralDefinition.Free;
  FItems.Free;
  inherited Destroy;
end;

function TNexusScriptCompiledValue.FindNamedItem(
  const AName: string): TNexusScriptCompiledValue;
var
  lItem: TNexusScriptCompiledValue;
begin
  Result := nil;
  for lItem in FItems do
    if SameText(lItem.EffectiveName, AName) then
      Exit(lItem);
end;

constructor TNexusScriptCompiledProperty.Create(const AName: string;
  AValue: TNexusScriptCompiledValue; const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FName := AName;
  FValue := AValue;
  FSourceRange := ASourceRange;
end;

destructor TNexusScriptCompiledProperty.Destroy;
begin
  FValue.Free;
  inherited Destroy;
end;

constructor TNexusScriptCompiledDefinition.Create(const AKind, AName: string;
  const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FKind := AKind;
  FName := AName;
  FSourceRange := ASourceRange;
  FProperties := TNexusScriptCompiledPropertyList.Create(True);
  FChildren := TNexusScriptCompiledDefinitionList.Create(True);
end;

destructor TNexusScriptCompiledDefinition.Destroy;
begin
  FChildren.Free;
  FProperties.Free;
  inherited Destroy;
end;

function TNexusScriptCompiledDefinition.FindProperty(
  const AName: string): TNexusScriptCompiledProperty;
var
  lProperty: TNexusScriptCompiledProperty;
begin
  Result := nil;
  for lProperty in FProperties do
    if SameText(lProperty.Name, AName) then
      Exit(lProperty);
end;

function TNexusScriptCompiledDefinition.FindChild(
  const AName: string): TNexusScriptCompiledDefinition;
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := nil;
  for lDefinition in FChildren do
    if SameText(lDefinition.Name, AName) then
      Exit(lDefinition);
end;

constructor TNexusScriptCompiledDocument.Create(const ASourceName: string);
begin
  inherited Create;
  FSourceName := ASourceName;
  FDefinitions := TNexusScriptCompiledDefinitionList.Create(True);
end;

destructor TNexusScriptCompiledDocument.Destroy;
begin
  FDefinitions.Free;
  inherited Destroy;
end;

function TNexusScriptCompiledDocument.FindDefinition(
  const AName: string): TNexusScriptCompiledDefinition;
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := nil;
  for lDefinition in FDefinitions do
    if SameText(lDefinition.Name, AName) then
      Exit(lDefinition);
end;

procedure TNexusScriptCompiledDocument.SetDoctype(const APath,
  ASourceName: string; const ASourceRange: TNexusScriptRange;
  ADocument: TNexusScriptCompiledDocument);
begin
  FDoctypePath := APath;
  FDoctypeSourceRange := ASourceRange;
  FDoctypeSourceName := ASourceName;
  FDoctypeDocument := ADocument;
end;

end.
