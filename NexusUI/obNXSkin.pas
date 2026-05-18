unit obNXSkin;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  fpjsonrtti,
  obNXCanvas,
  obNXSkinManifest,
  tpNXPlatform,
  tpNXSkin;

type
  TNXSkin = class
  private
    FActiveColor: TNXColor;
    FBackColor: TNXColor;
    FBorderColor: TNXColor;
    FCanvas: TNXCanvas;
    FForeColor: TNXColor;
    FFormBackColor: TNXColor;
    FFullTransColor: TNXColor;
    FImages: array of TNXSkinImageEntry;
    FSelectedColor: TNXColor;
    FSlices: array of TNXSkinSliceEntry;
    FTextBackColor: TNXColor;
    FTitleBarBackColor: TNXColor;
    FUnselectedTitleBarBackColor: TNXColor;

    function FindImageIndex(const AID: string): Integer;
    function FindNineSliceIndex(const ASkinClass, APart: string;
      AState: TNXSkinState): Integer;
    function GetImage(const AID: string): TNXImageHandle;
    function ResolveSkinFileName(const ASkinFileName,
      AImageFileName: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    function GetNineSlice(const ASkinClass, APart: string;
      AState: TNXSkinState; out ASlice: TNXNineSlice): Boolean;
    procedure LoadFromFile(const AFileName: string; ACanvas: TNXCanvas);
    procedure SetNineSlice(const ASkinClass, APart: string;
      AState: TNXSkinState; const ASlice: TNXNineSlice);

    property ActiveColor: TNXColor read FActiveColor write FActiveColor;
    property BackColor: TNXColor read FBackColor write FBackColor;
    property BorderColor: TNXColor read FBorderColor write FBorderColor;
    property ForeColor: TNXColor read FForeColor write FForeColor;
    property FormBackColor: TNXColor read FFormBackColor write FFormBackColor;
    property FullTransColor: TNXColor read FFullTransColor write FFullTransColor;
    property SelectedColor: TNXColor read FSelectedColor write FSelectedColor;
    property TextBackColor: TNXColor read FTextBackColor write FTextBackColor;
    property TitleBarBackColor: TNXColor read FTitleBarBackColor write FTitleBarBackColor;
    property UnselectedTitleBarBackColor: TNXColor read FUnselectedTitleBarBackColor write FUnselectedTitleBarBackColor;
  end;


implementation

function TNXSkin.FindImageIndex(const AID: string): Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  for lIndex := 0 to Length(FImages) - 1 do
    if FImages[lIndex].ID = AID then
    begin
      Result := lIndex;
      Exit;
    end;
end;

function TNXSkin.FindNineSliceIndex(const ASkinClass, APart: string;
  AState: TNXSkinState): Integer;
var
  lIndex: Integer;
begin
  Result := -1;

  for lIndex := 0 to Length(FSlices) - 1 do
    if (FSlices[lIndex].SkinClass = ASkinClass) and
      (FSlices[lIndex].Part = APart) and
      (FSlices[lIndex].State = AState) then
    begin
      Result := lIndex;
      Exit;
    end;
end;

function TNXSkin.GetImage(const AID: string): TNXImageHandle;
var
  lIndex: Integer;
begin
  Result := nil;
  lIndex := FindImageIndex(AID);
  if lIndex >= 0 then
    Result := FImages[lIndex].Image;
end;

function TNXSkin.ResolveSkinFileName(const ASkinFileName,
  AImageFileName: string): string;
begin
  if ExtractFileDrive(AImageFileName) <> '' then
    Result := AImageFileName
  else
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ASkinFileName)) +
      AImageFileName;
end;

constructor TNXSkin.Create;
begin
  inherited Create;
  FBackColor := MakeNXColor(48, 48, 48, 255);
  FTextBackColor := MakeNXColor(24, 24, 24, 255);
  FForeColor := MakeNXColor(190, 190, 190, 255);
  FBorderColor := MakeNXColor(64, 64, 64, 255);
  FFormBackColor := MakeNXColor(32, 32, 32, 255);
  FTitleBarBackColor := MakeNXColor(24, 24, 64, 255);
  FUnselectedTitleBarBackColor := MakeNXColor(24, 24, 24, 255);
  FSelectedColor := MakeNXColor(24, 24, 64, 255);
  FActiveColor := MakeNXColor(24, 24, 64, 255);
  FFullTransColor := MakeNXColor(0, 0, 0, 0);
end;

destructor TNXSkin.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TNXSkin.Clear;
var
  lIndex: Integer;
