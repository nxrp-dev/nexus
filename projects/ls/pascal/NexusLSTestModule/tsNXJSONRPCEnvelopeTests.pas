(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXJSONRPCEnvelopeTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXJSONRPCEnvelopeTests(ARegistry: TNXTestRegistry);

implementation

uses
  SysUtils,
  fpjson,
  obNXJSONRPCMessages,
  obNXTestContext,
  obNXTestSuite;

procedure TestStandardRejectsMissingVersion(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage('{"id":1,"method":"test/request"}').Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;
  AContext.AssertTrue(lRaised,
    'Standard policy must reject a missing jsonrpc member.');
end;

procedure TestHeaderlessAcceptsMissingVersion(AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"id":1,"method":"test/request"}', jepHeaderless);
  try
    AContext.AssertEquals(Integer(rpcRequest), Integer(lMessage.Kind),
      'Headerless policy should accept a request without jsonrpc.');
  finally
    lMessage.Free;
  end;
end;

procedure TestHeaderlessRejectsWrongVersion(AContext: TNXTestContext);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    TNXJSONRPC.ParseMessage(
      '{"jsonrpc":"1.0","id":1,"method":"test/request"}',
      jepHeaderless).Free;
  except
    on ENXJSONRPC do
      lRaised := True;
  end;
  AContext.AssertTrue(lRaised,
    'Headerless policy must reject an invalid present version.');
end;

procedure TestHeaderlessResponsesOmitVersion(AContext: TNXTestContext);
var
  lResponse: TJSONObject;
begin
  lResponse := TNXJSONRPC.CreateSuccessResponse(nil, nil, jepHeaderless);
  try
    AContext.AssertTrue(lResponse.Find('jsonrpc') = nil,
      'Headerless success response should omit jsonrpc.');
    AContext.AssertTrue(lResponse.Find('result') <> nil,
      'Headerless success response should contain result.');
  finally
    lResponse.Free;
  end;

  lResponse := TNXJSONRPC.CreateErrorResponse(nil,
    TNXJSONRPC.MethodNotFound, 'unknown', nil, jepHeaderless);
  try
    AContext.AssertTrue(lResponse.Find('jsonrpc') = nil,
      'Headerless error response should omit jsonrpc.');
    AContext.AssertTrue(lResponse.Find('error') <> nil,
      'Headerless error response should contain error.');
  finally
    lResponse.Free;
  end;
end;

procedure RegisterNXJSONRPCEnvelopeTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusJSONRPC.Envelope');
  lSuite.AddTest('StandardRejectsMissingVersion',
    @TestStandardRejectsMissingVersion);
  lSuite.AddTest('HeaderlessAcceptsMissingVersion',
    @TestHeaderlessAcceptsMissingVersion);
  lSuite.AddTest('HeaderlessRejectsWrongVersion',
    @TestHeaderlessRejectsWrongVersion);
  lSuite.AddTest('HeaderlessResponsesOmitVersion',
    @TestHeaderlessResponsesOmitVersion);
end;

end.
