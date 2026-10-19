// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program nxbuildPluginTests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, Process, obNXTestRegistry, obNXTestContext,
  obNXTestSuite, utNXTestConsole;

procedure TestPascalPlugin(AContext: TNXTestContext);
var
  lSimulator, lPlugin, lFixture, lOutputDirectory, lOutput: string;
  lLog: TStringList;
  lSucceeded: Boolean;
begin
  lSimulator := ExpandFileName(ParamStr(1));
  lPlugin := ExpandFileName(ParamStr(2));
  lOutputDirectory := ExpandFileName(ParamStr(3));
  lFixture := ExpandFileName(ParamStr(4));
  AContext.AssertTrue(FileExists(lSimulator), 'The actual simulator must exist');
  AContext.AssertTrue(FileExists(lPlugin), 'Build the real Pascal sample plugin first');
  AContext.AssertTrue(FileExists(lFixture), 'The Lua integration fixture must exist');
  ForceDirectories(lOutputDirectory);
  lSucceeded := RunCommandIndir(ExtractFileDir(lSimulator), 'env',
    ['SDL_VIDEODRIVER=offscreen', 'ALSOFT_DRIVERS=null',
     'NXTEST_PASCAL_PLUGIN=' + lPlugin, 'timeout', '20s',
     lSimulator, lFixture], lOutput, [poStderrToOutPut]);
  lLog := TStringList.Create;
  try
    lLog.Text := lOutput;
    lLog.SaveToFile(IncludeTrailingPathDelimiter(lOutputDirectory) + 'pascal-plugin-runtime.log');
  finally
    lLog.Free;
  end;
  AContext.AssertTrue(lSucceeded, 'The real engine/plugin interaction must exit successfully: ' + lOutput);
  AContext.AssertTrue(Pos('NXTEST_ENGINE_PASCAL_PLUGIN_OK', lOutput) > 0,
    'The plugin assertions and engine callback must complete: ' + lOutput);
end;

var
  lRegistry: TNXTestRegistry;
  lSuite: TNXTestSuite;
begin
  if ParamCount <> 4 then
  begin
    WriteLn('Usage: nxbuildPluginTests simulator plugin.so output-directory fixture-main.lua');
    Halt(2);
  end;
  lRegistry := TNXTestRegistry.Create;
  try
    lSuite := lRegistry.AddSuite('Nexus2D.PascalPlugin');
    lSuite.AddTest('ActualEngineInteraction', @TestPascalPlugin);
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
