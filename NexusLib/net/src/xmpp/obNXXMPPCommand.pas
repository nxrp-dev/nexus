unit obNXXMPPCommand;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, obNXXMPPRequestManager, tpNXXMPPTypes;

type
  TNXXMPPCommandKind = (xckRawXML, xckIQ, xckDisconnect);

  TNXXMPPCommand = class
  private
    FExpectedFrom: UTF8String;
    FHandler: TNXXMPPIQCompletionHandler;
    FIQType: TNXXMPPIQType;
    FKind: TNXXMPPCommandKind;
    FPayload: UTF8String;
    FTimeoutMS: Cardinal;
    FToJID: UTF8String;
    FXML: UTF8String;
  public
    class function CreateRaw(const AXML: UTF8String): TNXXMPPCommand;
    class function CreateIQ(AType: TNXXMPPIQType; const AToJID,
      AExpectedFrom, APayload: UTF8String; ATimeoutMS: Cardinal;
      AHandler: TNXXMPPIQCompletionHandler): TNXXMPPCommand;
    class function CreateDisconnect: TNXXMPPCommand;
    property ExpectedFrom: UTF8String read FExpectedFrom;
    property Handler: TNXXMPPIQCompletionHandler read FHandler;
    property IQType: TNXXMPPIQType read FIQType;
    property Kind: TNXXMPPCommandKind read FKind;
    property Payload: UTF8String read FPayload;
    property TimeoutMS: Cardinal read FTimeoutMS;
    property ToJID: UTF8String read FToJID;
    property XML: UTF8String read FXML;
  end;

implementation

class function TNXXMPPCommand.CreateRaw(
  const AXML: UTF8String): TNXXMPPCommand;
begin
  Result := TNXXMPPCommand.Create;
  Result.FKind := xckRawXML;
  Result.FXML := AXML;
end;

class function TNXXMPPCommand.CreateIQ(AType: TNXXMPPIQType;
  const AToJID, AExpectedFrom, APayload: UTF8String; ATimeoutMS: Cardinal;
  AHandler: TNXXMPPIQCompletionHandler): TNXXMPPCommand;
begin
  Result := TNXXMPPCommand.Create;
  Result.FKind := xckIQ;
  Result.FIQType := AType;
  Result.FToJID := AToJID;
  Result.FExpectedFrom := AExpectedFrom;
  Result.FPayload := APayload;
  Result.FTimeoutMS := ATimeoutMS;
  Result.FHandler := AHandler;
end;

class function TNXXMPPCommand.CreateDisconnect: TNXXMPPCommand;
begin
  Result := TNXXMPPCommand.Create;
  Result.FKind := xckDisconnect;
end;

end.
