unit obNexusScriptLSSemanticRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONRPCObjects,
  obNXLSProtocolParams,
  obNexusScriptLSSemanticObjects;

type
  TNexusScriptLSDocumentModelRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSDocumentLinkParams;
    procedure SetParams(AValue: TNXLSDocumentLinkParams);
    function GetResult: TNexusScriptLSDocumentModel;
    procedure SetResult(AValue: TNexusScriptLSDocumentModel);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDocumentLinkParams read GetParams write SetParams;
    property result: TNexusScriptLSDocumentModel read GetResult write SetResult;
  end;

  TNexusScriptLSDialectModelRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSDocumentLinkParams;
    procedure SetParams(AValue: TNXLSDocumentLinkParams);
    function GetResult: TNexusScriptLSDialectModel;
    procedure SetResult(AValue: TNexusScriptLSDialectModel);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDocumentLinkParams read GetParams write SetParams;
    property result: TNexusScriptLSDialectModel read GetResult write SetResult;
  end;

  TNexusScriptLSSetTargetsRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNexusScriptLSSetTargetsParams;
    procedure SetParams(AValue: TNexusScriptLSSetTargetsParams);
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNexusScriptLSSetTargetsParams read GetParams write SetParams;
  end;

  TNexusScriptLSSemanticEditRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNexusScriptLSSemanticEditParams;
    procedure SetParams(AValue: TNexusScriptLSSemanticEditParams);
    function GetResult: TNXLSWorkspaceEditResult;
    procedure SetResult(AValue: TNXLSWorkspaceEditResult);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNexusScriptLSSemanticEditParams read GetParams
      write SetParams;
    property result: TNXLSWorkspaceEditResult read GetResult write SetResult;
  end;

implementation

uses
  SysUtils,
  obNXClassFactory,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptCompiler,
  obNexusScriptAnalysis,
  obNexusScriptLanguageDefinition,
  obNexusScriptLSDocument,
  obNexusScriptLSModel,
  obNXLSProtocolBase;

procedure SetRange(ADestination: TNXLSRange;
  const ASource: TNexusScriptRange);
begin
  ADestination.start.line.Value := ASource.StartPosition.Line - 1;
  ADestination.start.character.Value := ASource.StartPosition.Column - 1;
  ADestination.&end.line.Value := ASource.EndPosition.Line - 1;
  ADestination.&end.character.Value := ASource.EndPosition.Column;
  ADestination.Assigned := True;
end;

function NodeID(ARevision: Integer; const ANodeType: string;
  const ARange: TNexusScriptRange): string;
begin
  Result := IntToStr(ARevision) + ':' + ANodeType + ':' +
    IntToStr(ARange.StartPosition.Offset);
end;

procedure AddDefinitionNodes(ADefinitions: TNexusScriptSourceDefinitionList;
  ARevision: Integer; AResult: TNexusScriptLSNodeArray);
var
  lDefinition: TNexusScriptSourceDefinition;
  lProperty: TNexusScriptSourceProperty;
  lNode: TNexusScriptLSNode;
  lPropertyNode: TNexusScriptLSNode;
begin
  for lDefinition in ADefinitions do
  begin
    lNode := TNexusScriptLSNode(AResult.AddObject(TNexusScriptLSNode));
    lNode.id.Value := NodeID(ARevision, 'definition',
      lDefinition.SourceRange);
    lNode.nodeType.Value := 'definition';
    lNode.kind.Value := lDefinition.Kind;
    lNode.name.Value := lDefinition.Name;
    lNode.sourceUri.Value := TNexusScriptLSModel.Current.URIForSourceName(
      lDefinition.SourceRange.SourceName);
    lNode.local.Value := True;
    lNode.allowedOperations.AddString('rename');
    lNode.allowedOperations.AddString('addChild');
    lNode.allowedOperations.AddString('setProperty');
    lNode.allowedOperations.AddString('createOverride');
    SetRange(lNode.range, lDefinition.SourceRange);
    SetRange(lNode.selectionRange, lDefinition.NameRange);
    if (lDefinition.Properties.Count > 0) or
      (lDefinition.Children.Count > 0) then
      lNode.children.Assigned := True;
    for lProperty in lDefinition.Properties do
    begin
      lPropertyNode := TNexusScriptLSNode(lNode.children.AddObject(
        TNexusScriptLSNode));
      lPropertyNode.id.Value := NodeID(ARevision, 'property',
        lProperty.SourceRange);
      lPropertyNode.nodeType.Value := 'property';
      lPropertyNode.name.Value := lProperty.Name;
      lPropertyNode.value.Value := lProperty.Value.Text;
      lPropertyNode.effectiveValue.Value := lProperty.Value.Text;
      lPropertyNode.sourceUri.Value :=
        TNexusScriptLSModel.Current.URIForSourceName(
        lProperty.SourceRange.SourceName);
      lPropertyNode.local.Value := True;
      lPropertyNode.allowedOperations.AddString('rename');
      lPropertyNode.allowedOperations.AddString('setReference');
      lPropertyNode.allowedOperations.AddString('removeProperty');
      lPropertyNode.allowedOperations.AddString('resetOverride');
      SetRange(lPropertyNode.range, lProperty.ValueRange);
      SetRange(lPropertyNode.selectionRange, lProperty.NameRange);
    end;
    AddDefinitionNodes(lDefinition.Children, ARevision, lNode.children);
  end;
