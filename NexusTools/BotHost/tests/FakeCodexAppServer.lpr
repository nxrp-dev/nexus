program FakeCodexAppServer;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  fpjson,
  jsonparser,
  SysUtils;

procedure Send(const AJSON: UTF8String);
const
  cLineFeed: AnsiChar = #10;
begin
  if AJSON <> '' then
    FileWrite(StdOutputHandle, AJSON[1], Length(AJSON));
  FileWrite(StdOutputHandle, cLineFeed, 1);
end;

function JSONString(AData: TJSONData; const AName: string): string;
var
  lValue: TJSONData;
begin
  Result := '';
  if not (AData is TJSONObject) then
    Exit;
  lValue := TJSONObject(AData).Find(AName);
  if Assigned(lValue) then
    Result := lValue.AsString;
end;

var
  lData: TJSONData;
  lID: string;
  lLine: string;
  lMethod: string;
  lValue: TJSONData;
begin
  while not EOF(Input) do
  begin
    ReadLn(lLine);
    if lLine = '' then
      Continue;
    lData := GetJSON(lLine);
    try
      lMethod := JSONString(lData, 'method');
      lID := JSONString(lData, 'id');
      if (lMethod = '') and (lID = '900') then
      begin
        lValue := lData.FindPath('result.decision');
        if (not Assigned(lValue)) or (lValue.AsString <> 'decline') then
          Halt(3);
      end
      else if (lMethod = '') and (lID = '901') then
      begin
        lValue := lData.FindPath('result.success');
        if (not Assigned(lValue)) or lValue.AsBoolean then
          Halt(4);
      end
      else if (lMethod = '') and (lID = '902') then
      begin
        lValue := lData.FindPath('result.success');
        if (not Assigned(lValue)) or not lValue.AsBoolean then
          Halt(5);
        lValue := lData.FindPath('result.contentItems[0].text');
        if (not Assigned(lValue)) or
          (Pos('NexusBot', lValue.AsString) = 0) then
          Halt(6);
      end
      else if (lMethod = '') and (lID = '903') then
      begin
        lValue := lData.FindPath('result.success');
        if (not Assigned(lValue)) or not lValue.AsBoolean then
          Halt(17);
        lValue := lData.FindPath('result.contentItems[0].text');
        if (not Assigned(lValue)) or
          (Pos('returned_bytes=1', lValue.AsString) = 0) or
          (Pos('more=True', lValue.AsString) = 0) then
          Halt(18);
      end
      else if (lMethod = '') and (lID = '904') then
      begin
        lValue := lData.FindPath('result.success');
        if (not Assigned(lValue)) or lValue.AsBoolean then
          Halt(19);
      end
      else if (lMethod = '') and (lID = '905') then
      begin
        lValue := lData.FindPath('result.success');
        if (not Assigned(lValue)) or not lValue.AsBoolean then
          Halt(20);
        lValue := lData.FindPath('result.contentItems[0].text');
        if (not Assigned(lValue)) or
          (Pos('returned_offset=5', lValue.AsString) = 0) or
          (Pos('returned_bytes=1', lValue.AsString) = 0) then
          Halt(21);
      end
      else if lMethod = 'initialize' then
      begin
        lValue := lData.FindPath('params.capabilities.experimentalApi');
        if (not Assigned(lValue)) or not lValue.AsBoolean then
          Halt(9);
        Write('{"id":' + lID + ',"result":');
        Flush(Output);
        Sleep(10);
        Send('{"userAgent":"fake"}}');
        WriteLn(StdErr, 'fake stderr diagnostic');
        Flush(StdErr);
      end
      else if lMethod = 'model/list' then
        Send('{"id":' + lID + ',"result":{"data":[{"id":"gpt-5.6-luna",' +
          '"model":"gpt-5.6-luna","displayName":"Luna"}]}}')
      else if lMethod = 'thread/start' then
      begin
        lValue := lData.FindPath('params.developerInstructions');
        if (not Assigned(lValue)) or
          (Pos('Use the bot_control tool', lValue.AsString) = 0) then
          Halt(11);
        if (Pos('The roster is the set of bots Nexus manages',
          lValue.AsString) = 0) or
          (Pos('Never substitute a plugin, app, service',
          lValue.AsString) = 0) then
          Halt(12);
        lValue := lData.FindPath('params.dynamicTools[0].name');
        if (not Assigned(lValue)) or (lValue.AsString <> 'bot_control') then
          Halt(7);
        lValue := lData.FindPath(
          'params.dynamicTools[0].inputSchema.additionalProperties');
        if (not Assigned(lValue)) or lValue.AsBoolean then
          Halt(8);
        lValue := lData.FindPath(
          'params.dynamicTools[0].inputSchema.properties.room.type');
        if (not Assigned(lValue)) or (lValue.AsString <> 'string') then
          Halt(10);
        lValue := lData.FindPath('params.dynamicTools[1].name');
        if (not Assigned(lValue)) or
          (lValue.AsString <> 'read_attachment') then
          Halt(13);
        lValue := lData.FindPath(
          'params.dynamicTools[1].inputSchema.properties.maximum_bytes.maximum');
        if (not Assigned(lValue)) or (lValue.AsInteger <> 65536) then
          Halt(14);
        lValue := lData.FindPath('params.dynamicTools[2].name');
        if (not Assigned(lValue)) or (lValue.AsString <> 'send_file') then
          Halt(15);
        lValue := lData.FindPath(
          'params.dynamicTools[2].inputSchema.additionalProperties');
        if (not Assigned(lValue)) or lValue.AsBoolean then
          Halt(16);
        Send('{"id":' + lID + ',"result":{"thread":{"id":"thread-1"},' +
          '"model":"gpt-5.6-luna"}}');
        Send('{"method":"fake/unknownNotification","params":{}}');
        Send('{"id":900,"method":"item/commandExecution/requestApproval",' +
          '"params":{"threadId":"thread-1","turnId":"turn-1",' +
          '"itemId":"item-approval"}}');
        Send('{"id":901,"method":"item/tool/call","params":{' +
          '"threadId":"thread-1","turnId":"turn-1","callId":"call-1",' +
          '"namespace":null,"tool":"forbidden","arguments":{}}}');
      end
      else if lMethod = 'turn/start' then
      begin
        Send('{"id":' + lID + ',"result":{"turn":{"id":"turn-1"}}}');
        Send('{"id":902,"method":"item/tool/call","params":{' +
          '"threadId":"thread-1","turnId":"turn-1","callId":"call-2",' +
          '"namespace":null,"tool":"bot_control","arguments":{' +
          '"operation":"status","bot":"NexusBot"}}}');
        Send('{"id":903,"method":"item/tool/call","params":{' +
          '"threadId":"thread-1","turnId":"turn-1","callId":"call-3",' +
          '"namespace":null,"tool":"read_attachment","arguments":{' +
          '"attachment_id":"test-attachment","offset":0,' +
          '"maximum_bytes":3}}}');
        Send('{"id":905,"method":"item/tool/call","params":{' +
          '"threadId":"thread-1","turnId":"turn-1","callId":"call-5",' +
          '"namespace":null,"tool":"read_attachment","arguments":{' +
          '"attachment_id":"test-attachment","offset":2,' +
          '"maximum_bytes":64}}}');
        Send('{"id":904,"method":"item/tool/call","params":{' +
          '"threadId":"thread-1","turnId":"turn-1","callId":"call-4",' +
          '"namespace":null,"tool":"send_file","arguments":{' +
          '"attachment_id":"test-attachment"}}}');
        Send('{"method":"item/completed","params":{"threadId":"thread-1",' +
          '"turnId":"turn-1","item":{"type":"agentMessage",' +
          '"id":"item-commentary","text":"thinking",' +
          '"phase":"commentary"}}}');
        Send('{"method":"item/completed","params":{"threadId":"thread-1",' +
          '"turnId":"turn-1","item":{"type":"agentMessage",' +
          '"id":"item-final","text":"fake — “quoted” café 中文 😀' +
          ' with a deliberately long suffix",' +
          '"phase":"final_answer"}}}');
        Send('{"method":"turn/completed","params":{"threadId":"thread-1",' +
          '"turn":{"id":"turn-1","status":"completed"}}}');
      end
      else if lMethod = 'turn/interrupt' then
        Send('{"id":' + lID + ',"result":{}}')
      else if lMethod = 'thread/unsubscribe' then
        Send('{"id":' + lID + ',"result":{"status":"notLoaded"}}');
    finally
      lData.Free;
    end;
  end;
end.
