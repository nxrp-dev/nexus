unit obNXXMPPError;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, tpNXXMPPTypes;

type
  ENXXMPPError = class(Exception)
  private
    FStage: TNXXMPPErrorStage;
    FCondition: string;
    FRecoverable: Boolean;
  public
    constructor Create(AStage: TNXXMPPErrorStage; const ACondition,
      AMessage: string; ARecoverable: Boolean = False);
    property Stage: TNXXMPPErrorStage read FStage;
    property Condition: string read FCondition;
    property Recoverable: Boolean read FRecoverable;
  end;

implementation

constructor ENXXMPPError.Create(AStage: TNXXMPPErrorStage;
  const ACondition, AMessage: string; ARecoverable: Boolean);
begin
  inherited Create(AMessage);
  FStage := AStage;
  FCondition := ACondition;
  FRecoverable := ARecoverable;
end;

end.