end;

function ScalarKindName(AKind: TNSScalarKind): string;
begin
  case AKind of
    nskText: Result := 'text';
    nskInteger: Result := 'integer';
    nskBoolean: Result := 'boolean';
  else
    Result := 'none';
  end;
end;

procedure AddSourceForms(AForms: TNSSourceForms; AResult: TNXJSONStringArray);
begin
  if nsfText in AForms then AResult.AddString('text');
  if nsfArray in AForms then AResult.AddString('array');
  if nsfReference in AForms then AResult.AddString('reference');
  if nsfTextComposition in AForms then AResult.AddString('textComposition');
  if nsfInlineDefinition in AForms then AResult.AddString('inlineDefinition');
end;

function FindDefinitionByOffset(ADefinitions: TNexusScriptSourceDefinitionList;
  AOffset: Integer): TNexusScriptSourceDefinition;
var
  lDefinition: TNexusScriptSourceDefinition;
begin
  Result := nil;
  for lDefinition in ADefinitions do
  begin
    if lDefinition.SourceRange.StartPosition.Offset = AOffset then
      Exit(lDefinition);
    Result := FindDefinitionByOffset(lDefinition.Children, AOffset);
    if Result <> nil then Exit;
  end;
end;

function FindPropertyByOffset(ADefinitions: TNexusScriptSourceDefinitionList;
  AOffset: Integer; out AOwner: TNexusScriptSourceDefinition): TNexusScriptSourceProperty;
var
  lDefinition: TNexusScriptSourceDefinition;
  lProperty: TNexusScriptSourceProperty;
begin
  Result := nil;
  AOwner := nil;
  for lDefinition in ADefinitions do
  begin
    for lProperty in lDefinition.Properties do
      if lProperty.SourceRange.StartPosition.Offset = AOffset then
      begin
        AOwner := lDefinition;
        Exit(lProperty);
      end;
    Result := FindPropertyByOffset(lDefinition.Children, AOffset, AOwner);
    if Result <> nil then Exit;
  end;
end;

function NodeOffset(const ANodeID, ANodeType: string; ARevision: Integer): Integer;
var
  lPrefix: string;
  lCode: Integer;
begin
  lPrefix := IntToStr(ARevision) + ':' + ANodeType + ':';
  if Copy(ANodeID, 1, Length(lPrefix)) <> lPrefix then
    raise Exception.Create('Stale or invalid NexusScript semantic node.');
  Val(Copy(ANodeID, Length(lPrefix) + 1, MaxInt), Result, lCode);
  if lCode <> 0 then
    raise Exception.Create('Invalid NexusScript semantic node identifier.');
end;

procedure AddEdit(AResult: TNXLSWorkspaceEditResult; const AURI: string;
  AVersion: Integer; const ARange: TNexusScriptRange; const AText: string);
var
  lDocumentEdit: TNXLSTextDocumentEdit;
  lEdit: TNXLSTextEdit;
begin
  lDocumentEdit := TNXLSTextDocumentEdit(AResult.documentChanges.AddObject(
    TNXLSTextDocumentEdit));
  lDocumentEdit.textDocument.uri.Value := AURI;
  lDocumentEdit.textDocument.version.Value := AVersion;
  lEdit := TNXLSTextEdit(lDocumentEdit.edits.AddObject(TNXLSTextEdit));
  SetRange(lEdit.range, ARange);
  lEdit.newText.Value := AText;
end;

procedure AddInsertion(AResult: TNXLSWorkspaceEditResult; const AURI: string;
  AVersion: Integer; const APosition: TNexusScriptPosition;
  const AText: string);
var
  lDocumentEdit: TNXLSTextDocumentEdit;
  lEdit: TNXLSTextEdit;
