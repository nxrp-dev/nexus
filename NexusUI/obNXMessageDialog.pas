unit obNXMessageDialog;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Math,
  fgl,
  tpNXEvents,
  tpNXPlatform,
  tpNXWindow,
  obNXElement,
  obNXControl,
  obNXPopup,
  obNXPanel,
  obNXLabel,
  obNXButton;

type
  TNXMessageDialogIcon = (
    mdiNone,
    mdiInformation,
    mdiWarning,
    mdiError,
    mdiQuestion
  );

  TNXMessageDialogButton = (
    mdbOK,
    mdbCancel,
    mdbYes,
    mdbNo,
    mdbRetry,
    mdbIgnore,
    mdbAbort
  );

  TNXMessageDialogButtons = set of TNXMessageDialogButton;

  TNXMessageDialogResultEvent = procedure(Sender: TObject; AResult: TNXModalResult) of object;

  TNXMessageDialogActionButton = class(TNXButton)
  private
    FModalResult: TNXModalResult;
  public
    property ModalResult: TNXModalResult read FModalResult write FModalResult;
  end;

  TNXMessageDialog = class(TNXPopup)
  private
    FDialogPanel: TNXPanel;
    FMessageLabel: TNXLabel;
    FIconLabel: TNXLabel;
    FButtons: specialize TFPGList<TNXMessageDialogActionButton>;
    FButtonSet: TNXMessageDialogButtons;
    FDefaultResult: TNXModalResult;
    FCancelResult: TNXModalResult;
    FIcon: TNXMessageDialogIcon;
    FMessageText: string;
    FOnResult: TNXMessageDialogResultEvent;

    procedure ButtonClicked(Sender: TObject; X, Y: Integer; Button: TNXMouseButton);
    procedure ClearButtons;
    procedure AddDialogButton(AButton: TNXMessageDialogButton);
    procedure BuildButtons;
    procedure Complete(AResult: TNXModalResult);
    function ButtonCaption(AButton: TNXMessageDialogButton): string;
    function ButtonResult(AButton: TNXMessageDialogButton): TNXModalResult;
    function IconCaption(AIcon: TNXMessageDialogIcon): string;
    function GetDialogWidth: Integer;
    function GetDialogHeight: Integer;
    procedure SetMessageText(const AValue: string);
    procedure SetTitleText(const AValue: string);
    procedure SetButtonSet(AValue: TNXMessageDialogButtons);
    procedure SetIcon(AValue: TNXMessageDialogIcon);
  protected
    procedure DoKeyDown(const AEvent: TNXKeyEventData); override;
    procedure DoOpened; override;
    procedure LayoutDialog; virtual;
  public
    constructor Create(AParent, AOwner: TNXElement); override;
    destructor Destroy; override;

    procedure ShowDialog(
      const ATitle: string;
      const AMessage: string;
      AButtons: TNXMessageDialogButtons;
      AIcon: TNXMessageDialogIcon;
      ADefaultResult: TNXModalResult;
      ACancelResult: TNXModalResult;
      AOnResult: TNXMessageDialogResultEvent
    );

    class function Show(
      const ATitle: string;
      const AMessage: string;
      AButtons: TNXMessageDialogButtons;
      AIcon: TNXMessageDialogIcon;
      AOnResult: TNXMessageDialogResultEvent = nil
    ): TNXMessageDialog;

    property DialogPanel: TNXPanel read FDialogPanel;
    property MessageText: string read FMessageText write SetMessageText;
    property TitleText: string write SetTitleText;
    property ButtonSet: TNXMessageDialogButtons read FButtonSet write SetButtonSet;
    property DefaultResult: TNXModalResult read FDefaultResult write FDefaultResult;
    property CancelResult: TNXModalResult read FCancelResult write FCancelResult;
    property Icon: TNXMessageDialogIcon read FIcon write SetIcon;
    property OnResult: TNXMessageDialogResultEvent read FOnResult write FOnResult;
  end;

implementation

