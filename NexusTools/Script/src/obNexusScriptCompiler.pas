unit obNexusScriptCompiler;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  tpNexusScript,
  obNexusScriptModel;

type
  TNexusScriptCompiler = class
  private
    FDiagnostics: TNexusScriptDiagnosticList;
    FSourceDocument: TNexusScriptSourceDocument;
    FCompiledDocument: TNexusScriptCompiledDocument;
    FImportedDefinitions: TNexusScriptCompiledDefinitionList;
    procedure AddError(const ACode, AMessageText: string;
      const ASourceRange: TNexusScriptRange);
    procedure CompileSource;
  public
    constructor Create;
    destructor Destroy; override;
    function CompileText(const ASourceName, AText: string): Boolean;
    function CompileFile(const AFileName: string): Boolean;
    procedure ClearImports;
    procedure AddImportedDefinition(
      ADefinition: TNexusScriptCompiledDefinition);
    procedure AddImportedDocument(ADocument: TNexusScriptCompiledDocument);
    property Diagnostics: TNexusScriptDiagnosticList read FDiagnostics;
    property SourceDocument: TNexusScriptSourceDocument read FSourceDocument;
    property CompiledDocument: TNexusScriptCompiledDocument read FCompiledDocument;
  end;

implementation

type
  TNexusScriptTokenKind = (
    nstWord, nstQuoted, nstLeftBrace, nstRightBrace, nstColon, nstSemicolon,
    nstLeftParenthesis, nstRightParenthesis, nstComma, nstLeftBracket,
    nstRightBracket, nstAt, nstDot, nstPlus, nstEndOfFile
  );

  TNexusScriptToken = record
    Kind: TNexusScriptTokenKind;
    Text: string;
    SourceRange: TNexusScriptRange;
  end;

  TNexusScriptTokenList = TList<TNexusScriptToken>;
  TNexusScriptTokenKindSet = set of TNexusScriptTokenKind;

  TNexusScriptParser = class
  private
    FCompiler: TNexusScriptCompiler;
    FSourceName: string;
    FTokens: TNexusScriptTokenList;
    FIndex: Integer;
    procedure Tokenize(const AText: string);
    function Current: TNexusScriptToken;
    function Match(AKind: TNexusScriptTokenKind): Boolean;
    function Require(AKind: TNexusScriptTokenKind;
      const ADescription: string): TNexusScriptToken;
    function ParsePath: string;
    function ParseValue(const AStopKinds: TNexusScriptTokenKindSet): TNexusScriptSourceValue;
    function ParseDefinition(AParent: TNexusScriptSourceDefinition): TNexusScriptSourceDefinition;
    procedure ParseModule(ADocument: TNexusScriptSourceDocument);
    procedure ParseDoctype(ADocument: TNexusScriptSourceDocument);
    procedure ParseInclude(ADocument: TNexusScriptSourceDocument);
    procedure ParseData(ADocument: TNexusScriptSourceDocument);
  public
    constructor Create(ACompiler: TNexusScriptCompiler;
      const ASourceName, AText: string);
    destructor Destroy; override;
    function Parse: TNexusScriptSourceDocument;
  end;

function NewPosition(AOffset, ALine, AColumn: Integer): TNexusScriptPosition;
begin
  Result.Offset := AOffset;
  Result.Line := ALine;
  Result.Column := AColumn;
end;

constructor TNexusScriptParser.Create(ACompiler: TNexusScriptCompiler;
  const ASourceName, AText: string);
begin
  inherited Create;
  FCompiler := ACompiler;
  FSourceName := ASourceName;
  FTokens := TNexusScriptTokenList.Create;
  Tokenize(AText);
end;

destructor TNexusScriptParser.Destroy;
begin
  FTokens.Free;
  inherited Destroy;
end;

procedure TNexusScriptParser.Tokenize(const AText: string);
var
  lIndex: Integer;
  lLine: Integer;
  lColumn: Integer;
  lStart: Integer;
  lStartLine: Integer;
  lStartColumn: Integer;
  lText: string;
  lToken: TNexusScriptToken;
  lCharacter: Char;

  procedure Advance;
  begin
    if lIndex <= Length(AText) then
    begin
      if AText[lIndex] = #10 then
      begin
        Inc(lLine);
        lColumn := 1;
      end
      else
        Inc(lColumn);
      Inc(lIndex);
    end;
  end;

  procedure Emit(AKind: TNexusScriptTokenKind; const AValue: string);
  begin
    lToken.Kind := AKind;
    lToken.Text := AValue;
    lToken.SourceRange.SourceName := FSourceName;
    lToken.SourceRange.StartPosition := NewPosition(lStart - 1,
      lStartLine, lStartColumn);
    lToken.SourceRange.EndPosition := NewPosition(lIndex - 1,
      lLine, lColumn);
    FTokens.Add(lToken);
  end;

