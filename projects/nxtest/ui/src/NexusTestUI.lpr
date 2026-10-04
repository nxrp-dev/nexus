program NexusTestUI;

{$linklib lua}

{$mode objfpc}{$H+}
{$apptype GUI}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  uiNXTestMain,
  tsNXLuaSkinSmoke,
  tsNXLuaSkinBenchmark,
  uiNXRenderPrototype,
  tsNXRenderSubscription,
  tsNXRenderBenchmark,
  Classes, SysUtils;

procedure ReportFailure(AException: Exception);
var
  lReport: TStringList;
begin
  lReport := TStringList.Create;
  try
    lReport.Add(AException.ClassName + ': ' + AException.Message);
    lReport.SaveToFile(ExtractFilePath(ParamStr(0)) + 'NexusTestUI.error.log');
  finally
    lReport.Free;
  end;
end;

begin
  try
    if (ParamCount = 3) and (ParamStr(1) = '--render-benchmark') then
    begin
      RunNXRenderBenchmark(StrToInt(ParamStr(2)), ParamStr(3));
      Halt(0);
    end;
    if (ParamCount = 2) and (ParamStr(1) = '--render-smoke') then
    begin
      RunNXRenderSubscriptionTests(ParamStr(2));
      Halt(0);
    end;
    if (ParamCount = 2) and (ParamStr(1) = '--panel-prototype') then
    begin
      RunNXRenderPrototype(ParamStr(2));
      Halt(0);
    end;
  except
    on lException: Exception do
    begin
      ReportFailure(lException);
      Halt(1);
    end;
  end;
  if (ParamCount = 3) and (ParamStr(1) = '--skin-benchmark') then
  begin
    try
      RunNXLuaSkinBenchmark(StrToInt(ParamStr(2)), ParamStr(3));
      Halt(0);
    except
      on lException: Exception do
      begin
        ReportFailure(lException);
        Halt(1);
      end;
    end;
  end;
  if (ParamCount = 1) and (ParamStr(1) = '--skin-smoke') then
  begin
    try
      RunNXLuaSkinSmoke;
      Halt(0);
    except
      on lException: Exception do
      begin
        ReportFailure(lException);
        Halt(1);
      end;
    end;
  end;
  RunNexusTestUI;
end.
