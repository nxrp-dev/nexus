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

