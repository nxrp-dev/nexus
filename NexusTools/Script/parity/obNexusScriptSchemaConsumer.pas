unit obNexusScriptSchemaConsumer;

{$mode delphi}{$H+}

interface

uses
  obNexusScriptModel,
  tpNexusScript,
  obMetaDataModuleList,
  obMetaDataModel;

type
  TNexusScriptSchemaConsumer = class
  private
    function LastSegment(const APath: string): string;
    procedure AddReferences(AValue: TNexusScriptCompiledValue; ATarget: TObject);
    procedure AddNames(AValue: TNexusScriptCompiledValue; ATarget: TNameList);
    procedure AddFields(ASource: TNexusScriptSourceDefinition;
      ACompiled: TNexusScriptCompiledDefinition; ATarget: TObject);
    procedure ConsumeRoot(ASource: TNexusScriptSourceDefinition;
      ACompiled: TNexusScriptCompiledDefinition;
      AMetaData: TMetaDataModuleList);
  public
    function Consume(ASource: TNexusScriptSourceDocument;
      ADocument: TNexusScriptCompiledDocument;
      AMetaData: TMetaDataModuleList): Boolean;
  end;

implementation

uses
  Classes,
  SysUtils;

procedure TNexusScriptSchemaConsumer.AddNames(
  AValue: TNexusScriptCompiledValue; ATarget: TNameList);
var
  lItem: TNexusScriptCompiledValue;
begin
  if AValue.Kind = nsvArray then
    for lItem in AValue.Items do
      if lItem.ResolvedDefinition <> nil then
        ATarget.AddObject(lItem.ResolvedDefinition.Name);
end;

function TNexusScriptSchemaConsumer.LastSegment(const APath: string): string;
var
  lIndex: Integer;
begin
  lIndex := LastDelimiter('.', APath);
  if lIndex = 0 then
    Result := APath
  else
    Result := Copy(APath, lIndex + 1, MaxInt);
end;

procedure TNexusScriptSchemaConsumer.AddReferences(
  AValue: TNexusScriptCompiledValue; ATarget: TObject);
var
  lReferences: TNameList;
begin
  if ATarget is TTemplateItem then
    lReferences := TTemplateItem(ATarget).AttributeReferences
  else if ATarget is TFieldItem then
    lReferences := TFieldItem(ATarget).AttributeReferences
  else
    Exit;
  if AValue.Kind = nsvArray then
    AddNames(AValue, lReferences);
end;

procedure TNexusScriptSchemaConsumer.AddFields(
  ASource: TNexusScriptSourceDefinition;
  ACompiled: TNexusScriptCompiledDefinition; ATarget: TObject);
var
  lSourceFields: TNexusScriptSourceProperty;
  lSourceItem: TNexusScriptSourceValue;
  lCompiledFields: TNexusScriptCompiledProperty;
  lCompiledItem: TNexusScriptCompiledValue;
  lSourceField: TNexusScriptSourceDefinition;
  lCompiledField: TNexusScriptCompiledDefinition;
  lEffectiveName: string;
  lProperty: TNexusScriptCompiledProperty;
  lField: TFieldItem;
  lFields: TFieldList;
begin
  if ATarget is TTemplateItem then
    lFields := TTemplateItem(ATarget).Fields
  else
    Exit;
  lSourceFields := ASource.FindProperty('Fields');
  lCompiledFields := ACompiled.FindProperty('Fields');
  if (lSourceFields = nil) or (lCompiledFields = nil) then
    Exit;
  for lSourceItem in lSourceFields.Value.Items do
  begin
    lSourceField := lSourceItem.InlineDefinition;
    if lSourceField = nil then
      Continue;
    if not SameText(lSourceField.Kind, 'Field') then
      Continue;
    lEffectiveName := lSourceItem.EntryName;
    if lEffectiveName = '' then
      lEffectiveName := lSourceField.Name;
    lCompiledItem := lCompiledFields.Value.FindNamedItem(lEffectiveName);
    if lCompiledItem = nil then
      Continue;
    lCompiledField := lCompiledItem.StructuralDefinition;
    if lCompiledField = nil then
      Continue;
    lField := lFields.AddObject(lCompiledItem.EffectiveName);
    lProperty := lCompiledField.FindProperty('Type');
    if lProperty <> nil then
    begin
      if lProperty.Value.ResolvedDefinition <> nil then
      begin
        lField.IsReference := True;
        lField.ReferenceEntity := lProperty.Value.ResolvedDefinition.Name;
      end
      else if lProperty.Value.HasEffectiveText then
        lField.FieldType := lProperty.Value.EffectiveText;
    end;
    lProperty := lCompiledField.FindProperty('Reference');
    if (lProperty <> nil) and
      (lProperty.Value.ResolvedDefinition <> nil) then
    begin
      lField.IsReference := True;
      lField.ReferenceEntity := lProperty.Value.ResolvedDefinition.Name;
    end;
    lProperty := lCompiledField.FindProperty('ReferencedField');
    if (lProperty <> nil) and lProperty.Value.HasEffectiveText then
      lField.ReferencedFieldName := lProperty.Value.EffectiveText;
    lProperty := lCompiledField.FindProperty('Attributes');
    if lProperty <> nil then
      AddReferences(lProperty.Value, lField);
  end;
end;

procedure TNexusScriptSchemaConsumer.ConsumeRoot(
  ASource: TNexusScriptSourceDefinition;
  ACompiled: TNexusScriptCompiledDefinition;
  AMetaData: TMetaDataModuleList);
