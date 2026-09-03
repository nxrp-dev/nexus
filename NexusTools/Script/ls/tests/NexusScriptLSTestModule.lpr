library NexusScriptLSTestModule;

{$mode objfpc}{$H+}

uses
  SysUtils,
  tpNXTest,
  obNXTestModule,
  obNXTestRegistry,
  obNXTestRPCRequests,
  tsNexusScriptLSShellTests;

var
  gModule: TNXTestModule = nil;

procedure RegisterTests(ARegistry: TNXTestRegistry);
begin
  RegisterNexusScriptLSShellTests(ARegistry);
end;

function NXTest_Init: Integer; cdecl;
begin
  if Assigned(gModule) then
    Exit(cNXTestSuccess);

  try
    gModule := TNXTestModule.Create(@RegisterTests);
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
  FreeAndNil(gModule);
end;

function NXTest_ExecuteCommand(ARequest: PAnsiChar; var AResultId: Integer;
  var AResultSize: Integer): Integer; cdecl;
begin
  AResultId := 0;
  AResultSize := 0;
  if not Assigned(gModule) then
    Exit(cNXTestErrorNotInitialized);
  Result := gModule.ExecuteCommand(ARequest, AResultId, AResultSize);
end;

function NXTest_ReadResult(AResultId: Integer; ABuffer: PAnsiChar;
  ABufferSize: Integer; var ABytesWritten: Integer): Integer; cdecl;
begin
  ABytesWritten := 0;
  if not Assigned(gModule) then
    Exit(cNXTestErrorNotInitialized);
  Result := gModule.ReadResult(AResultId, ABuffer, ABufferSize, ABytesWritten);
end;

exports
  NXTest_Init,
  NXTest_Release,
  NXTest_ExecuteCommand,
  NXTest_ReadResult;

begin
end.
