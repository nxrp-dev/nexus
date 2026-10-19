(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLLVMBuildOptions;

{$mode objfpc}{$H+}

interface

uses Classes, obNXBuildEntry, obNXBuildDirectories;

type
  TNXLLVMBuildKind = (lbkProgram, lbkSharedLibrary, lbkObject);
  TNXLLVMLanguage = (llmAuto, llmC, llmCPP);

  TNXLLVMBuildOptions = class(TNXBuildEntry)
  private
    FBuildKind: TNXLLVMBuildKind;
    FLanguage: TNXLLVMLanguage;
    FTarget: string;
    FStandard: string;
    FConfigFiles: TStringList;
    FRawOptions: TStringList;
    FIncludePaths: TStringList;
    FSystemIncludePaths: TStringList;
    FLibraryPaths: TStringList;
    FLibraries: TStringList;
    FDefines: TStringList;
    FDebugInfo: Boolean;
    FPositionIndependentCode: Boolean;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure ValidateTarget(const AOS, ACPU: string); override;
    function BuildType: string; override;
    function DefaultCompiler: string; override;
    procedure ResolvePaths(const ARoot: string); override;
    procedure AppendEnvironment(APaths: TNXBuildDirectories; AArguments: TStrings;
      var ASourceArgumentIndex: Integer); override;
    procedure AppendArguments(AArguments: TStrings; out ASourceArgumentIndex: Integer); override;
  published
    property BuildKind: TNXLLVMBuildKind read FBuildKind write FBuildKind;
    property Language: TNXLLVMLanguage read FLanguage write FLanguage;
    property Target: string read FTarget write FTarget;
    property Standard: string read FStandard write FStandard;
    property RawOptions: TStringList read FRawOptions;
    property ConfigFiles: TStringList read FConfigFiles;
    property IncludePaths: TStringList read FIncludePaths;
    property SystemIncludePaths: TStringList read FSystemIncludePaths;
    property LibraryPaths: TStringList read FLibraryPaths;
    property Libraries: TStringList read FLibraries;
    property Defines: TStringList read FDefines;
    property DebugInfo: Boolean read FDebugInfo write FDebugInfo;
    property PositionIndependentCode: Boolean read FPositionIndependentCode write FPositionIndependentCode;
  end;

implementation

uses SysUtils, obNXPersist;

constructor TNXLLVMBuildOptions.Create;
begin
  inherited Create;
  FConfigFiles := TStringList.Create;
  FRawOptions := TStringList.Create;
  FIncludePaths := TStringList.Create;
  FSystemIncludePaths := TStringList.Create;
  FLibraryPaths := TStringList.Create;
  FLibraries := TStringList.Create;
  FDefines := TStringList.Create;
end;

destructor TNXLLVMBuildOptions.Destroy;
begin
  FDefines.Free;
  FLibraries.Free;
  FLibraryPaths.Free;
  FSystemIncludePaths.Free;
  FIncludePaths.Free;
  FRawOptions.Free;
  FConfigFiles.Free;
  inherited Destroy;
end;

function TNXLLVMBuildOptions.BuildType: string;
begin
  Result := 'LLVM';
end;

function TNXLLVMBuildOptions.DefaultCompiler: string;
begin
  if FLanguage = llmCPP then
    Result := 'clang++'
  else
    Result := 'clang';
end;

procedure TNXLLVMBuildOptions.ValidateTarget(const AOS, ACPU: string);
var
  lTarget, lCPU, lOS: string;
  lSeparator: Integer;
begin
  if FTarget = '' then Exit;
  lTarget := LowerCase(FTarget);
  lSeparator := Pos('-', lTarget);
  if lSeparator = 0 then Exit;
  lCPU := Copy(lTarget, 1, lSeparator - 1);
  if lCPU = 'arm64' then lCPU := 'aarch64';
  if (lCPU = 'i486') or (lCPU = 'i586') or (lCPU = 'i686') then lCPU := 'i386';
  if (Pos('armv', lCPU) = 1) or (Pos('thumb', lCPU) = 1) then lCPU := 'arm';
  if (ACPU <> '') and not SameText(lCPU, ACPU) then
    raise Exception.CreateFmt('LLVM target CPU "%s" conflicts with selected TargetCPU "%s".',
      [lCPU, ACPU]);
  lOS := '';
  if Pos('android', lTarget) > 0 then lOS := 'android'
  else if (Pos('windows', lTarget) > 0) or (Pos('mingw', lTarget) > 0) then
  begin
    if lCPU = 'i386' then lOS := 'win32' else lOS := 'win64';
  end
  else if Pos('ios', lTarget) > 0 then
  begin
    if Pos('simulator', lTarget) > 0 then lOS := 'iphonesim' else lOS := 'ios';
  end
  else if (Pos('darwin', lTarget) > 0) or (Pos('macos', lTarget) > 0) then lOS := 'darwin'
  else if Pos('linux', lTarget) > 0 then lOS := 'linux';
  if (AOS <> '') and (lOS <> '') and not SameText(lOS, AOS) then
    raise Exception.CreateFmt('LLVM target OS "%s" conflicts with selected TargetOS "%s".',
      [lOS, AOS]);
end;

procedure TNXLLVMBuildOptions.AppendEnvironment(APaths: TNXBuildDirectories;
  AArguments: TStrings; var ASourceArgumentIndex: Integer);
begin
  InsertPaths(AArguments, APaths.Headers, '-I', ASourceArgumentIndex);
  if FBuildKind <> lbkObject then
    InsertPaths(AArguments, APaths.Libraries, '-L', ASourceArgumentIndex);
end;

procedure TNXLLVMBuildOptions.ResolvePaths(const ARoot: string);
begin
  inherited ResolvePaths(ARoot);
  ResolvePathList(FConfigFiles, ARoot);
  ResolvePathList(FIncludePaths, ARoot);
  ResolvePathList(FSystemIncludePaths, ARoot);
  ResolvePathList(FLibraryPaths, ARoot);
end;

procedure TNXLLVMBuildOptions.AppendArguments(AArguments: TStrings;
  out ASourceArgumentIndex: Integer);
var
  lValue: string;
begin
  for lValue in FConfigFiles do AArguments.Add('--config=' + lValue);
  case FBuildKind of
    lbkSharedLibrary: AArguments.Add('-shared');
    lbkObject: AArguments.Add('-c');
  end;
  if FLanguage <> llmAuto then
  begin
    AArguments.Add('-x');
    if FLanguage = llmC then AArguments.Add('c') else AArguments.Add('c++');
  end;
  if FTarget <> '' then AArguments.Add('--target=' + FTarget);
  if FStandard <> '' then AArguments.Add('-std=' + FStandard);
  if FDebugInfo then AArguments.Add('-g');
  if FPositionIndependentCode then AArguments.Add('-fPIC');
  for lValue in FIncludePaths do AArguments.Add('-I' + lValue);
  for lValue in FSystemIncludePaths do
  begin
    AArguments.Add('-isystem');
    AArguments.Add(lValue);
  end;
  for lValue in FDefines do AArguments.Add('-D' + lValue);
  for lValue in FLibraryPaths do AArguments.Add('-L' + lValue);
  for lValue in FRawOptions do AArguments.Add(lValue);
  ASourceArgumentIndex := AArguments.Count;
  for lValue in FLibraries do AArguments.Add('-l' + lValue);
end;

initialization
  TNXPersistObject.RegisterPersistClass(TNXLLVMBuildOptions);

end.
