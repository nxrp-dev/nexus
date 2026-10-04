(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSDocumentService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSDocumentSyncParams,
  obNXLSServiceContext;

type
  TNXLSDocumentService = class(TNXLSLSPService)
  public
    procedure DidOpen(AParams: TNXLSDidOpenTextDocumentParams); virtual;
    procedure DidChange(AParams: TNXLSDidChangeTextDocumentParams); virtual;
    procedure DidSave(AParams: TNXLSDidSaveTextDocumentParams); virtual;
    procedure DidClose(AParams: TNXLSDidCloseTextDocumentParams); virtual;
  end;

implementation

uses
  SysUtils;

procedure TNXLSDocumentService.DidOpen(AParams: TNXLSDidOpenTextDocumentParams);
var
  lDocument: TNXLSDocument;
begin
  if AParams = nil then
    raise Exception.Create('didOpen params are required.');

  lDocument := Model.OpenDocument(AParams.textDocument);
  Model.AnalyzeDocument(lDocument);
end;

procedure TNXLSDocumentService.DidChange(AParams: TNXLSDidChangeTextDocumentParams);
var
  lDocument: TNXLSDocument;
begin
  if AParams = nil then
    raise Exception.Create('didChange params are required.');

  Model.ChangeDocument(AParams.textDocument, AParams.contentChanges);
  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  Model.AnalyzeDocument(lDocument);
end;

procedure TNXLSDocumentService.DidSave(AParams: TNXLSDidSaveTextDocumentParams);
var
  lDocument: TNXLSDocument;
begin
  if AParams = nil then
    raise Exception.Create('didSave params are required.');

  Model.SaveDocument(AParams);
  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  Model.AnalyzeDocument(lDocument);
end;

procedure TNXLSDocumentService.DidClose(AParams: TNXLSDidCloseTextDocumentParams);
begin
  if AParams = nil then
    raise Exception.Create('didClose params are required.');

  Model.CloseDocument(AParams.textDocument);
end;

end.
