unit obNXTaskActions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, obNXTaskModel, tpNXTask;

type
  TNXTaskActionContext = class
  private
    FWorkingDirectory: string;
    FTrace: TStrings;
    FDiagnostics: TNXTaskDiagnostics;
  public
    constructor Create(const AWorkingDirectory: string; ATrace: TStrings;
      ADiagnostics: TNXTaskDiagnostics);
    property WorkingDirectory: string read FWorkingDirectory;
    property Trace: TStrings read FTrace;
    property Diagnostics: TNXTaskDiagnostics read FDiagnostics;
  end;

  TNXTaskAction = class
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); virtual; abstract;
  end;

  TNXTaskActionClass = class of TNXTaskAction;

  TNXTaskActionRegistry = class
  private
    FNames: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterAction(const AName: string; AClass: TNXTaskActionClass);
    function CreateAction(const AName: string): TNXTaskAction;
    function KnowsAction(const AName: string): Boolean;
  end;

procedure NXTaskRegisterDefaultActions(ARegistry: TNXTaskActionRegistry);

implementation

type
  TNXTaskGroupAction = class(TNXTaskAction)
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskTraceAction = class(TNXTaskAction)
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskAssertAction = class(TNXTaskAction)
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskWriteTextFileAction = class(TNXTaskAction)
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

function NXTaskPropertyText(ANode: TNXTaskNode; const AName: string;
  out AValue: string): Boolean;
var
  lProperty: TNXTaskProperty;
begin
  lProperty := ANode.PropertyByName(AName);
  Result := (lProperty <> nil) and (lProperty.Value.Kind = tvkString);
  if Result then
    AValue := lProperty.Value.StringValue
  else
    AValue := '';
end;

constructor TNXTaskActionContext.Create(const AWorkingDirectory: string;
  ATrace: TStrings; ADiagnostics: TNXTaskDiagnostics);
begin
  inherited Create;
  FWorkingDirectory := AWorkingDirectory;
  FTrace := ATrace;
  FDiagnostics := ADiagnostics;
end;

constructor TNXTaskActionRegistry.Create;
begin
  inherited Create;
  FNames := TStringList.Create;
  FNames.CaseSensitive := True;
end;

destructor TNXTaskActionRegistry.Destroy;
begin
  FNames.Free;
  inherited Destroy;
end;

procedure TNXTaskActionRegistry.RegisterAction(const AName: string;
  AClass: TNXTaskActionClass);
begin
  FNames.AddObject(AName, TObject(AClass));
end;

function TNXTaskActionRegistry.CreateAction(const AName: string): TNXTaskAction;
var
  lIndex: Integer;
begin
  lIndex := FNames.IndexOf(AName);
  if lIndex < 0 then
    Exit(nil);
  Result := TNXTaskActionClass(FNames.Objects[lIndex]).Create;
end;

function TNXTaskActionRegistry.KnowsAction(const AName: string): Boolean;
begin
  Result := FNames.IndexOf(AName) >= 0;
end;

procedure TNXTaskGroupAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
begin
  AContext.Trace.Add('action Group ' + ANode.Name);
end;

procedure TNXTaskTraceAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lMessage: string;
begin
  if not NXTaskPropertyText(ANode, 'Message', lMessage) then
  begin
    AContext.Diagnostics.Add(tdsError, 'NXTask.Action.Trace.Message',
      'Trace action requires string property Message.',
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column));
    Exit;
  end;
  AContext.Trace.Add('trace ' + ANode.Name + ' ' + NXTaskQuoteString(lMessage));
end;

procedure TNXTaskAssertAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lExpected: string;
  lActual: string;
begin
  NXTaskPropertyText(ANode, 'Expected', lExpected);
  NXTaskPropertyText(ANode, 'Actual', lActual);
  if lExpected <> lActual then
    AContext.Diagnostics.Add(tdsError, 'NXTask.Action.Assert',
      Format('Assert failed on "%s": expected "%s" actual "%s".',
      [ANode.Name, lExpected, lActual]),
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column))
  else
    AContext.Trace.Add('assert ' + ANode.Name + ' passed');
end;

procedure TNXTaskWriteTextFileAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lPath: string;
  lText: string;
  lFullPath: string;
  lFile: TStringList;
begin
  if not NXTaskPropertyText(ANode, 'Path', lPath) then
  begin
    AContext.Diagnostics.Add(tdsError, 'NXTask.Action.WriteTextFile.Path',
      'WriteTextFile requires string property Path.',
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column));
    Exit;
  end;
  if not NXTaskPropertyText(ANode, 'Text', lText) then
  begin
    AContext.Diagnostics.Add(tdsError, 'NXTask.Action.WriteTextFile.Text',
      'WriteTextFile requires string property Text.',
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column));
    Exit;
  end;
  if ExtractFileDrive(lPath) <> '' then
    lFullPath := ExpandFileName(lPath)
  else
    lFullPath := ExpandFileName(IncludeTrailingPathDelimiter(AContext.WorkingDirectory) +
      lPath);
  if ExtractFileDir(lFullPath) <> '' then
    ForceDirectories(ExtractFileDir(lFullPath));
  lFile := TStringList.Create;
  try
    lFile.LineBreak := #10;
    lFile.Text := lText;
    lFile.SaveToFile(lFullPath);
  finally
    lFile.Free;
  end;
  AContext.Trace.Add('write ' + NXTaskQuoteString(lFullPath));
end;

procedure NXTaskRegisterDefaultActions(ARegistry: TNXTaskActionRegistry);
begin
  ARegistry.RegisterAction('Group', TNXTaskGroupAction);
  ARegistry.RegisterAction('Trace', TNXTaskTraceAction);
  ARegistry.RegisterAction('Assert', TNXTaskAssertAction);
  ARegistry.RegisterAction('WriteTextFile', TNXTaskWriteTextFileAction);
end;

end.