begin
  if FCanvas <> nil then
    for lIndex := 0 to Length(FImages) - 1 do
      if FImages[lIndex].Image <> nil then
        FCanvas.DestroyImage(FImages[lIndex].Image);

  SetLength(FImages, 0);
  SetLength(FSlices, 0);
  FCanvas := nil;
end;

function TNXSkin.GetNineSlice(const ASkinClass, APart: string;
  AState: TNXSkinState; out ASlice: TNXNineSlice): Boolean;
var
  lIndex: Integer;
begin
  lIndex := FindNineSliceIndex(ASkinClass, APart, AState);

  if (lIndex < 0) and (AState <> ssNormal) then
    lIndex := FindNineSliceIndex(ASkinClass, APart, ssNormal);

  Result := lIndex >= 0;
  if Result then
    ASlice := FSlices[lIndex].Slice;
end;

procedure TNXSkin.LoadFromFile(const AFileName: string; ACanvas: TNXCanvas);
var
  lDeStreamer: TJSONDeStreamer;
  lFileText: string;
  lFile: TStringList;
  lImageDef: TNXSkinImageDef;
  lImageIndex: Integer;
  lManifest: TNXSkinManifest;
  lSlice: TNXNineSlice;
  lSliceDef: TNXSkinSliceDef;
  lSliceIndex: Integer;
begin
  if ACanvas = nil then
    raise Exception.Create('Cannot load skin without a canvas');

  lManifest := TNXSkinManifest.Create;
  try
    lFile := TStringList.Create;
    try
      lFile.LoadFromFile(AFileName);
      lFileText := Trim(lFile.Text);
    finally
      lFile.Free;
    end;
    lDeStreamer := TJSONDeStreamer.Create(nil);
    try
      lDeStreamer.Options := lDeStreamer.Options + [jdoCaseInsensitive];
      lDeStreamer.JSONToObject(lFileText, lManifest);
    finally
      lDeStreamer.Free;
    end;

    if lManifest.Version <> 1 then
      raise Exception.Create('Unsupported skin version: ' +
        IntToStr(lManifest.Version));

    Clear;
    FCanvas := ACanvas;

    SetLength(FImages, lManifest.Images.Count);
    for lImageIndex := 0 to lManifest.Images.Count - 1 do
    begin
      lImageDef := TNXSkinImageDef(lManifest.Images.Items[lImageIndex]);
      if lImageDef.ID = '' then
        raise Exception.Create('Skin image is missing an ID');
      if FindImageIndex(lImageDef.ID) >= 0 then
        raise Exception.Create('Duplicate skin image ID: ' + lImageDef.ID);

      FImages[lImageIndex].ID := lImageDef.ID;
      FImages[lImageIndex].Image := ACanvas.LoadImage(
        ResolveSkinFileName(AFileName, lImageDef.FileName));
    end;

    for lSliceIndex := 0 to lManifest.Slices.Count - 1 do
    begin
      lSliceDef := TNXSkinSliceDef(lManifest.Slices.Items[lSliceIndex]);
      lSlice.Image := GetImage(lSliceDef.Image);
      if lSlice.Image = nil then
        raise Exception.Create('Skin slice references unknown image: ' +
          lSliceDef.Image);

      lSlice.SourceRect := MakeNXRect(lSliceDef.SourceRect.X,
        lSliceDef.SourceRect.Y, lSliceDef.SourceRect.W, lSliceDef.SourceRect.H);
      lSlice.Left := lSliceDef.Border.Left;
      lSlice.Top := lSliceDef.Border.Top;
      lSlice.Right := lSliceDef.Border.Right;
      lSlice.Bottom := lSliceDef.Border.Bottom;

      SetNineSlice(lSliceDef.SkinClass, lSliceDef.Part, lSliceDef.State,
        lSlice);
    end;
  finally
    lManifest.Free;
  end;
end;

procedure TNXSkin.SetNineSlice(const ASkinClass, APart: string;
  AState: TNXSkinState; const ASlice: TNXNineSlice);
var
  lIndex: Integer;
begin
  lIndex := FindNineSliceIndex(ASkinClass, APart, AState);
  if lIndex < 0 then
  begin
    lIndex := Length(FSlices);
    SetLength(FSlices, lIndex + 1);
    FSlices[lIndex].SkinClass := ASkinClass;
    FSlices[lIndex].Part := APart;
    FSlices[lIndex].State := AState;
  end;

  FSlices[lIndex].Slice := ASlice;
end;

end.
