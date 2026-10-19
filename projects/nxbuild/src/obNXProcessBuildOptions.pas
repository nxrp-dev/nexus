(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXProcessBuildOptions;

{$mode objfpc}{$H+}

interface

uses Classes, obNXBuildEntry;

type
  TNXProcessBuildOptions = class(TNXBuildEntry)
  private
    FExecutable: string;
    FArguments: TStringList;
    FWorkingDirectory: string;
  public
    constructor Create; override;
    destructor Destroy; override;
    function BuildType: string; override;
    function DefaultCompiler: string; override;
    function RequiresSources: Boolean; override;
    function WorkingDirectory: string; override;
    procedure ResolvePaths(const ARoot: string); override;
    procedure AppendArguments(AArguments: TStrings; out ASourceArgumentIndex: Integer); override;
  published
    property Executable: string read FExecutable write FExecutable;
    property Arguments: TStringList read FArguments;
    property Directory: string read FWorkingDirectory write FWorkingDirectory;
  end;

implementation

constructor TNXProcessBuildOptions.Create;
begin
  inherited Create;
  FArguments := TStringList.Create;
end;

destructor TNXProcessBuildOptions.Destroy;
begin
  FArguments.Free;
  inherited Destroy;
end;

function TNXProcessBuildOptions.BuildType: string;
begin
  Result := 'Process';
end;

function TNXProcessBuildOptions.DefaultCompiler: string;
begin
  Result := FExecutable;
end;

function TNXProcessBuildOptions.RequiresSources: Boolean;
begin
  Result := False;
end;

function TNXProcessBuildOptions.WorkingDirectory: string;
begin
  if FWorkingDirectory = '' then Result := OutputPath
  else Result := FWorkingDirectory;
end;

procedure TNXProcessBuildOptions.ResolvePaths(const ARoot: string);
begin
  inherited ResolvePaths(ARoot);
  if FWorkingDirectory <> '' then
    FWorkingDirectory := ResolvePath(FWorkingDirectory, ARoot);
end;

procedure TNXProcessBuildOptions.AppendArguments(AArguments: TStrings;
  out ASourceArgumentIndex: Integer);
begin
  AArguments.AddStrings(FArguments);
  ASourceArgumentIndex := AArguments.Count;
end;

end.
