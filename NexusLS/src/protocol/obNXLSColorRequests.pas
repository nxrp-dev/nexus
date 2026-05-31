unit obNXLSColorRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSTextDocumentDocumentColorRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDocumentColorParams;
    procedure SetParams(AValue: TNXLSDocumentColorParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDocumentColorParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentColorPresentationRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSColorPresentationParams;
    procedure SetParams(AValue: TNXLSColorPresentationParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSColorPresentationParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentDocumentColorRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentColor';
end;

class function TNXLSTextDocumentDocumentColorRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSColorInformationArray;
end;

function TNXLSTextDocumentDocumentColorRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentColorPresentationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/colorPresentation';
end;

class function TNXLSTextDocumentColorPresentationRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSColorPresentationArray;
end;

function TNXLSTextDocumentColorPresentationRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentColorPresentationRequest.GetParams: TNXLSColorPresentationParams;
begin
  Result := TNXLSColorPresentationParams(inherited params);
end;

procedure TNXLSTextDocumentColorPresentationRequest.SetParams(AValue: TNXLSColorPresentationParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDocumentColorRequest.GetParams: TNXLSDocumentColorParams;
begin
  Result := TNXLSDocumentColorParams(inherited params);
end;

procedure TNXLSTextDocumentDocumentColorRequest.SetParams(AValue: TNXLSDocumentColorParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentColorRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentColorPresentationRequest);

end.