uses
  obNXApplication;

const
  cDialogPadding = 16;
  cIconWidth = 44;
  cButtonWidth = 86;
  cButtonHeight = 28;
  cButtonGap = 8;
  cMessageHeight = 84;
  cMinDialogWidth = 360;
  cMaxDialogWidth = 560;

constructor TNXMessageDialog.Create(AParent, AOwner: TNXElement);
begin
  inherited Create(AParent, AOwner);

  Left := 0;
  Top := 0;
  Width := 1;
  Height := 1;
  FillStyle := FS_Filled;
  BorderStyle := BS_None;
  BackColor := Skin.FullTransColor;
  Selectable := True;
  ReceiveAllEvents := True;

  FButtons := specialize TFPGList<TNXMessageDialogActionButton>.Create;
  FButtonSet := [mdbOK];
  FDefaultResult := mrOK;
  FCancelResult := mrCancel;
  FIcon := mdiNone;

  FDialogPanel := TNXPanel.Create(Self);
  FDialogPanel.Width := cMinDialogWidth;
  FDialogPanel.Height := 170;
  FDialogPanel.Caption := '';

  FIconLabel := TNXLabel.Create(FDialogPanel);
  FIconLabel.TextA := Align_Center;
  FIconLabel.VertA := VAlign_Center;
  FIconLabel.Width := cIconWidth;
  FIconLabel.Height := cMessageHeight;
  FIconLabel.Caption := '';

  FMessageLabel := TNXLabel.Create(FDialogPanel);
  FMessageLabel.TextA := Align_Left;
  FMessageLabel.VertA := VAlign_Center;
  FMessageLabel.Height := cMessageHeight;
  FMessageLabel.Caption := '';

  BuildButtons;
  LayoutDialog;
end;

destructor TNXMessageDialog.Destroy;
begin
  FreeAndNil(FButtons);
  inherited Destroy;
end;

function TNXMessageDialog.ButtonCaption(AButton: TNXMessageDialogButton): string;
begin
  case AButton of
    mdbOK:
      Result := 'OK';
    mdbCancel:
      Result := 'Cancel';
    mdbYes:
      Result := 'Yes';
    mdbNo:
      Result := 'No';
    mdbRetry:
      Result := 'Retry';
    mdbIgnore:
      Result := 'Ignore';
    mdbAbort:
      Result := 'Abort';
  else
    Result := '';
  end;
end;

function TNXMessageDialog.ButtonResult(AButton: TNXMessageDialogButton): TNXModalResult;
begin
  case AButton of
    mdbOK:
      Result := mrOK;
    mdbCancel:
      Result := mrCancel;
    mdbYes:
      Result := mrYes;
    mdbNo:
      Result := mrNo;
    mdbRetry:
      Result := mrRetry;
    mdbIgnore:
      Result := mrIgnore;
    mdbAbort:
      Result := mrAbort;
  else
    Result := mrNone;
  end;
end;

function TNXMessageDialog.IconCaption(AIcon: TNXMessageDialogIcon): string;
begin
  case AIcon of
    mdiInformation:
      Result := 'i';
    mdiWarning:
      Result := '!';
    mdiError:
      Result := 'X';
    mdiQuestion:
      Result := '?';
  else
    Result := '';
  end;
end;

function TNXMessageDialog.GetDialogWidth: Integer;
var
  lTextWidth: Integer;
begin
  lTextWidth := 0;

  if Assigned(Canvas) and Assigned(Font) and (FMessageText <> '') then
    lTextWidth := Canvas.TextWidth(FMessageText, Font);

  Result := Max(cMinDialogWidth, lTextWidth + cDialogPadding * 2 + cIconWidth + 16);
  Result := Min(cMaxDialogWidth, Result);
end;

function TNXMessageDialog.GetDialogHeight: Integer;
begin
  Result := cDialogPadding * 3 + cMessageHeight + cButtonHeight + GUI_TitleBarHeight;
end;

