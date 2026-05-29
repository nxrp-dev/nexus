unit obNXLSCommandService;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXJSONValues,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSCommandService = class(TNXLSLSPService)
  private
    procedure ApplyTextEdit(const AURI, ANewText: string;
      AStartLine, AStartCharacter, AEndLine, AEndCharacter: Integer);
    procedure ApplyFullDocumentEdit(const AURI, ANewText: string);
    procedure ExecuteCompleteCode(AParams: TNXLSExecuteCommandParams);
    procedure ExecuteInvertAssignment(AParams: TNXLSExecuteCommandParams);
    procedure ExecuteRemoveEmptyMethods(AParams: TNXLSExecuteCommandParams);
    procedure ExecuteRemoveUnusedUnits(AParams: TNXLSExecuteCommandParams);
  public
    function ExecuteCommand(AParams: TNXLSExecuteCommandParams): TNXJSONValue; virtual;
  end;

implementation

uses
  SysUtils,
  fpjson,
  BasicCodeTools,
  CodeCache,
  CodeToolManager,
  CodeToolsStructs,
  FindDeclarationTool,
  PascalParserTool,
  SourceChanger,
  obNXLSProjectService,
  obNXLSProtocolObjects,
  utNXLSCommandNames;

type
  TNXLSInvertAssignOption = (iaoSpaceBefore, iaoSpaceAfter, iaoAlign);
  TNXLSInvertAssignOptions = set of TNXLSInvertAssignOption;

  TNXLSInvertAssignment = class
  private
    FOptions: TNXLSInvertAssignOptions;
    class procedure DivideLines(ALines: TStrings; var APreList, AAList, ABList,
      APostList: TStrings); virtual;
    class function GetIndent(const ALine: string): Integer; virtual;
    class function IsAWholeLine(const ALine: string): Boolean; virtual;
    function InvertLine(const APreVar, AVarA, AVarB, APostVar: string;
      ALineStart, AEqualPosition: Integer): string; virtual;
  public
    constructor Create;
    function InvertAssignment(const AText: string): string;
    procedure InvertAssignment(ALines: TStrings);
    property Options: TNXLSInvertAssignOptions read FOptions write FOptions;
  end;

function NXLSArgument(AParams: TNXLSExecuteCommandParams; AIndex: Integer): TNXJSONValue;
begin
  if (AParams = nil) or (AParams.arguments = nil) or
    (AIndex < 0) or (AIndex >= AParams.arguments.Count) then
    raise Exception.CreateFmt('Command argument %d is required.', [AIndex]);

  Result := AParams.arguments[AIndex];
end;

function NXLSArgumentString(AParams: TNXLSExecuteCommandParams; AIndex: Integer): string;
begin
  Result := NXLSArgument(AParams, AIndex).AsString;
  if Result = '' then
    raise Exception.CreateFmt('Command argument %d must be a non-empty string.', [AIndex]);
end;

procedure NXLSArgumentPosition(AParams: TNXLSExecuteCommandParams; AIndex: Integer;
  out ALine, ACharacter: Integer);
var
  lData: TJSONData;
  lValue: TJSONData;
begin
  lData := NXLSArgument(AParams, AIndex).ToJSONData;
  try
    if (lData = nil) or (lData.JSONType <> jtObject) then
      raise Exception.CreateFmt('Command argument %d must be a position object.', [AIndex]);

    lValue := TJSONObject(lData).Find('line');
    if (lValue = nil) or (lValue.JSONType <> jtNumber) then
      raise Exception.CreateFmt('Command argument %d position.line is required.', [AIndex]);
    ALine := lValue.AsInteger;

    lValue := TJSONObject(lData).Find('character');
    if (lValue = nil) or (lValue.JSONType <> jtNumber) then
      raise Exception.CreateFmt('Command argument %d position.character is required.', [AIndex]);
    ACharacter := lValue.AsInteger;
  finally
    lData.Free;
  end;
end;

procedure NXLSAddPosition(AObject: TJSONObject; const AName: string; ALine,
  ACharacter: Integer);
var
  lPosition: TJSONObject;
