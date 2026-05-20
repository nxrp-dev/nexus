program LifeStatNXL;
{$mode objfpc}{$H+}
{$apptype GUI}

uses
  Classes,
  SysUtils,
  obNXButton,
  obNXCheckBox,
  obNXComboBox,
  obNXEditBox,
  obNXControl,
  obNXGrid,
  obNXGroupBox,
  obNXImage,
  obNXLabel,
  obNXListBox,
  obNXMainMenu,
  obNXMemo,
  obNXMessageDialog,
  obNXPanel,
  obNXPopupMenu,
  obNXProgressBar,
  obNXPropertyEditor,
  obNXRadioButton,
  obNXSplitPanel,
  obNXStatusBar,
  obNXTabControl,
  obNXTrackBar,
  obNXTreeList,
  obNXTreeMap,
  obNXTreeMapTestData,
  obNXWindow,
  obNXApplication,
  tpNXLayout,
  tpNXPlatform,
  tpNXWindow;

type
  TDemoEvents = class
  public
    procedure DialogButtonClick(Sender: TObject; X, Y: Integer; Button: TNXMouseButton);
    procedure DialogResult(Sender: TObject; AResult: TNXModalResult);
    procedure MenuButtonClick(Sender: TObject; X, Y: Integer; Button: TNXMouseButton);
    procedure MenuExecute(Sender: TObject; AItem: TNXMenuItem);
    procedure TrackBarChanged(Sender: TObject; AValue: Integer);
  end;

var
  Form1, Form2, Form3, Form4, Form5, Form6, Form7, Form8, Form9: TNXGroupBox;
  Form10: TNXGroupBox;
  Form11: TNXGroupBox;
  Button1, Button2: TNXButton;
  LayoutAnchorButton: TNXButton;
  LayoutBottomPanel: TNXPanel;
  LayoutClientPanel: TNXPanel;
  LayoutLeftPanel: TNXPanel;
  LayoutRightPanel: TNXPanel;
  LayoutTopPanel: TNXPanel;
  Chkbox1: TNXCheckBox;
  RadioButton1, RadioButton2: TNXRadioButton;
  ComboBox1: TNXComboBox;
  Label1: TNXLabel;
  Label2: TNXLabel;
  Label3: TNXLabel;
  LayoutClientLabel: TNXLabel;
  LayoutTopLabel: TNXLabel;
  PageBasics: TNXTabPage;
  PageData: TNXTabPage;
  PageLayout: TNXTabPage;
  PageVisuals: TNXTabPage;
  PropertyEditor1: TNXPropertyEditor;
  TabControl1: TNXTabControl;
  TextBox1: TNXEditBox;
  Image1: TNXImage;
  Grid1: TNXGrid;
  ListBox: TNXListBox;
  Memo1: TNXMemo;
  MainMenu1: TNXMainMenu;
  MainMenuFile: TNXMainMenuItem;
  MainMenuView: TNXMainMenuItem;
  MainMenuHelp: TNXMainMenuItem;
  PopupMenu1: TNXPopupMenu;
  ProgressBar1: TNXProgressBar;
  ProgressBar2: TNXProgressBar;
  SplitPanel1: TNXSplitPanel;
  StatusBar1: TNXStatusBar;
  TreeList1: TNXTreeList;
  TreeNode1: TNXTreeListNode;
  TreeNode2: TNXTreeListNode;
  TreeNode3: TNXTreeListNode;
  TrackBar1: TNXTrackBar;
  TrackBar2: TNXTrackBar;

  DemoEvents: TDemoEvents;
  RootWindow: TNXWindow;

  TestData: TTransactionArray;
  MoneyTreemap1: TNXTreeMap;
  lIndex: Integer;
const
  ResourcesDir = 'resources\';

procedure TDemoEvents.DialogButtonClick(Sender: TObject; X, Y: Integer;
  Button: TNXMouseButton);
begin
  if Button <> mbLeft then
    Exit;

  TNXMessageDialog.Show('NexusUI Dialog',
    'Message dialog, popup manager, buttons, and keyboard handling are active.',
    [mdbOK, mdbCancel], mdiInformation, @DialogResult);
end;

procedure TDemoEvents.DialogResult(Sender: TObject; AResult: TNXModalResult);
begin
  StatusBar1.SimplePanel := False;
  StatusBar1.Panels[0].Text := 'Dialog result';
  StatusBar1.Panels[1].Text := IntToStr(Ord(AResult));
end;

procedure TDemoEvents.MenuButtonClick(Sender: TObject; X, Y: Integer;
  Button: TNXMouseButton);
begin
  if Button <> mbLeft then
    Exit;

  PopupMenu1.ShowAt(Button2.AbsLeft, Button2.AbsTop + Button2.Height);
