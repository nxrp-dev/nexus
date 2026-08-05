unit obNXSkin;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  fpjsonrtti,
  obNXCanvas,
  obNXSkinManifest,
  obNXPersist,
  tpNXPlatform,
  tpNXSkin;

type
  TNXSkin = class;
  TNXSkinMaterial = class;
  TNXSkinWidget = class;
  TNXSkinWidgetState = class;
  TNXSkinAppearance = class;

  TNXSkinMaterialKind = (
    smkImage,
    smkFont,
    smkBinary
  );

  TNXSkinRect = class(TNXPersistObject)
  private
    FH: Integer;
    FW: Integer;
    FX: Integer;
    FY: Integer;
  published
    property X: Integer read FX write FX;
    property Y: Integer read FY write FY;
    property W: Integer read FW write FW;
    property H: Integer read FH write FH;
  end;

  TNXSkinInsets = class(TNXPersistObject)
  private
    FBottom: Integer;
    FLeft: Integer;
    FRight: Integer;
    FTop: Integer;
  published
    property Left: Integer read FLeft write FLeft;
    property Top: Integer read FTop write FTop;
    property Right: Integer read FRight write FRight;
    property Bottom: Integer read FBottom write FBottom;
  end;

  TNXSkinColor = class(TNXPersistObject)
  private
    FAlpha: Integer;
    FBlue: Integer;
    FGreen: Integer;
    FRed: Integer;
  public
    constructor Create; override;
  published
    property Red: Integer read FRed write FRed;
    property Green: Integer read FGreen write FGreen;
    property Blue: Integer read FBlue write FBlue;
    property Alpha: Integer read FAlpha write FAlpha;
  end;

  TNXSkinMaterialList = class(TNXPersistList)
  private
    function GetMaterial(AIndex: Integer): TNXSkinMaterial;
  public
    constructor Create; override;

    function AddMaterial: TNXSkinMaterial;
    function FindByName(const AName: string): TNXSkinMaterial;

    property Materials[AIndex: Integer]: TNXSkinMaterial read GetMaterial;
      default;
  end;

  TNXSkinAppearanceList = class(TNXPersistList)
  private
    function GetAppearance(AIndex: Integer): TNXSkinAppearance;
  public
    constructor Create; override;

    function AddAppearance(AClass: TNXPersistClass): TNXSkinAppearance;

    property Appearances[AIndex: Integer]: TNXSkinAppearance
      read GetAppearance; default;
  end;

  TNXSkinWidgetStateList = class(TNXPersistList)
  private
    function GetState(AIndex: Integer): TNXSkinWidgetState;
  public
    constructor Create; override;

    function AddState: TNXSkinWidgetState;
    function FindByState(AState: TNXSkinState): TNXSkinWidgetState;

    property States[AIndex: Integer]: TNXSkinWidgetState read GetState;
      default;
  end;

  TNXSkinWidgetList = class(TNXPersistList)
  private
    function GetWidget(AIndex: Integer): TNXSkinWidget;
  public
    constructor Create; override;

    function AddWidget: TNXSkinWidget;
    function FindBySkinClass(const ASkinClass: string): TNXSkinWidget;

    property Widgets[AIndex: Integer]: TNXSkinWidget read GetWidget; default;
  end;

  TNXSkinMaterial = class(TNXPersistObject)
  private
    FFileName: string;
    FImage: TNXImageHandle;
    FKind: TNXSkinMaterialKind;
  public
    procedure ClearRuntimeResource(ACanvas: TNXCanvas); virtual;
    procedure LoadRuntimeResource(const ASkinFileName: string;
      ACanvas: TNXCanvas); virtual;

    property Image: TNXImageHandle read FImage;
  published
    property FileName: string read FFileName write FFileName;
    property Kind: TNXSkinMaterialKind read FKind write FKind;
  end;

  TNXSkinAppearance = class(TNXPersistObject)
  end;

  TNXSkinColorAppearance = class(TNXSkinAppearance)
  private
    FBorderColor: TNXSkinColor;
    FBorderWidth: Integer;
    FFillColor: TNXSkinColor;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property FillColor: TNXSkinColor read FFillColor;
    property BorderColor: TNXSkinColor read FBorderColor;
    property BorderWidth: Integer read FBorderWidth write FBorderWidth;
  end;

  TNXSkinImageAppearance = class(TNXSkinAppearance)
  private
    FMaterial: string;
    FSourceRect: TNXSkinRect;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Material: string read FMaterial write FMaterial;
    property SourceRect: TNXSkinRect read FSourceRect;
  end;

  TNXSkinNineSliceAppearance = class(TNXSkinImageAppearance)
  private
    FBorder: TNXSkinInsets;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Border: TNXSkinInsets read FBorder;
  end;

  TNXSkinTextAppearance = class(TNXSkinAppearance)
  private
    FColor: TNXSkinColor;
    FFont: string;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Font: string read FFont write FFont;
    property Color: TNXSkinColor read FColor;
  end;

  TNXSkinCompositeAppearance = class(TNXSkinAppearance)
  private
    FAppearances: TNXSkinAppearanceList;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Appearances: TNXSkinAppearanceList read FAppearances;
  end;

  TNXSkinWidgetState = class(TNXPersistObject)
  private
    FAppearance: TNXSkinAppearance;
    FPart: string;
    FState: TNXSkinState;
    procedure SetAppearance(AValue: TNXSkinAppearance);
  public
    destructor Destroy; override;
  published
    property Part: string read FPart write FPart;
    property State: TNXSkinState read FState write FState;
    property Appearance: TNXSkinAppearance read FAppearance write SetAppearance;
  end;

  TNXSkinWidget = class(TNXPersistObject)
  private
    FSkinClass: string;
    FStates: TNXSkinWidgetStateList;
  public
    constructor Create; override;
    destructor Destroy; override;

    function FindState(AState: TNXSkinState): TNXSkinWidgetState;
  published
    property SkinClass: string read FSkinClass write FSkinClass;
    property States: TNXSkinWidgetStateList read FStates;
  end;

  TNXSkin = class(TNXPersistObject)
  private
    FActiveColor: TNXColor;
    FBackColor: TNXColor;
    FBorderColor: TNXColor;
    FForeColor: TNXColor;
    FFormBackColor: TNXColor;
    FFullTransColor: TNXColor;
    FMaterials: TNXSkinMaterialList;
    FSelectedColor: TNXColor;
    FSkinFileName: string;
    FTextBackColor: TNXColor;
    FTitleBarBackColor: TNXColor;
    FUnselectedTitleBarBackColor: TNXColor;
    FCanvas: TNXCanvas;
    FVersion: Integer;
    FWidgets: TNXSkinWidgetList;
    function AppearanceToNineSlice(AAppearance: TNXSkinAppearance;
      out ASlice: TNXNineSlice): Boolean;
    procedure LoadFromLegacyManifestFile(const AFileName: string;
      ACanvas: TNXCanvas);
    procedure LoadFromSkinFile(const AFileName: string; ACanvas: TNXCanvas);
    procedure BindRuntimeResources(const ASkinFileName: string;
      ACanvas: TNXCanvas);
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Clear; virtual;
    function FindMaterial(const AName: string): TNXSkinMaterial;
    function FindWidget(const ASkinClass: string): TNXSkinWidget;
    function FindAppearance(const ASkinClass, APart: string;
      AState: TNXSkinState): TNXSkinAppearance;
    function GetNineSlice(const ASkinClass, APart: string;
      AState: TNXSkinState; out ASlice: TNXNineSlice): Boolean;
    procedure LoadNamedSkin(const ASkinName: string; ACanvas: TNXCanvas);

    property ActiveColor: TNXColor read FActiveColor write FActiveColor;
    property BackColor: TNXColor read FBackColor write FBackColor;
    property BorderColor: TNXColor read FBorderColor write FBorderColor;
    property ForeColor: TNXColor read FForeColor write FForeColor;
    property FormBackColor: TNXColor read FFormBackColor write FFormBackColor;
    property FullTransColor: TNXColor read FFullTransColor write FFullTransColor;
    property SelectedColor: TNXColor read FSelectedColor write FSelectedColor;
    property TextBackColor: TNXColor read FTextBackColor write FTextBackColor;
    property TitleBarBackColor: TNXColor read FTitleBarBackColor write FTitleBarBackColor;
    property UnselectedTitleBarBackColor: TNXColor read FUnselectedTitleBarBackColor
      write FUnselectedTitleBarBackColor;
  published
    property Version: Integer read FVersion write FVersion;
    property Materials: TNXSkinMaterialList read FMaterials;
    property Widgets: TNXSkinWidgetList read FWidgets;
  end;

