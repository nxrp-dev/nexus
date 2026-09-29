unit obNexusScriptEmitter;

{$mode delphi}{$H+}

interface

uses
  Classes,
  obNXClassFactory,
  obNexusScriptModel;

type
  TNexusScriptEmitter = class(TNXFactoryObject)
  public
    procedure AddDocument(
      ADocument: TNexusScriptCompiledDocument); virtual; abstract;
    procedure WriteArtifact(AStream: TStream); overload; virtual; abstract;
    procedure WriteArtifact(
      const AFileName: string); overload; virtual;
  end;

implementation

uses
  SysUtils;

procedure TNexusScriptEmitter.WriteArtifact(const AFileName: string);
var
  lStream: TFileStream;
begin
  if AFileName = '' then
    raise EStreamError.Create('Artifact output file name is required.');
  if not ForceDirectories(ExtractFileDir(ExpandFileName(AFileName))) then
    raise EStreamError.CreateFmt(
      'Cannot create artifact output directory for %s.', [AFileName]);
  lStream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteArtifact(lStream);
  finally
    lStream.Free;
  end;
end;

end.
