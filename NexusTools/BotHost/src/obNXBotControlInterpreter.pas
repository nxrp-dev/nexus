unit obNXBotControlInterpreter;

{$mode objfpc}{$H+}

interface

uses
  obNXBotController,
  obNXBotHost,
  tpNXBotControl,
  tpNXBotHost;

type
  TNXBotControlInterpreter = class
  private
    FController: TNXBotController;
    FHost: TNXBotHost;
  public
    constructor Create(AController: TNXBotController; AHost: TNXBotHost);
    function HandlePrompt(ASender: TObject; APrompt: TNXBotPrompt): Boolean;
    class function Parse(APrompt: TNXBotPrompt;
      out AOperation: TNXBotControlOperation): Boolean;
    class function Render(const AResult: TNXBotControlResult): UTF8String;
  end;

implementation

uses
  SysUtils;

type
  TNXHumanControlRequest = class
  private
    FHost: TNXBotHost;
    FPrompt: TNXBotPrompt;
  public
    constructor Create(AHost: TNXBotHost; APrompt: TNXBotPrompt);
    destructor Destroy; override;
    procedure Complete(const AToken: QWord;
      const AResult: TNXBotControlResult);
  end;

constructor TNXHumanControlRequest.Create(AHost: TNXBotHost;
  APrompt: TNXBotPrompt);
begin
  inherited Create;
  FHost := AHost;
  FPrompt := APrompt.Clone;
end;

destructor TNXHumanControlRequest.Destroy;
begin
  FPrompt.Free;
  inherited Destroy;
end;

procedure TNXHumanControlRequest.Complete(const AToken: QWord;
  const AResult: TNXBotControlResult);
begin
  try
    FHost.SendPromptResponse(FPrompt,
      TNXBotControlInterpreter.Render(AResult));
  finally
    Free;
  end;
end;

constructor TNXBotControlInterpreter.Create(AController: TNXBotController;
  AHost: TNXBotHost);
begin
  inherited Create;
  if not Assigned(AController) or not Assigned(AHost) then
    raise Exception.Create('Control interpreter requires controller and host.');
  FController := AController;
  FHost := AHost;
end;

class function TNXBotControlInterpreter.Parse(APrompt: TNXBotPrompt;
  out AOperation: TNXBotControlOperation): Boolean;
var
  lBody: UTF8String;
  lBotName: UTF8String;
  lRoomJID: UTF8String;
  lSeparator: Integer;
  lVerb: UTF8String;
begin
  Result := False;
  if not Assigned(APrompt) then
    Exit;
  lBody := UTF8String(Trim(string(APrompt.Body)));
  if SameText(lBody, 'list roster') then
  begin
    AOperation := NXBotControlOperation(bcokList, '', '');
    Exit(True);
  end;
  lSeparator := Pos(' ', lBody);
  if lSeparator < 2 then
    Exit;
  lVerb := Copy(lBody, 1, lSeparator - 1);
  lBody := UTF8String(Trim(string(Copy(lBody, lSeparator + 1, MaxInt))));
  lSeparator := Pos(' ', lBody);
  if lSeparator > 0 then
  begin
    lBotName := Copy(lBody, 1, lSeparator - 1);
    lRoomJID := UTF8String(Trim(string(Copy(lBody, lSeparator + 1, MaxInt))));
  end
  else
  begin
    lBotName := lBody;
    lRoomJID := '';
  end;
  if (lBotName = '') or ((lRoomJID <> '') and (Pos(' ', lRoomJID) > 0)) then
    Exit;
  if (SameText(lVerb, 'status') or SameText(lVerb, 'info')) and
    (lRoomJID = '') then
    AOperation := NXBotControlOperation(bcokStatus, lBotName, '')
  else if SameText(lVerb, 'invite') then
  begin
    if lRoomJID = '' then
      lRoomJID := APrompt.RoomJID;
    AOperation := NXBotControlOperation(bcokInvite, lBotName, lRoomJID);
  end
  else if SameText(lVerb, 'dismiss') then
  begin
    if lRoomJID = '' then
      lRoomJID := APrompt.RoomJID;
    AOperation := NXBotControlOperation(bcokDismiss, lBotName, lRoomJID);
  end
  else
    Exit;
  Result := True;
end;

class function TNXBotControlInterpreter.Render(
  const AResult: TNXBotControlResult): UTF8String;
var
  lBot: TNXBotStatus;
  lIndex: Integer;
begin
  if AResult.Error <> bceNone then
    Exit('Control failed (' + NXBotControlErrorName(AResult.Error) +
      '): ' + AResult.Detail);
  if Length(AResult.Bots) = 0 then
    Exit(AResult.Detail);
  Result := '';
  for lIndex := 0 to High(AResult.Bots) do
  begin
    lBot := AResult.Bots[lIndex];
    if Result <> '' then
      Result := Result + #10;
    Result := Result + lBot.Name + ': ';
    if not lBot.Active then
      Result := Result + 'inactive'
    else
      Result := Result + lBot.ProviderState + ', XMPP ' + lBot.XMPPState;
  end;
  if AResult.NoOp then
    Result := Result + ' (no change)';
end;

function TNXBotControlInterpreter.HandlePrompt(ASender: TObject;
  APrompt: TNXBotPrompt): Boolean;
var
  lAuthorization: TNXBotAuthorization;
  lOperation: TNXBotControlOperation;
  lRequest: TNXHumanControlRequest;
  lToken: QWord;
begin
  Result := Parse(APrompt, lOperation);
  if not Result then
    Exit;
  if (APrompt.Delivery = bpdDirect) and (APrompt.RoomJID = '') then
    lAuthorization := NXBotAuthorization(bcoHumanDM,
      APrompt.VerifiedCallerBareJID, '', False)
  else
    lAuthorization := NXBotAuthorization(bcoHumanMUC,
      APrompt.VerifiedCallerBareJID, APrompt.RoomJID,
      APrompt.VerifiedMUCIdentity);
  lRequest := TNXHumanControlRequest.Create(FHost, APrompt);
  if not FController.Execute(lOperation, lAuthorization,
    @lRequest.Complete, lToken) then
  begin
    lRequest.Free;
    FHost.SendPromptResponse(APrompt, 'Control request could not be accepted.');
  end;
end;

end.
