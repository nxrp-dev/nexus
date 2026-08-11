unit obNXTaskActions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, Zipper, obNXTaskModel, tpNXTask;

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

  TNXTaskWriteTextFileAction = class(TNXTaskAction)
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskCopyFileAction = class(TNXTaskAction)
  private
    procedure AddDiagnostic(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ACode, AMessage: string);
    procedure BuildExcludeNames(ANode: TNXTaskNode; AExcludeNames: TStrings);
    function CopyDirectory(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ASource, ADestination: string; AOverwrite: Boolean;
      AExcludeNames: TStrings): Boolean;
    function CopyOneFile(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ASource, ADestination: string; AOverwrite: Boolean): Boolean;
    function IsExcludedName(const AName: string; AExcludeNames: TStrings): Boolean;
    function OptionalBoolean(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; ADefault: Boolean; out AValue: Boolean): Boolean;
    procedure RemoveDirectoryTree(const APath: string);
    function RequiredString(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; out AValue: string): Boolean;
    function ResolvePath(const AWorkingDirectory, APath: string): string;
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskDeletePathAction = class(TNXTaskAction)
  private
    procedure AddDiagnostic(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ACode, AMessage: string);
    function DeleteDirectoryTree(const APath: string): Boolean;
    function DeleteMatchingFiles(ANode: TNXTaskNode;
      AContext: TNXTaskActionContext; const ARoot, AMask: string;
      ARecursive: Boolean): Boolean;
    function OptionalBoolean(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; ADefault: Boolean; out AValue: Boolean): Boolean;
    function RequiredString(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; out AValue: string): Boolean;
    function ResolvePath(const AWorkingDirectory, APath: string): string;
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskArchiveAction = class(TNXTaskAction)
  private
    procedure AddDiagnostic(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ACode, AMessage: string);
    procedure AddDirectoryEntries(ANode: TNXTaskNode;
      AContext: TNXTaskActionContext; AEntries: TZipFileEntries;
      AExcludeNames: TStrings; const ASourceRoot, ACurrentPath: string;
      ARecursive: Boolean);
    procedure BuildExcludeNames(ANode: TNXTaskNode; AExcludeNames: TStrings);
    procedure ExecuteUnzip(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ASource, ADestination: string; AOverwrite: Boolean);
    procedure ExecuteZip(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ASource, ADestination: string; ARecursive, AOverwrite: Boolean;
      AExcludeNames: TStrings);
    function IsExcludedName(const AName: string; AExcludeNames: TStrings): Boolean;
    function OptionalBoolean(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; ADefault: Boolean; out AValue: Boolean): Boolean;
    function RequiredString(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; out AValue: string): Boolean;
    function ResolvePath(const AWorkingDirectory, APath: string): string;
    function ZipEntryName(const ASourceRoot, AFileName: string): string;
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskGitAction = class(TNXTaskAction)
  private
    function OptionalBoolean(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; ADefault: Boolean; out AValue: Boolean): Boolean;
    function RunGit(const AWorkingDirectory: string; AArguments: array of string;
      out AOutput: string): Integer;
    function RequiredString(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; out AValue: string): Boolean;
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskNpmAction = class(TNXTaskAction)
  private
    procedure AddDiagnostic(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ACode, AMessage: string);
    procedure AddSplitArguments(AArguments: TStrings; const AText: string);
    function OptionalString(ANode: TNXTaskNode; const AName: string;
      out AValue: string): Boolean;
    function ResolvePath(const AWorkingDirectory, APath: string): string;
    function RunNpm(const AExecutable, AWorkingDirectory: string;
      AArguments: TStrings; out AOutput: string): Integer;
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskFpcAction = class(TNXTaskAction)
  private
    procedure AddDiagnostic(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const ACode, AMessage: string);
    procedure AddSplitPaths(AArguments: TStrings; const ASwitch,
      AWorkingDirectory, AText: string);
    function OptionalString(ANode: TNXTaskNode; const AName: string;
      out AValue: string): Boolean;
    function RequiredString(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; out AValue: string): Boolean;
    function ResolvePath(const AWorkingDirectory, APath: string): string;
    function RunFpc(const AExecutable, AWorkingDirectory: string;
      AArguments: TStrings; out AOutput: string): Integer;
  public
    procedure Execute(ANode: TNXTaskNode; AContext: TNXTaskActionContext); override;
  end;

  TNXTaskLazBuildAction = class(TNXTaskAction)
  private
    function OptionalBoolean(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; ADefault: Boolean; out AValue: Boolean): Boolean;
    function OptionalString(ANode: TNXTaskNode; const AName: string;
      out AValue: string): Boolean;
    function RequiredString(ANode: TNXTaskNode; AContext: TNXTaskActionContext;
      const AName: string; out AValue: string): Boolean;
    function RunLazBuild(const AExecutable, AWorkingDirectory: string;
      AArguments: TStrings; out AOutput: string): Integer;
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

procedure TNXTaskCopyFileAction.AddDiagnostic(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ACode, AMessage: string);
begin
  AContext.Diagnostics.Add(tdsError, ACode, AMessage,
    TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
      ANode.SourceRange.Column));
end;

function TNXTaskCopyFileAction.RequiredString(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
  if not Result then
    AddDiagnostic(ANode, AContext, 'NXTask.Action.CopyFile.' + AName,
      'CopyFile action requires string property ' + AName + '.');
end;

function TNXTaskCopyFileAction.OptionalBoolean(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; ADefault: Boolean;
  out AValue: Boolean): Boolean;
var
  lProperty: TNXTaskProperty;
begin
  Result := True;
  AValue := ADefault;
  lProperty := ANode.PropertyByName(AName);
  if lProperty = nil then
    Exit;
  if lProperty.Value.Kind = tvkBoolean then
  begin
    AValue := lProperty.Value.BooleanValue;
    Exit;
  end;

  Result := False;
  AddDiagnostic(ANode, AContext, 'NXTask.Action.CopyFile.' + AName,
    'CopyFile action requires boolean property ' + AName + '.');
end;

function TNXTaskCopyFileAction.ResolvePath(const AWorkingDirectory,
  APath: string): string;
begin
  if ExtractFileDrive(APath) <> '' then
    Result := ExpandFileName(APath)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(AWorkingDirectory) +
      APath);
