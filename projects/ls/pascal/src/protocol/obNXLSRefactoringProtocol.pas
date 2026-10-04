(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSRefactoringProtocol;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase;

type
  TNXLSCompleteCodeParams = class(TNXJSONRPCObjectParams)
  private
    Furi: TNXJSONString;
    Fposition: TNXLSPosition;
  published
    property uri: TNXJSONString read Furi write Furi;
    property position: TNXLSPosition read Fposition write Fposition;
  end;

  TNXLSInvertAssignmentParams = class(TNXJSONRPCObjectParams)
  private
    Furi: TNXJSONString;
    Fstart: TNXLSPosition;
    Fend: TNXLSPosition;
  published
    property uri: TNXJSONString read Furi write Furi;
    property start: TNXLSPosition read Fstart write Fstart;
    property &end: TNXLSPosition read Fend write Fend;
  end;

  TNXLSRemoveEmptyMethodsParams = class(TNXJSONRPCObjectParams)
  private
    Furi: TNXJSONString;
    Fposition: TNXLSPosition;
  published
    property uri: TNXJSONString read Furi write Furi;
    property position: TNXLSPosition read Fposition write Fposition;
  end;

  TNXLSRemoveUnusedUnitsParams = class(TNXJSONRPCObjectParams)
  private
    Furi: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
  end;

implementation

end.

