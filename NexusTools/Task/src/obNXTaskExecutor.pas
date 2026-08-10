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
    FEchoProgress: Boolean;
    function ErrorCount: Integer;
    function FormatElapsed(AElapsedMilliseconds: QWord): string;
    procedure ReportTaskComplete(ANode: TNXTaskNode; AIndent: Integer;
      AElapsedMilliseconds: QWord; AStartErrorCount: Integer);
    procedure ExecuteNode(ANode: TNXTaskNode; AIndent: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(ADocument: TNXTaskDocument; const ATarget,
      AWorkingDirectory: string): string;
    property Diagnostics: TNXTaskDiagnostics read FDiagnostics;
    property EchoProgress: Boolean read FEchoProgress write FEchoProgress;
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
  FEchoProgress := False;
end;

destructor TNXTaskExecutor.Destroy;
begin
  FDiagnostics.Free;
  FTrace.Free;
  FRegistry.Free;
  inherited Destroy;
end;

function TNXTaskExecutor.ErrorCount: Integer;
var
  lIndex: Integer;
begin
  Result := 0;
  for lIndex := 0 to FDiagnostics.Count - 1 do
    if FDiagnostics.Item(lIndex).Severity = tdsError then
      Inc(Result);
end;

function TNXTaskExecutor.FormatElapsed(AElapsedMilliseconds: QWord): string;
var
  lHours: QWord;
  lMinutes: QWord;
  lSeconds: QWord;
  lMilliseconds: QWord;
begin
  lMilliseconds := AElapsedMilliseconds mod 1000;
  AElapsedMilliseconds := AElapsedMilliseconds div 1000;
  lSeconds := AElapsedMilliseconds mod 60;
  AElapsedMilliseconds := AElapsedMilliseconds div 60;
  lMinutes := AElapsedMilliseconds mod 60;
  lHours := AElapsedMilliseconds div 60;
  Result := Format('%.2d:%.2d:%.2d.%.3d',
    [lHours, lMinutes, lSeconds, lMilliseconds]);
end;

procedure TNXTaskExecutor.ReportTaskComplete(ANode: TNXTaskNode; AIndent: Integer;
  AElapsedMilliseconds: QWord; AStartErrorCount: Integer);
var
  lStatus: string;
begin
  if ErrorCount > AStartErrorCount then
    lStatus := 'Error'
  else
    lStatus := 'Success';
  if FEchoProgress then
    WriteLn(StringOfChar(' ', AIndent * 2) + '[' + lStatus + '] ' +
      ANode.Name + ' ' + ANode.Action + ' ' + FormatElapsed(AElapsedMilliseconds));
end;

procedure TNXTaskExecutor.ExecuteNode(ANode: TNXTaskNode; AIndent: Integer);
var
  lAction: TNXTaskAction;
  lContext: TNXTaskActionContext;
  lIndex: Integer;
  lStartTick: QWord;
  lStartErrorCount: Integer;
begin
  lStartTick := GetTickCount64;
  lStartErrorCount := ErrorCount;
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
  ReportTaskComplete(ANode, AIndent, GetTickCount64 - lStartTick, lStartErrorCount);
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
