unit obNXPascalProject;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  LazFileUtils,
  obNXPersist,
  obNXFPCBuildOptions;

type
  TNXPascalProjectKind = (
    ppkUnknown,
    ppkProgram,
    ppkLibrary,
    ppkPackage,
    ppkLazarusProject,
    ppkPascalUnitSet
  );

  TNXPascalTargetPlatform = class(TNXPersistObject)
  private
    FTargetOS: string;
    FTargetCPU: string;
    FWidgetSet: string;
    FFPCMode: string;
    FConfigName: string;
  published
    property TargetOS: string read FTargetOS write FTargetOS;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property WidgetSet: string read FWidgetSet write FWidgetSet;
    property FPCMode: string read FFPCMode write FFPCMode;
    property ConfigName: string read FConfigName write FConfigName;
  end;

  TNXPascalToolchain = class(TNXPersistObject)
  private
    FCompilerPath: string;
    FFPCSourceRoot: string;
    FFPCUnitRoot: string;
    FLazarusRoot: string;
  published
    property CompilerPath: string read FCompilerPath write FCompilerPath;
    property FPCSourceRoot: string read FFPCSourceRoot write FFPCSourceRoot;
    property FPCUnitRoot: string read FFPCUnitRoot write FFPCUnitRoot;
    property LazarusRoot: string read FLazarusRoot write FLazarusRoot;
  end;

  TNXPascalProject = class(TNXPersistObject)
  private
    FProjectKind: TNXPascalProjectKind;
    FProjectFileName: string;
    FProjectRoot: string;
    FSourceRoot: string;
    FOutputRoot: string;
    FLazarusProjectFile: string;
    FTargetPlatform: TNXPascalTargetPlatform;
    FToolchain: TNXPascalToolchain;
    FFPCBuildOptions: TNXFPCBuildOptions;
    FVariables: TStringList;

    procedure ResolveStringList(AValues: TStrings; AResolveAsPath: Boolean);
    procedure SetVariableValue(const AName: string; const AValue: string);
    procedure UpdateBuiltInVariables;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure ClearVariables;
    procedure SetVariable(const AName: string; const AValue: string);
    function GetVariable(const AName: string): string;
    function ResolveValue(const AValue: string): string;
    function ResolvePath(const APath: string): string;
    procedure ResolveValues(AInput: TStrings; AOutput: TStrings);
    procedure ResolvePaths(AInput: TStrings; AOutput: TStrings);
    procedure ApplyToBuildOptions;
    procedure ResolveBuildOptionPaths;

  published
    property ProjectKind: TNXPascalProjectKind read FProjectKind write FProjectKind;
    property ProjectFileName: string read FProjectFileName write FProjectFileName;
    property ProjectRoot: string read FProjectRoot write FProjectRoot;
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property OutputRoot: string read FOutputRoot write FOutputRoot;
    property LazarusProjectFile: string read FLazarusProjectFile write FLazarusProjectFile;
    property TargetPlatform: TNXPascalTargetPlatform read FTargetPlatform;
    property Toolchain: TNXPascalToolchain read FToolchain;
    property FPCBuildOptions: TNXFPCBuildOptions read FFPCBuildOptions;
    property Variables: TStringList read FVariables;
  end;

implementation

constructor TNXPascalProject.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FTargetPlatform := TNXPascalTargetPlatform.Create;
  FToolchain := TNXPascalToolchain.Create;
  FFPCBuildOptions := TNXFPCBuildOptions.Create;
  FVariables := TStringList.Create;
  FVariables.NameValueSeparator := '=';
  FVariables.CaseSensitive := False;
end;

destructor TNXPascalProject.Destroy;
begin
  FVariables.Free;
  FFPCBuildOptions.Free;
  FToolchain.Free;
  FTargetPlatform.Free;
  inherited Destroy;
end;

procedure TNXPascalProject.ClearVariables;
begin
  FVariables.Clear;
end;

procedure TNXPascalProject.SetVariableValue(const AName: string; const AValue: string);
var
  lIndex: Integer;
begin
  if AName = '' then
    Exit;

  lIndex := FVariables.IndexOfName(AName);
  if lIndex < 0 then
    FVariables.Add(AName + FVariables.NameValueSeparator + AValue)
  else
    FVariables.ValueFromIndex[lIndex] := AValue;
end;

procedure TNXPascalProject.SetVariable(const AName: string; const AValue: string);
begin
  SetVariableValue(AName, AValue);
end;

function TNXPascalProject.GetVariable(const AName: string): string;
var
  lIndex: Integer;
begin
  lIndex := FVariables.IndexOfName(AName);
  if lIndex < 0 then
    Result := ''
  else
    Result := FVariables.ValueFromIndex[lIndex];
end;

procedure TNXPascalProject.UpdateBuiltInVariables;
begin
  SetVariableValue('ProjectName', Name);
  SetVariableValue('ProjectFileName', FProjectFileName);
  SetVariableValue('ProjectRoot', FProjectRoot);
  SetVariableValue('SourceRoot', FSourceRoot);
  SetVariableValue('OutputRoot', FOutputRoot);
  SetVariableValue('LazarusProjectFile', FLazarusProjectFile);
  SetVariableValue('CompilerPath', FToolchain.CompilerPath);
  SetVariableValue('FPCSourceRoot', FToolchain.FPCSourceRoot);
  SetVariableValue('FPCUnitRoot', FToolchain.FPCUnitRoot);
  SetVariableValue('LazarusRoot', FToolchain.LazarusRoot);
  SetVariableValue('TargetOS', FTargetPlatform.TargetOS);
  SetVariableValue('TargetCPU', FTargetPlatform.TargetCPU);
  SetVariableValue('WidgetSet', FTargetPlatform.WidgetSet);
  SetVariableValue('FPCMode', FTargetPlatform.FPCMode);
  SetVariableValue('ConfigName', FTargetPlatform.ConfigName);
