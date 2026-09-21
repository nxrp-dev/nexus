unit tsNXBotDatabaseTests;

{$mode delphi}{$H+}

interface
uses obNXTestRegistry;
procedure RegisterNXBotDatabaseTests(ARegistry: TNXTestRegistry);

implementation
uses Classes, SysUtils, Process, obNXTestSuite, obNXTestContext,
  obNXForgePackages, obNexusScriptModel;

procedure SaveText(const APath, AText: string);
var
  lFile: TFileStream;
begin
  lFile := TFileStream.Create(APath, fmCreate);
  try
    if AText <> '' then lFile.WriteBuffer(AText[1], Length(AText));
  finally
    lFile.Free;
  end;
end;

function ReadText(const APath: string): string;
var
  lText: TStringList;
begin
  lText := TStringList.Create;
  try
    lText.LoadFromFile(APath);
    Result := lText.Text;
  finally
    lText.Free;
  end;
end;

function SQLString(const AText: string): string;
begin
  Result := QuotedStr(AText);
end;

function RunSQL(const ADirectory, AName, ASQL: string; out AOutput: string): Integer;
var
  lProcess: TProcess;
  lText: TStringList;
  lTool, lInput: string;
begin
  lTool := GetEnvironmentVariable('NEXUS_FIREBIRD_ISQL');
  if not FileExists(lTool) then
    raise Exception.Create('Set NEXUS_FIREBIRD_ISQL to the installed Firebird isql.exe');
  lInput := ADirectory + AName + '.sql';
  SaveText(lInput, ASQL);
  lProcess := TProcess.Create(nil);
  lText := TStringList.Create;
  try
    lProcess.Executable := lTool;
    lProcess.Parameters.Add('-bail');
    lProcess.Parameters.Add('-quiet');
    lProcess.Parameters.Add('-input');
    lProcess.Parameters.Add(lInput);
    lProcess.Options := [poUsePipes, poStderrToOutPut, poWaitOnExit, poNoConsole];
    lProcess.Execute;
    lText.LoadFromStream(lProcess.Output);
    AOutput := lText.Text;
    Result := lProcess.ExitStatus;
    SaveText(ADirectory + AName + '.log', AOutput);
  finally
    lText.Free;
    lProcess.Free;
  end;
end;

procedure TestFirebirdDatabase(AContext: TNXTestContext);
var
  lRoot, lDirectory, lDatabase, lPackage, lDDL, lOutput, lConnect, lSQL: string;
  lID: TGUID;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
  lIndex, lStatus: Integer;
  lSuffix: string;