end;

procedure TNXTaskCopyFileAction.BuildExcludeNames(ANode: TNXTaskNode;
  AExcludeNames: TStrings);
var
  lIndex: Integer;
  lName: string;
  lText: string;
  lParts: TStringList;
begin
  AExcludeNames.Clear;
  if not NXTaskPropertyText(ANode, 'ExcludeNames', lText) then
    Exit;

  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := ';';
    lParts.DelimitedText := lText;
    for lIndex := 0 to lParts.Count - 1 do
    begin
      lName := Trim(lParts[lIndex]);
      if lName <> '' then
        AExcludeNames.Add(lName);
    end;
  finally
    lParts.Free;
  end;
end;

function TNXTaskCopyFileAction.IsExcludedName(const AName: string;
  AExcludeNames: TStrings): Boolean;
begin
  Result := (AExcludeNames <> nil) and (AExcludeNames.IndexOf(AName) >= 0);
end;

procedure TNXTaskCopyFileAction.RemoveDirectoryTree(const APath: string);
var
  lChild: string;
  lSearch: TSearchRec;
begin
  if not DirectoryExists(APath) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, lSearch) = 0 then
  begin
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') then
        begin
          lChild := IncludeTrailingPathDelimiter(APath) + lSearch.Name;
          if (lSearch.Attr and faDirectory) <> 0 then
            RemoveDirectoryTree(lChild)
          else
            DeleteFile(lChild);
        end;
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;
  RemoveDir(APath);
end;

function TNXTaskCopyFileAction.CopyOneFile(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ASource, ADestination: string;
  AOverwrite: Boolean): Boolean;
var
  lDestination: string;
  lInput: TFileStream;
  lOutput: TFileStream;
begin
  Result := False;
  lDestination := ADestination;
  if DirectoryExists(lDestination) then
    lDestination := IncludeTrailingPathDelimiter(lDestination) +
      ExtractFileName(ASource);

  if FileExists(lDestination) and not AOverwrite then
  begin
    AddDiagnostic(ANode, AContext, 'NXTask.Action.CopyFile.Exists',
      'CopyFile destination already exists: ' + lDestination);
    Exit;
  end;

  if ExtractFileDir(lDestination) <> '' then
    ForceDirectories(ExtractFileDir(lDestination));

  lInput := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    lOutput := TFileStream.Create(lDestination, fmCreate);
    try
      lOutput.CopyFrom(lInput, 0);
    finally
      lOutput.Free;
    end;
  finally
    lInput.Free;
  end;

  AContext.Trace.Add('copy ' + NXTaskQuoteString(ASource) + ' ' +
    NXTaskQuoteString(lDestination));
  Result := True;
end;

function TNXTaskCopyFileAction.CopyDirectory(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ASource, ADestination: string;
  AOverwrite: Boolean; AExcludeNames: TStrings): Boolean;
var
  lDestination: string;
  lSearch: TSearchRec;
  lSource: string;
begin
  Result := True;
  if FileExists(ADestination) then
  begin
    AddDiagnostic(ANode, AContext, 'NXTask.Action.CopyFile.Destination',
      'CopyFile recursive destination is a file: ' + ADestination);
    Exit(False);
  end;
  ForceDirectories(ADestination);

  if FindFirst(IncludeTrailingPathDelimiter(ASource) + '*', faAnyFile, lSearch) = 0 then
  begin
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') then
        begin
          if IsExcludedName(lSearch.Name, AExcludeNames) then
            Continue;
          lSource := IncludeTrailingPathDelimiter(ASource) + lSearch.Name;
          lDestination := IncludeTrailingPathDelimiter(ADestination) +
            lSearch.Name;
          if (lSearch.Attr and faDirectory) <> 0 then
          begin
            if not CopyDirectory(ANode, AContext, lSource, lDestination,
              AOverwrite, AExcludeNames) then
              Result := False;
          end
          else if not CopyOneFile(ANode, AContext, lSource, lDestination,
            AOverwrite) then
            Result := False;
        end;
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;
end;

procedure TNXTaskCopyFileAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lDestination: string;
  lExcludeNames: TStringList;
  lFullDestination: string;
  lFullSource: string;
  lCleanDestination: Boolean;
  lOverwrite: Boolean;
  lRecursive: Boolean;
  lSource: string;
begin
  if not RequiredString(ANode, AContext, 'Source', lSource) then
    Exit;
  if not RequiredString(ANode, AContext, 'Destination', lDestination) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'Overwrite', False, lOverwrite) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'Recursive', False, lRecursive) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'CleanDestination', False,
    lCleanDestination) then
    Exit;

  lExcludeNames := TStringList.Create;
  try
    lExcludeNames.CaseSensitive := False;
    BuildExcludeNames(ANode, lExcludeNames);

    lFullSource := ResolvePath(AContext.WorkingDirectory, lSource);
    lFullDestination := ResolvePath(AContext.WorkingDirectory, lDestination);

    try
      if FileExists(lFullSource) then
        CopyOneFile(ANode, AContext, lFullSource, lFullDestination, lOverwrite)
      else if DirectoryExists(lFullSource) then
      begin
        if not lRecursive then
          AddDiagnostic(ANode, AContext, 'NXTask.Action.CopyFile.Recursive',
            'CopyFile source is a directory but Recursive is false: ' +
            lFullSource)
        else
        begin
          if lCleanDestination and DirectoryExists(lFullDestination) then
            RemoveDirectoryTree(lFullDestination);
          CopyDirectory(ANode, AContext, lFullSource, lFullDestination,
            lOverwrite, lExcludeNames);
        end;
      end
      else
        AddDiagnostic(ANode, AContext, 'NXTask.Action.CopyFile.Source',
          'CopyFile source does not exist: ' + lFullSource);
    except
      on E: Exception do
        AddDiagnostic(ANode, AContext, 'NXTask.Action.CopyFile',
          'CopyFile failed: ' + E.Message);
    end
  finally
    lExcludeNames.Free;
  end;
