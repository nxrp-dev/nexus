unit obNexusScriptLSReferences;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages, obNXJSONRPCObjects, obNXLSProtocolBase, obNXLSProtocolParams,
  obNXLSProtocolObjects;

type
  TNexusScriptLSReferencesRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSReferenceParams;
    procedure SetParams(AValue: TNXLSReferenceParams);
    function GetResult: TNXLSLocationArray;
    procedure SetResult(AValue: TNXLSLocationArray);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSReferenceParams read GetParams write SetParams;
    property result: TNXLSLocationArray read GetResult write SetResult;
  end;

  TNexusScriptLSDocumentHighlightRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
    function GetResult: TNXLSDocumentHighlightArray;
    procedure SetResult(AValue: TNXLSDocumentHighlightArray);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
    property result: TNXLSDocumentHighlightArray read GetResult write SetResult;
  end;

  TNexusScriptLSRenameRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSRenameParams;
    procedure SetParams(AValue: TNXLSRenameParams);
    function GetResult: TNXLSWorkspaceEditResult;
    procedure SetResult(AValue: TNXLSWorkspaceEditResult);
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSRenameParams read GetParams write SetParams;
    property result: TNXLSWorkspaceEditResult read GetResult write SetResult;
  end;

implementation

uses
  Classes, SysUtils, obNXClassFactory, obNXJSONValues,
  tpNexusScript, obNexusScriptModel, obNexusScriptAnalysis,
  obNexusScriptLSModel, obNexusScriptLSSemantics;

procedure SetRange(ADestination: TNXLSRange; const ASource: TNexusScriptRange);
begin
  ADestination.start.line.Value := ASource.StartPosition.Line - 1;
  ADestination.start.character.Value := ASource.StartPosition.Column - 1;
  ADestination.&end.line.Value := ASource.EndPosition.Line - 1;
  ADestination.&end.character.Value := ASource.EndPosition.Column;
  ADestination.Assigned := True;
end;

function SameRange(const ALeft, ARight: TNexusScriptRange): Boolean;
begin
  Result := (ALeft.SourceName = ARight.SourceName) and
    (ALeft.StartPosition.Offset = ARight.StartPosition.Offset) and
    (ALeft.EndPosition.Offset = ARight.EndPosition.Offset);
end;

function DefinitionRange(ADefinition: TNexusScriptCompiledDefinition): TNexusScriptRange;
begin
  Result := ADefinition.SourceRange;
  if ADefinition.SourceDefinition <> nil then
    Result := ADefinition.SourceDefinition.NameRange;
end;

function TargetAt(AAnalysis: TNexusScriptAnalysis; ALine, AColumn: Integer;
  out ATarget: TNexusScriptRange): Boolean;
var
  lValue: TNexusScriptCompiledValue;
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := False;
  lValue := NXScriptFindValueAt(AAnalysis.EntryCompiler.CompiledDocument,
    ALine, AColumn);
  if (lValue <> nil) and (lValue.ResolvedDefinition <> nil) then
  begin
    ATarget := DefinitionRange(lValue.ResolvedDefinition);
    Exit(True);
  end;
  lDefinition := NXScriptFindDefinitionAt(
    AAnalysis.EntryCompiler.CompiledDocument, ALine, AColumn);
  if lDefinition <> nil then
  begin
    ATarget := DefinitionRange(lDefinition);
    Result := NXScriptRangeContains(ATarget, ALine, AColumn);
  end;
end;

procedure CollectDefinitionReferences(ADefinition: TNexusScriptCompiledDefinition;
  const ATarget: TNexusScriptRange; ARanges: TNexusScriptRangeList); forward;

procedure CollectValueReferences(AValue: TNexusScriptCompiledValue;
  const ATarget: TNexusScriptRange; ARanges: TNexusScriptRangeList);
var
  lItem: TNexusScriptCompiledValue;
begin
  if (AValue.ResolvedDefinition <> nil) and
    SameRange(DefinitionRange(AValue.ResolvedDefinition), ATarget) and
    (AValue.ReferenceRanges.Count > 0) then
    ARanges.Add(AValue.ReferenceRanges[AValue.ReferenceRanges.Count - 1]);
  for lItem in AValue.Items do
    CollectValueReferences(lItem, ATarget, ARanges);
  if AValue.StructuralDefinition <> nil then
    CollectDefinitionReferences(AValue.StructuralDefinition, ATarget, ARanges);
end;

