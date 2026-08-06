unit obNXPasParser;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs,
  obNXPasAST,
  obNXPasDiagnostics,
  obNXPasMetadata,
  obNXPasSource,
  obNXPasTokenStream,
  tpNXPasTokens;

type
  TNXPasDirectiveFrame = class
  private
    FConditionActive: Boolean;
    FElseSeen: Boolean;
    FInactiveStart: TNXPasSourcePosition;
    FParentActive: Boolean;
  public
    property ConditionActive: Boolean read FConditionActive write FConditionActive;
    property ElseSeen: Boolean read FElseSeen write FElseSeen;
    property InactiveStart: TNXPasSourcePosition read FInactiveStart write FInactiveStart;
    property ParentActive: Boolean read FParentActive write FParentActive;
  end;

  TNXPasParser = class
  private
    FDiagnostics: TNXPasDiagnosticList;
    FDirectiveStack: TObjectList;
    FDefines: TStringList;
    FCurrentActive: Boolean;
    FCurrentUsesSection: TNXPasUsesSection;
    FHeaderParsed: Boolean;
    FLastDeclarationEnd: TNXPasSourcePosition;
    FStream: TNXPasTokenStream;
    FTree: TNXPasSyntaxTree;
    function TokenRange(const AToken: TNXPasToken): TNXPasSourceRange;
    function CurrentRange: TNXPasSourceRange;
    function SourceText(const ARange: TNXPasSourceRange): string;
    procedure SetNodeRange(ANode: TNXPasASTNode; const AStartPos,
      AEndPos: TNXPasSourcePosition);
    procedure SetDeclaredType(ANode: TNXPasASTNode; const AText: string;
      const ARange: TNXPasSourceRange);
    function IsRoutineKeyword: Boolean;
    function IsRoutineKeywordAt(AOffset: Integer): Boolean;
    function IsStructuredTypeKeyword: Boolean;
    function IsSectionStart: Boolean;
    function IsDeclarationSectionStart: Boolean;
    function IsVisibilityKeyword: Boolean;
    function IsRoutineDirective: Boolean;
    function IsParameterModifier: Boolean;
    function IsPropertySpecifier: Boolean;
    function IsPropertyDefaultSpecifier: Boolean;
    function IsFieldNameToken: Boolean;
    function IsDeclarationNameToken: Boolean;
    function IsDeclarationTailKeyword: Boolean;
    function NormalizeDirectiveText(const AText: string): string;
    function DirectiveCommand(const AText: string): string;
    function DirectiveArgument(const AText: string): string;
    function DirectiveArgumentRange(const AText: string;
      const ATokenRange: TNXPasSourceRange): TNXPasSourceRange;
    function StringLiteralValue(const AText: string): string;
    function IsDefined(const AName: string): Boolean;
    function ResolveCandidatePath(const AInFileName: string): string;
    function PathToFileURI(const APath: string): string;
    function ParseIdentifierList(AParent: TNXPasASTNode;
      AKind: TNXPasNodeKind): Boolean;
    procedure AddExpectedDiagnostic(const ACode, AMessage: string);
    procedure AddDiagnostic(const ACode, AMessage: string;
      const ARange: TNXPasSourceRange);
    procedure AddInactiveRegion(const AStartPos, AEndPos: TNXPasSourcePosition);
    procedure CloseInactiveRegionAt(const AEndPos: TNXPasSourcePosition);
    procedure ProcessDirective;
    procedure ProcessMetadataDirective(const ACommand, AArgument: string;
      const ARange: TNXPasSourceRange);
    procedure FinishDirectiveStack;
    procedure AdvanceToActiveToken;
    function RecoverAtSynchronizationPoint: Boolean;
    procedure RecoverDeclaration;
    procedure ParseHeader;
    procedure ParseSection;
    procedure ParseUsesClause(AParent: TNXPasASTNode);
    function ParseUsesEntry(AParent: TNXPasASTNode;
      ASection: TNXPasUsesSection): Boolean;
    procedure ParseTypeSection(AParent: TNXPasASTNode);
    procedure ParseConstSection(AParent: TNXPasASTNode);
    procedure ParseVarSection(AParent: TNXPasASTNode);
    procedure ParseRoutineDecl(AParent: TNXPasASTNode);
    procedure ParseRoutineDeclAt(AParent: TNXPasASTNode;
      const AStartPos: TNXPasSourcePosition);
    procedure ParseRoutineParameters(AParent: TNXPasASTNode);
    procedure ParseRoutineBodyDeclarations(AParent: TNXPasASTNode);
    procedure SkipRoutineBody(ANode: TNXPasASTNode);
    procedure ParseTypeDecl(AParent: TNXPasASTNode);
    procedure ParseStructuredTypeBody(ANode: TNXPasASTNode);
    procedure CaptureStructuredTypeHeritage(ANode: TNXPasASTNode);
    function TryFinishForwardStructuredType(ANode,
      AChildNode: TNXPasASTNode): Boolean;
    procedure ParseFieldDecl(AParent: TNXPasASTNode);
    procedure ParsePropertyDecl(AParent: TNXPasASTNode);
    procedure SkipPropertyParameters;
    function ExpectDeclarationNameToken(out AToken: TNXPasToken): Boolean;
    function ExpectFieldNameToken(out AToken: TNXPasToken): Boolean;
    procedure ParseVisibilitySection(AParent: TNXPasASTNode);
    function CaptureDeclaredType(AStopAtPropertyModifier,
      AStopAtParameterDelimiter: Boolean; out AText: string;
      out ARange: TNXPasSourceRange): Boolean;
    procedure SkipToDeclarationEnd(AStopAtRoutineKeyword: Boolean = True);
    procedure SkipRoutineDirectives;
    procedure SkipDeclarationTailDirectives;
  public
    destructor Destroy; override;
    constructor Create(ADiagnostics: TNXPasDiagnosticList);
    function Parse(ASource: TNXPasSourceFile): TNXPasSyntaxTree;
  end;

implementation

uses
  SysUtils,
  obNXFastPascal,
  obNXPasLexer;

constructor TNXPasParser.Create(ADiagnostics: TNXPasDiagnosticList);
begin
  inherited Create;
  FDiagnostics := ADiagnostics;
  FDirectiveStack := TObjectList.Create(True);
  FDefines := TStringList.Create;
  FDefines.CaseSensitive := False;
end;

destructor TNXPasParser.Destroy;
begin
  FreeAndNil(FDefines);
  FreeAndNil(FDirectiveStack);
  inherited Destroy;
end;

function TNXPasParser.CurrentRange: TNXPasSourceRange;
begin
  Result.StartPos := FStream.Current.StartPos;
  Result.EndPos := FStream.Current.EndPos;
end;

function TNXPasParser.TokenRange(const AToken: TNXPasToken): TNXPasSourceRange;
begin
  Result.StartPos := AToken.StartPos;
  Result.EndPos := AToken.EndPos;
end;

function TNXPasParser.SourceText(const ARange: TNXPasSourceRange): string;
begin
  Result := '';
  if (FTree = nil) or (FTree.Source = nil) then
    Exit;

  if (ARange.StartPos.Offset <= 0) or
    (ARange.EndPos.Offset <= ARange.StartPos.Offset) then
    Exit;

  Result := Trim(Copy(FTree.Source.Text, ARange.StartPos.Offset,
    ARange.EndPos.Offset - ARange.StartPos.Offset));
end;

procedure TNXPasParser.SetNodeRange(ANode: TNXPasASTNode; const AStartPos,
  AEndPos: TNXPasSourcePosition);
var
  lRange: TNXPasSourceRange;
begin
  lRange.StartPos := AStartPos;
  lRange.EndPos := AEndPos;
  ANode.Range := lRange;
end;

procedure TNXPasParser.SetDeclaredType(ANode: TNXPasASTNode;
  const AText: string; const ARange: TNXPasSourceRange);
begin
  if ANode = nil then
    Exit;

  ANode.DeclaredTypeText := Trim(AText);
  ANode.DeclaredTypeRange := ARange;
end;

