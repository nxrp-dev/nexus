unit obNXLSNavigationService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSNavigationService = class(TNXLSLSPService)
  public
    function Declaration(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function Definition(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function ImplementationLocation(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function References(AParams: TNXLSReferenceParams): TNXJSONValue; virtual;
  end;

implementation

uses
  obNXLSProtocolObjects;

function TNXLSNavigationService.Declaration(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSLocationResult.CreateValue;
end;

function TNXLSNavigationService.Definition(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSLocationResult.CreateValue;
end;

function TNXLSNavigationService.ImplementationLocation(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSLocationResult.CreateValue;
end;

function TNXLSNavigationService.References(AParams: TNXLSReferenceParams): TNXJSONValue;
begin
  Result := TNXLSLocationArrayResult.CreateValue;
end;

end.
