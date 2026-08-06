unit obMetaDataTransformations;

interface

uses obMetaDataModuleList, obMetaDataModel, SysUtils, obXMLObjects;

type
  TMetaDataTransform = class(TObject)
  private
    procedure ApplyCoreDefaults(AMetaDataModuleList: TMetaDataModuleList);
    procedure CopyAttributes(AMetaDataModuleList: TMetaDataModuleList; AReferences : TNameList; ATarget: TXMLObject);
    procedure CopyExtraAttributes(ASource, ATarget: TXMLObject);
    procedure CopyTemplateItem(ASource, ATarget: TTemplateItem);
    procedure CopyTableItem(ASource: TTableItem; ATarget: TTableItem);
    procedure CopyModuleItem(ASource, ATarget: TMetaDataModuleItem);
    function FindField(AFields: TFieldList; const AFieldName: string): TFieldItem;
    function FindTemplateField(AMetaDataModuleList: TMetaDataModuleList; ATemplate: TTemplateItem; const AFieldName: string): TFieldItem;
    function FindTable(AMetaDataModuleList: TMetaDataModuleList; const ATableName: string): TTableItem;
    function GetReferencedFieldType(AMetaDataModuleList: TMetaDataModuleList; AField: TFieldItem): string;
  protected
    procedure CopyTemplate(AMetaDataModuleList : TMetaDataModuleList; const ATemplateName : string; ATarget : TTableItem);
    procedure TransformTable(AMetaDataModuleList : TMetaDataModuleList; ATable : TTableItem; ATargetModule : TMetaDataModuleItem);
    procedure TransformModule(AMetaDataModuleList : TMetaDataModuleList; ASourceModule : TMetaDataModuleItem);
  public
    procedure Expand(ASource, ATarget : TMetaDataModuleList);
    procedure Transform(AMetaDataModuleList : TMetaDataModuleList);
  end;

implementation

{ TMetaDataTransform }

const
  cPrimaryKeyTypeSetting = 'NEXUS_SCHEMA_PRIMARY_KEY_TYPE';
  cDefaultPrimaryKeyType = 'integer';

procedure TMetaDataTransform.ApplyCoreDefaults(AMetaDataModuleList: TMetaDataModuleList);
begin
  if AMetaDataModuleList.ExtraAttributes.Values[cPrimaryKeyTypeSetting] = '' then
    AMetaDataModuleList.ExtraAttributes.Values[cPrimaryKeyTypeSetting] := cDefaultPrimaryKeyType;
end;

procedure TMetaDataTransform.Expand(ASource, ATarget: TMetaDataModuleList);
var
  lIdx: integer;
  lModule: TMetaDataModuleItem;
begin
  ATarget.Clear;
  ATarget.Data.Clear;
  ATarget.AttributeSets.Clear;
  ATarget.ExtraAttributes.Clear;

  CopyExtraAttributes(ASource, ATarget);
  ASource.Data.CopyTo(ATarget.Data);
  ASource.AttributeSets.CopyTo(ATarget.AttributeSets);

  for lIdx := 0 to ASource.Count - 1 do
  begin
    lModule := ATarget.AddObject(ASource.Items[lIdx].Name);
    CopyModuleItem(ASource.Items[lIdx], lModule);
  end;

  Transform(ATarget);
end;

procedure TMetaDataTransform.Transform(AMetaDataModuleList: TMetaDataModuleList);
var
  lIdx : integer;
  lModule : TMetaDataModuleItem;
begin
  ApplyCoreDefaults(AMetaDataModuleList);

  for lIdx := 0 to AMetaDataModuleList.Count - 1 do
  begin
    lModule := AMetaDataModuleList.Items[lIdx];
    TransformModule(AMetaDataModuleList, lModule);
  end;
end;

procedure TMetaDataTransform.TransformModule(AMetaDataModuleList: TMetaDataModuleList; ASourceModule : TMetaDataModuleItem);
var
  lIdx : integer;
begin
  for lIdx := 0 to ASourceModule.Tables.Count - 1 do
    TransformTable(AMetaDataModuleList, ASourceModule.Tables.Items[lIdx], ASourceModule);
