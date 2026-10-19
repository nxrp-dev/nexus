(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXForgeInvocation;

{$mode delphi}{$H+}

interface

uses SysUtils, tpNXForge;

type
  TNXForgeInvocation = class
  private
    FKind: TNXForgeOperationKind;
    FOperationName: string;
    FTemplatePath: string;
    FSourcePath: string;
    FOutputPath: string;
    FLeftPath: string;
    FRightPath: string;
    FArtifactText: string;
    FArchiveOperation: string;
    FExcludeNames: string;
    FIncludeMasks: TStringArray;
    FPackageDirectories: TStringArray;
    FPackageName: string;
    FPackageKind: string;
    FOverwrite: Boolean;
    FRecursive: Boolean;
    FCleanDestination: Boolean;
    FMissingOk: Boolean;
    FCommand: string;
    FCommandTemplate: string;
    FCommandContext: string;
    FSourceDirectory: string;
    FWorkingDirectory: string;
    FStdOut: string;
    FStdErr: string;
    FDiagnostic: string;
    FStarted: Boolean;
    FCompleted: Boolean;
    FExited: Boolean;
    FExitStatus: Integer;
  public
    function Succeeded: Boolean;
    property Kind: TNXForgeOperationKind read FKind write FKind;
    property OperationName: string read FOperationName write FOperationName;
    property TemplatePath: string read FTemplatePath write FTemplatePath;
    property SourcePath: string read FSourcePath write FSourcePath;
    property OutputPath: string read FOutputPath write FOutputPath;
    property LeftPath: string read FLeftPath write FLeftPath;
    property RightPath: string read FRightPath write FRightPath;
    property ArtifactText: string read FArtifactText write FArtifactText;
    property ArchiveOperation: string read FArchiveOperation write FArchiveOperation;
    property ExcludeNames: string read FExcludeNames write FExcludeNames;
    property IncludeMasks: TStringArray read FIncludeMasks write FIncludeMasks;
    property PackageDirectories: TStringArray read FPackageDirectories write FPackageDirectories;
    property PackageName: string read FPackageName write FPackageName;
    property PackageKind: string read FPackageKind write FPackageKind;
    property Overwrite: Boolean read FOverwrite write FOverwrite;
    property Recursive: Boolean read FRecursive write FRecursive;
    property CleanDestination: Boolean read FCleanDestination write FCleanDestination;
    property MissingOk: Boolean read FMissingOk write FMissingOk;
    property Command: string read FCommand write FCommand;
    property CommandTemplate: string read FCommandTemplate write FCommandTemplate;
    property CommandContext: string read FCommandContext write FCommandContext;
    property SourceDirectory: string read FSourceDirectory write FSourceDirectory;
    property WorkingDirectory: string read FWorkingDirectory write FWorkingDirectory;
    property StdOut: string read FStdOut write FStdOut;
    property StdErr: string read FStdErr write FStdErr;
    property Diagnostic: string read FDiagnostic write FDiagnostic;
    property Started: Boolean read FStarted write FStarted;
    property Completed: Boolean read FCompleted write FCompleted;
    property Exited: Boolean read FExited write FExited;
    property ExitStatus: Integer read FExitStatus write FExitStatus;
  end;

implementation

function TNXForgeInvocation.Succeeded: Boolean;
begin
  if FKind <> fokCommand then Result := FCompleted and (FDiagnostic = '')
  else Result := FExited and (FExitStatus = 0) and (FDiagnostic = '');
end;

end.