implementation

const
  cSkinManifestFileName = 'skin.json';
  cSkinsFolderName = 'skins';

{ TNXSkinColor }

constructor TNXSkinColor.Create;
begin
  inherited Create;
  FAlpha := 255;
end;

{ TNXSkinMaterialList }

constructor TNXSkinMaterialList.Create;
begin
  inherited Create;
  ItemClass := TNXSkinMaterial;
end;

function TNXSkinMaterialList.AddMaterial: TNXSkinMaterial;
begin
  Result := TNXSkinMaterial(New);
end;

function TNXSkinMaterialList.FindByName(
  const AName: string): TNXSkinMaterial;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to Count - 1 do
    if SameText(Materials[lIndex].Name, AName) then
      Exit(Materials[lIndex]);
end;

function TNXSkinMaterialList.GetMaterial(AIndex: Integer): TNXSkinMaterial;
begin
  Result := TNXSkinMaterial(Items[AIndex]);
end;

{ TNXSkinAppearanceList }

constructor TNXSkinAppearanceList.Create;
begin
  inherited Create;
  ItemClass := TNXSkinAppearance;
end;

function TNXSkinAppearanceList.AddAppearance(
  AClass: TNXPersistClass): TNXSkinAppearance;
begin
  Result := TNXSkinAppearance(AClass.Create);
  Add(Result);
