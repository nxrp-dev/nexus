(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLLVMBuildOptions;

{$mode objfpc}{$H+}

interface

uses Classes, obNXBuildEntry;

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
    function BuildType: string; override;
    function DefaultCompiler: string; override;
    procedure ResolvePaths(const ARoot: string); override;
    procedure AppendArguments(AArguments: TStrings; out ASourceArgumentIndex: Integer); override;
  published
    property BuildKind: TNXLLVMBuildKind read FBuildKind write FBuildKind;
    property Language: TNXLLVMLanguage read FLanguage write FLanguage;
    property Target: string read FTarget write FTarget;
    property Standard: string read FStandard write FStandard;
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

uses obNXPersist;

constructor TNXLLVMBuildOptions.Create;
begin
  inherited Create;
  FConfigFiles := TStringList.Create;
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
  ASourceArgumentIndex := AArguments.Count;
  for lValue in FLibraries do AArguments.Add('-l' + lValue);
end;

initialization
  TNXPersistObject.RegisterPersistClass(TNXLLVMBuildOptions);

end.
