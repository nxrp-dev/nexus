unit obNXImage;

{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform,
  obNXControl;

type
  TNXImage = class(TNXControl)
  private
    FFileName: string;
    FFullSrc: Boolean;
    FOwnsSource: Boolean;
    FSourceImage: TNXImageHandle;
    FSrcRect: TNXRect;
  protected
    procedure ClearSourceImage;
    function GetFullSrc: Boolean;
    function GetSource: TNXImageHandle;
    function GetSrcRect: TNXRect; virtual;
    procedure LoadImageFromFile;
    procedure SetFullSrc(AValue: Boolean);
    procedure SetSource(ASourceImage: TNXImageHandle);
    procedure SetSrcRect(ARect: TNXRect); virtual;
  public
    constructor Create(const AParent: INXControlParent); overload; override;
    destructor Destroy; override;
    procedure ChildAddedCallback; override;
    procedure LoadFromFile(const AFileName: string);
    procedure Render; override;
  end;

implementation

constructor TNXImage.Create(const AParent: INXControlParent);
begin
  inherited Create(AParent);
  FillStyle := FS_None;
  FFullSrc := True;
  FOwnsSource := False;
end;

destructor TNXImage.Destroy;
begin
  ClearSourceImage;
  inherited Destroy;
end;

procedure TNXImage.ChildAddedCallback;
begin
  inherited;
  if (FFileName <> '') and (FSourceImage = nil) and Assigned(Canvas) then
    LoadImageFromFile;
end;

procedure TNXImage.ClearSourceImage;
begin
  if FOwnsSource and (FSourceImage <> nil) and Assigned(Canvas) then
    Canvas.DestroyImage(FSourceImage);
  FSourceImage := nil;
  FOwnsSource := False;
end;

function TNXImage.GetFullSrc: Boolean;
begin
  Result := FFullSrc;
end;

function TNXImage.GetSource: TNXImageHandle;
begin
  Result := FSourceImage;
end;

function TNXImage.GetSrcRect: TNXRect;
begin
  Result := FSrcRect;
end;

procedure TNXImage.LoadFromFile(const AFileName: string);
begin
  FFileName := AFileName;
  if Assigned(Canvas) then
    LoadImageFromFile;
end;

procedure TNXImage.LoadImageFromFile;
begin
  if (FFileName = '') or (not Assigned(Canvas)) then
    Exit;

  ClearSourceImage;
  FSourceImage := Canvas.LoadImage(FFileName);
  FOwnsSource := True;
end;

procedure TNXImage.SetSource(ASourceImage: TNXImageHandle);
begin
  ClearSourceImage;
  FSourceImage := ASourceImage;
  FOwnsSource := False;
end;

procedure TNXImage.SetSrcRect(ARect: TNXRect);
begin
  FSrcRect := ARect;
end;

procedure TNXImage.SetFullSrc(AValue: Boolean);
begin
  FFullSrc := AValue;
end;

procedure TNXImage.Render;
var
  lDestRect: TNXRect;
begin
  inherited Render;
  if (FSourceImage = nil) or (not Assigned(Canvas)) then
    Exit;

  lDestRect.x := AbsLeft;
  lDestRect.y := AbsTop;
  lDestRect.w := Width;
  lDestRect.h := Height;

  if FFullSrc then
    Canvas.DrawImage(FSourceImage, lDestRect)
  else
    Canvas.DrawImage(FSourceImage, FSrcRect, lDestRect);
end;

end.
