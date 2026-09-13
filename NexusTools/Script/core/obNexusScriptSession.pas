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
    FDialectRoot: string;
    FSelectedTargets: TNexusScriptTargetSelection;
    FCompilers: TStringList;
    FActiveFiles: TStringList;
    FEntryCompiler: TNexusScriptCompiler;
    FLastError: string;
    function CompileDocument(const AFileName: string): TNexusScriptCompiler;
    function ExpandPatterns(ADocument: TNexusScriptSourceDocument): Boolean;
    function SelectMatchingFiles(const ASourceName, APattern: string;
      ARecursive: Boolean): TStringList;
    function ResolveDependencyPath(const ASourceName,
      ADeclaredPath: string): string;
    function ResolveDialectPath(const ASourceName,
      ADeclaredPath: string): string;
    function SelectDefinition(ACompiler: TNexusScriptCompiler;
      const ASelector: string): TNexusScriptCompiledDefinition;
    function GetCompilerCount: Integer;
    function GetCompiler(AIndex: Integer): TNexusScriptCompiler;
  public
    constructor Create(ASelectedTargets: TNexusScriptTargetSelection = nil);
    destructor Destroy; override;
    function CompileFile(const AFileName: string): Boolean;
    property EntryCompiler: TNexusScriptCompiler read FEntryCompiler;
    function FindCompiler(const AFileName: string): TNexusScriptCompiler;
    property CompilerCount: Integer read GetCompilerCount;
    property Compilers[AIndex: Integer]: TNexusScriptCompiler read GetCompiler;
    property DialectRoot: string read FDialectRoot write FDialectRoot;
    property LastError: string read FLastError;
  end;

implementation

constructor TNexusScriptCompilationSession.Create(
  ASelectedTargets: TNexusScriptTargetSelection);
begin
  inherited Create;
  FSelectedTargets := TNexusScriptTargetSelection.Create;
  FSelectedTargets.Assign(ASelectedTargets);
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
  FSelectedTargets.Free;
  inherited Destroy;
end;

function TNexusScriptCompilationSession.ResolveDependencyPath(
  const ASourceName, ADeclaredPath: string): string;
begin
  if (ExtractFileDrive(ADeclaredPath) <> '') or
    ((ADeclaredPath <> '') and IsPathDelimiter(ADeclaredPath, 1)) then
    Result := ExpandFileName(ADeclaredPath)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(
      ExtractFileDir(ASourceName)) + ADeclaredPath);
end;

function TNexusScriptCompilationSession.ResolveDialectPath(
  const ASourceName, ADeclaredPath: string): string;
var
  lLocalName: string;
begin
  lLocalName := ResolveDependencyPath(ASourceName, ADeclaredPath);
  if FileExists(lLocalName) or (FDialectRoot = '') or
    (ExtractFileDrive(ADeclaredPath) <> '') or
    ((ADeclaredPath <> '') and IsPathDelimiter(ADeclaredPath, 1)) then
    Exit(lLocalName);
  Result := ExpandFileName(IncludeTrailingPathDelimiter(FDialectRoot) +
    ADeclaredPath);
end;

function TNexusScriptCompilationSession.SelectMatchingFiles(
  const ASourceName, APattern: string;
  ARecursive: Boolean): TStringList;
var
  lFolderName: string;
  lDeclaredFolder: string;
  lFileNamePattern: string;

  procedure SelectFromFolder(const AFolderName: string);
  var
    lSearch: TSearchRec;
    lFileName: string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(AFolderName) + lFileNamePattern,
      faAnyFile, lSearch) = 0 then
    try
      repeat
        if (lSearch.Attr and faDirectory) = 0 then
        begin
          lFileName := ExpandFileName(IncludeTrailingPathDelimiter(
            AFolderName) + lSearch.Name);
          if not SameFileName(lFileName, ASourceName) then
            Result.Add(lFileName);
        end;
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
    if not ARecursive then
      Exit;
    if FindFirst(IncludeTrailingPathDelimiter(AFolderName) + '*',
      faDirectory, lSearch) = 0 then
    try
      repeat
        if ((lSearch.Attr and faDirectory) <> 0) and
          (lSearch.Name <> '.') and (lSearch.Name <> '..') then
          SelectFromFolder(IncludeTrailingPathDelimiter(AFolderName) +
            lSearch.Name);
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;

