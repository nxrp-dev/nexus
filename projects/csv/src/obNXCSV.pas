unit obNXCSV;

{$mode delphi}{$H+}

interface

type
  TNXCSVCompiler = class
  private
    procedure SQLString(const AValue: Variant; out AResult: Variant);
  public
    procedure Compile(const ASource, ATemplate, AOutput, AName: string;
      ADelimiter: Char);
  end;

implementation
uses Classes, SysUtils, Variants, fpjson, SynMustache, utNXDelimitedText;

procedure TNXCSVCompiler.SQLString(const AValue: Variant; out AResult: Variant);
begin
  AResult := QuotedStr(VarToStr(AValue));
end;

procedure TNXCSVCompiler.Compile(const ASource, ATemplate, AOutput,
  AName: string; ADelimiter: Char);
var
  lRoot, lData, lMetadata: TJSONObject;
  lTemplate: UTF8String;
  lInput: TFileStream;
  lHelpers: TSynMustacheHelpers;
  lRendered: UTF8String;
  lFile: TFileStream;
begin
  lRoot := TJSONObject.Create;
  try
    lData := LoadNXDelimitedData(ASource, ADelimiter);
    lRoot.Add('DataSource', lData);
    lMetadata := TJSONObject.Create;
    lData.Add('_nx', lMetadata);
    lMetadata.Add('Name', AName);
    lMetadata.Add('Source', ASource);
    lInput := TFileStream.Create(ATemplate, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(lTemplate, lInput.Size);
      if lInput.Size > 0 then lInput.ReadBuffer(lTemplate[1], lInput.Size);
    finally
      lInput.Free;
    end;
    lHelpers := nil;
    TSynMustache.HelperAdd(lHelpers, 'sql', SQLString);
    lRendered := TSynMustache.Parse(lTemplate).RenderJSON(
      UTF8String(lRoot.AsJSON), nil, lHelpers);
    // Parse and render before opening the destination. Failed input preserves it.
    lFile := TFileStream.Create(AOutput, fmCreate);
    try
      if lRendered <> '' then lFile.WriteBuffer(lRendered[1], Length(lRendered));
    finally
      lFile.Free;
    end;
  finally
    lRoot.Free;
  end;
end;

end.