end;

procedure TMetaDataTransform.CopyTemplate(AMetaDataModuleList : TMetaDataModuleList; const ATemplateName: string; ATarget: TTableItem);
var
  lTemplate : TTemplateItem;
  lIdx : integer;
begin
  lTemplate := AMetaDataModuleList.GetTemplate(ATemplateName);

  lTemplate.Fields.CopyTo(ATarget.Fields);
  lTemplate.Indexes.CopyTo(ATarget.Indexes);
  lTemplate.AttributeReferences.CopyTo(ATarget.AttributeReferences);
  lTemplate.ChildReferences.CopyTo(ATarget.ChildReferences);

  for lIdx := 0 to lTemplate.TemplateReferences.Count - 1 do
  begin
    CopyTemplate(AMetaDataModuleList, lTemplate.TemplateReferences.Items[lIdx].Name, ATarget);
  end;
end;

procedure TMetaDataTransform.CopyAttributes(AMetaDataModuleList : TMetaDataModuleList; AReferences : TNameList; ATarget: TXMLObject);
var
  lAttributeSet : TAttributeSetItem;
  lIdx : integer;
  lAttribute : TNameValueItem;
  lAttributeIdx : integer;
begin
  for lAttributeIdx := 0 to AReferences.Count - 1 do
  begin
    lAttributeSet := AMetaDataModuleList.GetAttributeSet(AReferences.Items[lAttributeIdx].Name);
    for lIdx := 0 to lAttributeSet.AttributeSet.Count - 1 do
    begin
      lAttribute := lAttributeSet.AttributeSet.Items[lIdx];
      ATarget.ExtraAttributes.Values[lAttribute.Name] := lAttribute.Value;
    end;
  end;
end;

procedure TMetaDataTransform.CopyExtraAttributes(ASource, ATarget: TXMLObject);
begin
  ATarget.ExtraAttributes.Assign(ASource.ExtraAttributes);
end;

procedure TMetaDataTransform.CopyTemplateItem(ASource, ATarget: TTemplateItem);
begin
  CopyExtraAttributes(ASource, ATarget);
  ASource.Fields.CopyTo(ATarget.Fields);
  ASource.Indexes.CopyTo(ATarget.Indexes);
  ASource.ForeignKeys.CopyTo(ATarget.ForeignKeys);
  ASource.TemplateReferences.CopyTo(ATarget.TemplateReferences);
  ASource.AttributeReferences.CopyTo(ATarget.AttributeReferences);
  ASource.ChildReferences.CopyTo(ATarget.ChildReferences);
end;

procedure TMetaDataTransform.CopyTableItem(ASource: TTableItem; ATarget: TTableItem);
begin
  CopyTemplateItem(ASource, ATarget);
end;

procedure TMetaDataTransform.CopyModuleItem(ASource, ATarget: TMetaDataModuleItem);
var
  lIdx: integer;
begin
  CopyExtraAttributes(ASource, ATarget);
  ASource.Types.CopyTo(ATarget.Types);
  ASource.AttributeSets.CopyTo(ATarget.AttributeSets);

  for lIdx := 0 to ASource.Templates.Count - 1 do
    CopyTemplateItem(
      ASource.Templates.Items[lIdx],
      ATarget.Templates.AddObject(ASource.Templates.Items[lIdx].Name)
    );

  for lIdx := 0 to ASource.Tables.Count - 1 do
    CopyTableItem(
      ASource.Tables.Items[lIdx],
      ATarget.Tables.AddObject(ASource.Tables.Items[lIdx].Name)
    );
end;

function TMetaDataTransform.FindField(AFields: TFieldList; const AFieldName: string): TFieldItem;
var
  lIdx: integer;
begin
  Result := nil;
  for lIdx := 0 to AFields.Count - 1 do
  begin
    if SameText(AFields.Items[lIdx].Name, AFieldName) then
    begin
      Result := AFields.Items[lIdx];
      Break;
    end;
  end;
end;

function TMetaDataTransform.FindTemplateField(AMetaDataModuleList: TMetaDataModuleList; ATemplate: TTemplateItem; const AFieldName: string): TFieldItem;
var
  lIdx: integer;
