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
    function IsStructuredTypeKeyword: Boolean;
    function IsSectionStart: Boolean;
    function IsDeclarationSectionStart: Boolean;
    function IsVisibilityKeyword: Boolean;
    function IsRoutineDirective: Boolean;
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
    procedure ParseRoutineParameters(AParent: TNXPasASTNode);
    procedure ParseRoutineBodyDeclarations(AParent: TNXPasASTNode);
    procedure SkipRoutineBody(ANode: TNXPasASTNode);
    procedure ParseTypeDecl(AParent: TNXPasASTNode);
    procedure ParseStructuredTypeBody(ANode: TNXPasASTNode);
    procedure CaptureStructuredTypeHeritage(ANode: TNXPasASTNode);
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
  Result := FStream.Check(ptkKeyword, 'procedure') or
    FStream.Check(ptkKeyword, 'function') or
    FStream.Check(ptkKeyword, 'constructor') or
    FStream.Check(ptkKeyword, 'destructor');
end;

function TNXPasParser.IsStructuredTypeKeyword: Boolean;
begin
  Result := FStream.Check(ptkKeyword, 'class') or
    FStream.Check(ptkKeyword, 'object') or FStream.Check(ptkKeyword, 'record') or
    FStream.Check(ptkKeyword, 'interface');
end;

function TNXPasParser.IsSectionStart: Boolean;
begin
  Result := FStream.Check(ptkKeyword, 'interface') or
    FStream.Check(ptkKeyword, 'implementation') or
    FStream.Check(ptkKeyword, 'initialization') or
    FStream.Check(ptkKeyword, 'finalization');
end;

function TNXPasParser.IsDeclarationSectionStart: Boolean;
begin
  Result := FStream.Check(ptkKeyword, 'type') or
    FStream.Check(ptkKeyword, 'const') or FStream.Check(ptkKeyword, 'var') or
    FStream.Check(ptkKeyword, 'threadvar') or
    FStream.Check(ptkKeyword, 'resourcestring');
end;

function TNXPasParser.IsVisibilityKeyword: Boolean;
begin
  Result := FStream.Check(ptkKeyword, 'private') or
    FStream.Check(ptkKeyword, 'protected') or FStream.Check(ptkKeyword, 'public') or
    FStream.Check(ptkKeyword, 'published');
end;

