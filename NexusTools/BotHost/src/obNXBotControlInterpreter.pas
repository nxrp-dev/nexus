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
    FRoomJID: UTF8String;
  public
    constructor Create(AHost: TNXBotHost; const ARoomJID: UTF8String);
    procedure Complete(const AToken: QWord;
      const AResult: TNXBotControlResult);
  end;

constructor TNXHumanControlRequest.Create(AHost: TNXBotHost;
  const ARoomJID: UTF8String);
begin
  inherited Create;
  FHost := AHost;
  FRoomJID := ARoomJID;
end;

procedure TNXHumanControlRequest.Complete(const AToken: QWord;
  const AResult: TNXBotControlResult);
begin
  try
    FHost.SendRoomMessage(FRoomJID, TNXBotControlInterpreter.Render(AResult));
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
  lSeparator: Integer;
  lVerb: UTF8String;
begin
  Result := False;
  if not Assigned(APrompt) then
    Exit;
  lBody := UTF8String(Trim(string(APrompt.Body)));
  if SameText(lBody, 'list bots') then
  begin
    AOperation := NXBotControlOperation(bcokList, '', '');
    Exit(True);
  end;
  lSeparator := Pos(' ', lBody);
  if lSeparator < 2 then
    Exit;
  lVerb := Copy(lBody, 1, lSeparator - 1);
  lBotName := UTF8String(Trim(string(Copy(lBody, lSeparator + 1, MaxInt))));
  if (lBotName = '') or (Pos(' ', lBotName) > 0) then
    Exit;
  if SameText(lVerb, 'status') or SameText(lVerb, 'info') then
    AOperation := NXBotControlOperation(bcokStatus, lBotName, '')
  else if SameText(lVerb, 'invite') then
    AOperation := NXBotControlOperation(bcokInvite, lBotName, APrompt.RoomJID)
  else if SameText(lVerb, 'dismiss') then
    AOperation := NXBotControlOperation(bcokDismiss, lBotName, APrompt.RoomJID)
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
    if not lBot.Available then
      Result := Result + 'unavailable'
    else if not lBot.Active then
      Result := Result + 'inactive'
    else
      Result := Result + lBot.AppServerState + ', XMPP ' + lBot.XMPPState;
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
  lAuthorization := NXBotAuthorization(bcoHumanMUC,
    APrompt.VerifiedCallerBareJID, APrompt.RoomJID,
    APrompt.VerifiedMUCIdentity);
  lRequest := TNXHumanControlRequest.Create(FHost, APrompt.RoomJID);
  if not FController.Execute(lOperation, lAuthorization,
    @lRequest.Complete, lToken) then
  begin
    lRequest.Free;
    FHost.SendRoomMessage(APrompt.RoomJID,
      'Control request could not be accepted.');
  end;
end;

end.