end;

procedure TNXTaskDeletePathAction.AddDiagnostic(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ACode, AMessage: string);
begin
  AContext.Diagnostics.Add(tdsError, ACode, AMessage,
    TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
      ANode.SourceRange.Column));
end;

function TNXTaskDeletePathAction.RequiredString(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
  if not Result then
    AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath.' + AName,
      'DeletePath action requires string property ' + AName + '.');
end;

function TNXTaskDeletePathAction.OptionalBoolean(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; ADefault: Boolean;
  out AValue: Boolean): Boolean;
var
  lProperty: TNXTaskProperty;
begin
  Result := True;
  AValue := ADefault;
  lProperty := ANode.PropertyByName(AName);
  if lProperty = nil then
    Exit;
  if lProperty.Value.Kind = tvkBoolean then
  begin
    AValue := lProperty.Value.BooleanValue;
    Exit;
  end;

  Result := False;
  AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath.' + AName,
    'DeletePath action requires boolean property ' + AName + '.');
end;

function TNXTaskDeletePathAction.ResolvePath(const AWorkingDirectory,
  APath: string): string;
begin
  if ExtractFileDrive(APath) <> '' then
    Result := ExpandFileName(APath)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(AWorkingDirectory) +
      APath);
end;

function TNXTaskDeletePathAction.DeleteDirectoryTree(const APath: string): Boolean;
var
  lChild: string;
  lSearch: TSearchRec;
begin
  Result := True;
  if not DirectoryExists(APath) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, lSearch) = 0 then
  begin
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') then
        begin
          lChild := IncludeTrailingPathDelimiter(APath) + lSearch.Name;
          if (lSearch.Attr and faDirectory) <> 0 then
          begin
            if not DeleteDirectoryTree(lChild) then
              Result := False;
          end
          else if not DeleteFile(lChild) then
            Result := False;
        end;
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;

  if not RemoveDir(APath) then
    Result := False;
end;

function TNXTaskDeletePathAction.DeleteMatchingFiles(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ARoot, AMask: string;
  ARecursive: Boolean): Boolean;
var
  lChild: string;
  lSearch: TSearchRec;
begin
  Result := True;
  if FindFirst(IncludeTrailingPathDelimiter(ARoot) + AMask, faAnyFile, lSearch) = 0 then
  begin
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') and
          ((lSearch.Attr and faDirectory) = 0) then
        begin
          lChild := IncludeTrailingPathDelimiter(ARoot) + lSearch.Name;
          if DeleteFile(lChild) then
            AContext.Trace.Add('delete ' + NXTaskQuoteString(lChild))
          else
          begin
            AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath.Delete',
              'DeletePath failed to delete file: ' + lChild);
            Result := False;
          end;
        end;
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;

  if not ARecursive then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(ARoot) + '*', faDirectory, lSearch) = 0 then
  begin
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') and
          ((lSearch.Attr and faDirectory) <> 0) then
        begin
          lChild := IncludeTrailingPathDelimiter(ARoot) + lSearch.Name;
          if not DeleteMatchingFiles(ANode, AContext, lChild, AMask,
            ARecursive) then
            Result := False;
        end;
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;
end;

procedure TNXTaskDeletePathAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lFullPath: string;
  lMask: string;
  lMissingOk: Boolean;
  lPath: string;
  lRecursive: Boolean;
begin
  if not RequiredString(ANode, AContext, 'Path', lPath) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'Recursive', False, lRecursive) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'MissingOk', True, lMissingOk) then
    Exit;

  lFullPath := ResolvePath(AContext.WorkingDirectory, lPath);
  lMask := ExtractFileName(lFullPath);

  try
    if (Pos('*', lMask) > 0) or (Pos('?', lMask) > 0) then
    begin
      if not DirectoryExists(ExtractFileDir(lFullPath)) then
      begin
        if not lMissingOk then
          AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath.Missing',
            'DeletePath root directory does not exist: ' +
            ExtractFileDir(lFullPath));
        Exit;
      end;
      DeleteMatchingFiles(ANode, AContext, ExtractFileDir(lFullPath), lMask,
        lRecursive);
      Exit;
    end;

    if FileExists(lFullPath) then
    begin
      if DeleteFile(lFullPath) then
        AContext.Trace.Add('delete ' + NXTaskQuoteString(lFullPath))
      else
        AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath.Delete',
          'DeletePath failed to delete file: ' + lFullPath);
    end
    else if DirectoryExists(lFullPath) then
    begin
      if lRecursive then
      begin
        if DeleteDirectoryTree(lFullPath) then
          AContext.Trace.Add('delete ' + NXTaskQuoteString(lFullPath))
        else
          AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath.Delete',
            'DeletePath failed to delete directory tree: ' + lFullPath);
      end
      else if RemoveDir(lFullPath) then
        AContext.Trace.Add('delete ' + NXTaskQuoteString(lFullPath))
      else
        AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath.Directory',
          'DeletePath directory is not empty or could not be removed: ' +
          lFullPath);
    end
    else if not lMissingOk then
      AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath.Missing',
        'DeletePath path does not exist: ' + lFullPath);
  except
    on E: Exception do
      AddDiagnostic(ANode, AContext, 'NXTask.Action.DeletePath',
        'DeletePath failed: ' + E.Message);
  end;
end;

