unit obNexusSchemaTokenizer;

{$mode delphi}{$H+}

interface

uses
  obNexusSchemaTypes,
  obTokenQueue;

type
  TNexusSchemaTokenDefinition = record
    Operators: TNexusSchemaCharSet;
    Keywords: TNexusSchemaKeywords;
  end;

function DefaultNexusSchemaTokenDefinition: TNexusSchemaTokenDefinition;
function TokenizeNexusSchemaModule(AModule: PChar): TTokenQueue; overload;
function TokenizeNexusSchemaModule(AModule: PChar;
  const ADefinition: TNexusSchemaTokenDefinition): TTokenQueue; overload;

implementation

uses
  SysUtils;

procedure AdvanceSource(var ACurrentPtr: PChar; var ALine, AColumn: integer);
begin
  if ACurrentPtr^ = #13 then
  begin
    Inc(ACurrentPtr);
    if ACurrentPtr^ = #10 then
      Inc(ACurrentPtr);
    Inc(ALine);
    AColumn := 1;
  end
  else if ACurrentPtr^ = #10 then
  begin
    Inc(ACurrentPtr);
    Inc(ALine);
    AColumn := 1;
  end
  else
  begin
    Inc(ACurrentPtr);
    Inc(AColumn);
  end;
end;

function DefaultNexusSchemaTokenDefinition: TNexusSchemaTokenDefinition;
begin
  Result.Operators := cOperators;
  Result.Keywords := cKeywords;
end;

function IsKeyword(const AToken: string; const ADefinition: TNexusSchemaTokenDefinition): boolean;
var
  lIdx: integer;
begin
  Result := False;
  for lIdx := Low(ADefinition.Keywords) to High(ADefinition.Keywords) do
  begin
    if SameText(ADefinition.Keywords[lIdx], AToken) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function GetUntilChar(var ACurrentPtr: PChar; var ALine, AColumn: integer; ATerminator: char; AIgnoreLineTerminator: boolean): string;
var
  lDone: boolean;
begin
  Result := '';

  AdvanceSource(ACurrentPtr, ALine, AColumn);
  lDone := False;

  while not lDone do
  begin
    if ((not AIgnoreLineTerminator) and (ACurrentPtr^ in cLineTerminators)) or (ACurrentPtr^ in cTerminators) then
      raise Exception.Create('Unterminated string or reference detected.');

    if ACurrentPtr^ = ATerminator then
    begin
      AdvanceSource(ACurrentPtr, ALine, AColumn);
      if ACurrentPtr^ = ATerminator then
      begin
        Result := Result + ACurrentPtr^;
        AdvanceSource(ACurrentPtr, ALine, AColumn);
      end
      else
      begin
        Dec(ACurrentPtr);
        Dec(AColumn);
        lDone := True;
      end;
    end
    else
    begin
      Result := Result + ACurrentPtr^;
      AdvanceSource(ACurrentPtr, ALine, AColumn);
    end;
  end;
  AdvanceSource(ACurrentPtr, ALine, AColumn);
end;

function GetUntilSequence(var ACurrentPtr: PChar; var ALine, AColumn: integer; const ATerminator: string; AIgnoreLineTerminator: boolean): string;
var
  lTermLength: integer;
  lTermIdx: integer;
begin
  Result := ACurrentPtr^;
  AdvanceSource(ACurrentPtr, ALine, AColumn);
  lTermIdx := 1;
  lTermLength := Length(ATerminator);
  while lTermIdx <= lTermLength do
  begin
    while not (ACurrentPtr^ = ATerminator[lTermIdx]) do
    begin
      if ((not AIgnoreLineTerminator) and (ACurrentPtr^ in cLineTerminators)) or (ACurrentPtr^ in cTerminators) then
        raise Exception.Create('Unterminated string or reference detected.');

      Result := Result + ACurrentPtr^;
      AdvanceSource(ACurrentPtr, ALine, AColumn);
    end;
    if ACurrentPtr^ = ATerminator[lTermIdx] then
    begin
      Result := Result + ACurrentPtr^;
      AdvanceSource(ACurrentPtr, ALine, AColumn);
      Inc(lTermIdx);
    end
    else
      lTermIdx := 1;
  end;
end;

