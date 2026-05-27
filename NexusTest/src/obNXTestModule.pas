unit obNXTestModule;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, tpNXTest, obNXTestRegistry, obNXTestCommandProcessor,
  obNXTestResultStore;

type
  TNXTestRegistryProc = procedure(ARegistry: TNXTestRegistry);

  TNXTestModule = class
  private
    FRegistry: TNXTestRegistry;
    FProcessor: TNXTestCommandProcessor;
    FResults: TNXTestResultStore;
  public
    constructor Create(ARegisterTests: TNXTestRegistryProc);
    destructor Destroy; override;

    function ExecuteCommand(ARequest: PAnsiChar; var AResultId: Integer; var AResultSize: Integer): Integer;
    function ReadResult(AResultId: Integer; ABuffer: PAnsiChar; ABufferSize: Integer; var ABytesWritten: Integer): Integer;

    property Registry: TNXTestRegistry read FRegistry;
  end;

implementation

constructor TNXTestModule.Create(ARegisterTests: TNXTestRegistryProc);
begin
  inherited Create;
  FRegistry := TNXTestRegistry.Create;
  try
    if Assigned(ARegisterTests) then
      ARegisterTests(FRegistry);
    FProcessor := TNXTestCommandProcessor.Create(FRegistry);
    FResults := TNXTestResultStore.Create;
  except
    FreeAndNil(FResults);
    FreeAndNil(FProcessor);
    FreeAndNil(FRegistry);
    raise;
  end;
end;

destructor TNXTestModule.Destroy;
begin
  FreeAndNil(FResults);
  FreeAndNil(FProcessor);
  FreeAndNil(FRegistry);
  inherited Destroy;
end;

function TNXTestModule.ExecuteCommand(ARequest: PAnsiChar; var AResultId: Integer; var AResultSize: Integer): Integer;
var
  lResponse: string;
begin
  AResultId := 0;
  AResultSize := 0;

  if ARequest = nil then
    Exit(cNXTestErrorInvalidRequest);

  if (not Assigned(FProcessor)) or (not Assigned(FResults)) then
    Exit(cNXTestErrorNotInitialized);

  lResponse := FProcessor.ExecuteCommand(StrPas(ARequest));
  Result := FResults.Store(lResponse, AResultId, AResultSize);
end;

function TNXTestModule.ReadResult(AResultId: Integer; ABuffer: PAnsiChar; ABufferSize: Integer; var ABytesWritten: Integer): Integer;
begin
  ABytesWritten := 0;

  if not Assigned(FResults) then
    Exit(cNXTestErrorNotInitialized);

  Result := FResults.Read(AResultId, ABuffer, ABufferSize, ABytesWritten);
end;

end.
