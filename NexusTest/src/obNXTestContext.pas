unit obNXTestContext;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, obNXTestResult;

type
  ENXTestFailure = class(Exception);
  ENXTestSkip = class(Exception);

  TNXTestContext = class
  private
    FResult: TNXTestResult;
  public
    constructor Create(AResult: TNXTestResult);

    procedure Fail(const AMessage: string);
    procedure Skip(const AMessage: string);
    procedure AssertTrue(AValue: Boolean; const AMessage: string = '');
    procedure AssertFalse(AValue: Boolean; const AMessage: string = '');
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string = '');
    procedure AssertEquals(AExpected, AActual: Integer; const AMessage: string = '');

    property Result: TNXTestResult read FResult;
  end;

implementation

constructor TNXTestContext.Create(AResult: TNXTestResult);
begin
  inherited Create;
  FResult := AResult;
end;

procedure TNXTestContext.Fail(const AMessage: string);
begin
  FResult.Message := AMessage;
  raise ENXTestFailure.Create(AMessage);
end;

procedure TNXTestContext.Skip(const AMessage: string);
begin
  FResult.Message := AMessage;
  raise ENXTestSkip.Create(AMessage);
end;

procedure TNXTestContext.AssertTrue(AValue: Boolean; const AMessage: string);
begin
  if not AValue then
  begin
    if AMessage <> '' then
      Fail(AMessage)
    else
      Fail('Expected true.');
  end;
end;

procedure TNXTestContext.AssertFalse(AValue: Boolean; const AMessage: string);
begin
  if AValue then
  begin
    if AMessage <> '' then
      Fail(AMessage)
    else
      Fail('Expected false.');
  end;
end;

procedure TNXTestContext.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    FResult.Expected := AExpected;
    FResult.Actual := AActual;

    if AMessage <> '' then
      Fail(AMessage)
    else
      Fail('Values are not equal.');
  end;
end;

procedure TNXTestContext.AssertEquals(AExpected, AActual: Integer; const AMessage: string);
begin
  AssertEquals(IntToStr(AExpected), IntToStr(AActual), AMessage);
end;

end.
