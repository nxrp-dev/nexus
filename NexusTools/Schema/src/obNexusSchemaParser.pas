unit obNexusSchemaParser;

interface

uses classes, sysutils, TypInfo, obNexusSchemaTypes, obNexusSchemaTokenizer, obTokenQueue,
  obMetaDataModuleList, obMetaDataModel;

{$M+}

type
  TNexusSchemaParser = class(TObject)
  private
    FMetadata : TMetaDataModuleList;
    FModule : TMetaDataModuleItem;

    procedure ProcessScript(ATokenList: TTokenQueue);
    procedure ProcessUses(const AFilename : string);
    function ResolveSourceFilename(const AFilename: string): string;
    procedure ProcessKeyword(AKeyword : TToken; ATokenList : TTokenQueue);
    procedure ProcessIdentifier(AIdentifier : TToken; ATokenList: TTokenQueue);
    procedure ProcessVar(ATokenList: TTokenQueue);
    procedure ProcessTable(const ATableName : string; ATokenList: TTokenQueue);
    procedure ProcessAttributes(const AContextName: string; ATokenList: TTokenQueue);
    procedure ProcessType(ATokenList: TTokenQueue);
    procedure ProcessTemplate(const ATemplateName: string; ATokenList: TTokenQueue);

    procedure LoadAttributes(ATable : TTemplateItem; ATokenList: TTokenQueue);
    procedure LoadFieldAttributes(AField : TFieldItem; ATokenList: TTokenQueue);

    procedure LoadFields(ATable : TTemplateItem; ATokenList: TTokenQueue);
    procedure LoadTableData(ATable: TTableItem; ATokenList: TTokenQueue);
    procedure LoadTemplates(ATable : TTemplateItem; ATokenList: TTokenQueue);

    function TokenIsKeyword(AToken: TToken; const AKeyword: string): boolean;
    function TokenIsOperator(AToken: TToken; const AOperator: string): boolean;
    procedure SkipLineTerms(ATokenList: TTokenQueue);
    function ValidatePop(ATokens : TTokenSet; const AKeywords : array of string; const AOperators : array of string; ATokenList : TTokenQueue) : TToken;
    procedure GetIdentifierList(AList: TNameList; ATokenList: TTokenQueue);
    function ValidateToken(ATokens: TTokenSet; const AKeywords: array of string; const AOperators: array of string; AToken: TToken): TToken;
    procedure GetNameDefined(out AValue : string; ATokenList : TTokenQueue);
    procedure GetNameValueBlock(AList: TNameValueList; ATokenList: TTokenQueue);
    procedure ProcessTableDefinition(ATable : TTemplateItem; ATokenList: TTokenQueue);
    procedure GetFieldDefined(out AValue, AReferenceTable, AReferenceFieldName: string; out AIsReference: boolean; ATokenList: TTokenQueue);
    procedure ValidateObject(AToken: TToken; AClass: TClass;
      AValidClasses: array of TPersistentClass);
    procedure ProcessData(const AModuleName, AFilename: string; AAllowMultiple: boolean = False);
    procedure SetDefineAttribute(const AName, AValue: string);
    procedure LoadChildren(ATable: TTemplateItem; ATokenList: TTokenQueue);
  protected
    function ParseModule(AModule : PChar; const ATokenDefinition: TNexusSchemaTokenDefinition) : TTokenQueue;

  public
    procedure ExecuteFile(const AFilename : string);
    constructor Create(AMetaData : TMetaDataModuleList); virtual;
    destructor Destroy; override;
  published
  end;

implementation

{ TNexusSchemaParser }

function LoadSourceFile(const AFilename: string): string;
var
  lFile: TFileStream;
begin
  Result := '';
  lFile := TFileStream.Create(AFilename, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, lFile.Size);
    if lFile.Size > 0 then
      lFile.ReadBuffer(Result[1], lFile.Size);
  finally
    lFile.Free;
  end;
end;

procedure TNexusSchemaParser.ExecuteFile(const AFilename: string);
var
  lSource : string;
  lpFile : PChar;
  lTokenList : TTokenQueue;
begin
  lSource := LoadSourceFile(AFilename);
  lpFile := PChar(lSource);
  lTokenList := ParseModule(lpFile, DefaultNexusSchemaTokenDefinition);
  try
    ProcessScript(lTokenList);
  finally
    lTokenList.Free;
  end;
end;

