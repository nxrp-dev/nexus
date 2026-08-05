unit obNXTaskValidation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, obNXTaskModel, tpNXTask;

type
  TNXTaskValidator = class
  private
    procedure ValidateNode(ANode: TNXTaskNode; ADiagnostics: TNXTaskDiagnostics);
    procedure ValidateNodeList(AList: TList; ADiagnostics: TNXTaskDiagnostics;
      const AKind: string);
  public
    procedure ValidateDocument(ADocument: TNXTaskDocument);
  end;

implementation

procedure TNXTaskValidator.ValidateNodeList(AList: TList;
  ADiagnostics: TNXTaskDiagnostics; const AKind: string);
var
  lSeen: TStringList;
  lIndex: Integer;
  lExisting: Integer;
  lNode: TNXTaskNode;
  lOriginal: TNXTaskNode;
begin
  lSeen := TStringList.Create;
  try
    lSeen.CaseSensitive := True;
    for lIndex := 0 to AList.Count - 1 do
    begin
      lNode := TNXTaskNode(AList[lIndex]);
      lExisting := lSeen.IndexOf(lNode.Name);
      if lExisting >= 0 then
      begin
        lOriginal := TNXTaskNode(lSeen.Objects[lExisting]);
        ADiagnostics.AddWithRelated(tdsError, 'NXTask.Validate.DuplicateTask',
          Format('Duplicate %s task name "%s".', [AKind, lNode.Name]),
          TNXTaskSourceRange.Create(lNode.SourceRange.FileName, lNode.SourceRange.Line,
            lNode.SourceRange.Column),
          'Original declaration: ' + lOriginal.SourceRange.Text);
      end
      else
        lSeen.AddObject(lNode.Name, lNode);
    end;
  finally
    lSeen.Free;
  end;
end;

procedure TNXTaskValidator.ValidateNode(ANode: TNXTaskNode;
  ADiagnostics: TNXTaskDiagnostics);
var
  lSeen: TStringList;
  lIndex: Integer;
  lExisting: Integer;
  lProperty: TNXTaskProperty;
  lOriginal: TNXTaskProperty;
begin
  lSeen := TStringList.Create;
  try
    lSeen.CaseSensitive := True;
    for lIndex := 0 to ANode.Properties.Count - 1 do
    begin
      lProperty := TNXTaskProperty(ANode.Properties[lIndex]);
      lExisting := lSeen.IndexOf(lProperty.Name);
      if lExisting >= 0 then
      begin
        lOriginal := TNXTaskProperty(lSeen.Objects[lExisting]);
        ADiagnostics.AddWithRelated(tdsError, 'NXTask.Validate.DuplicateProperty',
          Format('Duplicate property "%s" on task "%s".', [lProperty.Name, ANode.Name]),
          TNXTaskSourceRange.Create(lProperty.SourceRange.FileName,
            lProperty.SourceRange.Line, lProperty.SourceRange.Column),
          'Original declaration: ' + lOriginal.SourceRange.Text);
      end
      else
        lSeen.AddObject(lProperty.Name, lProperty);
    end;
  finally
    lSeen.Free;
  end;

  ValidateNodeList(ANode.Children, ADiagnostics, 'sibling');
  for lIndex := 0 to ANode.Children.Count - 1 do
    ValidateNode(TNXTaskNode(ANode.Children[lIndex]), ADiagnostics);
end;

procedure TNXTaskValidator.ValidateDocument(ADocument: TNXTaskDocument);
var
  lIndex: Integer;
begin
  ValidateNodeList(ADocument.Roots, ADocument.Diagnostics, 'root');
  for lIndex := 0 to ADocument.Roots.Count - 1 do
    ValidateNode(TNXTaskNode(ADocument.Roots[lIndex]), ADocument.Diagnostics);
end;

end.