function TNXPasParser.IsRoutineKeyword: Boolean;
begin
  Result := IsRoutineKeywordAt(0);
end;

function TNXPasParser.IsRoutineKeywordAt(AOffset: Integer): Boolean;
begin
  Result := FStream.CheckPeekKeyword(AOffset, pkwProcedure) or
    FStream.CheckPeekKeyword(AOffset, pkwFunction) or
    FStream.CheckPeekKeyword(AOffset, pkwConstructor) or
    FStream.CheckPeekKeyword(AOffset, pkwDestructor);
end;

function TNXPasParser.IsStructuredTypeKeyword: Boolean;
begin
  Result := FStream.CheckKeyword(pkwClass) or
    FStream.CheckKeyword(pkwObject) or FStream.CheckKeyword(pkwRecord) or
    FStream.CheckKeyword(pkwInterface);
end;

function TNXPasParser.IsSectionStart: Boolean;
begin
  Result := FStream.CheckKeyword(pkwInterface) or
    FStream.CheckKeyword(pkwImplementation) or
    FStream.CheckKeyword(pkwInitialization) or
    FStream.CheckKeyword(pkwFinalization);
end;

function TNXPasParser.IsDeclarationSectionStart: Boolean;
begin
  Result := FStream.CheckKeyword(pkwType) or
    FStream.CheckKeyword(pkwConst) or FStream.CheckKeyword(pkwVar) or
    FStream.CheckKeyword(pkwThreadvar) or
    FStream.CheckKeyword(pkwResourcestring);
end;

function TNXPasParser.IsVisibilityKeyword: Boolean;
begin
  Result := FStream.CheckKeyword(pkwPrivate) or
    FStream.CheckKeyword(pkwProtected) or FStream.CheckKeyword(pkwPublic) or
    FStream.CheckKeyword(pkwPublished);
end;

