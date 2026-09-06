program NexusBotHost;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  BaseUnix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils,
  obNXCodexAppServer,
  obNXOpenAIProvider,
  obNXBotHostRuntime;

type
  TNXBotHostConsole = class
  public
    procedure Activity(const AText: UTF8String);
  end;

var
  gStopRequested: Boolean = False;

procedure TNXBotHostConsole.Activity(const AText: UTF8String);
begin
  WriteLn(string(AText));
  Flush(Output);
end;

{$IFDEF UNIX}
procedure HandleSignal(ASignal: cint); cdecl;
begin
  gStopRequested := True;
end;
{$ENDIF}

{$IFDEF WINDOWS}
function HandleConsoleControl(AControlType: DWORD): BOOL; stdcall;
begin
  case AControlType of
    CTRL_C_EVENT,
    CTRL_BREAK_EVENT,
    CTRL_CLOSE_EVENT,
    CTRL_LOGOFF_EVENT,
    CTRL_SHUTDOWN_EVENT:
      begin
        gStopRequested := True;
        Exit(True);
      end;
  end;
  Result := False;
end;
{$ENDIF}

procedure InstallStopHandlers;
begin
  {$IFDEF UNIX}
  fpSignal(SIGINT, @HandleSignal);
  fpSignal(SIGTERM, @HandleSignal);
  {$ENDIF}
  {$IFDEF WINDOWS}
  if not SetConsoleCtrlHandler(@HandleConsoleControl, True) then
    raise Exception.Create('Could not install the console control handler.');
  {$ENDIF}
end;

function ResolveConfigFile: string;
begin
  if ParamCount = 0 then
    Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) +
      'NexusBotHost' + PathDelim + 'NexusBotHostLaunch.json'
  else if (ParamCount = 2) and (ParamStr(1) = '--config') then
    Result := ExpandFileName(ParamStr(2))
  else
    raise Exception.Create(
      'Usage: NexusBotHost [--config <launch-config.json>]');
end;

procedure Run;
var
  lConsole: TNXBotHostConsole;
  lRuntime: TNXBotHostRuntime;
begin
  InstallStopHandlers;
  lConsole := TNXBotHostConsole.Create;
  lRuntime := nil;
  try
    lRuntime := TNXBotHostRuntime.Create(ResolveConfigFile);
    lRuntime.OnActivity := @lConsole.Activity;
    lRuntime.Start;
    while not gStopRequested do
      Sleep(100);
    lRuntime.Shutdown;
  finally
    lRuntime.Free;
    lConsole.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'NexusBotHost: ', E.Message);
      Halt(1);
    end;
  end;
end.
