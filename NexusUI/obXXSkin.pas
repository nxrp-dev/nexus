unit obXXSkin;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  obNXPersist,
  tpNXSkin;

type
  TXXSkin = class;
  TXXSkinMaterial = class;
  TXXSkinWidget = class;
  TXXSkinWidgetState = class;
  TXXSkinAppearance = class;

  TXXSkinMaterialKind = (
    smkImage,
    smkFont,
    smkBinary
  );

  TXXSkinRect = class(TNXPersistObject)
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

  TXXSkinInsets = class(TNXPersistObject)
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

  TXXSkinColor = class(TNXPersistObject)
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

  TXXSkinMaterialList = class(TNXPersistList)
  private
    function GetMaterial(AIndex: Integer): TXXSkinMaterial;
  public
    constructor Create; override;

    function AddMaterial: TXXSkinMaterial;
    function FindByName(const AName: string): TXXSkinMaterial;

    property Materials[AIndex: Integer]: TXXSkinMaterial read GetMaterial;
      default;
  end;

  TXXSkinAppearanceList = class(TNXPersistList)
  private
    function GetAppearance(AIndex: Integer): TXXSkinAppearance;
  public
    constructor Create; override;

    function AddAppearance(AClass: TNXPersistClass): TXXSkinAppearance;

    property Appearances[AIndex: Integer]: TXXSkinAppearance
      read GetAppearance; default;
  end;

  TXXSkinWidgetStateList = class(TNXPersistList)
  private
    function GetState(AIndex: Integer): TXXSkinWidgetState;
  public
    constructor Create; override;

    function AddState: TXXSkinWidgetState;
    function FindByState(AState: TNXSkinState): TXXSkinWidgetState;

    property States[AIndex: Integer]: TXXSkinWidgetState read GetState;
      default;
  end;

  TXXSkinWidgetList = class(TNXPersistList)
  private
    function GetWidget(AIndex: Integer): TXXSkinWidget;
  public
    constructor Create; override;

    function AddWidget: TXXSkinWidget;
    function FindBySkinClass(const ASkinClass: string): TXXSkinWidget;

    property Widgets[AIndex: Integer]: TXXSkinWidget read GetWidget; default;
  end;

  TXXSkinMaterial = class(TNXPersistObject)
  private
    FFileName: string;
    FKind: TXXSkinMaterialKind;
  published
    property FileName: string read FFileName write FFileName;
    property Kind: TXXSkinMaterialKind read FKind write FKind;
  end;

  TXXSkinAppearance = class(TNXPersistObject)
  end;

  TXXSkinColorAppearance = class(TXXSkinAppearance)
  private
    FBorderColor: TXXSkinColor;
    FBorderWidth: Integer;
    FFillColor: TXXSkinColor;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property FillColor: TXXSkinColor read FFillColor;
    property BorderColor: TXXSkinColor read FBorderColor;
    property BorderWidth: Integer read FBorderWidth write FBorderWidth;
  end;

  TXXSkinImageAppearance = class(TXXSkinAppearance)
  private
    FMaterial: string;
    FSourceRect: TXXSkinRect;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Material: string read FMaterial write FMaterial;
    property SourceRect: TXXSkinRect read FSourceRect;
  end;

  TXXSkinNineSliceAppearance = class(TXXSkinImageAppearance)
  private
    FBorder: TXXSkinInsets;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Border: TXXSkinInsets read FBorder;
  end;

  TXXSkinTextAppearance = class(TXXSkinAppearance)
  private
    FColor: TXXSkinColor;
    FFont: string;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Font: string read FFont write FFont;
    property Color: TXXSkinColor read FColor;
  end;

  TXXSkinCompositeAppearance = class(TXXSkinAppearance)
  private
    FAppearances: TXXSkinAppearanceList;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Appearances: TXXSkinAppearanceList read FAppearances;
  end;

  TXXSkinWidgetState = class(TNXPersistObject)
  private
    FAppearance: TXXSkinAppearance;
    FState: TNXSkinState;
    procedure SetAppearance(AValue: TXXSkinAppearance);
  public
    destructor Destroy; override;
  published
    property State: TNXSkinState read FState write FState;
    property Appearance: TXXSkinAppearance read FAppearance write SetAppearance;
  end;

  TXXSkinWidget = class(TNXPersistObject)
  private
    FSkinClass: string;
    FStates: TXXSkinWidgetStateList;
  public
    constructor Create; override;
    destructor Destroy; override;

    function FindState(AState: TNXSkinState): TXXSkinWidgetState;
  published
    property SkinClass: string read FSkinClass write FSkinClass;
    property States: TXXSkinWidgetStateList read FStates;
  end;

  TXXSkin = class(TNXPersistObject)
  private
    FMaterials: TXXSkinMaterialList;
    FVersion: Integer;
    FWidgets: TXXSkinWidgetList;
  public
    constructor Create; override;
    destructor Destroy; override;

    function FindMaterial(const AName: string): TXXSkinMaterial;
    function FindWidget(const ASkinClass: string): TXXSkinWidget;
  published
    property Version: Integer read FVersion write FVersion;
    property Materials: TXXSkinMaterialList read FMaterials;
    property Widgets: TXXSkinWidgetList read FWidgets;
  end;