begin
  Result := FindField(ATemplate.Fields, AFieldName);
  if Assigned(Result) then
    Exit;

  for lIdx := 0 to ATemplate.TemplateReferences.Count - 1 do
  begin
    Result := FindTemplateField(
      AMetaDataModuleList,
      AMetaDataModuleList.GetTemplate(ATemplate.TemplateReferences.Items[lIdx].Name),
      AFieldName
    );
    if Assigned(Result) then
      Break;
  end;
end;

function TMetaDataTransform.FindTable(AMetaDataModuleList: TMetaDataModuleList; const ATableName: string): TTableItem;
var
  lModuleIdx: integer;
  lTableIdx: integer;
begin
  Result := nil;
  for lModuleIdx := 0 to AMetaDataModuleList.Count - 1 do
  begin
    for lTableIdx := 0 to AMetaDataModuleList.Items[lModuleIdx].Tables.Count - 1 do
    begin
      if SameText(AMetaDataModuleList.Items[lModuleIdx].Tables.Items[lTableIdx].Name, ATableName) then
      begin
        Result := AMetaDataModuleList.Items[lModuleIdx].Tables.Items[lTableIdx];
        Exit;
      end;
    end;
  end;
end;

function TMetaDataTransform.GetReferencedFieldType(AMetaDataModuleList: TMetaDataModuleList; AField: TFieldItem): string;
var
  lReferencedTable: TTableItem;
  lReferencedField: TFieldItem;
begin
  if AField.ReferencedFieldName = '' then
    Exit(AMetaDataModuleList.ExtraAttributes.Values[cPrimaryKeyTypeSetting]);

  lReferencedTable := FindTable(AMetaDataModuleList, AField.ReferenceEntity);
  if not Assigned(lReferencedTable) then
    raise Exception.CreateFmt('Invalid table reference %s.', [AField.ReferenceEntity]);

  lReferencedField := FindField(lReferencedTable.Fields, AField.ReferencedFieldName);
  if not Assigned(lReferencedField) then
    lReferencedField := FindTemplateField(AMetaDataModuleList, lReferencedTable, AField.ReferencedFieldName);

  if not Assigned(lReferencedField) then
    raise Exception.CreateFmt('Invalid field reference %s.%s.', [AField.ReferenceEntity, AField.ReferencedFieldName]);

  Result := lReferencedField.FieldType;
end;

procedure TMetaDataTransform.TransformTable(AMetaDataModuleList: TMetaDataModuleList; ATable: TTableItem; ATargetModule: TMetaDataModuleItem);
var
  lTemplateIdx : integer;
  lFieldIdx : integer;
  lForeignKey : TForeignKeyItem;
  lRefEntity : string;
  lFieldName : string;
  lField : TFieldItem;
begin
  try
    for lTemplateIdx := 0 to ATable.TemplateReferences.Count - 1 do
    begin
      CopyTemplate(AMetaDataModuleList, ATable.TemplateReferences.Items[lTemplateIdx].Name, ATable);
    end;

    CopyAttributes(AMetaDataModuleList, ATable.AttributeReferences, ATable);

    for lFieldIdx := 0 to ATable.Fields.Count - 1 do
    begin
      lField := ATable.Fields.Items[lFieldIdx];
      if lField.IsReference then
      begin
        lRefEntity := lField.ReferenceEntity;
        lFieldName := lField.Name;

        lForeignKey := ATable.ForeignKeys.AddObject(ATable.Name+'_'+lRefEntity+'_'+lFieldName);
        lForeignKey.Entity := ATable.Name;
        lForeignKey.ReferenceEntity := lRefEntity;
        lForeignKey.Field := lFieldName;
        lField.FieldType := GetReferencedFieldType(AMetaDataModuleList, lField);
      end;
      CopyAttributes(AMetaDataModuleList, lField.AttributeReferences, lField);
    end;
  except
    on e : Exception do begin
      raise Exception.CreateFmt('Exception occured during transformation of %s. [Error: %s]', [ATable.Name, e.Message]);
    end;
  end;
end;

end.

