library NexusLSTestModule;

{$mode objfpc}{$H+}

uses
  SysUtils,
  tpNXTest,
  obNXTestModule,
  obNXTestRegistry,
  obNXTestRPCRequests,
  tsNXLSCoreTests,
  tsNXLSProtocolObjectTests,
  tsNXLSSymbolTests,
  tsNXLSNavigationTests,
  tsNXLSIntelligenceTests,
  tsNXLSDiagnosticsTests,
  tsNXTestJSONRPCHardeningTests;

var
  gModule: TNXTestModule = nil;

procedure RegisterNXLSTests(ARegistry: TNXTestRegistry);
begin
  RegisterNXLSCoreTests(ARegistry);
  RegisterNXLSProtocolObjectTests(ARegistry);
  RegisterNXLSSymbolTests(ARegistry);
  RegisterNXLSNavigationTests(ARegistry);
  RegisterNXLSIntelligenceTests(ARegistry);
  RegisterNXLSDiagnosticsTests(ARegistry);
  RegisterNXTestJSONRPCHardeningTests(ARegistry);
end;

function NXTest_Init: Integer; cdecl;
begin
  if Assigned(gModule) then
    Exit(cNXTestSuccess);

  try
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