procedure TNXTaskArchiveAction.AddDiagnostic(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ACode, AMessage: string);
begin
  AContext.Diagnostics.Add(tdsError, ACode, AMessage,
    TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
      ANode.SourceRange.Column));
end;

function TNXTaskArchiveAction.RequiredString(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
  if not Result then
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive.' + AName,
      'Archive action requires string property ' + AName + '.');
end;

function TNXTaskArchiveAction.OptionalBoolean(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; ADefault: Boolean;
  out AValue: Boolean): Boolean;
var
  lProperty: TNXTaskProperty;
begin
  Result := True;
  AValue := ADefault;
  lProperty := ANode.PropertyByName(AName);
  if lProperty = nil then
    Exit;
  if lProperty.Value.Kind = tvkBoolean then
  begin
    AValue := lProperty.Value.BooleanValue;
    Exit;
  end;

  Result := False;
  AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive.' + AName,
    'Archive action requires boolean property ' + AName + '.');
end;

function TNXTaskArchiveAction.ResolvePath(const AWorkingDirectory,
  APath: string): string;
begin
  if ExtractFileDrive(APath) <> '' then
    Result := ExpandFileName(APath)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(AWorkingDirectory) +
      APath);
end;

procedure TNXTaskArchiveAction.BuildExcludeNames(ANode: TNXTaskNode;
  AExcludeNames: TStrings);
var
  lIndex: Integer;
  lName: string;
  lParts: TStringList;
  lText: string;
begin
  AExcludeNames.Clear;
  if not NXTaskPropertyText(ANode, 'ExcludeNames', lText) then
    Exit;

  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := ';';
    lParts.DelimitedText := lText;
    for lIndex := 0 to lParts.Count - 1 do
    begin
      lName := Trim(lParts[lIndex]);
      if lName <> '' then
        AExcludeNames.Add(lName);
    end;
  finally
    lParts.Free;
  end;
end;

function TNXTaskArchiveAction.IsExcludedName(const AName: string;
  AExcludeNames: TStrings): Boolean;
begin
  Result := (AExcludeNames <> nil) and (AExcludeNames.IndexOf(AName) >= 0);
end;

function TNXTaskArchiveAction.ZipEntryName(const ASourceRoot,
  AFileName: string): string;
begin
  Result := ExtractRelativePath(IncludeTrailingPathDelimiter(ASourceRoot),
    AFileName);
  Result := StringReplace(Result, '\', '/', [rfReplaceAll]);
end;

procedure TNXTaskArchiveAction.AddDirectoryEntries(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; AEntries: TZipFileEntries;
  AExcludeNames: TStrings; const ASourceRoot, ACurrentPath: string;
  ARecursive: Boolean);
var
  lChild: string;
  lSearch: TSearchRec;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ACurrentPath) + '*', faAnyFile,
    lSearch) = 0 then
  begin
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') then
        begin
          if IsExcludedName(lSearch.Name, AExcludeNames) then
            Continue;
          lChild := IncludeTrailingPathDelimiter(ACurrentPath) + lSearch.Name;
          if (lSearch.Attr and faDirectory) <> 0 then
          begin
            if ARecursive then
              AddDirectoryEntries(ANode, AContext, AEntries, AExcludeNames,
                ASourceRoot, lChild, ARecursive);
          end
          else
            AEntries.AddFileEntry(lChild, ZipEntryName(ASourceRoot, lChild));
        end;
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;
end;

procedure TNXTaskArchiveAction.ExecuteZip(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ASource, ADestination: string;
  ARecursive, AOverwrite: Boolean; AExcludeNames: TStrings);
var
  lEntries: TZipFileEntries;
  lSourceRoot: string;
  lZipper: TZipper;
begin
  if FileExists(ADestination) and not AOverwrite then
  begin
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive.Exists',
      'Archive destination already exists: ' + ADestination);
    Exit;
  end;

  if ExtractFileDir(ADestination) <> '' then
    ForceDirectories(ExtractFileDir(ADestination));

  if FileExists(ADestination) and AOverwrite then
    DeleteFile(ADestination);

  lEntries := TZipFileEntries.Create(TZipFileEntry);
  try
    if FileExists(ASource) then
      lEntries.AddFileEntry(ASource, ExtractFileName(ASource))
    else if DirectoryExists(ASource) then
    begin
      lSourceRoot := IncludeTrailingPathDelimiter(ASource);
      AddDirectoryEntries(ANode, AContext, lEntries, AExcludeNames, lSourceRoot,
        lSourceRoot, ARecursive);
    end
    else
    begin
      AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive.Source',
        'Archive source does not exist: ' + ASource);
      Exit;
    end;

    lZipper := TZipper.Create;
    try
      lZipper.FileName := ADestination;
      lZipper.ZipFiles(lEntries);
    finally
      lZipper.Free;
    end;
  finally
    lEntries.Free;
  end;

  AContext.Trace.Add('zip ' + NXTaskQuoteString(ASource) + ' ' +
    NXTaskQuoteString(ADestination));
end;

procedure TNXTaskArchiveAction.ExecuteUnzip(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ASource, ADestination: string;
  AOverwrite: Boolean);
var
  lEntry: TFullZipFileEntry;
  lIndex: Integer;
  lTarget: string;
  lUnZipper: TUnZipper;
