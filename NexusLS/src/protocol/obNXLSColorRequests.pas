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
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentColorPresentationRequest = class(TNXJSONRPCRequest)
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

class function TNXLSTextDocumentDocumentColorRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentColor';
end;

class function TNXLSTextDocumentDocumentColorRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentColorParams;
end;

function TNXLSTextDocumentDocumentColorRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/documentColor; required: Optional; original server: No; category: color; result: TNXLSColorInformationArrayResult.
  Result := TNXLSColorInformationArrayResult.CreateValue;
end;

class function TNXLSTextDocumentColorPresentationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/colorPresentation';
end;

class function TNXLSTextDocumentColorPresentationRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSColorPresentationParams;
end;

function TNXLSTextDocumentColorPresentationRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/colorPresentation; required: Optional; original server: No; category: color; result: TNXLSColorPresentationArrayResult.
  Result := TNXLSColorPresentationArrayResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentColorRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentColorPresentationRequest);

end.