function TNexusSchemaParser.TokenIsKeyword(AToken: TToken; const AKeyword: string): boolean;
begin
  Result := (AToken <> nil) and (AToken.TokenType = ttKeyword) and
    SameText(AToken.Text, AKeyword);
end;

function TNexusSchemaParser.TokenIsOperator(AToken: TToken; const AOperator: string): boolean;
begin
  Result := (AToken <> nil) and (AToken.TokenType = ttOperator) and
    SameText(AToken.Text, AOperator);
end;

procedure TNexusSchemaParser.SkipLineTerms(ATokenList: TTokenQueue);
begin
  while (ATokenList.Count > 0) and (ATokenList.Peek.TokenType = ttOperator) and
    TokenIsOperator(ATokenList.Peek, nxOpLineTerm) do
    ATokenList.Pop;
end;

procedure TNexusSchemaParser.SetDefineAttribute(const AName, AValue : string);
begin
  FMetadata.ExtraAttributes.Values[AName] := AValue
end;

function TNexusSchemaParser.ParseModule(AModule: PChar; const ATokenDefinition: TNexusSchemaTokenDefinition) : TTokenQueue;
begin
  FModule := FMetaData.AddObject('UNDEFINED');

  Result := TokenizeNexusSchemaModule(AModule, ATokenDefinition);
end;

procedure TNexusSchemaParser.LoadTemplates(ATable : TTemplateItem; ATokenList : TTokenQueue);
var
  lToken : TToken;
begin
  lToken := ATokenList.Peek;
  if TokenIsOperator(lToken, nxOpParamOpen) then
  begin
    ATable.TemplateReferences.Clear;
    GetIdentifierList(ATable.TemplateReferences, ATokenList);
  end;
end;

procedure TNexusSchemaParser.GetNameDefined(out AValue : string; ATokenList : TTokenQueue);
begin
  ValidatePop([ttOperator], [], [nxOpDefine], ATokenList);
  AValue := ValidatePop([ttString], [], [], ATokenList).Text;
  SkipLineTerms(ATokenList);
end;

procedure TNexusSchemaParser.GetNameValueBlock(AList : TNameValueList; ATokenList : TTokenQueue);
var
  lToken : TToken;
  lName,
  lValue : string;
begin
  if TokenIsOperator(ATokenList.Peek, nxOpBlockOpen) then
  begin
    ATokenList.Pop;
    SkipLineTerms(ATokenList);
    lToken := ValidatePop([ttIdentifier], [], [], ATokenList);
    while not TokenIsOperator(lToken, nxOpBlockClose) do
    begin
      lName := lToken.Text;
      GetNameDefined(lValue, ATokenList);
      AList.AddObject(lName).Value := lValue;

      SkipLineTerms(ATokenList);
      lToken := ValidatePop([ttIdentifier, ttString, ttOperator], [], [nxOpBlockClose, nxOpLineTerm, nxOpDefine], ATokenList);
    end;
  end;
  SkipLineTerms(ATokenList);
end;

procedure TNexusSchemaParser.ProcessType(ATokenList : TTokenQueue);
begin
  GetNameValueBlock(FModule.Types, ATokenList);
end;

procedure TNexusSchemaParser.ProcessAttributes(const AContextName : string; ATokenList : TTokenQueue);
var
  lAttributeSet: TAttributeSetItem;
begin
  lAttributeSet := FModule.AttributeSets.AddObject(AContextName);
  lAttributeSet.AttributeSet.Clear;
  GetNameValueBlock(lAttributeSet.AttributeSet, ATokenList);
end;

procedure TNexusSchemaParser.GetFieldDefined(out AValue, AReferenceTable, AReferenceFieldName : string; out AIsReference : boolean; ATokenList : TTokenQueue);
var
  lToken : TToken;
begin
  AValue := '';
  AReferenceTable := '';
  AReferenceFieldName := '';
  AIsReference := False;

  ValidatePop([ttOperator], [], [nxOpDefine], ATokenList);
  lToken := ValidatePop([ttString, ttIdentifier, ttOperator], [], [nxOpReference], ATokenList);
  case lToken.TokenType of
    ttString, ttIdentifier : AValue := lToken.Text;
    ttOperator :
    begin
      AValue := lToken.Text;

      AIsReference := True;

      lToken := ValidatePop([ttIdentifier], [], [], ATokenList);
      AReferenceTable := lToken.Text;
      AValue := AValue + lToken.Text;

      if TokenIsOperator(ATokenList.Peek, nxOpQualifier) then
      begin
        lToken := ValidatePop([ttOperator], [], [nxOpQualifier], ATokenList);
        AValue := AValue + lToken.Text;

        lToken := ValidatePop([ttIdentifier], [], [], ATokenList);
        AValue := AValue + lToken.Text;
        AReferenceFieldName := lToken.Text;
      end;
    end;
  end;