begin
  lDocumentEdit := TNXLSTextDocumentEdit(AResult.documentChanges.AddObject(
    TNXLSTextDocumentEdit));
  lDocumentEdit.textDocument.uri.Value := AURI;
  lDocumentEdit.textDocument.version.Value := AVersion;
  lEdit := TNXLSTextEdit(lDocumentEdit.edits.AddObject(TNXLSTextEdit));
  lEdit.range.start.line.Value := APosition.Line - 1;
  lEdit.range.start.character.Value := APosition.Column - 1;
  lEdit.range.&end.line.Value := APosition.Line - 1;
  lEdit.range.&end.character.Value := APosition.Column - 1;
  lEdit.range.Assigned := True;
  lEdit.newText.Value := AText;
end;

class function TNexusScriptLSDocumentModelRequest.GetFactoryName: string;
begin
  Result := 'nexusscript/documentModel';
end;

function TNexusScriptLSDocumentModelRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lCompiler: TNexusScriptCompiler;
  lDocument: TNexusScriptLSDocument;
  lResult: TNexusScriptLSDocumentModel;
begin
  lResult := TNexusScriptLSDocumentModel(PrepareResult);
  lDocument := TNexusScriptLSModel.Current.FindDocument(
    params.textDocument.uri.Value);
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(
    params.textDocument.uri.Value);
  lResult.uri.Value := params.textDocument.uri.Value;
  if lDocument <> nil then
    lResult.version.Value := lDocument.Version;
  if lAnalysis <> nil then
  begin
    lResult.revision.Value := lAnalysis.Revision;
    lResult.succeeded.Value := lAnalysis.Succeeded;
    lCompiler := lAnalysis.EntrySourceCompiler;
    if (lCompiler <> nil) and (lCompiler.SourceDocument <> nil) then
    begin
      lResult.nodes.Assigned := True;
      AddDefinitionNodes(lCompiler.SourceDocument.Definitions,
        lAnalysis.Revision, lResult.nodes);
    end;
  end;
  Result := lResult;
end;

class function TNexusScriptLSDialectModelRequest.GetFactoryName: string;
begin
  Result := 'nexusscript/dialectModel';
end;

function TNexusScriptLSDialectModelRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lRule: TNSDefinitionRule;
  lChildRule: TNSChildRule;
  lResult: TNexusScriptLSDialectModel;
  lResultRule: TNexusScriptLSDialectRule;
  lIndex: Integer;
  lMemberIndex: Integer;
  lKindIndex: Integer;
  lPropertyResult: TNexusScriptLSDialectPropertyRule;
  lChildResult: TNexusScriptLSDialectChildRule;
  lValueRule: TNSValueRule;
begin
  lResult := TNexusScriptLSDialectModel(PrepareResult);
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(
    params.textDocument.uri.Value);
  if lAnalysis = nil then
    Exit(lResult);
  lResult.revision.Value := lAnalysis.Revision;
  lResult.rules.Assigned := True;
  for lIndex := 0 to lAnalysis.Language.DefinitionRuleCount - 1 do
  begin
    lRule := lAnalysis.Language.DefinitionRules[lIndex];
    lResultRule := TNexusScriptLSDialectRule(lResult.rules.AddObject(
      TNexusScriptLSDialectRule));
    lResultRule.kind.Value := lRule.KindName;
    lResultRule.root.Value := lRule.RootAllowed;
    for lMemberIndex := 0 to lRule.PropertyRuleCount - 1 do
    begin
      lResultRule.properties.AddString(
        lRule.PropertyRules[lMemberIndex].Name);
      lPropertyResult := TNexusScriptLSDialectPropertyRule(
        lResultRule.propertyRules.AddObject(
        TNexusScriptLSDialectPropertyRule));
      lPropertyResult.name.Value := lRule.PropertyRules[lMemberIndex].Name;
      lPropertyResult.required.Value :=
        lRule.PropertyRules[lMemberIndex].Required;
      lValueRule := lRule.PropertyRules[lMemberIndex].ValueRule;
      if lValueRule <> nil then
      begin
        lPropertyResult.scalarKind.Value := ScalarKindName(
          lValueRule.ScalarKind);
        AddSourceForms(lValueRule.SourceForms,
          lPropertyResult.sourceForms);
        for lKindIndex := 0 to lValueRule.AllowedValueCount - 1 do
          lPropertyResult.allowedValues.AddString(
            lValueRule.AllowedValues[lKindIndex]);
        if lValueRule.ReferenceRule <> nil then
          for lKindIndex := 0 to
            lValueRule.ReferenceRule.DefinitionKindCount - 1 do
            lPropertyResult.referenceKinds.AddString(
              lValueRule.ReferenceRule.DefinitionKinds[lKindIndex]);
        if lValueRule.ArrayRule <> nil then
        begin
          for lKindIndex := 0 to lValueRule.ArrayRule.AllowedValueCount - 1 do
            lPropertyResult.arrayValues.AddString(
              lValueRule.ArrayRule.AllowedValues[lKindIndex]);
          for lKindIndex := 0 to
            lValueRule.ArrayRule.DefinitionKindCount - 1 do
            lPropertyResult.arrayDefinitionKinds.AddString(
              lValueRule.ArrayRule.DefinitionKinds[lKindIndex]);
        end;
      end;
    end;
    for lMemberIndex := 0 to lRule.ChildRuleCount - 1 do
    begin
      lChildRule := lRule.ChildRules[lMemberIndex];
      lChildResult := TNexusScriptLSDialectChildRule(
        lResultRule.childRules.AddObject(TNexusScriptLSDialectChildRule));
      lChildResult.name.Value := lChildRule.Name;
      lChildResult.minimum.Value := lChildRule.Minimum;
      lChildResult.maximum.Value := lChildRule.Maximum;
      for lKindIndex := 0 to lChildRule.KindCount - 1 do
      begin
        lResultRule.children.AddString(lChildRule.Kinds[lKindIndex]);
        lChildResult.kinds.AddString(lChildRule.Kinds[lKindIndex]);
      end;
    end;
  end;
  Result := lResult;
