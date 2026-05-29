unit obNXFileDialog;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Math,
  tpNXEvents,
  tpNXPlatform,
  tpNXWindow,
  obNXControl,
  obNXPopup,
  obNXPanel,
  obNXLabel,
  obNXButton,
  obNXEditBox,
  obNXGrid,
  obNXListBox,
  obNXFileSystemProvider;

type
  TNXFileDialog = class;

  TNXFileDialogMode = (
    fdmOpenFile,
    fdmSaveFile,
    fdmSelectFolder
  );

  TNXFileDialogResultEvent = procedure(ASender: TObject; AResult: TNXModalResult;
    const APath: string) of object;

  TNXFileDialogPlaceList = class(TNXListBox)
  private
    FDialog: TNXFileDialog;
  public
    procedure NewSelection(ASelection: TNXListBoxItem); override;

    property Dialog: TNXFileDialog read FDialog write FDialog;
  end;

  TNXFileDialog = class(TNXPopup)
  private
    FCancelButton: TNXButton;
    FCurrentPath: string;
    FDialogPanel: TNXPanel;
    FFileGrid: TNXGrid;
    FFileNameEdit: TNXEditBox;
    FFileNameLabel: TNXLabel;
    FFilter: string;
    FItems: TNXFileSystemItemArray;
    FMode: TNXFileDialogMode;
    FOnResult: TNXFileDialogResultEvent;
    FOneShot: Boolean;
    FPathEdit: TNXEditBox;
    FPathLabel: TNXLabel;
    FPlaces: TNXFileDialogPlaceList;
    FPlacePaths: array of string;
    FProvider: TNXFileSystemProvider;
    FResultButton: TNXButton;
    FTitleLabel: TNXLabel;
    FUpButton: TNXButton;

    procedure AddPlace(const ACaption, APath: string);
    procedure CancelButtonClick(ASender: TObject; AX, AY: Integer; AButton: TNXMouseButton);
    procedure Complete(AResult: TNXModalResult; const APath: string);
    function ComposeSelectedPath: string;
    procedure FileGridActivate(ASender: TObject; ACol, ARow: Integer);
    procedure FileGridSelected(ASender: TObject; ACol, ARow: Integer);
    function FileMatchesFilter(const APath: string): Boolean;
    function GetDialogHeight: Integer;
    function GetDialogWidth: Integer;
    function GetResultCaption: string;
    procedure LoadPlaces;
    procedure OpenSelectedItem;
    procedure PathEditChanged(ASender: TObject);
    procedure RefreshFiles;
    procedure ResultButtonClick(ASender: TObject; AX, AY: Integer; AButton: TNXMouseButton);
    procedure SetCurrentPath(const AValue: string);
    procedure SetFilter(const AValue: string);
    procedure SetMode(AValue: TNXFileDialogMode);
    procedure UpButtonClick(ASender: TObject; AX, AY: Integer; AButton: TNXMouseButton);
  protected
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoOpened; override;
    procedure LayoutDialog; virtual;
  public
    constructor Create(const AParent: INXControlParent; AOwner: TNXControl); override;
    destructor Destroy; override;

    procedure NavigateTo(const APath: string); virtual;
    procedure ShowDialog(AMode: TNXFileDialogMode; const ATitle: string;
      const AInitialPath: string; const AFilter: string;
      AOnResult: TNXFileDialogResultEvent); virtual;

    class function ShowOpen(const ATitle: string; const AInitialPath: string;
      const AFilter: string; AOnResult: TNXFileDialogResultEvent): TNXFileDialog;
    class function ShowSave(const ATitle: string; const AInitialPath: string;
      const AFilter: string; AOnResult: TNXFileDialogResultEvent): TNXFileDialog;
    class function ShowSelectFolder(const ATitle: string; const AInitialPath: string;
      AOnResult: TNXFileDialogResultEvent): TNXFileDialog;

    property CurrentPath: string read FCurrentPath write SetCurrentPath;
    property Filter: string read FFilter write SetFilter;
    property Mode: TNXFileDialogMode read FMode write SetMode;
    property OnResult: TNXFileDialogResultEvent read FOnResult write FOnResult;
    property Provider: TNXFileSystemProvider read FProvider;
  end;