function GetUntilLineTerminator(var ACurrentPtr: PChar; var ALine, AColumn: integer): string;
begin
  Result := ACurrentPtr^;
  AdvanceSource(ACurrentPtr, ALine, AColumn);
  while not (ACurrentPtr^ in cLineTerminators) and not (ACurrentPtr^ in cTerminators) do
  begin
    Result := Result + ACurrentPtr^;
    AdvanceSource(ACurrentPtr, ALine, AColumn);
  end;
  if ACurrentPtr^ in cLineTerminators then
  begin
    Result := Result + #10;
    AdvanceSource(ACurrentPtr, ALine, AColumn);
  end;
end;

function GetNextToken(var ACurrentPtr: PChar; var ALine, AColumn: integer; const ADefinition: TNexusSchemaTokenDefinition): TToken;
var
  lStartLine: integer;
  lStartColumn: integer;
begin
  Result := TToken.Create;
  Result.Text := '';
  Result.TokenType := ttNone;
  Result.Line := ALine;
  Result.Column := AColumn;

  while (ACurrentPtr^ in cWhiteSpace) and not (ACurrentPtr^ in cLineTerminators) do
    AdvanceSource(ACurrentPtr, ALine, AColumn);

  lStartLine := ALine;
  lStartColumn := AColumn;
  Result.Line := lStartLine;
  Result.Column := lStartColumn;

  if ACurrentPtr^ in cLineTerminators then
  begin
    AdvanceSource(ACurrentPtr, ALine, AColumn);
    Result.Text := ';';
    Result.TokenType := ttOperator;
  end
  else if ACurrentPtr^ = '"' then
  begin
    Result.Text := GetUntilChar(ACurrentPtr, ALine, AColumn, '"', False);
    Result.TokenType := ttString;
  end
  else if ACurrentPtr^ = '<' then
  begin
    Result.Text := GetUntilChar(ACurrentPtr, ALine, AColumn, '>', False);
    Result.TokenType := ttString;
  end
  else if ACurrentPtr^ = '/' then
  begin
    Result.Text := Result.Text + ACurrentPtr^;
    AdvanceSource(ACurrentPtr, ALine, AColumn);
    case ACurrentPtr^ of
      '*': Result.Text := Result.Text + GetUntilSequence(ACurrentPtr, ALine, AColumn, '*/', True);
      '/': Result.Text := Result.Text + GetUntilLineTerminator(ACurrentPtr, ALine, AColumn);
    end;
    Result.TokenType := ttComment;
  end
  else
  begin
    if ACurrentPtr^ in ADefinition.Operators then
    begin
      Result.Text := ACurrentPtr^;
      Result.TokenType := ttOperator;
      AdvanceSource(ACurrentPtr, ALine, AColumn);
    end
    else
    begin
      while not (ACurrentPtr^ in cWhiteSpace) and not (ACurrentPtr^ in cTerminators) and not (ACurrentPtr^ in ADefinition.Operators) do
      begin
        Result.Text := Result.Text + ACurrentPtr^;
        AdvanceSource(ACurrentPtr, ALine, AColumn);
      end;
      if IsKeyword(Result.Text, ADefinition) then
        Result.TokenType := ttKeyword
      else
        Result.TokenType := ttIdentifier;
    end;
  end;
end;

function TokenizeNexusSchemaModule(AModule: PChar): TTokenQueue;
begin
  Result := TokenizeNexusSchemaModule(AModule, DefaultNexusSchemaTokenDefinition);
end;

function TokenizeNexusSchemaModule(AModule: PChar;
  const ADefinition: TNexusSchemaTokenDefinition): TTokenQueue;
var
  lpCurrent: PChar;
  lToken: TToken;
  lLine: integer;
  lColumn: integer;
begin
  Result := TTokenQueue.Create;
  lpCurrent := AModule;
  lLine := 1;
  lColumn := 1;
  lToken := GetNextToken(lpCurrent, lLine, lColumn, ADefinition);
  lToken.Position := lpCurrent - (AModule + Length(lToken.Text));

  while lToken.Text <> '' do
  begin
    Result.Push(lToken);
    lToken := GetNextToken(lpCurrent, lLine, lColumn, ADefinition);
    lToken.Position := lpCurrent - (AModule + Length(lToken.Text));
  end;
  lToken.Free;
end;

end.
