unit obNexusScriptJSON;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  fpjson,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptDefinitionView,
  obNexusScriptArtifactModel;

type
  ENexusScriptJSON = class(Exception);

  TNexusScriptJSONEmitter = class
  private
    FRoot: TJSONObject;
    FRootNames: TStringList;
    FCollectedNames: TStringList;
    FCollections: TJSONObject;
    function DefinitionMetadata(
      ADefinition: TNexusScriptCompiledDefinition;
      AReferenceValue: TNexusScriptCompiledValue):
      TNexusScriptArtifactMetadata;
    function DefinitionJSON(
      ADefinition: TNexusScriptCompiledDefinition;
      AReferenceValue: TNexusScriptCompiledValue = nil): TJSONObject;
    function ValueJSON(AValue: TNexusScriptCompiledValue;
      AArrayItem: Boolean): TJSONData;
    function ArrayJSON(AValue: TNexusScriptCompiledValue): TJSONArray;
    function ArrayItemJSON(AValue: TNexusScriptCompiledValue): TJSONData;
    function NamedValueJSON(const AName: string;
      AValue: TJSONData): TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddDocument(ADocument: TNexusScriptCompiledDocument);
    function JSON: string;
  end;

implementation

function TNexusScriptJSONEmitter.DefinitionMetadata(
  ADefinition: TNexusScriptCompiledDefinition;
  AReferenceValue: TNexusScriptCompiledValue):
  TNexusScriptArtifactMetadata;
var
  lIsReference: Boolean;
  lTarget: TNexusScriptTarget;
  lArtifactTarget: TNexusScriptArtifactTarget;
  lValue: string;
begin
  Result := TNexusScriptArtifactMetadata.Create;
  try
    Result.Kind.Value := ADefinition.Kind;
    Result.Name.Value := ADefinition.Name;
    lIsReference := (AReferenceValue <> nil) and
      (AReferenceValue.Kind = nsvReference);
    Result.IsReference.Value := lIsReference;
    Result.SourceRange.SourceName.Value := ADefinition.SourceRange.SourceName;
    Result.SourceRange.StartPosition.Offset.Value :=
      ADefinition.SourceRange.StartPosition.Offset;
    Result.SourceRange.StartPosition.Line.Value :=
      ADefinition.SourceRange.StartPosition.Line;
    Result.SourceRange.StartPosition.Column.Value :=
      ADefinition.SourceRange.StartPosition.Column;
    Result.SourceRange.EndPosition.Offset.Value :=
      ADefinition.SourceRange.EndPosition.Offset;
    Result.SourceRange.EndPosition.Line.Value :=
      ADefinition.SourceRange.EndPosition.Line;
    Result.SourceRange.EndPosition.Column.Value :=
      ADefinition.SourceRange.EndPosition.Column;
    if lIsReference then
    begin
      if AReferenceValue.OriginalDefinitionName = '' then
        raise ENexusScriptJSON.CreateFmt(
          'Structural reference %s has no resolved target name.',
          [AReferenceValue.SourceText]);
      Result.Reference.Kind.Value := ADefinition.Kind;
      Result.Reference.Name.Value := AReferenceValue.OriginalDefinitionName;
    end;
    for lTarget in ADefinition.Targets do
    begin
      lArtifactTarget := Result.Targets.AddTarget;
      lArtifactTarget.Name.Value := lTarget.Name;
      for lValue in lTarget.Values do
        lArtifactTarget.Values.AddString(lValue);
    end;
  except
    Result.Free;
    raise;
  end;
end;

constructor TNexusScriptJSONEmitter.Create;
var
  lMetadata: TJSONObject;
begin
  inherited Create;
  FRoot := TJSONObject.Create;
  FRootNames := TStringList.Create;
  FRootNames.CaseSensitive := False;
  FCollectedNames := TStringList.Create;
  FCollectedNames.CaseSensitive := False;
  lMetadata := TJSONObject.Create;
  FRoot.Add('_nx', lMetadata);
  FCollections := TJSONObject.Create;
  lMetadata.Add('Collections', FCollections);
end;

destructor TNexusScriptJSONEmitter.Destroy;
begin
  FCollectedNames.Free;
  FRootNames.Free;
  FRoot.Free;
  inherited Destroy;
end;

function TNexusScriptJSONEmitter.NamedValueJSON(const AName: string;
  AValue: TJSONData): TJSONObject;
var
  lMetaData: TNexusScriptArtifactNamedValueMetadata;
begin
  Result := TJSONObject.Create;
  lMetaData := TNexusScriptArtifactNamedValueMetadata.Create;
  try
    try
      lMetaData.Name.Value := AName;
      Result.Add('_nx', lMetaData.ToJSONData);
    finally
      lMetaData.Free;
    end;
    Result.Add('Value', AValue);
  except
    Result.Free;
    raise;
  end;
end;

function TNexusScriptJSONEmitter.ArrayItemJSON(
  AValue: TNexusScriptCompiledValue): TJSONData;
var
  lValue: TNexusScriptCompiledValue;
begin
  lValue := AValue.ArtifactValue;
  Result := ValueJSON(AValue, True);
  if (AValue.EffectiveName <> '') and
    (lValue.ArtifactKind in [nsavText, nsavArray]) then
    Result := NamedValueJSON(AValue.EffectiveName, Result);