var
  lSourceDefinition: TNexusScriptSourceDefinition;
  lDefinition: TNexusScriptCompiledDefinition;
  lSourceProperty: TNexusScriptSourceProperty;
  lSourceFields: TNexusScriptSourceProperty;
  lSourceItem: TNexusScriptSourceValue;
  lProperty: TNexusScriptCompiledProperty;
  lCompiledFields: TNexusScriptCompiledProperty;
  lSelector: string;
  lModule: TMetaDataModuleItem;
  lTemplate: TTemplateItem;
  lTable: TTableItem;
  lAttributes: TAttributeSetItem;
  lData: TNexusScriptSourceDefinition;
  lItem: TNexusScriptSourceDefinition;
  lCompiledItem: TNexusScriptCompiledDefinition;
begin
  lModule := AMetaData.AddObject(ASource.Name);
  for lSourceProperty in ASource.Properties do
  begin
    lProperty := ACompiled.FindProperty(lSourceProperty.Name);
    if (lProperty <> nil) and lProperty.Value.HasEffectiveText then
      AMetaData.ExtraAttributes.Values[lProperty.Name] :=
        lProperty.Value.EffectiveText;
  end;
  for lSourceDefinition in ASource.Children do
  begin
    lDefinition := ACompiled.FindChild(lSourceDefinition.Name);
    if SameText(lSourceDefinition.Kind, 'Type') then
    begin
      lSourceFields := lSourceDefinition.FindProperty('Fields');
      lCompiledFields := lDefinition.FindProperty('Fields');
      if (lSourceFields <> nil) and (lCompiledFields <> nil) then
      for lSourceItem in lSourceFields.Value.Items do
      begin
        lItem := lSourceItem.InlineDefinition;
        if (lItem = nil) or not SameText(lItem.Kind, 'Field') then
          Continue;
        lCompiledItem := lCompiledFields.Value.FindNamedItem(lItem.Name).
          StructuralDefinition;
        lProperty := lCompiledItem.FindProperty('Type');
        if lProperty <> nil then
          lModule.Types.AddObject(lItem.Name).Value :=
            lProperty.Value.EffectiveText;
      end
    end
    else if SameText(lSourceDefinition.Kind, 'Setting') then
    begin
      lProperty := lDefinition.FindProperty('Value');
      if (lProperty <> nil) and lProperty.Value.HasEffectiveText then
        AMetaData.ExtraAttributes.Values[lDefinition.Name] :=
          lProperty.Value.EffectiveText;
    end
    else if SameText(lSourceDefinition.Kind, 'Template') or
      SameText(lSourceDefinition.Kind, 'Table') then
    begin
      if SameText(lSourceDefinition.Kind, 'Template') then
      begin
        lTemplate := lModule.Templates.AddObject(lDefinition.Name);
        AddFields(lSourceDefinition, lDefinition, lTemplate);
      end
      else
      begin
        lTable := lModule.Tables.AddObject(lDefinition.Name);
        lTemplate := lTable;
        AddFields(lSourceDefinition, lDefinition, lTable);
      end;
      for lSelector in lSourceDefinition.CompositionSelectors do
        lTemplate.TemplateReferences.AddObject(LastSegment(lSelector));
      lProperty := lDefinition.FindProperty('Attributes');
      if lProperty <> nil then
        AddReferences(lProperty.Value, lTemplate);
      lProperty := lDefinition.FindProperty('Children');
      if lProperty <> nil then
        AddNames(lProperty.Value, lTemplate.ChildReferences);
      for lData in lSourceDefinition.Children do
        if SameText(lData.Kind, 'Data') then
        begin
          lProperty := lDefinition.FindChild(lData.Name).FindProperty('Path');
          if (lProperty <> nil) and lProperty.Value.HasEffectiveText then
            AMetaData.Data.AddObject(lDefinition.Name).Value :=
              lProperty.Value.EffectiveText;
        end;
    end
    else if SameText(lSourceDefinition.Kind, 'Attributes') then
    begin
      lAttributes := lModule.AttributeSets.AddObject(lDefinition.Name);
      for lItem in lSourceDefinition.Children do
      begin
        if not SameText(lItem.Kind, 'Attribute') then
          Continue;
        lCompiledItem := lDefinition.FindChild(lItem.Name);
        lProperty := lCompiledItem.FindProperty('Value');
        if lProperty <> nil then
          lAttributes.AttributeSet.AddObject(lItem.Name).Value :=
            lProperty.Value.EffectiveText;
      end;
    end
    else if SameText(lSourceDefinition.Kind, 'Data') then
    begin
      lProperty := lDefinition.FindProperty('Path');
      if (lProperty <> nil) and lProperty.Value.HasEffectiveText then
      begin
        if lDefinition.FindProperty('Name') <> nil then
          AMetaData.Data.AddObject(
            lDefinition.FindProperty('Name').Value.EffectiveText).Value :=
              lProperty.Value.EffectiveText
        else
          AMetaData.Data.AddObject(lDefinition.Name).Value :=
            lProperty.Value.EffectiveText;
      end;
    end;
  end;
end;

function TNexusScriptSchemaConsumer.Consume(
  ASource: TNexusScriptSourceDocument;
  ADocument: TNexusScriptCompiledDocument;
  AMetaData: TMetaDataModuleList): Boolean;
var
  lSourceRoot: TNexusScriptSourceDefinition;
  lCompiledRoot: TNexusScriptCompiledDefinition;
  lInitialCount: Integer;
begin
  Result := (ASource <> nil) and (ADocument <> nil);
  if not Result then
    Exit;
  lInitialCount := AMetaData.Count;
  for lSourceRoot in ASource.Definitions do
    if SameText(lSourceRoot.Kind, 'Schema') then
    begin
      lCompiledRoot := ADocument.FindDefinition(lSourceRoot.Name);
      ConsumeRoot(lSourceRoot, lCompiledRoot, AMetaData);
    end;
  Result := AMetaData.Count > lInitialCount;
end;

end.