procedure CollectDefinitionReferences(ADefinition: TNexusScriptCompiledDefinition;
  const ATarget: TNexusScriptRange; ARanges: TNexusScriptRangeList);
var
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  for lProperty in ADefinition.Properties do
    CollectValueReferences(lProperty.Value, ATarget, ARanges);
  for lChild in ADefinition.Children do
    CollectDefinitionReferences(lChild, ATarget, ARanges);
end;

procedure CollectReferences(AAnalysis: TNexusScriptAnalysis;
  const ATarget: TNexusScriptRange; AIncludeDeclaration: Boolean;
  ARanges: TNexusScriptRangeList);
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  if AIncludeDeclaration then ARanges.Add(ATarget);
  for lDefinition in AAnalysis.EntryCompiler.CompiledDocument.Definitions do
    CollectDefinitionReferences(lDefinition, ATarget, ARanges);
end;

function RangeKey(const ARange: TNexusScriptRange): string;
begin
  Result := ARange.SourceName + ':' + IntToStr(ARange.StartPosition.Offset) +
    ':' + IntToStr(ARange.EndPosition.Offset);
end;

procedure AddLocation(AResult: TNXLSLocationArray; ASeen: TStringList;
  const ARange: TNexusScriptRange);
var lLocation: TNXLSLocation;
begin
  if ASeen.IndexOf(RangeKey(ARange)) >= 0 then Exit;
  ASeen.Add(RangeKey(ARange));
  lLocation := TNXLSLocation(AResult.AddObject(TNXLSLocation));
  lLocation.uri.Value := TNexusScriptLSModel.Current.URIForSourceName(
    ARange.SourceName);
  SetRange(lLocation.range, ARange);
end;

function DocumentEditFor(AResult: TNXLSWorkspaceEditResult;
  const AURI: string): TNXLSTextDocumentEdit;
var
  lIndex: Integer;
begin
  for lIndex := 0 to AResult.documentChanges.Count - 1 do
  begin
    Result := TNXLSTextDocumentEdit(AResult.documentChanges[lIndex]);
    if Result.textDocument.uri.Value = AURI then Exit;
  end;
  Result := TNXLSTextDocumentEdit(AResult.documentChanges.AddObject(
    TNXLSTextDocumentEdit));
  Result.textDocument.uri.Value := AURI;
end;

class function TNexusScriptLSReferencesRequest.GetFactoryName: string;
begin Result := 'textDocument/references'; end;

function TNexusScriptLSReferencesRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lTarget, lRange: TNexusScriptRange;
  lRanges: TNexusScriptRangeList;
  lSeen: TStringList;
  lIndex: Integer;
begin
  Result := PrepareResult;
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(params.textDocument.uri.Value);
  if (lAnalysis = nil) or (lAnalysis.EntryCompiler = nil) or
    not TargetAt(lAnalysis, params.position.line.Value + 1,
      params.position.character.Value + 1, lTarget) then Exit;
  lRanges := TNexusScriptRangeList.Create;
  lSeen := TStringList.Create;
  try
    if params.context.includeDeclaration.Value then lRanges.Add(lTarget);
    for lIndex := 0 to TNexusScriptLSModel.Current.AnalysisCount - 1 do
      if TNexusScriptLSModel.Current.Analyses(lIndex).EntryCompiler <> nil then
        CollectReferences(TNexusScriptLSModel.Current.Analyses(lIndex),
          lTarget, False, lRanges);
    for lRange in lRanges do AddLocation(TNXLSLocationArray(Result), lSeen, lRange);
  finally lSeen.Free; lRanges.Free; end;
end;

class function TNexusScriptLSDocumentHighlightRequest.GetFactoryName: string;
begin Result := 'textDocument/documentHighlight'; end;

function TNexusScriptLSDocumentHighlightRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lTarget, lRange: TNexusScriptRange;
  lRanges: TNexusScriptRangeList;
  lItem: TNXLSDocumentHighlight;
  lIndex: Integer;
begin
  Result := PrepareResult;
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(params.textDocument.uri.Value);
  if (lAnalysis = nil) or (lAnalysis.EntryCompiler = nil) or
    not TargetAt(lAnalysis, params.position.line.Value + 1,
      params.position.character.Value + 1, lTarget) then Exit;
  lRanges := TNexusScriptRangeList.Create;
  try
    lRanges.Add(lTarget);
    for lIndex := 0 to TNexusScriptLSModel.Current.AnalysisCount - 1 do
      if TNexusScriptLSModel.Current.Analyses(lIndex).EntryCompiler <> nil then
        CollectReferences(TNexusScriptLSModel.Current.Analyses(lIndex),
          lTarget, False, lRanges);
    for lRange in lRanges do
      if lRange.SourceName = lTarget.SourceName then
      begin
        lItem := TNXLSDocumentHighlight(
          TNXLSDocumentHighlightArray(Result).AddObject(TNXLSDocumentHighlight));
        SetRange(lItem.range, lRange);
        lItem.kind.Value := 1;
      end;
  finally lRanges.Free; end;