begin
  if ALine < 0 then
    ALine := 0;
  if ACharacter < 0 then
    ACharacter := 0;

  lPosition := TJSONObject.Create;
  lPosition.Add('line', ALine);
  lPosition.Add('character', ACharacter);
  AObject.Add(AName, lPosition);
end;

function NXLSWholeDocumentEndLine(ACode: TCodeBuffer): Integer;
begin
  Result := 0;
  if (ACode <> nil) and (ACode.LineCount > 0) then
    Result := ACode.LineCount - 1;
end;

function NXLSWholeDocumentEndCharacter(ACode: TCodeBuffer): Integer;
begin
  Result := 0;
  if (ACode <> nil) and (ACode.LineCount > 0) then
    Result := Length(ACode.GetLine(ACode.LineCount - 1));
end;

class function TNXLSInvertAssignment.GetIndent(const ALine: string): Integer;
begin
  Result := Length(ALine) - Length(TrimLeft(ALine));
end;

class function TNXLSInvertAssignment.IsAWholeLine(const ALine: string): Boolean;
var
  lLower: string;
begin
  lLower := LowerCase(ALine);
  Result := (Pos(';', ALine) > 0) or
    (Pos('if ', lLower) > 0) or
    (Pos('begin', lLower) > 0) or
    (Pos('end', lLower) > 0) or
    (Pos('then', lLower) > 0) or
    (Pos('else', lLower) > 0) or
    (Pos('and', lLower) > 0) or
    (Pos('or', lLower) > 0) or
    (Pos('//', ALine) > 0);
end;

class procedure TNXLSInvertAssignment.DivideLines(ALines: TStrings; var APreList,
  AAList, ABList, APostList: TStrings);
var
  lLine: string;
  lTrue: Boolean;
  lFalse: Boolean;
  lIdx: Integer;
  lScan: Integer;
  lEqPos: Integer;
  lSemiPos: Integer;
  lWordEndPos: Integer;
  lBracketCount: Integer;
  lTrueFalse: string;
begin
  for lIdx := 0 to ALines.Count - 1 do
  begin
    lLine := Trim(ALines[lIdx]);
    lEqPos := Pos(':=', lLine);
    if lEqPos > 0 then
    begin
      lSemiPos := Pos(';', lLine);
      if lSemiPos = 0 then
        lSemiPos := Length(lLine) + 1;

      lScan := lEqPos - 1;
      while (lScan > 0) and (lLine[lScan] = ' ') do
        Dec(lScan);
      lWordEndPos := lScan + 1;
      lBracketCount := 0;
      while lScan > 0 do
      begin
        if lLine[lScan] = ']' then
          Inc(lBracketCount)
        else if lLine[lScan] = '[' then
          Dec(lBracketCount);
        if (lBracketCount = 0) and (lLine[lScan] = ' ') then
          Break;
        Dec(lScan);
      end;

      AAList.Add(Copy(lLine, lScan + 1, lWordEndPos - (lScan + 1)));
      ABList.Add(Trim(Copy(lLine, lEqPos + 2, lSemiPos - lEqPos - 2)));
      APreList.Add(Trim(Copy(lLine, 1, lScan)));
      APostList.Add(Trim(Copy(lLine, lSemiPos, Length(lLine) - (lSemiPos - 1))));
      if Length(APreList[lIdx]) > 0 then
        APreList[lIdx] := APreList[lIdx] + ' ';
    end
    else
    begin
      APreList.Add('');
      AAList.Add(lLine);
      ABList.Add('');
      APostList.Add('');
    end;

    lTrue := CompareText(ABList[lIdx], 'True') = 0;
    lFalse := CompareText(ABList[lIdx], 'False') = 0;
    if lTrue or lFalse then
    begin
      lTrueFalse := AAList[lIdx];
      AAList[lIdx] := BoolToStr(not lTrue, 'True', 'False');
      ABList[lIdx] := lTrueFalse;
    end;
  end;
end;

constructor TNXLSInvertAssignment.Create;
begin
  inherited Create;
  FOptions := [iaoSpaceBefore, iaoSpaceAfter];
end;

function TNXLSInvertAssignment.InvertLine(const APreVar, AVarA, AVarB,
  APostVar: string; ALineStart, AEqualPosition: Integer): string;
var
  lLength: Integer;
  lOperator: string;