end;

class function TNexusScriptLSSetTargetsRequest.GetFactoryName: string;
begin
  Result := 'nexusscript/setTargets';
end;

class function TNexusScriptLSSetTargetsRequest.GetResultKind:
  TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNexusScriptLSSetTargetsRequest.Execute: TNXJSONRPCValue;
var
  lSelection: TNexusScriptTargetSelection;
  lTarget: TNexusScriptLSTarget;
  lIndex: Integer;
begin
  lSelection := TNexusScriptTargetSelection.Create;
  try
    for lIndex := 0 to params.targets.Count - 1 do
    begin
      lTarget := TNexusScriptLSTarget(params.targets[lIndex]);
      lSelection.Add(lTarget.kind.Value, lTarget.value.Value);
    end;
    TNexusScriptLSModel.Current.SetTargets(lSelection);
  finally
    lSelection.Free;
  end;
  Result := PrepareResult;
end;

class function TNexusScriptLSSemanticEditRequest.GetFactoryName: string;
begin
  Result := 'nexusscript/semanticEdit';
end;

function TNexusScriptLSSemanticEditRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lCompiler: TNexusScriptCompiler;
  lDocument: TNexusScriptLSDocument;
  lDefinition: TNexusScriptSourceDefinition;
  lOwner: TNexusScriptSourceDefinition;
  lProperty: TNexusScriptSourceProperty;
  lOffset: Integer;
  lText: string;