end;

class function TNexusScriptLSRenameRequest.GetFactoryName: string;
begin Result := 'textDocument/rename'; end;
class function TNexusScriptLSRenameRequest.GetResultKind: TNXJSONRPCResultKind;
begin Result := rkNullableConcreteResult; end;

function TNexusScriptLSRenameRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lTarget, lRange: TNexusScriptRange;
  lRanges: TNexusScriptRangeList;
  lDocumentEdit: TNXLSTextDocumentEdit;
  lEdit: TNXLSTextEdit;
  lIndex: Integer;
  lSeen: TStringList;
  lURI: string;
begin
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(params.textDocument.uri.Value);
  if (lAnalysis = nil) or (lAnalysis.EntryCompiler = nil) or
    (params.newName.Value = '') or
    not TargetAt(lAnalysis, params.position.line.Value + 1,
      params.position.character.Value + 1, lTarget) then
    Exit(TNXJSONNull.Create);
  Result := PrepareResult;
  lRanges := TNexusScriptRangeList.Create;
  lSeen := TStringList.Create;
  try
    lRanges.Add(lTarget);
    for lIndex := 0 to TNexusScriptLSModel.Current.AnalysisCount - 1 do
      if TNexusScriptLSModel.Current.Analyses(lIndex).EntryCompiler <> nil then
        CollectReferences(TNexusScriptLSModel.Current.Analyses(lIndex),
          lTarget, False, lRanges);
    for lRange in lRanges do
    begin
      if lSeen.IndexOf(RangeKey(lRange)) >= 0 then Continue;
      lSeen.Add(RangeKey(lRange));
      lURI := TNexusScriptLSModel.Current.URIForSourceName(lRange.SourceName);
      lDocumentEdit := DocumentEditFor(TNXLSWorkspaceEditResult(Result), lURI);
      lEdit := TNXLSTextEdit(lDocumentEdit.edits.AddObject(TNXLSTextEdit));
      SetRange(lEdit.range, lRange);
      lEdit.newText.Value := params.newName.Value;
    end;
  finally lSeen.Free; lRanges.Free; end;
end;

function TNexusScriptLSReferencesRequest.GetParams: TNXLSReferenceParams;
begin Result := TNXLSReferenceParams(inherited params); end;
procedure TNexusScriptLSReferencesRequest.SetParams(AValue: TNXLSReferenceParams);
begin inherited params := AValue; end;
function TNexusScriptLSReferencesRequest.GetResult: TNXLSLocationArray;
begin Result := TNXLSLocationArray(inherited result); end;
procedure TNexusScriptLSReferencesRequest.SetResult(AValue: TNXLSLocationArray);
begin inherited result := AValue; end;
function TNexusScriptLSDocumentHighlightRequest.GetParams: TNXLSTextDocumentPositionParams;
begin Result := TNXLSTextDocumentPositionParams(inherited params); end;
procedure TNexusScriptLSDocumentHighlightRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin inherited params := AValue; end;
function TNexusScriptLSDocumentHighlightRequest.GetResult: TNXLSDocumentHighlightArray;
begin Result := TNXLSDocumentHighlightArray(inherited result); end;
procedure TNexusScriptLSDocumentHighlightRequest.SetResult(AValue: TNXLSDocumentHighlightArray);
begin inherited result := AValue; end;
function TNexusScriptLSRenameRequest.GetParams: TNXLSRenameParams;
begin Result := TNXLSRenameParams(inherited params); end;
procedure TNexusScriptLSRenameRequest.SetParams(AValue: TNXLSRenameParams);
begin inherited params := AValue; end;
function TNexusScriptLSRenameRequest.GetResult: TNXLSWorkspaceEditResult;
begin Result := TNXLSWorkspaceEditResult(inherited result); end;
procedure TNexusScriptLSRenameRequest.SetResult(AValue: TNXLSWorkspaceEditResult);
begin inherited result := AValue; end;

initialization
  TNXClassFactory.RegisterClass(TNexusScriptLSReferencesRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSDocumentHighlightRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSRenameRequest);

end.