end;

function TNXSkinAppearanceList.GetAppearance(
  AIndex: Integer): TNXSkinAppearance;
begin
  Result := TNXSkinAppearance(Items[AIndex]);
end;

{ TNXSkinWidgetStateList }

constructor TNXSkinWidgetStateList.Create;
begin
  inherited Create;
  ItemClass := TNXSkinWidgetState;
end;

function TNXSkinWidgetStateList.AddState: TNXSkinWidgetState;
begin
  Result := TNXSkinWidgetState(New);
end;

function TNXSkinWidgetStateList.FindByState(
  AState: TNXSkinState): TNXSkinWidgetState;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to Count - 1 do
    if States[lIndex].State = AState then
      Exit(States[lIndex]);
end;

function TNXSkinWidgetStateList.GetState(
  AIndex: Integer): TNXSkinWidgetState;
begin
  Result := TNXSkinWidgetState(Items[AIndex]);
end;

{ TNXSkinWidgetList }

constructor TNXSkinWidgetList.Create;
begin
  inherited Create;
  ItemClass := TNXSkinWidget;
end;

function TNXSkinWidgetList.AddWidget: TNXSkinWidget;
begin
  Result := TNXSkinWidget(New);
end;

function TNXSkinWidgetList.FindBySkinClass(
  const ASkinClass: string): TNXSkinWidget;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to Count - 1 do
    if SameText(Widgets[lIndex].SkinClass, ASkinClass) then
      Exit(Widgets[lIndex]);
end;

function TNXSkinWidgetList.GetWidget(AIndex: Integer): TNXSkinWidget;
begin
  Result := TNXSkinWidget(Items[AIndex]);
end;

{ TNXSkinMaterial }

procedure TNXSkinMaterial.ClearRuntimeResource(ACanvas: TNXCanvas);
begin
  if Assigned(ACanvas) and Assigned(FImage) then
    ACanvas.DestroyImage(FImage);

  FImage := nil;
end;

procedure TNXSkinMaterial.LoadRuntimeResource(const ASkinFileName: string;
  ACanvas: TNXCanvas);
var
  lFileName: string;
begin
  ClearRuntimeResource(ACanvas);

  if (Kind <> smkImage) or (not Assigned(ACanvas)) or (FileName = '') then
    Exit;

  if ExtractFileDrive(FileName) <> '' then
    lFileName := FileName
  else
    lFileName := IncludeTrailingPathDelimiter(ExtractFilePath(ASkinFileName)) +
      FileName;

  FImage := ACanvas.LoadImage(lFileName);