begin
  if not FileExists(ASource) then
  begin
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive.Source',
      'Archive source does not exist: ' + ASource);
    Exit;
  end;
  if FileExists(ADestination) then
  begin
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive.Destination',
      'Archive unzip destination is a file: ' + ADestination);
    Exit;
  end;

  ForceDirectories(ADestination);
  lUnZipper := TUnZipper.Create;
  try
    lUnZipper.FileName := ASource;
    lUnZipper.OutputPath := ADestination;
    lUnZipper.Examine;
    if not AOverwrite then
    begin
      for lIndex := 0 to lUnZipper.Entries.Count - 1 do
      begin
        lEntry := lUnZipper.Entries[lIndex];
        if lEntry.IsDirectory then
          Continue;
        lTarget := IncludeTrailingPathDelimiter(ADestination) +
          StringReplace(lEntry.DiskFileName, '/', DirectorySeparator,
          [rfReplaceAll]);
        if FileExists(lTarget) then
        begin
          AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive.Exists',
            'Archive extraction destination already exists: ' + lTarget);
          Exit;
        end;
      end;
    end;
    lUnZipper.UnZipAllFiles;
  finally
    lUnZipper.Free;
  end;

  AContext.Trace.Add('unzip ' + NXTaskQuoteString(ASource) + ' ' +
    NXTaskQuoteString(ADestination));
end;

procedure TNXTaskArchiveAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lDestination: string;
  lExcludeNames: TStringList;
  lFullDestination: string;
  lFullSource: string;
  lOperation: string;
  lOverwrite: Boolean;
  lRecursive: Boolean;
  lSource: string;
begin
  if not RequiredString(ANode, AContext, 'Operation', lOperation) then
    Exit;
  if not RequiredString(ANode, AContext, 'Source', lSource) then
    Exit;
  if not RequiredString(ANode, AContext, 'Destination', lDestination) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'Overwrite', False, lOverwrite) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'Recursive', True, lRecursive) then
    Exit;

  lFullSource := ResolvePath(AContext.WorkingDirectory, lSource);
  lFullDestination := ResolvePath(AContext.WorkingDirectory, lDestination);

  lExcludeNames := TStringList.Create;
  try
    lExcludeNames.CaseSensitive := False;
    BuildExcludeNames(ANode, lExcludeNames);
    try
      if SameText(lOperation, 'Zip') then
        ExecuteZip(ANode, AContext, lFullSource, lFullDestination, lRecursive,
          lOverwrite, lExcludeNames)
      else if SameText(lOperation, 'Unzip') then
        ExecuteUnzip(ANode, AContext, lFullSource, lFullDestination,
          lOverwrite)
      else
        AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive.Operation',
          'Archive action Operation must be Zip or Unzip.');
    except
      on E: Exception do
        AddDiagnostic(ANode, AContext, 'NXTask.Action.Archive',
          'Archive action failed: ' + E.Message);
    end;
  finally
    lExcludeNames.Free;
  end;
end;

function TNXTaskGitAction.RunGit(const AWorkingDirectory: string;
  AArguments: array of string; out AOutput: string): Integer;
var
  lIndex: Integer;
  lProcess: TProcess;
  lBuffer: array[0..2047] of Byte;
  lBytesRead: LongInt;
  lOutput: TStringStream;
begin
  lProcess := TProcess.Create(nil);
  lOutput := TStringStream.Create('');
  try
    lProcess.Executable := 'git';
    if AWorkingDirectory <> '' then
      lProcess.CurrentDirectory := AWorkingDirectory;
    for lIndex := Low(AArguments) to High(AArguments) do
      lProcess.Parameters.Add(AArguments[lIndex]);
    lProcess.Options := [poUsePipes, poStderrToOutPut];
    lProcess.Execute;
    while lProcess.Running do
    begin
      while lProcess.Output.NumBytesAvailable > 0 do
      begin
        lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
        if lBytesRead > 0 then
          lOutput.Write(lBuffer, lBytesRead);
      end;
      Sleep(10);
    end;
    while lProcess.Output.NumBytesAvailable > 0 do
    begin
      lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
      if lBytesRead > 0 then
        lOutput.Write(lBuffer, lBytesRead);
    end;
    Result := lProcess.ExitStatus;
    AOutput := Trim(lOutput.DataString);
  finally
    lOutput.Free;
    lProcess.Free;
  end;
end;

function TNXTaskGitAction.RequiredString(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
  if not Result then
    AContext.Diagnostics.Add(tdsError, 'NXTask.Action.Git.' + AName,
      'Git action requires string property ' + AName + '.',
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column));
end;

function TNXTaskGitAction.OptionalBoolean(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; ADefault: Boolean;
  out AValue: Boolean): Boolean;
var
  lProperty: TNXTaskProperty;
begin
  Result := True;
  AValue := ADefault;
  lProperty := ANode.PropertyByName(AName);
  if lProperty = nil then
    Exit;
  if lProperty.Value.Kind = tvkBoolean then
  begin
    AValue := lProperty.Value.BooleanValue;
    Exit;
  end;

  Result := False;
  AContext.Diagnostics.Add(tdsError, 'NXTask.Action.Git.' + AName,
    'Git action requires boolean property ' + AName + '.',
    TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
      ANode.SourceRange.Column));
end;

procedure TNXTaskGitAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lBranch: string;
  lDirectory: string;
  lExitCode: Integer;
  lFullDirectory: string;
  lGitDirectory: string;
  lOutput: string;
  lRepository: string;
  lSubmodules: Boolean;
