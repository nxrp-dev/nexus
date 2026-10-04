(*
  Copyright (c) 2026 Kevin Collins.
  
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  
  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.
  
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSCodeActionRequests;

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
  TNXLSTextDocumentCodeActionRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCodeActionArray;
    procedure SetResult(AValue: TNXLSCodeActionArray);
    function GetParams: TNXLSCodeActionParams;
    procedure SetParams(AValue: TNXLSCodeActionParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSCodeActionArray read GetResult write SetResult;
    property params: TNXLSCodeActionParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel;

class function TNXLSTextDocumentCodeActionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/codeAction';
end;

function TNXLSTextDocumentCodeActionRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSCodeActionArray;
begin
  lResult := TNXLSCodeActionArray(PrepareResult);
  TNXLSLSPModel.Current.Editor.FillCodeActions(TNXLSCodeActionParams(params),
    lResult);
  Result := lResult;
end;

function TNXLSTextDocumentCodeActionRequest.GetParams: TNXLSCodeActionParams;
begin
  Result := TNXLSCodeActionParams(inherited params);
end;

procedure TNXLSTextDocumentCodeActionRequest.SetParams(AValue: TNXLSCodeActionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentCodeActionRequest.GetResult: TNXLSCodeActionArray;
begin
  Result := TNXLSCodeActionArray(inherited result);
end;

procedure TNXLSTextDocumentCodeActionRequest.SetResult(AValue: TNXLSCodeActionArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCodeActionRequest);

end.