end;

procedure TNexusSchemaParser.LoadFields(ATable : TTemplateItem; ATokenList : TTokenQueue);
var
  lToken : TToken;
  lName, lValue : string;
  lReferencedTable, lReferencedFieldName : string;
  lIsReference : boolean;
  lField : TFieldItem;
begin
  SkipLineTerms(ATokenList);
  lToken := ATokenList.Pop;
  while not TokenIsOperator(lToken, nxOpBlockClose) do
  begin
    if TokenIsKeyword(lToken, kwData) then
    begin
      if not (ATable is TTableItem) then
        raise Exception.CreateFmt('%s is only valid inside table blocks.', [kwData]);

      LoadTableData(TTableItem(ATable), ATokenList);
      SkipLineTerms(ATokenList);
      lToken := ATokenList.Pop;
      Continue;
    end;

    ValidateToken([ttIdentifier], [], [], lToken);
    lName := lToken.Text;
    lField := ATable.Fields.AddObject(lName);
    if TokenIsOperator(ATokenList.Peek, nxOpParamOpen) then
      LoadFieldAttributes(lField, ATokenList);

    GetFieldDefined(lValue, lReferencedTable, lReferencedFieldName, lIsReference, ATokenList);

    lField.IsReference := lIsReference;
    if not lIsReference then
      lField.FieldType := lValue;
    lField.ReferenceEntity := lReferencedTable;
    lField.ReferencedFieldName := lReferencedFieldName;

    SkipLineTerms(ATokenList);
    SkipLineTerms(ATokenList);
    lToken := ATokenList.Pop;
  end;
end;

function ContainsTextValue(const AValues: array of string; const AValue: string): boolean;
var
  lIdx: integer;
begin
  Result := False;
  for lIdx := Low(AValues) to High(AValues) do
  begin
    if SameText(AValues[lIdx], AValue) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function ExpectedText(const AValues: array of string): string;
var
  lIdx: integer;
begin
  Result := '';
  for lIdx := Low(AValues) to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + AValues[lIdx];
  end;
end;

function TokenLocation(AToken: TToken): string;
begin
  if Assigned(AToken) then
    Result := Format('Line:%d Column:%d Position:%d', [AToken.Line, AToken.Column, AToken.Position])
  else
    Result := 'end of file';
end;

function TokenTypeToString(ATokenType: TTokenType): string;
begin
  Result := GetEnumName(TypeInfo(TTokenType), Ord(ATokenType));
  if Pos('tt', Result) = 1 then
    Delete(Result, 1, 2);
end;

function TokenSetToString(ATokens: TTokenSet): string;
var
  lToken: TTokenType;
begin
  Result := '';
  for lToken := Low(TTokenType) to High(TTokenType) do
  begin
    if lToken in ATokens then
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + TokenTypeToString(lToken);
    end;
  end;
end;

function TNexusSchemaParser.ValidateToken(ATokens : TTokenSet; const AKeywords : array of string; const AOperators : array of string; AToken : TToken) : TToken;
begin
  Result := AToken;

  if not Assigned(Result) then
    raise Exception.CreateFmt('%s expected but %s found.', [TokenSetToString(ATokens), TokenLocation(Result)]);

  if (ATokens <> []) and not (Result.TokenType in ATokens) then
    raise Exception.CreateFmt('%s expected but %s (%s) (%s) found.', [TokenSetToString(ATokens), TokenTypeToString(Result.TokenType), Result.Text, TokenLocation(Result)]);

  if (Length(AKeywords) > 0) and (Result.TokenType = ttKeyword) and not ContainsTextValue(AKeywords, Result.Text) then
    raise Exception.CreateFmt('%s expected but %s (%s) (%s) found.', [ExpectedText(AKeywords), Result.Text, Result.Text, TokenLocation(Result)]);

  if (Length(AOperators) > 0) and (Result.TokenType = ttOperator) and not ContainsTextValue(AOperators, Result.Text) then
    raise Exception.CreateFmt('%s expected but %s (%s) (%s) found.', [ExpectedText(AOperators), Result.Text, Result.Text, TokenLocation(Result)]);