begin
  if not RequiredString(ANode, AContext, 'Repository', lRepository) then
    Exit;
  if not RequiredString(ANode, AContext, 'Directory', lDirectory) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'Submodules', False, lSubmodules) then
    Exit;

  if ExtractFileDrive(lDirectory) <> '' then
    lFullDirectory := ExpandFileName(lDirectory)
  else
    lFullDirectory := ExpandFileName(IncludeTrailingPathDelimiter(
      AContext.WorkingDirectory) + lDirectory);
  lGitDirectory := IncludeTrailingPathDelimiter(lFullDirectory) + '.git';

  if DirectoryExists(lGitDirectory) then
  begin
    lExitCode := RunGit(lFullDirectory, ['pull', '--ff-only'], lOutput);
    if lExitCode = 0 then
      AContext.Trace.Add('git pull ' + NXTaskQuoteString(lFullDirectory));
    if (lExitCode = 0) and lSubmodules then
    begin
      lExitCode := RunGit(lFullDirectory, ['submodule', 'update', '--init',
        '--recursive'], lOutput);
      if lExitCode = 0 then
        AContext.Trace.Add('git submodule update ' +
          NXTaskQuoteString(lFullDirectory));
    end;
  end
  else
  begin
    if DirectoryExists(lFullDirectory) then
    begin
      AContext.Diagnostics.Add(tdsError, 'NXTask.Action.Git.Directory',
        'Git target directory exists but is not a Git repository: ' +
        lFullDirectory,
        TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
          ANode.SourceRange.Column));
      Exit;
    end;

    if ExtractFileDir(lFullDirectory) <> '' then
      ForceDirectories(ExtractFileDir(lFullDirectory));

    if NXTaskPropertyText(ANode, 'Branch', lBranch) then
    begin
      if lSubmodules then
        lExitCode := RunGit(AContext.WorkingDirectory,
          ['clone', '--recurse-submodules', '--branch', lBranch, lRepository,
          lFullDirectory], lOutput)
      else
        lExitCode := RunGit(AContext.WorkingDirectory,
          ['clone', '--branch', lBranch, lRepository, lFullDirectory], lOutput);
    end
    else
    begin
      if lSubmodules then
        lExitCode := RunGit(AContext.WorkingDirectory,
          ['clone', '--recurse-submodules', lRepository, lFullDirectory], lOutput)
      else
        lExitCode := RunGit(AContext.WorkingDirectory,
          ['clone', lRepository, lFullDirectory], lOutput);
    end;
    if lExitCode = 0 then
      AContext.Trace.Add('git clone ' + NXTaskQuoteString(lRepository) + ' ' +
        NXTaskQuoteString(lFullDirectory));
  end;

  if lExitCode <> 0 then
    AContext.Diagnostics.Add(tdsError, 'NXTask.Action.Git',
      Format('Git command failed with exit code %d: %s', [lExitCode, lOutput]),
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column));
end;

procedure TNXTaskNpmAction.AddDiagnostic(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ACode, AMessage: string);
begin
  AContext.Diagnostics.Add(tdsError, ACode, AMessage,
    TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
      ANode.SourceRange.Column));
end;

function TNXTaskNpmAction.OptionalString(ANode: TNXTaskNode;
  const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
end;

function TNXTaskNpmAction.ResolvePath(const AWorkingDirectory,
  APath: string): string;
begin
  if APath = '' then
    Result := AWorkingDirectory
  else if ExtractFileDrive(APath) <> '' then
    Result := ExpandFileName(APath)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(AWorkingDirectory) +
      APath);
end;

procedure TNXTaskNpmAction.AddSplitArguments(AArguments: TStrings;
  const AText: string);
var
  lChar: Char;
  lIndex: Integer;
  lInQuote: Boolean;
  lToken: string;
begin
  lInQuote := False;
  lToken := '';
  for lIndex := 1 to Length(AText) do
  begin
    lChar := AText[lIndex];
    if lChar = '"' then
      lInQuote := not lInQuote
    else if (lChar <= ' ') and not lInQuote then
    begin
      if lToken <> '' then
      begin
        AArguments.Add(lToken);
        lToken := '';
      end;
    end
    else
      lToken := lToken + lChar;
  end;
  if lToken <> '' then
    AArguments.Add(lToken);
end;

function TNXTaskNpmAction.RunNpm(const AExecutable, AWorkingDirectory: string;
  AArguments: TStrings; out AOutput: string): Integer;
var
  lIndex: Integer;
  lProcess: TProcess;
  lBuffer: array[0..2047] of Byte;
  lBytesRead: LongInt;
  lOutput: TStringStream;
begin
  lProcess := TProcess.Create(nil);
  lOutput := TStringStream.Create('');
  try
    lProcess.Executable := AExecutable;
    if AWorkingDirectory <> '' then
      lProcess.CurrentDirectory := AWorkingDirectory;
    for lIndex := 0 to AArguments.Count - 1 do
      lProcess.Parameters.Add(AArguments[lIndex]);
    lProcess.Options := [poUsePipes, poStderrToOutPut];
    lProcess.Execute;
    while lProcess.Running do
    begin
      while lProcess.Output.NumBytesAvailable > 0 do
      begin
        lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
        if lBytesRead > 0 then
          lOutput.Write(lBuffer, lBytesRead);
      end;
      Sleep(10);
    end;
    while lProcess.Output.NumBytesAvailable > 0 do
    begin
      lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
      if lBytesRead > 0 then
        lOutput.Write(lBuffer, lBytesRead);
    end;
    Result := lProcess.ExitStatus;
    AOutput := Trim(lOutput.DataString);
  finally
    lOutput.Free;
    lProcess.Free;
  end;
end;

procedure TNXTaskNpmAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lArguments: TStringList;
  lCommand: string;
  lExecutable: string;
  lExitCode: Integer;
  lExtraArguments: string;
  lOutput: string;
  lScript: string;
  lWorkingDirectory: string;
begin
  OptionalString(ANode, 'Command', lCommand);
  OptionalString(ANode, 'Script', lScript);
  OptionalString(ANode, 'Arguments', lExtraArguments);
  if not OptionalString(ANode, 'Executable', lExecutable) then
  begin
    {$ifdef MSWINDOWS}
    lExecutable := 'npm.cmd';
    {$else}
    lExecutable := 'npm';
    {$endif}
  end;
  if OptionalString(ANode, 'WorkingDirectory', lWorkingDirectory) then
    lWorkingDirectory := ResolvePath(AContext.WorkingDirectory, lWorkingDirectory)
  else
    lWorkingDirectory := AContext.WorkingDirectory;

  if (lCommand = '') and (lScript = '') then
  begin
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Npm.Command',
      'Npm action requires either string property Command or Script.');
    Exit;
  end;
  if (lCommand <> '') and (lScript <> '') then
  begin
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Npm.Mode',
      'Npm action cannot use both Command and Script.');
    Exit;
  end;

  lArguments := TStringList.Create;
  try
    if lScript <> '' then
    begin
      lArguments.Add('run');
      lArguments.Add(lScript);
    end
    else
      AddSplitArguments(lArguments, lCommand);
    AddSplitArguments(lArguments, lExtraArguments);

    lExitCode := RunNpm(lExecutable, lWorkingDirectory, lArguments, lOutput);
  finally
    lArguments.Free;
  end;

  if lExitCode = 0 then
    AContext.Trace.Add('npm ' + NXTaskQuoteString(lWorkingDirectory))
  else
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Npm',
      Format('npm failed with exit code %d: %s', [lExitCode, lOutput]));
