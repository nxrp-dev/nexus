library NexusLSTestModule;

{$mode objfpc}{$H+}

uses
  SysUtils,
  Windows,
  tpNXTest,
  obNXTestModule,
  obNXTestRegistry,
  obNXTestRPCRequests,
  tsNXLSCoreTests,
  tsNXLSDiagnosticsTests,
  tsNXLSDocumentSymbolTests,
  tsNXLSExtensionEmulationTests,
  tsNXLSNexusPasNavigationTests,
  tsNXLSWorkspaceSymbolTests,
  tsNXLSProtocolObjectTests,
  tsNXPasLexerTests,
  tsNXPasParserTests,
  tsNXPasPassrcPortTests,
  tsNXPasSignatureTests,
  tsNXPasCompletionTests,
  tsNXPasEditorTests;

var
  gModule: TNXTestModule = nil;

procedure ConfigureNexusLSTestCache;
var
  lRoot: string;
begin
  lRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nexusls-test-module';
  ForceDirectories(IncludeTrailingPathDelimiter(lRoot) + 'search-paths');
  SetEnvironmentVariable(PChar('NEXUSLS_CACHE_DIR'), PChar(lRoot));
end;

procedure RegisterNXLSTests(ARegistry: TNXTestRegistry);
begin
  RegisterNXLSCoreTests(ARegistry);
  RegisterNXLSDiagnosticsTests(ARegistry);
  RegisterNXLSDocumentSymbolTests(ARegistry);
  RegisterNXLSExtensionEmulationTests(ARegistry);
  RegisterNXLSNexusPasNavigationTests(ARegistry);
  RegisterNXLSWorkspaceSymbolTests(ARegistry);
  RegisterNXLSProtocolObjectTests(ARegistry);
  RegisterNXPasLexerTests(ARegistry);
  RegisterNXPasParserTests(ARegistry);
  RegisterNXPasPassrcPortTests(ARegistry);
  RegisterNXPasSignatureTests(ARegistry);
  RegisterNXPasCompletionTests(ARegistry);
  RegisterNXPasEditorTests(ARegistry);
end;

function NXTest_Init: Integer; cdecl;
begin
  if Assigned(gModule) then
    Exit(cNXTestSuccess);

  try
    ConfigureNexusLSTestCache;
    gModule := TNXTestModule.Create(@RegisterNXLSTests);
    Result := cNXTestSuccess;
  except
    on E: Exception do
    begin
      FreeAndNil(gModule);
      Result := cNXTestErrorInternal;
    end;
  end;
end;

procedure NXTest_Release; cdecl;
begin
  try
    FreeAndNil(gModule);
  except
    on E: Exception do
    begin
    end;
  end;
end;

function NXTest_ExecuteCommand(ARequest: PAnsiChar; var AResultId: Integer;
  var AResultSize: Integer): Integer; cdecl;
begin
  AResultId := 0;
  AResultSize := 0;

  try
    if not Assigned(gModule) then
      Exit(cNXTestErrorNotInitialized);

    Result := gModule.ExecuteCommand(ARequest, AResultId, AResultSize);
  except
    on E: Exception do
      Result := cNXTestErrorInternal;
  end;
end;

function NXTest_ReadResult(AResultId: Integer; ABuffer: PAnsiChar;
  ABufferSize: Integer; var ABytesWritten: Integer): Integer; cdecl;
begin
  ABytesWritten := 0;

  try
    if not Assigned(gModule) then
      Exit(cNXTestErrorNotInitialized);

    Result := gModule.ReadResult(AResultId, ABuffer, ABufferSize,
      ABytesWritten);
  except
    on E: Exception do
      Result := cNXTestErrorInternal;
  end;
end;

exports
  NXTest_Init,
  NXTest_Release,
  NXTest_ExecuteCommand,
  NXTest_ReadResult;

begin
end.
