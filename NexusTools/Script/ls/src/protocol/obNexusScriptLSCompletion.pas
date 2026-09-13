unit obNexusScriptLSCompletion;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONRPCObjects,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

type
  TNexusScriptLSCompletionRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSCompletionParams;
    procedure SetParams(AValue: TNXLSCompletionParams);
    function GetResult: TNXLSCompletionItemArray;
    procedure SetResult(AValue: TNXLSCompletionItemArray);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSCompletionParams read GetParams write SetParams;
    property result: TNXLSCompletionItemArray read GetResult write SetResult;
  end;

implementation

uses
  obNXClassFactory,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptCompiler,
  obNexusScriptAnalysis,
  obNexusScriptLanguageDefinition,
  obNexusScriptLSModel;

function ContainsPosition(const ARange: TNexusScriptRange;
  ALine, AColumn: Integer): Boolean;
begin
  Result := ((ALine > ARange.StartPosition.Line) or
    ((ALine = ARange.StartPosition.Line) and
    (AColumn >= ARange.StartPosition.Column))) and
    ((ALine < ARange.EndPosition.Line) or
    ((ALine = ARange.EndPosition.Line) and
    (AColumn <= ARange.EndPosition.Column)));
end;

function DefinitionAt(ADefinitions: TNexusScriptSourceDefinitionList;
  ALine, AColumn: Integer): TNexusScriptSourceDefinition;
var
  lDefinition: TNexusScriptSourceDefinition;
  lChild: TNexusScriptSourceDefinition;
begin
  Result := nil;
  for lDefinition in ADefinitions do
    if ContainsPosition(lDefinition.SourceRange, ALine, AColumn) then
    begin
      lChild := DefinitionAt(lDefinition.Children, ALine, AColumn);
      if lChild <> nil then
        Exit(lChild);
      Exit(lDefinition);
    end;
end;

function PropertyAt(ADefinition: TNexusScriptSourceDefinition;
  ALine, AColumn: Integer): TNexusScriptSourceProperty;
var
  lProperty: TNexusScriptSourceProperty;
begin
  Result := nil;
  for lProperty in ADefinition.Properties do
    if ContainsPosition(lProperty.ValueRange, ALine, AColumn) then
      Exit(lProperty);
end;

procedure AddCompletion(AResult: TNXLSCompletionItemArray;
  const ALabel, AInsertText, ADetail: string; AKind: Integer);
var
  lItem: TNXLSCompletionItem;
begin
  lItem := TNXLSCompletionItem(AResult.AddObject(TNXLSCompletionItem));
  lItem.&label.Value := ALabel;
  lItem.insertText.Value := AInsertText;
  lItem.detail.Value := ADetail;
  lItem.kind.Value := AKind;
end;

procedure AddDefinitionCandidates(AResult: TNXLSCompletionItemArray;
  ADefinitions: TNexusScriptCompiledDefinitionList;
  ARule: TNSReferenceRule);
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  for lDefinition in ADefinitions do
  begin
    if (ARule.DefinitionKindCount = 0) or
      ARule.HasDefinitionKind(lDefinition.Kind) then
      AddCompletion(AResult, lDefinition.Name, lDefinition.Name,
        lDefinition.Kind + ' reference', 18);
    AddDefinitionCandidates(AResult, lDefinition.Children, ARule);
  end;
end;

procedure AddValueCompletions(AResult: TNXLSCompletionItemArray;
  ARule: TNSValueRule; AAnalysis: TNexusScriptAnalysis);
var
  lIndex: Integer;
begin
  for lIndex := 0 to ARule.AllowedValueCount - 1 do
    AddCompletion(AResult, ARule.AllowedValues[lIndex],
      ARule.AllowedValues[lIndex], 'Allowed value', 12);
  if ARule.ScalarKind = nskBoolean then
  begin
    AddCompletion(AResult, 'True', 'True', 'Boolean', 12);
    AddCompletion(AResult, 'False', 'False', 'Boolean', 12);
  end;
  if (ARule.ArrayRule <> nil) then
    for lIndex := 0 to ARule.ArrayRule.AllowedValueCount - 1 do
      AddCompletion(AResult, ARule.ArrayRule.AllowedValues[lIndex],
        ARule.ArrayRule.AllowedValues[lIndex], 'Allowed array value', 12);
  if (ARule.ReferenceRule <> nil) and
    (nrtDefinition in ARule.ReferenceRule.Targets) and
    (AAnalysis.EntryCompiler <> nil) then
    AddDefinitionCandidates(AResult,
      AAnalysis.EntryCompiler.CompiledDocument.Definitions,
      ARule.ReferenceRule);