end;

{ TNXSkinColorAppearance }

constructor TNXSkinColorAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FFillColor := TNXSkinColor.Create;
  FBorderColor := TNXSkinColor.Create;
end;

destructor TNXSkinColorAppearance.Destroy;
begin
  FreeAndNil(FBorderColor);
  FreeAndNil(FFillColor);
  inherited Destroy;
end;

{ TNXSkinImageAppearance }

constructor TNXSkinImageAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FSourceRect := TNXSkinRect.Create;
end;

destructor TNXSkinImageAppearance.Destroy;
begin
  FreeAndNil(FSourceRect);
  inherited Destroy;
end;

{ TNXSkinNineSliceAppearance }

constructor TNXSkinNineSliceAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FBorder := TNXSkinInsets.Create;
end;

destructor TNXSkinNineSliceAppearance.Destroy;
begin
  FreeAndNil(FBorder);
  inherited Destroy;
end;

{ TNXSkinTextAppearance }

constructor TNXSkinTextAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FColor := TNXSkinColor.Create;
end;

destructor TNXSkinTextAppearance.Destroy;
begin
  FreeAndNil(FColor);
  inherited Destroy;
end;

{ TNXSkinCompositeAppearance }

constructor TNXSkinCompositeAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FAppearances := TNXSkinAppearanceList.Create;
end;

destructor TNXSkinCompositeAppearance.Destroy;
begin
  FreeAndNil(FAppearances);
  inherited Destroy;
end;

{ TNXSkinWidgetState }

destructor TNXSkinWidgetState.Destroy;
begin
  FreeAndNil(FAppearance);
  inherited Destroy;
end;

procedure TNXSkinWidgetState.SetAppearance(AValue: TNXSkinAppearance);
begin
  if FAppearance = AValue then
    Exit;

  FreeAndNil(FAppearance);
  FAppearance := AValue;
end;

{ TNXSkinWidget }

constructor TNXSkinWidget.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FStates := TNXSkinWidgetStateList.Create;
end;

destructor TNXSkinWidget.Destroy;
begin
  FreeAndNil(FStates);
  inherited Destroy;
end;

function TNXSkinWidget.FindState(AState: TNXSkinState): TNXSkinWidgetState;
begin
  Result := States.FindByState(AState);
end;

{ TNXSkin }

function TNXSkin.AppearanceToNineSlice(AAppearance: TNXSkinAppearance;
  out ASlice: TNXNineSlice): Boolean;
var
  lAppearance: TNXSkinNineSliceAppearance;
  lMaterial: TNXSkinMaterial;
begin
  ASlice.Image := nil;
  ASlice.SourceRect := MakeNXRect(0, 0, 0, 0);
  ASlice.Left := 0;
  ASlice.Top := 0;
  ASlice.Right := 0;
  ASlice.Bottom := 0;

  Result := AAppearance is TNXSkinNineSliceAppearance;
  if not Result then
    Exit;

  lAppearance := TNXSkinNineSliceAppearance(AAppearance);
  lMaterial := FindMaterial(lAppearance.Material);
  if (not Assigned(lMaterial)) or (lMaterial.Image = nil) then
  begin
    Result := False;
    Exit;
  end;

  ASlice.Image := lMaterial.Image;
  ASlice.SourceRect := MakeNXRect(lAppearance.SourceRect.X,
    lAppearance.SourceRect.Y, lAppearance.SourceRect.W,
    lAppearance.SourceRect.H);
  ASlice.Left := lAppearance.Border.Left;
  ASlice.Top := lAppearance.Border.Top;
  ASlice.Right := lAppearance.Border.Right;
  ASlice.Bottom := lAppearance.Border.Bottom;
end;

procedure TNXSkin.BindRuntimeResources(const ASkinFileName: string;
  ACanvas: TNXCanvas);
var
  lIndex: Integer;
begin
  FCanvas := ACanvas;
  FSkinFileName := ASkinFileName;

  for lIndex := 0 to Materials.Count - 1 do
    Materials[lIndex].LoadRuntimeResource(ASkinFileName, ACanvas);
