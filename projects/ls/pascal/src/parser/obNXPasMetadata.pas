unit obNXPasMetadata;

{$mode objfpc}{$H+}

interface

uses
  Contnrs,
  obNXPasSource;

type
  TNXPasCompilationKind = (
    pckUnknown,
    pckUnit,
    pckProgram,
    pckLibrary,
    pckPackage
  );

  TNXPasUsesSection = (
    pusUnknown,
    pusInterface,
    pusImplementation
  );

  TNXPasUsesEntry = class
  private
    FActive: Boolean;
    FCandidatePath: string;
    FCandidateURI: string;
    FInFileName: string;
    FRange: TNXPasSourceRange;
    FSection: TNXPasUsesSection;
    FUnitName: string;
  public
    property Active: Boolean read FActive write FActive;
    property CandidatePath: string read FCandidatePath write FCandidatePath;
    property CandidateURI: string read FCandidateURI write FCandidateURI;
    property InFileName: string read FInFileName write FInFileName;
    property Range: TNXPasSourceRange read FRange write FRange;
    property Section: TNXPasUsesSection read FSection write FSection;
    property UnitName: string read FUnitName write FUnitName;
  end;

  TNXPasUsesEntryList = class(TObjectList)
  public
    function AddEntry(const AUnitName, AInFileName: string;
      ASection: TNXPasUsesSection; const ARange: TNXPasSourceRange;
      AActive: Boolean): TNXPasUsesEntry;
    function EntryAt(AIndex: Integer): TNXPasUsesEntry;
  end;

  TNXPasDirectiveMetadata = class
  private
    FActive: Boolean;
    FCommand: string;
    FRange: TNXPasSourceRange;
    FValue: string;
  public
    property Active: Boolean read FActive write FActive;
    property Command: string read FCommand write FCommand;
    property Range: TNXPasSourceRange read FRange write FRange;
    property Value: string read FValue write FValue;
  end;

  TNXPasDirectiveMetadataList = class(TObjectList)
  public
    function AddDirective(const ACommand, AValue: string;
      const ARange: TNXPasSourceRange; AActive: Boolean): TNXPasDirectiveMetadata;
    function DirectiveAt(AIndex: Integer): TNXPasDirectiveMetadata;
  end;

  TNXPasDeploymentDependency = class
  private
    FActive: Boolean;
    FRange: TNXPasSourceRange;
    FValue: string;
  public
    property Active: Boolean read FActive write FActive;
    property Range: TNXPasSourceRange read FRange write FRange;
    property Value: string read FValue write FValue;
  end;

  TNXPasDeploymentDependencyList = class(TObjectList)
  public
    function AddDependency(const AValue: string; const ARange: TNXPasSourceRange;
      AActive: Boolean): TNXPasDeploymentDependency;
    function DependencyAt(AIndex: Integer): TNXPasDeploymentDependency;
  end;

  TNXPasUnitMetadata = class
  private
    FActiveDirectives: TNXPasDirectiveMetadataList;
    FCompilationKind: TNXPasCompilationKind;
    FDependencies: TNXPasDeploymentDependencyList;
    FImplementationUses: TNXPasUsesEntryList;
    FIncludeDirectives: TNXPasDirectiveMetadataList;
    FInactiveRegions: TNXPasInactiveRegionList;
    FInterfaceUses: TNXPasUsesEntryList;
    FName: string;
    FSourcePath: string;
    FSourceURI: string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AssignFrom(ASource: TNXPasUnitMetadata);
    procedure Clear;
    function UsesForSection(ASection: TNXPasUsesSection): TNXPasUsesEntryList;

    property ActiveDirectives: TNXPasDirectiveMetadataList read FActiveDirectives;
    property CompilationKind: TNXPasCompilationKind read FCompilationKind write FCompilationKind;
    property Dependencies: TNXPasDeploymentDependencyList read FDependencies;
    property ImplementationUses: TNXPasUsesEntryList read FImplementationUses;
    property IncludeDirectives: TNXPasDirectiveMetadataList read FIncludeDirectives;
    property InactiveRegions: TNXPasInactiveRegionList read FInactiveRegions;
    property InterfaceUses: TNXPasUsesEntryList read FInterfaceUses;
    property Name: string read FName write FName;
    property SourcePath: string read FSourcePath write FSourcePath;
    property SourceURI: string read FSourceURI write FSourceURI;
  end;

  TNXPasDependencyManifestEntry = class
  private
    FDependency: string;
    FRange: TNXPasSourceRange;
    FSourceName: string;
    FSourcePath: string;
    FSourceURI: string;
  public
    property Dependency: string read FDependency write FDependency;
    property Range: TNXPasSourceRange read FRange write FRange;
    property SourceName: string read FSourceName write FSourceName;
    property SourcePath: string read FSourcePath write FSourcePath;
    property SourceURI: string read FSourceURI write FSourceURI;
  end;

  TNXPasDependencyManifest = class(TObjectList)
  public
    function AddEntry(const ADependency, ASourceName, ASourcePath,
      ASourceURI: string; const ARange: TNXPasSourceRange):
      TNXPasDependencyManifestEntry;
    function EntryAt(AIndex: Integer): TNXPasDependencyManifestEntry;
  end;

