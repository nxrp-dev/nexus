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
    function GetResult: TNXLSColorInformationArray;
    procedure SetResult(AValue: TNXLSColorInformationArray);
    function GetParams: TNXLSDocumentColorParams;
    procedure SetParams(AValue: TNXLSDocumentColorParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSColorInformationArray read GetResult write SetResult;
    property params: TNXLSDocumentColorParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentColorPresentationRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSColorPresentationArray;
    procedure SetResult(AValue: TNXLSColorPresentationArray);
    function GetParams: TNXLSColorPresentationParams;
    procedure SetParams(AValue: TNXLSColorPresentationParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSColorPresentationArray read GetResult write SetResult;
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

function TNXLSTextDocumentDocumentColorRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentColorPresentationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/colorPresentation';
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

function TNXLSTextDocumentDocumentColorRequest.GetResult: TNXLSColorInformationArray;
begin
  Result := TNXLSColorInformationArray(inherited result);
end;

procedure TNXLSTextDocumentDocumentColorRequest.SetResult(AValue: TNXLSColorInformationArray);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentColorPresentationRequest.GetResult: TNXLSColorPresentationArray;
begin
  Result := TNXLSColorPresentationArray(inherited result);
end;

procedure TNXLSTextDocumentColorPresentationRequest.SetResult(AValue: TNXLSColorPresentationArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentColorRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentColorPresentationRequest);

end.
