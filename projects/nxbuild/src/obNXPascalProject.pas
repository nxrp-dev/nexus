(*
  Copyright (c) 2026 Kevin Collins.
  
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  
  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.
  
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

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

  TNXPascalBuildTool = (
    pbtUnknown,
    pbtFPC,
    pbtLazarus
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
    FBuildFile: string;
    FBuildTool: TNXPascalBuildTool;
    FProjectKind: TNXPascalProjectKind;
    FProjectFileName: string;
    FProjectRoot: string;
    FSourceRoot: string;
    FOutputRoot: string;
    FLazarusProjectFile: string;
    FTargetPlatform: TNXPascalTargetPlatform;
    FToolchain: TNXPascalToolchain;
    FFPCBuildOptions: TNXFPCBuildOptions;

    procedure ResolvePathList(AValues: TStrings);
  public
    constructor Create; override;
    destructor Destroy; override;

    function ResolvePath(const APath: string): string;
    procedure ResolvePaths(AInput: TStrings; AOutput: TStrings);
    procedure ApplyToBuildOptions;
    procedure ResolveBuildOptionPaths;

  published
    property BuildFile: string read FBuildFile write FBuildFile;
    property BuildTool: TNXPascalBuildTool read FBuildTool write FBuildTool;
    property ProjectKind: TNXPascalProjectKind read FProjectKind write FProjectKind;
    property ProjectFileName: string read FProjectFileName write FProjectFileName;
    property ProjectRoot: string read FProjectRoot write FProjectRoot;
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property OutputRoot: string read FOutputRoot write FOutputRoot;
    property LazarusProjectFile: string read FLazarusProjectFile write FLazarusProjectFile;
    property TargetPlatform: TNXPascalTargetPlatform read FTargetPlatform;
    property Toolchain: TNXPascalToolchain read FToolchain;
    property FPCBuildOptions: TNXFPCBuildOptions read FFPCBuildOptions;
  end;

implementation

constructor TNXPascalProject.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FTargetPlatform := TNXPascalTargetPlatform.Create;
  FToolchain := TNXPascalToolchain.Create;
  FFPCBuildOptions := TNXFPCBuildOptions.Create;
  FFPCBuildOptions.Syntax.COperators := fssEnabled;
end;

destructor TNXPascalProject.Destroy;
begin
  FFPCBuildOptions.Free;
  FToolchain.Free;
  FTargetPlatform.Free;
  inherited Destroy;
end;

function TNXPascalProject.ResolvePath(const APath: string): string;
var
  lPath: string;
begin
  lPath := APath;
  if lPath = '' then
    Exit('');

  if (FProjectRoot <> '') and not FilenameIsAbsolute(lPath) then
    lPath := IncludeTrailingPathDelimiter(FProjectRoot) + lPath;

  Result := ExpandFileName(lPath);
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

procedure TNXPascalProject.ResolvePathList(AValues: TStrings);
var
  lIndex: Integer;
begin
  if AValues = nil then
    Exit;

  for lIndex := 0 to AValues.Count - 1 do
    AValues[lIndex] := ResolvePath(AValues[lIndex]);
end;

procedure TNXPascalProject.ApplyToBuildOptions;
begin
  FFPCBuildOptions.CompilerPath := FToolchain.CompilerPath;
  if ExtractFilePath(FFPCBuildOptions.CompilerPath) <> '' then
    FFPCBuildOptions.CompilerPath := ResolvePath(FFPCBuildOptions.CompilerPath);
  FBuildFile := ResolvePath(FBuildFile);
  FLazarusProjectFile := ResolvePath(FLazarusProjectFile);
  FFPCBuildOptions.InputFile := ResolvePath(FFPCBuildOptions.InputFile);
  FFPCBuildOptions.OutputFile := ResolvePath(FFPCBuildOptions.OutputFile);
  FFPCBuildOptions.Target.OperatingSystem := FTargetPlatform.TargetOS;
  ResolveBuildOptionPaths;
end;

procedure TNXPascalProject.ResolveBuildOptionPaths;
begin
  ResolvePathList(FFPCBuildOptions.Config.OptionFiles);
  ResolvePathList(FFPCBuildOptions.Files.FrameworkPaths);
  ResolvePathList(FFPCBuildOptions.Files.IncludePaths);
  ResolvePathList(FFPCBuildOptions.Files.LibraryPaths);
  ResolvePathList(FFPCBuildOptions.Files.ObjectPaths);
  ResolvePathList(FFPCBuildOptions.Files.UnitPaths);

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
