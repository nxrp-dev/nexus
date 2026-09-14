unit obNexusScriptLSNavigation;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolObjects;

type
  TNexusScriptLSDefinitionRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
    function GetResult: TNXLSLocation;
    procedure SetResult(AValue: TNXLSLocation);
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
    property result: TNXLSLocation read GetResult write SetResult;
  end;

  TNexusScriptLSHoverRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
    function GetResult: TNXLSHover;
    procedure SetResult(AValue: TNXLSHover);
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
    property result: TNXLSHover read GetResult write SetResult;
  end;

implementation

uses
  SysUtils,
  obNXClassFactory,
  obNXJSONValues,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptCompiler,
  obNexusScriptSession,
  obNexusScriptAnalysis,
  obNexusScriptLSModel,
  obNexusScriptLSSemantics;

function FirstDocumentRange(ACompiler: TNexusScriptCompiler): TNexusScriptRange;
begin
  Result := Default(TNexusScriptRange);
  if (ACompiler <> nil) and (ACompiler.SourceDocument <> nil) and
    (ACompiler.SourceDocument.Definitions.Count > 0) then
    Result := ACompiler.SourceDocument.Definitions[0].NameRange
  else if (ACompiler <> nil) and (ACompiler.SourceDocument <> nil) then
    Result.SourceName := ACompiler.SourceDocument.SourceName;
end;

function CompositionTargetAt(ADefinitions: TNexusScriptSourceDefinitionList;
  ALine, AColumn: Integer; out ARange: TNexusScriptRange): Boolean;
var
  lDefinition: TNexusScriptSourceDefinition;
  lIndex: Integer;
begin
  Result := False;
  for lDefinition in ADefinitions do
  begin
    for lIndex := 0 to lDefinition.CompositionSelectorRanges.Count - 1 do
      if NXScriptRangeContains(lDefinition.CompositionSelectorRanges[lIndex],
        ALine, AColumn) and
        (lIndex < lDefinition.CompositionTargetRanges.Count) and
        (lDefinition.CompositionTargetRanges[lIndex].SourceName <> '') then
      begin
        ARange := lDefinition.CompositionTargetRanges[lIndex];
        Exit(True);
      end;
    if CompositionTargetAt(lDefinition.Children, ALine, AColumn, ARange) then
      Exit(True);
  end;
end;

function DependencyTargetAt(AAnalysis: TNexusScriptAnalysis;
  ALine, AColumn: Integer; out ARange: TNexusScriptRange): Boolean;
var
  lSource: TNexusScriptSourceDocument;
  lModule: TNexusScriptSourceModule;
  lInclude: TNexusScriptSourceInclude;
  lCompiler: TNexusScriptCompiler;
  lName: string;
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := False;
  if (AAnalysis.EntrySourceCompiler = nil) or
    (AAnalysis.EntrySourceCompiler.SourceDocument = nil) then
    Exit;
  lSource := AAnalysis.EntrySourceCompiler.SourceDocument;
  if CompositionTargetAt(lSource.Definitions, ALine, AColumn, ARange) then
    Exit(True);
  if (lSource.Dialect <> nil) and
    NXScriptRangeContains(lSource.Dialect.PathRange, ALine, AColumn) then
  begin
    lName := AAnalysis.Session.ResolveDialectPath(lSource.SourceName,
      lSource.Dialect.Path);
    ARange := FirstDocumentRange(AAnalysis.Session.FindCompiler(lName));
    Exit(ARange.SourceName <> '');
  end;
  for lModule in lSource.Modules do
    if NXScriptRangeContains(lModule.PathRange, ALine, AColumn) or
      NXScriptRangeContains(lModule.RootSelectorRange, ALine, AColumn) then
    begin
      lName := AAnalysis.Session.ResolveDependencyPath(lSource.SourceName,
        lModule.Path);
      lCompiler := AAnalysis.Session.FindCompiler(lName);
      if (lCompiler <> nil) and (lModule.RootSelector <> '') and
        NXScriptRangeContains(lModule.RootSelectorRange, ALine, AColumn) then
      begin
        lDefinition := lCompiler.CompiledDocument.FindDefinition(
          lModule.RootSelector);
        if lDefinition <> nil then
        begin
          ARange := lDefinition.SourceRange;
          if lDefinition.SourceDefinition <> nil then
            ARange := lDefinition.SourceDefinition.NameRange;
          Exit(True);
        end;
      end;
      ARange := FirstDocumentRange(lCompiler);
      Exit(ARange.SourceName <> '');
    end;
  for lInclude in lSource.Includes do
    if NXScriptRangeContains(lInclude.PathRange, ALine, AColumn) then
    begin
      lName := AAnalysis.Session.ResolveDependencyPath(lSource.SourceName,
        lInclude.Path);
      ARange := FirstDocumentRange(AAnalysis.Session.FindCompiler(lName));
      Exit(ARange.SourceName <> '');
    end;