procedure TNXMessageDialog.SetMessageText(const AValue: string);
begin
  FMessageText := AValue;
  if Assigned(FMessageLabel) then
    FMessageLabel.Caption := AValue;

  LayoutDialog;
end;

procedure TNXMessageDialog.SetTitleText(const AValue: string);
begin
  if Assigned(FDialogPanel) then
    FDialogPanel.Caption := AValue;
end;

procedure TNXMessageDialog.SetButtonSet(AValue: TNXMessageDialogButtons);
begin
  if AValue = [] then
    AValue := [mdbOK];

  FButtonSet := AValue;
  BuildButtons;
  LayoutDialog;
end;

procedure TNXMessageDialog.SetIcon(AValue: TNXMessageDialogIcon);
begin
  FIcon := AValue;

  if Assigned(FIconLabel) then
    FIconLabel.Caption := IconCaption(AValue);

  LayoutDialog;
end;

procedure TNXMessageDialog.ButtonClicked(Sender: TObject; X, Y: Integer;
  Button: TNXMouseButton);
begin
  if Button <> mbLeft then
    Exit;

  if Sender is TNXMessageDialogActionButton then
    Complete((Sender as TNXMessageDialogActionButton).ModalResult);
end;

procedure TNXMessageDialog.ClearButtons;
var
  lChildIndex: Integer;
  lIndex: Integer;
begin
  if not Assigned(FDialogPanel) then
  begin
    FButtons.Clear;
    Exit;
  end;

  for lIndex := FButtons.Count - 1 downto 0 do
  begin
    lChildIndex := FDialogPanel.Children.IndexOf(FButtons[lIndex]);
    if lChildIndex >= 0 then
      FDialogPanel.Children.Delete(lChildIndex);
  end;

  FButtons.Clear;
end;

procedure TNXMessageDialog.AddDialogButton(AButton: TNXMessageDialogButton);
var
  lButton: TNXMessageDialogActionButton;
begin
  lButton := TNXMessageDialogActionButton.Create(FDialogPanel);
  lButton.Caption := ButtonCaption(AButton);
  lButton.ModalResult := ButtonResult(AButton);
  lButton.Width := cButtonWidth;
  lButton.Height := cButtonHeight;
  lButton.OnMouseClick := @ButtonClicked;

  FButtons.Add(lButton);
end;

procedure TNXMessageDialog.BuildButtons;
begin
  ClearButtons;

  if mdbAbort in FButtonSet then
    AddDialogButton(mdbAbort);
  if mdbRetry in FButtonSet then
    AddDialogButton(mdbRetry);
  if mdbIgnore in FButtonSet then
    AddDialogButton(mdbIgnore);
  if mdbYes in FButtonSet then
    AddDialogButton(mdbYes);
  if mdbNo in FButtonSet then
    AddDialogButton(mdbNo);
  if mdbOK in FButtonSet then
    AddDialogButton(mdbOK);
  if mdbCancel in FButtonSet then
    AddDialogButton(mdbCancel);
end;

procedure TNXMessageDialog.Complete(AResult: TNXModalResult);
begin
  Close;

  if Assigned(FOnResult) then
    FOnResult(Self, AResult);
end;

procedure TNXMessageDialog.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  inherited DoKeyDown(AEvent);

  case AEvent.Key of
    nkEscape:
      if FCancelResult <> mrNone then
        Complete(FCancelResult);
    nkEnter:
      if FDefaultResult <> mrNone then
        Complete(FDefaultResult);
  end;
end;

procedure TNXMessageDialog.DoOpened;
begin
  inherited DoOpened;

  if Assigned(Parent) then
  begin
    Width := Parent.Width;
    Height := Parent.Height;
  end;

  IsSelected := True;
  LayoutDialog;
end;

procedure TNXMessageDialog.LayoutDialog;
var
  lButtonAreaWidth: Integer;
  lButtonLeft: Integer;
  lDialogWidth: Integer;
  lDialogHeight: Integer;
  lIndex: Integer;
  lMessageLeft: Integer;
