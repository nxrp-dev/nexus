program NexusCSV;

{$mode delphi}{$H+}

uses SysUtils, obNXCommandLine, obNXCSV;

procedure Run;
var
  lCompiler: TNXCSVCompiler;
  lSource, lName, lDelimiterName: string;
  lDelimiter: Char;
begin
  TNXCommandLine.RegisterFlag('input', True, True, '', 'CSV source file');
  TNXCommandLine.RegisterFlag('template', True, True, '', 'Artifact Mustache template');
  TNXCommandLine.RegisterFlag('output', True, True, '', 'Output artifact file');
  TNXCommandLine.RegisterFlag('name', False, True, '', 'Data source name, defaults to file stem');
  TNXCommandLine.RegisterFlag('delimiter', False, True, 'comma', 'comma or tab');
  TNXCommandLine.AllowUnknownFlags := False;
  TNXCommandLine.Parse;
  TNXCommandLine.Validate;
  lSource := TNXCommandLine.GetValueDefault('input', '');
  lName := TNXCommandLine.GetValueDefault('name', '');
  if lName = '' then lName := ChangeFileExt(ExtractFileName(lSource), '');
  lDelimiterName := TNXCommandLine.GetValueDefault('delimiter', 'comma');
  if SameText(lDelimiterName, 'comma') then lDelimiter := ','
  else if SameText(lDelimiterName, 'tab') then lDelimiter := #9
  else raise Exception.Create('Delimiter must be comma or tab');
  lCompiler := TNXCSVCompiler.Create;
  try
    lCompiler.Compile(lSource, TNXCommandLine.GetValueDefault('template', ''),
      TNXCommandLine.GetValueDefault('output', ''), lName, lDelimiter);
  finally
    lCompiler.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      ExitCode := 1;
    end;
  end;
end.