end;

procedure SetRange(ADestination: TNXLSRange;
  const ASource: TNexusScriptRange);
begin
  ADestination.start.line.Value := ASource.StartPosition.Line - 1;
  ADestination.start.character.Value := ASource.StartPosition.Column - 1;
  ADestination.&end.line.Value := ASource.EndPosition.Line - 1;
  ADestination.&end.character.Value := ASource.EndPosition.Column;
  ADestination.Assigned := True;
end;

function TargetRange(AValue: TNexusScriptCompiledValue;
  out ARange: TNexusScriptRange): Boolean;
begin
  Result := False;
  if AValue.ResolvedDefinition <> nil then
  begin
    ARange := AValue.ResolvedDefinition.SourceRange;
    if AValue.ResolvedDefinition.SourceDefinition <> nil then
      ARange := AValue.ResolvedDefinition.SourceDefinition.NameRange;
    Exit(True);
  end;
  if AValue.ResolvedProperty <> nil then
  begin
    ARange := AValue.ResolvedProperty.SourceRange;
    Exit(True);
  end;
end;

function PropertyAt(ADefinitions: TNexusScriptCompiledDefinitionList;
  ALine, AColumn: Integer): TNexusScriptCompiledProperty;
var
  lDefinition: TNexusScriptCompiledDefinition;
  lProperty: TNexusScriptCompiledProperty;
begin
  Result := nil;
  for lDefinition in ADefinitions do
  begin
    for lProperty in lDefinition.Properties do
      if NXScriptRangeContains(lProperty.Value.SourceRange,
        ALine, AColumn) then
        Exit(lProperty);
    Result := PropertyAt(lDefinition.Children, ALine, AColumn);
    if Result <> nil then
      Exit;
  end;
end;

function EffectiveText(AValue: TNexusScriptCompiledValue): string;
begin
  if AValue.HasEffectiveText then
    Exit(AValue.EffectiveText);
  Result := AValue.SourceText;
end;

function SourceDescription(const ARange: TNexusScriptRange): string;
begin
  Result := TNexusScriptLSModel.Current.URIForSourceName(ARange.SourceName) +
    ':' + IntToStr(ARange.StartPosition.Line);
end;

function TargetsDescription(ADefinition: TNexusScriptCompiledDefinition): string;
var
  lTarget: TNexusScriptTarget;
  lValue: string;
begin
  Result := '';
  for lTarget in ADefinition.Targets do
    for lValue in lTarget.Values do
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + lTarget.Name + '=' + lValue;
    end;
end;

function SourceTargetsDescription(
  ADefinition: TNexusScriptSourceDefinition): string;
var
  lTarget: TNexusScriptTarget;
  lValue: string;
begin
  Result := '';
  for lTarget in ADefinition.Targets do
    for lValue in lTarget.Values do
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + lTarget.Name + '=' + lValue;
    end;
end;

function SourceDefinitionAt(ADefinitions: TNexusScriptSourceDefinitionList;
  ALine, AColumn: Integer): TNexusScriptSourceDefinition;
var
  lDefinition: TNexusScriptSourceDefinition;
begin
  Result := nil;
  for lDefinition in ADefinitions do
  begin
    Result := SourceDefinitionAt(lDefinition.Children, ALine, AColumn);
    if Result <> nil then
      Exit;
    if NXScriptRangeContains(lDefinition.SourceRange, ALine, AColumn) then
      Exit(lDefinition);
  end;
end;

class function TNexusScriptLSDefinitionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/definition';
end;

class function TNexusScriptLSDefinitionRequest.GetResultKind:
  TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNexusScriptLSDefinitionRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lValue: TNexusScriptCompiledValue;
  lRange: TNexusScriptRange;
  lResult: TNXLSLocation;
begin
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(
    params.textDocument.uri.Value);
  if (lAnalysis = nil) or (lAnalysis.EntryCompiler = nil) then
    Exit(TNXJSONNull.Create);
  if DependencyTargetAt(lAnalysis, params.position.line.Value + 1,
    params.position.character.Value + 1, lRange) then
  begin
    lResult := TNXLSLocation(PrepareResult);
    lResult.uri.Value := TNexusScriptLSModel.Current.URIForSourceName(
      lRange.SourceName);
    SetRange(lResult.range, lRange);
    Exit(lResult);
  end;
  lValue := NXScriptFindValueAt(lAnalysis.EntryCompiler.CompiledDocument,
    params.position.line.Value + 1, params.position.character.Value + 1);
  if (lValue = nil) or not TargetRange(lValue, lRange) then
    Exit(TNXJSONNull.Create);
  lResult := TNXLSLocation(PrepareResult);
  lResult.uri.Value := TNexusScriptLSModel.Current.URIForSourceName(
    lRange.SourceName);
  SetRange(lResult.range, lRange);
  Result := lResult;
