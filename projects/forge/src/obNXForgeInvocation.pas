unit obNXForgeInvocation;

{$mode delphi}{$H+}

interface

uses tpNXForge;

type
  TNXForgeInvocation = class
  private
    FKind: TNXForgeOperationKind;
    FOperationName: string;
    FTemplatePath: string;
    FSourcePath: string;
    FOutputPath: string;
    FArtifactText: string;
    FArchiveOperation: string;
    FExcludeNames: string;
    FOverwrite: Boolean;
    FRecursive: Boolean;
    FCleanDestination: Boolean;
    FMissingOk: Boolean;
    FCommand: string;
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
    property ArtifactText: string read FArtifactText write FArtifactText;
    property ArchiveOperation: string read FArchiveOperation write FArchiveOperation;
    property ExcludeNames: string read FExcludeNames write FExcludeNames;
    property Overwrite: Boolean read FOverwrite write FOverwrite;
    property Recursive: Boolean read FRecursive write FRecursive;
    property CleanDestination: Boolean read FCleanDestination write FCleanDestination;
    property MissingOk: Boolean read FMissingOk write FMissingOk;
    property Command: string read FCommand write FCommand;
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
