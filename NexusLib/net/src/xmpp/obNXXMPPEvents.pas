unit obNXXMPPEvents;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPRequestManager, obNXXMPPStanza,
  tpNXXMPPTypes;

type
  TNXXMPPEventKind = (xekState, xekStanza, xekError, xekIQCompletion);

  TNXXMPPEvent = class
  private
    FCompletion: TNXXMPPIQCompletionEvent;
    FCondition: UTF8String;
    FErrorMessage: UTF8String;
    FErrorStage: TNXXMPPErrorStage;
    FKind: TNXXMPPEventKind;
    FStanza: TNXXMPPStanza;
    FState: TNXXMPPConnectionState;
  public
    class function CreateState(AState: TNXXMPPConnectionState): TNXXMPPEvent;
    class function CreateStanza(AStanza: TNXXMPPStanza): TNXXMPPEvent;
    class function CreateError(AStage: TNXXMPPErrorStage;
      const ACondition, AMessage: UTF8String): TNXXMPPEvent;
    class function CreateCompletion(
      ACompletion: TNXXMPPIQCompletionEvent): TNXXMPPEvent;
    destructor Destroy; override;
    property Completion: TNXXMPPIQCompletionEvent read FCompletion;
    property Condition: UTF8String read FCondition;
    property ErrorMessage: UTF8String read FErrorMessage;
    property ErrorStage: TNXXMPPErrorStage read FErrorStage;
    property Kind: TNXXMPPEventKind read FKind;
    property Stanza: TNXXMPPStanza read FStanza;
    property State: TNXXMPPConnectionState read FState;
  end;

implementation

class function TNXXMPPEvent.CreateState(
  AState: TNXXMPPConnectionState): TNXXMPPEvent;
begin
  Result := TNXXMPPEvent.Create;
  Result.FKind := xekState;
  Result.FState := AState;
end;

class function TNXXMPPEvent.CreateStanza(
  AStanza: TNXXMPPStanza): TNXXMPPEvent;
begin
  Result := TNXXMPPEvent.Create;
  Result.FKind := xekStanza;
  Result.FStanza := AStanza;
end;

class function TNXXMPPEvent.CreateError(AStage: TNXXMPPErrorStage;
  const ACondition, AMessage: UTF8String): TNXXMPPEvent;
begin
  Result := TNXXMPPEvent.Create;
  Result.FKind := xekError;
  Result.FErrorStage := AStage;
  Result.FCondition := ACondition;
  Result.FErrorMessage := AMessage;
end;

class function TNXXMPPEvent.CreateCompletion(
  ACompletion: TNXXMPPIQCompletionEvent): TNXXMPPEvent;
begin
  Result := TNXXMPPEvent.Create;
  Result.FKind := xekIQCompletion;
  Result.FCompletion := ACompletion;
end;

destructor TNXXMPPEvent.Destroy;
begin
  FCompletion.Free;
  FStanza.Free;
  inherited Destroy;
end;

end.
