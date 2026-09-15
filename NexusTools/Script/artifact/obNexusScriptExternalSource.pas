unit obNexusScriptExternalSource;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  obNexusScriptArtifactModel;

type
  ENexusScriptExternalSource = class(Exception);

  TNexusScriptExternalSourceCompilerRegistry = class
  private
    class function CompileDelimited(const ACompilerName: string;
      ASource: TNexusScriptExternalSource; ADelimiter: Char): string; static;
  public
    class function SupportsCompiler(const ACompilerName: string): Boolean;
      static;
    class function CompilerSupportsType(const ACompilerName,
      ASourceType: string): Boolean; static;
    class function Compile(const ACompilerName: string;
      ASource: TNexusScriptExternalSource): string; static;
  end;

implementation

uses
  fpjson, utNXDelimitedText;

class function TNexusScriptExternalSourceCompilerRegistry.SupportsCompiler(
  const ACompilerName: string): Boolean;
begin
  Result := SameText(ACompilerName, 'CommaDelimited') or
    SameText(ACompilerName, 'TabDelimited');
end;

class function TNexusScriptExternalSourceCompilerRegistry.CompilerSupportsType(
  const ACompilerName, ASourceType: string): Boolean;
begin
  if SameText(ACompilerName, 'CommaDelimited') then
    Result := SameText(ASourceType, 'csv') or SameText(ASourceType, 'jcsv')
  else if SameText(ACompilerName, 'TabDelimited') then
    Result := SameText(ASourceType, 'tsv') or SameText(ASourceType, 'tab')
  else
    Result := False;
end;

class function TNexusScriptExternalSourceCompilerRegistry.CompileDelimited(
  const ACompilerName: string; ASource: TNexusScriptExternalSource;
  ADelimiter: Char): string;
var
  lRoot, lDataSource: TJSONObject;
  lMetaData: TNexusScriptArtifactMetadata;
begin
  if not CompilerSupportsType(ACompilerName, ASource.SourceType) then
    raise ENexusScriptExternalSource.CreateFmt(
      'Compiler %s does not support source type %s.',
      [ACompilerName, ASource.SourceType]);
  lRoot := TJSONObject.Create;
  try
    lDataSource := LoadNXDelimitedData(ASource.FileName, ADelimiter);
    lRoot.Add('DataSource', lDataSource);
    lMetaData := TNexusScriptArtifactMetadata.Create;
    try
      lMetaData.Kind.Value := 'DataSource';
      lMetaData.Name.Value := ASource.Name;
      lMetaData.&Type.Value := ASource.SourceType;
      lMetaData.Source.Value := ASource.DeclaredPath;
      lDataSource.Add('_nx', lMetaData.ToJSONData);
    finally
      lMetaData.Free;
    end;
    Result := lRoot.FormatJSON;
  finally
    lRoot.Free;
  end;
end;

class function TNexusScriptExternalSourceCompilerRegistry.Compile(
  const ACompilerName: string; ASource: TNexusScriptExternalSource): string;
begin
  if SameText(ACompilerName, 'CommaDelimited') then
    Result := CompileDelimited(ACompilerName, ASource, ',')
  else if SameText(ACompilerName, 'TabDelimited') then
    Result := CompileDelimited(ACompilerName, ASource, #9)
  else
    raise ENexusScriptExternalSource.CreateFmt(
      'Unknown external source compiler: %s', [ACompilerName]);
end;

end.
