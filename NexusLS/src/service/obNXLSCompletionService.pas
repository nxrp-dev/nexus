unit obNXLSCompletionService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext;

type
  TNXLSCompletionService = class(TNXLSLSPService)
  public
    procedure FillCompletionItems(AParams: TNXLSCompletionParams;
      AResult: TNXLSCompletionItemArray); virtual;
    function FillSignatureHelp(AParams: TNXLSSignatureHelpParams;
      AResult: TNXLSSignatureHelp): Boolean; virtual;
  end;

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  BasicCodeTools,
  CodeCache,
  CodeToolManager,
  CodeTree,
  FindDeclarationTool,
  IdentCompletionTool,
  PascalParserTool,
  obNXLSProtocolBase,
  utNXLSServiceHelpers;

function NXLSCompletionKind(AIdentifier: TIdentifierListItem): Integer;
var
  lDesc: TCodeTreeNodeDesc;
begin
  if AIdentifier.Node = nil then
    lDesc := AIdentifier.DefaultDesc
  else
    lDesc := AIdentifier.Node.Desc;

  case lDesc of
    ctnUnit, ctnUseUnit, ctnUseUnitClearName, ctnUseUnitNamespace:
      Result := 9;  // Module
    ctnClass, ctnObject, ctnObjCClass, ctnObjCCategory, ctnCPPClass,
    ctnTypeHelper, ctnRecordHelper:
      Result := 7;  // Class
    ctnRecordType:
      Result := 22; // Struct
    ctnClassInterface, ctnDispinterface, ctnObjCProtocol:
      Result := 8;  // Interface
    ctnProcedure:
      Result := 3;  // Function
    ctnTypeDefinition, ctnGenericType, ctnGenericParameter:
      Result := 25; // TypeParameter
    ctnProperty, ctnGlobalProperty:
      Result := 10; // Property
    ctnVarDefinition:
      Result := 6;  // Variable
    ctnConstDefinition:
      Result := 21; // Constant
    ctnEnumerationType:
      Result := 13; // Enum
    ctnEnumIdentifier:
      Result := 20; // EnumMember
  else
    Result := 14;   // Keyword
  end;
end;

function NXLSSplitParamString(const AValue: string; ADelimiter: Char): TStringList;
var
  lIdx: Integer;
  lPart: string;
begin
  Result := TStringList.Create;
  lPart := '';
  for lIdx := 1 to Length(AValue) do
  begin
    if AValue[lIdx] = ADelimiter then
    begin
      Result.Add(Trim(lPart));
      lPart := '';
    end
    else
      lPart := lPart + AValue[lIdx];
  end;
  if Trim(lPart) <> '' then
    Result.Add(Trim(lPart));
end;

function NXLSParseParamList(const AValue: string): TStringList;
var
  lGroups: TStringList;
  lNames: TStringList;
  lIdx: Integer;
  lNameIdx: Integer;
  lColonPos: Integer;
  lTypeName: string;
begin
  Result := TStringList.Create;
  lGroups := NXLSSplitParamString(AValue, ';');
  try
    for lIdx := 0 to lGroups.Count - 1 do
    begin
      lColonPos := Pos(':', lGroups[lIdx]);
      if lColonPos <= 0 then
        Continue;

      lTypeName := Trim(Copy(lGroups[lIdx], lColonPos + 1, MaxInt));
      lNames := NXLSSplitParamString(Copy(lGroups[lIdx], 1, lColonPos - 1), ',');
      try
        for lNameIdx := 0 to lNames.Count - 1 do
          if lNames[lNameIdx] <> '' then
            Result.Add(lNames[lNameIdx] + ': ' + lTypeName);
      finally
        lNames.Free;
      end;
    end;
  finally
    lGroups.Free;
  end;
end;

procedure NXLSSetJSONString(AValue: TNXJSONRPCValue; const AText: string);
var
  lJSON: TJSONData;
begin
  lJSON := TJSONString.Create(AText);
  try
    AValue.FromJSONData(lJSON);
  finally
    lJSON.Free;
  end;
end;

function NXLSWordMatchesPrefix(const AWord, APrefix: string): Boolean;
begin
  Result := (APrefix = '') or (Pos(LowerCase(APrefix), LowerCase(AWord)) = 1);
