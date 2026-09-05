program CodexAppServerLiveTest;

{$mode objfpc}{$H+}

uses
  SysUtils,
  obNXCodexAppServer,
  tpNXBotHost;

type
  TLiveRecorder = class
  private
    FAnswer: UTF8String;
    FCriticalSection: TRTLCriticalSection;
    FDone: Boolean;
    FFailed: Boolean;
    FReady: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Diagnostic(ASender: TObject; const AText: UTF8String);
    procedure FinalAnswer(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    procedure PromptFailed(ASender: TObject; APrompt: TNXBotPrompt;
      const AText: UTF8String);
    procedure StateChanged(ASender: TObject; AState: TNXCodexAppServerState;
      const ADetail: UTF8String);
    procedure Snapshot(out AReady, ADone, AFailed: Boolean;
      out AAnswer: UTF8String);
  end;

constructor TLiveRecorder.Create;
begin
  inherited Create;
  InitCriticalSection(FCriticalSection);
end;

destructor TLiveRecorder.Destroy;
begin
  DoneCriticalSection(FCriticalSection);
  inherited Destroy;
end;

procedure TLiveRecorder.Diagnostic(ASender: TObject; const AText: UTF8String);
begin
  WriteLn('diagnostic: ', string(AText));
end;

procedure TLiveRecorder.FinalAnswer(ASender: TObject; APrompt: TNXBotPrompt;
  const AText: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    FAnswer := AText;
    FDone := True;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TLiveRecorder.PromptFailed(ASender: TObject; APrompt: TNXBotPrompt;
  const AText: UTF8String);
begin
  WriteLn('prompt failed: ', string(AText));
  EnterCriticalSection(FCriticalSection);
  try
    FFailed := True;
    FDone := True;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TLiveRecorder.StateChanged(ASender: TObject;
  AState: TNXCodexAppServerState; const ADetail: UTF8String);
begin
  WriteLn('state: ', Ord(AState), ' ', string(ADetail));
  EnterCriticalSection(FCriticalSection);
  try
    FReady := AState = cassReady;
    if AState = cassFailed then
      FFailed := True;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TLiveRecorder.Snapshot(out AReady, ADone, AFailed: Boolean;
  out AAnswer: UTF8String);
begin
  EnterCriticalSection(FCriticalSection);
  try
    AReady := FReady;
    ADone := FDone;
    AFailed := FFailed;
    AAnswer := FAnswer;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

var
  lAnswer: UTF8String;
  lAppServer: TNXCodexAppServer;
  lDeadline: QWord;
  lDone: Boolean;
  lFailed: Boolean;
  lPrompt: TNXBotPrompt;
  lReady: Boolean;
  lRecorder: TLiveRecorder;
begin
  if ParamCount <> 3 then
  begin
    WriteLn('Usage: CodexAppServerLiveTest <codex.exe> <runtime-dir> <model>');
    Halt(2);
  end;
  lRecorder := TLiveRecorder.Create;
  lAppServer := TNXCodexAppServer.Create;
  try
    lAppServer.OnDiagnostic := @lRecorder.Diagnostic;
    lAppServer.OnFinalAnswer := @lRecorder.FinalAnswer;
    lAppServer.OnPromptFailed := @lRecorder.PromptFailed;
    lAppServer.OnState := @lRecorder.StateChanged;
    if not lAppServer.StartServer(ParamStr(1), ParamStr(2),
      UTF8String(ParamStr(3))) then
      raise Exception.Create('Start command was rejected.');
    lDeadline := GetTickCount64 + 30000;
    repeat
      lRecorder.Snapshot(lReady, lDone, lFailed, lAnswer);
      if lReady or lFailed then
        Break;
      Sleep(10);
    until GetTickCount64 >= lDeadline;
    if not lReady then
      raise Exception.Create('App Server did not become ready.');
    lPrompt := TNXBotPrompt.Create(1, 'local', 'local/test', 'live-1',
      'Reply with exactly: Nexus BotHost live test passed');
    if not lAppServer.SubmitPrompt(lPrompt) then
      raise Exception.Create('Prompt command was rejected.');
    lDeadline := GetTickCount64 + 120000;
    repeat
      lRecorder.Snapshot(lReady, lDone, lFailed, lAnswer);
      if lDone or lFailed then
        Break;
      Sleep(10);
    until GetTickCount64 >= lDeadline;
    if not lDone then
      raise Exception.Create('Codex turn did not complete.');
    if lFailed then
      Halt(1);
    WriteLn('answer: ', string(lAnswer));
    lAppServer.StopServer;
  finally
    lAppServer.Free;
    lRecorder.Free;
  end;
end.