implementation

uses
  obNXApplication;

const
  cDialogPadding = 12;
  cDialogWidth = 760;
  cDialogHeight = 500;
  cButtonWidth = 86;
  cButtonHeight = 28;
  cGap = 8;
  cPlacesWidth = 150;
  cLabelHeight = 20;
  cEditHeight = 26;

function NXFormatFileSize(ASize: Int64): string;
begin
  if ASize < 1024 then
    Result := IntToStr(ASize)
  else if ASize < 1024 * 1024 then
    Result := IntToStr(ASize div 1024) + ' KB'
  else if ASize < Int64(1024) * 1024 * 1024 then
    Result := IntToStr(ASize div (1024 * 1024)) + ' MB'
  else
    Result := IntToStr(ASize div (Int64(1024) * 1024 * 1024)) + ' GB';
end;

function NXKindCaption(AKind: TNXFileSystemItemKind): string;
begin
  case AKind of
    fsikDirectory:
      Result := 'Folder';
    fsikDrive:
      Result := 'Drive';
    fsikSpecialFolder:
      Result := 'Folder';
  else
    Result := 'File';
  end;
end;

procedure TNXFileDialogPlaceList.NewSelection(ASelection: TNXListBoxItem);
begin
  inherited NewSelection(ASelection);

  if Assigned(FDialog) and Assigned(ASelection) then
    if (ASelection.Index >= 0) and (ASelection.Index < Length(FDialog.FPlacePaths)) then
      FDialog.NavigateTo(FDialog.FPlacePaths[ASelection.Index]);
end;

constructor TNXFileDialog.Create(const AParent: INXControlParent; AOwner: TNXControl);
begin
  inherited Create(AParent, AOwner);

  Left := 0;
  Top := 0;
  Width := 1;
  Height := 1;
  FillStyle := FS_Filled;
  BorderStyle := BS_None;
  BackColor := Skin.FullTransColor;
  CanFocus := True;
  ReceiveAllEvents := True;

  FMode := fdmOpenFile;
  FFilter := '*';
  FOneShot := False;
  FProvider := TNXFileSystemProvider.Create;

  FDialogPanel := TNXPanel.Create(Self);
  FDialogPanel.Caption := '';
  FDialogPanel.Width := cDialogWidth;
  FDialogPanel.Height := cDialogHeight;

  FTitleLabel := TNXLabel.Create(FDialogPanel);
  FTitleLabel.Caption := 'Open';
  FTitleLabel.TextA := Align_Left;
  FTitleLabel.VertA := VAlign_Center;

  FPathLabel := TNXLabel.Create(FDialogPanel);
  FPathLabel.Caption := 'Path';
  FPathLabel.VertA := VAlign_Center;

  FPathEdit := TNXEditBox.Create(FDialogPanel);
  FPathEdit.OnChange := @PathEditChanged;

  FUpButton := TNXButton.Create(FDialogPanel);
  FUpButton.Caption := 'Up';
  FUpButton.OnMouseClick := @UpButtonClick;

  FPlaces := TNXFileDialogPlaceList.Create(FDialogPanel);
  FPlaces.Dialog := Self;

  FFileGrid := TNXGrid.Create(FDialogPanel);
  FFileGrid.ResizeGrid(4, 0);
  FFileGrid.Headers[0] := 'Name';
  FFileGrid.Headers[1] := 'Type';
  FFileGrid.Headers[2] := 'Size';
  FFileGrid.Headers[3] := 'Modified';
  FFileGrid.ColWidths[0] := 300;
  FFileGrid.ColWidths[1] := 90;
  FFileGrid.ColWidths[2] := 80;
  FFileGrid.ColWidths[3] := 150;
  FFileGrid.SelectionMode := gsmRow;
  FFileGrid.OnCellSelected := @FileGridSelected;
  FFileGrid.OnCellActivate := @FileGridActivate;

  FFileNameLabel := TNXLabel.Create(FDialogPanel);
  FFileNameLabel.Caption := 'File name';
  FFileNameLabel.VertA := VAlign_Center;

  FFileNameEdit := TNXEditBox.Create(FDialogPanel);

  FResultButton := TNXButton.Create(FDialogPanel);
  FResultButton.Caption := GetResultCaption;
  FResultButton.OnMouseClick := @ResultButtonClick;

  FCancelButton := TNXButton.Create(FDialogPanel);
  FCancelButton.Caption := 'Cancel';
  FCancelButton.OnMouseClick := @CancelButtonClick;

  LoadPlaces;
  LayoutDialog;