end;

procedure NXLSAddCompletionItem(ATarget: TNXJSONArray; ASeen: TStrings;
  const ALabel: string; AKind: Integer; const ADetail: string);
var
  lItem: TNXLSCompletionItem;
begin
  if (ALabel = '') or (ASeen.IndexOf(ALabel) >= 0) then
    Exit;

  ASeen.Add(ALabel);
  lItem := TNXLSCompletionItem(ATarget.AddObject(TNXLSCompletionItem));
  lItem.&label.Value := ALabel;
  lItem.kind.Value := AKind;
  if ADetail <> '' then
    lItem.detail.Value := ADetail;
  lItem.sortText.Value := IntToStr(ASeen.Count);
  lItem.Assigned := True;
end;

procedure NXLSAddSourceCompletions(ATarget: TNXJSONArray; ASeen: TStrings;
  ACode: TCodeBuffer; const APrefix: string);
var
  lIdx: Integer;
  lName: string;
begin
  if ACode = nil then
    Exit;

  for lIdx := 0 to ACode.LineCount - 1 do
  begin
    lName := NXLSIdentifierAfterKeyword(ACode.GetLine(lIdx), 'procedure');
    if NXLSWordMatchesPrefix(lName, APrefix) then
      NXLSAddCompletionItem(ATarget, ASeen, lName, 3, 'source procedure');

    lName := NXLSIdentifierAfterKeyword(ACode.GetLine(lIdx), 'function');
    if NXLSWordMatchesPrefix(lName, APrefix) then
      NXLSAddCompletionItem(ATarget, ASeen, lName, 3, 'source function');
  end;
end;

procedure NXLSAddSignatureFromHead(AResult: TNXLSSignatureHelp; const AHead: string;
  AActiveParameter: Integer);
var
  lSignature: TNXLSSignatureInformation;
  lParameter: TNXLSParameterInformation;
  lParamList: TStringList;
  lParamIdx: Integer;
  lProcName: string;
  lParamText: string;
begin
  lProcName := NXLSProcNameFromHead(AHead);
  if lProcName = '' then
    Exit;

  lParamText := NXLSParamTextFromHead(AHead);
  lSignature := TNXLSSignatureInformation(
    AResult.signatures.AddObject(TNXLSSignatureInformation));
  lSignature.&label.Value := Trim(AHead);
  lSignature.activeParameter.Value := AActiveParameter;

  lParamList := NXLSParseParamList(lParamText);
  try
    for lParamIdx := 0 to lParamList.Count - 1 do
    begin
      lParameter := TNXLSParameterInformation(
        lSignature.parameters.AddObject(TNXLSParameterInformation));
      NXLSSetJSONString(lParameter.&label, lParamList[lParamIdx]);
      lParameter.Assigned := True;
    end;
  finally
    lParamList.Free;
  end;

  lSignature.parameters.Assigned := lSignature.parameters.Count > 0;
  lSignature.Assigned := True;
end;

function NXLSCallIdentifierNear(ACode: TCodeBuffer; AX, AY: Integer): string;
var
  lLine: string;
  lPos: Integer;
  lEnd: Integer;
  lStart: Integer;
begin
  Result := '';
  if ACode = nil then
    Exit;

  lLine := ACode.GetLine(AY);
  lPos := AX;
  if lPos > Length(lLine) then
    lPos := Length(lLine);

  while (lPos >= 1) and (lLine[lPos] <> '(') do
    Dec(lPos);
  if lPos < 1 then
    Exit;

  Dec(lPos);
  while (lPos >= 1) and (lLine[lPos] = ' ') do
    Dec(lPos);
  if lPos < 1 then
    Exit;

  lEnd := lPos;
  while (lPos >= 1) and
    (lLine[lPos] in ['A'..'Z', 'a'..'z', '_', '.', '0'..'9']) do
    Dec(lPos);
  lStart := lPos + 1;
  Result := Copy(lLine, lStart, lEnd - lStart + 1);
  if Pos('.', Result) > 0 then
    Result := Copy(Result, LastDelimiter('.', Result) + 1, MaxInt);
end;

function NXLSFindDeclarationHead(ACode: TCodeBuffer; const AIdentifier: string): string;
var
  lIdx: Integer;
  lName: string;
