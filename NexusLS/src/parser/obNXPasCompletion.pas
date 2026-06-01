unit obNXPasCompletion;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXPasSource;

type
  TNXPasCompletionHelper = class
  private
    class function PositionInRange(ALine, AColumn: Integer;
      const ARange: TNXPasSourceRange): Boolean; static;
    class function TokenStartsAfterPosition(ALine, AColumn: Integer;
      const ARange: TNXPasSourceRange): Boolean; static;
    class function TokenEndsAtOrBeforePosition(ALine, AColumn: Integer;
      const ARange: TNXPasSourceRange): Boolean; static;
  public
    class function CompletionPrefixAtPosition(ASource: TNXPasSourceFile;
      ALine, AColumn: Integer; out APrefix: string): Boolean; static;
    class function CompletionSuppressedAtPosition(ASource: TNXPasSourceFile;
      ALine, AColumn: Integer): Boolean; static;
    class procedure AddKeywordCompletions(AKeywords: TStrings); static;
  end;

implementation

uses
  SysUtils,
  obNXPasLexer,
  obNXPasSignatures,
  tpNXPasTokens;

class function TNXPasCompletionHelper.PositionInRange(ALine, AColumn: Integer;
  const ARange: TNXPasSourceRange): Boolean;
begin
  Result := False;
  if ALine < ARange.StartPos.Line then
    Exit;
  if ALine > ARange.EndPos.Line then
    Exit;
  if (ALine = ARange.StartPos.Line) and (AColumn < ARange.StartPos.Column) then
    Exit;
  if (ALine = ARange.EndPos.Line) and (AColumn > ARange.EndPos.Column) then
    Exit;
  Result := True;
end;

class function TNXPasCompletionHelper.TokenStartsAfterPosition(ALine,
  AColumn: Integer; const ARange: TNXPasSourceRange): Boolean;
begin
  Result := (ARange.StartPos.Line > ALine) or
    ((ARange.StartPos.Line = ALine) and (ARange.StartPos.Column > AColumn));
end;

class function TNXPasCompletionHelper.TokenEndsAtOrBeforePosition(ALine,
  AColumn: Integer; const ARange: TNXPasSourceRange): Boolean;
begin
  Result := (ARange.EndPos.Line < ALine) or
    ((ARange.EndPos.Line = ALine) and (ARange.EndPos.Column <= AColumn));
end;

class function TNXPasCompletionHelper.CompletionPrefixAtPosition(
  ASource: TNXPasSourceFile; ALine, AColumn: Integer;
  out APrefix: string): Boolean;
var
  lRange: TNXPasSourceRange;
  lLexer: TNXPasLexer;
  lPrevSignificant: TNXPasToken;
  lToken: TNXPasToken;
begin
  Result := False;
  APrefix := '';
  if ASource = nil then
    Exit;

  if CompletionSuppressedAtPosition(ASource, ALine, AColumn) then
    Exit;

  lLexer := TNXPasLexer.Create(ASource.Text);
  try
    lPrevSignificant.Kind := ptkUnknown;
    lPrevSignificant.Text := '';
    repeat
      lToken := lLexer.NextToken;
      lRange := ASource.RangeFromPositions(lToken.StartPos, lToken.EndPos);
      if (lToken.Kind = ptkIdentifier) and
        PositionInRange(ALine, AColumn, lRange) then
      begin
        if (lPrevSignificant.Kind = ptkSymbol) and
          (lPrevSignificant.Text = '.') then
          Exit;
        APrefix := Copy(lToken.Text, 1, AColumn - lToken.StartPos.Column);
        Exit(True);
      end;

      if (lToken.Kind = ptkIdentifier) and
        (lToken.EndPos.Line = ALine) and (lToken.EndPos.Column = AColumn) then
      begin
        if (lPrevSignificant.Kind = ptkSymbol) and
          (lPrevSignificant.Text = '.') then
          Exit;
        APrefix := lToken.Text;
        Exit(True);
      end;

      if (lToken.Kind = ptkSymbol) and (lToken.Text = '.') and
        TokenEndsAtOrBeforePosition(ALine, AColumn, lRange) then
        lPrevSignificant := lToken
      else if not (lToken.Kind in [ptkWhitespace, ptkComment, ptkDirective]) and
        TokenEndsAtOrBeforePosition(ALine, AColumn, lRange) then
        lPrevSignificant := lToken;

      if TokenStartsAfterPosition(ALine, AColumn, lRange) then
        Break;
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;

  if (lPrevSignificant.Kind = ptkSymbol) and (lPrevSignificant.Text = '.') then
    Exit;

  Result := True;
end;

class function TNXPasCompletionHelper.CompletionSuppressedAtPosition(
  ASource: TNXPasSourceFile; ALine, AColumn: Integer): Boolean;
var
  lRange: TNXPasSourceRange;
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  Result := False;
  if ASource = nil then
    Exit;

  if TNXPasSignatureHelper.PositionIsInactive(ASource, ALine, AColumn) then
    Exit(True);

  lLexer := TNXPasLexer.Create(ASource.Text);
  try
    repeat
      lToken := lLexer.NextToken;
      lRange := ASource.RangeFromPositions(lToken.StartPos, lToken.EndPos);
      if (lToken.Kind in [ptkComment, ptkString]) and
        PositionInRange(ALine, AColumn, lRange) then
        Exit(True);

      if TokenStartsAfterPosition(ALine, AColumn, lRange) then
        Break;
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;
end;

class procedure TNXPasCompletionHelper.AddKeywordCompletions(
  AKeywords: TStrings);
begin
  if AKeywords = nil then
    Exit;

  AKeywords.Add('unit');
  AKeywords.Add('interface');
  AKeywords.Add('implementation');
  AKeywords.Add('uses');
  AKeywords.Add('type');
  AKeywords.Add('const');
  AKeywords.Add('var');
  AKeywords.Add('procedure');
  AKeywords.Add('function');
  AKeywords.Add('class');
  AKeywords.Add('record');
  AKeywords.Add('object');
  AKeywords.Add('begin');
  AKeywords.Add('end');
  AKeywords.Add('private');
  AKeywords.Add('protected');
  AKeywords.Add('public');
  AKeywords.Add('published');
end;

end.