end;

procedure TNXSkin.Clear;
var
  lIndex: Integer;
begin
  for lIndex := 0 to Materials.Count - 1 do
    Materials[lIndex].ClearRuntimeResource(FCanvas);

  Widgets.Clear;
  Materials.Clear;
  FSkinFileName := '';
  FCanvas := nil;
end;

constructor TNXSkin.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
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
  FVersion := 1;
  FMaterials := TNXSkinMaterialList.Create;
  FWidgets := TNXSkinWidgetList.Create;
end;

destructor TNXSkin.Destroy;
begin
  Clear;
  FreeAndNil(FWidgets);
  FreeAndNil(FMaterials);
  inherited Destroy;
end;

function TNXSkin.FindAppearance(const ASkinClass, APart: string;
  AState: TNXSkinState): TNXSkinAppearance;
var
  lIndex: Integer;
  lState: TNXSkinWidgetState;
  lWidget: TNXSkinWidget;
begin
  Result := nil;
  lWidget := FindWidget(ASkinClass);
  if not Assigned(lWidget) then
    Exit;

  for lIndex := 0 to lWidget.States.Count - 1 do
  begin
    lState := lWidget.States[lIndex];
    if (lState.State = AState) and SameText(lState.Part, APart) then
      Exit(lState.Appearance);
  end;

  if AState <> ssNormal then
    Result := FindAppearance(ASkinClass, APart, ssNormal);
end;

function TNXSkin.FindMaterial(const AName: string): TNXSkinMaterial;
begin
  Result := Materials.FindByName(AName);
end;

function TNXSkin.FindWidget(const ASkinClass: string): TNXSkinWidget;
begin
  Result := Widgets.FindBySkinClass(ASkinClass);
end;

function TNXSkin.GetNineSlice(const ASkinClass, APart: string;
  AState: TNXSkinState; out ASlice: TNXNineSlice): Boolean;
begin
  Result := AppearanceToNineSlice(FindAppearance(ASkinClass, APart, AState),
    ASlice);
end;

procedure TNXSkin.LoadFromLegacyManifestFile(const AFileName: string;
  ACanvas: TNXCanvas);
var
  lDeStreamer: TJSONDeStreamer;
  lFile: TStringList;
  lImageDef: TNXSkinImageDef;
  lImageIndex: Integer;
  lManifest: TNXSkinManifest;
  lMaterial: TNXSkinMaterial;
  lSliceDef: TNXSkinSliceDef;
  lSliceIndex: Integer;
  lState: TNXSkinWidgetState;
  lWidget: TNXSkinWidget;
begin
  lManifest := TNXSkinManifest.Create;
  try
    lFile := TStringList.Create;
    try
      lFile.LoadFromFile(AFileName);
      lDeStreamer := TJSONDeStreamer.Create(nil);
      try
        lDeStreamer.Options := lDeStreamer.Options + [jdoCaseInsensitive];
        lDeStreamer.JSONToObject(Trim(lFile.Text), lManifest);
      finally
        lDeStreamer.Free;
      end;
    finally
      lFile.Free;
    end;

    if lManifest.Version <> 1 then
      raise Exception.Create('Unsupported skin version: ' +
        IntToStr(lManifest.Version));

    Clear;
    Version := lManifest.Version;

    for lImageIndex := 0 to lManifest.Images.Count - 1 do
    begin
      lImageDef := TNXSkinImageDef(lManifest.Images.Items[lImageIndex]);
      if lImageDef.ID = '' then
        raise Exception.Create('Skin image is missing an ID');
      if Assigned(FindMaterial(lImageDef.ID)) then
        raise Exception.Create('Duplicate skin image ID: ' + lImageDef.ID);

      lMaterial := Materials.AddMaterial;
      lMaterial.Name := lImageDef.ID;
      lMaterial.Kind := smkImage;
      lMaterial.FileName := lImageDef.FileName;
    end;

    for lSliceIndex := 0 to lManifest.Slices.Count - 1 do
    begin
      lSliceDef := TNXSkinSliceDef(lManifest.Slices.Items[lSliceIndex]);
      if not Assigned(FindMaterial(lSliceDef.Image)) then
        raise Exception.Create('Skin slice references unknown image: ' +
          lSliceDef.Image);

      lWidget := FindWidget(lSliceDef.SkinClass);
      if not Assigned(lWidget) then
      begin
        lWidget := Widgets.AddWidget;
        lWidget.SkinClass := lSliceDef.SkinClass;
      end;

      lState := lWidget.States.AddState;
      lState.Part := lSliceDef.Part;
      lState.State := lSliceDef.State;
      lState.Appearance := TNXSkinNineSliceAppearance.Create;
      with TNXSkinNineSliceAppearance(lState.Appearance) do
      begin
        Material := lSliceDef.Image;
        SourceRect.X := lSliceDef.SourceRect.X;
        SourceRect.Y := lSliceDef.SourceRect.Y;
        SourceRect.W := lSliceDef.SourceRect.W;
        SourceRect.H := lSliceDef.SourceRect.H;
        Border.Left := lSliceDef.Border.Left;
        Border.Top := lSliceDef.Border.Top;
        Border.Right := lSliceDef.Border.Right;
        Border.Bottom := lSliceDef.Border.Bottom;
      end;
    end;

    BindRuntimeResources(AFileName, ACanvas);
  finally
    lManifest.Free;
  end;
