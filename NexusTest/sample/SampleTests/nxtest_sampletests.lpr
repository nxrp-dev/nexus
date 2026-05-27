library nxtest_sampletests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  tpNXTest,
  obNXTestRegistry,
  obNXTestCommandProcessor,
  tsSampleTests;

var
  gRegistry: TNXTestRegistry = nil;
  gProcessor: TNXTestCommandProcessor = nil;

function WriteResponseToBuffer(const AResponse: string; ABuffer: PChar; ABufferSize: Integer; var ABytesWritten: Integer): Integer;
var
  lRequiredSize: Integer;
begin
  ABytesWritten := 0;
  lRequiredSize := Length(AResponse) + 1;

  if (ABuffer = nil) or (ABufferSize < lRequiredSize) then
  begin
    ABytesWritten := lRequiredSize;
    Exit(cNXTestErrorBufferTooSmall);
  end;

  StrPCopy(ABuffer, AResponse);
  ABytesWritten := Length(AResponse);
  Result := cNXTestSuccess;
end;

function NXTest_Init: Integer; cdecl;
begin
  if Assigned(gRegistry) then
    Exit(cNXTestSuccess);

  try
    gRegistry := TNXTestRegistry.Create;
    RegisterSampleTests(gRegistry);
    gProcessor := TNXTestCommandProcessor.Create(gRegistry);
    Result := cNXTestSuccess;
  except
    on E: Exception do
      Result := cNXTestErrorInternal;
  end;
end;

procedure NXTest_Release; cdecl;
begin
  FreeAndNil(gProcessor);
  FreeAndNil(gRegistry);
end;

function NXTest_ExecuteCommand(ARequest: PChar; AResponse: PChar; AResponseSize: Integer; var ABytesWritten: Integer): Integer; cdecl;
var
  lResponse: string;
begin
  ABytesWritten := 0;

  if not Assigned(gProcessor) then
    Exit(cNXTestErrorNotInitialized);

  if ARequest = nil then
    Exit(cNXTestErrorInvalidRequest);

  try
    lResponse := gProcessor.ExecuteCommand(StrPas(ARequest));
    Result := WriteResponseToBuffer(lResponse, AResponse, AResponseSize, ABytesWritten);
  except
    on E: Exception do
      Result := cNXTestErrorInternal;
  end;
end;

exports
  NXTest_Init,
  NXTest_Release,
  NXTest_ExecuteCommand;

begin
end.