end;

function TNXPascalProject.ResolveValue(const AValue: string): string;
var
  lIndex: Integer;
  lName: string;
begin
  Result := AValue;
  UpdateBuiltInVariables;

  for lIndex := 0 to FVariables.Count - 1 do
  begin
    lName := FVariables.Names[lIndex];
    if lName <> '' then
      Result := StringReplace(Result, '$(' + lName + ')', FVariables.ValueFromIndex[lIndex], [rfReplaceAll, rfIgnoreCase]);
  end;
end;

function TNXPascalProject.ResolvePath(const APath: string): string;
var
  lPath: string;
begin
  lPath := ResolveValue(APath);
  if lPath = '' then
    Exit('');

  if (FProjectRoot <> '') and not FilenameIsAbsolute(lPath) then
    lPath := IncludeTrailingPathDelimiter(FProjectRoot) + lPath;

  Result := ExpandFileName(lPath);
end;

procedure TNXPascalProject.ResolveValues(AInput: TStrings; AOutput: TStrings);
var
  lIndex: Integer;
begin
  if AOutput = nil then
    Exit;

  AOutput.Clear;
  if AInput = nil then
    Exit;

  for lIndex := 0 to AInput.Count - 1 do
    AOutput.Add(ResolveValue(AInput[lIndex]));
end;

procedure TNXPascalProject.ResolvePaths(AInput: TStrings; AOutput: TStrings);
var
  lIndex: Integer;
begin
  if AOutput = nil then
    Exit;

  AOutput.Clear;
  if AInput = nil then
    Exit;

  for lIndex := 0 to AInput.Count - 1 do
    AOutput.Add(ResolvePath(AInput[lIndex]));
end;

procedure TNXPascalProject.ResolveStringList(AValues: TStrings; AResolveAsPath: Boolean);
var
  lValues: TStringList;
  lIndex: Integer;
begin
  if AValues = nil then
    Exit;

  lValues := TStringList.Create;
  try
    lValues.Assign(AValues);
    AValues.Clear;
    for lIndex := 0 to lValues.Count - 1 do
      if AResolveAsPath then
        AValues.Add(ResolvePath(lValues[lIndex]))
      else
        AValues.Add(ResolveValue(lValues[lIndex]));
  finally
    lValues.Free;
  end;
end;

procedure TNXPascalProject.ApplyToBuildOptions;
begin
  FFPCBuildOptions.CompilerPath := ResolveValue(FToolchain.CompilerPath);
  FLazarusProjectFile := ResolvePath(FLazarusProjectFile);
  FFPCBuildOptions.InputFile := ResolvePath(FFPCBuildOptions.InputFile);
  FFPCBuildOptions.OutputFile := ResolvePath(FFPCBuildOptions.OutputFile);
  FFPCBuildOptions.Target.OperatingSystem := ResolveValue(FTargetPlatform.TargetOS);
  ResolveBuildOptionPaths;
end;

procedure TNXPascalProject.ResolveBuildOptionPaths;
begin
  ResolveStringList(FFPCBuildOptions.Config.OptionFiles, True);
  ResolveStringList(FFPCBuildOptions.Files.PreloadUnits, False);
  ResolveStringList(FFPCBuildOptions.Files.FrameworkPaths, True);
  ResolveStringList(FFPCBuildOptions.Files.IncludePaths, True);
  ResolveStringList(FFPCBuildOptions.Files.LibraryPaths, True);
  ResolveStringList(FFPCBuildOptions.Files.DefaultUnitScopes, False);
  ResolveStringList(FFPCBuildOptions.Files.ObjectPaths, True);
  ResolveStringList(FFPCBuildOptions.Files.UnitPaths, True);

  FFPCBuildOptions.Files.ExecutableSearchPath := ResolvePath(FFPCBuildOptions.Files.ExecutableSearchPath);
  FFPCBuildOptions.Files.RCCompilerBinary := ResolvePath(FFPCBuildOptions.Files.RCCompilerBinary);
  FFPCBuildOptions.Files.CompilerUtilitiesPath := ResolvePath(FFPCBuildOptions.Files.CompilerUtilitiesPath);
  FFPCBuildOptions.Files.ErrorOutputFile := ResolvePath(FFPCBuildOptions.Files.ErrorOutputFile);
  FFPCBuildOptions.Files.ExecutableOutputPath := ResolvePath(FFPCBuildOptions.Files.ExecutableOutputPath);
  FFPCBuildOptions.Files.DynamicLinker := ResolvePath(FFPCBuildOptions.Files.DynamicLinker);
  FFPCBuildOptions.Files.UnicodeBinaryPath := ResolvePath(FFPCBuildOptions.Files.UnicodeBinaryPath);
  FFPCBuildOptions.Files.ErrorMessageFile := ResolvePath(FFPCBuildOptions.Files.ErrorMessageFile);
  FFPCBuildOptions.Files.ResourceLinker := ResolvePath(FFPCBuildOptions.Files.ResourceLinker);
  FFPCBuildOptions.Files.UnitOutputPath := ResolvePath(FFPCBuildOptions.Files.UnitOutputPath);
  FFPCBuildOptions.Files.WholeProgramFeedbackOutput := ResolvePath(FFPCBuildOptions.Files.WholeProgramFeedbackOutput);
  FFPCBuildOptions.Files.WholeProgramFeedbackInput := ResolvePath(FFPCBuildOptions.Files.WholeProgramFeedbackInput);
end;

end.
