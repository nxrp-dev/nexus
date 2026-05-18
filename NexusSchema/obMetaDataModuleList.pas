unit obMetaDataModuleList;


{$mode delphi}{$H+}
interface

uses obMetaDataModel, obXMLObjects;

type
  TMetaDataModuleItem = class(TXMLObject)
  private
    FTypes: TNameValueList;
    FTemplates: TTemplateList;
    FTables : TTableList;
    FAttributeSets : TAttributeSetList;
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Tables : TTableList read FTables write FTables;
    property Types : TNameValueList read FTypes write FTypes;
    property Templates : TTemplateList read FTemplates write FTemplates;
    property AttributeSets : TAttributeSetList read FAttributeSets write FAttributeSets;
  end;
  TMetaDataModuleList = class(TXMLObjectList<TMetaDataModuleItem>)
  private
    FData: TNameValueList;
    FAttributeSets: TAttributeSetList;
  protected
  public
    function GetTemplate(const ATemplateName : string) : TTemplateItem;
    function GetAttributeSet(const AAttributeSetName : string) : TAttributeSetItem;

    constructor Create; override;
    destructor Destroy; override;
  published
    property AttributeSets : TAttributeSetList read FAttributeSets write FAttributeSets;

    property Data : TNameValueList read FData write FData;
  end;

implementation

uses SysUtils;

{ TDDLMetaData }
constructor TMetaDataModuleItem.Create;
begin
  inherited;

  FTypes := TNameValueList.Create;
  FTemplates := TTemplateList.Create;
  FAttributeSets := TAttributeSetList.Create;
  FTables := TTableList.Create;
end;

destructor TMetaDataModuleItem.Destroy;
begin
  FTypes.Free;
  FTemplates.Free;
  FAttributeSets.Free;
  FTables.Free;
  inherited;
end;

function TMetaDataModuleList.GetTemplate(const ATemplateName: string): TTemplateItem;
var
  lIdx : integer;
begin
  Result := nil;
  for lIdx := 0 to Count - 1 do
  begin
    Result := Items[lIdx].Templates.FindByName(ATemplateName);
    if Assigned(Result) then
      Break;
  end;

  if not Assigned(Result) then
    raise Exception.CreateFmt('Invalid template reference %s', [ATemplateName]);
end;

constructor TMetaDataModuleList.Create;
begin
  inherited;

  FData := TNameValueList.Create;
  FAttributeSets := TAttributeSetList.Create;
end;

destructor TMetaDataModuleList.Destroy;
begin
  FData.Free;
  FAttributeSets.Free;

  inherited;
end;

function TMetaDataModuleList.GetAttributeSet(const AAttributeSetName: string): TAttributeSetItem;
var
  lIdx : integer;
begin
  Result := nil;
  for lIdx := 0 to Count - 1 do
  begin
    Result := Items[lIdx].AttributeSets.FindByName(AAttributeSetName);
    if Assigned(Result) then
      Break;
  end;

  if not Assigned(Result) then
    raise Exception.CreateFmt('Invalid AttributeSet reference %s', [AAttributeSetName]);
end;

end.
