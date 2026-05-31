unit obNXLSRefreshRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWorkspaceCodeLensRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceSemanticTokensRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceInlineValueRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceInlayHintRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory;

class function TNXLSWorkspaceCodeLensRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/codeLens/refresh';
end;

class function TNXLSWorkspaceCodeLensRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceCodeLensRefreshRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/codeLens/refresh; required: Client-side; original server: No; category: refresh; result: TNXLSNullResult.
  Result := PrepareResult;
end;

class function TNXLSWorkspaceSemanticTokensRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/semanticTokens/refresh';
end;

class function TNXLSWorkspaceSemanticTokensRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceSemanticTokensRefreshRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/semanticTokens/refresh; required: Client-side; original server: No; category: refresh; result: TNXLSNullResult.
  Result := PrepareResult;
end;

class function TNXLSWorkspaceInlineValueRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/inlineValue/refresh';
end;

class function TNXLSWorkspaceInlineValueRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceInlineValueRefreshRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/inlineValue/refresh; required: Client-side; original server: No; category: refresh; result: TNXLSNullResult.
  Result := PrepareResult;
end;

class function TNXLSWorkspaceInlayHintRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/inlayHint/refresh';
end;

class function TNXLSWorkspaceInlayHintRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceInlayHintRefreshRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/inlayHint/refresh; required: Client-side; original server: No; category: refresh; result: TNXLSNullResult.
  Result := PrepareResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWorkspaceCodeLensRefreshRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSemanticTokensRefreshRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceInlineValueRefreshRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceInlayHintRefreshRequest);

end.