end;

function TNexusScriptJSONEmitter.ArrayJSON(
  AValue: TNexusScriptCompiledValue): TJSONArray;
var
  lItem: TNexusScriptCompiledValue;
begin
  Result := TJSONArray.Create;
  try
    for lItem in AValue.Items do
      Result.Add(ArrayItemJSON(lItem));
  except
    Result.Free;
    raise;
  end;
end;

function TNexusScriptJSONEmitter.ValueJSON(
  AValue: TNexusScriptCompiledValue; AArrayItem: Boolean): TJSONData;
var
  lValue: TNexusScriptCompiledValue;
begin
  lValue := AValue.ArtifactValue;
  case lValue.ArtifactKind of
    nsavText:
      Result := TJSONString.Create(lValue.EffectiveText);
    nsavArray:
      Result := ArrayJSON(lValue);
    nsavDefinition:
      Result := DefinitionJSON(lValue.StructuralDefinition, AValue);
  else
    if AArrayItem then
      raise ENexusScriptJSON.Create(
        'Array item has no completed artifact value.')
    else
      raise ENexusScriptJSON.Create(
        'Property has no completed artifact value.');
  end;
end;

function TNexusScriptJSONEmitter.DefinitionJSON(
  ADefinition: TNexusScriptCompiledDefinition;
  AReferenceValue: TNexusScriptCompiledValue): TJSONObject;
var
  lMetaData: TNexusScriptArtifactMetadata;
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  if (ADefinition.FindProperty('_nx') <> nil) or
    (ADefinition.FindChild('_nx') <> nil) then
    raise ENexusScriptJSON.CreateFmt(
      'Definition %s uses reserved member _nx.', [ADefinition.Name]);

  Result := TJSONObject.Create;
  lMetaData := nil;
  try
    lMetaData := DefinitionMetadata(ADefinition, AReferenceValue);
    Result.Add('_nx', lMetaData.ToJSONData);
    FreeAndNil(lMetaData);
    for lProperty in ADefinition.Properties do
      Result.Add(lProperty.Name, ValueJSON(lProperty.Value, False));
    for lChild in ADefinition.Children do
      Result.Add(lChild.Name, DefinitionJSON(lChild));
  except
    lMetaData.Free;
    Result.Free;
    raise;
  end;
end;

procedure TNexusScriptJSONEmitter.AddDocument(
  ADocument: TNexusScriptCompiledDocument);
var
  lDefinition: TNexusScriptCompiledDefinition;
  lView: TNexusScriptDefinitionView;
  lRoots, lDefinitions: TJSONObject;
  lCollection: TJSONArray;
  lIndex, lExisting: Integer;
  lKey, lName: string;
begin
  lView := TNexusScriptDefinitionView.Create;
  lRoots := TJSONObject.Create;
  lDefinitions := TJSONObject.Create;
  try
    try
      lView.AddDocument(ADocument);
    except
      on E: Exception do raise ENexusScriptJSON.Create(E.Message);
    end;
    for lDefinition in lView.Roots do
    begin
      if SameText(lDefinition.Name, '_nx') then
        raise ENexusScriptJSON.Create('Artifact root uses reserved name _nx.');
      lExisting := FRootNames.IndexOfName(lDefinition.Name);
      if lExisting >= 0 then
      begin
        if FRootNames.ValueFromIndex[lExisting] = lDefinition.SourceRange.SourceName then
          Continue;
        raise ENexusScriptJSON.CreateFmt('Duplicate artifact root name %s.',
          [lDefinition.Name]);
      end;
      lRoots.Add(lDefinition.Name, DefinitionJSON(lDefinition));
    end;
    for lIndex := 0 to lView.Definitions.Count - 1 do
    begin
      lDefinition := lView.Definitions[lIndex];
      lKey := lView.ScopedNames[lIndex];
      if FCollectedNames.IndexOf(lKey) < 0 then
        lDefinitions.Add(lKey, DefinitionJSON(lDefinition));
    end;
    { Commit copied JSON only after all rendering succeeds. The caller may
      release or recompile its documents after this method returns. }
    while lRoots.Count > 0 do
    begin
      lName := lRoots.Names[0];
      FRoot.Add(lName, lRoots.Extract(0));
    end;
    for lDefinition in lView.Roots do
      if FRootNames.IndexOfName(lDefinition.Name) < 0 then
        FRootNames.Add(lDefinition.Name + '=' + lDefinition.SourceRange.SourceName);
    for lIndex := 0 to lView.Definitions.Count - 1 do
    begin
      lKey := lView.ScopedNames[lIndex];
      lExisting := lDefinitions.IndexOfName(lKey);
      if lExisting < 0 then Continue;
      lDefinition := lView.Definitions[lIndex];
      if not FCollections.Find(lDefinition.Kind, lCollection) then
      begin
        lCollection := TJSONArray.Create;
        FCollections.Add(lDefinition.Kind, lCollection);
      end;
      lCollection.Add(lDefinitions.Extract(lExisting));
      FCollectedNames.Add(lKey);
    end;
  finally
    lDefinitions.Free;
    lRoots.Free;
    lView.Free;
  end;
end;

function TNexusScriptJSONEmitter.JSON: string;
begin
  Result := FRoot.FormatJSON;
end;

end.