end;

procedure TNexusSchemaParser.ValidateObject(AToken : TToken; AClass : TClass; AValidClasses: array of TPersistentClass);
var
  lIdx : Integer;
  lValid : boolean;
begin
  lValid := False;
  for lIdx := Low(AValidClasses) to High(AValidClasses) do
  begin
    lValid := AClass = AValidClasses[lIdx];
    if lValid then
      Break;
  end;

  if not lValid then
    raise Exception.CreateFmt('%s not valid for use on object (%s).', [AToken.Text, AClass.ClassName]);
end;

procedure TNexusSchemaParser.LoadAttributes(ATable : TTemplateItem; ATokenList : TTokenQueue);
begin
  GetIdentifierList(ATable.AttributeReferences, ATokenList);
end;

procedure TNexusSchemaParser.LoadChildren(ATable : TTemplateItem; ATokenList : TTokenQueue);
begin
  GetIdentifierList(ATable.ChildReferences, ATokenList);
end;

procedure TNexusSchemaParser.ProcessTableDefinition(ATable : TTemplateItem; ATokenList : TTokenQueue);
var
  lToken : TToken;
begin
  LoadTemplates(ATable, ATokenList);

  SkipLineTerms(ATokenList);
  while TokenIsKeyword(ATokenList.Peek, kwAttributes) or TokenIsKeyword(ATokenList.Peek, kwChildren) do
  begin
    lToken := ValidatePop([ttKeyword], [kwAttributes, kwChildren], [], ATokenList);
    if TokenIsKeyword(lToken, kwAttributes) then
      LoadAttributes(ATable, ATokenList)
    else if TokenIsKeyword(lToken, kwChildren) then
      LoadChildren(ATable, ATokenList);
    SkipLineTerms(ATokenList);
  end;

  if TokenIsOperator(ATokenList.Peek, nxOpBlockOpen) then
  begin
    ATokenList.Pop;
    LoadFields(ATable, ATokenList);
    SkipLineTerms(ATokenList);
  end;
end;

procedure TNexusSchemaParser.ProcessTable(const ATableName : string; ATokenList : TTokenQueue);
var
  lTable : TTableItem;
begin
  try
    lTable := FModule.Tables.AddObject(ATableName);
    ProcessTableDefinition(lTable, ATokenList);
  except on E:Exception do
    raise Exception.CreateFmt('Error [Table : %s]: %s', [ATableName, e.Message]);
  end;
end;

procedure TNexusSchemaParser.ProcessTemplate(const ATemplateName : string; ATokenList : TTokenQueue);
var
  lTemplate : TTemplateItem;
begin
  lTemplate := FModule.Templates.AddObject(ATemplateName);
  ProcessTableDefinition(lTemplate, ATokenList);
end;

procedure TNexusSchemaParser.GetIdentifierList(AList : TNameList; ATokenList : TTokenQueue);
var
  lToken : TToken;
begin
  lToken := ValidatePop([ttOperator], [], [nxOpParamOpen], ATokenList);
  while not TokenIsOperator(lToken, nxOpParamClose) do
  begin
    case lToken.TokenType of
      ttOperator : ; // skip it....
      ttIdentifier : AList.AddObject(lToken.Text);
    end;
    lToken := ValidatePop([ttOperator, ttIdentifier], [], [nxOpParamNext, nxOpParamClose], ATokenList);
  end;
end;

procedure TNexusSchemaParser.LoadTableData(ATable: TTableItem; ATokenList: TTokenQueue);
var
  lToken : TToken;
begin
  lToken := ValidatePop([ttString], [], [], ATokenList);
  ProcessData(ATable.Name, lToken.Text, True);
end;

function TNexusSchemaParser.ValidatePop(ATokens : TTokenSet; const AKeywords : array of string; const AOperators : array of string; ATokenList : TTokenQueue) : TToken;
begin
  Result := ATokenList.Pop;
  ValidateToken(ATokens, AKeywords, AOperators, Result);
end;

procedure TNexusSchemaParser.ProcessIdentifier(AIdentifier : TToken; ATokenList : TTokenQueue);
var
  lIdentifier : string;
  lToken : TToken;
