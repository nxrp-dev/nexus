unit obNXTaskResolver;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, obNXTaskModel, obNXTaskParser,
  obNXTaskValidation, tpNXTask;

type
  TNXTaskResolver = class
  private
    FDocuments: TStringList;
    FReportedDocuments: TStringList;
    FDiagnostics: TNXTaskDiagnostics;
    FValidator: TNXTaskValidator;
    function LoadParsedDocument(const AFileName: string): TNXTaskDocument;
    function ResolveExternalFile(const ABaseFile, AExternalFile: string): string;
    function RangeForReference(AReference: TNXTaskReference): TNXTaskSourceRange;
    function ReferenceIdentity(AReference: TNXTaskReference;
      AKind: TNXTaskReferenceKind): string;
    function FormatCycleChain(AStack: TStringList; const AIdentity: string): string;
    function FindNodeByPath(ADocument: TNXTaskDocument; const APath: string): TNXTaskNode;
    function FindProperty(AValueReference: TNXTaskReference): TNXTaskProperty;
    procedure MergeDiagnostics(ADocument: TNXTaskDocument);
    function ExpandNode(ANode: TNXTaskNode; AStack: TStringList): TNXTaskNode;
    procedure ResolveNodeValues(ANode: TNXTaskNode; AStack: TStringList);
    function ResolveValue(AValue: TNXTaskValue; AStack: TStringList): TNXTaskValue;
    function CloneExpandedNode(AReference: TNXTaskReference; AStack: TStringList): TNXTaskNode;
    procedure AddExpandedBody(ATarget, AExpanded: TNXTaskNode);
  public
    constructor Create;
    destructor Destroy; override;
    function MaterializeFile(const AFileName: string): TNXTaskDocument;
    property Diagnostics: TNXTaskDiagnostics read FDiagnostics;
  end;

implementation

constructor TNXTaskResolver.Create;
begin
  inherited Create;
  FDocuments := TStringList.Create;
  FDocuments.CaseSensitive := False;
  FDocuments.OwnsObjects := True;
  FReportedDocuments := TStringList.Create;
  FReportedDocuments.CaseSensitive := False;
  FDiagnostics := TNXTaskDiagnostics.Create;
  FValidator := TNXTaskValidator.Create;
end;

destructor TNXTaskResolver.Destroy;
begin
  FValidator.Free;
  FDiagnostics.Free;
  FReportedDocuments.Free;
  FDocuments.Free;
  inherited Destroy;
end;

function TNXTaskResolver.ResolveExternalFile(const ABaseFile, AExternalFile: string): string;
begin
  if ExtractFileDrive(AExternalFile) <> '' then
    Result := ExpandFileName(AExternalFile)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(ExtractFileDir(ABaseFile)) +
      AExternalFile);
end;

function TNXTaskResolver.RangeForReference(
  AReference: TNXTaskReference): TNXTaskSourceRange;
begin
  if AReference.SourceRange <> nil then
    Result := TNXTaskSourceRange.Create(AReference.SourceRange.FileName,
      AReference.SourceRange.Line, AReference.SourceRange.Column)
  else
    Result := TNXTaskSourceRange.Create(AReference.DeclarationFile, 1, 1);
end;

function TNXTaskResolver.ReferenceIdentity(AReference: TNXTaskReference;
  AKind: TNXTaskReferenceKind): string;
var
  lFileName: string;
begin
  if AReference.ExternalFile <> '' then
    lFileName := ResolveExternalFile(AReference.DeclarationFile,
      AReference.ExternalFile)
  else
    lFileName := ExpandFileName(AReference.DeclarationFile);

  if AKind = trkValue then
    Result := Format('value:%s:%s.%s',
      [lFileName, AReference.Path, AReference.PropertyName])
  else
    Result := Format('node:%s:%s', [lFileName, AReference.Path]);
end;

function TNXTaskResolver.FormatCycleChain(AStack: TStringList;
  const AIdentity: string): string;
var
  lIndex: Integer;
  lStartIndex: Integer;
begin
  Result := '';
  lStartIndex := AStack.IndexOf(AIdentity);
  if lStartIndex < 0 then
    lStartIndex := 0;

  for lIndex := lStartIndex to AStack.Count - 1 do
  begin
    if Result <> '' then
      Result := Result + ' -> ';
    Result := Result + AStack[lIndex];
  end;

  if Result <> '' then
    Result := Result + ' -> ';
  Result := Result + AIdentity;
end;

procedure TNXTaskResolver.MergeDiagnostics(ADocument: TNXTaskDocument);
var
  lIndex: Integer;
  lDiagnostic: TNXTaskDiagnostic;
begin
  for lIndex := 0 to ADocument.Diagnostics.Count - 1 do
  begin
    lDiagnostic := ADocument.Diagnostics.Item(lIndex);
    FDiagnostics.Add(lDiagnostic.Severity, lDiagnostic.Code, lDiagnostic.Message,
      TNXTaskSourceRange.Create(lDiagnostic.Range.FileName, lDiagnostic.Range.Line,
        lDiagnostic.Range.Column));
  end;