end;

destructor TNXFileDialog.Destroy;
begin
  FreeAndNil(FProvider);
  inherited Destroy;
end;

function TNXFileDialog.GetDialogWidth: Integer;
begin
  Result := cDialogWidth;
  if Assigned(Parent) then
    Result := Min(Result, Max(360, Parent.Width - cDialogPadding * 2));
end;

function TNXFileDialog.GetDialogHeight: Integer;
begin
  Result := cDialogHeight;
  if Assigned(Parent) then
    Result := Min(Result, Max(280, Parent.Height - cDialogPadding * 2));
end;

function TNXFileDialog.GetResultCaption: string;
begin
  case FMode of
    fdmSaveFile:
      Result := 'Save';
    fdmSelectFolder:
      Result := 'Select';
  else
    Result := 'Open';
  end;
end;

procedure TNXFileDialog.SetMode(AValue: TNXFileDialogMode);
begin
  if FMode = AValue then
    Exit;

  FMode := AValue;
  FResultButton.Caption := GetResultCaption;
  if FMode = fdmSelectFolder then
    FFileNameLabel.Caption := 'Folder'
  else
    FFileNameLabel.Caption := 'File name';
end;

procedure TNXFileDialog.SetFilter(const AValue: string);
begin
  if AValue = '' then
    FFilter := '*'
  else
    FFilter := AValue;
  RefreshFiles;
end;

procedure TNXFileDialog.SetCurrentPath(const AValue: string);
begin
  NavigateTo(AValue);
end;

procedure TNXFileDialog.AddPlace(const ACaption, APath: string);
var
  lIndex: Integer;
begin
  if (APath = '') or not FProvider.DirectoryExists(APath) then
    Exit;

  lIndex := Length(FPlacePaths);
  SetLength(FPlacePaths, lIndex + 1);
  FPlacePaths[lIndex] := APath;
  FPlaces.Items.AddItem(ACaption, lIndex);
end;

procedure TNXFileDialog.LoadPlaces;
var
  lIndex: Integer;
  lItems: TNXFileSystemItemArray;
begin
  FPlaces.Items.Clear;
  SetLength(FPlacePaths, 0);

  lItems := FProvider.GetSpecialFolders;
  for lIndex := 0 to High(lItems) do
    AddPlace(lItems[lIndex].Name, lItems[lIndex].FullPath);

  lItems := FProvider.GetRoots;
  for lIndex := 0 to High(lItems) do
    AddPlace(lItems[lIndex].Name, lItems[lIndex].FullPath);
end;

procedure TNXFileDialog.NavigateTo(const APath: string);
var
  lPath: string;
begin
  lPath := ExpandFileName(APath);
  if not FProvider.DirectoryExists(lPath) then
    Exit;

  FCurrentPath := ExcludeTrailingPathDelimiter(lPath);
  FPathEdit.OnChange := nil;
  try
    FPathEdit.Text := FCurrentPath;
  finally
    FPathEdit.OnChange := @PathEditChanged;
  end;

  RefreshFiles;