begin
  lDocument := TNexusScriptLSModel.Current.FindDocument(
    params.textDocument.uri.Value);
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(
    params.textDocument.uri.Value);
  if (lDocument = nil) or (lAnalysis = nil) or
    (params.version.Value <> lDocument.Version) or
    (params.revision.Value <> lAnalysis.Revision) then
    raise Exception.Create('Stale NexusScript semantic edit request.');
  lCompiler := lAnalysis.EntrySourceCompiler;
  if (lCompiler = nil) or (lCompiler.SourceDocument = nil) then
    raise Exception.Create('No NexusScript source model is available.');
  Result := PrepareResult;

  if (params.operation.Value = 'rename') or
    (params.operation.Value = 'removeProperty') or
    (params.operation.Value = 'setReference') or
    (params.operation.Value = 'resetOverride') then
  begin
    lOffset := NodeOffset(params.nodeId.Value, 'property', lAnalysis.Revision);
    lProperty := FindPropertyByOffset(lCompiler.SourceDocument.Definitions,
      lOffset, lOwner);
    if lProperty = nil then
      raise Exception.Create('NexusScript property node was not found.');
    if params.operation.Value = 'rename' then
      AddEdit(TNXLSWorkspaceEditResult(Result), lDocument.URI,
        lDocument.Version, lProperty.NameRange, params.name.Value)
    else if (params.operation.Value = 'removeProperty') or
      (params.operation.Value = 'resetOverride') then
      AddEdit(TNXLSWorkspaceEditResult(Result), lDocument.URI,
        lDocument.Version, lProperty.SourceRange, '')
    else
      AddEdit(TNXLSWorkspaceEditResult(Result), lDocument.URI,
        lDocument.Version, lProperty.ValueRange, '@' + params.value.Value);
    Exit;
  end;

  lOffset := NodeOffset(params.nodeId.Value, 'definition', lAnalysis.Revision);
  lDefinition := FindDefinitionByOffset(lCompiler.SourceDocument.Definitions,
    lOffset);
  if lDefinition = nil then
    raise Exception.Create('NexusScript definition node was not found.');
  if params.operation.Value = 'rename' then
    AddEdit(TNXLSWorkspaceEditResult(Result), lDocument.URI,
      lDocument.Version, lDefinition.NameRange, params.name.Value)
  else if (params.operation.Value = 'removeChild') or
    (params.operation.Value = 'resetOverride') then
    AddEdit(TNXLSWorkspaceEditResult(Result), lDocument.URI,
      lDocument.Version, lDefinition.SourceRange, '')
  else if (params.operation.Value = 'setProperty') or
    (params.operation.Value = 'createOverride') then
  begin
    lProperty := lDefinition.FindProperty(params.name.Value);
    if lProperty <> nil then
      AddEdit(TNXLSWorkspaceEditResult(Result), lDocument.URI,
        lDocument.Version, lProperty.ValueRange, params.value.Value)
    else
    begin
      lText := ' ' + params.name.Value + ': ' + params.value.Value + ';';
      AddInsertion(TNXLSWorkspaceEditResult(Result), lDocument.URI,
        lDocument.Version, lDefinition.BodyEndRange.StartPosition, lText);
    end;
  end
  else if params.operation.Value = 'addChild' then
  begin
    lText := ' ' + params.kind.Value + ' ' + params.name.Value + ' {}';
    AddInsertion(TNXLSWorkspaceEditResult(Result), lDocument.URI,
      lDocument.Version, lDefinition.BodyEndRange.StartPosition, lText);
  end
  else
    raise Exception.Create('Unsupported NexusScript semantic operation: ' +
      params.operation.Value);
end;

function TNexusScriptLSDocumentModelRequest.GetParams:
  TNXLSDocumentLinkParams;
begin
  Result := TNXLSDocumentLinkParams(inherited params);
end;

procedure TNexusScriptLSDocumentModelRequest.SetParams(
  AValue: TNXLSDocumentLinkParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSDocumentModelRequest.GetResult:
  TNexusScriptLSDocumentModel;
begin
  Result := TNexusScriptLSDocumentModel(inherited result);
end;

procedure TNexusScriptLSDocumentModelRequest.SetResult(
  AValue: TNexusScriptLSDocumentModel);
begin
  inherited result := AValue;
end;

function TNexusScriptLSDialectModelRequest.GetParams:
  TNXLSDocumentLinkParams;
begin
  Result := TNXLSDocumentLinkParams(inherited params);
end;

procedure TNexusScriptLSDialectModelRequest.SetParams(
  AValue: TNXLSDocumentLinkParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSDialectModelRequest.GetResult:
  TNexusScriptLSDialectModel;
begin
  Result := TNexusScriptLSDialectModel(inherited result);
end;

procedure TNexusScriptLSDialectModelRequest.SetResult(
  AValue: TNexusScriptLSDialectModel);
begin
  inherited result := AValue;
end;

function TNexusScriptLSSetTargetsRequest.GetParams:
  TNexusScriptLSSetTargetsParams;
begin
  Result := TNexusScriptLSSetTargetsParams(inherited params);
end;

procedure TNexusScriptLSSetTargetsRequest.SetParams(
  AValue: TNexusScriptLSSetTargetsParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSSemanticEditRequest.GetParams:
  TNexusScriptLSSemanticEditParams;
begin Result := TNexusScriptLSSemanticEditParams(inherited params); end;
procedure TNexusScriptLSSemanticEditRequest.SetParams(
  AValue: TNexusScriptLSSemanticEditParams);
begin inherited params := AValue; end;
function TNexusScriptLSSemanticEditRequest.GetResult: TNXLSWorkspaceEditResult;
begin Result := TNXLSWorkspaceEditResult(inherited result); end;
procedure TNexusScriptLSSemanticEditRequest.SetResult(
  AValue: TNXLSWorkspaceEditResult);
begin inherited result := AValue; end;

initialization
  TNXClassFactory.RegisterClass(TNexusScriptLSDocumentModelRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSDialectModelRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSSetTargetsRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSSemanticEditRequest);

end.