begin
  Result := StringOfChar(' ', ALineStart);
  if Length(Trim(AVarB)) = 0 then
    Result := Result + AVarA
  else
  begin
    Result := Result + APreVar + AVarB;
    lLength := Length(Trim(Result));
    if (iaoAlign in Options) and (lLength < AEqualPosition) then
      Result := Result + StringOfChar(' ', AEqualPosition - lLength);

    lOperator := ':=';
    if iaoSpaceBefore in Options then
      lOperator := ' ' + lOperator;
    if iaoSpaceAfter in Options then
      lOperator := lOperator + ' ';
    Result := Result + lOperator + AVarA + APostVar;
  end;
end;

function TNXLSInvertAssignment.InvertAssignment(const AText: string): string;
var
  lLines: TStringList;
  lHasLinefeed: Boolean;
begin
  if AText = '' then
    Exit('');

  lHasLinefeed := AText[Length(AText)] in [#10, #13];
  lLines := TStringList.Create;
  try
    lLines.SkipLastLineBreak := True;
    lLines.Text := AText;
    InvertAssignment(lLines);
    Result := lLines.Text;
  finally
    lLines.Free;
  end;

  if not lHasLinefeed then
    while (Result <> '') and (Result[Length(Result)] in [#10, #13]) do
      SetLength(Result, Length(Result) - 1);
end;

procedure TNXLSInvertAssignment.InvertAssignment(ALines: TStrings);
var
  lTempLines: TStringList;
  lPreList: TStrings;
  lAList: TStrings;
  lBList: TStrings;
  lPostList: TStrings;
  lLine: string;
  lIndents: array of Integer;
  lIdx: Integer;
  lWidth: Integer;
  lEqPos: Integer;
begin
  lTempLines := nil;
  lPreList := nil;
  lAList := nil;
  lBList := nil;
  lPostList := nil;
  lIndents := nil;
  try
    SetLength(lIndents, ALines.Count);
    lTempLines := TStringList.Create;
    lLine := '';
    for lIdx := 0 to ALines.Count - 1 do
    begin
      lLine := lLine + ALines[lIdx];
      if IsAWholeLine(lLine) then
      begin
        lIndents[lTempLines.Add(lLine)] := GetIndent(lLine);
        lLine := '';
      end;
    end;
    if lLine <> '' then
      lIndents[lTempLines.Add(lLine)] := GetIndent(lLine);

    ALines.Clear;
    lPreList := TStringList.Create;
    lAList := TStringList.Create;
    lBList := TStringList.Create;
    lPostList := TStringList.Create;
    DivideLines(lTempLines, lPreList, lAList, lBList, lPostList);

    lEqPos := 0;
    for lIdx := 0 to lBList.Count - 1 do
    begin
      lWidth := Length(lBList[lIdx]);
      if lWidth > lEqPos then
        lEqPos := lWidth;
    end;

    for lIdx := 0 to lAList.Count - 1 do
      ALines.Add(InvertLine(lPreList[lIdx], lAList[lIdx], lBList[lIdx],
        lPostList[lIdx], lIndents[lIdx], lEqPos));
  finally
    lPreList.Free;
    lAList.Free;
    lBList.Free;
    lPostList.Free;
    lTempLines.Free;
  end;
end;

procedure TNXLSCommandService.ApplyTextEdit(const AURI, ANewText: string;
  AStartLine, AStartCharacter, AEndLine, AEndCharacter: Integer);
var
  lParams: TJSONObject;
  lEdit: TJSONObject;
  lChanges: TJSONObject;
  lEdits: TJSONArray;
  lTextEdit: TJSONObject;
  lRange: TJSONObject;
begin
  lParams := TJSONObject.Create;
  try
    lEdit := TJSONObject.Create;
    lChanges := TJSONObject.Create;
    lEdits := TJSONArray.Create;
    lTextEdit := TJSONObject.Create;
    lRange := TJSONObject.Create;

    NXLSAddPosition(lRange, 'start', AStartLine, AStartCharacter);
    NXLSAddPosition(lRange, 'end', AEndLine, AEndCharacter);
    lTextEdit.Add('range', lRange);
    lTextEdit.Add('newText', ANewText);
    lEdits.Add(lTextEdit);
    lChanges.Add(AURI, lEdits);
    lEdit.Add('changes', lChanges);
    lParams.Add('edit', lEdit);

    Model.SendClientRequest('workspace/applyEdit', lParams);
    lParams.Free;
    lParams := nil;
  except
    lParams.Free;
    raise;
  end;
end;

procedure TNXLSCommandService.ApplyFullDocumentEdit(const AURI, ANewText: string);
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
begin
  lDocument := Model.RequireDocument(AURI);
  lCode := lDocument.CodeBuffer;
  ApplyTextEdit(AURI, ANewText, 0, 0, NXLSWholeDocumentEndLine(lCode),
    NXLSWholeDocumentEndCharacter(lCode));
end;

procedure TNXLSCommandService.ExecuteCompleteCode(AParams: TNXLSExecuteCommandParams);
var
  lURI: string;
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lNewCode: TCodeBuffer;
  lLine: Integer;
  lCharacter: Integer;
  lNewX: Integer;
  lNewY: Integer;
  lNewTopLine: Integer;
  lBlockTopLine: Integer;
  lBlockBottomLine: Integer;
begin
  lURI := NXLSArgumentString(AParams, 0);
  NXLSArgumentPosition(AParams, 1, lLine, lCharacter);
  lDocument := Model.RequireDocument(lURI);
  lCode := lDocument.CodeBuffer;

  with CodeToolBoss.SourceChangeCache.BeautifyCodeOptions do
  begin
    ClassHeaderComments := False;
    ClassImplementationComments := False;
    ForwardProcBodyInsertPolicy := fpipInFrontOfMethods;
  end;

  if not CodeToolBoss.CompleteCode(lCode, lCharacter + 1, lLine + 1,
    lLine + 1, lNewCode, lNewX, lNewY, lNewTopLine, lBlockTopLine,
    lBlockBottomLine, False) then
    raise Exception.CreateFmt('CompleteCode failed: %s', [CodeToolBoss.ErrorMessage]);

  ApplyFullDocumentEdit(lURI, lCode.Source);
end;

procedure TNXLSCommandService.ExecuteInvertAssignment(AParams: TNXLSExecuteCommandParams);
var
  lURI: string;
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lStartLine: Integer;
  lStartCharacter: Integer;
  lEndLine: Integer;
  lEndCharacter: Integer;
  lText: string;
  lLineText: string;
  lInverter: TNXLSInvertAssignment;
begin
  lURI := NXLSArgumentString(AParams, 0);
  NXLSArgumentPosition(AParams, 1, lStartLine, lStartCharacter);
  NXLSArgumentPosition(AParams, 2, lEndLine, lEndCharacter);
  lDocument := Model.RequireDocument(lURI);
  lCode := lDocument.CodeBuffer;
  if lCode = nil then
    raise Exception.CreateFmt('Document has no CodeTools buffer: %s', [lURI]);

  if lStartLine = lEndLine then
  begin
    lLineText := lCode.GetLine(lStartLine);
    lText := Copy(lLineText, lStartCharacter + 1, lEndCharacter - lStartCharacter);
  end
  else
  begin
    lText := lCode.GetLines(lStartLine + 1, lEndLine);
    if lStartCharacter > 0 then
      Delete(lText, 1, lStartCharacter);
    lLineText := lCode.GetLine(lEndLine);
    lText := lText + Copy(lLineText, 1, lEndCharacter);
  end;

  lInverter := TNXLSInvertAssignment.Create;
  try
    lText := lInverter.InvertAssignment(lText);
    ApplyTextEdit(lURI, lText, lStartLine, lStartCharacter, lEndLine,
      lEndCharacter);
  finally
    lInverter.Free;
  end;
end;

procedure TNXLSCommandService.ExecuteRemoveEmptyMethods(AParams: TNXLSExecuteCommandParams);
const
  cAttributes =
    [phpAddClassName, phpDoNotAddSemicolon, phpWithoutParamList,
     phpWithoutBrackets, phpWithoutClassKeyword, phpWithoutSemicolon];
var
  lURI: string;
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lLine: Integer;
  lCharacter: Integer;
  lAllEmpty: Boolean;
  lList: TFPList;
  lRemovedProcHeads: TStrings;
begin
  lURI := NXLSArgumentString(AParams, 0);
  NXLSArgumentPosition(AParams, 1, lLine, lCharacter);
  lDocument := Model.RequireDocument(lURI);
  lCode := lDocument.CodeBuffer;

  lList := TFPList.Create;
  lRemovedProcHeads := nil;
  try
    if not CodeToolBoss.FindEmptyMethods(lCode, '', lCharacter + 1, lLine + 1,
      AllPascalClassSections, lList, lAllEmpty) then
      raise Exception.CreateFmt('Cannot find empty methods: %s', [CodeToolBoss.ErrorMessage]);

    if not CodeToolBoss.RemoveEmptyMethods(lCode, '', lCharacter + 1,
      lLine + 1, AllPascalClassSections, lAllEmpty, cAttributes,
      lRemovedProcHeads) then
      raise Exception.CreateFmt('RemoveEmptyMethods failed: %s', [CodeToolBoss.ErrorMessage]);

    ApplyFullDocumentEdit(lURI, lCode.Source);
  finally
    CodeToolBoss.FreeListOfPCodeXYPosition(lList);
    lRemovedProcHeads.Free;
  end;
end;

procedure TNXLSCommandService.ExecuteRemoveUnusedUnits(AParams: TNXLSExecuteCommandParams);
var
  lURI: string;
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lUnits: TStringList;
  lIdx: Integer;
  lRemovedCount: Integer;
begin
  lURI := NXLSArgumentString(AParams, 0);
  lDocument := Model.RequireDocument(lURI);
  lCode := lDocument.CodeBuffer;

  lUnits := TStringList.Create;
  try
    if not CodeToolBoss.FindUnusedUnits(lCode, lUnits) then
      raise Exception.CreateFmt('FindUnusedUnits failed: %s', [CodeToolBoss.ErrorMessage]);

    lRemovedCount := 0;
    for lIdx := 0 to lUnits.Count - 1 do
      if SameText(lUnits.ValueFromIndex[lIdx], 'unused') and
        CodeToolBoss.RemoveUnitFromAllUsesSections(lCode, lUnits.Names[lIdx]) then
        Inc(lRemovedCount);

    if lRemovedCount > 0 then
      ApplyFullDocumentEdit(lURI, lCode.Source);
  finally
    lUnits.Free;
  end;
end;

function TNXLSCommandService.ExecuteCommand(AParams: TNXLSExecuteCommandParams): TNXJSONValue;
var
  lCommand: string;
  lData: TJSONData;
begin
  if (AParams <> nil) and (AParams.command <> nil) then
  begin
    lCommand := AParams.command.Value;
    if SameText(lCommand, cNXLSCommandCompleteCode) then
      ExecuteCompleteCode(AParams)
    else if SameText(lCommand, cNXLSCommandInvertAssignment) then
      ExecuteInvertAssignment(AParams)
    else if SameText(lCommand, cNXLSCommandRemoveEmptyMethods) then
      ExecuteRemoveEmptyMethods(AParams)
    else if SameText(lCommand, cNXLSCommandRemoveUnusedUnits) then
      ExecuteRemoveUnusedUnits(AParams)
    else if SameText(lCommand, cNXLSCommandNexusProjectCreateWizard) then
      Exit(TNXLSProjectService.CreateNexusProjectWizard(NXLSArgumentString(AParams, 0)))
    else if SameText(lCommand, cNXLSCommandNexusProjectPlanCreate) then
    begin
      lData := NXLSArgument(AParams, 0).ToJSONData;
      try
        Exit(TNXLSProjectService.PlanNexusProjectCreate(lData));
      finally
        lData.Free;
      end;
    end
    else if SameText(lCommand, cNXLSCommandNexusProjectCreate) then
    begin
      lData := NXLSArgument(AParams, 0).ToJSONData;
      try
        Exit(TNXLSProjectService.CreateNexusProject(lData));
      finally
        lData.Free;
      end;
    end
    else
      raise Exception.CreateFmt('Unsupported command: %s', [lCommand]);
  end;

  Result := TNXLSCommandResult.CreateValue;
end;

end.
