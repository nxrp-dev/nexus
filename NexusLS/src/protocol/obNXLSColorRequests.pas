unit obNXLSColorRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentDocumentColorRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentColorPresentationRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentDocumentColorRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentColor';
end;

class function TNXLSTextDocumentDocumentColorRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentColorParams;
end;

class function TNXLSTextDocumentDocumentColorRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSColorInformationArray;
end;

function TNXLSTextDocumentDocumentColorRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSTextDocumentColorPresentationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/colorPresentation';
end;

class function TNXLSTextDocumentColorPresentationRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSColorPresentationParams;
end;

class function TNXLSTextDocumentColorPresentationRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSColorPresentationArray;
end;

function TNXLSTextDocumentColorPresentationRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentColorRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentColorPresentationRequest);

end.
