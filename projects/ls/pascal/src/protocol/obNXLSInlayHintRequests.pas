(*
  Copyright (c) 2026 Kevin Collins.
  
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  
  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.
  
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSInlayHintRequests;

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
  TNXLSTextDocumentInlayHintRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSInlayHintArray;
    procedure SetResult(AValue: TNXLSInlayHintArray);
    function GetParams: TNXLSInlayHintParams;
    procedure SetParams(AValue: TNXLSInlayHintParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSInlayHintArray read GetResult write SetResult;
    property params: TNXLSInlayHintParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel;

class function TNXLSTextDocumentInlayHintRequest.GetFactoryName: string;
begin
  Result := 'textDocument/inlayHint';
end;

function TNXLSTextDocumentInlayHintRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSInlayHintArray;
begin
  lResult := TNXLSInlayHintArray(PrepareResult);
  TNXLSLSPModel.Current.Editor.FillInlayHints(TNXLSInlayHintParams(params),
    lResult);
  Result := lResult;
end;

function TNXLSTextDocumentInlayHintRequest.GetParams: TNXLSInlayHintParams;
begin
  Result := TNXLSInlayHintParams(inherited params);
end;

procedure TNXLSTextDocumentInlayHintRequest.SetParams(AValue: TNXLSInlayHintParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentInlayHintRequest.GetResult: TNXLSInlayHintArray;
begin
  Result := TNXLSInlayHintArray(inherited result);
end;

procedure TNXLSTextDocumentInlayHintRequest.SetResult(AValue: TNXLSInlayHintArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentInlayHintRequest);

end.
