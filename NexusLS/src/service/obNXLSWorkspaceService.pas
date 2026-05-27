unit obNXLSWorkspaceService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSWorkspaceService = class(TNXLSLSPService)
  public
    procedure DidChangeConfiguration(AParams: TNXLSDidChangeConfigurationParams); virtual;
    procedure DidChangeWorkspaceFolders(AParams: TNXLSDidChangeWorkspaceFoldersParams); virtual;
  end;

implementation

procedure TNXLSWorkspaceService.DidChangeConfiguration(AParams: TNXLSDidChangeConfigurationParams);
begin
end;

procedure TNXLSWorkspaceService.DidChangeWorkspaceFolders(AParams: TNXLSDidChangeWorkspaceFoldersParams);
begin
  if (AParams = nil) or (AParams.event = nil) then
    Exit;

  Model.AddWorkspaceFolders(AParams.event.added);
  Model.RemoveWorkspaceFolders(AParams.event.removed);
  Model.RebuildWorkspaceIndex;
end;

end.
