unit obMetaDataJSON;

{$mode delphi}{$H+}

interface

uses
  obMetaDataModuleList;

function MetaDataToMustacheJSON(AMetaData: TMetaDataModuleList): string;
procedure SaveMetaDataMustacheJSON(AMetaData: TMetaDataModuleList; const AFilename: string);

implementation

uses
  Classes,
  fpjson,
  SysUtils,
  obMetaDataModel,
  obXMLObjects;

function ExtraAttributesToJSON(AObject: TXMLObject): TJSONObject;
var
  lIdx: integer;
begin
  Result := TJSONObject.Create;
  for lIdx := 0 to AObject.ExtraAttributes.Count - 1 do
    Result.Add(AObject.ExtraAttributes.Names[lIdx], AObject.ExtraAttributes.ValueFromIndex[lIdx]);
end;

function NameListToJSON(AList: TNameList): TJSONArray;
var
  lIdx: integer;
  lItem: TJSONObject;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
  begin
    lItem := TJSONObject.Create;
    lItem.Add('Name', AList.Items[lIdx].Name);
    lItem.Add('Attributes', ExtraAttributesToJSON(AList.Items[lIdx]));
    Result.Add(lItem);
  end;
end;

function NameValueListToJSON(AList: TNameValueList): TJSONArray;
var
  lIdx: integer;
  lItem: TJSONObject;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
  begin
    lItem := TJSONObject.Create;
    lItem.Add('Name', AList.Items[lIdx].Name);
    lItem.Add('Value', AList.Items[lIdx].Value);
    lItem.Add('Attributes', ExtraAttributesToJSON(AList.Items[lIdx]));
    Result.Add(lItem);
  end;
end;

function AttributeSetListToJSON(AList: TAttributeSetList): TJSONArray;
var
  lIdx: integer;
  lItem: TJSONObject;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
  begin
    lItem := TJSONObject.Create;
    lItem.Add('Name', AList.Items[lIdx].Name);
    lItem.Add('Attributes', ExtraAttributesToJSON(AList.Items[lIdx]));
    lItem.Add('Values', NameValueListToJSON(AList.Items[lIdx].AttributeSet));
    Result.Add(lItem);
  end;
end;

function FieldListToJSON(AList: TFieldList; const ATableName: string = ''): TJSONArray;
var
  lIdx: integer;
  lItem: TJSONObject;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
  begin
    lItem := TJSONObject.Create;
    lItem.Add('Name', AList.Items[lIdx].Name);
    lItem.Add('TableName', ATableName);
    lItem.Add('FieldType', AList.Items[lIdx].FieldType);
    lItem.Add('IsReference', AList.Items[lIdx].IsReference);
    lItem.Add('ReferenceEntity', AList.Items[lIdx].ReferenceEntity);
    lItem.Add('ReferencedFieldName', AList.Items[lIdx].ReferencedFieldName);
    if lIdx < AList.Count - 1 then
      lItem.Add('Comma', ',')
    else
      lItem.Add('Comma', '');
    lItem.Add('AttributeReferences', NameListToJSON(AList.Items[lIdx].AttributeReferences));
    lItem.Add('Attributes', ExtraAttributesToJSON(AList.Items[lIdx]));
    Result.Add(lItem);
  end;
end;

function IndexListToJSON(AList: TIndexList): TJSONArray;
var
  lIdx: integer;
  lItem: TJSONObject;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
  begin
    lItem := TJSONObject.Create;
    lItem.Add('Name', AList.Items[lIdx].Name);
    lItem.Add('Fields', FieldListToJSON(AList.Items[lIdx].Fields));
    lItem.Add('FieldReferences', NameValueListToJSON(AList.Items[lIdx].FieldReferences));
    lItem.Add('Attributes', ExtraAttributesToJSON(AList.Items[lIdx]));
    Result.Add(lItem);
  end;
end;

