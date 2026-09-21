unit obNXBotWorkspace;

{$mode delphi}{$H+}

interface

uses
  Generics.Collections;

type
  TNXBotWorkspaceAccess = class
  private
    FCachePath: string;
    FName: UTF8String;
    FPurpose: UTF8String;
    FRepositoryPath: string;
    FResolvedCommit: UTF8String;
  public
    function Clone: TNXBotWorkspaceAccess;
    property CachePath: string read FCachePath write FCachePath;
    property Name: UTF8String read FName write FName;
    property Purpose: UTF8String read FPurpose write FPurpose;
    property RepositoryPath: string read FRepositoryPath write FRepositoryPath;
    property ResolvedCommit: UTF8String read FResolvedCommit
      write FResolvedCommit;
  end;

  TNXBotWorkspaceAccessList = TObjectList<TNXBotWorkspaceAccess>;

implementation

function TNXBotWorkspaceAccess.Clone: TNXBotWorkspaceAccess;
begin
  Result := TNXBotWorkspaceAccess.Create;
  Result.CachePath := FCachePath;
  Result.Name := FName;
  Result.Purpose := FPurpose;
  Result.RepositoryPath := FRepositoryPath;
  Result.ResolvedCommit := FResolvedCommit;
end;

end.
