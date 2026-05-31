unit obNXLSFormattingRequests;

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
  TNXLSTextDocumentFormattingRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDocumentFormattingParams;
    procedure SetParams(AValue: TNXLSDocumentFormattingParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDocumentFormattingParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentRangeFormattingRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDocumentRangeFormattingParams;
    procedure SetParams(AValue: TNXLSDocumentRangeFormattingParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDocumentRangeFormattingParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentOnTypeFormattingRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDocumentOnTypeFormattingParams;
    procedure SetParams(AValue: TNXLSDocumentOnTypeFormattingParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDocumentOnTypeFormattingParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentFormattingRequest.GetFactoryName: string;
begin
  Result := 'textDocument/formatting';
end;

class function TNXLSTextDocumentFormattingRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTextEditArray;
end;

function TNXLSTextDocumentFormattingRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentRangeFormattingRequest.GetFactoryName: string;
begin
  Result := 'textDocument/rangeFormatting';
end;

class function TNXLSTextDocumentRangeFormattingRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTextEditArray;
end;

function TNXLSTextDocumentRangeFormattingRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentOnTypeFormattingRequest.GetFactoryName: string;
begin
  Result := 'textDocument/onTypeFormatting';
end;

class function TNXLSTextDocumentOnTypeFormattingRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTextEditArray;
end;

function TNXLSTextDocumentOnTypeFormattingRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentRangeFormattingRequest.GetParams: TNXLSDocumentRangeFormattingParams;
begin
  Result := TNXLSDocumentRangeFormattingParams(inherited params);
end;

procedure TNXLSTextDocumentRangeFormattingRequest.SetParams(AValue: TNXLSDocumentRangeFormattingParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentFormattingRequest.GetParams: TNXLSDocumentFormattingParams;
begin
  Result := TNXLSDocumentFormattingParams(inherited params);
end;

procedure TNXLSTextDocumentFormattingRequest.SetParams(AValue: TNXLSDocumentFormattingParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentOnTypeFormattingRequest.GetParams: TNXLSDocumentOnTypeFormattingParams;
begin
  Result := TNXLSDocumentOnTypeFormattingParams(inherited params);
end;

procedure TNXLSTextDocumentOnTypeFormattingRequest.SetParams(AValue: TNXLSDocumentOnTypeFormattingParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentFormattingRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentRangeFormattingRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentOnTypeFormattingRequest);

end.
