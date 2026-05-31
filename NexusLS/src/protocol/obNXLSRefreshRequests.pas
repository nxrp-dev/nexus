unit obNXLSRefreshRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects;

type
  TNXLSWorkspaceCodeLensRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  end;

  TNXLSWorkspaceSemanticTokensRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  end;

  TNXLSWorkspaceInlineValueRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  end;

  TNXLSWorkspaceInlayHintRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSWorkspaceCodeLensRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/codeLens/refresh';
end;

class function TNXLSWorkspaceCodeLensRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceCodeLensRefreshRequest.Execute: TNXJSONRPCValue;
begin
  // Method: workspace/codeLens/refresh; required: Client-side; original server: No; category: refresh; result: TNXLSNullResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceSemanticTokensRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/semanticTokens/refresh';
end;

class function TNXLSWorkspaceSemanticTokensRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceSemanticTokensRefreshRequest.Execute: TNXJSONRPCValue;
begin
  // Method: workspace/semanticTokens/refresh; required: Client-side; original server: No; category: refresh; result: TNXLSNullResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceInlineValueRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/inlineValue/refresh';
end;

class function TNXLSWorkspaceInlineValueRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceInlineValueRefreshRequest.Execute: TNXJSONRPCValue;
begin
  // Method: workspace/inlineValue/refresh; required: Client-side; original server: No; category: refresh; result: TNXLSNullResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceInlayHintRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/inlayHint/refresh';
end;

class function TNXLSWorkspaceInlayHintRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceInlayHintRefreshRequest.Execute: TNXJSONRPCValue;
begin
  // Method: workspace/inlayHint/refresh; required: Client-side; original server: No; category: refresh; result: TNXLSNullResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceCodeLensRefreshRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSemanticTokensRefreshRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceInlineValueRefreshRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceInlayHintRefreshRequest);

end.