begin
  Result := TStringList.Create;
  lDeclaredFolder := ExtractFileDir(APattern);
  if lDeclaredFolder = '' then
    lDeclaredFolder := '.';
  lFileNamePattern := ExtractFileName(APattern);
  lFolderName := ResolveDependencyPath(ASourceName, lDeclaredFolder);
  if not DirectoryExists(lFolderName) then
  begin
    FLastError := 'Unable to select files for ' + ASourceName +
      ': folder not found: ' + lDeclaredFolder;
    FreeAndNil(Result);
    Exit;
  end;
  try
    SelectFromFolder(lFolderName);
  except
    on E: Exception do
    begin
      FLastError := 'Unable to select files in ' + lDeclaredFolder +
        ' for ' + ASourceName + ': ' + E.Message;
      FreeAndNil(Result);
    end;
  end;
end;

function TNexusScriptCompilationSession.ExpandPatterns(
  ADocument: TNexusScriptSourceDocument): Boolean;
var
  lIndex: Integer;
  lPathIndex: Integer;
  lPaths: TStringList;
  lModule: TNexusScriptSourceModule;
  lInclude: TNexusScriptSourceInclude;
  lNewModule: TNexusScriptSourceModule;
  lNewInclude: TNexusScriptSourceInclude;
  lRange: TNexusScriptRange;
begin
  Result := False;
  lIndex := 0;
  while lIndex < ADocument.Modules.Count do
  begin
    lModule := ADocument.Modules[lIndex];
    if not lModule.Recursive and (Pos('*', lModule.Path) = 0) and
      (Pos('?', lModule.Path) = 0) then
    begin
      Inc(lIndex);
      Continue;
    end;
    lPaths := SelectMatchingFiles(ADocument.SourceName, lModule.Path,
      lModule.Recursive);
    if lPaths = nil then
      Exit;
    try
      lRange := lModule.SourceRange;
      ADocument.Modules.Delete(lIndex);
      for lPathIndex := 0 to lPaths.Count - 1 do
      begin
        lNewModule := TNexusScriptSourceModule.Create;
        lNewModule.Path := lPaths[lPathIndex];
        lNewModule.SourceRange := lRange;
        ADocument.Modules.Insert(lIndex, lNewModule);
        Inc(lIndex);
      end;
    finally
      lPaths.Free;
    end;
  end;
  lIndex := 0;
  while lIndex < ADocument.Includes.Count do
  begin
    lInclude := ADocument.Includes[lIndex];
    if not lInclude.Recursive and (Pos('*', lInclude.Path) = 0) and
      (Pos('?', lInclude.Path) = 0) then
    begin
      Inc(lIndex);
      Continue;
    end;
    lPaths := SelectMatchingFiles(ADocument.SourceName, lInclude.Path,
      lInclude.Recursive);
    if lPaths = nil then
      Exit;
    try
      lRange := lInclude.SourceRange;
      ADocument.Includes.Delete(lIndex);
      for lPathIndex := 0 to lPaths.Count - 1 do
      begin
        lNewInclude := TNexusScriptSourceInclude.Create;
        lNewInclude.Path := lPaths[lPathIndex];
        lNewInclude.SourceRange := lRange;
        ADocument.Includes.Insert(lIndex, lNewInclude);
        Inc(lIndex);
      end;
    finally
      lPaths.Free;
    end;
  end;
  Result := True;
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
  lDialect: TNexusScriptSourceDialect;
  lDialectCompiler: TNexusScriptCompiler;
  lDialectSourceName: string;
  lDeclaredDialectPath: string;
  lDialectRange: TNexusScriptRange;
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
  lCompiler := TNexusScriptCompiler.Create(FSelectedTargets);
  try
    lCompiler.CompileFile(lCanonicalName);
    lCompiler.ClearImports;
    if not ExpandPatterns(lCompiler.SourceDocument) then
      Exit;
    lDialect := lCompiler.SourceDocument.Dialect;
    lDialectCompiler := nil;
    lDialectSourceName := '';
    lDeclaredDialectPath := '';
    if lDialect <> nil then
    begin
      lDeclaredDialectPath := lDialect.Path;
      lDialectRange := lDialect.SourceRange;
      lDialectSourceName := ResolveDialectPath(lCanonicalName,
        lDeclaredDialectPath);
      lDialectCompiler := CompileDocument(lDialectSourceName);
      if lDialectCompiler = nil then
      begin
        FLastError := 'Unable to load dialect for ' + lCanonicalName +
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
    if not ExpandPatterns(lCompiler.SourceDocument) then
      Exit;
    if lDeclaredDialectPath <> '' then
      lCompiler.CompiledDocument.SetDialect(lDeclaredDialectPath,
        lDialectSourceName, lDialectRange,
        lDialectCompiler.CompiledDocument);
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