end;

function TNXTaskResolver.LoadParsedDocument(const AFileName: string): TNXTaskDocument;
var
  lFileName: string;
  lIndex: Integer;
  lParser: TNXTaskParser;
begin
  lFileName := ExpandFileName(AFileName);
  lIndex := FDocuments.IndexOf(lFileName);
  if lIndex >= 0 then
  begin
    Result := TNXTaskDocument(FDocuments.Objects[lIndex]);
    if FReportedDocuments.IndexOf(lFileName) < 0 then
    begin
      MergeDiagnostics(Result);
      FReportedDocuments.Add(lFileName);
    end;
    Exit;
  end;

  if not FileExists(lFileName) then
  begin
    Result := TNXTaskDocument.Create(lFileName);
    Result.Diagnostics.Add(tdsError, 'NXTask.Load.FileNotFound',
      'NexusTask file was not found: ' + lFileName,
      TNXTaskSourceRange.Create(lFileName, 1, 1));
    FDocuments.AddObject(lFileName, Result);
    MergeDiagnostics(Result);
    FReportedDocuments.Add(lFileName);
    Exit;
  end;

  lParser := TNXTaskParser.Create;
  try
    Result := lParser.ParseFile(lFileName);
    FValidator.ValidateDocument(Result);
    FDocuments.AddObject(lFileName, Result);
    MergeDiagnostics(Result);
    FReportedDocuments.Add(lFileName);
  finally
    lParser.Free;
  end;
end;

function TNXTaskResolver.FindNodeByPath(ADocument: TNXTaskDocument;
  const APath: string): TNXTaskNode;
var
  lParts: TStringList;
  lIndex: Integer;
begin
  Result := nil;
  lParts := TStringList.Create;
  try
    lParts.Delimiter := '.';
    lParts.StrictDelimiter := True;
    lParts.DelimitedText := APath;
    if lParts.Count = 0 then
      Exit;
    Result := ADocument.RootByName(lParts[0]);
    for lIndex := 1 to lParts.Count - 1 do
    begin
      if Result = nil then
        Exit;
      Result := Result.ChildByName(lParts[lIndex]);
    end;
  finally
    lParts.Free;
  end;
end;

function TNXTaskResolver.FindProperty(AValueReference: TNXTaskReference): TNXTaskProperty;
var
  lFileName: string;
  lDocument: TNXTaskDocument;
  lNode: TNXTaskNode;
begin
  if AValueReference.ExternalFile <> '' then
    lFileName := ResolveExternalFile(AValueReference.DeclarationFile,
      AValueReference.ExternalFile)
  else
    lFileName := AValueReference.DeclarationFile;

  lDocument := LoadParsedDocument(lFileName);
  lNode := FindNodeByPath(lDocument, AValueReference.Path);
  if lNode = nil then
  begin
    FDiagnostics.Add(tdsError, 'NXTask.Resolve.MissingNode',
      'Referenced node was not found: ' + AValueReference.Path,
      RangeForReference(AValueReference));
    Exit(nil);
  end;
  Result := lNode.PropertyByName(AValueReference.PropertyName);
  if Result = nil then
    FDiagnostics.Add(tdsError, 'NXTask.Resolve.MissingProperty',
      'Referenced property was not found: ' + AValueReference.Path + '.' +
      AValueReference.PropertyName,
      RangeForReference(AValueReference));
end;

function TNXTaskResolver.CloneExpandedNode(AReference: TNXTaskReference;
  AStack: TStringList): TNXTaskNode;
var
  lFileName: string;
  lDocument: TNXTaskDocument;
  lNode: TNXTaskNode;
  lIdentity: string;
begin
  Result := nil;
  if AReference.ExternalFile <> '' then
    lFileName := ResolveExternalFile(AReference.DeclarationFile, AReference.ExternalFile)
  else
    lFileName := AReference.DeclarationFile;
  lIdentity := ReferenceIdentity(AReference, trkNode);
  if AStack.IndexOf(lIdentity) >= 0 then
  begin
    FDiagnostics.Add(tdsError, 'NXTask.Resolve.NodeCycle',
      'Circular node expansion: ' + FormatCycleChain(AStack, lIdentity),
      TNXTaskSourceRange.Create(AReference.SourceRange.FileName,
        AReference.SourceRange.Line, AReference.SourceRange.Column));
    Exit;
  end;
  AStack.Add(lIdentity);
  lDocument := LoadParsedDocument(lFileName);
  lNode := FindNodeByPath(lDocument, AReference.Path);
  if lNode = nil then
  begin
    FDiagnostics.Add(tdsError, 'NXTask.Resolve.MissingNode',
      'Referenced node was not found: ' + AReference.Path,
      RangeForReference(AReference));
    AStack.Delete(AStack.Count - 1);
    Exit;
  end;
  Result := ExpandNode(lNode, AStack);
  Result.ExpansionSite := AReference.DeclarationFile;
  AStack.Delete(AStack.Count - 1);
