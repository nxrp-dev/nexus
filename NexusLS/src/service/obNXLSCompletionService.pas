unit obNXLSCompletionService;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext,
  obNXPasSignatures,
  obNXPasSymbols,
  obNXPasWorkspaceIndex;

type
  TNXLSCompletionService = class(TNXLSLSPService)
  private
    FWorkspaceIndex: TNXPasWorkspaceIndex;
    procedure AddCompletionItem(AResult: TNXLSCompletionItemArray;
      const ALabel: string; AKind: Integer; const ADetail: string;
      ASeen: TStrings);
    procedure AddSignatureResult(AResult: TNXLSSignatureHelp;
      ASignature: TNXPasRoutineSignature);
    procedure FillKeywordCompletions(AResult: TNXLSCompletionItemArray;
      const APrefix: string; ASeen: TStrings);
    procedure FillSymbolCompletions(AResult: TNXLSCompletionItemArray;
      const APrefix: string; ASeen: TStrings);
    procedure FindSignatureCandidates(const AName, AURI: string;
      AResults: TNXPasRoutineSignatureList);
    function SymbolCompletionKind(AKind: TNXPasSymbolKind): Integer;
  public
    constructor Create(AModel: TNXLSLSPContext); override;
    destructor Destroy; override;
    procedure FillCompletionItems(AParams: TNXLSCompletionParams;
      AResult: TNXLSCompletionItemArray); virtual;
    function FillSignatureHelp(AParams: TNXLSSignatureHelpParams;
      AResult: TNXLSSignatureHelp): Boolean; virtual;
    procedure RebuildWorkspaceIndex;
    procedure ReindexDocument(ADocument: TNXLSDocument);
  end;

implementation

uses
  SysUtils,
  obNXPasCompletion,
  obNXPasSource;

constructor TNXLSCompletionService.Create(AModel: TNXLSLSPContext);
begin
  inherited Create(AModel);
  FWorkspaceIndex := TNXPasWorkspaceIndex.Create;
end;

destructor TNXLSCompletionService.Destroy;
begin
  FreeAndNil(FWorkspaceIndex);
  inherited Destroy;
end;

procedure TNXLSCompletionService.FillCompletionItems(AParams: TNXLSCompletionParams;
  AResult: TNXLSCompletionItemArray);
var
  lDocument: TNXLSDocument;
  lPrefix: string;
  lSeen: TStringList;
  lSource: TNXPasSourceFile;
begin
  if AResult = nil then
    Exit;

  AResult.Assigned := True;
  if (AParams = nil) or (AParams.textDocument = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lSeen := TStringList.Create;
  lSource := TNXPasSourceFile.Create(lDocument.LocalPath, lDocument.URI,
    lDocument.Text);
  try
    lSeen.CaseSensitive := False;
    lSeen.Sorted := True;
    lSeen.Duplicates := dupIgnore;
    if not TNXPasCompletionHelper.CompletionPrefixAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value,
      lPrefix) then
      Exit;

    FillSymbolCompletions(AResult, lPrefix, lSeen);
    FillKeywordCompletions(AResult, lPrefix, lSeen);
  finally
    lSource.Free;
    lSeen.Free;
  end;
end;

function TNXLSCompletionService.FillSignatureHelp(
  AParams: TNXLSSignatureHelpParams; AResult: TNXLSSignatureHelp): Boolean;
var
  lCall: TNXPasCallContext;
  lDocument: TNXLSDocument;
  lIdx: Integer;
  lSignatures: TNXPasRoutineSignatureList;
  lSource: TNXPasSourceFile;
begin
  Result := False;
  if (AParams = nil) or (AParams.textDocument = nil) or (AResult = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lCall := TNXPasCallContext.Create;
  lSignatures := TNXPasRoutineSignatureList.Create(True);
  lSource := TNXPasSourceFile.Create(lDocument.LocalPath, lDocument.URI,
    lDocument.Text);
  try
    if TNXPasSignatureHelper.PositionIsInactive(lSource,
      AParams.position.line.Value, AParams.position.character.Value) then
      Exit;

    if not TNXPasSignatureHelper.FindCallAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value, lCall) then
      Exit;

    FindSignatureCandidates(lCall.Name, lDocument.URI, lSignatures);
    if lSignatures.Count = 0 then
      Exit;

    AResult.signatures.Assigned := True;
    for lIdx := 0 to lSignatures.Count - 1 do
      AddSignatureResult(AResult, lSignatures.SignatureAt(lIdx));
    AResult.activeSignature.Value := 0;
    AResult.activeParameter.Value := lCall.ActiveParameter;
    AResult.Assigned := True;
    Result := True;
  finally
    lSource.Free;
    lSignatures.Free;
    lCall.Free;
  end;
end;

procedure TNXLSCompletionService.AddSignatureResult(AResult: TNXLSSignatureHelp;
  ASignature: TNXPasRoutineSignature);
var
  lIdx: Integer;
  lParam: TNXLSParameterInformation;
  lSignature: TNXLSSignatureInformation;
