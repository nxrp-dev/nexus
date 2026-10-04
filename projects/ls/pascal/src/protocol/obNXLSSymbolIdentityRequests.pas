(*
  Copyright (c) 2026 Kevin Collins.
  
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  
  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.
  
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSSymbolIdentityRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSTextDocumentMonikerRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSMonikerArray;
    procedure SetResult(AValue: TNXLSMonikerArray);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSMonikerArray read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentMonikerRequest.GetFactoryName: string;
begin
  Result := 'textDocument/moniker';
end;

function TNXLSTextDocumentMonikerRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentMonikerRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentMonikerRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentMonikerRequest.GetResult: TNXLSMonikerArray;
begin
  Result := TNXLSMonikerArray(inherited result);
end;

procedure TNXLSTextDocumentMonikerRequest.SetResult(AValue: TNXLSMonikerArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentMonikerRequest);

end.