begin
  Result := '';
  if (ACode = nil) or (AIdentifier = '') then
    Exit;

  for lIdx := 0 to ACode.LineCount - 1 do
  begin
    lName := NXLSProcNameFromHead(ACode.GetLine(lIdx));
    if CompareText(lName, AIdentifier) = 0 then
      Exit(Trim(ACode.GetLine(lIdx)));
  end;
end;

function NXLSActiveParameterAt(ACode: TCodeBuffer; AX, AY: Integer): Integer;
var
  lLine: string;
  lIdx: Integer;
begin
  Result := 0;
  if ACode = nil then
    Exit;

  lLine := ACode.GetLine(AY);
  if AX > Length(lLine) then
    AX := Length(lLine);

  lIdx := AX;
  while (lIdx >= 1) and (lLine[lIdx] <> '(') do
  begin
    if lLine[lIdx] = ',' then
      Inc(Result);
    Dec(lIdx);
  end;
end;

function NXLSFillFallbackSignatureHelp(ACode: TCodeBuffer; AX, AY: Integer;
  AResult: TNXLSSignatureHelp): Boolean;
var
  lIdentifier: string;
  lHead: string;
  lActiveParameter: Integer;
begin
  Result := False;
  if AResult = nil then
    Exit;

  lIdentifier := NXLSCallIdentifierNear(ACode, AX, AY);
  lHead := NXLSFindDeclarationHead(ACode, lIdentifier);
  if lHead = '' then
    Exit;

  lActiveParameter := NXLSActiveParameterAt(ACode, AX, AY);
  AResult.activeSignature.Value := 0;
  AResult.activeParameter.Value := lActiveParameter;
  NXLSAddSignatureFromHead(AResult, lHead, lActiveParameter);
  AResult.signatures.Assigned := AResult.signatures.Count > 0;
  AResult.Assigned := AResult.signatures.Count > 0;
  Result := AResult.Assigned;
end;

procedure TNXLSCompletionService.FillCompletionItems(AParams: TNXLSCompletionParams;
  AResult: TNXLSCompletionItemArray);
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lLine: string;
  lIdentStart: Integer;
  lIdentEnd: Integer;
  lIdx: Integer;
  lCount: Integer;
  lIdentifier: TIdentifierListItem;
  lSeen: TStringList;
  lPrefix: string;
