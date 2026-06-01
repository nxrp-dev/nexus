unit obNXPasSignatures;

{$mode objfpc}{$H+}

interface

uses
  Contnrs,
  obNXPasSource,
  obNXPasSymbols,
  obNXPasWorkspaceIndex;

type
  TNXPasRoutineKind = (
    prkUnknown,
    prkProcedure,
    prkFunction,
    prkConstructor,
    prkDestructor
  );

  TNXPasSignatureParameter = class
  private
    FLabel: string;
  public
    property &Label: string read FLabel write FLabel;
  end;

  TNXPasSignatureParameterList = class(TObjectList)
  public
    function AddParameter(const ALabel: string): TNXPasSignatureParameter;
    function ParameterAt(AIndex: Integer): TNXPasSignatureParameter;
  end;

  TNXPasRoutineSignature = class
  private
    FDeclarationRange: TNXPasSourceRange;
    FKind: TNXPasRoutineKind;
    FLabel: string;
    FName: string;
    FParameters: TNXPasSignatureParameterList;
    FReturnType: string;
    FSelectionRange: TNXPasSourceRange;
    FURI: string;
  public
    constructor Create;
    destructor Destroy; override;
    property DeclarationRange: TNXPasSourceRange read FDeclarationRange write FDeclarationRange;
    property Kind: TNXPasRoutineKind read FKind write FKind;
    property &Label: string read FLabel write FLabel;
    property Name: string read FName write FName;
    property Parameters: TNXPasSignatureParameterList read FParameters;
    property ReturnType: string read FReturnType write FReturnType;
    property SelectionRange: TNXPasSourceRange read FSelectionRange write FSelectionRange;
    property URI: string read FURI write FURI;
  end;

  TNXPasRoutineSignatureList = class(TObjectList)
  public
    function AddSignature: TNXPasRoutineSignature;
    function SignatureAt(AIndex: Integer): TNXPasRoutineSignature;
  end;

  TNXPasCallContext = class
  private
    FActiveParameter: Integer;
    FName: string;
    FRange: TNXPasSourceRange;
  public
    property ActiveParameter: Integer read FActiveParameter write FActiveParameter;
    property Name: string read FName write FName;
    property Range: TNXPasSourceRange read FRange write FRange;
  end;

  TNXPasSignatureHelper = class
  private
    class function FindDeclarationEnd(const AText: string;
      AStartOffset: Integer; out AEndOffset: Integer): Boolean; static;
    class function RoutineKindFromText(const AText: string): TNXPasRoutineKind; static;
    class function ExtractParameterText(const ALabel: string): string; static;
    class function ExtractReturnType(const ALabel: string): string; static;
    class procedure SplitParameters(const AText: string;
      AParameters: TNXPasSignatureParameterList); static;
  public
    class function ExtractSignature(AFile: TNXPasIndexedFile;
      ASymbol: TNXPasSymbol; ASignature: TNXPasRoutineSignature): Boolean; static;
    class function FindCallAtPosition(ASource: TNXPasSourceFile;
      ALine, AColumn: Integer; AContext: TNXPasCallContext): Boolean; static;
    class function PositionIsInactive(ASource: TNXPasSourceFile;
      ALine, AColumn: Integer): Boolean; static;
  end;

implementation

uses
  SysUtils,
  obNXPasAST,
  obNXPasDiagnostics,
  obNXPasLexer,
  obNXPasParser,
  tpNXPasTokens;

function TNXPasSignatureParameterList.AddParameter(
  const ALabel: string): TNXPasSignatureParameter;
begin
  Result := TNXPasSignatureParameter.Create;
  Result.&Label := Trim(ALabel);
  Add(Result);
end;

function TNXPasSignatureParameterList.ParameterAt(
  AIndex: Integer): TNXPasSignatureParameter;
begin
  Result := TNXPasSignatureParameter(Items[AIndex]);
end;

constructor TNXPasRoutineSignature.Create;
begin
  inherited Create;
  FParameters := TNXPasSignatureParameterList.Create(True);
end;

destructor TNXPasRoutineSignature.Destroy;
begin
  FreeAndNil(FParameters);
  inherited Destroy;
end;

function TNXPasRoutineSignatureList.AddSignature: TNXPasRoutineSignature;
begin
  Result := TNXPasRoutineSignature.Create;
  Add(Result);
end;

function TNXPasRoutineSignatureList.SignatureAt(
  AIndex: Integer): TNXPasRoutineSignature;
begin
  Result := TNXPasRoutineSignature(Items[AIndex]);
end;

class function TNXPasSignatureHelper.RoutineKindFromText(
  const AText: string): TNXPasRoutineKind;
var
  lText: string;
begin
  lText := LowerCase(Trim(AText));
  if Pos('procedure ', lText) = 1 then
    Result := prkProcedure
  else if Pos('function ', lText) = 1 then
    Result := prkFunction
  else if Pos('constructor ', lText) = 1 then
    Result := prkConstructor
  else if Pos('destructor ', lText) = 1 then
    Result := prkDestructor
  else
    Result := prkUnknown;