begin
  lIdentifier := AIdentifier.Text;

  ValidatePop([ttOperator], [], [nxOpAssign], ATokenList);

  lToken := ValidatePop([ttKeyword], [kwTable, kwTemplate, kwType, kwAttributes], [], ATokenList);

  if TokenIsKeyword(lToken, kwTable) then
    ProcessTable(lIdentifier, ATokenList)
  else if TokenIsKeyword(lToken, kwTemplate) then
    ProcessTemplate(lIdentifier, ATokenList)
  else if TokenIsKeyword(lToken, kwType) then
    ProcessType(ATokenList)
  else if TokenIsKeyword(lToken, kwAttributes) then
    ProcessAttributes(lIdentifier, ATokenList);
end;

procedure TNexusSchemaParser.ProcessVar(ATokenList: TTokenQueue);
var
  lName: string;
  lValue: string;
  lToken: TToken;
begin
  lName := ValidatePop([ttIdentifier], [], [], ATokenList).Text;

  if TokenIsOperator(ATokenList.Peek, nxOpAssign) then
  begin
    ATokenList.Pop;
    lToken := ValidatePop([ttString, ttIdentifier], [], [], ATokenList);
    lValue := lToken.Text;
    SkipLineTerms(ATokenList);
  end
  else
    lValue := 'true';

  SetDefineAttribute(lName, lValue);
end;

procedure TNexusSchemaParser.ProcessUses(const AFilename : string);
var
  lParser : TNexusSchemaParser;
begin
  lParser := TNexusSchemaParser.Create(FMetadata);
  try
    lParser.ExecuteFile(ResolveSourceFilename(AFilename));
  finally
    lParser.Free;
  end;
end;

function TNexusSchemaParser.ResolveSourceFilename(const AFilename: string): string;
begin
  Result := AFilename;

  if FileExists(Result) then
    Exit;

  Result := ExtractFileName(AFilename);
  if FileExists(Result) then
    Exit;

  Result := AFilename;
end;

procedure TNexusSchemaParser.ProcessData(const AModuleName, AFilename : string; AAllowMultiple: boolean);
var
  lName : string;
  lIdx : integer;
begin
  lName := AModuleName;
  if AAllowMultiple then
  begin
    lIdx := 1;
    while FMetadata.Data.IndexOf(lName) > -1 do
    begin
      Inc(lIdx);
      lName := AModuleName + IntToStr(lIdx);
    end;
  end;

  FMetadata.Data.AddObject(lName).Value := AFilename;
end;

procedure TNexusSchemaParser.ProcessKeyword(AKeyword : TToken; ATokenList : TTokenQueue);
var
  lToken : TToken;
  lModuleToken : TToken;
begin
  if TokenIsKeyword(AKeyword, kwUses) then
  begin
    lToken := ValidatePop([ttString], [], [], ATokenList);
    ProcessUses(lToken.Text);
  end
  else if TokenIsKeyword(AKeyword, kwData) then
  begin
    lModuleToken := ValidatePop([ttIdentifier], [], [], ATokenList);
    lToken := ValidatePop([ttString], [], [], ATokenList);
    ProcessData(lModuleToken.Text, lToken.Text);
  end
  else if TokenIsKeyword(AKeyword, kwVar) then
  begin
    ProcessVar(ATokenList);
    Exit;
  end;
  SkipLineTerms(ATokenList);
end;

procedure TNexusSchemaParser.ProcessScript(ATokenList : TTokenQueue);
var
  lModuleName : string;
  lToken : TToken;
begin
  ValidatePop([ttKeyword], [kwModule], [], ATokenList);
  lModuleName := ValidatePop([ttIdentifier], [], [], ATokenList).Text;
  SkipLineTerms(ATokenList);

  FModule.Name := lModuleName;

  while ATokenList.Count > 0 do
  begin
    SkipLineTerms(ATokenList);
    if ATokenList.Count = 0 then
      Break;
    lToken := ValidatePop([ttIdentifier, ttKeyword], [kwUses, kwData, kwVar], [], ATokenList);
    case lToken.TokenType of
      ttIdentifier : ProcessIdentifier(lToken, ATokenList);
      ttKeyword : ProcessKeyword(lToken, ATokenList);
    end;
  end;
end;

constructor TNexusSchemaParser.Create(AMetaData : TMetaDataModuleList);
begin
  FMetadata := AMetaData;
end;

destructor TNexusSchemaParser.Destroy;
begin

  inherited;
end;

procedure TNexusSchemaParser.LoadFieldAttributes(AField: TFieldItem; ATokenList: TTokenQueue);
begin
  GetIdentifierList(AField.AttributeReferences, ATokenList);
end;

end.