begin
  if AResult = nil then
    Exit;
  if (AParams = nil) or (AParams.textDocument = nil) or
    (AParams.position = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lCode := lDocument.CodeBuffer;
  if lCode = nil then
    Exit;
  if (AParams.position.line.Value < 0) or
    (AParams.position.line.Value >= lCode.LineCount) then
    Exit;

  lLine := lCode.GetLine(AParams.position.line.Value);
  GetIdentStartEndAtPosition(lLine, AParams.position.character.Value + 1,
    lIdentStart, lIdentEnd);
  lPrefix := Copy(lLine, lIdentStart, lIdentEnd - lIdentStart);
  CodeToolBoss.IdentifierList.Prefix := lPrefix;

  lSeen := TStringList.Create;
  try
    lSeen.Sorted := True;
    lSeen.Duplicates := dupIgnore;
    if CodeToolBoss.GatherIdentifiers(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value + 1) then
    begin
      lCount := CodeToolBoss.IdentifierList.GetFilteredCount;
      for lIdx := 0 to lCount - 1 do
      begin
        lIdentifier := CodeToolBoss.IdentifierList.FilteredItems[lIdx];
        if (lIdentifier = nil) or (lIdentifier.Identifier = '') then
          Continue;

        NXLSAddCompletionItem(AResult, lSeen, lIdentifier.Identifier,
          NXLSCompletionKind(lIdentifier), '');
      end;
    end;

    NXLSAddSourceCompletions(AResult, lSeen, lCode, lPrefix);
  finally
    lSeen.Free;
  end;
end;

function TNXLSCompletionService.FillSignatureHelp(
  AParams: TNXLSSignatureHelpParams; AResult: TNXLSSignatureHelp): Boolean;
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lContext: TCodeContextInfo;
  lContextIdx: Integer;
  lItem: TCodeContextInfoItem;
  lExpr: TExpressionType;
  lNode: TCodeTreeNode;
  lTool: TFindDeclarationTool;
  lSignature: TNXLSSignatureInformation;
  lParameter: TNXLSParameterInformation;
  lParams: string;
  lResultType: string;
  lParamList: TStringList;
  lParamIdx: Integer;
  lDeclCode: TCodeBuffer;
  lDeclX: Integer;
  lDeclY: Integer;
  lTopLine: Integer;
begin
  Result := False;
  if AResult = nil then
    Exit;
  if (AParams = nil) or (AParams.textDocument = nil) or
    (AParams.position = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lCode := lDocument.CodeBuffer;
  if lCode = nil then
    Exit;
  if (AParams.position.line.Value < 0) or
    (AParams.position.line.Value >= lCode.LineCount) then
    Exit;

  lContext := nil;
  if not CodeToolBoss.FindCodeContext(lCode, AParams.position.character.Value + 1,
    AParams.position.line.Value + 1, lContext) or (lContext = nil) or
    (lContext.Count = 0) then
  begin
    if CodeToolBoss.FindMainDeclaration(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value + 1,
      lDeclCode, lDeclX, lDeclY, lTopLine) then
    begin
      AResult.activeSignature.Value := 0;
      AResult.activeParameter.Value := 0;
      NXLSAddSignatureFromHead(AResult,
        Trim(lDeclCode.GetLine(lDeclY - 1)), 0);
      AResult.signatures.Assigned := AResult.signatures.Count > 0;
      AResult.Assigned := AResult.signatures.Count > 0;
      Result := AResult.Assigned;
    end;
    if not Result then
      Result := NXLSFillFallbackSignatureHelp(lCode,
        AParams.position.character.Value + 1, AParams.position.line.Value,
        AResult);
    Exit;
  end;

  try
    AResult.activeSignature.Value := 0;
    AResult.activeParameter.Value := lContext.ParameterIndex - 1;

    for lContextIdx := 0 to lContext.Count - 1 do
    begin
      lItem := lContext[lContextIdx];
      lExpr := lItem.Expr;
      if (lExpr.Context.Node = nil) or
        (not (lExpr.Context.Tool is TFindDeclarationTool)) then
        Continue;

      lNode := lExpr.Context.Node;
      lTool := TFindDeclarationTool(lExpr.Context.Tool);
      if lNode.Desc <> ctnProcedure then
        Continue;

      lResultType := lTool.ExtractProcHead(lNode,
        [phpWithoutClassName, phpWithoutName, phpWithoutGenericParams,
         phpWithoutParamList, phpWithoutParamTypes, phpWithoutBrackets,
         phpWithoutSemicolon, phpWithResultType]);

      lParams := lTool.ExtractProcHead(lNode,
        [phpWithoutName, phpWithoutBrackets, phpWithoutSemicolon,
         phpWithVarModifiers, phpWithParameterNames, phpWithDefaultValues]);

      lSignature := TNXLSSignatureInformation(
        AResult.signatures.AddObject(TNXLSSignatureInformation));
      if lParams <> '' then
        lSignature.&label.Value := lContext.ProcName + '(' + lParams + ')' + lResultType
      else
        lSignature.&label.Value := lContext.ProcName + lResultType;
      lSignature.activeParameter.Value := lContext.ParameterIndex - 1;

      lParamList := NXLSParseParamList(lParams);
      try
        for lParamIdx := 0 to lParamList.Count - 1 do
        begin
          lParameter := TNXLSParameterInformation(
            lSignature.parameters.AddObject(TNXLSParameterInformation));
          NXLSSetJSONString(lParameter.&label, lParamList[lParamIdx]);
          lParameter.Assigned := True;
        end;
      finally
        lParamList.Free;
      end;

      lSignature.parameters.Assigned := lSignature.parameters.Count > 0;
      lSignature.Assigned := True;
    end;

    AResult.signatures.Assigned := AResult.signatures.Count > 0;
    AResult.Assigned := AResult.signatures.Count > 0;
    Result := AResult.Assigned;
    if not Result then
      Result := NXLSFillFallbackSignatureHelp(lCode,
        AParams.position.character.Value + 1, AParams.position.line.Value,
        AResult);
  finally
    lContext.Free;
  end;
end;

end.