function TNXPasParser.IsRoutineDirective: Boolean;
begin
  Result := (FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
    (SameText(FStream.Current.Text, 'abstract') or
    SameText(FStream.Current.Text, 'alias') or
    SameText(FStream.Current.Text, 'assembler') or
    SameText(FStream.Current.Text, 'cdecl') or
    SameText(FStream.Current.Text, 'compilerproc') or
    SameText(FStream.Current.Text, 'deprecated') or
    SameText(FStream.Current.Text, 'dynamic') or
    SameText(FStream.Current.Text, 'experimental') or
    SameText(FStream.Current.Text, 'export') or
    SameText(FStream.Current.Text, 'external') or
    SameText(FStream.Current.Text, 'far') or
    SameText(FStream.Current.Text, 'final') or
    SameText(FStream.Current.Text, 'forward') or
    SameText(FStream.Current.Text, 'hardfloat') or
    SameText(FStream.Current.Text, 'inline') or
    SameText(FStream.Current.Text, 'message') or
    SameText(FStream.Current.Text, 'ms_abi_cdecl') or
    SameText(FStream.Current.Text, 'ms_abi_default') or
    SameText(FStream.Current.Text, 'mwpascal') or
    SameText(FStream.Current.Text, 'noreturn') or
    SameText(FStream.Current.Text, 'oldfpccall') or
    SameText(FStream.Current.Text, 'overload') or
    SameText(FStream.Current.Text, 'override') or
    SameText(FStream.Current.Text, 'pascal') or
    SameText(FStream.Current.Text, 'platform') or
    SameText(FStream.Current.Text, 'public') or
    SameText(FStream.Current.Text, 'reintroduce') or
    SameText(FStream.Current.Text, 'safecall') or
    SameText(FStream.Current.Text, 'stdcall') or
    SameText(FStream.Current.Text, 'sysv_abi_cdecl') or
    SameText(FStream.Current.Text, 'sysv_abi_default') or
    SameText(FStream.Current.Text, 'unimplemented') or
    SameText(FStream.Current.Text, 'varargs') or
    SameText(FStream.Current.Text, 'vectorcall') or
    SameText(FStream.Current.Text, 'virtual'));
end;

function TNXPasParser.IsFieldNameToken: Boolean;
begin
  Result := FStream.Check(ptkIdentifier) or FStream.Check(ptkKeyword, 'helper');
end;

function TNXPasParser.IsDeclarationNameToken: Boolean;
begin
  Result := FStream.Check(ptkIdentifier) or FStream.Check(ptkKeyword, 'helper');
end;

function TNXPasParser.IsDeclarationTailKeyword: Boolean;
begin
  Result := (FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
    (SameText(FStream.Current.Text, 'absolute') or
    SameText(FStream.Current.Text, 'cvar') or
    SameText(FStream.Current.Text, 'deprecated') or
    SameText(FStream.Current.Text, 'experimental') or
    SameText(FStream.Current.Text, 'external') or
    SameText(FStream.Current.Text, 'name') or
    SameText(FStream.Current.Text, 'platform') or
    SameText(FStream.Current.Text, 'public'));
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
  lCommand := DirectiveCommand(FStream.Current.Text);
  lArg := DirectiveArgument(FStream.Current.Text);
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
  Result := FStream.Check(ptkEndOfFile) or FStream.Check(ptkSymbol, ';') or
    FStream.Check(ptkDirective) or IsSectionStart or IsDeclarationSectionStart or
    IsRoutineKeyword or IsVisibilityKeyword or FStream.Check(ptkKeyword, 'end');
end;

procedure TNXPasParser.RecoverDeclaration;
begin
  while not RecoverAtSynchronizationPoint do
    FStream.Next;
  if FStream.Check(ptkSymbol, ';') then
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
    lNode := AParent.AddChild(AKind, lToken.Text);
    lNode.Range := TokenRange(lToken);
    Result := True;
    if not FStream.MatchSymbol(',') then
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
  if not (FStream.Check(ptkKeyword, 'unit') or
    FStream.Check(ptkKeyword, 'program') or
    FStream.Check(ptkKeyword, 'library') or
    FStream.Check(ptkKeyword, 'package')) then
    Exit;

  FHeaderParsed := True;

  lStart := FStream.Current.StartPos;
  if FStream.Check(ptkKeyword, 'program') then
    lKind := pnkProgramHeader
  else if FStream.Check(ptkKeyword, 'library') then
    lKind := pnkLibraryHeader
  else if FStream.Check(ptkKeyword, 'package') then
    lKind := pnkHeader
  else
    lKind := pnkUnitHeader;
  lNode := FTree.Root.AddChild(lKind);
  if FStream.Check(ptkKeyword, 'unit') then
    FTree.Metadata.CompilationKind := pckUnit
  else if FStream.Check(ptkKeyword, 'program') then
    FTree.Metadata.CompilationKind := pckProgram
  else if FStream.Check(ptkKeyword, 'library') then
    FTree.Metadata.CompilationKind := pckLibrary
  else if FStream.Check(ptkKeyword, 'package') then
    FTree.Metadata.CompilationKind := pckPackage;
  FStream.Next;
  if FStream.ExpectIdentifierToken(lNameToken) then
  begin
    lNode.Name := lNameToken.Text;
    FTree.Metadata.Name := lNameToken.Text;
    SetNodeRange(lNode, lStart, lNameToken.EndPos);
  end
  else
  begin
    lNode.Range := CurrentRange;
    AddExpectedDiagnostic('nxpas.header.malformed',
      'Expected unit, program, library, or package name.');
  end;

  if not FStream.MatchSymbol(';') then
    AddExpectedDiagnostic('nxpas.header.missingSemicolon',
      'Missing semicolon after unit, program, library, or package header.');
end;

procedure TNXPasParser.ParseSection;
var
  lNode: TNXPasASTNode;
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

  if FStream.Check(ptkKeyword, 'interface') then
  begin
    lNode := FTree.Root.AddChild(pnkInterfaceSection, 'interface');
    lNode.Range := CurrentRange;
    FCurrentUsesSection := pusInterface;
    FStream.Next;
    Exit;
  end;

  if FStream.Check(ptkKeyword, 'implementation') then
  begin
    lNode := FTree.Root.AddChild(pnkImplementationSection, 'implementation');
    lNode.Range := CurrentRange;
    FCurrentUsesSection := pusImplementation;
    FStream.Next;
    Exit;
  end;

  lNode := FTree.Root;
  if FStream.Check(ptkKeyword, 'uses') then
    ParseUsesClause(lNode)
  else if FStream.Check(ptkKeyword, 'type') then
    ParseTypeSection(lNode)
  else if FStream.Check(ptkKeyword, 'const') or
    FStream.Check(ptkKeyword, 'resourcestring') then
    ParseConstSection(lNode)
  else if FStream.Check(ptkKeyword, 'var') or
    FStream.Check(ptkKeyword, 'threadvar') then
    ParseVarSection(lNode)
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

    if FStream.Check(ptkSymbol, ';') then
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
  lNode := AParent.AddChild(pnkUsesUnit, lNameToken.Text);
  lNode.Range := lRange;

  if FStream.MatchKeyword('in') then
  begin
    if FStream.Check(ptkString) then
    begin
      lFileName := StringLiteralValue(FStream.Current.Text);
      lRange.EndPos := FStream.Current.EndPos;
      lNode.Range := lRange;
      FStream.Next;
    end
    else
      AddExpectedDiagnostic('nxpas.uses.missingInFile',
        'Expected filename string after uses in clause.');
  end;

  lEntry := FTree.Metadata.UsesForSection(ASection).AddEntry(lNameToken.Text,
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
  while not (FStream.Check(ptkEndOfFile) or FStream.Check(ptkKeyword, 'const') or
    FStream.Check(ptkKeyword, 'var') or FStream.Check(ptkKeyword, 'threadvar') or
    FStream.Check(ptkKeyword, 'resourcestring') or FStream.Check(ptkKeyword, 'uses') or
    IsRoutineKeyword or FStream.Check(ptkKeyword, 'implementation') or
    FStream.Check(ptkKeyword, 'begin')) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) or FStream.Check(ptkKeyword, 'const') or
      FStream.Check(ptkKeyword, 'var') or FStream.Check(ptkKeyword, 'threadvar') or
      FStream.Check(ptkKeyword, 'resourcestring') or FStream.Check(ptkKeyword, 'uses') or
      IsRoutineKeyword or FStream.Check(ptkKeyword, 'implementation') or
      FStream.Check(ptkKeyword, 'begin') then
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
    FStream.Check(ptkKeyword, 'begin') or FStream.Check(ptkKeyword, 'end')) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) or IsSectionStart or
      IsDeclarationSectionStart or IsRoutineKeyword or
      FStream.Check(ptkKeyword, 'begin') or FStream.Check(ptkKeyword, 'end') then
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
    lItemNode := lNode.AddChild(pnkConstDecl, lNameToken.Text);
    lItemNode.Range := TokenRange(lNameToken);
    if FStream.MatchSymbol(':') and CaptureDeclaredType(False, False,
      lDeclaredTypeText, lDeclaredTypeRange) then
      SetDeclaredType(lItemNode, lDeclaredTypeText, lDeclaredTypeRange);
    SkipToDeclarationEnd;
    SkipDeclarationTailDirectives;
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
    FStream.Check(ptkKeyword, 'begin') or FStream.Check(ptkKeyword, 'end')) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) or IsSectionStart or
      IsDeclarationSectionStart or IsRoutineKeyword or
      FStream.Check(ptkKeyword, 'begin') or FStream.Check(ptkKeyword, 'end') then
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
    lItemNode := lNode.AddChild(pnkVarDecl, lNameToken.Text);
    lItemNode.Range := TokenRange(lNameToken);
    lItems.Clear;
    lItems.Add(lItemNode);
    while FStream.MatchSymbol(',') do
      if ExpectDeclarationNameToken(lNameToken) then
      begin
        lItemNode := lNode.AddChild(pnkVarDecl, lNameToken.Text);
        lItemNode.Range := TokenRange(lNameToken);
        lItems.Add(lItemNode);
      end;
    if FStream.MatchSymbol(':') and CaptureDeclaredType(False, False,
      lDeclaredTypeText, lDeclaredTypeRange) then
      for lIdx := 0 to lItems.Count - 1 do
        SetDeclaredType(TNXPasASTNode(lItems[lIdx]), lDeclaredTypeText,
          lDeclaredTypeRange);
    SkipToDeclarationEnd;
    SkipDeclarationTailDirectives;
  end;
  finally
    lItems.Free;
  end;