end;

class function TNexusScriptLSHoverRequest.GetFactoryName: string;
begin
  Result := 'textDocument/hover';
end;

class function TNexusScriptLSHoverRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNexusScriptLSHoverRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lValue: TNexusScriptCompiledValue;
  lDefinition: TNexusScriptCompiledDefinition;
  lSourceDefinition: TNexusScriptSourceDefinition;
  lProperty: TNexusScriptCompiledProperty;
  lResult: TNXLSHover;
  lText: string;
  lTargets: string;
begin
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(
    params.textDocument.uri.Value);
  if (lAnalysis = nil) or (lAnalysis.EntryCompiler = nil) then
    Exit(TNXJSONNull.Create);
  lProperty := PropertyAt(lAnalysis.EntryCompiler.CompiledDocument.Definitions,
    params.position.line.Value + 1, params.position.character.Value + 1);
  lValue := NXScriptFindValueAt(lAnalysis.EntryCompiler.CompiledDocument,
    params.position.line.Value + 1, params.position.character.Value + 1);
  if lProperty <> nil then
  begin
    lText := 'Property ' + lProperty.Name + LineEnding +
      'Effective: ' + EffectiveText(lProperty.Value) + LineEnding +
      'Local: ' + BoolToStr(lProperty.SourceRange.SourceName =
        lAnalysis.EntryCompiler.CompiledDocument.SourceName, True) +
        LineEnding +
      'Source: ' + SourceDescription(lProperty.SourceRange);
    if lProperty.ContributorRanges.Count > 1 then
      lText := lText + LineEnding + 'Contributors: ' +
        IntToStr(lProperty.ContributorRanges.Count);
    if (lValue <> nil) and (lValue.ResolvedDefinition <> nil) then
      lText := lText + LineEnding + 'Resolves to: ' +
        lValue.ResolvedDefinition.Kind + ' ' +
        lValue.ResolvedDefinition.Name
    else if (lValue <> nil) and (lValue.ResolvedProperty <> nil) then
      lText := lText + LineEnding + 'Resolves to property: ' +
        lValue.ResolvedProperty.Name;
  end
  else
  begin
    lDefinition := NXScriptFindDefinitionAt(
      lAnalysis.EntryCompiler.CompiledDocument,
      params.position.line.Value + 1, params.position.character.Value + 1);
    if lDefinition <> nil then
    begin
      lText := lDefinition.Kind + ' ' + lDefinition.Name + LineEnding +
        'Applicable: True' + LineEnding +
        'Local: ' + BoolToStr(lDefinition.SourceRange.SourceName =
          lAnalysis.EntryCompiler.CompiledDocument.SourceName, True) +
          LineEnding + 'Source: ' +
          SourceDescription(lDefinition.SourceRange);
      lTargets := TargetsDescription(lDefinition);
    end
    else
    begin
      lSourceDefinition := SourceDefinitionAt(
        lAnalysis.EntrySourceCompiler.SourceDocument.Definitions,
        params.position.line.Value + 1,
        params.position.character.Value + 1);
      if lSourceDefinition = nil then
        Exit(TNXJSONNull.Create);
      lText := lSourceDefinition.Kind + ' ' + lSourceDefinition.Name +
        LineEnding + 'Applicable: False' + LineEnding + 'Local: True' +
        LineEnding + 'Source: ' +
        SourceDescription(lSourceDefinition.SourceRange);
      lTargets := SourceTargetsDescription(lSourceDefinition);
    end;
    if lTargets <> '' then
      lText := lText + LineEnding + 'Targets: ' + lTargets;
  end;
  lResult := TNXLSHover(PrepareResult);
  lResult.contents.kind.Value := 'plaintext';
  lResult.contents.value.Value := lText;
  lResult.Assigned := True;
  Result := lResult;
end;

function TNexusScriptLSDefinitionRequest.GetParams:
  TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNexusScriptLSDefinitionRequest.SetParams(
  AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSDefinitionRequest.GetResult: TNXLSLocation;
begin
  Result := TNXLSLocation(inherited result);
end;

procedure TNexusScriptLSDefinitionRequest.SetResult(AValue: TNXLSLocation);
begin
  inherited result := AValue;
end;

function TNexusScriptLSHoverRequest.GetParams:
  TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNexusScriptLSHoverRequest.SetParams(
  AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSHoverRequest.GetResult: TNXLSHover;
begin
  Result := TNXLSHover(inherited result);
end;

procedure TNexusScriptLSHoverRequest.SetResult(AValue: TNXLSHover);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNexusScriptLSDefinitionRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSHoverRequest);

end.
