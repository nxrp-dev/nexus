unit obNexusScriptSession;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptCompiler;

type
  TNexusScriptCompilationSession = class
  private
    FCompilers: TStringList;
    FActiveFiles: TStringList;
    FEntryCompiler: TNexusScriptCompiler;
    FLastError: string;
    function CompileDocument(const AFileName: string): TNexusScriptCompiler;
    function ResolveDependencyPath(const ASourceName,
      ADeclaredPath: string): string;
    function SelectDefinition(ACompiler: TNexusScriptCompiler;
      const ASelector: string): TNexusScriptCompiledDefinition;
    function GetCompilerCount: Integer;
    function GetCompiler(AIndex: Integer): TNexusScriptCompiler;
  public
    constructor Create;
    destructor Destroy; override;
    function CompileFile(const AFileName: string): Boolean;
    property EntryCompiler: TNexusScriptCompiler read FEntryCompiler;
    function FindCompiler(const AFileName: string): TNexusScriptCompiler;
    property CompilerCount: Integer read GetCompilerCount;
    property Compilers[AIndex: Integer]: TNexusScriptCompiler read GetCompiler;
    property LastError: string read FLastError;
  end;

implementation

constructor TNexusScriptCompilationSession.Create;
begin
  inherited Create;
  FCompilers := TStringList.Create;
  FCompilers.CaseSensitive := False;
  FCompilers.Sorted := True;
  FCompilers.Duplicates := dupError;
  FActiveFiles := TStringList.Create;
  FActiveFiles.CaseSensitive := False;
end;

destructor TNexusScriptCompilationSession.Destroy;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FCompilers.Count - 1 do
    FCompilers.Objects[lIndex].Free;
  FActiveFiles.Free;
  FCompilers.Free;
  inherited Destroy;
end;

function TNexusScriptCompilationSession.ResolveDependencyPath(
  const ASourceName, ADeclaredPath: string): string;
begin
  Result := ExpandFileName(IncludeTrailingPathDelimiter(
    ExtractFileDir(ASourceName)) + ADeclaredPath);
end;

function TNexusScriptCompilationSession.SelectDefinition(
  ACompiler: TNexusScriptCompiler;
  const ASelector: string): TNexusScriptCompiledDefinition;
begin
  Result := nil;
  if ACompiler.CompiledDocument = nil then
    Exit;
  Result := ACompiler.CompiledDocument.FindDefinition(ASelector);
end;

function TNexusScriptCompilationSession.CompileDocument(
  const AFileName: string): TNexusScriptCompiler;
var
  lCanonicalName: string;
  lIndex: Integer;
  lCompiler: TNexusScriptCompiler;
  lModule: TNexusScriptSourceModule;
  lImportedCompiler: TNexusScriptCompiler;
  lImportedDefinition: TNexusScriptCompiledDefinition;
  lImportedName: string;
  lDoctype: TNexusScriptSourceDoctype;
  lDoctypeCompiler: TNexusScriptCompiler;
  lDoctypeSourceName: string;
  lDeclaredDoctypePath: string;
  lDoctypeRange: TNexusScriptRange;
  lInclude: TNexusScriptSourceInclude;
  lIncludedCompiler: TNexusScriptCompiler;
  lIncludedName: string;
