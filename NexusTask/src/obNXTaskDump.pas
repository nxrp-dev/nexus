unit obNXTaskDump;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, obNXTaskModel, tpNXTask;

type
  TNXTaskDumper = class
  private
    class procedure DumpNode(ALines: TStrings; ANode: TNXTaskNode; AIndent: Integer;
      AIncludeReferences: Boolean);
    class procedure AddLine(ALines: TStrings; AIndent: Integer; const AText: string);
  public
    class function DumpDocument(ADocument: TNXTaskDocument;
      AIncludeReferences: Boolean): string;
    class function DumpDiagnostics(ADiagnostics: TNXTaskDiagnostics): string;
  end;

implementation

class procedure TNXTaskDumper.AddLine(ALines: TStrings; AIndent: Integer;
  const AText: string);
begin
  ALines.Add(StringOfChar(' ', AIndent * 2) + AText);
end;

class procedure TNXTaskDumper.DumpNode(ALines: TStrings; ANode: TNXTaskNode;
  AIndent: Integer; AIncludeReferences: Boolean);
var
  lIndex: Integer;
  lTargets: string;
  lProperty: TNXTaskProperty;
  lChild: TNXTaskNode;
  lExpansion: TNXTaskNodeReference;
  lBodyItem: TNXTaskBodyItem;
begin
  if ANode.Targets.Count > 0 then
    lTargets := ' targets(' + StringReplace(ANode.Targets.CommaText, ',', ', ',
      [rfReplaceAll]) + ')'
  else
    lTargets := ' targets(*)';

  AddLine(ALines, AIndent, Format('task %s action %s%s',
    [ANode.Name, ANode.Action, lTargets]));

  if AIncludeReferences then
  begin
    for lIndex := 0 to ANode.BodyItems.Count - 1 do
    begin
      lBodyItem := TNXTaskBodyItem(ANode.BodyItems[lIndex]);
      case lBodyItem.Kind of
        tbikProperty:
          begin
            lProperty := TNXTaskProperty(lBodyItem.Item);
            AddLine(ALines, AIndent + 1, Format('property %s = %s',
              [lProperty.Name, lProperty.Value.CanonicalText]));
          end;
        tbikChild:
          begin
            lChild := TNXTaskNode(lBodyItem.Item);
            DumpNode(ALines, lChild, AIndent + 1, AIncludeReferences);
          end;
        tbikExpansion:
          begin
            lExpansion := TNXTaskNodeReference(lBodyItem.Item);
            if lExpansion.Reference.ExternalFile <> '' then
              AddLine(ALines, AIndent + 1, 'expand ' +
                NXTaskQuoteString(lExpansion.Reference.ExternalFile) + ':' +
                lExpansion.Reference.Path)
            else
              AddLine(ALines, AIndent + 1, 'expand ' + lExpansion.Reference.Path);
          end;
      end;
    end;
    Exit;
  end;

  for lIndex := 0 to ANode.Properties.Count - 1 do
  begin
    lProperty := TNXTaskProperty(ANode.Properties[lIndex]);
    AddLine(ALines, AIndent + 1, Format('property %s = %s',
      [lProperty.Name, lProperty.Value.CanonicalText]));
  end;
  for lIndex := 0 to ANode.Children.Count - 1 do
  begin
    lChild := TNXTaskNode(ANode.Children[lIndex]);
    DumpNode(ALines, lChild, AIndent + 1, AIncludeReferences);
  end;
end;

class function TNXTaskDumper.DumpDocument(ADocument: TNXTaskDocument;
  AIncludeReferences: Boolean): string;
var
  lLines: TStringList;
  lIndex: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.LineBreak := #10;
    lLines.Add('document ' + ADocument.FileName);
    for lIndex := 0 to ADocument.Roots.Count - 1 do
      DumpNode(lLines, TNXTaskNode(ADocument.Roots[lIndex]), 1, AIncludeReferences);
    Result := lLines.Text;
  finally
    lLines.Free;
  end;
end;

class function TNXTaskDumper.DumpDiagnostics(ADiagnostics: TNXTaskDiagnostics): string;
var
  lLines: TStringList;
  lIndex: Integer;
  lRelatedIndex: Integer;
  lDiagnostic: TNXTaskDiagnostic;
begin
  lLines := TStringList.Create;
  try
    lLines.LineBreak := #10;
    lLines.Add('diagnostics ' + IntToStr(ADiagnostics.Count));
    for lIndex := 0 to ADiagnostics.Count - 1 do
    begin
      lDiagnostic := ADiagnostics.Item(lIndex);
      lLines.Add(lDiagnostic.Text);
      for lRelatedIndex := 0 to lDiagnostic.Related.Count - 1 do
        lLines.Add('  related ' + lDiagnostic.Related[lRelatedIndex]);
    end;
    Result := lLines.Text;
  finally
    lLines.Free;
  end;
end;

end.