begin
  lIndex := 1;
  lLine := 1;
  lColumn := 1;
  while lIndex <= Length(AText) do
  begin
    if AText[lIndex] <= ' ' then
    begin
      Advance;
      Continue;
    end;
    if (AText[lIndex] = '/') and (lIndex < Length(AText)) and
      (AText[lIndex + 1] = '/') then
    begin
      while (lIndex <= Length(AText)) and
        not (AText[lIndex] in [#10, #13]) do
        Advance;
      Continue;
    end;
    if (AText[lIndex] = '/') and (lIndex < Length(AText)) and
      (AText[lIndex + 1] = '*') then
    begin
      lStart := lIndex;
      lStartLine := lLine;
      lStartColumn := lColumn;
      Advance;
      Advance;
      while (lIndex <= Length(AText)) and not ((AText[lIndex] = '*') and
        (lIndex < Length(AText)) and (AText[lIndex + 1] = '/')) do
        Advance;
      if lIndex > Length(AText) then
      begin
        lToken.SourceRange.SourceName := FSourceName;
        lToken.SourceRange.StartPosition := NewPosition(lStart - 1,
          lStartLine, lStartColumn);
        lToken.SourceRange.EndPosition := NewPosition(lIndex - 1,
          lLine, lColumn);
        FCompiler.AddError('NXS1002', 'Unterminated block comment',
          lToken.SourceRange);
        Break;
      end;
      Advance;
      Advance;
      Continue;
    end;

    lStart := lIndex;
    lStartLine := lLine;
    lStartColumn := lColumn;
    case AText[lIndex] of
      '{': begin Advance; Emit(nstLeftBrace, '{'); end;
      '}': begin Advance; Emit(nstRightBrace, '}'); end;
      ':': begin Advance; Emit(nstColon, ':'); end;
      ';': begin Advance; Emit(nstSemicolon, ';'); end;
      '(': begin Advance; Emit(nstLeftParenthesis, '('); end;
      ')': begin Advance; Emit(nstRightParenthesis, ')'); end;
      ',': begin Advance; Emit(nstComma, ','); end;
      '[': begin Advance; Emit(nstLeftBracket, '['); end;
      ']': begin Advance; Emit(nstRightBracket, ']'); end;
      '@': begin Advance; Emit(nstAt, '@'); end;
      '.': begin Advance; Emit(nstDot, '.'); end;
      '+': begin Advance; Emit(nstPlus, '+'); end;
      '"':
        begin
          Advance;
          lText := '';
          while (lIndex <= Length(AText)) and (AText[lIndex] <> '"') do
          begin
            if AText[lIndex] = '^' then
            begin
              Advance;
              if lIndex > Length(AText) then
                Break;
              lCharacter := AText[lIndex];
              case lCharacter of
                '^': lText := lText + '^';
                '"': lText := lText + '"';
                'n': lText := lText + #10;
                'r': lText := lText + #13;
                't': lText := lText + #9;
              else
                begin
                  lToken.SourceRange.SourceName := FSourceName;
                  lToken.SourceRange.StartPosition := NewPosition(lIndex - 1,
                    lLine, lColumn);
                  lToken.SourceRange.EndPosition := lToken.SourceRange.StartPosition;
                  FCompiler.AddError('NXS1003', 'Invalid string escape',
                    lToken.SourceRange);
                  lText := lText + lCharacter;
                end;
              end;
              Advance;
            end
            else
            begin
              lText := lText + AText[lIndex];
              Advance;
            end;
          end;
          if lIndex > Length(AText) then
            FCompiler.AddError('NXS1001', 'Unterminated quoted text',
              lToken.SourceRange)
          else
            Advance;
          Emit(nstQuoted, lText);
        end;
    else
      lText := '';
      while (lIndex <= Length(AText)) and not (AText[lIndex] <= ' ') and
        not (AText[lIndex] in ['{', '}', ':', ';', '(', ')', ',', '[', ']',
          '@', '.', '+', '"']) do
      begin
        lText := lText + AText[lIndex];
        Advance;
      end;
      Emit(nstWord, lText);
    end;
  end;
  lStart := lIndex;
  lStartLine := lLine;
  lStartColumn := lColumn;
  Emit(nstEndOfFile, '');
end;

function TNexusScriptParser.Current: TNexusScriptToken;
begin
  Result := FTokens[FIndex];
end;

function TNexusScriptParser.Match(AKind: TNexusScriptTokenKind): Boolean;
begin
  Result := Current.Kind = AKind;
  if Result then
    Inc(FIndex);
end;

function TNexusScriptParser.Require(AKind: TNexusScriptTokenKind;
  const ADescription: string): TNexusScriptToken;
begin
  Result := Current;
  if Result.Kind = AKind then
    Inc(FIndex)
  else
  begin
    FCompiler.AddError('NXS2001', 'Expected ' + ADescription,
      Result.SourceRange);
    if Result.Kind <> nstEndOfFile then
      Inc(FIndex);
  end;
end;

function TNexusScriptParser.ParsePath: string;
begin
  Result := Require(nstWord, 'name').Text;
  while Match(nstDot) do
    Result := Result + '.' + Require(nstWord, 'name').Text;
end;

function TNexusScriptParser.ParseValue(
  const AStopKinds: TNexusScriptTokenKindSet): TNexusScriptSourceValue;
var
  lPart: TNexusScriptSourceValue;
  lText: string;
  lEntry: TNexusScriptSourceValue;
  lEntryName: string;

  function StartsInlineDefinition: Boolean;
  begin
    Result := (Current.Kind = nstWord) and
      (FIndex + 2 < FTokens.Count) and
      (FTokens[FIndex + 1].Kind = nstWord) and
      (FTokens[FIndex + 2].Kind in [nstLeftBrace, nstLeftParenthesis]);
  end;

  function ParsePart: TNexusScriptSourceValue;
  var
    lRange: TNexusScriptRange;
  begin
    lRange := Current.SourceRange;
    if Match(nstAt) then
    begin
      Result := TNexusScriptSourceValue.Create(nsvReference, lRange);
      Result.Text := ParsePath;
    end
    else if Current.Kind = nstQuoted then
    begin
      Result := TNexusScriptSourceValue.Create(nsvText, lRange);
      Result.Text := Current.Text;
      Inc(FIndex);
    end
    else
    begin
      Result := TNexusScriptSourceValue.Create(nsvText, lRange);
      lText := '';
      while not (Current.Kind in AStopKinds + [nstPlus, nstComma,
        nstRightBracket, nstEndOfFile]) do
      begin
        if lText <> '' then
          lText := lText + ' ';
        lText := lText + Current.Text;
        Inc(FIndex);
      end;
      Result.Text := Trim(lText);
    end;
  end;

begin
  if Match(nstLeftBracket) then
  begin
    Result := TNexusScriptSourceValue.Create(nsvArray,
      FTokens[FIndex - 1].SourceRange);
    while not Match(nstRightBracket) and
      (Current.Kind <> nstEndOfFile) do
    begin
      lEntryName := '';
      if (Current.Kind = nstWord) and (FIndex + 1 < FTokens.Count) and
        (FTokens[FIndex + 1].Kind = nstColon) then
      begin
        lEntryName := Current.Text;
        Inc(FIndex, 2);
      end;
      if StartsInlineDefinition then
      begin
        lEntry := TNexusScriptSourceValue.Create(nsvDefinition,
          Current.SourceRange);
        lEntry.InlineDefinition := ParseDefinition(nil);
      end
      else
        lEntry := ParseValue([nstComma, nstRightBracket]);
      lEntry.EntryName := lEntryName;
      Result.Items.Add(lEntry);
      if not Match(nstComma) then
      begin
        Require(nstRightBracket, ']');
        Break;
      end;
    end;
    Exit;
  end;

  lPart := ParsePart;
  if Current.Kind <> nstPlus then
    Exit(lPart);
  Result := TNexusScriptSourceValue.Create(nsvTextComposition,
    lPart.SourceRange);
  Result.Items.Add(lPart);
  while Match(nstPlus) do
    Result.Items.Add(ParsePart);
end;

function TNexusScriptParser.ParseDefinition(
  AParent: TNexusScriptSourceDefinition): TNexusScriptSourceDefinition;
var
  lKindToken: TNexusScriptToken;
  lNameToken: TNexusScriptToken;
  lMemberToken: TNexusScriptToken;
  lValue: TNexusScriptSourceValue;
  lChild: TNexusScriptSourceDefinition;
begin
  lKindToken := Require(nstWord, 'definition kind');
  lNameToken := Require(nstWord, 'definition name');
  Result := TNexusScriptSourceDefinition.Create(lKindToken.Text,
    lNameToken.Text, lKindToken.SourceRange);
  Result.Parent := AParent;
  if Match(nstLeftParenthesis) then
  begin
    while not Match(nstRightParenthesis) and
      (Current.Kind <> nstEndOfFile) do
    begin
      Result.CompositionSelectors.Add(ParsePath);
      if not Match(nstComma) then
      begin
        Require(nstRightParenthesis, ')');
        Break;
      end;
    end;
  end;
  Require(nstLeftBrace, '{');
  while (Current.Kind <> nstRightBrace) and
    (Current.Kind <> nstEndOfFile) do
  begin
    lMemberToken := Require(nstWord, 'member name');
    if Match(nstColon) then
    begin
      lValue := ParseValue([nstSemicolon]);
      Require(nstSemicolon, ';');
      if (Result.FindProperty(lMemberToken.Text) <> nil) or
        (Result.FindChild(lMemberToken.Text) <> nil) then
      begin
        FCompiler.AddError('NXS3001', 'Duplicate member ' +
          lMemberToken.Text, lMemberToken.SourceRange);
        lValue.Free;
      end
      else
        Result.Properties.Add(TNexusScriptSourceProperty.Create(
          lMemberToken.Text, lValue, lMemberToken.SourceRange));
    end
    else
    begin
      Dec(FIndex);
      lChild := ParseDefinition(Result);
      if (Result.FindProperty(lChild.Name) <> nil) or
        (Result.FindChild(lChild.Name) <> nil) then
      begin
        FCompiler.AddError('NXS3001', 'Duplicate member ' + lChild.Name,
          lChild.SourceRange);
        lChild.Free;
      end
      else
        Result.Children.Add(lChild);
    end;
  end;
  Require(nstRightBrace, '}');
end;

procedure TNexusScriptParser.ParseModule(ADocument: TNexusScriptSourceDocument);
var
  lModule: TNexusScriptSourceModule;
  lPieces: TStringList;
  lRange: TNexusScriptRange;
begin
  lRange := Current.SourceRange;
  Inc(FIndex);
  lModule := TNexusScriptSourceModule.Create;
  lPieces := TStringList.Create;
  try
    lModule.SourceRange := lRange;
    while not (Current.Kind in [nstSemicolon, nstEndOfFile]) do
    begin
      if Current.Kind = nstDot then
      begin
        if lPieces.Count > 0 then
          lPieces[lPieces.Count - 1] := lPieces[lPieces.Count - 1] + '.';
      end
      else if (lPieces.Count > 0) and
        (lPieces[lPieces.Count - 1][Length(lPieces[lPieces.Count - 1])] = '.') then
        lPieces[lPieces.Count - 1] := lPieces[lPieces.Count - 1] + Current.Text
      else
        lPieces.Add(Current.Text);
      Inc(FIndex);
    end;
    Require(nstSemicolon, ';');
    if lPieces.Count = 1 then
      lModule.Path := lPieces[0]
    else if lPieces.Count = 2 then
    begin
      lModule.RootSelector := lPieces[0];
      lModule.Path := lPieces[1];
    end
    else
      FCompiler.AddError('NXS2002', 'Invalid module declaration', lRange);
    ADocument.Modules.Add(lModule);
    lModule := nil;
  finally
    lPieces.Free;
    lModule.Free;
  end;
end;

procedure TNexusScriptParser.ParseDoctype(
  ADocument: TNexusScriptSourceDocument);
var
  lDoctype: TNexusScriptSourceDoctype;
  lPieces: TStringList;
  lRange: TNexusScriptRange;
begin
  lRange := Current.SourceRange;
  Inc(FIndex);
  lDoctype := TNexusScriptSourceDoctype.Create;
  lPieces := TStringList.Create;
  try
    lDoctype.SourceRange := lRange;
    while not (Current.Kind in [nstSemicolon, nstEndOfFile]) do
    begin
      if Current.Kind = nstDot then
      begin
        if lPieces.Count > 0 then
          lPieces[lPieces.Count - 1] := lPieces[lPieces.Count - 1] + '.';
      end
      else if (lPieces.Count > 0) and
        (lPieces[lPieces.Count - 1][Length(lPieces[lPieces.Count - 1])] = '.') then
        lPieces[lPieces.Count - 1] := lPieces[lPieces.Count - 1] + Current.Text
      else
        lPieces.Add(Current.Text);
      Inc(FIndex);
    end;
    Require(nstSemicolon, ';');
    if lPieces.Count <> 1 then
      FCompiler.AddError('NXS2011', 'Invalid doctype declaration', lRange)
    else if ADocument.Doctype <> nil then
      FCompiler.AddError('NXS2012', 'Duplicate doctype declaration', lRange)
    else
    begin
      lDoctype.Path := lPieces[0];
      ADocument.Doctype := lDoctype;
      lDoctype := nil;
    end;
  finally
    lPieces.Free;
    lDoctype.Free;
  end;
end;

procedure TNexusScriptParser.ParseInclude(
  ADocument: TNexusScriptSourceDocument);
var
  lInclude: TNexusScriptSourceInclude;
  lPieces: TStringList;
  lRange: TNexusScriptRange;
begin
  lRange := Current.SourceRange;
  Inc(FIndex);
  lInclude := TNexusScriptSourceInclude.Create;
  lPieces := TStringList.Create;
  try
    lInclude.SourceRange := lRange;
    while not (Current.Kind in [nstSemicolon, nstEndOfFile]) do
    begin
      if Current.Kind = nstDot then
      begin
        if lPieces.Count > 0 then
          lPieces[lPieces.Count - 1] := lPieces[lPieces.Count - 1] + '.';
      end
      else if (lPieces.Count > 0) and
        (lPieces[lPieces.Count - 1][Length(lPieces[lPieces.Count - 1])] = '.') then
        lPieces[lPieces.Count - 1] := lPieces[lPieces.Count - 1] + Current.Text
      else
        lPieces.Add(Current.Text);
      Inc(FIndex);
    end;
    Require(nstSemicolon, ';');
    if lPieces.Count <> 1 then
      FCompiler.AddError('NXS2015', 'Invalid include declaration', lRange)
    else
    begin
      lInclude.Path := lPieces[0];
      ADocument.Includes.Add(lInclude);
      lInclude := nil;
    end;
  finally
    lPieces.Free;
    lInclude.Free;
  end;
end;

procedure TNexusScriptParser.ParseData(
  ADocument: TNexusScriptSourceDocument);
var
  lDataSource: TNexusScriptSourceData;
  lName: TNexusScriptToken;
  lPath: TNexusScriptToken;
  lRange: TNexusScriptRange;
begin
  lRange := Current.SourceRange;
  Inc(FIndex);
  lName := Require(nstWord, 'data source name');
  lPath := Require(nstQuoted, 'quoted data source path');
  Require(nstSemicolon, ';');
  if (lName.Kind <> nstWord) or (lPath.Kind <> nstQuoted) then
    Exit;
  if ADocument.FindDataSource(lName.Text) <> nil then
  begin
    FCompiler.AddError('NXS2018', 'Duplicate data source ' + lName.Text,
      lRange);
    Exit;
  end;
  lDataSource := TNexusScriptSourceData.Create;
  lDataSource.Name := lName.Text;
  lDataSource.Path := lPath.Text;
  lDataSource.SourceRange := lRange;
  ADocument.DataSources.Add(lDataSource);
end;

function TNexusScriptParser.Parse: TNexusScriptSourceDocument;
var
  lDefinition: TNexusScriptSourceDefinition;
  lHasDefinition: Boolean;
begin
  Result := TNexusScriptSourceDocument.Create(FSourceName);
  lHasDefinition := False;
  while Current.Kind <> nstEndOfFile do
  begin
    if (Current.Kind = nstWord) and SameText(Current.Text, 'module') then
    begin
      if lHasDefinition then
        FCompiler.AddError('NXS2013',
          'Module declaration must precede definitions', Current.SourceRange);
      ParseModule(Result);
      Continue;
    end;
    if (Current.Kind = nstWord) and SameText(Current.Text, 'doctype') then
    begin
      if lHasDefinition then
        FCompiler.AddError('NXS2014',
          'Doctype declaration must precede definitions', Current.SourceRange);
      ParseDoctype(Result);
      Continue;
    end;
    if (Current.Kind = nstWord) and SameText(Current.Text, 'include') then
    begin
      if lHasDefinition then
        FCompiler.AddError('NXS2016',
          'Include declaration must precede definitions', Current.SourceRange);
      ParseInclude(Result);
      Continue;
    end;
    if (Current.Kind = nstWord) and SameText(Current.Text, 'data') then
    begin
      if lHasDefinition then
        FCompiler.AddError('NXS2017',
          'Data declaration must precede definitions', Current.SourceRange);
      ParseData(Result);
      Continue;
    end;
    lHasDefinition := True;
    lDefinition := ParseDefinition(nil);
    if Result.FindDefinition(lDefinition.Name) <> nil then
    begin
      FCompiler.AddError('NXS3002', 'Duplicate root definition ' +
        lDefinition.Name, lDefinition.SourceRange);
      lDefinition.Free;
    end
    else
      Result.Definitions.Add(lDefinition);
  end;
end;

constructor TNexusScriptCompiler.Create;
begin
  inherited Create;
  FDiagnostics := TNexusScriptDiagnosticList.Create(True);
  FImportedDefinitions := TNexusScriptCompiledDefinitionList.Create(True);
end;

destructor TNexusScriptCompiler.Destroy;
begin
  FCompiledDocument.Free;
  FSourceDocument.Free;
  FImportedDefinitions.Free;
  FDiagnostics.Free;
  inherited Destroy;
end;

procedure TNexusScriptCompiler.AddError(const ACode, AMessageText: string;
  const ASourceRange: TNexusScriptRange);
begin
  FDiagnostics.Add(TNexusScriptDiagnostic.Create(ACode, AMessageText,
    ASourceRange));
end;

function CopyDefinition(ASource: TNexusScriptSourceDefinition;
  AParent: TNexusScriptCompiledDefinition): TNexusScriptCompiledDefinition; forward;

function CopyValue(AValue: TNexusScriptSourceValue): TNexusScriptCompiledValue;
var
  lItem: TNexusScriptSourceValue;
begin
  Result := TNexusScriptCompiledValue.Create(AValue.Kind, AValue.SourceRange);
  Result.SourceText := AValue.Text;
  Result.EntryName := AValue.EntryName;
  Result.InlineSourceDefinition := AValue.InlineDefinition;
  if AValue.InlineDefinition <> nil then
  begin
    Result.OriginalDefinitionName := AValue.InlineDefinition.Name;
    Result.StructuralDefinition := CopyDefinition(AValue.InlineDefinition, nil);
  end;
  for lItem in AValue.Items do
    Result.Items.Add(CopyValue(lItem));
end;

function CopyDefinition(ASource: TNexusScriptSourceDefinition;
  AParent: TNexusScriptCompiledDefinition): TNexusScriptCompiledDefinition;
var
  lProperty: TNexusScriptSourceProperty;
  lChild: TNexusScriptSourceDefinition;
begin
  Result := TNexusScriptCompiledDefinition.Create(ASource.Kind, ASource.Name,
    ASource.SourceRange);
  Result.Parent := AParent;
  for lProperty in ASource.Properties do
    Result.Properties.Add(TNexusScriptCompiledProperty.Create(lProperty.Name,
      CopyValue(lProperty.Value), lProperty.SourceRange));
  for lChild in ASource.Children do
    Result.Children.Add(CopyDefinition(lChild, Result));
end;

function CloneDefinition(ASource: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition): TNexusScriptCompiledDefinition; forward;

function CloneDefinitionForRebinding(ASource: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition): TNexusScriptCompiledDefinition; forward;

function CloneDefinitionAs(ASource: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition;
  const AName: string): TNexusScriptCompiledDefinition; forward;

function CloneValue(AValue: TNexusScriptCompiledValue): TNexusScriptCompiledValue;
var
  lItem: TNexusScriptCompiledValue;
  lContributor: TNexusScriptCompiledValue;
begin
  Result := TNexusScriptCompiledValue.Create(AValue.Kind, AValue.SourceRange);
  Result.SourceText := AValue.SourceText;
  Result.EntryName := AValue.EntryName;
  Result.EffectiveName := AValue.EffectiveName;
  Result.OriginalDefinitionName := AValue.OriginalDefinitionName;
  Result.InlineSourceDefinition := AValue.InlineSourceDefinition;
  Result.EffectiveText := AValue.EffectiveText;
  Result.HasEffectiveText := AValue.HasEffectiveText;
  Result.ResolvedDefinition := AValue.ResolvedDefinition;
  Result.ResolvedProperty := AValue.ResolvedProperty;
  Result.ResolvedValue := AValue.ResolvedValue;
  if AValue.EvaluationState = nsvesCompleted then
    Result.EvaluationState := nsvesCompleted
  else if AValue.EvaluationState = nsvesFailed then
    Result.EvaluationState := nsvesFailed;
  if AValue.ArrayPreparationState = nsapsPrepared then
    Result.ArrayPreparationState := nsapsPrepared
  else if AValue.ArrayPreparationState = nsapsFailed then
    Result.ArrayPreparationState := nsapsFailed;
  if AValue.EffectiveValue <> nil then
    Result.EffectiveValue := CloneValue(AValue.EffectiveValue);
  if AValue.StructuralDefinition <> nil then
    Result.StructuralDefinition := CloneDefinition(
      AValue.StructuralDefinition, nil);
  for lItem in AValue.Items do
    Result.Items.Add(CloneValue(lItem));
  for lContributor in AValue.CompositionContributors do
    Result.CompositionContributors.Add(CloneValue(lContributor));
end;

function CloneValueForRebinding(
  AValue: TNexusScriptCompiledValue): TNexusScriptCompiledValue;
var
  lItem: TNexusScriptCompiledValue;
  lContributor: TNexusScriptCompiledValue;
begin
  Result := TNexusScriptCompiledValue.Create(AValue.Kind, AValue.SourceRange);
  Result.SourceText := AValue.SourceText;
  Result.EntryName := AValue.EntryName;
  Result.OriginalDefinitionName := AValue.OriginalDefinitionName;
  Result.InlineSourceDefinition := AValue.InlineSourceDefinition;
  if Result.EntryName <> '' then
    Result.EffectiveName := Result.EntryName
  else if Result.Kind = nsvDefinition then
    Result.EffectiveName := Result.OriginalDefinitionName;
  if (Result.Kind = nsvDefinition) and
    (AValue.StructuralDefinition <> nil) then
    Result.StructuralDefinition := CloneDefinitionForRebinding(
      AValue.StructuralDefinition, nil);
  for lItem in AValue.Items do
    Result.Items.Add(CloneValueForRebinding(lItem));
  for lContributor in AValue.CompositionContributors do
    Result.CompositionContributors.Add(
      CloneValueForRebinding(lContributor));
end;

function CloneDefinition(ASource: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition): TNexusScriptCompiledDefinition;
var
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  Result := TNexusScriptCompiledDefinition.Create(ASource.Kind, ASource.Name,
    ASource.SourceRange);
  Result.ImportedRoot := ASource.ImportedRoot;
  Result.Parent := AParent;
  for lProperty in ASource.Properties do
    Result.Properties.Add(TNexusScriptCompiledProperty.Create(lProperty.Name,
      CloneValue(lProperty.Value), lProperty.SourceRange));
  for lChild in ASource.Children do
    Result.Children.Add(CloneDefinition(lChild, Result));
end;

function CloneDefinitionForRebinding(ASource: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition): TNexusScriptCompiledDefinition;
var
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  Result := TNexusScriptCompiledDefinition.Create(ASource.Kind, ASource.Name,
    ASource.SourceRange);
  Result.ImportedRoot := ASource.ImportedRoot;
  Result.Parent := AParent;
  for lProperty in ASource.Properties do
    Result.Properties.Add(TNexusScriptCompiledProperty.Create(lProperty.Name,
      CloneValueForRebinding(lProperty.Value), lProperty.SourceRange));
  for lChild in ASource.Children do
    Result.Children.Add(CloneDefinitionForRebinding(lChild, Result));
end;

function CloneDefinitionAs(ASource: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition;
  const AName: string): TNexusScriptCompiledDefinition;
var
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  Result := TNexusScriptCompiledDefinition.Create(ASource.Kind, AName,
    ASource.SourceRange);
  Result.ImportedRoot := ASource.ImportedRoot;
  Result.Parent := AParent;
  for lProperty in ASource.Properties do
    Result.Properties.Add(TNexusScriptCompiledProperty.Create(lProperty.Name,
      CloneValue(lProperty.Value), lProperty.SourceRange));
  for lChild in ASource.Children do
    Result.Children.Add(CloneDefinition(lChild, Result));
end;

function IsScalarProjectionValue(AValue: TNexusScriptCompiledValue): Boolean;
var
  lItem: TNexusScriptCompiledValue;
  lContributor: TNexusScriptCompiledValue;
begin
  if AValue.Kind = nsvArray then
  begin
    if AValue.ArrayPreparationState <> nsapsPrepared then
      for lContributor in AValue.CompositionContributors do
        if not IsScalarProjectionValue(lContributor) then
          Exit(False);
    for lItem in AValue.Items do
      if not IsScalarProjectionValue(lItem) then
        Exit(False);
    Exit(True);
  end;
  Result := (AValue.Kind <> nsvDefinition) and
    (AValue.StructuralDefinition = nil) and
    (AValue.ResolvedDefinition = nil);
end;

function CloneReferenceProjection(ASource: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition;
  const AName: string): TNexusScriptCompiledDefinition; forward;

function CloneProjectionValue(AValue: TNexusScriptCompiledValue;
  AParent: TNexusScriptCompiledDefinition): TNexusScriptCompiledValue;
var
  lItem: TNexusScriptCompiledValue;
  lContributor: TNexusScriptCompiledValue;
begin
  Result := TNexusScriptCompiledValue.Create(AValue.Kind, AValue.SourceRange);
  Result.SourceText := AValue.SourceText;
  Result.EntryName := AValue.EntryName;
  Result.EffectiveName := AValue.EffectiveName;
  Result.OriginalDefinitionName := AValue.OriginalDefinitionName;
  Result.InlineSourceDefinition := AValue.InlineSourceDefinition;
  Result.EffectiveText := AValue.EffectiveText;
  Result.HasEffectiveText := AValue.HasEffectiveText;
  Result.ResolvedDefinition := AValue.ResolvedDefinition;
  Result.ResolvedProperty := AValue.ResolvedProperty;
  Result.ResolvedValue := AValue.ResolvedValue;
  if AValue.EvaluationState = nsvesCompleted then
    Result.EvaluationState := nsvesCompleted
  else if AValue.EvaluationState = nsvesFailed then
    Result.EvaluationState := nsvesFailed;
  if AValue.ArrayPreparationState = nsapsPrepared then
    Result.ArrayPreparationState := nsapsPrepared
  else if AValue.ArrayPreparationState = nsapsFailed then
    Result.ArrayPreparationState := nsapsFailed;
  if AValue.EffectiveValue <> nil then
    Result.EffectiveValue := CloneValue(AValue.EffectiveValue);
  if AValue.StructuralDefinition <> nil then
    Result.StructuralDefinition := CloneReferenceProjection(
      AValue.StructuralDefinition, AParent,
      AValue.StructuralDefinition.Name);
  for lItem in AValue.Items do
    Result.Items.Add(CloneProjectionValue(lItem, AParent));
  for lContributor in AValue.CompositionContributors do
    Result.CompositionContributors.Add(CloneValue(lContributor));
end;

function CloneReferenceProjection(ASource: TNexusScriptCompiledDefinition;
  AParent: TNexusScriptCompiledDefinition;
  const AName: string): TNexusScriptCompiledDefinition;
var
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  Result := TNexusScriptCompiledDefinition.Create(ASource.Kind, AName,
    ASource.SourceRange);
  Result.ImportedRoot := ASource.ImportedRoot;
  Result.Parent := AParent;
  for lProperty in ASource.Properties do
  begin
    if lProperty.Resolving then
      Continue;
    if (lProperty.Value.Kind = nsvArray) and
      not IsScalarProjectionValue(lProperty.Value) then
      Continue;
    Result.Properties.Add(TNexusScriptCompiledProperty.Create(lProperty.Name,
      CloneProjectionValue(lProperty.Value, Result), lProperty.SourceRange));
  end;
  for lChild in ASource.Children do
    Result.Children.Add(CloneReferenceProjection(lChild, Result, lChild.Name));
end;

procedure TNexusScriptCompiler.CompileSource;
var
  lSourceDefinition: TNexusScriptSourceDefinition;
  lMaterializingDefinitions: TList<TNexusScriptCompiledDefinition>;

  function SourceFor(ACompiled: TNexusScriptCompiledDefinition): TNexusScriptSourceDefinition;
  var
    lSource: TNexusScriptSourceDefinition;
    lParentSource: TNexusScriptSourceDefinition;
  begin
    if ACompiled.Parent = nil then
      Exit(FSourceDocument.FindDefinition(ACompiled.Name));
    lParentSource := SourceFor(ACompiled.Parent);
    Result := nil;
    for lSource in lParentSource.Children do
      if SameText(lSource.Name, ACompiled.Name) then
        Exit(lSource);
  end;

  function EvaluateProperty(AScope: TNexusScriptCompiledDefinition;
    AProperty: TNexusScriptCompiledProperty): Boolean; forward;

  function EvaluateValue(AScope: TNexusScriptCompiledDefinition;
    AValue: TNexusScriptCompiledValue;
    const AReceiverName: string): Boolean; forward;

  function PrepareArrayValue(AScope: TNexusScriptCompiledDefinition;
    AValue: TNexusScriptCompiledValue;
    out AArrayValue: TNexusScriptCompiledValue): Boolean; forward;

  function BindDefinition(
    ADefinition: TNexusScriptCompiledDefinition): Boolean; forward;

  function FindNestedScope(AScope: TNexusScriptCompiledDefinition;
    const AName: string): TNexusScriptCompiledDefinition;
  var
    lProperty: TNexusScriptCompiledProperty;
  begin
    Result := AScope.FindChild(AName);
    if Result <> nil then
      Exit;
    lProperty := AScope.FindProperty(AName);
    if lProperty <> nil then
    begin
      if lProperty.Value.StructuralDefinition = nil then
        EvaluateProperty(AScope, lProperty);
      Result := lProperty.Value.StructuralDefinition;
    end;
  end;

  function FindStructuralPropertyScope(
    AScope: TNexusScriptCompiledDefinition;
    const AName: string): TNexusScriptCompiledDefinition;
  var
    lProperty: TNexusScriptCompiledProperty;
  begin
    Result := nil;
    if AScope = nil then
      Exit;
    lProperty := AScope.FindProperty(AName);
    if lProperty <> nil then
    begin
      if lProperty.Value.StructuralDefinition = nil then
        EvaluateProperty(AScope, lProperty);
      Result := lProperty.Value.StructuralDefinition;
    end;
  end;

  function FindDefinitionPath(AScope: TNexusScriptCompiledDefinition;
    const APath: string): TNexusScriptCompiledDefinition;
  var
    lParts: TStringList;
    lScope: TNexusScriptCompiledDefinition;
    lIndex: Integer;
  begin
    Result := nil;
    lParts := TStringList.Create;
    try
      lParts.Delimiter := '.';
      lParts.StrictDelimiter := True;
      lParts.DelimitedText := APath;
      if lParts.Count = 1 then
      begin
        if AScope = nil then
          Exit(FCompiledDocument.FindDefinition(lParts[0]));
        Result := AScope.FindChild(lParts[0]);
        if Result = nil then
        begin
          Result := FCompiledDocument.FindDefinition(lParts[0]);
          if (Result <> nil) and not Result.ImportedRoot then
            Result := nil;
        end;
        Exit;
      end;
      lScope := FindStructuralPropertyScope(AScope, lParts[0]);
      if lScope <> nil then
      begin
        for lIndex := 1 to lParts.Count - 1 do
        begin
          lScope := FindNestedScope(lScope, lParts[lIndex]);
          if lScope = nil then
            Exit;
        end;
        Exit(lScope);
      end;
      lScope := AScope;
      while (lScope <> nil) and not SameText(lScope.Name, lParts[0]) do
        lScope := lScope.Parent;
      if lScope = nil then
      begin
        lScope := FCompiledDocument.FindDefinition(lParts[0]);
        if (lScope <> nil) and not lScope.ImportedRoot then
          lScope := nil;
      end;
      if lScope = nil then
        Exit;
      for lIndex := 1 to lParts.Count - 1 do
      begin
        lScope := FindNestedScope(lScope, lParts[lIndex]);
        if lScope = nil then
          Exit;
      end;
      Result := lScope;
    finally
      lParts.Free;
    end;
  end;

  procedure Compose(ADefinition: TNexusScriptCompiledDefinition;
    ASource: TNexusScriptSourceDefinition = nil);
  var
    lSource: TNexusScriptSourceDefinition;
    lSelector: string;
    lBase: TNexusScriptCompiledDefinition;
    lProperty: TNexusScriptCompiledProperty;
    lChild: TNexusScriptCompiledDefinition;
    lChildSource: TNexusScriptSourceDefinition;
    lLocalProperties: TNexusScriptCompiledPropertyList;
    lLocalChildren: TNexusScriptCompiledDefinitionList;

    procedure RemoveProperty(const AName: string);
    var
      lMemberIndex: Integer;
    begin
      for lMemberIndex := ADefinition.Properties.Count - 1 downto 0 do
        if SameText(ADefinition.Properties[lMemberIndex].Name, AName) then
          ADefinition.Properties.Delete(lMemberIndex);
    end;

    procedure RemoveChild(const AName: string);
    var
      lMemberIndex: Integer;
    begin
      for lMemberIndex := ADefinition.Children.Count - 1 downto 0 do
        if SameText(ADefinition.Children[lMemberIndex].Name, AName) then
          ADefinition.Children.Delete(lMemberIndex);
    end;

    procedure AppendCompositionLayers(ATarget,
      ASource: TNexusScriptCompiledValue);
    var
      lContributor: TNexusScriptCompiledValue;
    begin
      if ASource.CompositionContributors.Count = 0 then
        ATarget.CompositionContributors.Add(
          CloneValueForRebinding(ASource))
      else
        for lContributor in ASource.CompositionContributors do
          ATarget.CompositionContributors.Add(
            CloneValueForRebinding(lContributor));
    end;

    procedure ApplyProperty(AProperty: TNexusScriptCompiledProperty);
    var
      lExisting: TNexusScriptCompiledProperty;
      lMergedValue: TNexusScriptCompiledValue;

      function CanHaveArrayResult(
        AValue: TNexusScriptCompiledValue): Boolean;
      begin
        Result := AValue.Kind in [nsvArray, nsvReference];
      end;
    begin
      if ADefinition.FindChild(AProperty.Name) <> nil then
      begin
        AddError('NXS4003', 'Ambiguous composed member ' + AProperty.Name,
          ADefinition.SourceRange);
        Exit;
      end;
      lExisting := ADefinition.FindProperty(AProperty.Name);
      if (lExisting <> nil) and CanHaveArrayResult(lExisting.Value) and
        CanHaveArrayResult(AProperty.Value) then
      begin
        lMergedValue := CloneValueForRebinding(AProperty.Value);
        lMergedValue.CompositionContributors.Clear;
        lMergedValue.EvaluationState := nsvesPending;
        lMergedValue.ArrayPreparationState := nsapsUnprepared;
        AppendCompositionLayers(lMergedValue, lExisting.Value);
        AppendCompositionLayers(lMergedValue, AProperty.Value);
        RemoveProperty(AProperty.Name);
        ADefinition.Properties.Add(TNexusScriptCompiledProperty.Create(
          AProperty.Name, lMergedValue, AProperty.SourceRange));
        Exit;
      end;
      RemoveProperty(AProperty.Name);
      ADefinition.Properties.Add(TNexusScriptCompiledProperty.Create(
        AProperty.Name, CloneValueForRebinding(AProperty.Value),
        AProperty.SourceRange));
    end;
  begin
    if ADefinition.Composed then
      Exit;
    if ADefinition.Composing then
    begin
      AddError('NXS4001', 'Composition cycle at ' + ADefinition.Name,
        ADefinition.SourceRange);
      Exit;
    end;
    ADefinition.Composing := True;
    lSource := ASource;
    if lSource = nil then
      lSource := SourceFor(ADefinition);
    if lSource = nil then
    begin
      ADefinition.Composing := False;
      ADefinition.Composed := True;
      Exit;
    end;
    lLocalProperties := TNexusScriptCompiledPropertyList.Create(True);
    lLocalChildren := TNexusScriptCompiledDefinitionList.Create(True);
    try
      for lProperty in ADefinition.Properties do
        lLocalProperties.Add(TNexusScriptCompiledProperty.Create(lProperty.Name,
          CloneValue(lProperty.Value), lProperty.SourceRange));
      for lChild in ADefinition.Children do
        lLocalChildren.Add(CloneDefinition(lChild, ADefinition));
      ADefinition.Properties.Clear;
      ADefinition.Children.Clear;

      for lSelector in lSource.CompositionSelectors do
      begin
        lBase := FindDefinitionPath(ADefinition.Parent, lSelector);
        if lBase = nil then
        begin
          AddError('NXS4002', 'Unresolved composition target ' + lSelector,
            ADefinition.SourceRange);
          Continue;
        end;
        Compose(lBase);
        for lProperty in lBase.Properties do
          ApplyProperty(lProperty);
        for lChild in lBase.Children do
        begin
          if ADefinition.FindProperty(lChild.Name) <> nil then
            AddError('NXS4003', 'Ambiguous composed member ' + lChild.Name,
              ADefinition.SourceRange)
          else
          begin
            RemoveChild(lChild.Name);
            ADefinition.Children.Add(CloneDefinition(lChild, ADefinition));
          end;
        end;
      end;

      for lProperty in lLocalProperties do
        ApplyProperty(lProperty);
      for lChild in lLocalChildren do
      begin
        if ADefinition.FindProperty(lChild.Name) <> nil then
          AddError('NXS4003', 'Ambiguous composed member ' + lChild.Name,
            ADefinition.SourceRange)
        else
        begin
          RemoveChild(lChild.Name);
          ADefinition.Children.Add(CloneDefinition(lChild, ADefinition));
        end;
      end;
    finally
      lLocalChildren.Free;
      lLocalProperties.Free;
    end;
    ADefinition.Composing := False;
    ADefinition.Composed := True;
    for lChild in ADefinition.Children do
    begin
      lChildSource := nil;
      if lSource <> nil then
        lChildSource := lSource.FindChild(lChild.Name);
      Compose(lChild, lChildSource);
    end;
  end;

  function ResolveNamedArrayItem(AScope: TNexusScriptCompiledDefinition;
    AValue: TNexusScriptCompiledValue; const AName: string;
    out AArrayValue: TNexusScriptCompiledValue;
    out AItem: TNexusScriptCompiledValue): Boolean;
  begin
    AArrayValue := nil;
    AItem := nil;
    if not PrepareArrayValue(AScope, AValue, AArrayValue) then
      Exit(False);
    if AArrayValue = nil then
      Exit(False);
    AItem := AArrayValue.FindNamedItem(AName);
    Result := AItem <> nil;
  end;

  function ResolveMember(AScope: TNexusScriptCompiledDefinition;
    const APath: string; out AProperty: TNexusScriptCompiledProperty;
    out ADefinition: TNexusScriptCompiledDefinition;
    out APropertyOwner: TNexusScriptCompiledDefinition;
    out ADirectValue: TNexusScriptCompiledValue): Boolean;
  var
    lParts: TStringList;
    lScope: TNexusScriptCompiledDefinition;

    function ResolveDown(ACurrentScope: TNexusScriptCompiledDefinition;
      AIndex: Integer): Boolean;
    var
      lMemberProperty: TNexusScriptCompiledProperty;
      lMemberDefinition: TNexusScriptCompiledDefinition;
      lArrayItem: TNexusScriptCompiledValue;
      lArrayValue: TNexusScriptCompiledValue;
    begin
      Result := False;
      lMemberProperty := ACurrentScope.FindProperty(lParts[AIndex]);
      if lMemberProperty <> nil then
      begin
        if AIndex = lParts.Count - 1 then
        begin
          AProperty := lMemberProperty;
          APropertyOwner := ACurrentScope;
          Exit(True);
        end;
        lArrayValue := nil;
        if (lMemberProperty.Value.Kind in [nsvArray, nsvReference]) or
          (lMemberProperty.Value.CompositionContributors.Count > 0) then
        begin
          if not lMemberProperty.Resolving then
            if not EvaluateProperty(ACurrentScope, lMemberProperty) then
            begin
              AProperty := lMemberProperty;
              APropertyOwner := ACurrentScope;
              Exit(True);
            end;
          if not ResolveNamedArrayItem(ACurrentScope,
            lMemberProperty.Value, lParts[AIndex + 1], lArrayValue,
            lArrayItem) then
          begin
            if (lMemberProperty.Value.ArrayPreparationState = nsapsFailed) or
              (lMemberProperty.Value.EvaluationState = nsvesFailed) then
            begin
              AProperty := lMemberProperty;
              APropertyOwner := ACurrentScope;
              Exit(True);
            end;
            if lArrayValue <> nil then
              Exit;
          end
          else
          begin
            if AIndex + 1 = lParts.Count - 1 then
            begin
              APropertyOwner := ACurrentScope;
              ADirectValue := lArrayItem;
              Exit(True);
            end;
            if (lArrayItem.EvaluationState = nsvesResolving) and
              (lArrayItem.Kind = nsvDefinition) and
              (lArrayItem.StructuralDefinition <> nil) then
              Exit(ResolveDown(lArrayItem.StructuralDefinition,
                AIndex + 2));
            if not EvaluateValue(ACurrentScope, lArrayItem,
              lArrayItem.EntryName) then
            begin
              ADirectValue := lArrayItem;
              Exit(True);
            end;
            if lArrayItem.StructuralDefinition = nil then
              Exit;
            Exit(ResolveDown(lArrayItem.StructuralDefinition, AIndex + 2));
          end;
        end;
        if not EvaluateProperty(ACurrentScope, lMemberProperty) then
        begin
          AProperty := lMemberProperty;
          APropertyOwner := ACurrentScope;
          Exit(True);
        end;
        if lMemberProperty.Value.StructuralDefinition <> nil then
          Exit(ResolveDown(lMemberProperty.Value.StructuralDefinition,
            AIndex + 1));
        if (lMemberProperty.Value.EffectiveValue <> nil) and
          (lMemberProperty.Value.EffectiveValue.StructuralDefinition <> nil) then
          Exit(ResolveDown(
            lMemberProperty.Value.EffectiveValue.StructuralDefinition,
            AIndex + 1));
        Exit;
      end;
      lMemberDefinition := ACurrentScope.FindChild(lParts[AIndex]);
      if lMemberDefinition = nil then
        Exit;
      if AIndex = lParts.Count - 1 then
      begin
        ADefinition := lMemberDefinition;
        Exit(True);
      end;
      Result := ResolveDown(lMemberDefinition, AIndex + 1);
    end;
  begin
    AProperty := nil;
    ADefinition := nil;
    APropertyOwner := nil;
    ADirectValue := nil;
    lParts := TStringList.Create;
    try
      lParts.Delimiter := '.';
      lParts.StrictDelimiter := True;
      lParts.DelimitedText := APath;
      if lParts.Count = 1 then
      begin
        if ResolveDown(AScope, 0) then
          Exit(True);
        lScope := FCompiledDocument.FindDefinition(lParts[0]);
        if (lScope <> nil) and lScope.ImportedRoot then
        begin
          ADefinition := lScope;
          Exit(True);
        end;
        Exit(False);
      end;
      lScope := AScope;
      while lScope <> nil do
      begin
        if lScope.FindProperty(lParts[0]) <> nil then
          Exit(ResolveDown(lScope, 0));
        lScope := lScope.Parent;
      end;
      lScope := AScope;
      while (lScope <> nil) and not SameText(lScope.Name, lParts[0]) do
        lScope := lScope.Parent;
      if lScope = nil then
      begin
        lScope := FCompiledDocument.FindDefinition(lParts[0]);
        if (lScope <> nil) and not lScope.ImportedRoot then
          lScope := nil;
      end;
      if lScope = nil then
        Exit(False);
      Result := ResolveDown(lScope, 1);
    finally
      lParts.Free;
    end;
  end;

  function EvaluateProperty(AScope: TNexusScriptCompiledDefinition;
    AProperty: TNexusScriptCompiledProperty): Boolean;
  begin
    if AProperty.Resolving then
    begin
      AddError('NXS5002', 'Value dependency cycle at ' + AProperty.Name,
        AProperty.SourceRange);
      Exit(False);
    end;
    if AProperty.Value.EvaluationState = nsvesCompleted then
      Exit(True);
    if AProperty.Value.EvaluationState = nsvesFailed then
      Exit(False);
    AProperty.Resolving := True;
    try
      Result := EvaluateValue(AScope, AProperty.Value, AProperty.Name);
    finally
      AProperty.Resolving := False;
    end;
  end;

  function ValueDiagnosticName(AValue: TNexusScriptCompiledValue): string;
  begin
    Result := AValue.EffectiveName;
    if Result = '' then
      Result := AValue.EntryName;
    if Result = '' then
      Result := AValue.OriginalDefinitionName;
    if Result = '' then
      Result := AValue.SourceText;
    if Result = '' then
      Result := 'array';
  end;

  function EstablishEntryIdentity(AScope: TNexusScriptCompiledDefinition;
    AValue: TNexusScriptCompiledValue): Boolean;
  var
    lProperty: TNexusScriptCompiledProperty;
    lDefinition: TNexusScriptCompiledDefinition;
    lPropertyOwner: TNexusScriptCompiledDefinition;
    lDirectValue: TNexusScriptCompiledValue;
  begin
    if AValue.EffectiveName <> '' then
      Exit(True);
    if AValue.EntryName <> '' then
    begin
      AValue.EffectiveName := AValue.EntryName;
      Exit(True);
    end;
    if AValue.Kind = nsvDefinition then
    begin
      AValue.EffectiveName := AValue.OriginalDefinitionName;
      Exit(True);
    end;
    if AValue.Kind <> nsvReference then
      Exit(True);
    lDefinition := AValue.ResolvedDefinition;
    if lDefinition = nil then
    begin
      if not ResolveMember(AScope, AValue.SourceText, lProperty,
        lDefinition, lPropertyOwner, lDirectValue) then
      begin
        AddError('NXS5001', 'Unresolved reference @' + AValue.SourceText,
          AValue.SourceRange);
        AValue.EvaluationState := nsvesFailed;
        Exit(False);
      end;
      AValue.ResolvedProperty := lProperty;
      AValue.ResolvedDefinition := lDefinition;
      AValue.ResolvedValue := lDirectValue;
    end;
    if lDefinition <> nil then
    begin
      AValue.EffectiveName := lDefinition.Name;
      AValue.OriginalDefinitionName := lDefinition.Name;
    end;
    Result := True;
  end;

  function PrepareArrayValue(AScope: TNexusScriptCompiledDefinition;
    AValue: TNexusScriptCompiledValue;
    out AArrayValue: TNexusScriptCompiledValue): Boolean;
  var
    lItem: TNexusScriptCompiledValue;
    lContributor: TNexusScriptCompiledValue;
    lContributorArray: TNexusScriptCompiledValue;
    lTargetArray: TNexusScriptCompiledValue;
    lMergedItem: TNexusScriptCompiledValue;
    lExistingItem: TNexusScriptCompiledValue;
    lProperty: TNexusScriptCompiledProperty;
    lDefinition: TNexusScriptCompiledDefinition;
    lPropertyOwner: TNexusScriptCompiledDefinition;
    lDirectValue: TNexusScriptCompiledValue;
    lNames: TStringList;
    lExistingIndex: Integer;
    lAllContributorArrays: Boolean;
    lSucceeded: Boolean;
  begin
    AArrayValue := nil;
    case AValue.ArrayPreparationState of
      nsapsPrepared:
        begin
          if AValue.Kind = nsvArray then
            AArrayValue := AValue
          else if (AValue.EffectiveValue <> nil) and
            (AValue.EffectiveValue.Kind = nsvArray) then
            AArrayValue := AValue.EffectiveValue;
          Exit(True);
        end;
      nsapsPreparing:
        begin
          AddError('NXS5002', 'Value dependency cycle at ' +
            ValueDiagnosticName(AValue), AValue.SourceRange);
          AValue.ArrayPreparationState := nsapsFailed;
          Exit(False);
        end;
      nsapsFailed:
        Exit(False);
    end;

    AValue.ArrayPreparationState := nsapsPreparing;
    Result := False;
    try
      if AValue.CompositionContributors.Count > 0 then
      begin
        lAllContributorArrays := True;
        for lContributor in AValue.CompositionContributors do
        begin
          if not PrepareArrayValue(AScope, lContributor,
            lContributorArray) then
            Exit;
          if lContributorArray = nil then
            lAllContributorArrays := False;
        end;
        if lAllContributorArrays then
        begin
          AValue.Kind := nsvArray;
          AValue.EffectiveValue.Free;
          AValue.EffectiveValue := nil;
          AValue.Items.Clear;
          for lContributor in AValue.CompositionContributors do
          begin
            if not PrepareArrayValue(AScope, lContributor,
              lContributorArray) then
              Exit;
            for lItem in lContributorArray.Items do
            begin
              lMergedItem := CloneValueForRebinding(lItem);
              lExistingIndex := -1;
              if lMergedItem.EffectiveName <> '' then
              begin
                lExistingItem := AValue.FindNamedItem(
                  lMergedItem.EffectiveName);
                if lExistingItem <> nil then
                  lExistingIndex := AValue.Items.IndexOf(lExistingItem);
              end;
              if lExistingIndex >= 0 then
                AValue.Items[lExistingIndex] := lMergedItem
              else
                AValue.Items.Add(lMergedItem);
            end;
          end;
        end
        else
          AValue.CompositionContributors.Clear;
      end;

      if AValue.Kind = nsvArray then
      begin
        lNames := TStringList.Create;
        try
          lNames.CaseSensitive := False;
          lSucceeded := True;
          for lItem in AValue.Items do
          begin
            if not EstablishEntryIdentity(AScope, lItem) then
              lSucceeded := False;
            if lItem.EffectiveName <> '' then
            begin
              if lNames.IndexOf(lItem.EffectiveName) >= 0 then
              begin
                AddError('NXS5005', 'Duplicate array entry name ' +
                  lItem.EffectiveName, lItem.SourceRange);
                lSucceeded := False;
              end
              else
                lNames.Add(lItem.EffectiveName);
            end;
          end;
          if not lSucceeded then
            Exit;
        finally
          lNames.Free;
        end;
        AArrayValue := AValue;
        Result := True;
        Exit;
      end;

      if AValue.Kind = nsvReference then
      begin
        lProperty := nil;
        lDefinition := nil;
        lPropertyOwner := nil;
        lDirectValue := nil;
        if not ResolveMember(AScope, AValue.SourceText, lProperty,
          lDefinition, lPropertyOwner, lDirectValue) then
        begin
          AddError('NXS5001', 'Unresolved reference @' + AValue.SourceText,
            AValue.SourceRange);
          Exit;
        end;
        AValue.ResolvedProperty := lProperty;
        AValue.ResolvedDefinition := lDefinition;
        AValue.ResolvedValue := lDirectValue;
        lTargetArray := nil;
        if lProperty <> nil then
        begin
          if not PrepareArrayValue(lPropertyOwner, lProperty.Value,
            lTargetArray) then
            Exit;
        end
        else if lDirectValue <> nil then
        begin
          if not PrepareArrayValue(AScope, lDirectValue, lTargetArray) then
            Exit;
        end;
        if lTargetArray <> nil then
        begin
          AValue.EffectiveValue.Free;
          AValue.EffectiveValue := CloneValue(lTargetArray);
          AArrayValue := AValue.EffectiveValue;
        end;
      end;
      Result := True;
    finally
      if Result then
        AValue.ArrayPreparationState := nsapsPrepared
      else
        AValue.ArrayPreparationState := nsapsFailed;
    end;
  end;

  function PrepareReferenceProjection(
    ADefinition: TNexusScriptCompiledDefinition): Boolean;
  var
    lProperty: TNexusScriptCompiledProperty;
    lChild: TNexusScriptCompiledDefinition;
  begin
    Result := False;
    for lProperty in ADefinition.Properties do
    begin
      if lProperty.Resolving then
      begin
        if (lProperty.Value.Kind = nsvArray) and
          not IsScalarProjectionValue(lProperty.Value) then
          Continue;
        Exit;
      end;
      if lProperty.Value.EvaluationState <> nsvesCompleted then
        if not EvaluateProperty(ADefinition, lProperty) then
          Exit;
      if (lProperty.Value.Kind = nsvArray) and
        not IsScalarProjectionValue(lProperty.Value) then
        Continue;
      if (lProperty.Value.Kind = nsvReference) and
        (lProperty.Value.ResolvedDefinition <> nil) and
        (lProperty.Value.StructuralDefinition = nil) then
        Exit;
      if (lProperty.Value.StructuralDefinition <> nil) and
        not PrepareReferenceProjection(
          lProperty.Value.StructuralDefinition) then
        Exit;
    end;
    for lChild in ADefinition.Children do
      if not PrepareReferenceProjection(lChild) then
        Exit;
    Result := True;
  end;

  function DefinitionIsBinding(
    ADefinition: TNexusScriptCompiledDefinition): Boolean;
  var
    lProperty: TNexusScriptCompiledProperty;
  begin
    Result := False;
    for lProperty in ADefinition.Properties do
      if lProperty.Resolving then
        Exit(True);
  end;

  function EvaluateValue(AScope: TNexusScriptCompiledDefinition;
    AValue: TNexusScriptCompiledValue;
    const AReceiverName: string): Boolean;
  var
    lItem: TNexusScriptCompiledValue;
    lProperty: TNexusScriptCompiledProperty;
    lDefinition: TNexusScriptCompiledDefinition;
    lPropertyOwner: TNexusScriptCompiledDefinition;
    lOriginalDefinition: TNexusScriptCompiledDefinition;
    lEffectiveName: string;
    lDirectValue: TNexusScriptCompiledValue;
    lArrayValue: TNexusScriptCompiledValue;
    lSucceeded: Boolean;
  begin
    case AValue.EvaluationState of
      nsvesCompleted:
        Exit(True);
      nsvesResolving:
        begin
          AddError('NXS5002', 'Value dependency cycle at ' +
            ValueDiagnosticName(AValue), AValue.SourceRange);
          AValue.EvaluationState := nsvesFailed;
          Exit(False);
        end;
      nsvesFailed:
        Exit(False);
    end;

    AValue.EvaluationState := nsvesResolving;
    Result := False;
    try
      if AValue.CompositionContributors.Count > 0 then
        if not PrepareArrayValue(AScope, AValue, lArrayValue) then
          Exit;
      case AValue.Kind of
      nsvText:
        begin
          AValue.EffectiveText := AValue.SourceText;
          AValue.HasEffectiveText := True;
          Result := True;
        end;
      nsvDefinition:
        begin
          lOriginalDefinition := AValue.StructuralDefinition;
          lOriginalDefinition.Parent := AScope;
          Compose(lOriginalDefinition, AValue.InlineSourceDefinition);
          if not BindDefinition(lOriginalDefinition) then
            Exit;
          lEffectiveName := AValue.EntryName;
          if lEffectiveName = '' then
            lEffectiveName := AValue.OriginalDefinitionName;
          AValue.StructuralDefinition := CloneDefinitionAs(
            lOriginalDefinition, AScope, lEffectiveName);
          lOriginalDefinition.Free;
          AValue.EffectiveName := lEffectiveName;
          Result := True;
        end;
      nsvReference:
        begin
          lProperty := nil;
          lDefinition := nil;
          lPropertyOwner := nil;
          lDirectValue := nil;
          if not ResolveMember(AScope, AValue.SourceText, lProperty,
            lDefinition, lPropertyOwner, lDirectValue) then
          begin
            AddError('NXS5001', 'Unresolved reference @' + AValue.SourceText,
              AValue.SourceRange);
            Exit;
          end;
          AValue.ResolvedProperty := lProperty;
          AValue.ResolvedDefinition := lDefinition;
          AValue.ResolvedValue := lDirectValue;
          if lDirectValue <> nil then
          begin
            if (lDirectValue.EvaluationState = nsvesResolving) and
              (lDirectValue.Kind = nsvDefinition) and
              (lDirectValue.StructuralDefinition <> nil) then
            begin
              AValue.ResolvedDefinition :=
                lDirectValue.StructuralDefinition;
              AValue.StructuralDefinition := CloneReferenceProjection(
                lDirectValue.StructuralDefinition, AScope, AReceiverName);
              AValue.OriginalDefinitionName :=
                lDirectValue.OriginalDefinitionName;
              AValue.EffectiveName := AReceiverName;
              Result := True;
              Exit;
            end;
            if lPropertyOwner = nil then
              lPropertyOwner := AScope;
            if not EvaluateValue(lPropertyOwner, lDirectValue,
              lDirectValue.EntryName) then
              Exit;
            AValue.EffectiveText := lDirectValue.EffectiveText;
            AValue.HasEffectiveText := lDirectValue.HasEffectiveText;
            AValue.ResolvedProperty := lDirectValue.ResolvedProperty;
            AValue.ResolvedDefinition := lDirectValue.ResolvedDefinition;
            AValue.EffectiveValue.Free;
            AValue.EffectiveValue := nil;
            if lDirectValue.EffectiveValue <> nil then
              AValue.EffectiveValue := CloneValue(
                lDirectValue.EffectiveValue)
            else if lDirectValue.Kind = nsvArray then
              AValue.EffectiveValue := CloneValue(lDirectValue);
            if lDirectValue.StructuralDefinition <> nil then
            begin
              AValue.StructuralDefinition := CloneReferenceProjection(
                lDirectValue.StructuralDefinition, AScope, AReceiverName);
              AValue.OriginalDefinitionName :=
                lDirectValue.OriginalDefinitionName;
            end;
            Result := True;
            Exit;
          end;
          if lProperty <> nil then
          begin
            if not EvaluateProperty(lPropertyOwner, lProperty) then
              Exit;
            AValue.EffectiveText := lProperty.Value.EffectiveText;
            AValue.HasEffectiveText := lProperty.Value.HasEffectiveText;
            AValue.EffectiveValue.Free;
            AValue.EffectiveValue := nil;
            if lProperty.Value.EffectiveValue <> nil then
              AValue.EffectiveValue := CloneValue(
                lProperty.Value.EffectiveValue)
            else if lProperty.Value.Kind = nsvArray then
              AValue.EffectiveValue := CloneValue(lProperty.Value);
            Result := True;
          end;
          if lDefinition <> nil then
          begin
            if AValue.StructuralDefinition <> nil then
            begin
              Result := True;
              Exit;
            end;
            if (lMaterializingDefinitions.IndexOf(lDefinition) >= 0) or
              DefinitionIsBinding(lDefinition) then
            begin
              if PrepareReferenceProjection(lDefinition) then
              begin
                lEffectiveName := AReceiverName;
                if lEffectiveName = '' then
                  lEffectiveName := lDefinition.Name;
                AValue.StructuralDefinition := CloneReferenceProjection(
                  lDefinition, AScope, lEffectiveName);
                AValue.EffectiveName := lEffectiveName;
                AValue.OriginalDefinitionName := lDefinition.Name;
                Result := True;
              end
              else
                AddError('NXS5004', 'Structural reference cycle at @' +
                  AValue.SourceText, AValue.SourceRange);
              Exit;
            end;
            lMaterializingDefinitions.Add(lDefinition);
            try
              if not BindDefinition(lDefinition) then
                Exit;
              lEffectiveName := AReceiverName;
              if lEffectiveName = '' then
                lEffectiveName := lDefinition.Name;
              AValue.StructuralDefinition := CloneReferenceProjection(
                lDefinition, AScope, lEffectiveName);
              AValue.EffectiveName := lEffectiveName;
              AValue.OriginalDefinitionName := lDefinition.Name;
              Result := True;
            finally
              lMaterializingDefinitions.Delete(
                lMaterializingDefinitions.Count - 1);
            end;
          end;
        end;
      nsvTextComposition:
        begin
          AValue.EffectiveText := '';
          AValue.HasEffectiveText := True;
          lSucceeded := True;
          for lItem in AValue.Items do
          begin
            if not EvaluateValue(AScope, lItem, AReceiverName) then
              lSucceeded := False;
            if not lItem.HasEffectiveText then
            begin
              AddError('NXS5003',
                'Definition reference cannot be composed as text',
                lItem.SourceRange);
              AValue.HasEffectiveText := False;
              lSucceeded := False;
            end
            else
              AValue.EffectiveText := AValue.EffectiveText +
                lItem.EffectiveText;
          end;
          Result := lSucceeded;
        end;
      nsvArray:
        begin
          if not PrepareArrayValue(AScope, AValue, lArrayValue) then
            Exit;
          lSucceeded := True;
          for lItem in lArrayValue.Items do
            if not EvaluateValue(AScope, lItem, lItem.EntryName) then
              lSucceeded := False;
          Result := lSucceeded;
        end;
      end;
    finally
      if Result then
        AValue.EvaluationState := nsvesCompleted
      else
        AValue.EvaluationState := nsvesFailed;
    end;
  end;

  function BindDefinition(
    ADefinition: TNexusScriptCompiledDefinition): Boolean;
  var
    lProperty: TNexusScriptCompiledProperty;
    lChild: TNexusScriptCompiledDefinition;
  begin
    Result := True;
    for lProperty in ADefinition.Properties do
      if not EvaluateProperty(ADefinition, lProperty) then
        Result := False;
    for lChild in ADefinition.Children do
      if not BindDefinition(lChild) then
        Result := False;
  end;

var
  lCompiledDefinition: TNexusScriptCompiledDefinition;
  lImportedDefinition: TNexusScriptCompiledDefinition;

  procedure MarkComposed(ADefinition: TNexusScriptCompiledDefinition);
  var
    lChild: TNexusScriptCompiledDefinition;
  begin
    ADefinition.Composed := True;
    for lChild in ADefinition.Children do
      MarkComposed(lChild);
  end;
begin
  lMaterializingDefinitions := TList<TNexusScriptCompiledDefinition>.Create;
  try
    FCompiledDocument := TNexusScriptCompiledDocument.Create(
      FSourceDocument.SourceName);
  for lImportedDefinition in FImportedDefinitions do
  begin
    if FCompiledDocument.FindDefinition(lImportedDefinition.Name) <> nil then
    begin
      AddError('NXS3003', 'Duplicate imported root ' +
        lImportedDefinition.Name, lImportedDefinition.SourceRange);
      Continue;
    end;
    lCompiledDefinition := CloneDefinitionAs(lImportedDefinition, nil,
      lImportedDefinition.Name);
    MarkComposed(lCompiledDefinition);
    FCompiledDocument.Definitions.Add(lCompiledDefinition);
  end;
  for lSourceDefinition in FSourceDocument.Definitions do
    if FCompiledDocument.FindDefinition(lSourceDefinition.Name) <> nil then
      AddError('NXS3004', 'Imported root collides with local root definition ' +
        lSourceDefinition.Name, lSourceDefinition.SourceRange)
    else
      FCompiledDocument.Definitions.Add(CopyDefinition(lSourceDefinition, nil));
  for lCompiledDefinition in FCompiledDocument.Definitions do
    Compose(lCompiledDefinition);
  for lSourceDefinition in FSourceDocument.Definitions do
  begin
    lCompiledDefinition := FCompiledDocument.FindDefinition(
      lSourceDefinition.Name);
    if lCompiledDefinition <> nil then
      BindDefinition(lCompiledDefinition);
  end;
  finally
    lMaterializingDefinitions.Free;
  end;
end;

procedure TNexusScriptCompiler.ClearImports;
begin
  FImportedDefinitions.Clear;
end;

procedure TNexusScriptCompiler.AddImportedDefinition(
  ADefinition: TNexusScriptCompiledDefinition);
var
  lImportedDefinition: TNexusScriptCompiledDefinition;
begin
  lImportedDefinition := CloneDefinition(ADefinition, nil);
  lImportedDefinition.ImportedRoot := True;
  FImportedDefinitions.Add(lImportedDefinition);
end;

procedure TNexusScriptCompiler.AddImportedDocument(
  ADocument: TNexusScriptCompiledDocument);
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  for lDefinition in ADocument.Definitions do
    AddImportedDefinition(lDefinition);
end;

function TNexusScriptCompiler.CompileText(const ASourceName,
  AText: string): Boolean;
var
  lParser: TNexusScriptParser;
begin
  FDiagnostics.Clear;
  FreeAndNil(FCompiledDocument);
  FreeAndNil(FSourceDocument);
  lParser := TNexusScriptParser.Create(Self, ASourceName, AText);
  try
    FSourceDocument := lParser.Parse;
  finally
    lParser.Free;
  end;
  CompileSource;
  Result := FDiagnostics.Count = 0;
end;

function TNexusScriptCompiler.CompileFile(const AFileName: string): Boolean;
var
  lText: TStringList;
begin
  lText := TStringList.Create;
  try
    lText.LoadFromFile(AFileName);
    Result := CompileText(ExpandFileName(AFileName), lText.Text);
  finally
    lText.Free;
  end;
end;

end.