end;

procedure TNXFileDialog.RefreshFiles;
var
  lIndex: Integer;
  lRow: Integer;
  lItem: TNXFileSystemItem;
begin
  if FCurrentPath = '' then
    Exit;

  FItems := FProvider.ListDirectory(FCurrentPath);
  FFileGrid.ResizeGrid(4, 0);

  lRow := 0;
  for lIndex := 0 to High(FItems) do
  begin
    lItem := FItems[lIndex];

    if (FMode = fdmSelectFolder) and (lItem.Kind = fsikFile) then
      Continue;
    if (lItem.Kind = fsikFile) and (not FileMatchesFilter(lItem.FullPath)) then
      Continue;

    FFileGrid.RowCount := lRow + 1;
    FFileGrid.Cells[0, lRow] := lItem.Name;
    FFileGrid.Cells[1, lRow] := NXKindCaption(lItem.Kind);
    if lItem.Kind = fsikFile then
      FFileGrid.Cells[2, lRow] := NXFormatFileSize(lItem.Size)
    else
      FFileGrid.Cells[2, lRow] := '';
    if lItem.ModifiedAt > 0 then
      FFileGrid.Cells[3, lRow] := DateTimeToStr(lItem.ModifiedAt)
    else
      FFileGrid.Cells[3, lRow] := '';

    if lRow <> lIndex then
      FItems[lRow] := FItems[lIndex];
    Inc(lRow);
  end;

  SetLength(FItems, lRow);
end;

function TNXFileDialog.FileMatchesFilter(const APath: string): Boolean;
var
  lExt: string;
  lFilter: string;
  lPart: string;
  lPos: Integer;
begin
  Result := True;

  lFilter := Trim(FFilter);
  if (lFilter = '') or (lFilter = '*') or (lFilter = '*.*') then
    Exit;

  Result := False;
  lExt := LowerCase(ExtractFileExt(APath));

  while lFilter <> '' do
  begin
    lPos := Pos(';', lFilter);
    if lPos > 0 then
    begin
      lPart := Trim(Copy(lFilter, 1, lPos - 1));
      Delete(lFilter, 1, lPos);
    end
    else
    begin
      lPart := Trim(lFilter);
      lFilter := '';
    end;

    if (lPart = '*') or (lPart = '*.*') then
      Exit(True);
    if Pos('*.', lPart) = 1 then
      if LowerCase(Copy(lPart, 2, MaxInt)) = lExt then
        Exit(True);
    if LowerCase(lPart) = LowerCase(ExtractFileName(APath)) then
      Exit(True);
  end;
end;

procedure TNXFileDialog.FileGridSelected(ASender: TObject; ACol, ARow: Integer);
begin
  if (ARow < 0) or (ARow > High(FItems)) then
    Exit;

  if FItems[ARow].Kind = fsikFile then
    FFileNameEdit.Text := FItems[ARow].Name
  else if FMode = fdmSelectFolder then
    FFileNameEdit.Text := FItems[ARow].Name;
end;

procedure TNXFileDialog.FileGridActivate(ASender: TObject; ACol, ARow: Integer);
begin
  OpenSelectedItem;
end;

procedure TNXFileDialog.OpenSelectedItem;
var
  lRow: Integer;
begin
  lRow := FFileGrid.SelectedRow;
  if (lRow < 0) or (lRow > High(FItems)) then
    Exit;

  if FItems[lRow].Kind <> fsikFile then
  begin
    NavigateTo(FItems[lRow].FullPath);
    Exit;
  end;

  if FMode = fdmOpenFile then
    Complete(mrOK, FItems[lRow].FullPath);
end;

function TNXFileDialog.ComposeSelectedPath: string;
var
  lName: string;
  lRow: Integer;
