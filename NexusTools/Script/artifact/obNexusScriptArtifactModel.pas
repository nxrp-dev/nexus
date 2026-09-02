unit obNexusScriptArtifactModel;

{$mode delphi}{$H+}

interface

uses
  Generics.Collections,
  tpNexusScript,
  obNexusScriptModel;

type
  TNexusScriptArtifactValueKind = (
    nsavInvalid,
    nsavText,
    nsavArray,
    nsavDefinition
  );

  TNexusScriptCompiledValueArtifactHelper = class helper for TNexusScriptCompiledValue
  private
    function GetArtifactKind: TNexusScriptArtifactValueKind;
    function GetArtifactValue: TNexusScriptCompiledValue;
  public
    property ArtifactKind: TNexusScriptArtifactValueKind read GetArtifactKind;
    property ArtifactValue: TNexusScriptCompiledValue read GetArtifactValue;
  end;

  TNexusScriptExternalSource = class
  private
    FName: string;
    FDeclaredPath: string;
    FFileName: string;
    FSourceType: string;
    FDeclaringDocument: string;
    FSourceRange: TNexusScriptRange;
  public
    constructor Create(const AName, ADeclaredPath, AFileName,
      ASourceType, ADeclaringDocument: string;
      const ASourceRange: TNexusScriptRange);
    property Name: string read FName;
    property DeclaredPath: string read FDeclaredPath;
    property FileName: string read FFileName;
    property SourceType: string read FSourceType;
    property DeclaringDocument: string read FDeclaringDocument;
    property SourceRange: TNexusScriptRange read FSourceRange;
  end;

  TNexusScriptExternalSourceList = TObjectList<TNexusScriptExternalSource>;

  TNexusScriptArtifactDocument = class
  private
    FSourceDocument: TNexusScriptSourceDocument;
    FCompiledDocument: TNexusScriptCompiledDocument;
  public
    constructor Create(ASourceDocument: TNexusScriptSourceDocument;
      ACompiledDocument: TNexusScriptCompiledDocument);
    property SourceDocument: TNexusScriptSourceDocument read FSourceDocument;
    property CompiledDocument: TNexusScriptCompiledDocument
      read FCompiledDocument;
  end;

  TNexusScriptArtifactDocumentList = TObjectList<TNexusScriptArtifactDocument>;

implementation

function TNexusScriptCompiledValueArtifactHelper.GetArtifactValue:
  TNexusScriptCompiledValue;
begin
  Result := Self;
  while Result.EffectiveValue <> nil do
    Result := Result.EffectiveValue;
end;

function TNexusScriptCompiledValueArtifactHelper.GetArtifactKind:
  TNexusScriptArtifactValueKind;
var
  lValue: TNexusScriptCompiledValue;
begin
  lValue := GetArtifactValue;
  if lValue.StructuralDefinition <> nil then
    Result := nsavDefinition
  else if lValue.Kind = nsvArray then
    Result := nsavArray
  else if lValue.HasEffectiveText then
    Result := nsavText
  else
    Result := nsavInvalid;
end;

constructor TNexusScriptExternalSource.Create(const AName, ADeclaredPath,
  AFileName, ASourceType, ADeclaringDocument: string;
  const ASourceRange: TNexusScriptRange);
begin
  inherited Create;
  FName := AName;
  FDeclaredPath := ADeclaredPath;
  FFileName := AFileName;
  FSourceType := ASourceType;
  FDeclaringDocument := ADeclaringDocument;
  FSourceRange := ASourceRange;
end;

constructor TNexusScriptArtifactDocument.Create(
  ASourceDocument: TNexusScriptSourceDocument;
  ACompiledDocument: TNexusScriptCompiledDocument);
begin
  inherited Create;
  FSourceDocument := ASourceDocument;
  FCompiledDocument := ACompiledDocument;
end;

end.