end;

procedure TNXPasParser.ParseRoutineDecl(AParent: TNXPasASTNode);
var
  lDeclaredTypeRange: TNXPasSourceRange;
  lDeclaredTypeText: string;
  lNameToken: TNXPasToken;
  lNode: TNXPasASTNode;
  lStart: TNXPasSourcePosition;
begin
  lStart := FStream.Current.StartPos;
  lNode := AParent.AddChild(pnkRoutineDecl);
  FStream.Next;
  if FStream.ExpectIdentifierToken(lNameToken) then
  begin
    lNode.Name := lNameToken.Text;
    SetNodeRange(lNode, lStart, lNameToken.EndPos);
  end
  else
  begin
    lNode.Range := CurrentRange;
    AddExpectedDiagnostic('nxpas.routine.malformed',
      'Expected routine name.');
  end;
  if FStream.Check(ptkSymbol, '(') then
    ParseRoutineParameters(lNode);
  if FStream.MatchSymbol(':') and CaptureDeclaredType(False, False,
    lDeclaredTypeText, lDeclaredTypeRange) then
    SetDeclaredType(lNode, lDeclaredTypeText, lDeclaredTypeRange);
  SkipToDeclarationEnd;
  SkipRoutineDirectives;
  SetNodeRange(lNode, lStart, FLastDeclarationEnd);
  if not (AParent.Kind in [pnkClassDecl, pnkObjectDecl, pnkRecordDecl,
    pnkInterfaceDecl]) then
  begin
    ParseRoutineBodyDeclarations(lNode);
    if FStream.Check(ptkKeyword, 'begin') then
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
  if not FStream.MatchSymbol('(') then
    Exit;

  lItems := TObjectList.Create(False);
  try
    while not (FStream.Check(ptkEndOfFile) or FStream.Check(ptkSymbol, ')')) do
    begin
      lItems.Clear;
      if FStream.Check(ptkKeyword, 'const') or
        FStream.Check(ptkIdentifier, 'constref') or
        FStream.Check(ptkKeyword, 'var') or FStream.Check(ptkKeyword, 'out') then
        FStream.Next;

      if not FStream.ExpectIdentifierToken(lNameToken) then
      begin
        FStream.Next;
        Continue;
      end;

      lParamNode := AParent.AddChild(pnkParameterDecl, lNameToken.Text);
      lParamNode.Range := TokenRange(lNameToken);
      lItems.Add(lParamNode);
      while FStream.MatchSymbol(',') do
        if FStream.ExpectIdentifierToken(lNameToken) then
        begin
          lParamNode := AParent.AddChild(pnkParameterDecl, lNameToken.Text);
          lParamNode.Range := TokenRange(lNameToken);
          lItems.Add(lParamNode);
        end;

      if FStream.MatchSymbol(':') and CaptureDeclaredType(False, True,
        lDeclaredTypeText, lDeclaredTypeRange) then
        for lIdx := 0 to lItems.Count - 1 do
          SetDeclaredType(TNXPasASTNode(lItems[lIdx]), lDeclaredTypeText,
            lDeclaredTypeRange);

      if FStream.Check(ptkSymbol, ';') then
        FStream.Next
      else if not FStream.Check(ptkSymbol, ')') then
        FStream.Next;
    end;
  finally
    lItems.Free;
  end;

  if FStream.Check(ptkSymbol, ')') then
    FStream.Next;
