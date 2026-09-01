unit obNexusScriptJSON;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  fpjson,
  obNexusScriptModel;

type
  ENexusScriptJSON = class(Exception);

  TNexusScriptJSONEmitter = class
  private
    FRoot: TJSONObject;
    FRootNames: TStringList;
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

uses
  tpNexusScript;

constructor TNexusScriptJSONEmitter.Create;
begin
  inherited Create;
  FRoot := TJSONObject.Create;
  FRootNames := TStringList.Create;
  FRootNames.CaseSensitive := False;
end;

destructor TNexusScriptJSONEmitter.Destroy;
begin
  FRootNames.Free;
  FRoot.Free;
  inherited Destroy;
end;

function TNexusScriptJSONEmitter.NamedValueJSON(const AName: string;
  AValue: TJSONData): TJSONObject;
var
  lMetaData: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    lMetaData := TJSONObject.Create;
    lMetaData.Add('Name', AName);
    Result.Add('_nx', lMetaData);
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
  lMetaData: TJSONObject;
  lReference: TJSONObject;
  lTags: TJSONArray;
  lIsReference: Boolean;
  lTag: string;
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  if (ADefinition.FindProperty('_nx') <> nil) or
    (ADefinition.FindChild('_nx') <> nil) then
    raise ENexusScriptJSON.CreateFmt(
      'Definition %s uses reserved member _nx.', [ADefinition.Name]);

  Result := TJSONObject.Create;
  try
    lMetaData := TJSONObject.Create;
    lMetaData.Add('Kind', ADefinition.Kind);
    lMetaData.Add('Name', ADefinition.Name);
    lIsReference := (AReferenceValue <> nil) and
      (AReferenceValue.Kind = nsvReference);
    lMetaData.Add('IsReference', lIsReference);
    if lIsReference then
    begin
      if AReferenceValue.OriginalDefinitionName = '' then
        raise ENexusScriptJSON.CreateFmt(
          'Structural reference %s has no resolved target name.',
          [AReferenceValue.SourceText]);
      lReference := TJSONObject.Create;
      lReference.Add('Kind', ADefinition.Kind);
      lReference.Add('Name', AReferenceValue.OriginalDefinitionName);
      lMetaData.Add('Reference', lReference);
    end;
    if ADefinition.Tags.Count > 0 then
    begin
      lTags := TJSONArray.Create;
      for lTag in ADefinition.Tags do
        lTags.Add(lTag);
      lMetaData.Add('Tags', lTags);
    end;
    Result.Add('_nx', lMetaData);
    for lProperty in ADefinition.Properties do
      Result.Add(lProperty.Name, ValueJSON(lProperty.Value, False));
    for lChild in ADefinition.Children do
      Result.Add(lChild.Name, DefinitionJSON(lChild));
  except
    Result.Free;
    raise;
  end;
end;

procedure TNexusScriptJSONEmitter.AddDocument(
  ADocument: TNexusScriptCompiledDocument);
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  for lDefinition in ADocument.Definitions do
  begin
    if lDefinition.ImportedRoot then
      Continue;
    if FRootNames.IndexOf(lDefinition.Name) >= 0 then
      raise ENexusScriptJSON.CreateFmt(
        'Duplicate artifact root name %s.', [lDefinition.Name]);
    FRoot.Add(lDefinition.Name, DefinitionJSON(lDefinition));
    FRootNames.Add(lDefinition.Name);
  end;
end;

function TNexusScriptJSONEmitter.JSON: string;
begin
  Result := FRoot.FormatJSON;
end;

end.
