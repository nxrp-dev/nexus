unit obNXFont;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fgl,
  obNXPlatform,
  tpNXPlatform;

type
  ENexusFontManager = class(Exception);

  TNXFont = class
  private
    FKey: string;
    FName: string;
    FFileName: string;
    FSize: Integer;
    FHandle: TNXFontHandle;
    FHeight: Integer;
    FAscent: Integer;
    FDescent: Integer;
    FLineSkip: Integer;
    FIsMonospace: Boolean;

    procedure SetName(const AName: string);
  public
    constructor Create(const AKey, AFileName: string; ASize: Integer;
      AHandle: TNXFontHandle; const AMetrics: TNXFontMetrics);
    destructor Destroy; override;

    property Key: string read FKey;
    property Name: string read FName write SetName;
    property FileName: string read FFileName;
    property Size: Integer read FSize;
    property Handle: TNXFontHandle read FHandle;

    property Height: Integer read FHeight;
    property Ascent: Integer read FAscent;
    property Descent: Integer read FDescent;
    property LineSkip: Integer read FLineSkip;
    property IsMonospace: Boolean read FIsMonospace;
  end;

  TNXFontList = specialize TFPGObjectList<TNXFont>;

  TNXFontManager = class
  private
    FInitialized: Boolean;
    FFonts: TNXFontList;
    FDefaultFont: TNXFont;
    FPlatform: TNXPlatform;

    function BuildKey(const AFileName: string; ASize: Integer): string;
    function FindFontByKey(const AKey: string): TNXFont;
    function GetCount: Integer;
    function GetFont(AIndex: Integer): TNXFont;
  protected
    procedure CheckInitialized;
    procedure DestroyFontHandle(AFont: TNXFont);
  public
    constructor Create(APlatform: TNXPlatform);
    destructor Destroy; override;

    procedure Initialize;
    procedure Shutdown;
    procedure Clear;

    function LoadFont(const AFileName: string; ASize: Integer): TNXFont;
    function LoadNamedFont(const AName, AFileName: string; ASize: Integer): TNXFont;
    function LoadDefaultFont(const AFileName: string; ASize: Integer): TNXFont;
    function LoadNamedDefaultFont(const AName, AFileName: string; ASize: Integer): TNXFont;

    function FindFont(const AFileName: string; ASize: Integer): TNXFont;
    function FindNamedFont(const AName: string): TNXFont;
    function HasFont(const AFileName: string; ASize: Integer): Boolean;

    property Count: Integer read GetCount;
    property Fonts[AIndex: Integer]: TNXFont read GetFont; default;
    property DefaultFont: TNXFont read FDefaultFont;
    property Initialized: Boolean read FInitialized;
  end;

implementation

constructor TNXFont.Create(const AKey, AFileName: string; ASize: Integer;
  AHandle: TNXFontHandle; const AMetrics: TNXFontMetrics);
begin
  inherited Create;

  if AHandle = nil then
    raise ENexusFontManager.Create('Cannot create TNXFont: nil font handle.');

  FKey := AKey;
  FFileName := AFileName;
  FSize := ASize;
  FHandle := AHandle;

  FHeight := AMetrics.Height;
  FAscent := AMetrics.Ascent;
  FDescent := AMetrics.Descent;
  FLineSkip := AMetrics.LineSkip;
  FIsMonospace := AMetrics.IsMonospace;
end;

destructor TNXFont.Destroy;
begin
  inherited Destroy;
end;

procedure TNXFont.SetName(const AName: string);
begin
  FName := AName;
end;

constructor TNXFontManager.Create(APlatform: TNXPlatform);
begin
  inherited Create;
  if APlatform = nil then
    raise ENexusFontManager.Create('Cannot create TNXFontManager: nil platform.');

  FPlatform := APlatform;
  FFonts := TNXFontList.Create(True);
end;

destructor TNXFontManager.Destroy;
begin
  Shutdown;
  FreeAndNil(FFonts);
  inherited Destroy;
end;