end;

procedure TNXTaskFpcAction.AddDiagnostic(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const ACode, AMessage: string);
begin
  AContext.Diagnostics.Add(tdsError, ACode, AMessage,
    TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
      ANode.SourceRange.Column));
end;

function TNXTaskFpcAction.OptionalString(ANode: TNXTaskNode;
  const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
end;

function TNXTaskFpcAction.RequiredString(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
  if not Result then
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Fpc.' + AName,
      'Fpc action requires string property ' + AName + '.');
end;

function TNXTaskFpcAction.ResolvePath(const AWorkingDirectory,
  APath: string): string;
begin
  if APath = '' then
    Result := ''
  else if ExtractFileDrive(APath) <> '' then
    Result := ExpandFileName(APath)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(AWorkingDirectory) +
      APath);
end;

procedure TNXTaskFpcAction.AddSplitPaths(AArguments: TStrings; const ASwitch,
  AWorkingDirectory, AText: string);
var
  lIndex: Integer;
  lPart: string;
  lParts: TStringList;
begin
  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := ';';
    lParts.DelimitedText := AText;
    for lIndex := 0 to lParts.Count - 1 do
    begin
      lPart := Trim(lParts[lIndex]);
      if lPart <> '' then
        AArguments.Add(ASwitch + ResolvePath(AWorkingDirectory, lPart));
    end;
  finally
    lParts.Free;
  end;
end;

function TNXTaskFpcAction.RunFpc(const AExecutable, AWorkingDirectory: string;
  AArguments: TStrings; out AOutput: string): Integer;
var
  lIndex: Integer;
  lProcess: TProcess;
  lBuffer: array[0..2047] of Byte;
  lBytesRead: LongInt;
  lOutput: TStringStream;
begin
  lProcess := TProcess.Create(nil);
  lOutput := TStringStream.Create('');
  try
    lProcess.Executable := AExecutable;
    if AWorkingDirectory <> '' then
      lProcess.CurrentDirectory := AWorkingDirectory;
    for lIndex := 0 to AArguments.Count - 1 do
      lProcess.Parameters.Add(AArguments[lIndex]);
    lProcess.Options := [poUsePipes, poStderrToOutPut];
    lProcess.Execute;
    while lProcess.Running do
    begin
      while lProcess.Output.NumBytesAvailable > 0 do
      begin
        lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
        if lBytesRead > 0 then
          lOutput.Write(lBuffer, lBytesRead);
      end;
      Sleep(10);
    end;
    while lProcess.Output.NumBytesAvailable > 0 do
    begin
      lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
      if lBytesRead > 0 then
        lOutput.Write(lBuffer, lBytesRead);
    end;
    Result := lProcess.ExitStatus;
    AOutput := Trim(lOutput.DataString);
  finally
    lOutput.Free;
    lProcess.Free;
  end;
end;

procedure TNXTaskFpcAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lArguments: TStringList;
  lExecutable: string;
  lExitCode: Integer;
  lOutput: string;
  lOutputDirectory: string;
  lOutputName: string;
  lSearchPath: string;
  lSource: string;
  lUnitOutputDirectory: string;
begin
  if not RequiredString(ANode, AContext, 'Source', lSource) then
    Exit;
  if not OptionalString(ANode, 'Executable', lExecutable) then
    lExecutable := 'fpc';
  OptionalString(ANode, 'OutputDirectory', lOutputDirectory);
  OptionalString(ANode, 'OutputName', lOutputName);
  OptionalString(ANode, 'SearchPath', lSearchPath);
  OptionalString(ANode, 'UnitOutputDirectory', lUnitOutputDirectory);

  lSource := ResolvePath(AContext.WorkingDirectory, lSource);
  lOutputDirectory := ResolvePath(AContext.WorkingDirectory, lOutputDirectory);
  lUnitOutputDirectory := ResolvePath(AContext.WorkingDirectory,
    lUnitOutputDirectory);

  if lOutputDirectory <> '' then
    ForceDirectories(lOutputDirectory);
  if lUnitOutputDirectory <> '' then
    ForceDirectories(lUnitOutputDirectory);

  lArguments := TStringList.Create;
  try
    lArguments.Add('-MObjFPC');
    lArguments.Add('-Scgi');
    AddSplitPaths(lArguments, '-Fu', AContext.WorkingDirectory, lSearchPath);
    if lUnitOutputDirectory <> '' then
      lArguments.Add('-FU' + lUnitOutputDirectory);
    if lOutputDirectory <> '' then
      lArguments.Add('-FE' + lOutputDirectory);
    if lOutputName <> '' then
      lArguments.Add('-o' + lOutputName);
    lArguments.Add(lSource);

    lExitCode := RunFpc(lExecutable, ExtractFileDir(lSource), lArguments,
      lOutput);
  finally
    lArguments.Free;
  end;

  if lExitCode = 0 then
    AContext.Trace.Add('fpc ' + NXTaskQuoteString(lSource))
  else
    AddDiagnostic(ANode, AContext, 'NXTask.Action.Fpc',
      Format('fpc failed with exit code %d: %s', [lExitCode, lOutput]));