end;

class function TNXPasSignatureHelper.FindDeclarationEnd(const AText: string;
  AStartOffset: Integer; out AEndOffset: Integer): Boolean;
var
  lAngleDepth: Integer;
  lBracketDepth: Integer;
  lLexer: TNXPasLexer;
  lParenDepth: Integer;
  lToken: TNXPasToken;
begin
  Result := False;
  AEndOffset := 0;
  lAngleDepth := 0;
  lBracketDepth := 0;
  lParenDepth := 0;
  lLexer := TNXPasLexer.Create(AText);
  try
    repeat
      lToken := lLexer.NextToken;
      if lToken.StartPos.Offset < AStartOffset then
        Continue;

      if (lToken.Kind = ptkSymbol) and (lToken.Text = ';') and
        (lParenDepth = 0) and (lBracketDepth = 0) and (lAngleDepth = 0) then
      begin
        AEndOffset := lToken.StartPos.Offset;
        Exit(True);
      end;

      if (lToken.Kind = ptkSymbol) and (lToken.Text = '(') then
        Inc(lParenDepth)
      else if (lToken.Kind = ptkSymbol) and (lToken.Text = ')') and
        (lParenDepth > 0) then
        Dec(lParenDepth)
      else if (lToken.Kind = ptkSymbol) and (lToken.Text = '[') then
        Inc(lBracketDepth)
      else if (lToken.Kind = ptkSymbol) and (lToken.Text = ']') and
        (lBracketDepth > 0) then
        Dec(lBracketDepth)
      else if (lToken.Kind = ptkSymbol) and (lToken.Text = '<') then
        Inc(lAngleDepth)
      else if (lToken.Kind = ptkSymbol) and (lToken.Text = '>') and
        (lAngleDepth > 0) then
        Dec(lAngleDepth);
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;
end;

class function TNXPasSignatureHelper.ExtractParameterText(
  const ALabel: string): string;
var
  lDepth: Integer;
  lEndIdx: Integer;
  lIdx: Integer;
  lStartIdx: Integer;
begin
  Result := '';
  lStartIdx := 0;
  lEndIdx := 0;
  lDepth := 0;
  for lIdx := 1 to Length(ALabel) do
  begin
    if ALabel[lIdx] = '(' then
    begin
      if lDepth = 0 then
        lStartIdx := lIdx + 1;
      Inc(lDepth);
    end
    else if ALabel[lIdx] = ')' then
    begin
      Dec(lDepth);
      if lDepth = 0 then
      begin
        lEndIdx := lIdx - 1;
        Break;
      end;
    end;
  end;

  if (lStartIdx > 0) and (lEndIdx >= lStartIdx) then
    Result := Copy(ALabel, lStartIdx, lEndIdx - lStartIdx + 1);
end;

class function TNXPasSignatureHelper.ExtractReturnType(
  const ALabel: string): string;
var
  lDepth: Integer;
  lIdx: Integer;
begin
  Result := '';
  lDepth := 0;
  for lIdx := 1 to Length(ALabel) do
  begin
    if ALabel[lIdx] = '(' then
      Inc(lDepth)
    else if ALabel[lIdx] = ')' then
      Dec(lDepth)
    else if (ALabel[lIdx] = ':') and (lDepth = 0) then
      Exit(Trim(Copy(ALabel, lIdx + 1, MaxInt)));
  end;
end;

class procedure TNXPasSignatureHelper.SplitParameters(const AText: string;
  AParameters: TNXPasSignatureParameterList);
var
  lBracketDepth: Integer;
  lCurrent: string;
  lIdx: Integer;
  lParenDepth: Integer;
  lQuote: Boolean;