implementation

{ TXXSkinColor }

constructor TXXSkinColor.Create;
begin
  inherited Create;
  FAlpha := 255;
end;

{ TXXSkinMaterialList }

constructor TXXSkinMaterialList.Create;
begin
  inherited Create;
  ItemClass := TXXSkinMaterial;
end;

function TXXSkinMaterialList.AddMaterial: TXXSkinMaterial;
begin
  Result := TXXSkinMaterial(New);
end;

function TXXSkinMaterialList.FindByName(
  const AName: string): TXXSkinMaterial;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to Count - 1 do
    if SameText(Materials[lIndex].Name, AName) then
      Exit(Materials[lIndex]);
end;

function TXXSkinMaterialList.GetMaterial(AIndex: Integer): TXXSkinMaterial;
begin
  Result := TXXSkinMaterial(Items[AIndex]);
end;

{ TXXSkinAppearanceList }

constructor TXXSkinAppearanceList.Create;
begin
  inherited Create;
  ItemClass := TXXSkinAppearance;
end;

function TXXSkinAppearanceList.AddAppearance(
  AClass: TNXPersistClass): TXXSkinAppearance;
begin
  Result := TXXSkinAppearance(AClass.Create);
  Add(Result);
end;

function TXXSkinAppearanceList.GetAppearance(
  AIndex: Integer): TXXSkinAppearance;
begin
  Result := TXXSkinAppearance(Items[AIndex]);
end;

{ TXXSkinWidgetStateList }

constructor TXXSkinWidgetStateList.Create;
begin
  inherited Create;
  ItemClass := TXXSkinWidgetState;
end;

function TXXSkinWidgetStateList.AddState: TXXSkinWidgetState;
begin
  Result := TXXSkinWidgetState(New);
end;

function TXXSkinWidgetStateList.FindByState(
  AState: TNXSkinState): TXXSkinWidgetState;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to Count - 1 do
    if States[lIndex].State = AState then
      Exit(States[lIndex]);
end;

function TXXSkinWidgetStateList.GetState(
  AIndex: Integer): TXXSkinWidgetState;
begin
  Result := TXXSkinWidgetState(Items[AIndex]);
end;

{ TXXSkinWidgetList }

constructor TXXSkinWidgetList.Create;
begin
  inherited Create;
  ItemClass := TXXSkinWidget;
end;

function TXXSkinWidgetList.AddWidget: TXXSkinWidget;
begin
  Result := TXXSkinWidget(New);
end;

function TXXSkinWidgetList.FindBySkinClass(
  const ASkinClass: string): TXXSkinWidget;
var
  lIndex: Integer;
begin
  Result := nil;

  for lIndex := 0 to Count - 1 do
    if SameText(Widgets[lIndex].SkinClass, ASkinClass) then
      Exit(Widgets[lIndex]);
end;

function TXXSkinWidgetList.GetWidget(AIndex: Integer): TXXSkinWidget;
begin
  Result := TXXSkinWidget(Items[AIndex]);
end;

{ TXXSkinColorAppearance }

constructor TXXSkinColorAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FFillColor := TXXSkinColor.Create;
  FBorderColor := TXXSkinColor.Create;