implementation

uses
  SysUtils;

function TNXPasUsesEntryList.AddEntry(const AUnitName, AInFileName: string;
  ASection: TNXPasUsesSection; const ARange: TNXPasSourceRange;
  AActive: Boolean): TNXPasUsesEntry;
begin
  Result := TNXPasUsesEntry.Create;
  Result.UnitName := AUnitName;
  Result.InFileName := AInFileName;
  Result.Section := ASection;
  Result.Range := ARange;
  Result.Active := AActive;
  Add(Result);
end;

function TNXPasUsesEntryList.EntryAt(AIndex: Integer): TNXPasUsesEntry;
begin
  Result := TNXPasUsesEntry(Items[AIndex]);
end;

function TNXPasDirectiveMetadataList.AddDirective(const ACommand,
  AValue: string; const ARange: TNXPasSourceRange;
  AActive: Boolean): TNXPasDirectiveMetadata;
begin
  Result := TNXPasDirectiveMetadata.Create;
  Result.Command := ACommand;
  Result.Value := AValue;
  Result.Range := ARange;
  Result.Active := AActive;
  Add(Result);
end;

function TNXPasDirectiveMetadataList.DirectiveAt(
  AIndex: Integer): TNXPasDirectiveMetadata;
begin
  Result := TNXPasDirectiveMetadata(Items[AIndex]);
end;

function TNXPasDeploymentDependencyList.AddDependency(const AValue: string;
  const ARange: TNXPasSourceRange; AActive: Boolean): TNXPasDeploymentDependency;
begin
  Result := TNXPasDeploymentDependency.Create;
  Result.Value := AValue;
  Result.Range := ARange;
  Result.Active := AActive;
  Add(Result);
end;

function TNXPasDeploymentDependencyList.DependencyAt(
  AIndex: Integer): TNXPasDeploymentDependency;
begin
  Result := TNXPasDeploymentDependency(Items[AIndex]);
end;

constructor TNXPasUnitMetadata.Create;
begin
  inherited Create;
  FActiveDirectives := TNXPasDirectiveMetadataList.Create(True);
  FDependencies := TNXPasDeploymentDependencyList.Create(True);
  FImplementationUses := TNXPasUsesEntryList.Create(True);
  FIncludeDirectives := TNXPasDirectiveMetadataList.Create(True);
  FInactiveRegions := TNXPasInactiveRegionList.Create(True);
  FInterfaceUses := TNXPasUsesEntryList.Create(True);
end;

destructor TNXPasUnitMetadata.Destroy;
begin
  FreeAndNil(FInterfaceUses);
  FreeAndNil(FInactiveRegions);
  FreeAndNil(FIncludeDirectives);
  FreeAndNil(FImplementationUses);
  FreeAndNil(FDependencies);
  FreeAndNil(FActiveDirectives);
  inherited Destroy;
end;