begin
  if AParameters = nil then
    Exit;

  lBracketDepth := 0;
  lCurrent := '';
  lParenDepth := 0;
  lQuote := False;
  for lIdx := 1 to Length(AText) do
  begin
    if AText[lIdx] = '''' then
      lQuote := not lQuote
    else if not lQuote then
    begin
      if AText[lIdx] = '(' then
        Inc(lParenDepth)
      else if (AText[lIdx] = ')') and (lParenDepth > 0) then
        Dec(lParenDepth)
      else if AText[lIdx] = '[' then
        Inc(lBracketDepth)
      else if (AText[lIdx] = ']') and (lBracketDepth > 0) then
        Dec(lBracketDepth)
      else if (AText[lIdx] = ';') and (lParenDepth = 0) and
        (lBracketDepth = 0) then
      begin
        if Trim(lCurrent) <> '' then
          AParameters.AddParameter(lCurrent);
        lCurrent := '';
        Continue;
      end;
    end;

    lCurrent := lCurrent + AText[lIdx];
  end;

  if Trim(lCurrent) <> '' then
    AParameters.AddParameter(lCurrent);
end;

class function TNXPasSignatureHelper.ExtractSignature(
  AFile: TNXPasIndexedFile; ASymbol: TNXPasSymbol;
  ASignature: TNXPasRoutineSignature): Boolean;
var
  lEndOffset: Integer;
  lLabel: string;
  lParamText: string;
  lRange: TNXPasSourceRange;
  lStartOffset: Integer;
begin
  Result := False;
  if (AFile = nil) or (ASymbol = nil) or (ASignature = nil) or
    (ASymbol.Kind <> pskRoutine) then
    Exit;

  lStartOffset := ASymbol.Range.StartPos.Offset;
  if not FindDeclarationEnd(AFile.Text, lStartOffset, lEndOffset) then
    Exit;

  lLabel := Trim(Copy(AFile.Text, lStartOffset, lEndOffset - lStartOffset));
  if lLabel = '' then
    Exit;

  ASignature.URI := AFile.URI;
  ASignature.Name := ASymbol.Name;
  ASignature.Kind := RoutineKindFromText(lLabel);
  ASignature.&Label := lLabel;
  ASignature.ReturnType := ExtractReturnType(lLabel);
  lRange.StartPos := ASymbol.Range.StartPos;
  lRange.EndPos := ASymbol.Range.EndPos;
  lRange.EndPos.Offset := lEndOffset;
  ASignature.DeclarationRange := lRange;
  ASignature.SelectionRange := ASymbol.Range;
  lParamText := ExtractParameterText(lLabel);
  SplitParameters(lParamText, ASignature.Parameters);
  Result := True;
end;

class function TNXPasSignatureHelper.FindCallAtPosition(
  ASource: TNXPasSourceFile; ALine, AColumn: Integer;
  AContext: TNXPasCallContext): Boolean;
var
  lActiveParameter: Integer;
  lBestName: string;
  lCallDepth: Integer;
  lLastIdentifier: string;
  lLastIdentifierRange: TNXPasSourceRange;
  lLexer: TNXPasLexer;
  lRange: TNXPasSourceRange;
  lToken: TNXPasToken;
begin
  Result := False;
  if (ASource = nil) or (AContext = nil) then
    Exit;

  lActiveParameter := 0;
  lBestName := '';
  lCallDepth := 0;
  lLastIdentifier := '';
  lLexer := TNXPasLexer.Create(ASource.Text);
  try
    repeat
      lToken := lLexer.NextToken;
      lRange := ASource.RangeFromPositions(lToken.StartPos, lToken.EndPos);
      if (lToken.StartPos.Line > ALine) or
        ((lToken.StartPos.Line = ALine) and (lToken.StartPos.Column >= AColumn)) then
        Break;

      if lToken.Kind = ptkIdentifier then
      begin
        lLastIdentifier := lToken.Text;
        lLastIdentifierRange := lRange;
      end
      else if (lToken.Kind = ptkSymbol) and (lToken.Text = '(') then
      begin
        Inc(lCallDepth);
        if (lCallDepth = 1) and (lLastIdentifier <> '') then
        begin
          lBestName := lLastIdentifier;
          AContext.Range := lLastIdentifierRange;
          lActiveParameter := 0;
        end;
      end
      else if (lToken.Kind = ptkSymbol) and (lToken.Text = ')') then
      begin
        if lCallDepth > 0 then
          Dec(lCallDepth);
        if lCallDepth = 0 then
          lBestName := '';
      end
      else if (lToken.Kind = ptkSymbol) and (lToken.Text = ',') and
        (lCallDepth = 1) and (lBestName <> '') then
        Inc(lActiveParameter);
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;

  if (lBestName = '') or (lCallDepth = 0) then
    Exit;

  AContext.Name := lBestName;
  AContext.ActiveParameter := lActiveParameter;
  Result := True;
end;

class function TNXPasSignatureHelper.PositionIsInactive(
  ASource: TNXPasSourceFile; ALine, AColumn: Integer): Boolean;
var
  lDiagnostics: TNXPasDiagnosticList;
  lIdx: Integer;
  lParser: TNXPasParser;
  lRange: TNXPasSourceRange;
  lTree: TNXPasSyntaxTree;
begin
  Result := False;
  if ASource = nil then
    Exit;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lParser := TNXPasParser.Create(lDiagnostics);
  lTree := nil;
  try
    lTree := lParser.Parse(ASource);
    for lIdx := 0 to lTree.InactiveRegions.Count - 1 do
    begin
      lRange := lTree.InactiveRegions.RegionAt(lIdx).Range;
      if (ALine < lRange.StartPos.Line) or (ALine > lRange.EndPos.Line) then
        Continue;
      if (ALine = lRange.StartPos.Line) and (AColumn < lRange.StartPos.Column) then
        Continue;
      if (ALine = lRange.EndPos.Line) and (AColumn > lRange.EndPos.Column) then
        Continue;
      Exit(True);
    end;
  finally
    lTree.Free;
    lParser.Free;
    lDiagnostics.Free;
  end;
end;

end.
