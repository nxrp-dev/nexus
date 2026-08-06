unit obMetaDataModel;

{$mode delphi}{$H+}
interface

uses obXMLObjects;

type
{$M+}
  TNameItem = class(TXMLObject);
  TNameList = class(TXMLObjectList<TNameItem>);

  TFieldItem = class;
  TFieldList = class;
  TIndexItem = class;
  TIndexList = class;
  TForeignKeyItem = class;
  TForeignKeyList = class;
  TTemplateItem = class;
  TTemplateList = class;
  TTableItem = class;
  TTableList = class;

  TNameValueItem = class(TXMLObject)
  private
    FValue: string;
  published
    property Value : string read FValue write FValue;
  end;

  TNameValueList = class(TXMLObjectList<TNameValueItem>);

  TForeignKeyItem = class(TXMLObject)
  private
    FEntity: string;
    FReferenceEntity: string;
    FField: string;
  protected
  public
  published
    property Entity : string read FEntity write FEntity;
    property ReferenceEntity : string read FReferenceEntity write FReferenceEntity;
    property Field : string read FField write FField;
  end;

  TForeignKeyList = class(TXMLObjectList<TForeignKeyItem>);

  TTemplateItem = class(TXMLObject)
  private
    FTemplateReferences : TNameList;
    FAttributeReferences : TNameList;
    FFields : TFieldList;
    FIndexes : TIndexList;
    FForeignKeys: TForeignKeyList;
    FChildReferences: TNameList;
  protected
  public
    constructor Create; override;
    destructor Destroy; override;

  published
    property Fields : TFieldList read FFields write FFields;
    property Indexes : TIndexList read FIndexes write FIndexes;
    property ForeignKeys : TForeignKeyList read FForeignKeys write FForeignKeys;

    property TemplateReferences : TNameList read FTemplateReferences write FTemplateReferences;
    property AttributeReferences : TNameList read FAttributeReferences write FAttributeReferences;
    property ChildReferences : TNameList read FChildReferences write FChildReferences;
  end;

  TTemplateList = class(TXMLObjectList<TTemplateItem>);

  TTableItem = class(TTemplateItem);
  TTableList = class(TXMLObjectList<TTableItem>);

  TFieldItem = class(TXMLObject)
  private
    FFieldType: string;
    FIsReference: boolean;
    FReferencedEntity: string;
    FReferencedFieldName: string;
    FAttributeReferences: TNameList;
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property FieldType : string read FFieldType write FFieldType;
    property IsReference : boolean read FIsReference write FIsReference;
    property ReferenceEntity : string read FReferencedEntity write FReferencedEntity;
    property ReferencedFieldName : string read FReferencedFieldName write FReferencedFieldName;
    property AttributeReferences : TNameList read FAttributeReferences write FAttributeReferences;
  end;

  TFieldList = class(TXMLObjectList<TFieldItem>);
  
  TIndexItem = class(TXMLObject)
  private
    FFields : TFieldList;
    FFieldReferences: TNameValueList;
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Fields : TFieldList read FFields;
    property FieldReferences : TNameValueList read FFieldReferences write FFieldReferences;
  end;

  TIndexList = class(TXMLObjectList<TIndexItem>);

  TAttributeSetItem = class(TXMLObject)
  private
    FAttributeSet : TNameValueList;
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property AttributeSet : TNameValueList read FAttributeSet write FAttributeSet;
  end;

  TAttributeSetList = class(TXMLObjectList<TAttributeSetItem>);


implementation

constructor TTemplateItem.Create;
begin
  inherited;

  FTemplateReferences := TNameList.Create;
  FAttributeReferences := TNameList.Create;
  FChildReferences := TNameList.Create;
  FFields := TFieldList.Create;
  FIndexes := TIndexList.Create;
  FForeignKeys := TForeignKeyList.Create;
end;

destructor TTemplateItem.Destroy;
begin
  FAttributeReferences.Free;
  FTemplateReferences.Free;
  FChildReferences.Free;
  FFields.Free;
  FIndexes.Free;
  FForeignKeys.Free;

  inherited;
end;

constructor TIndexItem.Create;
begin
  inherited;

  FFields := TFieldList.Create;
  FFieldReferences := TNameValueList.Create;
end;

destructor TIndexItem.Destroy;
begin
  FFields.Free;
  FFieldReferences.Free;
  inherited;
end;

constructor TFieldItem.Create;
begin
  inherited;

  FAttributeReferences := TNameList.Create;
end;

destructor TFieldItem.Destroy;
begin
  FAttributeReferences.Free;

  inherited;
end;

constructor TAttributeSetItem.Create;
begin
  inherited;

  FAttributeSet := TNameValueList.Create;
end;

destructor TAttributeSetItem.Destroy;
begin
  FAttributeSet.Free;

  inherited;
end;

end.