function ForeignKeyListToJSON(AList: TForeignKeyList; const ATableName: string = ''): TJSONArray;
var
  lIdx: integer;
  lItem: TJSONObject;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
  begin
    lItem := TJSONObject.Create;
    lItem.Add('Name', AList.Items[lIdx].Name);
    lItem.Add('TableName', ATableName);
    lItem.Add('ConstraintName', 'FK_' + ATableName + '_' + AList.Items[lIdx].Field);
    lItem.Add('Entity', AList.Items[lIdx].Entity);
    lItem.Add('ReferenceEntity', AList.Items[lIdx].ReferenceEntity);
    lItem.Add('Field', AList.Items[lIdx].Field);
    lItem.Add('Attributes', ExtraAttributesToJSON(AList.Items[lIdx]));
    Result.Add(lItem);
  end;
end;

function TemplateItemToJSON(AItem: TTemplateItem): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('Name', AItem.Name);
  Result.Add('Fields', FieldListToJSON(AItem.Fields, AItem.Name));
  Result.Add('Indexes', IndexListToJSON(AItem.Indexes));
  Result.Add('ForeignKeys', ForeignKeyListToJSON(AItem.ForeignKeys, AItem.Name));
  Result.Add('TemplateReferences', NameListToJSON(AItem.TemplateReferences));
  Result.Add('AttributeReferences', NameListToJSON(AItem.AttributeReferences));
  Result.Add('ChildReferences', NameListToJSON(AItem.ChildReferences));
  Result.Add('Attributes', ExtraAttributesToJSON(AItem));
end;

function TemplateListToJSON(AList: TTemplateList): TJSONArray;
var
  lIdx: integer;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
    Result.Add(TemplateItemToJSON(AList.Items[lIdx]));
end;

function TableItemToJSON(AItem: TTableItem): TJSONObject;
begin
  Result := TemplateItemToJSON(AItem);
end;

function TableListToJSON(AList: TTableList): TJSONArray;
var
  lIdx: integer;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
    Result.Add(TableItemToJSON(AList.Items[lIdx]));
end;

function ModuleItemToJSON(AItem: TMetaDataModuleItem): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('Name', AItem.Name);
  Result.Add('Types', NameValueListToJSON(AItem.Types));
  Result.Add('Templates', TemplateListToJSON(AItem.Templates));
  Result.Add('Tables', TableListToJSON(AItem.Tables));
  Result.Add('AttributeSets', AttributeSetListToJSON(AItem.AttributeSets));
  Result.Add('Attributes', ExtraAttributesToJSON(AItem));
end;

function ModuleListToJSON(AList: TMetaDataModuleList): TJSONArray;
var
  lIdx: integer;
begin
  Result := TJSONArray.Create;
  for lIdx := 0 to AList.Count - 1 do
    Result.Add(ModuleItemToJSON(AList.Items[lIdx]));
end;

function MetaDataObjectToJSON(AMetaData: TMetaDataModuleList): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('Attributes', ExtraAttributesToJSON(AMetaData));
  Result.Add('Data', NameValueListToJSON(AMetaData.Data));
  Result.Add('AttributeSets', AttributeSetListToJSON(AMetaData.AttributeSets));
  Result.Add('Modules', ModuleListToJSON(AMetaData));
end;

function MetaDataToMustacheJSON(AMetaData: TMetaDataModuleList): string;
var
  lRoot: TJSONObject;
  lNexusSchema: TJSONObject;
begin
  lRoot := TJSONObject.Create;
  try
    lNexusSchema := TJSONObject.Create;
    lNexusSchema.Add('MetaData', MetaDataObjectToJSON(AMetaData));
    lRoot.Add('NexusSchema', lNexusSchema);
    Result := lRoot.FormatJSON;
  finally
    lRoot.Free;
  end;
end;

procedure SaveMetaDataMustacheJSON(AMetaData: TMetaDataModuleList; const AFilename: string);
var
  lPath: string;
  lJSON: TStringList;
begin
  lPath := ExtractFilePath(AFilename);
  if (lPath <> '') and not DirectoryExists(lPath) then
    ForceDirectories(lPath);

  lJSON := TStringList.Create;
  try
    lJSON.Text := MetaDataToMustacheJSON(AMetaData);
    lJSON.SaveToFile(AFilename);
  finally
    lJSON.Free;
  end;
end;

end.