begin
  if (AResult = nil) or (ASignature = nil) then
    Exit;

  lSignature := TNXLSSignatureInformation(
    AResult.signatures.AddObject(TNXLSSignatureInformation));
  lSignature.&label.Value := ASignature.&Label;
  lSignature.parameters.Assigned := True;
  for lIdx := 0 to ASignature.Parameters.Count - 1 do
  begin
    lParam := TNXLSParameterInformation(
      lSignature.parameters.AddObject(TNXLSParameterInformation));
    lParam.&label.StringValue :=
      ASignature.Parameters.ParameterAt(lIdx).&Label;
    lParam.Assigned := True;
  end;
  lSignature.Assigned := True;
end;

procedure TNXLSCompletionService.AddCompletionItem(
  AResult: TNXLSCompletionItemArray; const ALabel: string; AKind: Integer;
  const ADetail: string; ASeen: TStrings);
var
  lItem: TNXLSCompletionItem;
begin
  if (AResult = nil) or (Trim(ALabel) = '') then
    Exit;

  if (ASeen <> nil) and (ASeen.IndexOf(ALabel) >= 0) then
    Exit;

  if ASeen <> nil then
    ASeen.Add(ALabel);

  lItem := TNXLSCompletionItem(AResult.AddObject(TNXLSCompletionItem));
  lItem.&label.Value := ALabel;
  if AKind > 0 then
    lItem.kind.Value := AKind;
  if ADetail <> '' then
    lItem.detail.Value := ADetail;
  lItem.Assigned := True;
end;

procedure TNXLSCompletionService.FillKeywordCompletions(
  AResult: TNXLSCompletionItemArray; const APrefix: string; ASeen: TStrings);
var
  lIdx: Integer;
  lKeywords: TStringList;
begin
  lKeywords := TStringList.Create;
  try
    TNXPasCompletionHelper.AddKeywordCompletions(lKeywords);
    for lIdx := 0 to lKeywords.Count - 1 do
      if (APrefix = '') or
        (Pos(UpperCase(APrefix), UpperCase(lKeywords[lIdx])) = 1) then
        AddCompletionItem(AResult, lKeywords[lIdx], 14, 'keyword', ASeen);
  finally
    lKeywords.Free;
  end;
end;

procedure TNXLSCompletionService.FillSymbolCompletions(
  AResult: TNXLSCompletionItemArray; const APrefix: string; ASeen: TStrings);
var
  lIdx: Integer;
  lMatches: TNXPasWorkspaceSymbolMatchList;
  lMatch: TNXPasWorkspaceSymbolMatch;
begin
  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    FWorkspaceIndex.QuerySymbols('', lMatches);
    for lIdx := 0 to lMatches.Count - 1 do
    begin
      lMatch := lMatches.MatchAt(lIdx);
      if (lMatch.Symbol = nil) or
        (lMatch.Symbol.Kind in [pskUnknown, pskUsesUnit, pskVisibility]) then
        Continue;
      if (APrefix <> '') and
        (Pos(UpperCase(APrefix), UpperCase(lMatch.Symbol.Name)) <> 1) then
        Continue;

      AddCompletionItem(AResult, lMatch.Symbol.Name,
        SymbolCompletionKind(lMatch.Symbol.Kind),
        NXPasSymbolKindName(lMatch.Symbol.Kind), ASeen);
    end;
  finally
    lMatches.Free;
  end;
end;

procedure TNXLSCompletionService.FindSignatureCandidates(const AName,
  AURI: string; AResults: TNXPasRoutineSignatureList);
var
  lIdx: Integer;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lMatches: TNXPasWorkspaceSymbolMatchList;
  lSignature: TNXPasRoutineSignature;
begin
  if (AResults = nil) or (Trim(AName) = '') then
    Exit;

  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    FWorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
    for lIdx := 0 to lMatches.Count - 1 do
    begin
      lMatch := lMatches.MatchAt(lIdx);
      if (lMatch.Symbol = nil) or (lMatch.Symbol.Kind <> pskRoutine) then
        Continue;

      lSignature := AResults.AddSignature;
      if not TNXPasSignatureHelper.ExtractSignature(lMatch.FileRef,
        lMatch.Symbol, lSignature) then
        AResults.Remove(lSignature);
    end;
  finally
    lMatches.Free;
  end;
end;

function TNXLSCompletionService.SymbolCompletionKind(
  AKind: TNXPasSymbolKind): Integer;
begin
  case AKind of
    pskUnit:
      Result := 9;
    pskType:
      Result := 7;
    pskClass,
    pskObject:
      Result := 7;
    pskRecord:
      Result := 22;
    pskInterface:
      Result := 8;
    pskRoutine:
      Result := 3;
    pskConst:
      Result := 21;
    pskVariable:
      Result := 6;
    pskField:
      Result := 5;
    pskParameter:
      Result := 6;
    pskProperty:
      Result := 10;
  else
    Result := 1;
  end;
end;

procedure TNXLSCompletionService.RebuildWorkspaceIndex;
var
  lIdx: Integer;
begin
  FWorkspaceIndex.Clear;
  for lIdx := 0 to Model.DocumentCount - 1 do
    ReindexDocument(Model.DocumentByIndex(lIdx));
end;

procedure TNXLSCompletionService.ReindexDocument(ADocument: TNXLSDocument);
var
  lSource: TNXPasSourceFile;
begin
  if ADocument = nil then
    Exit;

  lSource := TNXPasSourceFile.Create(ADocument.LocalPath, ADocument.URI,
    ADocument.Text);
  try
    FWorkspaceIndex.UpdateSourceFile(lSource);
  finally
    lSource.Free;
  end;
end;

end.