end;

procedure TNXPasParser.ParseRoutineBodyDeclarations(AParent: TNXPasASTNode);
begin
  while not (FStream.Check(ptkEndOfFile) or FStream.Check(ptkKeyword, 'begin') or
    FStream.Check(ptkKeyword, 'end') or IsSectionStart or IsRoutineKeyword) do
  begin
    AdvanceToActiveToken;
    if FStream.Check(ptkEndOfFile) or FStream.Check(ptkKeyword, 'begin') or
      FStream.Check(ptkKeyword, 'end') or IsSectionStart or IsRoutineKeyword then
      Break;

    if FStream.Check(ptkKeyword, 'var') then
      ParseVarSection(AParent)
    else if FStream.Check(ptkKeyword, 'const') or
      FStream.Check(ptkKeyword, 'resourcestring') then
      ParseConstSection(AParent)
    else if FStream.Check(ptkKeyword, 'type') then
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
  if (ANode = nil) or not FStream.Check(ptkKeyword, 'begin') then
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

    if FStream.Check(ptkKeyword, 'begin') then
      Inc(lDepth)
    else if FStream.Check(ptkKeyword, 'end') then
    begin
      Dec(lDepth);
      lEndPos := FStream.Current.EndPos;
      FStream.Next;
      if lDepth <= 0 then
      begin
        if FStream.Check(ptkSymbol, ';') then
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
begin
  if not FStream.ExpectIdentifierToken(lNameToken) then
  begin
    if not FStream.Check(ptkDirective) then
      AddExpectedDiagnostic('nxpas.type.malformed',
        'Expected type declaration name.');
    FStream.Next;
    Exit;
  end;

  lNode := AParent.AddChild(pnkTypeDecl, lNameToken.Text);
  lNode.Range := TokenRange(lNameToken);
  if not FStream.MatchSymbol('=') then
  begin
    SkipToDeclarationEnd;
    Exit;
  end;

  if FStream.Check(ptkKeyword, 'class') then
  begin
    lChildNode := lNode.AddChild(pnkClassDecl, lNameToken.Text);
    SetNodeRange(lChildNode, lNameToken.StartPos, FStream.Current.EndPos);
    FStream.Next;
    CaptureStructuredTypeHeritage(lChildNode);
    ParseStructuredTypeBody(lChildNode);
    lNode.Range := lChildNode.Range;
    Exit;
  end
  else if FStream.Check(ptkKeyword, 'object') then
  begin
    lChildNode := lNode.AddChild(pnkObjectDecl, lNameToken.Text);
    SetNodeRange(lChildNode, lNameToken.StartPos, FStream.Current.EndPos);
    FStream.Next;
    CaptureStructuredTypeHeritage(lChildNode);
    ParseStructuredTypeBody(lChildNode);
    lNode.Range := lChildNode.Range;
    Exit;
  end
  else if FStream.Check(ptkKeyword, 'record') then
  begin
    lChildNode := lNode.AddChild(pnkRecordDecl, lNameToken.Text);
    SetNodeRange(lChildNode, lNameToken.StartPos, FStream.Current.EndPos);
    FStream.Next;
    ParseStructuredTypeBody(lChildNode);
    lNode.Range := lChildNode.Range;
    Exit;
  end
  else if FStream.Check(ptkKeyword, 'interface') then
  begin
    lChildNode := lNode.AddChild(pnkInterfaceDecl, lNameToken.Text);
    SetNodeRange(lChildNode, lNameToken.StartPos, FStream.Current.EndPos);
    FStream.Next;
    CaptureStructuredTypeHeritage(lChildNode);
    ParseStructuredTypeBody(lChildNode);
    lNode.Range := lChildNode.Range;
    Exit;
  end;

  if CaptureDeclaredType(False, False, lDeclaredTypeText, lDeclaredTypeRange) then
    SetDeclaredType(lNode, lDeclaredTypeText, lDeclaredTypeRange);
  SkipToDeclarationEnd(False);
