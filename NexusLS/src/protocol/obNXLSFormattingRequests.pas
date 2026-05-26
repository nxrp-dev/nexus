unit obNXLSFormattingRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentFormattingRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentRangeFormattingRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentOnTypeFormattingRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentFormattingRequest.GetFactoryName: string;
begin
  Result := 'textDocument/formatting';
end;

class function TNXLSTextDocumentFormattingRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentFormattingParams;
end;

function TNXLSTextDocumentFormattingRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/formatting; required: Optional; original server: No; category: formatting; result: TNXLSTextEditArrayResult.
  Result := TNXLSTextEditArrayResult.CreateValue;
end;

class function TNXLSTextDocumentRangeFormattingRequest.GetFactoryName: string;
begin
  Result := 'textDocument/rangeFormatting';
end;

class function TNXLSTextDocumentRangeFormattingRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentRangeFormattingParams;
end;

function TNXLSTextDocumentRangeFormattingRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/rangeFormatting; required: Optional; original server: No; category: formatting; result: TNXLSTextEditArrayResult.
  Result := TNXLSTextEditArrayResult.CreateValue;
end;

class function TNXLSTextDocumentOnTypeFormattingRequest.GetFactoryName: string;
begin
  Result := 'textDocument/onTypeFormatting';
end;

class function TNXLSTextDocumentOnTypeFormattingRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentOnTypeFormattingParams;
end;

function TNXLSTextDocumentOnTypeFormattingRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/onTypeFormatting; required: Optional; original server: No; category: formatting; result: TNXLSTextEditArrayResult.
  Result := TNXLSTextEditArrayResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentFormattingRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentRangeFormattingRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentOnTypeFormattingRequest);

end.