end;

destructor TXXSkinColorAppearance.Destroy;
begin
  FreeAndNil(FBorderColor);
  FreeAndNil(FFillColor);
  inherited Destroy;
end;

{ TXXSkinImageAppearance }

constructor TXXSkinImageAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FSourceRect := TXXSkinRect.Create;
end;

destructor TXXSkinImageAppearance.Destroy;
begin
  FreeAndNil(FSourceRect);
  inherited Destroy;
end;

{ TXXSkinNineSliceAppearance }

constructor TXXSkinNineSliceAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FBorder := TXXSkinInsets.Create;
end;

destructor TXXSkinNineSliceAppearance.Destroy;
begin
  FreeAndNil(FBorder);
  inherited Destroy;
end;

{ TXXSkinTextAppearance }

constructor TXXSkinTextAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FColor := TXXSkinColor.Create;
end;

destructor TXXSkinTextAppearance.Destroy;
begin
  FreeAndNil(FColor);
  inherited Destroy;
end;

{ TXXSkinCompositeAppearance }

constructor TXXSkinCompositeAppearance.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FAppearances := TXXSkinAppearanceList.Create;
end;

destructor TXXSkinCompositeAppearance.Destroy;
begin
  FreeAndNil(FAppearances);
  inherited Destroy;
end;

{ TXXSkinWidgetState }

destructor TXXSkinWidgetState.Destroy;
begin
  FreeAndNil(FAppearance);
  inherited Destroy;
end;

procedure TXXSkinWidgetState.SetAppearance(AValue: TXXSkinAppearance);
begin
  if FAppearance = AValue then
    Exit;

  FreeAndNil(FAppearance);
  FAppearance := AValue;
end;

{ TXXSkinWidget }

constructor TXXSkinWidget.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FStates := TXXSkinWidgetStateList.Create;
end;

destructor TXXSkinWidget.Destroy;
begin
  FreeAndNil(FStates);
  inherited Destroy;
end;

function TXXSkinWidget.FindState(AState: TNXSkinState): TXXSkinWidgetState;
begin
  Result := States.FindByState(AState);
end;

{ TXXSkin }

constructor TXXSkin.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FVersion := 1;
  FMaterials := TXXSkinMaterialList.Create;
  FWidgets := TXXSkinWidgetList.Create;
end;

destructor TXXSkin.Destroy;
begin
  FreeAndNil(FWidgets);
  FreeAndNil(FMaterials);
  inherited Destroy;
end;

function TXXSkin.FindMaterial(const AName: string): TXXSkinMaterial;
begin
  Result := Materials.FindByName(AName);
end;

function TXXSkin.FindWidget(const ASkinClass: string): TXXSkinWidget;
begin
  Result := Widgets.FindBySkinClass(ASkinClass);
end;

initialization
  TNXPersistObject.RegisterPersistClass(TXXSkin);
  TNXPersistObject.RegisterPersistClass(TXXSkinRect);
  TNXPersistObject.RegisterPersistClass(TXXSkinInsets);
  TNXPersistObject.RegisterPersistClass(TXXSkinColor);
  TNXPersistObject.RegisterPersistClass(TXXSkinMaterial);
  TNXPersistObject.RegisterPersistClass(TXXSkinMaterialList);
  TNXPersistObject.RegisterPersistClass(TXXSkinAppearance);
  TNXPersistObject.RegisterPersistClass(TXXSkinAppearanceList);
  TNXPersistObject.RegisterPersistClass(TXXSkinColorAppearance);
  TNXPersistObject.RegisterPersistClass(TXXSkinImageAppearance);
  TNXPersistObject.RegisterPersistClass(TXXSkinNineSliceAppearance);
  TNXPersistObject.RegisterPersistClass(TXXSkinTextAppearance);
  TNXPersistObject.RegisterPersistClass(TXXSkinCompositeAppearance);
  TNXPersistObject.RegisterPersistClass(TXXSkinWidgetState);
  TNXPersistObject.RegisterPersistClass(TXXSkinWidgetStateList);
  TNXPersistObject.RegisterPersistClass(TXXSkinWidget);
  TNXPersistObject.RegisterPersistClass(TXXSkinWidgetList);

end.