begin
  Result := '';

  if FMode = fdmSelectFolder then
  begin
    lRow := FFileGrid.SelectedRow;
    if (lRow >= 0) and (lRow <= High(FItems)) and
      (FItems[lRow].Kind <> fsikFile) then
      Exit(FItems[lRow].FullPath);

    Exit(FCurrentPath);
  end;

  lName := Trim(FFileNameEdit.Text);
  if lName = '' then
    Exit;

  if ExtractFilePath(lName) <> '' then
    Result := ExpandFileName(lName)
  else
    Result := IncludeTrailingPathDelimiter(FCurrentPath) + lName;
end;

procedure TNXFileDialog.ResultButtonClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
var
  lPath: string;
begin
  if AButton <> mbLeft then
    Exit;

  lPath := ComposeSelectedPath;
  if lPath = '' then
    Exit;

  if (FMode = fdmOpenFile) and (not FProvider.FileExists(lPath)) then
    Exit;

  Complete(mrOK, lPath);
end;

procedure TNXFileDialog.CancelButtonClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
begin
  if AButton = mbLeft then
    Complete(mrCancel, '');
end;

procedure TNXFileDialog.UpButtonClick(ASender: TObject; AX, AY: Integer;
  AButton: TNXMouseButton);
var
  lParent: string;
begin
  if AButton <> mbLeft then
    Exit;

  lParent := FProvider.GetParentPath(FCurrentPath);
  if (lParent <> '') and (lParent <> FCurrentPath) then
    NavigateTo(lParent);
end;

procedure TNXFileDialog.PathEditChanged(ASender: TObject);
begin
  if FProvider.DirectoryExists(FPathEdit.Text) then
    NavigateTo(FPathEdit.Text);
end;

procedure TNXFileDialog.Complete(AResult: TNXModalResult; const APath: string);
var
  lOneShot: Boolean;
begin
  lOneShot := FOneShot;

  Close;

  if Assigned(FOnResult) then
    FOnResult(Self, AResult, APath);

  if lOneShot and Assigned(Application) then
    Application.QueueFreeControl(Self);
end;

procedure TNXFileDialog.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  case AEvent.Key of
    nkEscape:
      Complete(mrCancel, '');
    nkEnter:
      ResultButtonClick(Self, 0, 0, mbLeft);
  end;
end;

procedure TNXFileDialog.DoOpened;
begin
  inherited DoOpened;

  if Assigned(Parent) then
  begin
    Width := Parent.Width;
    Height := Parent.Height;
  end;

  Focus;
  LayoutDialog;
end;

procedure TNXFileDialog.LayoutDialog;
var
  lButtonTop: Integer;
  lDialogHeight: Integer;
  lDialogLeft: Integer;
  lDialogTop: Integer;
  lDialogWidth: Integer;
  lEditTop: Integer;
  lFileAreaLeft: Integer;
  lFileAreaTop: Integer;
  lFileAreaWidth: Integer;
  lGridHeight: Integer;
  lPathTop: Integer;
