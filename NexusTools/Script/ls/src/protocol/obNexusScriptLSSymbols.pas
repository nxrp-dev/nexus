unit obNexusScriptLSSymbols;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolParams;

type
  TNexusScriptLSDocumentSymbolRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSDocumentSymbolParams;
    procedure SetParams(AValue: TNXLSDocumentSymbolParams);
    function GetResult: TNXJSONArray;
    procedure SetResult(AValue: TNXJSONArray);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSDocumentSymbolParams read GetParams write SetParams;
    property result: TNXJSONArray read GetResult write SetResult;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolObjects,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptCompiler,
  obNexusScriptAnalysis,
  obNexusScriptLSModel;

procedure SetRange(ADestination: TNXLSRange;
  const ASource: TNexusScriptRange);
begin
  ADestination.start.line.Value := ASource.StartPosition.Line - 1;
  ADestination.start.character.Value := ASource.StartPosition.Column - 1;
  ADestination.&end.line.Value := ASource.EndPosition.Line - 1;
  ADestination.&end.character.Value := ASource.EndPosition.Column;
  ADestination.Assigned := True;
end;

procedure AddDefinitionSymbols(ADefinitions: TNexusScriptSourceDefinitionList;
  AResult: TNXJSONArray);
var
  lDefinition: TNexusScriptSourceDefinition;
  lSymbol: TNXLSDocumentSymbol;
begin
  for lDefinition in ADefinitions do
  begin
    lSymbol := TNXLSDocumentSymbol(AResult.AddObject(TNXLSDocumentSymbol));
    lSymbol.name.Value := lDefinition.Name;
    lSymbol.detail.Value := lDefinition.Kind;
    lSymbol.kind.Value := 19;
    SetRange(lSymbol.range, lDefinition.SourceRange);
    SetRange(lSymbol.selectionRange, lDefinition.NameRange);
    if lDefinition.Children.Count > 0 then
    begin
      lSymbol.children.Assigned := True;
      AddDefinitionSymbols(lDefinition.Children, lSymbol.children);
    end;
  end;
end;

class function TNexusScriptLSDocumentSymbolRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentSymbol';
end;

function TNexusScriptLSDocumentSymbolRequest.Execute: TNXJSONRPCValue;
var
  lAnalysis: TNexusScriptAnalysis;
  lCompiler: TNexusScriptCompiler;
  lResult: TNXJSONArray;
begin
  lResult := TNXJSONArray(PrepareResult);
  lAnalysis := TNexusScriptLSModel.Current.FindAnalysis(
    params.textDocument.uri.Value);
  if lAnalysis <> nil then
  begin
    lCompiler := lAnalysis.EntrySourceCompiler;
    if (lCompiler <> nil) and (lCompiler.SourceDocument <> nil) then
      AddDefinitionSymbols(lCompiler.SourceDocument.Definitions, lResult);
  end;
  Result := lResult;
end;

function TNexusScriptLSDocumentSymbolRequest.GetParams:
  TNXLSDocumentSymbolParams;
begin
  Result := TNXLSDocumentSymbolParams(inherited params);
end;

procedure TNexusScriptLSDocumentSymbolRequest.SetParams(
  AValue: TNXLSDocumentSymbolParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSDocumentSymbolRequest.GetResult: TNXJSONArray;
begin
  Result := TNXJSONArray(inherited result);
end;

procedure TNexusScriptLSDocumentSymbolRequest.SetResult(AValue: TNXJSONArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNexusScriptLSDocumentSymbolRequest);

end.
