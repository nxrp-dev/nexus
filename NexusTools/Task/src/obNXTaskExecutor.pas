unit obNXTaskExecutor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, obNXTaskModel, obNXTaskActions, obNXTaskTargets, tpNXTask;

type
  TNXTaskExecutor = class
  private
    FRegistry: TNXTaskActionRegistry;
    FTrace: TStringList;
    FDiagnostics: TNXTaskDiagnostics;
    FTarget: string;
    FWorkingDirectory: string;
    procedure ExecuteNode(ANode: TNXTaskNode; AIndent: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(ADocument: TNXTaskDocument; const ATarget,
      AWorkingDirectory: string): string;
    property Diagnostics: TNXTaskDiagnostics read FDiagnostics;
  end;

implementation

constructor TNXTaskExecutor.Create;
begin
  inherited Create;
  FRegistry := TNXTaskActionRegistry.Create;
  NXTaskRegisterDefaultActions(FRegistry);
  FTrace := TStringList.Create;
  FTrace.LineBreak := #10;
  FDiagnostics := TNXTaskDiagnostics.Create;
end;

destructor TNXTaskExecutor.Destroy;
begin
  FDiagnostics.Free;
  FTrace.Free;
  FRegistry.Free;
  inherited Destroy;
end;

procedure TNXTaskExecutor.ExecuteNode(ANode: TNXTaskNode; AIndent: Integer);
var
  lAction: TNXTaskAction;
  lContext: TNXTaskActionContext;
  lIndex: Integer;
begin
  FTrace.Add(StringOfChar(' ', AIndent * 2) + 'enter ' + ANode.Name);
  lAction := FRegistry.CreateAction(ANode.Action);
  if lAction = nil then
  begin
    FDiagnostics.Add(tdsError, 'NXTask.Execute.UnknownAction',
      'Unknown task action: ' + ANode.Action,
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column));
  end
  else
  begin
    lContext := TNXTaskActionContext.Create(FWorkingDirectory, FTrace, FDiagnostics);
    try
      lAction.Execute(ANode, lContext);
    finally
      lContext.Free;
      lAction.Free;
    end;
  end;

  for lIndex := 0 to ANode.Children.Count - 1 do
    ExecuteNode(TNXTaskNode(ANode.Children[lIndex]), AIndent + 1);

  FTrace.Add(StringOfChar(' ', AIndent * 2) + 'leave ' + ANode.Name);
end;

function TNXTaskExecutor.Execute(ADocument: TNXTaskDocument; const ATarget,
  AWorkingDirectory: string): string;
var
  lIndex: Integer;
  lProjected: TNXTaskDocument;
begin
  FTarget := ATarget;
  FWorkingDirectory := AWorkingDirectory;
  FDiagnostics.Clear;
  FTrace.Clear;
  FTrace.Add('execute target ' + FTarget);
  lProjected := TNXTaskTargetInspector.ProjectDocument(ADocument, ATarget);
  try
    for lIndex := 0 to lProjected.Roots.Count - 1 do
      ExecuteNode(TNXTaskNode(lProjected.Roots[lIndex]), 1);
    Result := FTrace.Text;
  finally
    lProjected.Free;
  end;
end;

end.