end;

procedure TNXPasParser.CaptureStructuredTypeHeritage(ANode: TNXPasASTNode);
var
  lEndPos: TNXPasSourcePosition;
  lRange: TNXPasSourceRange;
  lStartPos: TNXPasSourcePosition;
  lDepth: Integer;
begin
  if (ANode = nil) or not FStream.Check(ptkSymbol, '(') then
    Exit;

  FStream.Next;
  if FStream.Check(ptkEndOfFile) then
    Exit;

  lStartPos := FStream.Current.StartPos;
  lEndPos := FStream.Current.EndPos;
  lDepth := 1;
  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.Check(ptkSymbol, '(') then
      Inc(lDepth)
    else if FStream.Check(ptkSymbol, ')') then
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

    if FStream.Check(ptkKeyword, 'var') then
    begin
      FStream.Next;
      Continue;
    end;

    if FStream.Check(ptkKeyword, 'class') then
    begin
      FStream.Next;
      if FStream.Check(ptkKeyword, 'var') then
      begin
        FStream.Next;
        Continue;
      end;
      if IsRoutineKeyword then
      begin
        ParseRoutineDecl(ANode);
        Continue;
      end;
      if FStream.Check(ptkKeyword, 'property') then
      begin
        ParsePropertyDecl(ANode);
        Continue;
      end;
      Continue;
    end;

    if IsSectionStart or IsDeclarationSectionStart then
    begin
      AddExpectedDiagnostic('nxpas.structuredType.missingEnd',
        'Missing end for structured type body.');
      SetNodeRange(ANode, lStartPos, lEndPos);
      Exit;
    end;

    if FStream.Check(ptkKeyword, 'end') then
    begin
      lEndPos := FStream.Current.EndPos;
      FStream.Next;
      if FStream.Check(ptkSymbol, ';') then
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
    else if FStream.Check(ptkKeyword, 'property') then
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
  lNode := AParent.AddChild(pnkFieldDecl, lNameToken.Text);
  lNode.Range := TokenRange(lNameToken);
  lItems.Add(lNode);
  while FStream.MatchSymbol(',') do
    if ExpectFieldNameToken(lNameToken) then
    begin
      lNode := AParent.AddChild(pnkFieldDecl, lNameToken.Text);
      lNode.Range := TokenRange(lNameToken);
      lItems.Add(lNode);
    end;
  if FStream.MatchSymbol(':') and CaptureDeclaredType(False, False,
    lDeclaredTypeText, lDeclaredTypeRange) then
    for lIdx := 0 to lItems.Count - 1 do
      SetDeclaredType(TNXPasASTNode(lItems[lIdx]), lDeclaredTypeText,
        lDeclaredTypeRange);
  SkipToDeclarationEnd;
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
  FStream.Next;
  if FStream.ExpectIdentifierToken(lNameToken) then
  begin
    lNode := AParent.AddChild(pnkPropertyDecl, lNameToken.Text);
    SetNodeRange(lNode, lStartPos, lNameToken.EndPos);
    SkipPropertyParameters;
    if FStream.MatchSymbol(':') and CaptureDeclaredType(True, False,
      lDeclaredTypeText, lDeclaredTypeRange) then
      SetDeclaredType(lNode, lDeclaredTypeText, lDeclaredTypeRange);
  end;
  SkipToDeclarationEnd;
  while (FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
    (SameText(FStream.Current.Text, 'default') or
    SameText(FStream.Current.Text, 'nodefault')) do
    SkipToDeclarationEnd;
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
    AToken.Text := '';
    AToken.StartPos.Offset := 0;
    AToken.StartPos.Line := 0;
    AToken.StartPos.Column := 0;
    AToken.EndPos := AToken.StartPos;
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
    AToken.Text := '';
    AToken.StartPos.Offset := 0;
    AToken.StartPos.Line := 0;
    AToken.StartPos.Column := 0;
    AToken.EndPos := AToken.StartPos;
  end;
end;

procedure TNXPasParser.SkipPropertyParameters;
var
  lBracketDepth: Integer;
  lParenDepth: Integer;
begin
  lBracketDepth := 0;
  lParenDepth := 0;
  if not (FStream.Check(ptkSymbol, '[') or FStream.Check(ptkSymbol, '(')) then
    Exit;

  repeat
    if FStream.Check(ptkSymbol, '[') then
      Inc(lBracketDepth)
    else if FStream.Check(ptkSymbol, ']') and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if FStream.Check(ptkSymbol, '(') then
      Inc(lParenDepth)
    else if FStream.Check(ptkSymbol, ')') and (lParenDepth > 0) then
      Dec(lParenDepth);

    FStream.Next;
  until FStream.Check(ptkEndOfFile) or
    ((lBracketDepth = 0) and (lParenDepth = 0));
end;

procedure TNXPasParser.ParseVisibilitySection(AParent: TNXPasASTNode);
var
  lNode: TNXPasASTNode;
begin
  lNode := AParent.AddChild(pnkVisibilitySection, FStream.Current.Text);
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
  lPreviousText: string;
  lStartPos: TNXPasSourcePosition;
  lStructuredDepth: Integer;
begin
  Result := False;
  AText := '';
  lAngleDepth := 0;
  lBracketDepth := 0;
  lParenDepth := 0;
  lPreviousText := '';
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
      if FStream.Check(ptkSymbol, ';') or FStream.Check(ptkSymbol, '=') then
        Break;
      if AStopAtParameterDelimiter and
        (FStream.Check(ptkSymbol, ')') or FStream.Check(ptkSymbol, ',')) then
        Break;
      if AStopAtPropertyModifier and
        ((FStream.Current.Kind in [ptkIdentifier, ptkKeyword]) and
        (SameText(FStream.Current.Text, 'read') or
        SameText(FStream.Current.Text, 'write') or
        SameText(FStream.Current.Text, 'index') or
        SameText(FStream.Current.Text, 'stored') or
        SameText(FStream.Current.Text, 'default') or
        SameText(FStream.Current.Text, 'nodefault') or
        SameText(FStream.Current.Text, 'implements'))) then
        Break;
      if IsDeclarationTailKeyword then
        Break;
      if IsSectionStart or
        (IsDeclarationSectionStart and
        not (SameText(FStream.Current.Text, 'const') and
        SameText(lPreviousText, 'of'))) or
        FStream.Check(ptkKeyword, 'begin') or
        FStream.Check(ptkKeyword, 'end') then
        Break;
    end;

    lEndPos := FStream.Current.EndPos;
    if FStream.Check(ptkSymbol, '(') then
      Inc(lParenDepth)
    else if FStream.Check(ptkSymbol, ')') and (lParenDepth > 0) then
      Dec(lParenDepth)
    else if FStream.Check(ptkSymbol, '[') then
      Inc(lBracketDepth)
    else if FStream.Check(ptkSymbol, ']') and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if FStream.Check(ptkSymbol, '<') then
      Inc(lAngleDepth)
    else if FStream.Check(ptkSymbol, '>') and (lAngleDepth > 0) then
      Dec(lAngleDepth);
    if FStream.Check(ptkKeyword, 'record') or
      (FStream.Check(ptkKeyword, 'object') and
      (not SameText(lPreviousText, 'of'))) or
      FStream.Check(ptkKeyword, 'class') or
      FStream.Check(ptkKeyword, 'interface') then
      Inc(lStructuredDepth)
    else if FStream.Check(ptkKeyword, 'end') and (lStructuredDepth > 0) then
      Dec(lStructuredDepth);

    lPreviousText := FStream.Current.Text;
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
  lPreviousText: string;
  lStructuredDepth: Integer;
begin
  lAngleDepth := 0;
  lBracketDepth := 0;
  lParenDepth := 0;
  lPreviousText := '';
  lStructuredDepth := 0;
  FLastDeclarationEnd := FStream.Current.EndPos;

  while not FStream.Check(ptkEndOfFile) do
  begin
    if FStream.Check(ptkDirective) then
    begin
      ProcessDirective;
      Continue;
    end;

    if FStream.Check(ptkSymbol, ';') and (lParenDepth = 0) and
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
      IsVisibilityKeyword or FStream.Check(ptkKeyword, 'end')) then
    begin
      AddExpectedDiagnostic('nxpas.declaration.missingSemicolon',
        'Missing semicolon after declaration.');
      FLastDeclarationEnd := FStream.Current.StartPos;
      Exit;
    end;

    if FStream.Check(ptkSymbol, '(') then
      Inc(lParenDepth)
    else if FStream.Check(ptkSymbol, ')') and (lParenDepth > 0) then
      Dec(lParenDepth)
    else if FStream.Check(ptkSymbol, '[') then
      Inc(lBracketDepth)
    else if FStream.Check(ptkSymbol, ']') and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if FStream.Check(ptkSymbol, '<') then
      Inc(lAngleDepth)
    else if FStream.Check(ptkSymbol, '>') and (lAngleDepth > 0) then
      Dec(lAngleDepth);
    if FStream.Check(ptkKeyword, 'record') or
      (FStream.Check(ptkKeyword, 'object') and
      (not SameText(lPreviousText, 'of'))) or
      FStream.Check(ptkKeyword, 'class') or
      FStream.Check(ptkKeyword, 'interface') then
      Inc(lStructuredDepth)
    else if FStream.Check(ptkKeyword, 'end') and (lStructuredDepth > 0) then
      Dec(lStructuredDepth);

    lPreviousText := FStream.Current.Text;
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
    if FStream.Check(ptkSymbol, ';') then
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
      Continue;
    end;

    if not IsRoutineDirective then
      Exit;

    while not (FStream.Check(ptkEndOfFile) or FStream.Check(ptkSymbol, ';') or
      IsSectionStart or IsDeclarationSectionStart or IsRoutineKeyword or
      IsVisibilityKeyword or FStream.Check(ptkKeyword, 'end') or
      FStream.Check(ptkKeyword, 'property')) do
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
    end;

    if FStream.Check(ptkSymbol, ';') then
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
    if FStream.Check(ptkSymbol, ';') then
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
      Continue;
    end;

    if not IsDeclarationTailKeyword then
      Exit;

    while not (FStream.Check(ptkEndOfFile) or FStream.Check(ptkSymbol, ';') or
      IsSectionStart or IsDeclarationSectionStart or IsRoutineKeyword or
      FStream.Check(ptkKeyword, 'end')) do
    begin
      FLastDeclarationEnd := FStream.Current.EndPos;
      FStream.Next;
    end;

    if FStream.Check(ptkSymbol, ';') then
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
      if not FHeaderParsed and (FStream.Check(ptkKeyword, 'unit') or
        FStream.Check(ptkKeyword, 'program') or
        FStream.Check(ptkKeyword, 'library') or
        FStream.Check(ptkKeyword, 'package')) then
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