end;

procedure TNXSkin.LoadFromSkinFile(const AFileName: string; ACanvas: TNXCanvas);
var
  lFile: TStringList;
  lFileText: string;
begin
  if ACanvas = nil then
    raise Exception.Create('Cannot load skin without a canvas');

  lFile := TStringList.Create;
  try
    lFile.LoadFromFile(AFileName);
    lFileText := Trim(lFile.Text);
  finally
    lFile.Free;
  end;

  if (Pos('"Materials"', lFileText) = 0) and
    (Pos('"materials"', lFileText) = 0) then
  begin
    LoadFromLegacyManifestFile(AFileName, ACanvas);
    Exit;
  end;

  Clear;
  JSON := lFileText;
  BindRuntimeResources(AFileName, ACanvas);
end;

procedure TNXSkin.LoadNamedSkin(const ASkinName: string; ACanvas: TNXCanvas);
var
  lSkinFolder: string;
  lSkinsFolder: string;
begin
  if Trim(ASkinName) = '' then
    raise Exception.Create('Skin name cannot be empty');

  lSkinsFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    cSkinsFolderName;
  lSkinFolder := IncludeTrailingPathDelimiter(lSkinsFolder) + ASkinName;
  Name := ASkinName;
  LoadFromSkinFile(IncludeTrailingPathDelimiter(lSkinFolder) +
    cSkinManifestFileName, ACanvas);
end;

initialization
  TNXPersistObject.RegisterPersistClass(TNXSkin);
  TNXPersistObject.RegisterPersistClass(TNXSkinRect);
  TNXPersistObject.RegisterPersistClass(TNXSkinInsets);
  TNXPersistObject.RegisterPersistClass(TNXSkinColor);
  TNXPersistObject.RegisterPersistClass(TNXSkinMaterial);
  TNXPersistObject.RegisterPersistClass(TNXSkinMaterialList);
  TNXPersistObject.RegisterPersistClass(TNXSkinAppearance);
  TNXPersistObject.RegisterPersistClass(TNXSkinAppearanceList);
  TNXPersistObject.RegisterPersistClass(TNXSkinColorAppearance);
  TNXPersistObject.RegisterPersistClass(TNXSkinImageAppearance);
  TNXPersistObject.RegisterPersistClass(TNXSkinNineSliceAppearance);
  TNXPersistObject.RegisterPersistClass(TNXSkinTextAppearance);
  TNXPersistObject.RegisterPersistClass(TNXSkinCompositeAppearance);
  TNXPersistObject.RegisterPersistClass(TNXSkinWidgetState);
  TNXPersistObject.RegisterPersistClass(TNXSkinWidgetStateList);
  TNXPersistObject.RegisterPersistClass(TNXSkinWidget);
  TNXPersistObject.RegisterPersistClass(TNXSkinWidgetList);

end.