end;

procedure TNXTaskResolver.AddExpandedBody(ATarget, AExpanded: TNXTaskNode);
var
  lIndex: Integer;
  lBodyItem: TNXTaskBodyItem;
begin
  for lIndex := 0 to AExpanded.BodyItems.Count - 1 do
  begin
    lBodyItem := TNXTaskBodyItem(AExpanded.BodyItems[lIndex]);
    case lBodyItem.Kind of
      tbikProperty:
        ATarget.AddProperty(TNXTaskProperty(lBodyItem.Item).Clone);
      tbikChild:
        ATarget.AddChild(TNXTaskNode(lBodyItem.Item).CloneShallow);
    end;
  end;
end;

function TNXTaskResolver.ExpandNode(ANode: TNXTaskNode;
  AStack: TStringList): TNXTaskNode;
var
  lIndex: Integer;
  lBodyItem: TNXTaskBodyItem;
  lChild: TNXTaskNode;
  lExpansion: TNXTaskNodeReference;
  lExpanded: TNXTaskNode;
begin
  Result := ANode.CloneShallow;
  Result.ClearBody;

  for lIndex := 0 to ANode.BodyItems.Count - 1 do
  begin
    lBodyItem := TNXTaskBodyItem(ANode.BodyItems[lIndex]);
    case lBodyItem.Kind of
      tbikProperty:
        Result.AddProperty(TNXTaskProperty(lBodyItem.Item).Clone);
      tbikChild:
        begin
          lChild := ExpandNode(TNXTaskNode(lBodyItem.Item), AStack);
          Result.AddChild(lChild);
        end;
      tbikExpansion:
        begin
          lExpansion := TNXTaskNodeReference(lBodyItem.Item);
          lExpanded := CloneExpandedNode(lExpansion.Reference, AStack);
          if lExpanded <> nil then
          begin
            AddExpandedBody(Result, lExpanded);
            lExpanded.Free;
          end;
        end;
    end;
  end;
end;

function TNXTaskResolver.ResolveValue(AValue: TNXTaskValue;
  AStack: TStringList): TNXTaskValue;
var
  lReference: TNXTaskReference;
  lIdentity: string;
  lProperty: TNXTaskProperty;
begin
  if AValue.Kind <> tvkReference then
    Exit(AValue.Clone);

  lReference := AValue.Reference;
  lIdentity := ReferenceIdentity(lReference, trkValue);
  if AStack.IndexOf(lIdentity) >= 0 then
  begin
    FDiagnostics.Add(tdsError, 'NXTask.Resolve.ValueCycle',
      'Circular scalar reference: ' + FormatCycleChain(AStack, lIdentity),
      TNXTaskSourceRange.Create(lReference.SourceRange.FileName,
        lReference.SourceRange.Line, lReference.SourceRange.Column));
    Exit(nil);
  end;
  AStack.Add(lIdentity);
  lProperty := FindProperty(lReference);
  if lProperty <> nil then
    Result := ResolveValue(lProperty.Value, AStack)
  else
    Result := nil;
  AStack.Delete(AStack.Count - 1);
end;

procedure TNXTaskResolver.ResolveNodeValues(ANode: TNXTaskNode;
  AStack: TStringList);
var
  lIndex: Integer;
  lProperty: TNXTaskProperty;
  lValue: TNXTaskValue;
begin
  for lIndex := 0 to ANode.Properties.Count - 1 do
  begin
    lProperty := TNXTaskProperty(ANode.Properties[lIndex]);
    lValue := ResolveValue(lProperty.Value, AStack);
    if lValue <> nil then
    begin
      lProperty.Value.Free;
      lProperty.Value := lValue;
    end;
  end;
  for lIndex := 0 to ANode.Children.Count - 1 do
    ResolveNodeValues(TNXTaskNode(ANode.Children[lIndex]), AStack);
end;

function TNXTaskResolver.MaterializeFile(const AFileName: string): TNXTaskDocument;
var
  lParsed: TNXTaskDocument;
  lIndex: Integer;
  lStack: TStringList;
begin
  FDiagnostics.Clear;
  FReportedDocuments.Clear;
  lParsed := LoadParsedDocument(AFileName);
  Result := TNXTaskDocument.Create(lParsed.FileName);

  lStack := TStringList.Create;
  try
    lStack.CaseSensitive := True;
    for lIndex := 0 to lParsed.Roots.Count - 1 do
      Result.Roots.Add(ExpandNode(TNXTaskNode(lParsed.Roots[lIndex]), lStack));
    FValidator.ValidateDocument(Result);
    MergeDiagnostics(Result);
    lStack.Clear;
    for lIndex := 0 to Result.Roots.Count - 1 do
      ResolveNodeValues(TNXTaskNode(Result.Roots[lIndex]), lStack);
  finally
    lStack.Free;
  end;
end;

end.
