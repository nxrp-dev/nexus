unit obNXPasRoutineIdentity;

{$mode objfpc}{$H+}

interface

uses
  obNXPasSymbols;

function NXPasRoutineNormalizedTypeText(const AText: string): string;
function NXPasRoutineOwnerName(ASymbol: TNXPasSymbol): string;
function NXPasRoutineSimpleName(ASymbol: TNXPasSymbol): string;
function NXPasRoutineParameterSignature(ASymbol: TNXPasSymbol): string;
function NXPasRoutineIdentity(ASymbol: TNXPasSymbol): string;

implementation

uses
  SysUtils;

function NXPasRoutineNormalizedTypeText(const AText: string): string;
begin
  Result := StringReplace(UpperCase(Trim(AText)), ' ', '', [rfReplaceAll]);
end;

function NXPasRoutineOwnerName(ASymbol: TNXPasSymbol): string;
var
  lDotPos: Integer;
begin
  Result := '';
  if ASymbol = nil then
    Exit;

  lDotPos := LastDelimiter('.', ASymbol.Name);
  if lDotPos > 0 then
    Exit(Copy(ASymbol.Name, 1, lDotPos - 1));

  if (ASymbol.Parent <> nil) and (ASymbol.Parent.Kind in [pskClass,
    pskRecord, pskObject, pskInterface]) then
    Result := ASymbol.Parent.Name;
end;

function NXPasRoutineSimpleName(ASymbol: TNXPasSymbol): string;
var
  lDotPos: Integer;
begin
  Result := '';
  if ASymbol = nil then
    Exit;

  lDotPos := LastDelimiter('.', ASymbol.Name);
  if lDotPos > 0 then
    Result := Copy(ASymbol.Name, lDotPos + 1, MaxInt)
  else
    Result := ASymbol.Name;
end;

function NXPasRoutineParameterSignature(ASymbol: TNXPasSymbol): string;
var
  lChild: TNXPasSymbol;
  lIdx: Integer;
begin
  Result := '';
  if ASymbol = nil then
    Exit;

  for lIdx := 0 to ASymbol.ChildCount - 1 do
  begin
    lChild := ASymbol.Children[lIdx];
    if lChild.Kind <> pskParameter then
      Continue;

    if Result <> '' then
      Result := Result + ';';
    Result := Result + NXPasRoutineNormalizedTypeText(lChild.DeclaredTypeText);
  end;
end;

function NXPasRoutineIdentity(ASymbol: TNXPasSymbol): string;
begin
  Result := '';
  if (ASymbol = nil) or (ASymbol.Kind <> pskRoutine) then
    Exit;

  Result := UpperCase(NXPasRoutineOwnerName(ASymbol)) + '|' +
    UpperCase(NXPasRoutineSimpleName(ASymbol)) + '|' +
    NXPasRoutineParameterSignature(ASymbol);
end;

end.