end;

function TNXTaskLazBuildAction.OptionalBoolean(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; ADefault: Boolean;
  out AValue: Boolean): Boolean;
var
  lProperty: TNXTaskProperty;
begin
  Result := True;
  AValue := ADefault;
  lProperty := ANode.PropertyByName(AName);
  if lProperty = nil then
    Exit;
  if lProperty.Value.Kind = tvkBoolean then
  begin
    AValue := lProperty.Value.BooleanValue;
    Exit;
  end;

  Result := False;
  AContext.Diagnostics.Add(tdsError, 'NXTask.Action.LazBuild.' + AName,
    'LazBuild action requires boolean property ' + AName + '.',
    TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
      ANode.SourceRange.Column));
end;

function TNXTaskLazBuildAction.RequiredString(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext; const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
  if not Result then
    AContext.Diagnostics.Add(tdsError, 'NXTask.Action.LazBuild.' + AName,
      'LazBuild action requires string property ' + AName + '.',
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column));
end;

function TNXTaskLazBuildAction.OptionalString(ANode: TNXTaskNode;
  const AName: string; out AValue: string): Boolean;
begin
  Result := NXTaskPropertyText(ANode, AName, AValue);
end;

function TNXTaskLazBuildAction.RunLazBuild(const AExecutable,
  AWorkingDirectory: string; AArguments: TStrings; out AOutput: string): Integer;
var
  lIndex: Integer;
  lProcess: TProcess;
  lBuffer: array[0..2047] of Byte;
  lBytesRead: LongInt;
  lOutput: TStringStream;
begin
  lProcess := TProcess.Create(nil);
  lOutput := TStringStream.Create('');
  try
    lProcess.Executable := AExecutable;
    if AWorkingDirectory <> '' then
      lProcess.CurrentDirectory := AWorkingDirectory;
    for lIndex := 0 to AArguments.Count - 1 do
      lProcess.Parameters.Add(AArguments[lIndex]);
    lProcess.Options := [poUsePipes, poStderrToOutPut];
    lProcess.Execute;
    while lProcess.Running do
    begin
      while lProcess.Output.NumBytesAvailable > 0 do
      begin
        lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
        if lBytesRead > 0 then
          lOutput.Write(lBuffer, lBytesRead);
      end;
      Sleep(10);
    end;
    while lProcess.Output.NumBytesAvailable > 0 do
    begin
      lBytesRead := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
      if lBytesRead > 0 then
        lOutput.Write(lBuffer, lBytesRead);
    end;
    Result := lProcess.ExitStatus;
    AOutput := Trim(lOutput.DataString);
  finally
    lOutput.Free;
    lProcess.Free;
  end;
end;

procedure TNXTaskLazBuildAction.Execute(ANode: TNXTaskNode;
  AContext: TNXTaskActionContext);
var
  lArguments: TStringList;
  lBuildAll: Boolean;
  lExecutable: string;
  lExitCode: Integer;
  lLazarusDirectory: string;
  lOutput: string;
  lPrimaryConfigPath: string;
  lProject: string;
  lProjectFile: string;
  lQuiet: Boolean;
begin
  if not RequiredString(ANode, AContext, 'Project', lProject) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'BuildAll', False, lBuildAll) then
    Exit;
  if not OptionalBoolean(ANode, AContext, 'Quiet', True, lQuiet) then
    Exit;

  if not NXTaskPropertyText(ANode, 'Executable', lExecutable) then
    lExecutable := 'lazbuild';

  if ExtractFileDrive(lProject) <> '' then
    lProjectFile := ExpandFileName(lProject)
  else
    lProjectFile := ExpandFileName(IncludeTrailingPathDelimiter(
    AContext.WorkingDirectory) + lProject);

  lArguments := TStringList.Create;
  try
    if OptionalString(ANode, 'PrimaryConfigPath', lPrimaryConfigPath) then
      lArguments.Add('--pcp=' + lPrimaryConfigPath);
    if OptionalString(ANode, 'LazarusDirectory', lLazarusDirectory) then
      lArguments.Add('--lazarusdir=' + lLazarusDirectory);
    if lQuiet then
      lArguments.Add('--quiet');
    if lBuildAll then
      lArguments.Add('--build-all');
    lArguments.Add(lProjectFile);

    lExitCode := RunLazBuild(lExecutable, ExtractFileDir(lProjectFile),
      lArguments, lOutput);
  finally
    lArguments.Free;
  end;

  if lExitCode = 0 then
    AContext.Trace.Add('lazbuild ' + NXTaskQuoteString(lProjectFile))
  else
    AContext.Diagnostics.Add(tdsError, 'NXTask.Action.LazBuild',
      Format('lazbuild failed with exit code %d: %s', [lExitCode, lOutput]),
      TNXTaskSourceRange.Create(ANode.SourceRange.FileName, ANode.SourceRange.Line,
        ANode.SourceRange.Column));
end;

procedure NXTaskRegisterDefaultActions(ARegistry: TNXTaskActionRegistry);
begin
  ARegistry.RegisterAction('Group', TNXTaskGroupAction);
  ARegistry.RegisterAction('Trace', TNXTaskTraceAction);
  ARegistry.RegisterAction('WriteTextFile', TNXTaskWriteTextFileAction);
  ARegistry.RegisterAction('CopyFile', TNXTaskCopyFileAction);
  ARegistry.RegisterAction('DeletePath', TNXTaskDeletePathAction);
  ARegistry.RegisterAction('Archive', TNXTaskArchiveAction);
  ARegistry.RegisterAction('Git', TNXTaskGitAction);
  ARegistry.RegisterAction('Npm', TNXTaskNpmAction);
  ARegistry.RegisterAction('Fpc', TNXTaskFpcAction);
  ARegistry.RegisterAction('LazBuild', TNXTaskLazBuildAction);
end;

end.