begin
  Result := nil;
  lCanonicalName := ExpandFileName(AFileName);
  lIndex := FCompilers.IndexOf(lCanonicalName);
  if lIndex >= 0 then
    Exit(TNexusScriptCompiler(FCompilers.Objects[lIndex]));
  if FActiveFiles.IndexOf(lCanonicalName) >= 0 then
  begin
    FLastError := 'Document dependency cycle at ' + lCanonicalName;
    Exit;
  end;
  if not FileExists(lCanonicalName) then
  begin
    FLastError := 'Document file not found: ' + lCanonicalName;
    Exit;
  end;
  FActiveFiles.Add(lCanonicalName);
  lCompiler := TNexusScriptCompiler.Create;
  try
    lCompiler.CompileFile(lCanonicalName);
    lCompiler.ClearImports;
    lDoctype := lCompiler.SourceDocument.Doctype;
    lDoctypeCompiler := nil;
    lDoctypeSourceName := '';
    lDeclaredDoctypePath := '';
    if lDoctype <> nil then
    begin
      lDeclaredDoctypePath := lDoctype.Path;
      lDoctypeRange := lDoctype.SourceRange;
      lDoctypeSourceName := ResolveDependencyPath(lCanonicalName,
        lDeclaredDoctypePath);
      lDoctypeCompiler := CompileDocument(lDoctypeSourceName);
      if lDoctypeCompiler = nil then
      begin
        FLastError := 'Unable to load doctype for ' + lCanonicalName +
          ': ' + FLastError;
        Exit;
      end;
    end;
    for lModule in lCompiler.SourceDocument.Modules do
    begin
      lImportedName := ResolveDependencyPath(lCanonicalName, lModule.Path);
      lImportedCompiler := CompileDocument(lImportedName);
      if lImportedCompiler = nil then
        Exit;
      if lModule.RootSelector = '' then
        lCompiler.AddImportedDocument(lImportedCompiler.CompiledDocument)
      else
      begin
        lImportedDefinition := SelectDefinition(lImportedCompiler,
          lModule.RootSelector);
        if lImportedDefinition = nil then
        begin
          FLastError := 'Module root selector not found: ' +
            lModule.RootSelector + ' in ' + lImportedName;
          Exit;
        end;
        lCompiler.AddImportedDefinition(lImportedDefinition);
      end;
    end;
    for lInclude in lCompiler.SourceDocument.Includes do
    begin
      lIncludedName := ResolveDependencyPath(lCanonicalName, lInclude.Path);
      lIncludedCompiler := CompileDocument(lIncludedName);
      if lIncludedCompiler = nil then
      begin
        FLastError := 'Unable to load include ' + lInclude.Path + ' for ' +
          lCanonicalName + ': ' + FLastError;
        Exit;
      end;
    end;
    if not lCompiler.CompileFile(lCanonicalName) then
    begin
      FLastError := 'Compilation failed: ' + lCanonicalName;
      if lCompiler.Diagnostics.Count > 0 then
        FLastError := FLastError + ': ' +
          lCompiler.Diagnostics[0].MessageText;
      Exit;
    end;
    if lDeclaredDoctypePath <> '' then
      lCompiler.CompiledDocument.SetDoctype(lDeclaredDoctypePath,
        lDoctypeSourceName, lDoctypeRange,
        lDoctypeCompiler.CompiledDocument);
    FCompilers.AddObject(lCanonicalName, lCompiler);
    Result := lCompiler;
    lCompiler := nil;
  finally
    FActiveFiles.Delete(FActiveFiles.IndexOf(lCanonicalName));
    lCompiler.Free;
  end;
end;

function TNexusScriptCompilationSession.CompileFile(
  const AFileName: string): Boolean;
begin
  FLastError := '';
  FEntryCompiler := nil;
  FEntryCompiler := CompileDocument(AFileName);
  Result := FEntryCompiler <> nil;
end;

function TNexusScriptCompilationSession.GetCompilerCount: Integer;
begin
  Result := FCompilers.Count;
end;

function TNexusScriptCompilationSession.GetCompiler(
  AIndex: Integer): TNexusScriptCompiler;
begin
  Result := TNexusScriptCompiler(FCompilers.Objects[AIndex]);
end;

function TNexusScriptCompilationSession.FindCompiler(
  const AFileName: string): TNexusScriptCompiler;
var
  lIndex: Integer;
begin
  Result := nil;
  lIndex := FCompilers.IndexOf(ExpandFileName(AFileName));
  if lIndex >= 0 then
    Result := TNexusScriptCompiler(FCompilers.Objects[lIndex]);
end;

end.
