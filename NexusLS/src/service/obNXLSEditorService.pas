unit obNXLSEditorService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSEditorService = class(TNXLSLSPService)
  public
    function CodeAction(AParams: TNXLSCodeActionParams): TNXJSONValue; virtual;
    function DocumentHighlight(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function Hover(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function InlayHint(AParams: TNXLSInlayHintParams): TNXJSONValue; virtual;
  end;

implementation

uses
  SysUtils,
  fpjson,
  BasicCodeTools,
  CodeCache,
  CodeToolManager,
  obNXLSProtocolObjects,
  utNXLSServiceHelpers;

procedure NXLSSetHoverJSONString(AValue: TNXJSONValue; AData: TJSONData);
begin
  try
    AValue.FromJSONData(AData);
  finally
    AData.Free;
  end;
end;

function NXLSFindDeclarationLine(ACode: TCodeBuffer; const AIdentifier: string): string;
var
  lIdx: Integer;
  lName: string;
begin
  Result := '';
  if (ACode = nil) or (AIdentifier = '') then
    Exit;

  for lIdx := 0 to ACode.LineCount - 1 do
  begin
    lName := NXLSIdentifierAfterKeyword(ACode.GetLine(lIdx), 'procedure');
    if CompareText(lName, AIdentifier) = 0 then
      Exit(Trim(ACode.GetLine(lIdx)));

    lName := NXLSIdentifierAfterKeyword(ACode.GetLine(lIdx), 'function');
    if CompareText(lName, AIdentifier) = 0 then
      Exit(Trim(ACode.GetLine(lIdx)));
  end;
end;

function TNXLSEditorService.CodeAction(AParams: TNXLSCodeActionParams): TNXJSONValue;
begin
  Result := TNXLSCodeActionArrayResult.CreateValue;
end;

function TNXLSEditorService.DocumentHighlight(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lNewCode: TCodeBuffer;
  lNewX: Integer;
  lNewY: Integer;
  lNewTopLine: Integer;
  lHighlight: TNXLSDocumentHighlight;
begin
  Result := TNXLSDocumentHighlightArrayResult.CreateValue;
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

  if CodeToolBoss.FindBlockCounterPart(lCode,
    AParams.position.character.Value + 1, AParams.position.line.Value + 1,
    lNewCode, lNewX, lNewY, lNewTopLine) then
  begin
    if lNewY - (AParams.position.line.Value + 1) <> 0 then
    begin
      lHighlight := TNXLSDocumentHighlight(
        TNXJSONArray(Result).AddObject(TNXLSDocumentHighlight));
      lHighlight.kind.Value := 1;
      NXLSSetIdentifierRange(lHighlight.range, lNewCode, lNewX, lNewY - 1);
      lHighlight.Assigned := True;

      lHighlight := TNXLSDocumentHighlight(
        TNXJSONArray(Result).AddObject(TNXLSDocumentHighlight));
      lHighlight.kind.Value := 1;
      NXLSSetIdentifierRange(lHighlight.range, lCode,
        AParams.position.character.Value + 1, AParams.position.line.Value);
      lHighlight.Assigned := True;
    end;
  end;
end;

function TNXLSEditorService.Hover(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lDeclCode: TCodeBuffer;
  lHint: string;
  lLine: string;
  lIdentStart: Integer;
  lIdentEnd: Integer;
  lDeclX: Integer;
  lDeclY: Integer;
  lTopLine: Integer;
  lBlockTopLine: Integer;
  lBlockBottomLine: Integer;
  lMarkup: TJSONObject;
  lHover: TNXLSHover;
  lIdentifier: string;
  lUsedDeclCode: TCodeBuffer;
begin
  Result := TNXLSHoverResult.CreateValue;
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

  try
    lHint := CodeToolBoss.FindSmartHint(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value + 1);
  except
    on E: Exception do
      lHint := '';
  end;

  if lHint = '' then
  begin
    if CodeToolBoss.FindMainDeclaration(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value + 1,
      lDeclCode, lDeclX, lDeclY, lTopLine) then
      lHint := Trim(lDeclCode.GetLine(lDeclY - 1));
  end;

  if lHint = '' then
  begin
    if CodeToolBoss.FindDeclaration(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value + 1,
      lDeclCode, lDeclX, lDeclY, lTopLine, lBlockTopLine, lBlockBottomLine) then
      lHint := Trim(lDeclCode.GetLine(lDeclY - 1));
  end;

  if lHint = '' then
  begin
    lIdentifier := NXLSIdentifierNear(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value);
    if NXLSFindTypeDeclaration(lCode, lIdentifier, lDeclX, lDeclY) then
      lHint := Trim(lCode.GetLine(lDeclY - 1));
  end;

  if lHint = '' then
  begin
    lIdentifier := NXLSIdentifierNear(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value);
    if NXLSFindRoutineDeclarationInUses(lCode, lIdentifier, lUsedDeclCode,
      lDeclX, lDeclY) then
      lHint := Trim(lUsedDeclCode.GetLine(lDeclY - 1));
  end;

  if lHint = '' then
  begin
    lIdentifier := NXLSIdentifierNear(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value);
    lHint := NXLSFindDeclarationLine(lCode, lIdentifier);
  end;

  if lHint = '' then
    Exit;

  Result.Free;
  lHover := TNXLSHover.Create;
  Result := lHover;

  lMarkup := TJSONObject.Create;
  lMarkup.Add('kind', 'markdown');
  lMarkup.Add('value', '```pascal' + LineEnding + lHint + LineEnding + '```');
  NXLSSetHoverJSONString(lHover.contents, lMarkup);

  if (AParams.position.line.Value >= 0) and
    (AParams.position.line.Value < lCode.LineCount) then
  begin
    lLine := lCode.GetLine(AParams.position.line.Value);
    GetIdentStartEndAtPosition(lLine, AParams.position.character.Value + 1,
      lIdentStart, lIdentEnd);
    NXLSSetRange(lHover.range, AParams.position.line.Value, lIdentStart - 1,
      AParams.position.line.Value, lIdentEnd - 1);
  end;
  lHover.Assigned := True;
end;

function TNXLSEditorService.InlayHint(AParams: TNXLSInlayHintParams): TNXJSONValue;
begin
  Result := TNXLSInlayHintArrayResult.CreateValue;
end;

end.
