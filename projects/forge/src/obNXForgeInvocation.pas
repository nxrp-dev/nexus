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
  if FKind = fokRender then Result := FCompleted and (FDiagnostic = '')
  else Result := FExited and (FExitStatus = 0) and (FDiagnostic = '');
end;

end.
