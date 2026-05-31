unit obNXLSFormattingRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSTextDocumentFormattingRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSTextEditArray;
    procedure SetResult(AValue: TNXLSTextEditArray);
    function GetParams: TNXLSDocumentFormattingParams;
    procedure SetParams(AValue: TNXLSDocumentFormattingParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSTextEditArray read GetResult write SetResult;
    property params: TNXLSDocumentFormattingParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentRangeFormattingRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSTextEditArray;
    procedure SetResult(AValue: TNXLSTextEditArray);
    function GetParams: TNXLSDocumentRangeFormattingParams;
    procedure SetParams(AValue: TNXLSDocumentRangeFormattingParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSTextEditArray read GetResult write SetResult;
    property params: TNXLSDocumentRangeFormattingParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentOnTypeFormattingRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSTextEditArray;
    procedure SetResult(AValue: TNXLSTextEditArray);
    function GetParams: TNXLSDocumentOnTypeFormattingParams;
    procedure SetParams(AValue: TNXLSDocumentOnTypeFormattingParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSTextEditArray read GetResult write SetResult;
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

function TNXLSTextDocumentFormattingRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentRangeFormattingRequest.GetFactoryName: string;
begin
  Result := 'textDocument/rangeFormatting';
end;

function TNXLSTextDocumentRangeFormattingRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentOnTypeFormattingRequest.GetFactoryName: string;
begin
  Result := 'textDocument/onTypeFormatting';
end;

function TNXLSTextDocumentOnTypeFormattingRequest.Execute: TNXJSONRPCValue;
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

function TNXLSTextDocumentFormattingRequest.GetResult: TNXLSTextEditArray;
begin
  Result := TNXLSTextEditArray(inherited result);
end;

procedure TNXLSTextDocumentFormattingRequest.SetResult(AValue: TNXLSTextEditArray);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentRangeFormattingRequest.GetResult: TNXLSTextEditArray;
begin
  Result := TNXLSTextEditArray(inherited result);
end;

procedure TNXLSTextDocumentRangeFormattingRequest.SetResult(AValue: TNXLSTextEditArray);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentOnTypeFormattingRequest.GetResult: TNXLSTextEditArray;
begin
  Result := TNXLSTextEditArray(inherited result);
end;

procedure TNXLSTextDocumentOnTypeFormattingRequest.SetResult(AValue: TNXLSTextEditArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentFormattingRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentRangeFormattingRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentOnTypeFormattingRequest);

end.
