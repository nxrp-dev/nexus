unit obNXTestModule;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, tpNXTest, obNXTestRegistry, obNXTestCommandProcessor,
  obNXTestResultStore, obNXTestRunner;

type
  TNXTestRegistryProc = procedure(ARegistry: TNXTestRegistry);

  TNXTestModule = class
  private
    class var FCurrent: TNXTestModule;

    FRegistry: TNXTestRegistry;
    FProcessor: TNXTestCommandProcessor;
    FResults: TNXTestResultStore;
    function GetRunner: TNXTestRunner;
  public
    constructor Create(ARegisterTests: TNXTestRegistryProc);
    destructor Destroy; override;

    function ExecuteCommand(ARequest: PAnsiChar; var AResultId: Integer; var AResultSize: Integer): Integer;
    function ReadResult(AResultId: Integer; ABuffer: PAnsiChar; ABufferSize: Integer; var ABytesWritten: Integer): Integer;

    class function Current: TNXTestModule; static;

    property Registry: TNXTestRegistry read FRegistry;
    property Runner: TNXTestRunner read GetRunner;
  end;

implementation

constructor TNXTestModule.Create(ARegisterTests: TNXTestRegistryProc);
begin
  inherited Create;
  FCurrent := Self;
  FRegistry := TNXTestRegistry.Create;
  try
    if Assigned(ARegisterTests) then
      ARegisterTests(FRegistry);
    FProcessor := TNXTestCommandProcessor.Create(FRegistry);
    FResults := TNXTestResultStore.Create;
  except
    if FCurrent = Self then
      FCurrent := nil;

    FreeAndNil(FResults);
    FreeAndNil(FProcessor);
    FreeAndNil(FRegistry);
    raise;
  end;
end;

destructor TNXTestModule.Destroy;
begin
  if FCurrent = Self then
    FCurrent := nil;

  FreeAndNil(FResults);
  FreeAndNil(FProcessor);
  FreeAndNil(FRegistry);
  inherited Destroy;
end;

function TNXTestModule.GetRunner: TNXTestRunner;
begin
  if Assigned(FProcessor) then
    Result := FProcessor.Runner
  else
    Result := nil;
end;

class function TNXTestModule.Current: TNXTestModule;
begin
  Result := FCurrent;
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