begin
  if (FDialogPanel = nil) or (FMessageLabel = nil) or (FIconLabel = nil) then
    Exit;

  if Assigned(Parent) then
  begin
    Width := Parent.Width;
    Height := Parent.Height;
  end;

  lDialogWidth := GetDialogWidth;
  lDialogHeight := GetDialogHeight;

  FDialogPanel.Width := lDialogWidth;
  FDialogPanel.Height := lDialogHeight;
  FDialogPanel.Left := Max(0, (Width - lDialogWidth) div 2);
  FDialogPanel.Top := Max(0, (Height - lDialogHeight) div 2);

  FIconLabel.Left := cDialogPadding;
  FIconLabel.Top := cDialogPadding;
  FIconLabel.Width := cIconWidth;
  FIconLabel.Height := cMessageHeight;

  if FIcon = mdiNone then
    lMessageLeft := cDialogPadding
  else
    lMessageLeft := cDialogPadding + cIconWidth + 12;

  FMessageLabel.Left := lMessageLeft;
  FMessageLabel.Top := cDialogPadding;
  FMessageLabel.Width := Max(0, lDialogWidth - lMessageLeft - cDialogPadding);
  FMessageLabel.Height := cMessageHeight;

  lButtonAreaWidth := (FButtons.Count * cButtonWidth) +
    Max(0, FButtons.Count - 1) * cButtonGap;
  lButtonLeft := Max(cDialogPadding, (lDialogWidth - lButtonAreaWidth) div 2);

  for lIndex := 0 to FButtons.Count - 1 do
  begin
    FButtons[lIndex].Left := lButtonLeft + lIndex * (cButtonWidth + cButtonGap);
    FButtons[lIndex].Top := lDialogHeight - cDialogPadding - cButtonHeight - GUI_TitleBarHeight;
    FButtons[lIndex].Width := cButtonWidth;
    FButtons[lIndex].Height := cButtonHeight;
    FButtons[lIndex].Visible := True;
  end;
end;

procedure TNXMessageDialog.ShowDialog(
  const ATitle: string;
  const AMessage: string;
  AButtons: TNXMessageDialogButtons;
  AIcon: TNXMessageDialogIcon;
  ADefaultResult: TNXModalResult;
  ACancelResult: TNXModalResult;
  AOnResult: TNXMessageDialogResultEvent
);
begin
  TitleText := ATitle;
  MessageText := AMessage;
  ButtonSet := AButtons;
  Icon := AIcon;
  DefaultResult := ADefaultResult;
  CancelResult := ACancelResult;
  OnResult := AOnResult;

  if Assigned(Application) and Assigned(Application.Master) then
    Application.Master.Popups.ShowPopup(Self)
  else
    Open;
end;

class function TNXMessageDialog.Show(
  const ATitle: string;
  const AMessage: string;
  AButtons: TNXMessageDialogButtons;
  AIcon: TNXMessageDialogIcon;
  AOnResult: TNXMessageDialogResultEvent
): TNXMessageDialog;
var
  lDefaultResult: TNXModalResult;
  lCancelResult: TNXModalResult;
begin
  Result := nil;

  if (not Assigned(Application)) or (not Assigned(Application.Master)) then
    Exit;

  if mdbOK in AButtons then
    lDefaultResult := mrOK
  else if mdbYes in AButtons then
    lDefaultResult := mrYes
  else if mdbRetry in AButtons then
    lDefaultResult := mrRetry
  else
    lDefaultResult := mrNone;

  if mdbCancel in AButtons then
    lCancelResult := mrCancel
  else if mdbNo in AButtons then
    lCancelResult := mrNo
  else
    lCancelResult := mrNone;

  Result := TNXMessageDialog.Create(Application.Master, Application.Master);
  Result.ShowDialog(ATitle, AMessage, AButtons, AIcon,
    lDefaultResult, lCancelResult, AOnResult);
end;

end.
