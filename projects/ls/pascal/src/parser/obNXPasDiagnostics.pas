(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPasDiagnostics;

{$mode objfpc}{$H+}

interface

uses
  Contnrs,
  obNXPasSource;

type
  TNXPasDiagnosticSeverity = (
    pdsInfo,
    pdsWarning,
    pdsError
  );

  TNXPasDiagnostic = class
  private
    FCode: string;
    FMessage: string;
    FRange: TNXPasSourceRange;
    FSeverity: TNXPasDiagnosticSeverity;
  public
    property Code: string read FCode write FCode;
    property Message: string read FMessage write FMessage;
    property Range: TNXPasSourceRange read FRange write FRange;
    property Severity: TNXPasDiagnosticSeverity read FSeverity write FSeverity;
  end;

  TNXPasDiagnosticList = class(TObjectList)
  public
    function AddDiagnostic(ASeverity: TNXPasDiagnosticSeverity;
      const AMessage: string; const ARange: TNXPasSourceRange;
      const ACode: string = ''): TNXPasDiagnostic;
    function DiagnosticAt(AIndex: Integer): TNXPasDiagnostic;
  end;

implementation

function TNXPasDiagnosticList.AddDiagnostic(ASeverity: TNXPasDiagnosticSeverity;
  const AMessage: string; const ARange: TNXPasSourceRange;
  const ACode: string): TNXPasDiagnostic;
begin
  Result := TNXPasDiagnostic.Create;
  Result.Severity := ASeverity;
  Result.Code := ACode;
  Result.Message := AMessage;
  Result.Range := ARange;
  Add(Result);
end;

function TNXPasDiagnosticList.DiagnosticAt(AIndex: Integer): TNXPasDiagnostic;
begin
  Result := TNXPasDiagnostic(Items[AIndex]);
end;

end.
