unit frmNexusLSTestClient;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  StdCtrls,
  ExtCtrls,
  Contnrs,
  blcksock;

type
  TNXLSTestRequest = class
  public
    Name: string;
    RequestJSON: string;
  end;

  TNexusLSTestClientForm = class(TForm)
  private
    FSamples: TObjectList;
    FSock: TTCPBlockSocket;
    FConnected: Boolean;

    FList: TListBox;
    FNameEdit: TEdit;
    FRequestMemo: TMemo;
    FResponseMemo: TMemo;
    FHostEdit: TEdit;
    FPortEdit: TEdit;
    FConnectButton: TButton;
    FDisconnectButton: TButton;
    FStatusLabel: TLabel;
    FSendButton: TButton;
    FSaveButton: TButton;
    FNewButton: TButton;
    FDeleteButton: TButton;

    function CurrentSample: TNXLSTestRequest;
    function StorageFileName: string;
    function SocketError: string;
    function RequestHasID(const AJSON: string): Boolean;
    function ReadLine(out ALine: string): Boolean;
    function ReadMessage(out AMessage: string): Boolean;
    procedure WriteMessage(const AMessage: string);
    procedure BuildUI;
    procedure LoadSamples;
    procedure SaveSamples;
    procedure SeedSamples;
    procedure AddSample(const AName: string; const AJSON: string);
    procedure RefreshList;
    procedure LoadSelectedSample;
    procedure UpdateButtons;
    procedure ConnectButtonClick(Sender: TObject);
    procedure DisconnectButtonClick(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure SendButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure NewButtonClick(Sender: TObject);
    procedure DeleteButtonClick(Sender: TObject);
    procedure Disconnect;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  NexusLSTestClientForm: TNexusLSTestClientForm;

implementation

uses
  fpjson,
  jsonparser;

function FormatJSONText(const AJSON: string): string;
var
  lJSON: TJSONData;
begin
  Result := AJSON;
  lJSON := GetJSON(AJSON);
  try
    Result := lJSON.FormatJSON;
  finally
    lJSON.Free;
  end;
end;

constructor TNexusLSTestClientForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Nexus LS Test Client';
  Width := 1200;
  Height := 760;
  Position := poScreenCenter;

  FSamples := TObjectList.Create(True);
  FSock := TTCPBlockSocket.Create;
  BuildUI;
  LoadSamples;
  UpdateButtons;
end;

destructor TNexusLSTestClientForm.Destroy;
begin
  SaveSamples;
  Disconnect;
  FSock.Free;
  FSamples.Free;
  inherited Destroy;
end;

function TNexusLSTestClientForm.CurrentSample: TNXLSTestRequest;
begin
  if (FList.ItemIndex < 0) or (FList.ItemIndex >= FSamples.Count) then
    Result := nil
  else
    Result := TNXLSTestRequest(FSamples[FList.ItemIndex]);
end;

function TNexusLSTestClientForm.StorageFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'requests.json';
end;

function TNexusLSTestClientForm.SocketError: string;
begin
  Result := Format('%d: %s', [FSock.LastError, FSock.LastErrorDesc]);
end;

function TNexusLSTestClientForm.RequestHasID(const AJSON: string): Boolean;
var
  lJSON: TJSONData;
begin
  Result := False;
  lJSON := GetJSON(AJSON);
  try
    Result := (lJSON is TJSONObject) and (TJSONObject(lJSON).Find('id') <> nil);
  finally
    lJSON.Free;
  end;
end;

function TNexusLSTestClientForm.ReadLine(out ALine: string): Boolean;
begin
  ALine := string(FSock.RecvString(10000));
  Result := FSock.LastError = 0;
end;

function TNexusLSTestClientForm.ReadMessage(out AMessage: string): Boolean;
var
  lLine: string;
  lName: string;
  lValue: string;
  lPos: SizeInt;
  lContentLength: Integer;
begin
  AMessage := '';
  lContentLength := -1;

  while ReadLine(lLine) do
  begin
    if lLine = '' then
      Break;

    lPos := Pos(':', lLine);
    if lPos <= 0 then
      raise Exception.CreateFmt('Invalid response header "%s".', [lLine]);

    lName := Trim(Copy(lLine, 1, lPos - 1));
    lValue := Trim(Copy(lLine, lPos + 1, Length(lLine) - lPos));

    if SameText(lName, 'Content-Length') then
      lContentLength := StrToIntDef(lValue, -1);
  end;

  if FSock.LastError <> 0 then
    raise Exception.Create('Unable to read response headers. ' + SocketError);

  if lContentLength < 0 then
    raise Exception.Create('Response is missing Content-Length.');

  AMessage := string(FSock.RecvBufferStr(lContentLength, 10000));
  if FSock.LastError <> 0 then
    raise Exception.Create('Unable to read response body. ' + SocketError);

  if Length(AMessage) <> lContentLength then
    raise Exception.Create('Unexpected end of response body.');

  Result := True;
end;

procedure TNexusLSTestClientForm.WriteMessage(const AMessage: string);
var
  lPayload: AnsiString;
  lBody: AnsiString;
begin
  lBody := AnsiString(AMessage);
  lPayload :=
    'Content-Type: application/vscode-jsonrpc; charset=utf-8' + #13#10 +
    'Content-Length: ' + AnsiString(IntToStr(Length(lBody))) + #13#10 +
    #13#10 +
    lBody;

  FSock.SendString(lPayload);
  if FSock.LastError <> 0 then
    raise Exception.Create('Unable to send request. ' + SocketError);
end;

procedure TNexusLSTestClientForm.BuildUI;
var
  lLeft: TPanel;
  lConnection: TPanel;
  lTop: TPanel;
  lSplit: TSplitter;
  lRight: TPanel;
  lRequestPanel: TPanel;
  lResponsePanel: TPanel;
  lButtonPanel: TPanel;
  lHostLabel: TLabel;
  lPortLabel: TLabel;
  lNameLabel: TLabel;
  lResponseLabel: TLabel;
begin
  lLeft := TPanel.Create(Self);
  lLeft.Parent := Self;
  lLeft.Align := alLeft;
  lLeft.Width := 300;
  lLeft.BevelOuter := bvNone;
  lLeft.BorderSpacing.Around := 8;

  FList := TListBox.Create(Self);
  FList.Parent := lLeft;
  FList.Align := alClient;
  FList.OnClick := @ListClick;

  lButtonPanel := TPanel.Create(Self);
  lButtonPanel.Parent := lLeft;
  lButtonPanel.Align := alBottom;
  lButtonPanel.Height := 38;
  lButtonPanel.BevelOuter := bvNone;

  FNewButton := TButton.Create(Self);
  FNewButton.Parent := lButtonPanel;
  FNewButton.Align := alLeft;
  FNewButton.Width := 72;
  FNewButton.Caption := 'New';
  FNewButton.OnClick := @NewButtonClick;

  FDeleteButton := TButton.Create(Self);
  FDeleteButton.Parent := lButtonPanel;
  FDeleteButton.Align := alLeft;
  FDeleteButton.Width := 72;
  FDeleteButton.Caption := 'Delete';
  FDeleteButton.OnClick := @DeleteButtonClick;

  lSplit := TSplitter.Create(Self);
  lSplit.Parent := Self;
  lSplit.Align := alLeft;

  lRight := TPanel.Create(Self);
  lRight.Parent := Self;
  lRight.Align := alClient;
  lRight.BevelOuter := bvNone;
  lRight.BorderSpacing.Around := 8;

  lConnection := TPanel.Create(Self);
  lConnection.Parent := lRight;
  lConnection.Align := alTop;
  lConnection.Height := 36;
  lConnection.BevelOuter := bvNone;

  lHostLabel := TLabel.Create(Self);
  lHostLabel.Parent := lConnection;
  lHostLabel.Align := alLeft;
  lHostLabel.Width := 42;
  lHostLabel.Caption := 'Host';

  FHostEdit := TEdit.Create(Self);
  FHostEdit.Parent := lConnection;
  FHostEdit.Align := alLeft;
  FHostEdit.Width := 140;
  FHostEdit.Text := '127.0.0.1';

  lPortLabel := TLabel.Create(Self);
  lPortLabel.Parent := lConnection;
  lPortLabel.Align := alLeft;
  lPortLabel.Width := 36;
  lPortLabel.Caption := 'Port';

  FPortEdit := TEdit.Create(Self);
  FPortEdit.Parent := lConnection;
  FPortEdit.Align := alLeft;
  FPortEdit.Width := 70;
  FPortEdit.Text := '2087';

  FConnectButton := TButton.Create(Self);
  FConnectButton.Parent := lConnection;
  FConnectButton.Align := alLeft;
  FConnectButton.Width := 88;
  FConnectButton.Caption := 'Connect';
  FConnectButton.OnClick := @ConnectButtonClick;

  FDisconnectButton := TButton.Create(Self);
  FDisconnectButton.Parent := lConnection;
  FDisconnectButton.Align := alLeft;
  FDisconnectButton.Width := 88;
  FDisconnectButton.Caption := 'Disconnect';
  FDisconnectButton.OnClick := @DisconnectButtonClick;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := lConnection;
  FStatusLabel.Align := alClient;
  FStatusLabel.Caption := 'Disconnected';

  lTop := TPanel.Create(Self);
  lTop.Parent := lRight;
  lTop.Align := alTop;
  lTop.Height := 36;
  lTop.BevelOuter := bvNone;

  lNameLabel := TLabel.Create(Self);
  lNameLabel.Parent := lTop;
  lNameLabel.Align := alLeft;
  lNameLabel.Width := 48;
  lNameLabel.Caption := 'Name';

  FNameEdit := TEdit.Create(Self);
  FNameEdit.Parent := lTop;
  FNameEdit.Align := alClient;

  FSaveButton := TButton.Create(Self);
  FSaveButton.Parent := lTop;
  FSaveButton.Align := alRight;
  FSaveButton.Width := 96;
  FSaveButton.Caption := 'Save';
  FSaveButton.OnClick := @SaveButtonClick;

  FSendButton := TButton.Create(Self);
  FSendButton.Parent := lTop;
  FSendButton.Align := alRight;
  FSendButton.Width := 96;
  FSendButton.Caption := 'Send';
  FSendButton.OnClick := @SendButtonClick;

  lRequestPanel := TPanel.Create(Self);
  lRequestPanel.Parent := lRight;
  lRequestPanel.Align := alLeft;
  lRequestPanel.Width := 430;
  lRequestPanel.BevelOuter := bvNone;

  FRequestMemo := TMemo.Create(Self);
  FRequestMemo.Parent := lRequestPanel;
  FRequestMemo.Align := alClient;
  FRequestMemo.ScrollBars := ssBoth;
  FRequestMemo.WordWrap := False;

  lSplit := TSplitter.Create(Self);
  lSplit.Parent := lRight;
  lSplit.Align := alLeft;

  lResponsePanel := TPanel.Create(Self);
  lResponsePanel.Parent := lRight;
  lResponsePanel.Align := alClient;
  lResponsePanel.BevelOuter := bvNone;

  lResponseLabel := TLabel.Create(Self);
  lResponseLabel.Parent := lResponsePanel;
  lResponseLabel.Align := alTop;
  lResponseLabel.Height := 22;
  lResponseLabel.Caption := 'Response JSON';

  FResponseMemo := TMemo.Create(Self);
  FResponseMemo.Parent := lResponsePanel;
  FResponseMemo.Align := alClient;
  FResponseMemo.ScrollBars := ssBoth;
  FResponseMemo.WordWrap := False;
end;

procedure TNexusLSTestClientForm.LoadSamples;
var
  lJSON: TJSONData;
  lArray: TJSONArray;
  lObject: TJSONObject;
  lIdx: Integer;
  lFile: TStringList;
begin
  if FileExists(StorageFileName) then
  begin
    lFile := TStringList.Create;
    try
      lFile.LoadFromFile(StorageFileName);
      lJSON := GetJSON(lFile.Text);
    finally
      lFile.Free;
    end;
    try
      if lJSON is TJSONArray then
      begin
        lArray := TJSONArray(lJSON);
        for lIdx := 0 to lArray.Count - 1 do
          if lArray.Items[lIdx] is TJSONObject then
          begin
            lObject := TJSONObject(lArray.Items[lIdx]);
            AddSample(lObject.Get('name', ''), lObject.Get('request', ''));
          end;
      end;
    finally
      lJSON.Free;
    end;
  end;

  if FSamples.Count = 0 then
    SeedSamples;

  RefreshList;
  if FList.Count > 0 then
    FList.ItemIndex := 0;
  LoadSelectedSample;
end;

procedure TNexusLSTestClientForm.SaveSamples;
var
  lArray: TJSONArray;
  lObject: TJSONObject;
  lSample: TNXLSTestRequest;
  lIdx: Integer;
  lStream: TFileStream;
  lText: string;
begin
  SaveButtonClick(nil);

  lArray := TJSONArray.Create;
  try
    for lIdx := 0 to FSamples.Count - 1 do
    begin
      lSample := TNXLSTestRequest(FSamples[lIdx]);
      lObject := TJSONObject.Create;
      lObject.Add('name', lSample.Name);
      lObject.Add('request', lSample.RequestJSON);
      lArray.Add(lObject);
    end;

    ForceDirectories(ExtractFilePath(StorageFileName));
    lText := lArray.FormatJSON;
    lStream := TFileStream.Create(StorageFileName, fmCreate);
    try
      if lText <> '' then
        lStream.WriteBuffer(lText[1], Length(lText));
    finally
      lStream.Free;
    end;
  finally
    lArray.Free;
  end;
end;

procedure TNexusLSTestClientForm.SeedSamples;
begin
  AddSample('initialize',
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":null,"capabilities":{}}}');
  AddSample('initialized',
    '{"jsonrpc":"2.0","method":"initialized","params":{}}');
  AddSample('didOpen',
    '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///C:/tmp/test.pas","languageId":"pascal","version":1,"text":"program Test;\nbegin\nend.\n"}}}');
  AddSample('didChange full',
    '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///C:/tmp/test.pas","version":2},"contentChanges":[{"text":"program Test;\nbegin\n  WriteLn(''hello'');\nend.\n"}]}}');
  AddSample('didClose',
    '{"jsonrpc":"2.0","method":"textDocument/didClose","params":{"textDocument":{"uri":"file:///C:/tmp/test.pas"}}}');
  AddSample('shutdown',
    '{"jsonrpc":"2.0","id":2,"method":"shutdown"}');
  AddSample('exit',
    '{"jsonrpc":"2.0","method":"exit"}');
end;

procedure TNexusLSTestClientForm.AddSample(const AName: string; const AJSON: string);
var
  lSample: TNXLSTestRequest;
begin
  lSample := TNXLSTestRequest.Create;
  lSample.Name := AName;
  try
    lSample.RequestJSON := FormatJSONText(AJSON);
  except
    lSample.RequestJSON := AJSON;
  end;
  FSamples.Add(lSample);
end;

procedure TNexusLSTestClientForm.RefreshList;
var
  lIdx: Integer;
begin
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    for lIdx := 0 to FSamples.Count - 1 do
      FList.Items.Add(TNXLSTestRequest(FSamples[lIdx]).Name);
  finally
    FList.Items.EndUpdate;
  end;
end;

procedure TNexusLSTestClientForm.LoadSelectedSample;
var
  lSample: TNXLSTestRequest;
begin
  lSample := CurrentSample;
  if lSample = nil then
  begin
    FNameEdit.Clear;
    FRequestMemo.Clear;
  end
  else
  begin
    FNameEdit.Text := lSample.Name;
    FRequestMemo.Text := lSample.RequestJSON;
  end;
  UpdateButtons;
end;

procedure TNexusLSTestClientForm.UpdateButtons;
begin
  FSendButton.Enabled := (CurrentSample <> nil) and FConnected;
  FSaveButton.Enabled := True;
  FDeleteButton.Enabled := CurrentSample <> nil;
  FConnectButton.Enabled := not FConnected;
  FDisconnectButton.Enabled := FConnected;
end;

procedure TNexusLSTestClientForm.ConnectButtonClick(Sender: TObject);
begin
  Disconnect;
  FSock.Connect(FHostEdit.Text, FPortEdit.Text);
  if FSock.LastError <> 0 then
  begin
    FStatusLabel.Caption := 'Connection failed: ' + SocketError;
    UpdateButtons;
    Exit;
  end;

  FConnected := True;
  FStatusLabel.Caption := 'Connected to ' + FHostEdit.Text + ':' + FPortEdit.Text;
  UpdateButtons;
end;

procedure TNexusLSTestClientForm.DisconnectButtonClick(Sender: TObject);
begin
  Disconnect;
  UpdateButtons;
end;

procedure TNexusLSTestClientForm.ListClick(Sender: TObject);
begin
  LoadSelectedSample;
end;

procedure TNexusLSTestClientForm.SendButtonClick(Sender: TObject);
var
  lResponse: string;
begin
  SaveButtonClick(nil);

  FResponseMemo.Clear;
  try
    if not FConnected then
      raise Exception.Create('Not connected.');

    WriteMessage(FRequestMemo.Text);
    if RequestHasID(FRequestMemo.Text) then
    begin
      if ReadMessage(lResponse) then
        FResponseMemo.Text := FormatJSONText(lResponse);
    end
    else
      FResponseMemo.Text := '(notification sent; no response expected)';
  except
    on E: Exception do
    begin
      FResponseMemo.Text := E.ClassName + ': ' + E.Message;
      FStatusLabel.Caption := 'Error';
      Disconnect;
    end;
  end;
  UpdateButtons;
end;

procedure TNexusLSTestClientForm.SaveButtonClick(Sender: TObject);
var
  lSample: TNXLSTestRequest;
  lIndex: Integer;
begin
  lSample := CurrentSample;
  if lSample = nil then
  begin
    AddSample(FNameEdit.Text, FRequestMemo.Text);
    FList.ItemIndex := FSamples.Count - 1;
  end
  else
  begin
    lSample.Name := FNameEdit.Text;
    lSample.RequestJSON := FRequestMemo.Text;
  end;

  lIndex := FList.ItemIndex;
  RefreshList;
  if (lIndex >= 0) and (lIndex < FList.Count) then
    FList.ItemIndex := lIndex;
  UpdateButtons;
end;

procedure TNexusLSTestClientForm.NewButtonClick(Sender: TObject);
begin
  AddSample('new request', '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}');
  RefreshList;
  FList.ItemIndex := FSamples.Count - 1;
  LoadSelectedSample;
end;

procedure TNexusLSTestClientForm.DeleteButtonClick(Sender: TObject);
var
  lIndex: Integer;
begin
  lIndex := FList.ItemIndex;
  if (lIndex < 0) or (lIndex >= FSamples.Count) then
    Exit;

  FSamples.Delete(lIndex);
  RefreshList;

  if lIndex >= FList.Count then
    lIndex := FList.Count - 1;
  FList.ItemIndex := lIndex;
  LoadSelectedSample;
end;

procedure TNexusLSTestClientForm.Disconnect;
begin
  if FSock <> nil then
    FSock.CloseSocket;

  FConnected := False;
  if FStatusLabel <> nil then
    FStatusLabel.Caption := 'Disconnected';
end;

end.
