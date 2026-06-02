unit obNXPasSearchPaths;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXPersist;

type
  TNXPasSearchPathKind = (
    pspkUnitPath,
    pspkIncludePath,
    pspkSourcePath,
    pspkOutputPath
  );

  TNXPasSearchPathTemplate = class(TNXPersistObject)
  private
    FEnabled: Boolean;
    FPathKind: TNXPasSearchPathKind;
    FPathTemplate: string;
    FTargetCPU: string;
    FTargetOS: string;
  public
    constructor Create; override;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property TargetOS: string read FTargetOS write FTargetOS;
    property PathKind: TNXPasSearchPathKind read FPathKind write FPathKind;
    property PathTemplate: string read FPathTemplate write FPathTemplate;
  end;

  TNXPasSearchPathTemplateList = class(TNXPersistList)
  protected
    function GetItemClass: TNXPersistClass; override;
  public
    function AddTemplate(const AName, APathTemplate: string;
      AKind: TNXPasSearchPathKind): TNXPasSearchPathTemplate;
    function TemplateAt(AIndex: Integer): TNXPasSearchPathTemplate;
  end;

  TNXPasSearchPathTemplateStore = class
  public
    class function DefaultFileName: string; static;
    class function DefaultRootDir: string; static;
    class procedure AddMasterDefaults(
      ATemplates: TNXPasSearchPathTemplateList); static;
    class procedure LoadOrCreate(ATemplates: TNXPasSearchPathTemplateList);
      overload; static;
    class procedure LoadOrCreate(const AFileName: string;
      ATemplates: TNXPasSearchPathTemplateList); overload; static;
  end;

  TNXPasSearchPathContext = class
  private
    FExistingPaths: TStringList;
    FFPCDir: string;
    FFPCSrcDir: string;
    FIncludePaths: TStringList;
    FLazarusDir: string;
    FLazarusSrcDir: string;
    FLPIFileName: string;
    FLog: TStringList;
    FMissingPaths: TStringList;
    FProjectDir: string;
    FRawPaths: TStringList;
    FSourcePaths: TStringList;
    FTargetCPU: string;
    FTargetOS: string;
    FUnitPaths: TStringList;
    FWorkspaceDir: string;
    procedure AddExistingPath(AList: TStrings; const APath, ASource: string);
    procedure AddMissingPath(const APath, ASource: string);
    function ExpandTemplate(const AValue: string; out AResolved: string): Boolean;
    function NormalizePath(const APath: string): string;
    function PathListForKind(AKind: TNXPasSearchPathKind): TStrings;
    procedure SetFPCDir(const AValue: string);
    procedure SetLazarusDir(const AValue: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure AddRawPath(const APath, ASource: string; AKind: TNXPasSearchPathKind;
      const ABaseDir: string = '');
    procedure AddRawPaths(APaths: TStrings; const ASource: string;
      AKind: TNXPasSearchPathKind; const ABaseDir: string = '');
    procedure AddTemplate(ATemplate: TNXPasSearchPathTemplate);
    procedure AddTemplates(ATemplates: TNXPasSearchPathTemplateList);
    procedure AddDefaultTemplates(ATemplates: TNXPasSearchPathTemplateList);
    procedure AddFPCOptionPaths(AOptions: TStrings);

    property ExistingPaths: TStringList read FExistingPaths;
    property FPCDir: string read FFPCDir write SetFPCDir;
    property FPCSrcDir: string read FFPCSrcDir;
    property IncludePaths: TStringList read FIncludePaths;
    property LazarusDir: string read FLazarusDir write SetLazarusDir;
    property LazarusSrcDir: string read FLazarusSrcDir;
    property LPIFileName: string read FLPIFileName write FLPIFileName;
    property Log: TStringList read FLog;
    property MissingPaths: TStringList read FMissingPaths;
    property ProjectDir: string read FProjectDir write FProjectDir;
    property RawPaths: TStringList read FRawPaths;
    property SourcePaths: TStringList read FSourcePaths;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property TargetOS: string read FTargetOS write FTargetOS;
    property UnitPaths: TStringList read FUnitPaths;
    property WorkspaceDir: string read FWorkspaceDir write FWorkspaceDir;
  end;

function NXPasDefaultTargetCPU: string;
function NXPasDefaultTargetOS: string;
function NXPasPathIsAbsolute(const APath: string): Boolean;

implementation

uses
  SysUtils;

const
  cSearchPathTemplateFile = 'nexuspas-search-paths.json';
  cSearchPathTemplateDir = 'search-paths';
  cNexusLSStorageEnv = 'NEXUSLS_CACHE_DIR';

function NXPasDefaultTargetCPU: string;
begin
  {$ifdef CPUX86_64}
  Result := 'x86_64';
  {$else}
  {$ifdef CPUI386}
  Result := 'i386';
  {$else}
  {$ifdef CPUAARCH64}
  Result := 'aarch64';
  {$else}
  {$ifdef CPUARM}
  Result := 'arm';
  {$else}
  Result := '';
  {$endif}
  {$endif}
  {$endif}
  {$endif}
end;

function NXPasDefaultTargetOS: string;
begin
  {$ifdef MSWINDOWS}
  {$ifdef CPU64}
  Result := 'win64';
  {$else}
  Result := 'win32';
  {$endif}
  {$else}
  {$ifdef LINUX}
  Result := 'linux';
  {$else}
  {$ifdef DARWIN}
  Result := 'darwin';
  {$else}
  Result := '';
  {$endif}
  {$endif}
  {$endif}
end;

function NXPasPathIsAbsolute(const APath: string): Boolean;
begin
  Result := (APath <> '') and
    (((Length(APath) >= 2) and (APath[2] = ':')) or
    (APath[1] in ['\', '/']));
end;

constructor TNXPasSearchPathTemplate.Create;
begin
  inherited Create;
  FEnabled := True;
  FPathKind := pspkUnitPath;
end;

function TNXPasSearchPathTemplateList.GetItemClass: TNXPersistClass;
begin
  Result := TNXPasSearchPathTemplate;
end;

function TNXPasSearchPathTemplateList.AddTemplate(const AName,
  APathTemplate: string; AKind: TNXPasSearchPathKind): TNXPasSearchPathTemplate;
begin
  Result := TNXPasSearchPathTemplate(New);
  Result.Name := AName;
  Result.PathTemplate := APathTemplate;
  Result.PathKind := AKind;
end;

function TNXPasSearchPathTemplateList.TemplateAt(
  AIndex: Integer): TNXPasSearchPathTemplate;
begin
  Result := TNXPasSearchPathTemplate(Items[AIndex]);
end;

class function TNXPasSearchPathTemplateStore.DefaultFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(DefaultRootDir) +
    IncludeTrailingPathDelimiter(cSearchPathTemplateDir) +
    cSearchPathTemplateFile;
end;

class function TNXPasSearchPathTemplateStore.DefaultRootDir: string;
begin
  Result := Trim(GetEnvironmentVariable(cNexusLSStorageEnv));
  if Result = '' then
    Result := GetAppConfigDir(False);
end;

class procedure TNXPasSearchPathTemplateStore.AddMasterDefaults(
  ATemplates: TNXPasSearchPathTemplateList);

  function FindTemplate(const AName: string): TNXPasSearchPathTemplate;
  var
    lIdx: Integer;
  begin
    Result := nil;
    for lIdx := 0 to ATemplates.Count - 1 do
      if SameText(ATemplates.TemplateAt(lIdx).Name, AName) then
        Exit(ATemplates.TemplateAt(lIdx));
  end;

  procedure AddUnitPath(const AName, APath: string);
  var
    lTemplate: TNXPasSearchPathTemplate;
  begin
    lTemplate := FindTemplate(AName);
    if lTemplate = nil then
      ATemplates.AddTemplate(AName, APath, pspkUnitPath)
    else
    begin
      lTemplate.PathTemplate := APath;
      lTemplate.PathKind := pspkUnitPath;
    end;
  end;

begin
  if ATemplates = nil then
    Exit;

  AddUnitPath('Lazarus LCL', '$(LazarusSrcDir)\lcl');
  AddUnitPath('Lazarus LCL Interfaces', '$(LazarusSrcDir)\lcl\interfaces');
  AddUnitPath('Lazarus LCL Win32',
    '$(LazarusSrcDir)\lcl\interfaces\win32');
  AddUnitPath('Lazarus LCL GTK2', '$(LazarusSrcDir)\lcl\interfaces\gtk2');
  AddUnitPath('Lazarus LCL QT5', '$(LazarusSrcDir)\lcl\interfaces\qt5');
  AddUnitPath('Lazarus LCL QT6', '$(LazarusSrcDir)\lcl\interfaces\qt6');
  AddUnitPath('Lazarus LazUtils', '$(LazarusSrcDir)\components\lazutils');
  AddUnitPath('Lazarus Packager', '$(LazarusSrcDir)\packager');
  AddUnitPath('Lazarus IDEIntf', '$(LazarusSrcDir)\ideintf');
  AddUnitPath('Lazarus SynEdit', '$(LazarusSrcDir)\components\synedit');
  AddUnitPath('Lazarus DebuggerIntf',
    '$(LazarusSrcDir)\components\debuggerintf');
  AddUnitPath('Lazarus Project Groups',
    '$(LazarusSrcDir)\components\projectgroups');
  AddUnitPath('Lazarus AnchorDocking',
    '$(LazarusSrcDir)\components\anchordocking');
  AddUnitPath('Lazarus Printer4Lazarus',
    '$(LazarusSrcDir)\components\printer4lazarus');
  AddUnitPath('Lazarus DateTimeCtrls',
    '$(LazarusSrcDir)\components\datetimectrls');
  AddUnitPath('Lazarus TAChart', '$(LazarusSrcDir)\components\tachart');
  AddUnitPath('Lazarus VirtualTreeView',
    '$(LazarusSrcDir)\components\virtualtreeview');
  AddUnitPath('Lazarus DBExport', '$(LazarusSrcDir)\components\dbexport');

  AddUnitPath('FPC RTL', '$(FPCSrcDir)\rtl');
  AddUnitPath('FPC RTL Target', '$(FPCSrcDir)\rtl\$(TargetOS)');
  AddUnitPath('FPC RTL Win', '$(FPCSrcDir)\rtl\win');
  AddUnitPath('FPC RTL Unix', '$(FPCSrcDir)\rtl\unix');
  AddUnitPath('FPC RTL ObjPas', '$(FPCSrcDir)\rtl\objpas');
  AddUnitPath('FPC RTL ObjPas Classes',
    '$(FPCSrcDir)\rtl\objpas\classes');
  AddUnitPath('FPC RTL ObjPas SysUtils',
    '$(FPCSrcDir)\rtl\objpas\sysutils');
  AddUnitPath('FPC RTL Inc', '$(FPCSrcDir)\rtl\inc');
  AddUnitPath('FPC FCL Base', '$(FPCSrcDir)\packages\fcl-base\src');
  AddUnitPath('FPC FCL JSON', '$(FPCSrcDir)\packages\fcl-json\src');
  AddUnitPath('FPC FCL XML', '$(FPCSrcDir)\packages\fcl-xml\src');
  AddUnitPath('FPC FCL DB', '$(FPCSrcDir)\packages\fcl-db\src');
  AddUnitPath('FPC FCL Image', '$(FPCSrcDir)\packages\fcl-image\src');
  AddUnitPath('FPC FCL Net', '$(FPCSrcDir)\packages\fcl-net\src');
  AddUnitPath('FPC FCL Process', '$(FPCSrcDir)\packages\fcl-process\src');
  AddUnitPath('FPC FCL Reg', '$(FPCSrcDir)\packages\fcl-registry\src');
  AddUnitPath('FPC FCL Web Base', '$(FPCSrcDir)\packages\fcl-web\src\base');
  AddUnitPath('FPC RTL Extra', '$(FPCSrcDir)\packages\rtl-extra\src');
  AddUnitPath('FPC PasJPEG', '$(FPCSrcDir)\packages\pasjpeg\src');
  AddUnitPath('FPC Hash', '$(FPCSrcDir)\packages\hash\src');
  AddUnitPath('FPC RegExpr', '$(FPCSrcDir)\packages\regexpr\src');
  AddUnitPath('FPC CHM', '$(FPCSrcDir)\packages\chm\src');
  AddUnitPath('FPC SQLite', '$(FPCSrcDir)\packages\sqlite\src');
  AddUnitPath('FPC MySQL', '$(FPCSrcDir)\packages\mysql\src');
  AddUnitPath('FPC PostgreSQL', '$(FPCSrcDir)\packages\postgres\src');
  AddUnitPath('FPC IBase', '$(FPCSrcDir)\packages\ibase\src');
end;

class procedure TNXPasSearchPathTemplateStore.LoadOrCreate(
  ATemplates: TNXPasSearchPathTemplateList);
begin
  LoadOrCreate(DefaultFileName, ATemplates);
end;

class procedure TNXPasSearchPathTemplateStore.LoadOrCreate(
  const AFileName: string; ATemplates: TNXPasSearchPathTemplateList);
begin
  if ATemplates = nil then
    Exit;

  if FileExists(AFileName) then
  begin
    ATemplates.LoadFromJSONFile(AFileName);
    AddMasterDefaults(ATemplates);
    ATemplates.SaveToJSONFile(AFileName);
    Exit;
  end;

  ATemplates.Clear;
  AddMasterDefaults(ATemplates);
  if ExtractFileDir(AFileName) <> '' then
    ForceDirectories(ExtractFileDir(AFileName));
  ATemplates.SaveToJSONFile(AFileName);
end;

constructor TNXPasSearchPathContext.Create;
begin
  inherited Create;
  FExistingPaths := TStringList.Create;
  FIncludePaths := TStringList.Create;
  FLog := TStringList.Create;
  FMissingPaths := TStringList.Create;
  FRawPaths := TStringList.Create;
  FSourcePaths := TStringList.Create;
  FUnitPaths := TStringList.Create;

  FExistingPaths.Sorted := True;
  FExistingPaths.Duplicates := dupIgnore;
  FExistingPaths.CaseSensitive := False;
  FMissingPaths.Sorted := True;
  FMissingPaths.Duplicates := dupIgnore;
  FMissingPaths.CaseSensitive := False;
  FUnitPaths.CaseSensitive := False;
  FIncludePaths.CaseSensitive := False;
  FSourcePaths.CaseSensitive := False;

  FTargetCPU := '';
  FTargetOS := '';
  SetLazarusDir('');
  SetFPCDir('');
end;

destructor TNXPasSearchPathContext.Destroy;
begin
  FSourcePaths.Free;
  FRawPaths.Free;
  FMissingPaths.Free;
  FLog.Free;
  FIncludePaths.Free;
  FExistingPaths.Free;
  FUnitPaths.Free;
  inherited Destroy;
end;

procedure TNXPasSearchPathContext.Clear;
begin
  FExistingPaths.Clear;
  FIncludePaths.Clear;
  FLog.Clear;
  FMissingPaths.Clear;
  FRawPaths.Clear;
  FSourcePaths.Clear;
  FUnitPaths.Clear;
  FLPIFileName := '';
end;

function TNXPasSearchPathContext.NormalizePath(const APath: string): string;
begin
  Result := Trim(APath);
  if Result = '' then
    Exit;

  Result := StringReplace(Result, '/', DirectorySeparator, [rfReplaceAll]);
  Result := ExpandFileName(Result);
  Result := ExcludeTrailingPathDelimiter(Result);
end;

procedure TNXPasSearchPathContext.SetFPCDir(const AValue: string);
begin
  FFPCDir := Trim(AValue);
  if FFPCDir = '' then
    FFPCSrcDir := ''
  else
    FFPCSrcDir := IncludeTrailingPathDelimiter(FFPCDir) + 'source';
end;

procedure TNXPasSearchPathContext.SetLazarusDir(const AValue: string);
begin
  FLazarusDir := Trim(AValue);
  FLazarusSrcDir := FLazarusDir;
end;

function TNXPasSearchPathContext.PathListForKind(
  AKind: TNXPasSearchPathKind): TStrings;
begin
  case AKind of
    pspkIncludePath:
      Result := FIncludePaths;
    pspkSourcePath:
      Result := FSourcePaths;
  else
    Result := FUnitPaths;
  end;
end;

procedure TNXPasSearchPathContext.AddExistingPath(AList: TStrings;
  const APath, ASource: string);
var
  lPath: string;
begin
  lPath := NormalizePath(APath);
  if lPath = '' then
    Exit;

  if AList.IndexOf(lPath) < 0 then
    AList.Add(lPath);
  if FExistingPaths.IndexOf(lPath) < 0 then
    FExistingPaths.Add(lPath);
  FLog.Add('path: ' + lPath + ' [' + ASource + ']');
end;

procedure TNXPasSearchPathContext.AddMissingPath(const APath,
  ASource: string);
var
  lPath: string;
begin
  lPath := NormalizePath(APath);
  if lPath = '' then
    Exit;

  if FMissingPaths.IndexOf(lPath) < 0 then
    FMissingPaths.Add(lPath);
  FLog.Add('missing path: ' + lPath + ' [' + ASource + ']');
end;

function TNXPasSearchPathContext.ExpandTemplate(const AValue: string;
  out AResolved: string): Boolean;

  function ReplaceVar(const AName, AValue: string): Boolean;
  var
    lNeedle: string;
  begin
    Result := True;
    lNeedle := '$(' + AName + ')';
    if Pos(UpperCase(lNeedle), UpperCase(AResolved)) = 0 then
      Exit;
    if AValue = '' then
      Exit(False);
    AResolved := StringReplace(AResolved, lNeedle, AValue,
      [rfReplaceAll, rfIgnoreCase]);
  end;

begin
  AResolved := AValue;
  Result :=
    ReplaceVar('ProjectDir', FProjectDir) and
    ReplaceVar('WorkspaceDir', FWorkspaceDir) and
    ReplaceVar('LazarusDir', FLazarusDir) and
    ReplaceVar('LazarusSrcDir', FLazarusSrcDir) and
    ReplaceVar('FPCDir', FFPCDir) and
    ReplaceVar('FPCSrcDir', FFPCSrcDir) and
    ReplaceVar('TargetOS', FTargetOS) and
    ReplaceVar('TargetCPU', FTargetCPU);

  if Result and (Pos('$(', AResolved) > 0) then
    Result := False;
end;

procedure TNXPasSearchPathContext.AddRawPath(const APath, ASource: string;
  AKind: TNXPasSearchPathKind; const ABaseDir: string);
var
  lBase: string;
  lExpanded: string;
  lPath: string;
begin
  lPath := Trim(APath);
  if lPath = '' then
    Exit;

  FRawPaths.Add(ASource + '=' + lPath);
  if not ExpandTemplate(lPath, lExpanded) then
  begin
    FLog.Add('unresolved path template: ' + lPath + ' [' + ASource + ']');
    Exit;
  end;

  if (ABaseDir <> '') and (not NXPasPathIsAbsolute(lExpanded)) then
  begin
    lBase := IncludeTrailingPathDelimiter(ABaseDir);
    lExpanded := lBase + lExpanded;
  end;

  if DirectoryExists(lExpanded) then
    AddExistingPath(PathListForKind(AKind), lExpanded, ASource)
  else
    AddMissingPath(lExpanded, ASource);
end;

procedure TNXPasSearchPathContext.AddRawPaths(APaths: TStrings;
  const ASource: string; AKind: TNXPasSearchPathKind; const ABaseDir: string);
var
  lIdx: Integer;
begin
  if APaths = nil then
    Exit;

  for lIdx := 0 to APaths.Count - 1 do
    AddRawPath(APaths[lIdx], ASource, AKind, ABaseDir);
end;

procedure TNXPasSearchPathContext.AddTemplate(
  ATemplate: TNXPasSearchPathTemplate);
begin
  if (ATemplate = nil) or (not ATemplate.Enabled) then
    Exit;

  if ATemplate.TargetOS <> '' then
  begin
    if FTargetOS = '' then
    begin
      FLog.Add('skipped target-specific template without TargetOS: ' +
        ATemplate.Name);
      Exit;
    end;
    if not SameText(ATemplate.TargetOS, FTargetOS) then
      Exit;
  end;

  if ATemplate.TargetCPU <> '' then
  begin
    if FTargetCPU = '' then
    begin
      FLog.Add('skipped target-specific template without TargetCPU: ' +
        ATemplate.Name);
      Exit;
    end;
    if not SameText(ATemplate.TargetCPU, FTargetCPU) then
      Exit;
  end;

  AddRawPath(ATemplate.PathTemplate, 'template:' + ATemplate.Name,
    ATemplate.PathKind);
end;

procedure TNXPasSearchPathContext.AddTemplates(
  ATemplates: TNXPasSearchPathTemplateList);
var
  lIdx: Integer;
begin
  if ATemplates = nil then
    Exit;

  for lIdx := 0 to ATemplates.Count - 1 do
    AddTemplate(ATemplates.TemplateAt(lIdx));
end;

procedure TNXPasSearchPathContext.AddDefaultTemplates(
  ATemplates: TNXPasSearchPathTemplateList);
begin
  if ATemplates = nil then
    Exit;

  TNXPasSearchPathTemplateStore.AddMasterDefaults(ATemplates);
end;

procedure TNXPasSearchPathContext.AddFPCOptionPaths(AOptions: TStrings);
var
  lIdx: Integer;
  lOption: string;
begin
  if AOptions = nil then
    Exit;

  for lIdx := 0 to AOptions.Count - 1 do
  begin
    lOption := Trim(AOptions[lIdx]);
    if Copy(lOption, 1, 3) = '-Fu' then
      AddRawPath(Copy(lOption, 4, MaxInt), 'fpcOption:-Fu', pspkUnitPath,
        FProjectDir)
    else if Copy(lOption, 1, 3) = '-Fi' then
      AddRawPath(Copy(lOption, 4, MaxInt), 'fpcOption:-Fi', pspkIncludePath,
        FProjectDir);
  end;
end;

initialization
  TNXPersistObject.RegisterPersistClass(TNXPasSearchPathTemplate);
  TNXPersistObject.RegisterPersistClass(TNXPasSearchPathTemplateList);

end.
