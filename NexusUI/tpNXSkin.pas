unit tpNXSkin;

{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform;

type
  TNXSkinState = (
    ssNormal,
    ssHot,
    ssPressed,
    ssDisabled,
    ssFocused
  );

  TNXNineSlice = record
    Image: TNXImageHandle;
    SourceRect: TNXRect;
    Left: Integer;
    Top: Integer;
    Right: Integer;
    Bottom: Integer;
  end;

  TNXSkinSliceEntry = record
    SkinClass: string;
    Part: string;
    State: TNXSkinState;
    Slice: TNXNineSlice;
  end;

  TNXSkinImageEntry = record
    ID: string;
    Image: TNXImageHandle;
  end;

implementation

end.
