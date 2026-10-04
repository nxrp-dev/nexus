(*
  Copyright (c) 2026 Kevin Collins.
  
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  
  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.
  
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program NexusForge;

{$mode delphi}{$H+}

uses Classes, SysUtils, obNXCommandLine, obNexusScriptModel,
  obNXForge, obNXForgeInvocation, obNXForgePackages, tpNXForge;

procedure PrintInvocation(AInvocation: TNXForgeInvocation);
begin
  if AInvocation.TemplatePath <> '' then
    WriteLn(AInvocation.OperationName, ' [', AInvocation.TemplatePath, ']')
  else WriteLn(AInvocation.OperationName);
  WriteLn('cwd: ', AInvocation.WorkingDirectory);
  if AInvocation.Kind = fokCommand then
    WriteLn('command: ', AInvocation.Command)
  else
  begin
    if AInvocation.Kind = fokDeletePath then
      WriteLn('path: ', AInvocation.SourcePath)
    else if AInvocation.SourcePath <> '' then
      WriteLn('source: ', AInvocation.SourcePath);
    if AInvocation.OutputPath <> '' then
      WriteLn('output: ', AInvocation.OutputPath);
    if AInvocation.Kind = fokArchive then
      WriteLn('archive: ', AInvocation.ArchiveOperation);
    if AInvocation.Kind = fokRender then
    begin
      if AInvocation.Completed then WriteLn('written') else WriteLn('not written');
    end
    else if AInvocation.Completed then WriteLn('completed')
    else WriteLn('not completed');
  end;
  if AInvocation.Started then WriteLn('started') else WriteLn('not started');
  Write(AInvocation.StdOut);
  Write(StdErr, AInvocation.StdErr);
  if AInvocation.Exited then WriteLn('exit: ', AInvocation.ExitStatus);
end;

procedure RunPackage(ATargets: TNexusScriptTargetSelection);
var
  lPackages: TNXForgePackages;
  lRequest: TNXPackageRequest;
  lInvocation: TNXForgeInvocation;
  lOutput: TNXPackageOutput;
begin
  if TNXCommandLine.Supplied('working-directory') then
    raise ENXForge.Create('Package operations use their defining directory');
  lPackages := TNXForgePackages.Create;
  try
    if not lPackages.Execute(TNXCommandLine.GetValueDefault('input', ''),
      TNXCommandLine.GetValueDefault('package', ''),
      ATargets) then ExitCode := 1;
    for lRequest in lPackages.CompletionOrder do
    begin
      WriteLn('package: ', lRequest.Description, ' root: ', lRequest.Root);
      if lRequest.Reused then WriteLn('reused')
      else if lRequest.Ready then WriteLn('built') else WriteLn('not ready');
      if FileExists(lRequest.LogPath) then WriteLn('log: ', lRequest.LogPath);
      if lRequest.Runner <> nil then
        for lInvocation in lRequest.Runner.Invocations do PrintInvocation(lInvocation);
      for lOutput in lRequest.Outputs do WriteLn(lOutput.Name, ': ', lOutput.Path);
    end;
    if lPackages.Diagnostic <> '' then WriteLn(StdErr, lPackages.Diagnostic);
  finally
    lPackages.Free;
  end;
end;

procedure Run;
var
  lTargets: TNexusScriptTargetSelection;
  lParts: TStringList;
  lPart: string;
  lColon: Integer;
  lForge: TNXForge;
  lInvocation: TNXForgeInvocation;
begin
  TNXCommandLine.RegisterFlag('input', True, True, '', 'Forge document');
  TNXCommandLine.RegisterFlag('package', False, True, '', 'Package definition to obtain');
  TNXCommandLine.RegisterFlag('targets', False, True, '', 'Comma-separated Name:Value selections');
  TNXCommandLine.RegisterFlag('working-directory', False, True, '', 'Relative to the Forge document');
  TNXCommandLine.AllowUnknownFlags := False;
  TNXCommandLine.Parse;
  TNXCommandLine.Validate;
  lTargets := TNexusScriptTargetSelection.Create;
  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := ',';
    lParts.DelimitedText := TNXCommandLine.GetValueDefault('targets', '');
    for lPart in lParts do
    begin
      lColon := Pos(':', lPart);
      if (lColon <= 1) or (lColon = Length(lPart)) then
        raise ENXForge.Create('Target selections require Name:Value');
      lTargets.Add(Copy(lPart, 1, lColon - 1), Copy(lPart, lColon + 1, MaxInt));
    end;
    if TNXCommandLine.Supplied('package') then
    begin
      RunPackage(lTargets);
      Exit;
    end;
    lForge := TNXForge.Create(lTargets);
    try
      if not lForge.Execute(TNXCommandLine.GetValueDefault('input', ''),
        TNXCommandLine.GetValueDefault('working-directory', '')) then ExitCode := 1;
      for lInvocation in lForge.Invocations do
        PrintInvocation(lInvocation);
      if lForge.Diagnostic <> '' then WriteLn(StdErr, lForge.Diagnostic);
    finally
      lForge.Free;
    end;
  finally
    lParts.Free;
    lTargets.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      ExitCode := 1;
    end;
  end;
end.