begin
  lRoot := IncludeTrailingPathDelimiter(GetCurrentDir);
  AContext.AssertTrue(FileExists(lRoot + 'NexusLib/script/bothost/database/BotHost.Schema.nxscript'),
    'Run this suite from the repository root');
  CreateGUID(lID);
  lDirectory := lRoot + 'output/BotHostDatabaseVerification/' + GUIDToString(lID) + '/';
  ForceDirectories(lDirectory);
  lDatabase := ExpandFileName(lDirectory + 'fixture.fdb');
  lConnect := 'CONNECT ' + SQLString(lDatabase) + ' USER ''SYSDBA'';' + LineEnding;
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('TargetDB', 'Firebird');
  lPackages := TNXForgePackages.Create;
  try
    // Both configurations use the real schema/template and ordinary composition.
    for lIndex := 0 to 1 do
    begin
      if lIndex = 0 then lSuffix := '_ID' else lSuffix := '_KEY';
      lPackage := lDirectory + 'Build.nxscript';
      lDDL := lDirectory + 'generated/schema' + IntToStr(lIndex) + '.sql';
      SaveText(lDirectory + 'Environment.nxscript',
        'module Firebird "' + lRoot + 'NexusLib/script/bothost/database/Environments.nxscript"; ' +
        'Environment Selected (Firebird) { MODULE_ID_POSTFIX: "' +
        lSuffix + '"; }');
      SaveText(lPackage, 'dialect "' + lRoot +
        'NexusLib/script/dialects/NexusForge/NexusForge.Language.nxscript"; ' +
        'module Selected "Environment.nxscript"; Package Verify { ' +
        'Targets: [Dimension TargetDB { Required: True; Allowed: [Firebird]; }]; ' +
        'Outputs: [Output SQL { Path: "generated/schema' + IntToStr(lIndex) + '.sql"; }]; ' +
        'Render Generate { Source: "' + lRoot + 'NexusLib/script/bothost/database/BotHost.Schema.nxscript"; ' +
        'Output: @Verify.Outputs.SQL.Path; Environment: @Selected; Template: @Selected.Template; } }');
      AContext.AssertTrue(lPackages.Execute(lPackage, 'Verify', lTargets), lPackages.Diagnostic);
      AContext.AssertFalse(lPackages.PackageResult.Reused, 'Absent artifact builds');
      AContext.AssertTrue(FileExists(lDDL), 'Package creates output parent and SQL');
      AContext.AssertTrue(lPackages.Execute(lPackage, 'Verify', lTargets), lPackages.Diagnostic);
      AContext.AssertTrue(lPackages.PackageResult.Reused, 'Present artifact reuses');
      lSQL := ReadText(lDDL);
      AContext.AssertTrue(Pos('REFERENCES OWNED_BOT_TBL' + LineEnding + '    (OWNED_BOT' + lSuffix + ')', lSQL) > 0,
        'References use physical TableName and the selected key convention');
      try
        lStatus := RunSQL(lDirectory, 'create' + IntToStr(lIndex),
          'CREATE DATABASE ' + SQLString(lDatabase) + ' USER ''SYSDBA'';' + LineEnding +
          'INPUT ' + SQLString(ExpandFileName(lDDL)) + ';' + LineEnding + 'QUIT;', lOutput);
        AContext.AssertEquals(0, lStatus, 'Generated DDL applies: ' + lOutput);
        if lIndex = 0 then
        begin
          lSQL := ReadText(lRoot + 'projects/bothost/tests/fixtures/database/assertions.sql');
          lStatus := RunSQL(lDirectory, 'assertions', lConnect + lSQL, lOutput);
          AContext.AssertEquals(0, lStatus, 'Database and permission assertions: ' + lOutput);
          AContext.AssertTrue(Pos('DATABASE_ASSERTIONS_PASSED', lOutput) > 0, 'Assertions reached completion');
          lStatus := RunSQL(lDirectory, 'duplicate-key', lConnect +
            'INSERT INTO BOT_HOST_TBL (BOT_HOST_ID, HOST_KEY) VALUES (1, ''duplicate''); COMMIT;', lOutput);
          AContext.AssertTrue((lStatus <> 0) and (Pos('PRIMARY or UNIQUE', lOutput) > 0),
            'Duplicate primary key rejected: ' + lOutput);
          lStatus := RunSQL(lDirectory, 'invalid-reference', lConnect +
            'INSERT INTO OWNED_BOT_TBL (HOST_ID) VALUES (99999); COMMIT;', lOutput);
          AContext.AssertTrue((lStatus <> 0) and (Pos('FOREIGN KEY', lOutput) > 0),
            'Invalid foreign key rejected: ' + lOutput);
        end;
      finally
        if FileExists(lDatabase) then
        begin
          lStatus := RunSQL(lDirectory, 'drop' + IntToStr(lIndex), lConnect + 'DROP DATABASE;', lOutput);
          AContext.AssertEquals(0, lStatus, 'Disposable database cleanup: ' + lOutput);
        end;
      end;
    end;
    FreeAndNil(lTargets);
    lTargets := TNexusScriptTargetSelection.Create;
    lTargets.Add('TargetDB', 'Unsupported');
    AContext.AssertFalse(lPackages.Execute(lPackage, 'Verify', lTargets), 'Unsupported target rejected');
  finally
    lPackages.Free;
    lTargets.Free;
  end;
end;

procedure RegisterNXBotDatabaseTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusBotHost.Database');
  lSuite.AddTest('Firebird', @TestFirebirdDatabase);
end;

end.
