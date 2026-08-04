unit obNXTaskTargets;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, obNXTaskModel, tpNXTask;

type
  TNXTaskTargetInspector = class
  private
    class function IncludeNode(ANode: TNXTaskNode; const ATarget: string;
      out AApplicability: TNXTaskApplicability): Boolean;
    class function ProjectNode(ANode: TNXTaskNode; const ATarget: string): TNXTaskNode;
    class procedure InspectNode(ALines: TStrings; ANode: TNXTaskNode;
      AIndent: Integer);
  public
    class function ProjectDocument(ADocument: TNXTaskDocument;
      const ATarget: string): TNXTaskDocument;
    class function Inspect(ADocument: TNXTaskDocument; const ATarget: string): string;
  end;

implementation

class function TNXTaskTargetInspector.IncludeNode(ANode: TNXTaskNode;
  const ATarget: string;
  out AApplicability: TNXTaskApplicability): Boolean;
begin
  if ANode.Targets.Count = 0 then
  begin
    AApplicability := taaAppliesInherited;
    Exit(True);
  end;
  if ANode.HasTarget(ATarget) then
  begin
    AApplicability := taaAppliesExplicit;
    Exit(True);
  end;
  AApplicability := taaSkippedOwnTarget;
  Result := False;
end;

class function TNXTaskTargetInspector.ProjectNode(ANode: TNXTaskNode;
  const ATarget: string): TNXTaskNode;
var
  lApplicability: TNXTaskApplicability;
  lIndex: Integer;
  lChild: TNXTaskNode;
  lProjectedChild: TNXTaskNode;
begin
  Result := nil;
  if not IncludeNode(ANode, ATarget, lApplicability) then
    Exit;

  Result := ANode.CloneShallow;
  Result.ClearChildren;
  for lIndex := 0 to ANode.Children.Count - 1 do
  begin
    lChild := TNXTaskNode(ANode.Children[lIndex]);
    lProjectedChild := ProjectNode(lChild, ATarget);
    if lProjectedChild <> nil then
      Result.AddChild(lProjectedChild);
  end;
end;

class function TNXTaskTargetInspector.ProjectDocument(ADocument: TNXTaskDocument;
  const ATarget: string): TNXTaskDocument;
var
  lIndex: Integer;
  lProjected: TNXTaskNode;
begin
  Result := TNXTaskDocument.Create(ADocument.FileName);
  for lIndex := 0 to ADocument.Roots.Count - 1 do
  begin
    lProjected := ProjectNode(TNXTaskNode(ADocument.Roots[lIndex]), ATarget);
    if lProjected <> nil then
      Result.Roots.Add(lProjected);
  end;
end;

class procedure TNXTaskTargetInspector.InspectNode(ALines: TStrings;
  ANode: TNXTaskNode; AIndent: Integer);
var
  lIndex: Integer;
begin
  ALines.Add(StringOfChar(' ', AIndent * 2) + Format('%s %s',
    [ANode.Name, ANode.Action]));
  for lIndex := 0 to ANode.Children.Count - 1 do
    InspectNode(ALines, TNXTaskNode(ANode.Children[lIndex]), AIndent + 1);
end;

class function TNXTaskTargetInspector.Inspect(ADocument: TNXTaskDocument;
  const ATarget: string): string;
var
  lLines: TStringList;
  lProjected: TNXTaskDocument;
  lIndex: Integer;
begin
  lLines := TStringList.Create;
  lProjected := ProjectDocument(ADocument, ATarget);
  try
    lLines.LineBreak := #10;
    lLines.Add('inspect target ' + ATarget);
    for lIndex := 0 to lProjected.Roots.Count - 1 do
      InspectNode(lLines, TNXTaskNode(lProjected.Roots[lIndex]), 1);
    Result := lLines.Text;
  finally
    lProjected.Free;
    lLines.Free;
  end;
end;

end.