function TNXFontManager.BuildKey(const AFileName: string; ASize: Integer): string;
begin
  Result := AFileName + #0 + IntToStr(ASize);
end;

procedure TNXFontManager.CheckInitialized;
begin
  if not FInitialized then
    raise ENexusFontManager.Create('Nexus font manager has not been initialized.');
end;

procedure TNXFontManager.Clear;
var
  lIndex: Integer;
begin
  FDefaultFont := nil;
  for lIndex := 0 to FFonts.Count - 1 do
    DestroyFontHandle(FFonts[lIndex]);
  FFonts.Clear;
end;

procedure TNXFontManager.DestroyFontHandle(AFont: TNXFont);
begin
  if (AFont <> nil) and (AFont.FHandle <> nil) then
  begin
    FPlatform.DestroyFont(AFont.FHandle);
    AFont.FHandle := nil;
  end;
end;

function TNXFontManager.FindFontByKey(const AKey: string): TNXFont;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to FFonts.Count - 1 do
  begin
    if FFonts[lIndex].Key = AKey then
    begin
      Result := FFonts[lIndex];
      Exit;
    end;
  end;
end;

function TNXFontManager.FindFont(const AFileName: string; ASize: Integer): TNXFont;
begin
  Result := FindFontByKey(BuildKey(AFileName, ASize));
end;

function TNXFontManager.FindNamedFont(const AName: string): TNXFont;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to FFonts.Count - 1 do
  begin
    if SameText(FFonts[lIndex].Name, AName) then
    begin
      Result := FFonts[lIndex];
      Exit;
    end;
  end;
end;

function TNXFontManager.GetCount: Integer;
begin
  Result := FFonts.Count;
end;

function TNXFontManager.GetFont(AIndex: Integer): TNXFont;
begin
  Result := FFonts[AIndex];
end;

function TNXFontManager.HasFont(const AFileName: string; ASize: Integer): Boolean;
begin
  Result := FindFont(AFileName, ASize) <> nil;
end;

procedure TNXFontManager.Initialize;
begin
  if FInitialized then
    Exit;

  FPlatform.InitializeFonts;
  FInitialized := True;
end;

function TNXFontManager.LoadDefaultFont(const AFileName: string;
  ASize: Integer): TNXFont;
begin
  Result := LoadFont(AFileName, ASize);
  FDefaultFont := Result;
end;

function TNXFontManager.LoadFont(const AFileName: string; ASize: Integer): TNXFont;
var
  lKey: string;
  lHandle: TNXFontHandle;
  lMetrics: TNXFontMetrics;
begin
  CheckInitialized;

  if ASize <= 0 then
    raise ENexusFontManager.Create('Font size must be greater than zero.');

  lKey := BuildKey(AFileName, ASize);
  Result := FindFontByKey(lKey);
  if Result <> nil then
    Exit;

  lHandle := FPlatform.LoadFont(AFileName, ASize);
  if lHandle = nil then
    raise ENexusFontManager.Create('Unable to load font "' + AFileName + '".');

  try
    lMetrics := FPlatform.GetFontMetrics(lHandle);
    Result := TNXFont.Create(lKey, AFileName, ASize, lHandle, lMetrics);
    lHandle := nil;
    FFonts.Add(Result);
  finally
    if lHandle <> nil then
      FPlatform.DestroyFont(lHandle);
  end;
end;

function TNXFontManager.LoadNamedDefaultFont(const AName, AFileName: string;
  ASize: Integer): TNXFont;
begin
  Result := LoadNamedFont(AName, AFileName, ASize);
  FDefaultFont := Result;
end;

function TNXFontManager.LoadNamedFont(const AName, AFileName: string;
  ASize: Integer): TNXFont;
begin
  Result := LoadFont(AFileName, ASize);
  Result.Name := AName;
end;

procedure TNXFontManager.Shutdown;
begin
  Clear;

  if FInitialized then
  begin
    FPlatform.FinalizeFonts;
    FInitialized := False;
  end;
end;

end.