function TNXPasParser.IsRoutineDirective: Boolean;
begin
  Result := (FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
    TNXPascalRoutineDirectiveSet.Contains(FStream.CurrentText);
end;

function TNXPasParser.IsParameterModifier: Boolean;
begin
  Result := (FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
    TNXPascalParameterModifierSet.Contains(FStream.CurrentText);
end;

function TNXPasParser.IsPropertySpecifier: Boolean;
begin
  Result := (FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
    TNXPascalPropertySpecifierSet.Contains(FStream.CurrentText);
end;

function TNXPasParser.IsPropertyDefaultSpecifier: Boolean;
var
  lKind: TNXPasPropertySpecifierKind;
begin
  Result := (FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
    TNXPascalPropertySpecifierSet.TryKindOf(FStream.CurrentText, lKind) and
    (lKind in [ppsDefault, ppsNodefault]);
end;

function TNXPasParser.IsFieldNameToken: Boolean;
begin
  Result := FStream.Check(ptkIdentifier) or FStream.CheckKeyword(pkwHelper);
end;

function TNXPasParser.IsDeclarationNameToken: Boolean;
begin
  Result := FStream.Check(ptkIdentifier) or FStream.CheckKeyword(pkwHelper);
end;

function TNXPasParser.IsDeclarationTailKeyword: Boolean;
begin
  Result := (FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
    TNXPascalDeclarationTailKeywordSet.Contains(FStream.CurrentText);
end;

function TNXPasParser.NormalizeDirectiveText(const AText: string): string;
begin
  Result := Trim(AText);
  if (Length(Result) >= 3) and (Result[1] = '{') and (Result[2] = '$') then
    Result := Copy(Result, 3, Length(Result) - 3)
  else if (Length(Result) >= 5) and (Copy(Result, 1, 3) = '(*$') then
    Result := Copy(Result, 4, Length(Result) - 5);
  Result := Trim(Result);
end;

function TNXPasParser.DirectiveCommand(const AText: string): string;
var
  lPos: Integer;
  lText: string;
begin
  lText := NormalizeDirectiveText(AText);
  lPos := Pos(' ', lText);
  if lPos = 0 then
    Result := UpperCase(lText)
  else
    Result := UpperCase(Copy(lText, 1, lPos - 1));
end;

function TNXPasParser.DirectiveArgument(const AText: string): string;
var
  lPos: Integer;
  lText: string;
begin
  lText := NormalizeDirectiveText(AText);
  lPos := Pos(' ', lText);
  if lPos = 0 then
    Result := ''
  else
    Result := Trim(Copy(lText, lPos + 1, MaxInt));
end;

function TNXPasParser.DirectiveArgumentRange(const AText: string;
  const ATokenRange: TNXPasSourceRange): TNXPasSourceRange;
var
  lArgument: string;
  lNormalized: string;
  lPos: Integer;
begin
  Result := ATokenRange;
  lArgument := DirectiveArgument(AText);
  if lArgument = '' then
    Exit;

  lNormalized := NormalizeDirectiveText(AText);
  lPos := Pos(lArgument, lNormalized);
  if lPos <= 0 then
    Exit;

  Result.StartPos.Offset := ATokenRange.StartPos.Offset + 1 + lPos;
  Result.StartPos.Line := ATokenRange.StartPos.Line;
  Result.StartPos.Column := ATokenRange.StartPos.Column + 1 + lPos;
end;

function TNXPasParser.StringLiteralValue(const AText: string): string;
begin
  Result := AText;
  if (Length(Result) >= 2) and (Result[1] = '''') and
    (Result[Length(Result)] = '''') then
  begin
    Result := Copy(Result, 2, Length(Result) - 2);
    Result := StringReplace(Result, '''''', '''', [rfReplaceAll]);
  end;
end;

function TNXPasParser.IsDefined(const AName: string): Boolean;
begin
  Result := FDefines.IndexOf(UpperCase(AName)) >= 0;
end;

function TNXPasParser.ResolveCandidatePath(const AInFileName: string): string;
var
  lBasePath: string;
begin
  Result := '';
  if (AInFileName = '') or (FTree = nil) or (FTree.Source = nil) then
    Exit;

  if ExtractFilePath(AInFileName) <> '' then
    Result := ExpandFileName(AInFileName)
  else
  begin
    lBasePath := ExtractFilePath(FTree.Source.FileName);
    if lBasePath = '' then
      Exit;
    Result := ExpandFileName(lBasePath + AInFileName);
  end;
end;

function TNXPasParser.PathToFileURI(const APath: string): string;
begin
  Result := '';
  if APath = '' then
    Exit;

  Result := 'file:///' + StringReplace(APath, '\', '/', [rfReplaceAll]);
end;

procedure TNXPasParser.AddDiagnostic(const ACode, AMessage: string;
  const ARange: TNXPasSourceRange);
begin
  if FDiagnostics <> nil then
    FDiagnostics.AddDiagnostic(pdsError, AMessage, ARange, ACode);
end;

procedure TNXPasParser.AddExpectedDiagnostic(const ACode,
  AMessage: string);
begin
  AddDiagnostic(ACode, AMessage, CurrentRange);
end;

procedure TNXPasParser.AddInactiveRegion(const AStartPos,
  AEndPos: TNXPasSourcePosition);
var
  lRange: TNXPasSourceRange;
begin
  if FTree = nil then
    Exit;

  if AEndPos.Offset < AStartPos.Offset then
    Exit;

  lRange.StartPos := AStartPos;
  lRange.EndPos := AEndPos;
  FTree.InactiveRegions.AddRegion(lRange);
  FTree.Metadata.InactiveRegions.AddRegion(lRange);
end;

procedure TNXPasParser.CloseInactiveRegionAt(
  const AEndPos: TNXPasSourcePosition);
var
  lFrame: TNXPasDirectiveFrame;
begin
  if FDirectiveStack.Count = 0 then
    Exit;

  lFrame := TNXPasDirectiveFrame(FDirectiveStack[FDirectiveStack.Count - 1]);
  if not FCurrentActive then
    AddInactiveRegion(lFrame.InactiveStart, AEndPos);
end;

procedure TNXPasParser.ProcessDirective;
var
  lArg: string;
  lCommand: string;
  lDefined: Boolean;
  lFrame: TNXPasDirectiveFrame;
  lRange: TNXPasSourceRange;
begin
  if not FStream.Check(ptkDirective) then
    Exit;

  lRange := CurrentRange;
  lCommand := DirectiveCommand(FStream.CurrentText);
  lArg := DirectiveArgument(FStream.CurrentText);
  ProcessMetadataDirective(lCommand, lArg, lRange);

  if lCommand = 'DEFINE' then
  begin
    if lArg <> '' then
      if FCurrentActive and (FDefines.IndexOf(UpperCase(lArg)) < 0) then
        FDefines.Add(UpperCase(lArg));
    FStream.Next;
    Exit;
  end;

  if lCommand = 'UNDEF' then
  begin
    if lArg <> '' then
      if FCurrentActive and (FDefines.IndexOf(UpperCase(lArg)) >= 0) then
        FDefines.Delete(FDefines.IndexOf(UpperCase(lArg)));
    FStream.Next;
    Exit;
  end;

  if (lCommand = 'IFDEF') or (lCommand = 'IFNDEF') then
  begin
    lDefined := IsDefined(lArg);
    if lCommand = 'IFNDEF' then
      lDefined := not lDefined;

    lFrame := TNXPasDirectiveFrame.Create;
    lFrame.ParentActive := FCurrentActive;
    lFrame.ConditionActive := lDefined;
    lFrame.ElseSeen := False;
    lFrame.InactiveStart := FStream.Current.EndPos;
    FDirectiveStack.Add(lFrame);
    FCurrentActive := lFrame.ParentActive and lFrame.ConditionActive;
    FStream.Next;
    Exit;
  end;

  if lCommand = 'ELSE' then
  begin
    if FDirectiveStack.Count = 0 then
      AddDiagnostic('nxpas.directive.elseWithoutIf',
        'ELSE directive without matching IFDEF or IFNDEF.', lRange)
    else
    begin
      lFrame := TNXPasDirectiveFrame(FDirectiveStack[FDirectiveStack.Count - 1]);
      if lFrame.ElseSeen then
        AddDiagnostic('nxpas.directive.duplicateElse',
          'Duplicate ELSE directive in conditional region.', lRange);
      CloseInactiveRegionAt(FStream.Current.StartPos);
      lFrame.ElseSeen := True;
      lFrame.ConditionActive := not lFrame.ConditionActive;
      lFrame.InactiveStart := FStream.Current.EndPos;
      FCurrentActive := lFrame.ParentActive and lFrame.ConditionActive;
    end;
    FStream.Next;
    Exit;
  end;

  if lCommand = 'ENDIF' then
  begin
    if FDirectiveStack.Count = 0 then
      AddDiagnostic('nxpas.directive.endifWithoutIf',
        'ENDIF directive without matching IFDEF or IFNDEF.', lRange)
    else
    begin
      CloseInactiveRegionAt(FStream.Current.StartPos);
      lFrame := TNXPasDirectiveFrame(FDirectiveStack[FDirectiveStack.Count - 1]);
      FCurrentActive := lFrame.ParentActive;
      FDirectiveStack.Delete(FDirectiveStack.Count - 1);
    end;
    FStream.Next;
    Exit;
  end;

  if lCommand = 'IF' then
    AddDiagnostic('nxpas.directive.unsupportedIf',
      'Unsupported conditional directive expression.', lRange);

  FStream.Next;
end;

procedure TNXPasParser.ProcessMetadataDirective(const ACommand,
  AArgument: string; const ARange: TNXPasSourceRange);
begin
  if FTree = nil then
    Exit;

  if FCurrentActive and (ACommand <> '') then
    FTree.Metadata.ActiveDirectives.AddDirective(ACommand, AArgument, ARange,
      True);

  if (ACommand = 'I') or (ACommand = 'INCLUDE') then
    FTree.Metadata.IncludeDirectives.AddDirective(ACommand, AArgument, ARange,
      FCurrentActive)
  else if ACommand = 'NXDEP' then
  begin
    if FCurrentActive and (AArgument = '') then
      AddDiagnostic('nxpas.nxdep.malformed',
        'NXDEP directive requires a dependency value.', ARange);
    FTree.Metadata.Dependencies.AddDependency(AArgument, ARange,
      FCurrentActive and (AArgument <> ''));
  end;
end;

procedure TNXPasParser.FinishDirectiveStack;
var
  lFrame: TNXPasDirectiveFrame;
begin
  while FDirectiveStack.Count > 0 do
  begin
    lFrame := TNXPasDirectiveFrame(FDirectiveStack[FDirectiveStack.Count - 1]);
    if not FCurrentActive then
      AddInactiveRegion(lFrame.InactiveStart, FStream.Current.StartPos);
    AddDiagnostic('nxpas.directive.missingEndIf',
      'Missing ENDIF directive for conditional region.', CurrentRange);
    FCurrentActive := lFrame.ParentActive;
    FDirectiveStack.Delete(FDirectiveStack.Count - 1);
  end;
end;

procedure TNXPasParser.AdvanceToActiveToken;
begin
  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.Check(ptkDirective) then
    begin
      ProcessDirective;
      Continue;
    end;

    if FCurrentActive then
      Exit;

    FStream.Next;
  end;
end;

function TNXPasParser.RecoverAtSynchronizationPoint: Boolean;
begin
  Result := FStream.Check(ptkEndOfFile) or FStream.CheckSymbol(psySemicolon) or
    FStream.Check(ptkDirective) or IsSectionStart or IsDeclarationSectionStart or
    IsRoutineKeyword or IsVisibilityKeyword or FStream.CheckKeyword(pkwEnd);
end;

procedure TNXPasParser.RecoverDeclaration;
begin
  while not RecoverAtSynchronizationPoint do
    FStream.Next;
  if FStream.CheckSymbol(psySemicolon) then
    FStream.Next;
end;

function TNXPasParser.ParseIdentifierList(AParent: TNXPasASTNode;
  AKind: TNXPasNodeKind): Boolean;
var
  lNode: TNXPasASTNode;
  lToken: TNXPasToken;
begin
  Result := False;
  while FStream.ExpectIdentifierToken(lToken) do
  begin
    lNode := AParent.AddChild(AKind, FStream.TokenText(lToken));
    lNode.Range := TokenRange(lToken);
    Result := True;
    if not FStream.MatchSymbol(psyComma) then
      Break;
  end;
end;

procedure TNXPasParser.ParseHeader;
var
  lNameToken: TNXPasToken;
  lKind: TNXPasNodeKind;
  lNode: TNXPasASTNode;
  lStart: TNXPasSourcePosition;
begin
  if not (FStream.CheckKeyword(pkwUnit) or
    FStream.CheckKeyword(pkwProgram) or
    FStream.CheckKeyword(pkwLibrary) or
    FStream.CheckKeyword(pkwPackage)) then
    Exit;

  FHeaderParsed := True;

  lStart := FStream.Current.StartPos;
  if FStream.CheckKeyword(pkwProgram) then
    lKind := pnkProgramHeader
  else if FStream.CheckKeyword(pkwLibrary) then
    lKind := pnkLibraryHeader
  else if FStream.CheckKeyword(pkwPackage) then
    lKind := pnkHeader
  else
    lKind := pnkUnitHeader;
  lNode := FTree.Root.AddChild(lKind);
  if FStream.CheckKeyword(pkwUnit) then
    FTree.Metadata.CompilationKind := pckUnit
  else if FStream.CheckKeyword(pkwProgram) then
    FTree.Metadata.CompilationKind := pckProgram
  else if FStream.CheckKeyword(pkwLibrary) then
    FTree.Metadata.CompilationKind := pckLibrary
  else if FStream.CheckKeyword(pkwPackage) then
    FTree.Metadata.CompilationKind := pckPackage;
  FStream.Next;
  if FStream.ExpectIdentifierToken(lNameToken) then
  begin
    lNode.Name := FStream.TokenText(lNameToken);
    FTree.Metadata.Name := FStream.TokenText(lNameToken);
    SetNodeRange(lNode, lStart, lNameToken.EndPos);
  end
  else
  begin
    lNode.Range := CurrentRange;
    AddExpectedDiagnostic('nxpas.header.malformed',
      'Expected unit, program, library, or package name.');
  end;

  if not FStream.MatchSymbol(psySemicolon) then
    AddExpectedDiagnostic('nxpas.header.missingSemicolon',
      'Missing semicolon after unit, program, library, or package header.');
end;

procedure TNXPasParser.ParseSection;
var
  lNode: TNXPasASTNode;
  lStartPos: TNXPasSourcePosition;
begin
  if FStream.Check(ptkDirective) then
  begin
    ProcessDirective;
    Exit;
  end;

  if not FCurrentActive then
  begin
    FStream.Next;
    Exit;
  end;

  if FStream.CheckKeyword(pkwInterface) then
  begin
    lNode := FTree.Root.AddChild(pnkInterfaceSection, 'interface');
    lNode.Range := CurrentRange;
    FCurrentUsesSection := pusInterface;
    FStream.Next;
    Exit;
  end;

  if FStream.CheckKeyword(pkwImplementation) then
  begin
    lNode := FTree.Root.AddChild(pnkImplementationSection, 'implementation');
    lNode.Range := CurrentRange;
    FCurrentUsesSection := pusImplementation;
    FStream.Next;
    Exit;
  end;

  lNode := FTree.Root;
  if FStream.CheckKeyword(pkwUses) then
    ParseUsesClause(lNode)
  else if FStream.CheckKeyword(pkwType) then
    ParseTypeSection(lNode)
  else if FStream.CheckKeyword(pkwConst) or
    FStream.CheckKeyword(pkwResourcestring) then
    ParseConstSection(lNode)
  else if FStream.CheckKeyword(pkwVar) or
    FStream.CheckKeyword(pkwThreadvar) then
    ParseVarSection(lNode)
  else if FStream.CheckKeyword(pkwClass) and IsRoutineKeywordAt(1) then
  begin
    lStartPos := FStream.Current.StartPos;
    FStream.Next;
    ParseRoutineDeclAt(lNode, lStartPos);
  end
  else if IsRoutineKeyword then
    ParseRoutineDecl(lNode)
  else
    FStream.Next;
end;

procedure TNXPasParser.ParseUsesClause(AParent: TNXPasASTNode);
var
  lNode: TNXPasASTNode;
  lSawItem: Boolean;
begin
  lNode := AParent.AddChild(pnkUsesClause, 'uses');
  lNode.Range := CurrentRange;
  FStream.Next;
  lSawItem := ParseUsesEntry(lNode, FCurrentUsesSection);

  while not FStream.Check(ptkEndOfFile) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) then
      Break;

    if FStream.CheckSymbol(psySemicolon) then
    begin
      FStream.Next;
      Exit;
    end;

    if FStream.Check(ptkDirective) then
      ProcessDirective
    else if IsSectionStart or IsDeclarationSectionStart or IsRoutineKeyword then
      Break
    else if not ParseUsesEntry(lNode, FCurrentUsesSection) then
      FStream.Next;
  end;

  if not lSawItem then
    AddExpectedDiagnostic('nxpas.uses.malformed',
      'Expected uses clause item.');
  AddExpectedDiagnostic('nxpas.uses.missingSemicolon',
    'Missing semicolon after uses clause.');
end;

function TNXPasParser.ParseUsesEntry(AParent: TNXPasASTNode;
  ASection: TNXPasUsesSection): Boolean;
var
  lCandidatePath: string;
  lEntry: TNXPasUsesEntry;
  lFileName: string;
  lNameToken: TNXPasToken;
  lNode: TNXPasASTNode;
  lRange: TNXPasSourceRange;
begin
  Result := False;
  if not FStream.ExpectIdentifierToken(lNameToken) then
    Exit;

  lFileName := '';
  lRange := TokenRange(lNameToken);
  lNode := AParent.AddChild(pnkUsesUnit, FStream.TokenText(lNameToken));
  lNode.Range := lRange;

  if FStream.MatchKeyword(pkwIn) then
  begin
    if FStream.Check(ptkString) then
    begin
      lFileName := StringLiteralValue(FStream.CurrentText);
      lRange.EndPos := FStream.Current.EndPos;
      lNode.Range := lRange;
      FStream.Next;
    end
    else
      AddExpectedDiagnostic('nxpas.uses.missingInFile',
        'Expected filename string after uses in clause.');
  end;

  lEntry := FTree.Metadata.UsesForSection(ASection).AddEntry(FStream.TokenText(lNameToken),
    lFileName, ASection, lRange, FCurrentActive);
  if lFileName <> '' then
  begin
    lCandidatePath := ResolveCandidatePath(lFileName);
    lEntry.CandidatePath := lCandidatePath;
    lEntry.CandidateURI := PathToFileURI(lCandidatePath);
  end;

  Result := True;
end;

procedure TNXPasParser.ParseTypeSection(AParent: TNXPasASTNode);
var
  lNode: TNXPasASTNode;
begin
  lNode := AParent.AddChild(pnkTypeSection, 'type');
  lNode.Range := CurrentRange;
  FStream.Next;
  while not (FStream.Check(ptkEndOfFile) or FStream.CheckKeyword(pkwConst) or
    FStream.CheckKeyword(pkwVar) or FStream.CheckKeyword(pkwThreadvar) or
    FStream.CheckKeyword(pkwResourcestring) or FStream.CheckKeyword(pkwUses) or
    IsRoutineKeyword or FStream.CheckKeyword(pkwImplementation) or
    FStream.CheckKeyword(pkwBegin)) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) or FStream.CheckKeyword(pkwConst) or
      FStream.CheckKeyword(pkwVar) or FStream.CheckKeyword(pkwThreadvar) or
      FStream.CheckKeyword(pkwResourcestring) or FStream.CheckKeyword(pkwUses) or
      IsRoutineKeyword or FStream.CheckKeyword(pkwImplementation) or
      FStream.CheckKeyword(pkwBegin) then
      Break;

    if not FStream.Check(ptkDirective) then
      ParseTypeDecl(lNode);
  end;
end;

procedure TNXPasParser.ParseConstSection(AParent: TNXPasASTNode);
var
  lDeclaredTypeRange: TNXPasSourceRange;
  lDeclaredTypeText: string;
  lNameToken: TNXPasToken;
  lItemNode: TNXPasASTNode;
  lNode: TNXPasASTNode;
begin
  lNode := AParent.AddChild(pnkConstSection, 'const');
  lNode.Range := CurrentRange;
  FStream.Next;
  while not (FStream.Check(ptkEndOfFile) or IsSectionStart or
    IsDeclarationSectionStart or IsRoutineKeyword or
    FStream.CheckKeyword(pkwBegin) or FStream.CheckKeyword(pkwEnd)) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) or IsSectionStart or
      IsDeclarationSectionStart or IsRoutineKeyword or
      FStream.CheckKeyword(pkwBegin) or FStream.CheckKeyword(pkwEnd) then
      Break;

    if FStream.Check(ptkDirective) then
    begin
      ProcessDirective;
      Continue;
    end;
    if not ExpectDeclarationNameToken(lNameToken) then
    begin
      RecoverDeclaration;
      Continue;
    end;
    lItemNode := lNode.AddChild(pnkConstDecl, FStream.TokenText(lNameToken));
    lItemNode.Range := TokenRange(lNameToken);
    lItemNode.NameRange := TokenRange(lNameToken);
    if FStream.MatchSymbol(psyColon) and CaptureDeclaredType(False, False,
      lDeclaredTypeText, lDeclaredTypeRange) then
      SetDeclaredType(lItemNode, lDeclaredTypeText, lDeclaredTypeRange);
    SkipToDeclarationEnd;
    SkipDeclarationTailDirectives;
    SetNodeRange(lItemNode, lItemNode.Range.StartPos, FLastDeclarationEnd);
  end;
end;

procedure TNXPasParser.ParseVarSection(AParent: TNXPasASTNode);
var
  lDeclaredTypeRange: TNXPasSourceRange;
  lDeclaredTypeText: string;
  lItems: TObjectList;
  lIdx: Integer;
  lNameToken: TNXPasToken;
  lItemNode: TNXPasASTNode;
  lNode: TNXPasASTNode;
begin
  lNode := AParent.AddChild(pnkVarSection, 'var');
  lNode.Range := CurrentRange;
  FStream.Next;
  lItems := TObjectList.Create(False);
  try
  while not (FStream.Check(ptkEndOfFile) or IsSectionStart or
    IsDeclarationSectionStart or IsRoutineKeyword or
    FStream.CheckKeyword(pkwBegin) or FStream.CheckKeyword(pkwEnd)) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) or IsSectionStart or
      IsDeclarationSectionStart or IsRoutineKeyword or
      FStream.CheckKeyword(pkwBegin) or FStream.CheckKeyword(pkwEnd) then
      Break;

    if FStream.Check(ptkDirective) then
    begin
      ProcessDirective;
      Continue;
    end;
    if not ExpectDeclarationNameToken(lNameToken) then
    begin
      RecoverDeclaration;
      Continue;
    end;
    lItemNode := lNode.AddChild(pnkVarDecl, FStream.TokenText(lNameToken));
    lItemNode.Range := TokenRange(lNameToken);
    lItemNode.NameRange := TokenRange(lNameToken);
    lItems.Clear;
    lItems.Add(lItemNode);
    while FStream.MatchSymbol(psyComma) do
      if ExpectDeclarationNameToken(lNameToken) then
      begin
        lItemNode := lNode.AddChild(pnkVarDecl, FStream.TokenText(lNameToken));
        lItemNode.Range := TokenRange(lNameToken);
        lItemNode.NameRange := TokenRange(lNameToken);
        lItems.Add(lItemNode);
      end;
    if FStream.MatchSymbol(psyColon) and CaptureDeclaredType(False, False,
      lDeclaredTypeText, lDeclaredTypeRange) then
      for lIdx := 0 to lItems.Count - 1 do
        SetDeclaredType(TNXPasASTNode(lItems[lIdx]), lDeclaredTypeText,
          lDeclaredTypeRange);
    SkipToDeclarationEnd;
    SkipDeclarationTailDirectives;
    for lIdx := 0 to lItems.Count - 1 do
      SetNodeRange(TNXPasASTNode(lItems[lIdx]),
        TNXPasASTNode(lItems[lIdx]).Range.StartPos, FLastDeclarationEnd);
  end;
  finally
    lItems.Free;
  end;
end;

procedure TNXPasParser.ParseRoutineDecl(AParent: TNXPasASTNode);
var
  lStartPos: TNXPasSourcePosition;
begin
  lStartPos := FStream.Current.StartPos;
  ParseRoutineDeclAt(AParent, lStartPos);
end;

procedure TNXPasParser.ParseRoutineDeclAt(AParent: TNXPasASTNode;
  const AStartPos: TNXPasSourcePosition);
var
  lDeclaredTypeRange: TNXPasSourceRange;
  lDeclaredTypeText: string;
  lEndToken: TNXPasToken;
  lNameToken: TNXPasToken;
  lNode: TNXPasASTNode;
  lOwnerRange: TNXPasSourceRange;
  lRoutineName: string;
begin
  lNode := AParent.AddChild(pnkRoutineDecl);
  FStream.Next;
  if FStream.ExpectIdentifierToken(lNameToken) then
  begin
    lRoutineName := FStream.TokenText(lNameToken);
    lEndToken := lNameToken;
    lOwnerRange.StartPos.Offset := 0;
    lOwnerRange.StartPos.Line := 0;
    lOwnerRange.StartPos.Column := 0;
    lOwnerRange.EndPos.Offset := 0;
    lOwnerRange.EndPos.Line := 0;
    lOwnerRange.EndPos.Column := 0;
    while FStream.MatchSymbol(psyDot) do
    begin
      if lOwnerRange.StartPos.Offset = 0 then
        lOwnerRange.StartPos := lEndToken.StartPos;
      lOwnerRange.EndPos := lEndToken.EndPos;
      if not FStream.ExpectIdentifierToken(lNameToken) then
        Break;
      lRoutineName := lRoutineName + '.' + FStream.TokenText(lNameToken);
      lEndToken := lNameToken;
    end;
    lNode.Name := lRoutineName;
    lNode.NameRange := TokenRange(lEndToken);
    lNode.OwnerNameRange := lOwnerRange;
    SetNodeRange(lNode, AStartPos, lEndToken.EndPos);
  end
  else
  begin
    lNode.Range := CurrentRange;
    AddExpectedDiagnostic('nxpas.routine.malformed',
      'Expected routine name.');
  end;
  if FStream.CheckSymbol(psyOpenParen) then
    ParseRoutineParameters(lNode);
  if FStream.MatchSymbol(psyColon) and CaptureDeclaredType(False, False,
    lDeclaredTypeText, lDeclaredTypeRange) then
    SetDeclaredType(lNode, lDeclaredTypeText, lDeclaredTypeRange);
  SkipToDeclarationEnd;
  SkipRoutineDirectives;
  SetNodeRange(lNode, AStartPos, FLastDeclarationEnd);
  if (FCurrentUsesSection <> pusInterface) and
    not (AParent.Kind in [pnkClassDecl, pnkObjectDecl, pnkRecordDecl,
    pnkInterfaceDecl]) then
  begin
    ParseRoutineBodyDeclarations(lNode);
    if FStream.CheckKeyword(pkwBegin) then
      SkipRoutineBody(lNode);
  end;
end;

procedure TNXPasParser.ParseRoutineParameters(AParent: TNXPasASTNode);
var
  lDeclaredTypeRange: TNXPasSourceRange;
  lDeclaredTypeText: string;
  lItems: TObjectList;
  lNameToken: TNXPasToken;
  lParamNode: TNXPasASTNode;
  lIdx: Integer;
begin
  if not FStream.MatchSymbol(psyOpenParen) then
    Exit;

  lItems := TObjectList.Create(False);
  try
    while not (FStream.Check(ptkEndOfFile) or FStream.CheckSymbol(psyCloseParen)) do
    begin
      lItems.Clear;
      if FStream.CheckKeyword(pkwConst) or
        IsParameterModifier or FStream.CheckKeyword(pkwVar) or
        FStream.CheckKeyword(pkwOut) then
        FStream.Next;

      if not FStream.ExpectIdentifierToken(lNameToken) then
      begin
        FStream.Next;
        Continue;
      end;

      lParamNode := AParent.AddChild(pnkParameterDecl, FStream.TokenText(lNameToken));
      lParamNode.Range := TokenRange(lNameToken);
      lParamNode.NameRange := TokenRange(lNameToken);
      lItems.Add(lParamNode);
      while FStream.MatchSymbol(psyComma) do
        if FStream.ExpectIdentifierToken(lNameToken) then
        begin
          lParamNode := AParent.AddChild(pnkParameterDecl, FStream.TokenText(lNameToken));
          lParamNode.Range := TokenRange(lNameToken);
          lParamNode.NameRange := TokenRange(lNameToken);
          lItems.Add(lParamNode);
        end;

      if FStream.MatchSymbol(psyColon) and CaptureDeclaredType(False, True,
        lDeclaredTypeText, lDeclaredTypeRange) then
        for lIdx := 0 to lItems.Count - 1 do
          SetDeclaredType(TNXPasASTNode(lItems[lIdx]), lDeclaredTypeText,
            lDeclaredTypeRange);

      if FStream.CheckSymbol(psySemicolon) then
        FStream.Next
      else if not FStream.CheckSymbol(psyCloseParen) then
        FStream.Next;
    end;
  finally
    lItems.Free;
  end;

  if FStream.CheckSymbol(psyCloseParen) then
    FStream.Next;
end;

procedure TNXPasParser.ParseRoutineBodyDeclarations(AParent: TNXPasASTNode);
begin
  while not (FStream.Check(ptkEndOfFile) or FStream.CheckKeyword(pkwBegin) or
    FStream.CheckKeyword(pkwEnd) or IsSectionStart or IsRoutineKeyword) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) or FStream.CheckKeyword(pkwBegin) or
      FStream.CheckKeyword(pkwEnd) or IsSectionStart or IsRoutineKeyword then
      Break;

    if FStream.CheckKeyword(pkwVar) then
      ParseVarSection(AParent)
    else if FStream.CheckKeyword(pkwConst) or
      FStream.CheckKeyword(pkwResourcestring) then
      ParseConstSection(AParent)
    else if FStream.CheckKeyword(pkwType) then
      ParseTypeSection(AParent)
    else
      FStream.Next;
  end;
end;

procedure TNXPasParser.SkipRoutineBody(ANode: TNXPasASTNode);
var
  lDepth: Integer;
  lEndPos: TNXPasSourcePosition;
begin
  if (ANode = nil) or not FStream.CheckKeyword(pkwBegin) then
    Exit;

  lDepth := 0;
  lEndPos := FStream.Current.EndPos;
  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.Check(ptkDirective) then
    begin
      ProcessDirective;
      Continue;
    end;

    if FStream.CheckKeyword(pkwBegin) then
      Inc(lDepth)
    else if FStream.CheckKeyword(pkwEnd) then
    begin
      Dec(lDepth);
      lEndPos := FStream.Current.EndPos;
      FStream.Next;
      if lDepth <= 0 then
      begin
        if FStream.CheckSymbol(psySemicolon) then
        begin
          lEndPos := FStream.Current.EndPos;
          FStream.Next;
        end;
        SetNodeRange(ANode, ANode.Range.StartPos, lEndPos);
        Exit;
      end;
      Continue;
    end;

    lEndPos := FStream.Current.EndPos;
    FStream.Next;
  end;

  SetNodeRange(ANode, ANode.Range.StartPos, lEndPos);
end;

procedure TNXPasParser.ParseTypeDecl(AParent: TNXPasASTNode);
var
  lDeclaredTypeRange: TNXPasSourceRange;
  lDeclaredTypeText: string;
  lNameToken: TNXPasToken;
  lNode: TNXPasASTNode;
  lChildNode: TNXPasASTNode;
  lTypeToken: TNXPasToken;
begin
  if not FStream.ExpectIdentifierToken(lNameToken) then
  begin
    if not FStream.Check(ptkDirective) then
      AddExpectedDiagnostic('nxpas.type.malformed',
        'Expected type declaration name.');
    FStream.Next;
    Exit;
  end;

  lNode := AParent.AddChild(pnkTypeDecl, FStream.TokenText(lNameToken));
  lNode.Range := TokenRange(lNameToken);
  lNode.NameRange := TokenRange(lNameToken);
  if not FStream.MatchSymbol(psyEquals) then
  begin
    SkipToDeclarationEnd;
    Exit;
  end;

  if FStream.CheckKeyword(pkwClass) and
    FStream.CheckPeekKeyword(1, pkwOf) then
  begin
    lTypeToken := FStream.Current;
    FStream.Next;
    if CaptureDeclaredType(False, False, lDeclaredTypeText,
      lDeclaredTypeRange) then
    begin
      lDeclaredTypeRange.StartPos := lTypeToken.StartPos;
      SetDeclaredType(lNode, 'class ' + lDeclaredTypeText,
        lDeclaredTypeRange);
    end;
    SkipToDeclarationEnd(False);
    Exit;
  end;

  if FStream.CheckKeyword(pkwClass) then
  begin
    lTypeToken := FStream.Current;
    FStream.Next;
    lChildNode := lNode.AddChild(pnkClassDecl, FStream.TokenText(lNameToken));
    lChildNode.NameRange := TokenRange(lNameToken);
    SetNodeRange(lChildNode, lNameToken.StartPos, lTypeToken.EndPos);
    CaptureStructuredTypeHeritage(lChildNode);
    if TryFinishForwardStructuredType(lNode, lChildNode) then
      Exit;
    ParseStructuredTypeBody(lChildNode);
    lNode.Range := lChildNode.Range;
    Exit;
  end
  else if FStream.CheckKeyword(pkwObject) then
  begin
    lChildNode := lNode.AddChild(pnkObjectDecl, FStream.TokenText(lNameToken));
    lChildNode.NameRange := TokenRange(lNameToken);
    SetNodeRange(lChildNode, lNameToken.StartPos, FStream.Current.EndPos);
    FStream.Next;
    CaptureStructuredTypeHeritage(lChildNode);
    if TryFinishForwardStructuredType(lNode, lChildNode) then
      Exit;
    ParseStructuredTypeBody(lChildNode);
    lNode.Range := lChildNode.Range;
    Exit;
  end
  else if FStream.CheckKeyword(pkwRecord) then
  begin
    lChildNode := lNode.AddChild(pnkRecordDecl, FStream.TokenText(lNameToken));
    lChildNode.NameRange := TokenRange(lNameToken);
    SetNodeRange(lChildNode, lNameToken.StartPos, FStream.Current.EndPos);
    FStream.Next;
    ParseStructuredTypeBody(lChildNode);
    lNode.Range := lChildNode.Range;
    Exit;
  end
  else if FStream.CheckKeyword(pkwInterface) then
  begin
    lChildNode := lNode.AddChild(pnkInterfaceDecl, FStream.TokenText(lNameToken));
    lChildNode.NameRange := TokenRange(lNameToken);
    SetNodeRange(lChildNode, lNameToken.StartPos, FStream.Current.EndPos);
    FStream.Next;
    CaptureStructuredTypeHeritage(lChildNode);
    if TryFinishForwardStructuredType(lNode, lChildNode) then
      Exit;
    ParseStructuredTypeBody(lChildNode);
    lNode.Range := lChildNode.Range;
    Exit;
  end;

  if CaptureDeclaredType(False, False, lDeclaredTypeText, lDeclaredTypeRange) then
    SetDeclaredType(lNode, lDeclaredTypeText, lDeclaredTypeRange);
  SkipToDeclarationEnd(False);
end;

function TNXPasParser.TryFinishForwardStructuredType(ANode,
  AChildNode: TNXPasASTNode): Boolean;
var
  lEndPos: TNXPasSourcePosition;
begin
  Result := False;
  if not FStream.CheckSymbol(psySemicolon) then
    Exit;

  lEndPos := FStream.Current.EndPos;
  FStream.Next;
  SetNodeRange(AChildNode, AChildNode.Range.StartPos, lEndPos);
  ANode.Range := AChildNode.Range;
  Result := True;
end;

procedure TNXPasParser.CaptureStructuredTypeHeritage(ANode: TNXPasASTNode);
var
  lEndPos: TNXPasSourcePosition;
  lRange: TNXPasSourceRange;
  lStartPos: TNXPasSourcePosition;
  lDepth: Integer;
begin
  if (ANode = nil) or not FStream.CheckSymbol(psyOpenParen) then
    Exit;

  FStream.Next;
  if FStream.Check(ptkEndOfFile) then
    Exit;

  lStartPos := FStream.Current.StartPos;
  lEndPos := FStream.Current.EndPos;
  lDepth := 1;
  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.CheckSymbol(psyOpenParen) then
      Inc(lDepth)
    else if FStream.CheckSymbol(psyCloseParen) then
    begin
      Dec(lDepth);
      if lDepth = 0 then
      begin
        lRange.StartPos := lStartPos;
        lRange.EndPos := lEndPos;
        SetDeclaredType(ANode, SourceText(lRange), lRange);
        FStream.Next;
        Exit;
      end;
    end;

    lEndPos := FStream.Current.EndPos;
    FStream.Next;
  end;
end;

procedure TNXPasParser.ParseStructuredTypeBody(ANode: TNXPasASTNode);
var
  lClassStartPos: TNXPasSourcePosition;
  lStartPos: TNXPasSourcePosition;
  lEndPos: TNXPasSourcePosition;
begin
  lStartPos := ANode.Range.StartPos;
  lEndPos := ANode.Range.EndPos;

  while not FStream.Check(ptkEndOfFile) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) then
      Break;

    if FStream.Check(ptkDirective) then
    begin
      ProcessDirective;
      Continue;
    end;

    if FStream.CheckKeyword(pkwVar) then
    begin
      FStream.Next;
      Continue;
    end;

    if FStream.CheckKeyword(pkwClass) and
      FStream.CheckPeekKeyword(1, pkwVar) then
    begin
      FStream.Next;
      FStream.Next;
      Continue;
    end;

    if FStream.CheckKeyword(pkwClass) and IsRoutineKeywordAt(1) then
    begin
      lClassStartPos := FStream.Current.StartPos;
      FStream.Next;
      ParseRoutineDeclAt(ANode, lClassStartPos);
      Continue;
    end;

    if FStream.CheckKeyword(pkwClass) and
      FStream.CheckPeekKeyword(1, pkwProperty) then
    begin
      FStream.Next;
      ParsePropertyDecl(ANode);
      Continue;
    end;

    if IsSectionStart or IsDeclarationSectionStart then
    begin
      AddExpectedDiagnostic('nxpas.structuredType.missingEnd',
        'Missing end for structured type body.');
      SetNodeRange(ANode, lStartPos, lEndPos);
      Exit;
    end;

    if FStream.CheckKeyword(pkwEnd) then
    begin
      lEndPos := FStream.Current.EndPos;
      FStream.Next;
      if FStream.CheckSymbol(psySemicolon) then
      begin
        lEndPos := FStream.Current.EndPos;
        FStream.Next;
      end;
      SetNodeRange(ANode, lStartPos, lEndPos);
      Exit;
    end;

    if IsVisibilityKeyword then
      ParseVisibilitySection(ANode)
    else if IsRoutineKeyword then
      ParseRoutineDecl(ANode)
    else if FStream.CheckKeyword(pkwProperty) then
      ParsePropertyDecl(ANode)
    else if IsFieldNameToken then
      ParseFieldDecl(ANode)
    else
      FStream.Next;
  end;

  AddExpectedDiagnostic('nxpas.declaration.unexpectedEOF',
    'Unexpected EOF inside declaration body.');
  AddExpectedDiagnostic('nxpas.structuredType.missingEnd',
    'Missing end for structured type body.');
  SetNodeRange(ANode, lStartPos, lEndPos);
end;

procedure TNXPasParser.ParseFieldDecl(AParent: TNXPasASTNode);
var
  lDeclaredTypeRange: TNXPasSourceRange;
  lDeclaredTypeText: string;
  lItems: TObjectList;
  lIdx: Integer;
  lNameToken: TNXPasToken;
  lNode: TNXPasASTNode;
begin
  if not ExpectFieldNameToken(lNameToken) then
    Exit;

  lItems := TObjectList.Create(False);
  try
  lNode := AParent.AddChild(pnkFieldDecl, FStream.TokenText(lNameToken));
  lNode.Range := TokenRange(lNameToken);
  lNode.NameRange := TokenRange(lNameToken);
  lItems.Add(lNode);
  while FStream.MatchSymbol(psyComma) do
    if ExpectFieldNameToken(lNameToken) then
    begin
      lNode := AParent.AddChild(pnkFieldDecl, FStream.TokenText(lNameToken));
      lNode.Range := TokenRange(lNameToken);
      lNode.NameRange := TokenRange(lNameToken);
      lItems.Add(lNode);
    end;
  if FStream.MatchSymbol(psyColon) and CaptureDeclaredType(False, False,
    lDeclaredTypeText, lDeclaredTypeRange) then
    for lIdx := 0 to lItems.Count - 1 do
      SetDeclaredType(TNXPasASTNode(lItems[lIdx]), lDeclaredTypeText,
        lDeclaredTypeRange);
  SkipToDeclarationEnd;
  for lIdx := 0 to lItems.Count - 1 do
    SetNodeRange(TNXPasASTNode(lItems[lIdx]),
      TNXPasASTNode(lItems[lIdx]).Range.StartPos, FLastDeclarationEnd);
  finally
    lItems.Free;
  end;
end;

procedure TNXPasParser.ParsePropertyDecl(AParent: TNXPasASTNode);
var
  lDeclaredTypeRange: TNXPasSourceRange;
  lDeclaredTypeText: string;
  lNameToken: TNXPasToken;
  lNode: TNXPasASTNode;
  lStartPos: TNXPasSourcePosition;
begin
  lStartPos := FStream.Current.StartPos;
  lNode := nil;
  FStream.Next;
  if FStream.ExpectIdentifierToken(lNameToken) then
  begin
    lNode := AParent.AddChild(pnkPropertyDecl, FStream.TokenText(lNameToken));
    lNode.NameRange := TokenRange(lNameToken);
    SetNodeRange(lNode, lStartPos, lNameToken.EndPos);
    SkipPropertyParameters;
    if FStream.MatchSymbol(psyColon) and CaptureDeclaredType(True, False,
      lDeclaredTypeText, lDeclaredTypeRange) then
      SetDeclaredType(lNode, lDeclaredTypeText, lDeclaredTypeRange);
  end;
  SkipToDeclarationEnd;
  if lNode <> nil then
    SetNodeRange(lNode, lNode.Range.StartPos, FLastDeclarationEnd);
  while IsPropertyDefaultSpecifier do
  begin
    SkipToDeclarationEnd;
    if lNode <> nil then
      SetNodeRange(lNode, lNode.Range.StartPos, FLastDeclarationEnd);
  end;
end;

function TNXPasParser.ExpectDeclarationNameToken(
  out AToken: TNXPasToken): Boolean;
begin
  Result := IsDeclarationNameToken;
  if Result then
  begin
    AToken := FStream.Current;
    FStream.Next;
  end
  else
  begin
    AToken.Kind := ptkUnknown;
    NXPasClearToken(AToken);
  end;
end;

function TNXPasParser.ExpectFieldNameToken(out AToken: TNXPasToken): Boolean;
begin
  Result := IsFieldNameToken;
  if Result then
  begin
    AToken := FStream.Current;
    FStream.Next;
  end
  else
  begin
    AToken.Kind := ptkUnknown;
    NXPasClearToken(AToken);
  end;
end;

procedure TNXPasParser.SkipPropertyParameters;
var
  lBracketDepth: Integer;
  lParenDepth: Integer;
begin
  lBracketDepth := 0;
  lParenDepth := 0;
  if not (FStream.CheckSymbol(psyOpenBracket) or FStream.CheckSymbol(psyOpenParen)) then
    Exit;

  repeat
    if FStream.CheckSymbol(psyOpenBracket) then
      Inc(lBracketDepth)
    else if FStream.CheckSymbol(psyCloseBracket) and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if FStream.CheckSymbol(psyOpenParen) then
      Inc(lParenDepth)
    else if FStream.CheckSymbol(psyCloseParen) and (lParenDepth > 0) then
      Dec(lParenDepth);

    FStream.Next;
  until FStream.Check(ptkEndOfFile) or
    ((lBracketDepth = 0) and (lParenDepth = 0));
end;

procedure TNXPasParser.ParseVisibilitySection(AParent: TNXPasASTNode);
var
  lNode: TNXPasASTNode;
begin
  lNode := AParent.AddChild(pnkVisibilitySection, FStream.CurrentText);
  lNode.Range := CurrentRange;
  FStream.Next;
end;

function TNXPasParser.CaptureDeclaredType(AStopAtPropertyModifier,
  AStopAtParameterDelimiter: Boolean; out AText: string;
  out ARange: TNXPasSourceRange): Boolean;
var
  lAngleDepth: Integer;
  lBracketDepth: Integer;
  lEndPos: TNXPasSourcePosition;
  lParenDepth: Integer;
  lPreviousKeyword: TNXPasKeywordKind;
  lStartPos: TNXPasSourcePosition;
  lStructuredDepth: Integer;
begin
  Result := False;
  AText := '';
  lAngleDepth := 0;
  lBracketDepth := 0;
  lParenDepth := 0;
  lPreviousKeyword := pkwNone;
  lStructuredDepth := 0;

  if FStream.Check(ptkEndOfFile) then
    Exit;

  lStartPos := FStream.Current.StartPos;
  lEndPos := FStream.Current.EndPos;
  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.Check(ptkDirective) then
      Break;

    if (lParenDepth = 0) and (lBracketDepth = 0) and (lAngleDepth = 0) and
      (lStructuredDepth = 0) then
    begin
      if FStream.CheckSymbol(psySemicolon) or FStream.CheckSymbol(psyEquals) then
        Break;
      if AStopAtParameterDelimiter and
        (FStream.CheckSymbol(psyCloseParen) or FStream.CheckSymbol(psyComma)) then
        Break;
      if AStopAtPropertyModifier and
        IsPropertySpecifier then
        Break;
      if IsDeclarationTailKeyword then
        Break;
      if IsSectionStart or
        (IsDeclarationSectionStart and
        not FStream.CheckKeyword(pkwType) and
        not (FStream.CheckKeyword(pkwConst) and
        (lPreviousKeyword = pkwOf))) or
        FStream.CheckKeyword(pkwBegin) or
        FStream.CheckKeyword(pkwEnd) then
        Break;
    end;

    lEndPos := FStream.Current.EndPos;
    if FStream.CheckSymbol(psyOpenParen) then
      Inc(lParenDepth)
    else if FStream.CheckSymbol(psyCloseParen) and (lParenDepth > 0) then
      Dec(lParenDepth)
    else if FStream.CheckSymbol(psyOpenBracket) then
      Inc(lBracketDepth)
    else if FStream.CheckSymbol(psyCloseBracket) and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if FStream.CheckSymbol(psyLess) then
      Inc(lAngleDepth)
    else if FStream.CheckSymbol(psyGreater) and (lAngleDepth > 0) then
      Dec(lAngleDepth);
    if FStream.CheckKeyword(pkwRecord) or
      (FStream.CheckKeyword(pkwObject) and
      (lPreviousKeyword <> pkwOf)) or
      (FStream.CheckKeyword(pkwClass) and
      (lPreviousKeyword <> pkwType)) or
      FStream.CheckKeyword(pkwInterface) then
      Inc(lStructuredDepth)
    else if FStream.CheckKeyword(pkwEnd) and (lStructuredDepth > 0) then
      Dec(lStructuredDepth);

    lPreviousKeyword := FStream.Current.Keyword;
    FStream.Next;
  end;

  ARange.StartPos := lStartPos;
  ARange.EndPos := lEndPos;
  AText := SourceText(ARange);
  Result := AText <> '';
end;

procedure TNXPasParser.SkipToDeclarationEnd(AStopAtRoutineKeyword: Boolean);
var
  lAngleDepth: Integer;
  lBracketDepth: Integer;
  lParenDepth: Integer;
  lPreviousKeyword: TNXPasKeywordKind;
  lStructuredDepth: Integer;
begin
  lAngleDepth := 0;
  lBracketDepth := 0;
  lParenDepth := 0;
  lPreviousKeyword := pkwNone;
  lStructuredDepth := 0;
  FLastDeclarationEnd := FStream.Current.EndPos;

  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.Check(ptkDirective) then
    begin
      ProcessDirective;
      Continue;
    end;

    if FStream.CheckSymbol(psySemicolon) and (lParenDepth = 0) and
      (lBracketDepth = 0) and (lAngleDepth = 0) and (lStructuredDepth = 0) then
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
      Exit;
    end;

    if (lParenDepth = 0) and (lBracketDepth = 0) and (lAngleDepth = 0) and
      (lStructuredDepth = 0) and
      (IsSectionStart or IsDeclarationSectionStart or
      (AStopAtRoutineKeyword and IsRoutineKeyword) or
      IsVisibilityKeyword or FStream.CheckKeyword(pkwEnd)) then
    begin
      AddExpectedDiagnostic('nxpas.declaration.missingSemicolon',
        'Missing semicolon after declaration.');
      FLastDeclarationEnd := FStream.Current.StartPos;
      Exit;
    end;

    if FStream.CheckSymbol(psyOpenParen) then
      Inc(lParenDepth)
    else if FStream.CheckSymbol(psyCloseParen) and (lParenDepth > 0) then
      Dec(lParenDepth)
    else if FStream.CheckSymbol(psyOpenBracket) then
      Inc(lBracketDepth)
    else if FStream.CheckSymbol(psyCloseBracket) and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if FStream.CheckSymbol(psyLess) then
      Inc(lAngleDepth)
    else if FStream.CheckSymbol(psyGreater) and (lAngleDepth > 0) then
      Dec(lAngleDepth);
    if FStream.CheckKeyword(pkwRecord) or
      (FStream.CheckKeyword(pkwObject) and
      (lPreviousKeyword <> pkwOf)) or
      FStream.CheckKeyword(pkwClass) or
      FStream.CheckKeyword(pkwInterface) then
      Inc(lStructuredDepth)
    else if FStream.CheckKeyword(pkwEnd) and (lStructuredDepth > 0) then
      Dec(lStructuredDepth);

    lPreviousKeyword := FStream.Current.Keyword;
    FStream.Next;
  end;
  FLastDeclarationEnd := FStream.Current.StartPos;
  AddExpectedDiagnostic('nxpas.declaration.unexpectedEOF',
    'Unexpected EOF inside declaration body.');
end;

procedure TNXPasParser.SkipRoutineDirectives;
begin
  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.CheckSymbol(psySemicolon) then
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
      Continue;
    end;

    if not IsRoutineDirective then
      Exit;

    while not (FStream.Check(ptkEndOfFile) or FStream.CheckSymbol(psySemicolon) or
      IsSectionStart or IsDeclarationSectionStart or IsRoutineKeyword or
      IsVisibilityKeyword or FStream.CheckKeyword(pkwEnd) or
      FStream.CheckKeyword(pkwProperty)) do
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
    end;

    if FStream.CheckSymbol(psySemicolon) then
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
    end
    else
      Exit;
  end;
end;

procedure TNXPasParser.SkipDeclarationTailDirectives;
begin
  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.CheckSymbol(psySemicolon) then
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
      Continue;
    end;

    if not IsDeclarationTailKeyword then
      Exit;

    while not (FStream.Check(ptkEndOfFile) or FStream.CheckSymbol(psySemicolon) or
      IsSectionStart or IsDeclarationSectionStart or IsRoutineKeyword or
      FStream.CheckKeyword(pkwEnd)) do
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
    end;

    if FStream.CheckSymbol(psySemicolon) then
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
    end
    else
      Exit;
  end;
end;

function TNXPasParser.Parse(ASource: TNXPasSourceFile): TNXPasSyntaxTree;
var
  lIdx: Integer;
  lLexer: TNXPasLexer;
begin
  FCurrentActive := True;
  FCurrentUsesSection := pusUnknown;
  FHeaderParsed := False;
  FDirectiveStack.Clear;
  FDefines.Clear;
  if ASource <> nil then
    for lIdx := 0 to ASource.Defines.Count - 1 do
      if FDefines.IndexOf(UpperCase(ASource.Defines[lIdx])) < 0 then
        FDefines.Add(UpperCase(ASource.Defines[lIdx]));

  lLexer := TNXPasLexer.Create(ASource.Text, FDiagnostics);
  FStream := TNXPasTokenStream.Create(lLexer, True);
  FTree := TNXPasSyntaxTree.Create(ASource);
  try
    AdvanceToActiveToken;
    while not FStream.Check(ptkEndOfFile) do
    begin
      AdvanceToActiveToken;
      if FStream.Check(ptkEndOfFile) then
        Break;
      if not FHeaderParsed and (FStream.CheckKeyword(pkwUnit) or
        FStream.CheckKeyword(pkwProgram) or
        FStream.CheckKeyword(pkwLibrary) or
        FStream.CheckKeyword(pkwPackage)) then
        ParseHeader
      else
      ParseSection;
    end;
    if not FHeaderParsed then
      AddExpectedDiagnostic('nxpas.header.missing',
        'No active unit, program, or library header found.');
    FinishDirectiveStack;
    Result := FTree;
    FTree := nil;
  finally
    FStream.Free;
    FStream := nil;
    FTree.Free;
    FTree := nil;
  end;
end;

end.