end;

procedure TDemoEvents.MenuExecute(Sender: TObject; AItem: TNXMenuItem);
begin
  StatusBar1.SimplePanel := False;
  StatusBar1.Panels[0].Text := 'Menu selected';
  StatusBar1.Panels[1].Text := AItem.Caption;
end;

procedure TDemoEvents.TrackBarChanged(Sender: TObject; AValue: Integer);
begin
  if not Assigned(StatusBar1) then
    Exit;

  StatusBar1.SimplePanel := False;
  StatusBar1.Panels[0].Text := 'Trackbar value';
  StatusBar1.Panels[1].Text := IntToStr(AValue);
end;

begin
  Application.Initialize('Window', 1024, 768);
  Application.Skin.LoadNamedSkin('default', Application.Canvas);

  RootWindow := Application.RootWindow;
  DemoEvents := TDemoEvents.Create;

  MainMenu1 := TNXMainMenu.Create(RootWindow);
  MainMenuFile := MainMenu1.AddMenu('File');
  MainMenuFile.AddItem('New', nil, 'Ctrl+N');
  MainMenuFile.AddItem('Open', nil, 'Ctrl+O');
  MainMenuFile.AddSeparator;
  MainMenuFile.AddItem('Exit', nil, 'Esc');
  MainMenuFile.DropDown.OnExecute := @DemoEvents.MenuExecute;

  MainMenuView := MainMenu1.AddMenu('View');
  MainMenuView.AddItem('Refresh', nil, 'F5');
  MainMenuView.AddItem('Toggle Grid', nil);
  MainMenuView.DropDown.OnExecute := @DemoEvents.MenuExecute;

  MainMenuHelp := MainMenu1.AddMenu('Help');
  MainMenuHelp.AddItem('About NexusUI', nil);
  MainMenuHelp.DropDown.OnExecute := @DemoEvents.MenuExecute;

  TabControl1 := TNXTabControl.Create(RootWindow, MakeNXRect(10, 34, 1000, 676));
  TabControl1.Anchors := [ancLeft, ancTop, ancRight, ancBottom];

  PageBasics := TabControl1.AddPage('Basics');
  PageData := TabControl1.AddPage('Data');
  PageLayout := TabControl1.AddPage('Layout');
  PageVisuals := TabControl1.AddPage('Visuals');

  Form1 := TNXGroupBox.Create(PageBasics, 'Form1', MakeNXRect(10, 10, 250, 256));
  Form2 := TNXGroupBox.Create(PageBasics, 'Form2', MakeNXRect(280, 10, 400, 200));
  Form4 := TNXGroupBox.Create(PageBasics, 'Form4', MakeNXRect(700, 10, 260, 300));

  Form6 := TNXGroupBox.Create(PageData, 'Tree List', MakeNXRect(10, 10, 300, 300));
  Form9 := TNXGroupBox.Create(PageData, 'Grid', MakeNXRect(330, 10, 630, 180));
  Form11 := TNXGroupBox.Create(PageData, 'Property Editor', MakeNXRect(330, 210, 360, 260));

  Form7 := TNXGroupBox.Create(PageLayout, 'Memo', MakeNXRect(10, 10, 300, 256));
  Form8 := TNXGroupBox.Create(PageLayout, 'Split Panel', MakeNXRect(330, 10, 300, 140));
  Form10 := TNXGroupBox.Create(PageLayout, 'Layout', MakeNXRect(10, 290, 620, 160));
  Form10.Anchors := [ancLeft, ancRight, ancBottom];

  Form3 := TNXGroupBox.Create(PageVisuals, 'Image', MakeNXRect(10, 10, 400, 325));
  Form5 := TNXGroupBox.Create(PageVisuals, 'Tree Map', MakeNXRect(430, 10, 400, 325));

  LayoutTopPanel := TNXPanel.Create(Form10);
  LayoutTopPanel.Height := 18;
  LayoutTopPanel.BackColor := MakeNXColor(55, 78, 115, 255);
  LayoutTopPanel.Align := caTop;

  LayoutTopLabel := TNXLabel.Create(LayoutTopPanel, MakeNXRect(6, 1, 120, 16));
  LayoutTopLabel.Caption := 'Align Top';

  LayoutBottomPanel := TNXPanel.Create(Form10);
  LayoutBottomPanel.Height := 18;
  LayoutBottomPanel.BackColor := MakeNXColor(88, 55, 74, 255);
  LayoutBottomPanel.Align := caBottom;

  LayoutLeftPanel := TNXPanel.Create(Form10);
  LayoutLeftPanel.Width := 55;
  LayoutLeftPanel.BackColor := MakeNXColor(55, 95, 72, 255);
  LayoutLeftPanel.Align := caLeft;

  LayoutRightPanel := TNXPanel.Create(Form10);
  LayoutRightPanel.Width := 55;
  LayoutRightPanel.BackColor := MakeNXColor(96, 82, 48, 255);
  LayoutRightPanel.Align := caRight;

  LayoutClientPanel := TNXPanel.Create(Form10);
  LayoutClientPanel.BackColor := MakeNXColor(43, 43, 48, 255);
  LayoutClientPanel.Align := caClient;

  LayoutClientLabel := TNXLabel.Create(LayoutClientPanel, MakeNXRect(8, 8, 200, 18));
  LayoutClientLabel.Caption := 'Align Client';

  LayoutAnchorButton := TNXButton.Create(Form10, MakeNXRect(285, 38, 110, 22));
  LayoutAnchorButton.Caption := 'Anchor RB';
  LayoutAnchorButton.Anchors := [ancRight, ancBottom];

  ListBox := TNXListBox.Create(Form4, MakeNXRect(10, 30, 200, 200));
  for lIndex := 1 to 12 do
    ListBox.Items.AddItem('Item ' + IntToStr(lIndex), lIndex);

  Memo1 := TNXMemo.Create(Form7, MakeNXRect(10, 30, 260, 190));
  Memo1.Placeholder := 'Enter notes';
  Memo1.AddLine('Memo control');
  Memo1.AddLine('Supports multiple lines.');
  Memo1.AddLine('Try typing, selecting, and scrolling.');
  for lIndex := 1 to 8 do
    Memo1.AddLine('Line ' + IntToStr(lIndex));

  Chkbox1 := TNXCheckBox.Create(Form2, MakeNXRect(10, 40, 150, 30));
  ChkBox1.Caption := 'Check 1';

  RadioButton1 := TNXRadioButton.Create(Form2, MakeNXRect(10, 80, 150, 30));
  RadioButton1.Caption := 'Exclusive 1';
  RadioButton1.GroupName := 'ExclusiveDemo';
  RadioButton1.Value := True;

  RadioButton2 := TNXRadioButton.Create(Form2, MakeNXRect(150, 80, 150, 30));
  RadioButton2.Caption := 'Exclusive 2';
  RadioButton2.GroupName := 'ExclusiveDemo';

  ComboBox1 := TNXComboBox.Create(Form2, MakeNXRect(10, 130, 220, 25));
  ComboBox1.Caption := 'Choose option';
  ComboBox1.DropDownItemCount := 5;
  ComboBox1.Items.Add('Alpha');
  ComboBox1.Items.Add('Bravo');
  ComboBox1.Items.Add('Charlie');
  ComboBox1.Items.Add('Delta');
  ComboBox1.Items.Add('Echo');
  ComboBox1.SelectedIndex := 0;

  ProgressBar1 := TNXProgressBar.Create(Form2, MakeNXRect(250, 35, 120, 20));
  ProgressBar1.Value := 65;

  ProgressBar2 := TNXProgressBar.Create(Form2, MakeNXRect(250, 70, 20, 90));
  ProgressBar2.Direction := Dir_Vertical;
  ProgressBar2.Value := 40;

  Button1 := TNXButton.Create(Form1, MakeNXRect(10, 100, 100, 20));
  Button1.Caption := 'Dialog';
  Button1.OnMouseClick := @DemoEvents.DialogButtonClick;

  Button2 := TNXButton.Create(Form1, MakeNXRect(130, 100, 100, 20));
  Button2.Caption := 'Menu';
  Button2.OnMouseClick := @DemoEvents.MenuButtonClick;

  Label1 := TNXLabel.Create(Form1, MakeNXRect(10, 40, 200, 30));
  Label1.Caption := 'Press ESC to quit.';

  TextBox1 := TNXEditBox.Create(Form1, MakeNXRect(10, 150, 230, 25));
  TextBox1.Caption := 'Textbox 1';

  TrackBar1 := TNXTrackBar.Create(Form1);
  TrackBar1.SetBounds(10, 200, 220, 28);
  TrackBar1.Value := 35;
  TrackBar1.OnChange := @DemoEvents.TrackBarChanged;

  TrackBar2 := TNXTrackBar.Create(Form2);
  TrackBar2.SetBounds(315, 35, 28, 125);
  TrackBar2.Direction := Dir_Vertical;
  TrackBar2.Value := 60;
  TrackBar2.OnChange := @DemoEvents.TrackBarChanged;

  SplitPanel1 := TNXSplitPanel.Create(Form8);
  SplitPanel1.Left := 10;
  SplitPanel1.Top := 30;
  SplitPanel1.Width := 260;
  SplitPanel1.Height := 70;
  SplitPanel1.SplitPercent := 0.45;

  Label2 := TNXLabel.Create(SplitPanel1.PaneA, MakeNXRect(6, 8, 100, 20));
  Label2.Caption := 'Pane A';
  Label3 := TNXLabel.Create(SplitPanel1.PaneB, MakeNXRect(6, 8, 100, 20));
  Label3.Caption := 'Pane B';

  PopupMenu1 := TNXPopupMenu.Create(RootWindow, Button2);
  PopupMenu1.AddItem('Refresh', nil, 'F5');
  PopupMenu1.AddItem('Checked option').Checked := True;
  PopupMenu1.AddSeparator;
  PopupMenu1.AddItem('Disabled item').Enabled := False;
  PopupMenu1.OnExecute := @DemoEvents.MenuExecute;

  Image1 := TNXImage.Create(Form3, MakeNXRect(0, 0, 398, 298));
  Image1.LoadFromFile(ResourcesDir + 'nexus.png');

  MoneyTreemap1 := TNXTreeMap.Create(Form5);
  GenerateTestData(TestData);
  MoneyTreemap1.Data := TestData;

  TreeList1 := TNXTreeList.Create(Form6);
  TreeList1.Left := 10;
  TreeList1.Top := 10;
  TreeList1.Width := 260;
  TreeList1.Height := 240;

  TreeNode1 := TreeList1.AddNode('Accounts');
  TreeList1.AddChildNode(TreeNode1, 'Checking');
  TreeList1.AddChildNode(TreeNode1, 'Savings');
  TreeList1.AddChildNode(TreeNode1, 'Brokerage');

  TreeNode2 := TreeList1.AddNode('Budget');
  TreeList1.AddChildNode(TreeNode2, 'Housing');
  TreeList1.AddChildNode(TreeNode2, 'Food');
  TreeList1.AddChildNode(TreeNode2, 'Utilities');

  TreeNode3 := TreeList1.AddNode('Reports');
  TreeList1.AddChildNode(TreeNode3, 'Monthly Summary');
  TreeList1.AddChildNode(TreeNode3, 'Category Detail');
  TreeList1.AddChildNode(TreeNode3, 'Net Worth');
  TreeList1.ExpandAll;
  TreeList1.SelectedNode := TreeNode1;

  Grid1 := TNXGrid.Create(Form9);
  Grid1.Left := 10;
  Grid1.Top := 30;
  Grid1.Width := 600;
  Grid1.Height := 130;
  Grid1.ResizeGrid(5, 12);
  Grid1.Headers[0] := 'Code';
  Grid1.Headers[1] := 'Commodity';
  Grid1.Headers[2] := 'Qty';
  Grid1.Headers[3] := 'Price';
  Grid1.Headers[4] := 'Market';
  Grid1.ColWidths[0] := 55;
  Grid1.ColWidths[1] := 130;
  Grid1.ColWidths[2] := 60;
  Grid1.ColWidths[3] := 70;
  Grid1.ColWidths[4] := 120;
  for lIndex := 0 to 11 do
  begin
    Grid1.Cells[0, lIndex] := 'C' + Format('%.3d', [lIndex + 1]);
    Grid1.Cells[1, lIndex] := 'Cargo Item ' + IntToStr(lIndex + 1);
    Grid1.Cells[2, lIndex] := IntToStr((lIndex + 1) * 3);
    Grid1.Cells[3, lIndex] := IntToStr(90 + (lIndex * 11));
    Grid1.Cells[4, lIndex] := 'System ' + Chr(Ord('A') + lIndex);
  end;

  PropertyEditor1 := TNXPropertyEditor.Create(Form11);
  PropertyEditor1.Left := 10;
  PropertyEditor1.Top := 30;
  PropertyEditor1.Width := 330;
  PropertyEditor1.Height := 210;
  PropertyEditor1.AddProperty('Name', 'TNXPropertyEditor', pkString);
  PropertyEditor1.AddProperty('Rows', '5', pkInteger);
  PropertyEditor1.AddProperty('Editable', 'True', pkBoolean);
  PropertyEditor1.AddProperty('SelectedColor', '$336699', pkColor);
  PropertyEditor1.AddProperty('Owner', 'Form11', pkReadOnly, True);

  StatusBar1 := TNXStatusBar.Create(RootWindow);
  StatusBar1.SimplePanel := False;
  StatusBar1.AddPanel('Ready', 160);
  StatusBar1.AddPanel('New controls compiled', 180);
  StatusBar1.AddPanel('ESC quits', 120);

  Application.Run;

  DemoEvents.Free;
end.
