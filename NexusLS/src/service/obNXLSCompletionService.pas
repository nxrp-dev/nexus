unit obNXLSCompletionService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSCompletionService = class(TNXLSLSPService)
  public
    function Completion(AParams: TNXLSCompletionParams): TNXJSONValue; virtual;
    function SignatureHelp(AParams: TNXLSSignatureHelpParams): TNXJSONValue; virtual;
  end;

implementation

uses
  obNXLSProtocolObjects;

function TNXLSCompletionService.Completion(AParams: TNXLSCompletionParams): TNXJSONValue;
begin
  Result := TNXLSCompletionResult.CreateValue;
end;

function TNXLSCompletionService.SignatureHelp(AParams: TNXLSSignatureHelpParams): TNXJSONValue;
begin
  Result := TNXLSSignatureHelpResult.CreateValue;
end;

end.
