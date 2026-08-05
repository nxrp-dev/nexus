unit obNXSkinManifest;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  tpNXSkin;

type
  TNXSkinRectDef = class(TPersistent)
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

  TNXSkinBorderDef = class(TPersistent)
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

  TNXSkinImageDef = class(TCollectionItem)
  private
    FFileName: string;
    FID: string;
  published
    property ID: string read FID write FID;
    property FileName: string read FFileName write FFileName;
  end;

  TNXSkinSliceDef = class(TCollectionItem)
  private
    FBorder: TNXSkinBorderDef;
    FImage: string;
    FPart: string;
    FSkinClass: string;
    FSourceRect: TNXSkinRectDef;
    FState: TNXSkinState;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
  published
    property SkinClass: string read FSkinClass write FSkinClass;
    property Part: string read FPart write FPart;
    property State: TNXSkinState read FState write FState;
    property Image: string read FImage write FImage;
    property SourceRect: TNXSkinRectDef read FSourceRect write FSourceRect;
    property Border: TNXSkinBorderDef read FBorder write FBorder;
  end;

  TNXSkinManifest = class(TPersistent)
  private
    FImages: TCollection;
    FSlices: TCollection;
    FVersion: Integer;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property Version: Integer read FVersion write FVersion;
    property Images: TCollection read FImages;
    property Slices: TCollection read FSlices;
  end;

implementation

constructor TNXSkinSliceDef.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FSourceRect := TNXSkinRectDef.Create;
  FBorder := TNXSkinBorderDef.Create;
end;

destructor TNXSkinSliceDef.Destroy;
begin
  FreeAndNil(FBorder);
  FreeAndNil(FSourceRect);
  inherited Destroy;
end;

constructor TNXSkinManifest.Create;
begin
  inherited Create;
  FVersion := 1;
  FImages := TCollection.Create(TNXSkinImageDef);
  FSlices := TCollection.Create(TNXSkinSliceDef);
end;

destructor TNXSkinManifest.Destroy;
begin
  FreeAndNil(FSlices);
  FreeAndNil(FImages);
  inherited Destroy;
end;

end.
