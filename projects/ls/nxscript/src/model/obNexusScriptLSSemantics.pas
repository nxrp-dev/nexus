unit obNexusScriptLSSemantics;

{$mode delphi}{$H+}

interface

uses
  tpNexusScript,
  obNexusScriptModel;

function NXScriptRangeContains(const ARange: TNexusScriptRange;
  ALine, AColumn: Integer): Boolean;
function NXScriptFindValueAt(ADocument: TNexusScriptCompiledDocument;
  ALine, AColumn: Integer): TNexusScriptCompiledValue;
function NXScriptFindDefinitionAt(ADocument: TNexusScriptCompiledDocument;
  ALine, AColumn: Integer): TNexusScriptCompiledDefinition;

implementation

function NXScriptRangeContains(const ARange: TNexusScriptRange;
  ALine, AColumn: Integer): Boolean;
begin
  Result := ((ALine > ARange.StartPosition.Line) or
    ((ALine = ARange.StartPosition.Line) and
    (AColumn >= ARange.StartPosition.Column))) and
    ((ALine < ARange.EndPosition.Line) or
    ((ALine = ARange.EndPosition.Line) and
    (AColumn <= ARange.EndPosition.Column)));
end;

function FindDefinition(ADefinition: TNexusScriptCompiledDefinition;
  const ASourceName: string; ALine, AColumn: Integer; AValueOnly: Boolean;
  out AValue: TNexusScriptCompiledValue): TNexusScriptCompiledDefinition;
  forward;

function FindValue(AValue: TNexusScriptCompiledValue;
  const ASourceName: string; ALine, AColumn: Integer): TNexusScriptCompiledValue;
var
  lItem: TNexusScriptCompiledValue;
  lRange: TNexusScriptRange;
begin
  Result := nil;
  for lRange in AValue.ReferenceRanges do
    if (lRange.SourceName = ASourceName) and
      NXScriptRangeContains(lRange, ALine, AColumn) then
      Exit(AValue);
  for lItem in AValue.Items do
  begin
    Result := FindValue(lItem, ASourceName, ALine, AColumn);
    if Result <> nil then
      Exit;
  end;
  if AValue.StructuralDefinition <> nil then
    FindDefinition(AValue.StructuralDefinition, ASourceName, ALine,
      AColumn, True, Result);
end;

function FindDefinition(ADefinition: TNexusScriptCompiledDefinition;
  const ASourceName: string; ALine, AColumn: Integer; AValueOnly: Boolean;
  out AValue: TNexusScriptCompiledValue): TNexusScriptCompiledDefinition;
var
  lProperty: TNexusScriptCompiledProperty;
  lChild: TNexusScriptCompiledDefinition;
begin
  Result := nil;
  AValue := nil;
  for lProperty in ADefinition.Properties do
  begin
    AValue := FindValue(lProperty.Value, ASourceName, ALine, AColumn);
    if AValue <> nil then
      Exit(ADefinition);
  end;
  for lChild in ADefinition.Children do
  begin
    Result := FindDefinition(lChild, ASourceName, ALine, AColumn,
      AValueOnly, AValue);
    if (Result <> nil) or (AValue <> nil) then
      Exit;
  end;
  if not AValueOnly and (ADefinition.SourceRange.SourceName = ASourceName) and
    NXScriptRangeContains(ADefinition.SourceRange,
    ALine, AColumn) then
    Result := ADefinition;
end;

function NXScriptFindValueAt(ADocument: TNexusScriptCompiledDocument;
  ALine, AColumn: Integer): TNexusScriptCompiledValue;
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  Result := nil;
  if ADocument = nil then
    Exit;
  for lDefinition in ADocument.Definitions do
  begin
    FindDefinition(lDefinition, ADocument.SourceName, ALine, AColumn, True,
      Result);
    if Result <> nil then
      Exit;
  end;
end;

function NXScriptFindDefinitionAt(ADocument: TNexusScriptCompiledDocument;
  ALine, AColumn: Integer): TNexusScriptCompiledDefinition;
var
  lDefinition: TNexusScriptCompiledDefinition;
  lValue: TNexusScriptCompiledValue;
begin
  Result := nil;
  if ADocument = nil then
    Exit;
  for lDefinition in ADocument.Definitions do
  begin
    Result := FindDefinition(lDefinition, ADocument.SourceName, ALine,
      AColumn, False, lValue);
    if Result <> nil then
      Exit;
  end;
end;

end.