end;

class function TNexusScriptLSCompletionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/completion';
end;

function TNexusScriptLSCompletionRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lCompiler: TNexusScriptCompiler;
  lDefinition: TNexusScriptSourceDefinition;
  lRule: TNSDefinitionRule;
  lPropertyRule: TNSPropertyRule;
  lChildRule: TNSChildRule;
  lProperty: TNexusScriptSourceProperty;
  lIndex: Integer;
  lKindIndex: Integer;
  lResult: TNXLSCompletionItemArray;
begin
  lResult := TNXLSCompletionItemArray(PrepareResult);
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(
    params.textDocument.uri.Value);
  if lAnalysis = nil then
    Exit(lResult);
  lCompiler := lAnalysis.EntrySourceCompiler;
  if (lCompiler = nil) or (lCompiler.SourceDocument = nil) then
    Exit(lResult);
  lDefinition := DefinitionAt(lCompiler.SourceDocument.Definitions,
    params.position.line.Value + 1, params.position.character.Value + 1);
  if lDefinition = nil then
  begin
    AddCompletion(lResult, 'module', 'module "";',
      'NexusScript module dependency', 14);
    AddCompletion(lResult, 'include', 'include "";',
      'NexusScript include dependency', 14);
    AddCompletion(lResult, 'dialect', 'dialect "";',
      'NexusScript dialect', 14);
    AddCompletion(lResult, 'data', 'data ',
      'NexusScript data source', 14);
    for lIndex := 0 to lAnalysis.Language.DefinitionRuleCount - 1 do
    begin
      lRule := lAnalysis.Language.DefinitionRules[lIndex];
      if lRule.RootAllowed then
        AddCompletion(lResult, lRule.KindName, lRule.KindName + ' ',
          'Root definition', 7);
    end;
    Exit(lResult);
  end;
  lRule := lAnalysis.Language.FindDefinitionRule(lDefinition.Kind);
  if lRule = nil then
    Exit(lResult);
  lProperty := PropertyAt(lDefinition, params.position.line.Value + 1,
    params.position.character.Value + 1);
  if lProperty <> nil then
  begin
    lPropertyRule := lRule.FindPropertyRule(lProperty.Name);
    if (lPropertyRule <> nil) and (lPropertyRule.ValueRule <> nil) then
      AddValueCompletions(lResult, lPropertyRule.ValueRule, lAnalysis);
    Exit(lResult);
  end;
  for lIndex := 0 to lRule.PropertyRuleCount - 1 do
  begin
    lPropertyRule := lRule.PropertyRules[lIndex];
    if lDefinition.FindProperty(lPropertyRule.Name) = nil then
      AddCompletion(lResult, lPropertyRule.Name,
        lPropertyRule.Name + ': ', 'Property', 10);
  end;
  for lIndex := 0 to lRule.ChildRuleCount - 1 do
  begin
    lChildRule := lRule.ChildRules[lIndex];
    for lKindIndex := 0 to lChildRule.KindCount - 1 do
      AddCompletion(lResult, lChildRule.Kinds[lKindIndex],
        lChildRule.Kinds[lKindIndex] + ' ', 'Child definition', 7);
  end;
  Result := lResult;
end;

function TNexusScriptLSCompletionRequest.GetParams: TNXLSCompletionParams;
begin
  Result := TNXLSCompletionParams(inherited params);
end;

procedure TNexusScriptLSCompletionRequest.SetParams(
  AValue: TNXLSCompletionParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSCompletionRequest.GetResult: TNXLSCompletionItemArray;
begin
  Result := TNXLSCompletionItemArray(inherited result);
end;

procedure TNexusScriptLSCompletionRequest.SetResult(
  AValue: TNXLSCompletionItemArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNexusScriptLSCompletionRequest);

end.