begin
  if Assigned(Parent) then
  begin
    Width := Parent.Width;
    Height := Parent.Height;
  end;

  lDialogWidth := GetDialogWidth;
  lDialogHeight := GetDialogHeight;
  lDialogLeft := Max(0, (Width - lDialogWidth) div 2);
  lDialogTop := Max(0, (Height - lDialogHeight) div 2);

  FDialogPanel.SetBounds(lDialogLeft, lDialogTop, lDialogWidth, lDialogHeight);

  FTitleLabel.SetBounds(cDialogPadding, cDialogPadding,
    lDialogWidth - cDialogPadding * 2, cLabelHeight);

  lPathTop := cDialogPadding + cLabelHeight + cGap;
  FPathLabel.SetBounds(cDialogPadding, lPathTop, 50, cEditHeight);
  FUpButton.SetBounds(lDialogWidth - cDialogPadding - 48, lPathTop, 48, cEditHeight);
  FPathEdit.SetBounds(cDialogPadding + 54, lPathTop,
    lDialogWidth - cDialogPadding * 2 - 54 - 48 - cGap, cEditHeight);

  lFileAreaTop := lPathTop + cEditHeight + cGap;
  lEditTop := lDialogHeight - cDialogPadding - cButtonHeight - cGap - cEditHeight;
  lButtonTop := lDialogHeight - cDialogPadding - cButtonHeight;
  lGridHeight := Max(32, lEditTop - lFileAreaTop - cGap);

  FPlaces.SetBounds(cDialogPadding, lFileAreaTop, cPlacesWidth, lGridHeight);

  lFileAreaLeft := cDialogPadding + cPlacesWidth + cGap;
  lFileAreaWidth := lDialogWidth - lFileAreaLeft - cDialogPadding;
  FFileGrid.SetBounds(lFileAreaLeft, lFileAreaTop, lFileAreaWidth, lGridHeight);

  FFileNameLabel.SetBounds(cDialogPadding, lEditTop, 80, cEditHeight);
  FFileNameEdit.SetBounds(cDialogPadding + 84, lEditTop,
    lDialogWidth - cDialogPadding * 2 - 84 - (cButtonWidth * 2) - cGap * 2,
    cEditHeight);

  FCancelButton.SetBounds(lDialogWidth - cDialogPadding - cButtonWidth,
    lButtonTop, cButtonWidth, cButtonHeight);
  FResultButton.SetBounds(FCancelButton.Left - cGap - cButtonWidth,
    lButtonTop, cButtonWidth, cButtonHeight);
end;

procedure TNXFileDialog.ShowDialog(AMode: TNXFileDialogMode; const ATitle: string;
  const AInitialPath: string; const AFilter: string;
  AOnResult: TNXFileDialogResultEvent);
var
  lInitialPath: string;
begin
  Mode := AMode;
  FTitleLabel.Caption := ATitle;
  Filter := AFilter;
  OnResult := AOnResult;

  lInitialPath := AInitialPath;
  if lInitialPath = '' then
    lInitialPath := GetCurrentDir;
  if not FProvider.DirectoryExists(lInitialPath) then
    lInitialPath := GetCurrentDir;

  NavigateTo(lInitialPath);

  if Assigned(Application) and Assigned(Application.RootWindow) then
    Application.Popups.ShowPopup(Self)
  else
    Open;
end;

class function TNXFileDialog.ShowOpen(const ATitle: string;
  const AInitialPath: string; const AFilter: string;
  AOnResult: TNXFileDialogResultEvent): TNXFileDialog;
begin
  Result := nil;
  if (not Assigned(Application)) or (not Assigned(Application.RootWindow)) then
    Exit;

  Result := TNXFileDialog.Create(Application.RootWindow, nil);
  Result.FOneShot := True;
  Result.ShowDialog(fdmOpenFile, ATitle, AInitialPath, AFilter, AOnResult);
end;

class function TNXFileDialog.ShowSave(const ATitle: string;
  const AInitialPath: string; const AFilter: string;
  AOnResult: TNXFileDialogResultEvent): TNXFileDialog;
begin
  Result := nil;
  if (not Assigned(Application)) or (not Assigned(Application.RootWindow)) then
    Exit;

  Result := TNXFileDialog.Create(Application.RootWindow, nil);
  Result.FOneShot := True;
  Result.ShowDialog(fdmSaveFile, ATitle, AInitialPath, AFilter, AOnResult);
end;

class function TNXFileDialog.ShowSelectFolder(const ATitle: string;
  const AInitialPath: string; AOnResult: TNXFileDialogResultEvent): TNXFileDialog;
begin
  Result := nil;
  if (not Assigned(Application)) or (not Assigned(Application.RootWindow)) then
    Exit;

  Result := TNXFileDialog.Create(Application.RootWindow, nil);
  Result.FOneShot := True;
  Result.ShowDialog(fdmSelectFolder, ATitle, AInitialPath, '*', AOnResult);
end;

end.
