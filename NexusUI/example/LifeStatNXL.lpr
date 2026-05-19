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
  obNXGroupBox,
  obNXImage,
  obNXLabel,
  obNXListBox,
  obNXMemo,
  obNXMessageDialog,
  obNXPopupMenu,
  obNXProgressBar,
  obNXSplitPanel,
  obNXStatusBar,
  obNXTreeList,
  obNXTreeMap,
  obNXTreeMapTestData,
  obNXWindow,
  obNXApplication,
  tpNXPlatform,
  tpNXWindow;

type
  TDemoEvents = class
  public
    procedure DialogButtonClick(Sender: TObject; X, Y: Integer; Button: TNXMouseButton);
    procedure DialogResult(Sender: TObject; AResult: TNXModalResult);
    procedure MenuButtonClick(Sender: TObject; X, Y: Integer; Button: TNXMouseButton);
    procedure MenuExecute(Sender: TObject; AItem: TNXMenuItem);
  end;

var
  Form1, Form2, Form3, Form4, Form5, Form6, Form7, Form8: TNXGroupBox;
  Button1, Button2: TNXButton;
  Chkbox1: TNXCheckBox;
  Chkbox2, Chkbox3: TNXCheckBox;
  ComboBox1: TNXComboBox;
  Label1: TNXLabel;
  Label2: TNXLabel;
  Label3: TNXLabel;
  TextBox1: TNXEditBox;
  Image1: TNXImage;
  ListBox: TNXListBox;
  Memo1: TNXMemo;
  PopupMenu1: TNXPopupMenu;
  ProgressBar1: TNXProgressBar;
  ProgressBar2: TNXProgressBar;
  SplitPanel1: TNXSplitPanel;
  StatusBar1: TNXStatusBar;
  TreeList1: TNXTreeList;
  TreeNode1: TNXTreeListNode;
  TreeNode2: TNXTreeListNode;
  TreeNode3: TNXTreeListNode;

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

begin
  Application.Initialize('Window', 1024, 768);
  Application.Skin.LoadFromFile('..\skins\button\skin.json', Application.Canvas);

  RootWindow := Application.RootWindow;
  DemoEvents := TDemoEvents.Create;

  Form1 := TNXGroupBox.Create(RootWindow, 'Form1', MakeNXRect(0, 0, 250, 256));
  Form2 := TNXGroupBox.Create(RootWindow, 'Form2', MakeNXRect(500, 400, 400, 200));
  Form3 := TNXGroupBox.Create(RootWindow, 'Form3', MakeNXRect(0, 400, 400, 325));
  Form4 := TNXGroupBox.Create(RootWindow, 'Form4', MakeNXRect(600, 0, 300, 300));
  Form5 := TNXGroupBox.Create(RootWindow, 'Form5', MakeNXRect(550, 50, 300, 300));
  Form6 := TNXGroupBox.Create(RootWindow, 'Tree List', MakeNXRect(900, 0, 300, 300));
  Form7 := TNXGroupBox.Create(RootWindow, 'Memo', MakeNXRect(260, 0, 300, 256));
  Form8 := TNXGroupBox.Create(RootWindow, 'Split Panel', MakeNXRect(260, 270, 300, 120));

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

  Chkbox2 := TNXCheckBox.Create(Form2, MakeNXRect(10, 80, 150, 30));
  ChkBox2.Caption := 'Exclusive 1';
  ChkBox2.ExcGroup := 1;

  Chkbox3 := TNXCheckBox.Create(Form2, MakeNXRect(150, 80, 150, 30));
  ChkBox3.Caption := 'Exclusive 2';
  ChkBox3.ExcGroup := 1;

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

  StatusBar1 := TNXStatusBar.Create(RootWindow);
  StatusBar1.SimplePanel := False;
  StatusBar1.AddPanel('Ready', 160);
  StatusBar1.AddPanel('New controls compiled', 180);
  StatusBar1.AddPanel('ESC quits', 120);

  Application.Run;

  DemoEvents.Free;
end.