procedure TNXPasUnitMetadata.Clear;
begin
  FCompilationKind := pckUnknown;
  FName := '';
  FSourcePath := '';
  FSourceURI := '';
  FActiveDirectives.Clear;
  FDependencies.Clear;
  FImplementationUses.Clear;
  FIncludeDirectives.Clear;
  FInactiveRegions.Clear;
  FInterfaceUses.Clear;
end;

procedure TNXPasUnitMetadata.AssignFrom(ASource: TNXPasUnitMetadata);
var
  lDependency: TNXPasDeploymentDependency;
  lDirective: TNXPasDirectiveMetadata;
  lIdx: Integer;
  lUsesEntry: TNXPasUsesEntry;
begin
  Clear;
  if ASource = nil then
    Exit;

  FCompilationKind := ASource.CompilationKind;
  FName := ASource.Name;
  FSourcePath := ASource.SourcePath;
  FSourceURI := ASource.SourceURI;

  for lIdx := 0 to ASource.InterfaceUses.Count - 1 do
  begin
    lUsesEntry := ASource.InterfaceUses.EntryAt(lIdx);
    with FInterfaceUses.AddEntry(lUsesEntry.UnitName, lUsesEntry.InFileName,
      lUsesEntry.Section, lUsesEntry.Range, lUsesEntry.Active) do
    begin
      CandidatePath := lUsesEntry.CandidatePath;
      CandidateURI := lUsesEntry.CandidateURI;
    end;
  end;

  for lIdx := 0 to ASource.ImplementationUses.Count - 1 do
  begin
    lUsesEntry := ASource.ImplementationUses.EntryAt(lIdx);
    with FImplementationUses.AddEntry(lUsesEntry.UnitName,
      lUsesEntry.InFileName, lUsesEntry.Section, lUsesEntry.Range,
      lUsesEntry.Active) do
    begin
      CandidatePath := lUsesEntry.CandidatePath;
      CandidateURI := lUsesEntry.CandidateURI;
    end;
  end;

  for lIdx := 0 to ASource.IncludeDirectives.Count - 1 do
  begin
    lDirective := ASource.IncludeDirectives.DirectiveAt(lIdx);
    FIncludeDirectives.AddDirective(lDirective.Command, lDirective.Value,
      lDirective.Range, lDirective.Active);
  end;

  for lIdx := 0 to ASource.ActiveDirectives.Count - 1 do
  begin
    lDirective := ASource.ActiveDirectives.DirectiveAt(lIdx);
    FActiveDirectives.AddDirective(lDirective.Command, lDirective.Value,
      lDirective.Range, lDirective.Active);
  end;

  for lIdx := 0 to ASource.Dependencies.Count - 1 do
  begin
    lDependency := ASource.Dependencies.DependencyAt(lIdx);
    FDependencies.AddDependency(lDependency.Value, lDependency.Range,
      lDependency.Active);
  end;

  for lIdx := 0 to ASource.InactiveRegions.Count - 1 do
    FInactiveRegions.AddRegion(ASource.InactiveRegions.RegionAt(lIdx).Range);
end;

function TNXPasUnitMetadata.UsesForSection(
  ASection: TNXPasUsesSection): TNXPasUsesEntryList;
begin
  if ASection = pusImplementation then
    Result := FImplementationUses
  else
    Result := FInterfaceUses;
end;

function TNXPasDependencyManifest.AddEntry(const ADependency, ASourceName,
  ASourcePath, ASourceURI: string; const ARange: TNXPasSourceRange):
  TNXPasDependencyManifestEntry;
begin
  Result := TNXPasDependencyManifestEntry.Create;
  Result.Dependency := ADependency;
  Result.SourceName := ASourceName;
  Result.SourcePath := ASourcePath;
  Result.SourceURI := ASourceURI;
  Result.Range := ARange;
  Add(Result);
end;

function TNXPasDependencyManifest.EntryAt(
  AIndex: Integer): TNXPasDependencyManifestEntry;
begin
  Result := TNXPasDependencyManifestEntry(Items[AIndex]);
end;

end.
