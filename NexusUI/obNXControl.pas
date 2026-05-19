unit obNXControl;
{$mode objfpc}{$H+}
{$interfaces corba}

interface

uses Classes, SysUtils, Math, fgl, obNXCanvas, obNXFont, obNXSkin,
  tpNXEvents, tpNXPlatform, obNXPlatform;

type
  TNXControl = class;
  TNXControlList = specialize TFPGObjectList<TNXControl>;
  INXControlParent = interface
    procedure AddChild(AChild: TNXControl);
    procedure FreeChild(AChild: TNXControl);
    procedure UnselectChildren;
    function GetAbsLeft: Integer;
    function GetAbsTop: Integer;
    function GetCanvas: TNXCanvas;
    function GetChildOriginX(AChild: TNXControl): Integer;
    function GetChildOriginY(AChild: TNXControl): Integer;
    function GetChildren: TNXControlList;
    function GetFontForChildren: TNXFont;
    function GetHeight: Integer;
    function GetSkin: TNXSkin;
    function GetWidth: Integer;
    property AbsLeft: Integer read GetAbsLeft;
    property AbsTop: Integer read GetAbsTop;
    property Canvas: TNXCanvas read GetCanvas;
    property Children: TNXControlList read GetChildren;
    property FontForChildren: TNXFont read GetFontForChildren;
    property Height: Integer read GetHeight;
    property Skin: TNXSkin read GetSkin;
    property Width: Integer read GetWidth;
  end;
  TNXMouseEvent = procedure(Sender: TObject; X, Y: Integer; Button: TNXMouseButton) of object;
  TNXMouseMotionEvent = procedure(Sender: TObject; X, Y: Integer; ButtonState: TNXMouseButtons) of object;
  TNXTextInputEvent = procedure(Sender: TObject; const AText: string) of object;
  TNXKeyEvent = procedure(Sender: TObject; const AEvent: TNXKeyEventData) of object;

  TNXControl = class(INXControlParent)
  private
    FChildren: TNXControlList;
    FCurSelected, FDestroying, FEnabled, FMouseEntered, FReceiveAllEvents: Boolean;
    FSelectable, FVisible: Boolean;
    FHeight, FLeft, FTop, FWidth: integer;
    FHasLastClick: Boolean;
    FLastClickButton: TNXMouseButton;
    FLastClickTicks: UInt32;
    FLastClickX, FLastClickY: Integer;
    FOnKeyDown: TNXKeyEvent;
    FOnKeyUp: TNXKeyEvent;
    FOnLostSelected: TNotifyEvent;
    FOnMouseClick: TNXMouseEvent;
    FOnMouseDoubleClick: TNXMouseEvent;
    FOnMouseDown: TNXMouseEvent;
    FOnMouseEnter: TNotifyEvent;
    FOnMouseExit: TNotifyEvent;
    FOnMouseMotion: TNXMouseMotionEvent;
    FOnMouseUp: TNXMouseEvent;
    FOnResize: TNotifyEvent;
    FOnSelected: TNotifyEvent;
    FOnTextInput: TNXTextInputEvent;
    FCanvas: TNXCanvas;
    FParent: INXControlParent;
    FFont: TNXFont;
    FMetricFont: TNXFont;
    FSkinClass: string;
  protected
    FBackColor: TNXColor;
    FForeColor: TNXColor;
    FActiveColor: TNXColor;
    CurFillColor: TNXColor;
    CurBorderColor: TNXColor;
    FFillStyle: TFillStyle;
    FCaption: string;
    FBorderStyle: TBorderStyle;
    FBorderColor: TNXColor;
    FontHeight, FontAscent, FontDescent, FontLineSkip: Integer;
    FontMonospace: Integer;
    ButtonStates: TNXMouseButtons;
    procedure SetWidth(NewWidth: integer); virtual;
    procedure SetHeight(NewHeight: integer); virtual;
    procedure SetSelected(NewState: Boolean); virtual;
    procedure SetCanvas(ACanvas: TNXCanvas); virtual;
    procedure PropagateParentContext; virtual;
    procedure AttachToParent(const AParent: INXControlParent); virtual;
    procedure BringToFront; virtual;
    procedure CaptureMouse; virtual;
    procedure ReleaseMouseCapture; virtual;
    function HasMouseCapture: Boolean; virtual;

    function GetAbsLeft: Integer; virtual;
    function GetAbsTop: Integer; virtual;
    function GetCanvas: TNXCanvas; virtual;
    function GetChildOriginX(AChild: TNXControl): Integer; virtual;
    function GetChildOriginY(AChild: TNXControl): Integer; virtual;
    function GetChildren: TNXControlList; virtual;
    function GetAbsContentRect: TNXRect; virtual;
    function GetBorderThickness: Integer; virtual;
    function GetContentRect: TNXRect; virtual;
    function GetFont: TNXFont; virtual;
    function GetFontForChildren: TNXFont; virtual;
    function GetHeight: Integer; virtual;
    function GetLeft: Integer; virtual;
    function GetPlatform: TNXPlatform; virtual;
    function GetSkin: TNXSkin; virtual;
    function GetTop: Integer; virtual;
    function GetWidth: Integer; virtual;
    procedure SetLeft(AValue: Integer); virtual;
    procedure SetTop(AValue: Integer); virtual;
    procedure SetBackColor(InColor: TNXColor);
    procedure SetBorderColor(InColor: TNXColor);
    procedure SetFont(AFont: TNXFont); virtual;
    procedure UpdateFontMetrics(AFont: TNXFont); virtual;

    procedure RenderRect(const Rect: TNXRect; Color: TNXColor); overload;
    procedure RenderFilledRect(const Rect: TNXRect; Color: TNXColor); overload;
    procedure RenderLine(x0, y0, x1, y1: Integer; Color: TNXColor);
    procedure RenderText(TextIn: string; x, y: Integer; Alignment: TTextAlign);
    procedure RenderClient; virtual;

    procedure DoMouseEnter; virtual;
    procedure DoMouseExit; virtual;
    procedure DoMouseDown(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure DoMouseUp(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure DoMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); virtual;
    procedure DoTextInput(const AText: string); virtual;
    procedure DoMouseClick(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure DoMouseDoubleClick(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure DoSelected; virtual;
    procedure DoLostSelected; virtual;
    procedure DoKeyDown(const AEvent: TNXKeyEventData); virtual;
    procedure DoKeyUp(const AEvent: TNXKeyEventData); virtual;
    procedure DoResize; virtual;
  public
    procedure SetParent(const AParent: INXControlParent); virtual;
    procedure Paint; virtual;
    procedure Render; virtual;
    procedure ctrl_FontChanged; virtual;
    constructor Create(const AParent: INXControlParent); overload; virtual;
    constructor Create(const AParent: INXControlParent; const ARect: TNXRect); overload; virtual;
    destructor Destroy; override;
    procedure AddChild(Child: TNXControl); virtual;
    procedure FreeChild(Child: TNXControl); virtual;
    procedure UnselectChildren; virtual;
    procedure ParentSizeCallback(NewW, NewH: Integer); virtual;
    procedure SendSizeCallback(NewW, NewH: Integer);
    procedure ChildAddedCallback; virtual;
    property MouseEntered: Boolean read FMouseEntered;
    function InControl(AX, AY: Integer): Boolean; virtual;

    procedure ProcessMouseEnter; virtual;
    procedure ProcessMouseExit; virtual;
    procedure ProcessMouseDown(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure ProcessMouseUp(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure ProcessMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); virtual;
    procedure ProcessTextInput(const AText: string); virtual;
    procedure ProcessMouseClick(X, Y: Integer; Button: TNXMouseButton); virtual;
    procedure ProcessSelected; virtual;
    procedure ProcessLostSelected; virtual;
    procedure ProcessKeyDown(const AEvent: TNXKeyEventData); virtual;
    procedure ProcessKeyUp(const AEvent: TNXKeyEventData); virtual;
    procedure ProcessResize; virtual;

    property AbsLeft: Integer read GetAbsLeft;
    property AbsContentRect: TNXRect read GetAbsContentRect;
    property AbsTop: Integer read GetAbsTop;
    property ActiveColor: TNXColor read FActiveColor write FActiveColor;
    property BackColor: TNXColor read FBackColor write SetBackColor;
    property BorderColor: TNXColor read FBorderColor write SetBorderColor;
    property BorderStyle: TBorderStyle read FBorderStyle write FBorderStyle;
    property Caption: string read FCaption write FCaption;
    property Children: TNXControlList read GetChildren;
    property ContentRect: TNXRect read GetContentRect;
    property Enabled: Boolean read FEnabled write FEnabled;
    property FillStyle: TFillStyle read FFillStyle write FFillStyle;
    property Font: TNXFont read GetFont write SetFont;
    property FontForChildren: TNXFont read GetFontForChildren;
    property ForeColor: TNXColor read FForeColor write FForeColor;
    property Height: Integer read FHeight write SetHeight;
    property Left: Integer read GetLeft write SetLeft;
    property OnKeyDown: TNXKeyEvent read FOnKeyDown write FOnKeyDown;
    property OnKeyUp: TNXKeyEvent read FOnKeyUp write FOnKeyUp;
    property OnLostSelected: TNotifyEvent read FOnLostSelected write FOnLostSelected;
    property OnMouseClick: TNXMouseEvent read FOnMouseClick write FOnMouseClick;
    property OnMouseDoubleClick: TNXMouseEvent read FOnMouseDoubleClick write FOnMouseDoubleClick;
    property OnMouseDown: TNXMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseEnter: TNotifyEvent read FOnMouseEnter write FOnMouseEnter;
    property OnMouseExit: TNotifyEvent read FOnMouseExit write FOnMouseExit;
    property OnMouseMotion: TNXMouseMotionEvent read FOnMouseMotion write FOnMouseMotion;
    property OnMouseUp: TNXMouseEvent read FOnMouseUp write FOnMouseUp;
    property OnResize: TNotifyEvent read FOnResize write FOnResize;
    property OnSelected: TNotifyEvent read FOnSelected write FOnSelected;
    property OnTextInput: TNXTextInputEvent read FOnTextInput write FOnTextInput;
    property Parent: INXControlParent read FParent;
    property ReceiveAllEvents: Boolean read FReceiveAllEvents write FReceiveAllEvents;
    property Canvas: TNXCanvas read GetCanvas write SetCanvas;
    property Selectable: Boolean read FSelectable write FSelectable;
    property IsSelected: Boolean read FCurSelected write SetSelected;
    property IsDestroying: Boolean read FDestroying;
    property Skin: TNXSkin read GetSkin;
    property SkinClass: string read FSkinClass write FSkinClass;
    property Top: Integer read GetTop write SetTop;
    property Visible: Boolean read FVisible write FVisible;
    property Width: Integer read FWidth write SetWidth;
  end;

function NXCapturedMouseControl: TNXControl;

implementation

uses
  obNXApplication;

var
  GCapturedMouseControl: TNXControl = nil;

const
  cDoubleClickMaxMS = 500;
  cDoubleClickMaxDistance = 4;

function NXCapturedMouseControl: TNXControl;
begin
  Result := GCapturedMouseControl;
end;

procedure TNXControl.AddChild(Child: TNXControl);
begin
  if not Assigned(Child) then
    Exit;

  if Children.IndexOf(Child) >= 0 then
  begin
    Exit;
  end;

  if Assigned(Child.Parent) then
    raise Exception.Create('Cannot add child that is already attached to another parent');

  Children.Add(Child);
  Child.SetParent(Self);
  Child.ChildAddedCallback;
end;

procedure TNXControl.FreeChild(Child: TNXControl);
var
  lIndex: Integer;
begin
  if FDestroying or (not Assigned(FChildren)) or (not Assigned(Child)) then
    Exit;

  lIndex := Children.IndexOf(Child);
  if lIndex < 0 then
    Exit;

  Children.Delete(lIndex);
end;

procedure TNXControl.SetParent(const AParent: INXControlParent);
begin
  FParent := AParent;
  if not Assigned(Parent) or not Assigned(Parent.Canvas) then
    Exit;

  SetCanvas(Parent.Canvas);
  ParentSizeCallback(Parent.Width, Parent.Height);
  PropagateParentContext;
end;

procedure TNXControl.PropagateParentContext;
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
  begin
    Children[lIndex].SetCanvas(Canvas);
    Children[lIndex].SetParent(INXControlParent(Self));
  end;
end;

procedure TNXControl.Paint;
var
  lClipRect: TNXRect;
  lIndex: Integer;
begin
  if Assigned(Canvas) and Visible then
  begin
    lClipRect.x := AbsLeft;
    lClipRect.y := AbsTop;
    lClipRect.w := Max(0, Width);
    lClipRect.h := Max(0, Height);

    Canvas.PushClip(lClipRect);
    try
      Render;

      for lIndex := 0 to Children.Count - 1 do
        Children[lIndex].Paint;
    finally
      Canvas.PopClip;
    end;
  end;
end;

procedure TNXControl.ParentSizeCallback(NewW, NewH: Integer);
begin

end;

procedure TNXControl.Render;
var
  lClipRect: TNXRect;
  lRect: TNXRect;
begin
  if not Visible then
    Exit;

  lRect := MakeNXRect(AbsLeft, AbsTop, Width, Height);

  case FFillStyle of
    FS_Filled:
      RenderFilledRect(lRect, CurFillColor);
    FS_None:
    begin
    end;
  end;

  lClipRect := AbsContentRect;
  Canvas.PushClip(lClipRect);
  try
    RenderClient;
  finally
    Canvas.PopClip;
  end;

  case FBorderStyle of
    BS_Single:
      RenderRect(lRect, CurBorderColor);
  end;
end;

procedure TNXControl.AttachToParent(const AParent: INXControlParent);
begin
  if Assigned(AParent) then
    AParent.AddChild(Self);
end;

constructor TNXControl.Create(const AParent: INXControlParent);
begin
  FChildren := TNXControlList.Create(True);
  FHeight := 50;
  FWidth := 50;
  FCanvas := nil;
  FHasLastClick := False;
  FLastClickButton := mbNone;
  FLastClickTicks := 0;
  FLastClickX := 0;
  FLastClickY := 0;
  ReceiveAllEvents := False;
  Selectable := True;
  Enabled := True;
  Visible := True;
  AttachToParent(AParent);
  ForeColor := Skin.ForeColor;
  BackColor := Skin.BackColor;
  Width := 256;
  Height := 256;
  BorderStyle := BS_None;
  BorderColor := Skin.BorderColor;
  ActiveColor := Skin.ActiveColor;
  FillStyle := FS_Filled;
  SkinClass := '';
end;

constructor TNXControl.Create(const AParent: INXControlParent; const ARect: TNXRect);
begin
  Create(AParent);
  Left := ARect.x;
  Top := ARect.y;
  Width := ARect.w;
  Height := ARect.h;
end;

destructor TNXControl.Destroy;
begin
  FDestroying := True;

  if GCapturedMouseControl = Self then
    GCapturedMouseControl := nil;

  FreeAndNil(FChildren);
  inherited Destroy;
end;

procedure TNXControl.CaptureMouse;
begin
  GCapturedMouseControl := Self;
end;

procedure TNXControl.ReleaseMouseCapture;
begin
  if GCapturedMouseControl = Self then
    GCapturedMouseControl := nil;
end;

function TNXControl.HasMouseCapture: Boolean;
begin
  Result := GCapturedMouseControl = Self;
end;

procedure TNXControl.SetWidth(NewWidth: integer);
begin
  FWidth := NewWidth;
  ProcessResize;
  SendSizeCallback(NewWidth, Height);
end;

procedure TNXControl.SetHeight(NewHeight: integer);
begin
  FHeight := NewHeight;
  ProcessResize;
  SendSizeCallback(Width, NewHeight);
end;

procedure TNXControl.SetCanvas(ACanvas: TNXCanvas);
begin
  FCanvas := ACanvas;
end;

function TNXControl.GetCanvas: TNXCanvas;
begin
  Result := FCanvas;
end;

procedure TNXControl.BringToFront;
var
  lIndex: Integer;
begin
  if not Assigned(Parent) then
    Exit;

  lIndex := Parent.Children.IndexOf(Self);
  if (lIndex >= 0) and (lIndex < Parent.Children.Count - 1) then
    Parent.Children.Move(lIndex, Parent.Children.Count - 1);
end;

function TNXControl.GetAbsLeft: integer;
begin
  if Parent = nil then
    Result := 0
  else
    Result := Parent.AbsLeft + Parent.GetChildOriginX(Self) + Left;
end;

function TNXControl.GetAbsTop: integer;
begin
  if Parent = nil then
    Result := 0
  else
    Result := Parent.AbsTop + Parent.GetChildOriginY(Self) + Top;
end;

function TNXControl.GetChildOriginX(AChild: TNXControl): Integer;
begin
  Result := 0;
end;

function TNXControl.GetChildOriginY(AChild: TNXControl): Integer;
begin
  Result := 0;
end;

function TNXControl.GetChildren: TNXControlList;
begin
  Result := FChildren;
end;

function TNXControl.GetAbsContentRect: TNXRect;
var
  lBorderThickness: Integer;
begin
  lBorderThickness := GetBorderThickness;
  Result := MakeNXRect(AbsLeft + lBorderThickness, AbsTop + lBorderThickness,
    Max(0, Width - (lBorderThickness * 2)),
    Max(0, Height - (lBorderThickness * 2)));
end;

function TNXControl.GetBorderThickness: Integer;
begin
  case FBorderStyle of
    BS_Single:
      Result := 1;
  else
    Result := 0;
  end;
end;

function TNXControl.GetContentRect: TNXRect;
var
  lBorderThickness: Integer;
begin
  lBorderThickness := GetBorderThickness;
  Result := MakeNXRect(lBorderThickness, lBorderThickness,
    Max(0, Width - (lBorderThickness * 2)),
    Max(0, Height - (lBorderThickness * 2)));
end;

function TNXControl.GetFont: TNXFont;
begin
  Result := FFont;

  if (Result = nil) and (Parent <> nil) then
    Result := Parent.FontForChildren;

  if FMetricFont <> Result then
    UpdateFontMetrics(Result);
end;

function TNXControl.GetFontForChildren: TNXFont;
begin
  Result := Font;
end;

function TNXControl.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TNXControl.GetLeft: Integer;
begin
  Result := FLeft;
end;

function TNXControl.GetPlatform: TNXPlatform;
begin
  Result := nil;
  if Assigned(Canvas) then
    Result := Canvas.Platform;
end;

function TNXControl.GetSkin: TNXSkin;
begin
  Result := nil;

  if Assigned(Parent) then
    Result := Parent.Skin
  else if Assigned(Application) then
    Result := Application.Skin;
end;

function TNXControl.GetTop: Integer;
begin
  Result := FTop;
end;

function TNXControl.GetWidth: Integer;
begin
  Result := FWidth;
end;

procedure TNXControl.SetLeft(AValue: Integer);
begin
  FLeft := AValue;
end;

procedure TNXControl.SetTop(AValue: Integer);
begin
  FTop := AValue;
end;

procedure TNXControl.SetBackColor(InColor: TNXColor);
begin
  FBackColor := InColor;
  CurFillColor := InColor;
end;

procedure TNXControl.SetBorderColor(InColor: TNXColor);
begin
  FBorderColor := InColor;
  CurBorderColor := InColor;
end;

procedure TNXControl.SetFont(AFont: TNXFont);
begin
  FFont := AFont;
  UpdateFontMetrics(Font);
  ctrl_FontChanged;
end;

procedure TNXControl.UpdateFontMetrics(AFont: TNXFont);
begin
  FMetricFont := AFont;

  if AFont = nil then
  begin
    FontHeight := 0;
    FontAscent := 0;
    FontDescent := 0;
    FontLineSkip := 0;
    FontMonospace := 0;
    Exit;
  end;

  FontHeight := AFont.Height;
  FontAscent := AFont.Ascent;
  FontDescent := AFont.Descent;
  FontLineSkip := AFont.LineSkip;
  FontMonospace := Ord(AFont.IsMonospace);
end;

procedure TNXControl.RenderRect(const Rect: TNXRect; Color: TNXColor);
begin
  Canvas.DrawRect(Rect, Color);
end;

procedure TNXControl.RenderFilledRect(const Rect: TNXRect; Color: TNXColor);
begin
  Canvas.FillRect(Rect, Color);
end;

procedure TNXControl.RenderLine(x0, y0, x1, y1: Integer; Color: TNXColor);
begin
  Canvas.DrawLine(x0, y0, x1, y1, Color);
end;

procedure TNXControl.RenderText(TextIn: string; x, y: Integer;
  Alignment: TTextAlign);
var
  lNXFont: TNXFont;
  lTextWidth: Integer;
  lTextX: Integer;
begin
  if TextIn = '' then
    Exit;

  lNXFont := Font;
  if not Assigned(lNXFont) then
    raise Exception.Create('RenderText called on [' + TextIn + '] but no Font Set');

  lTextWidth := Canvas.TextWidth(TextIn, lNXFont);

  case Alignment of
    Align_Left:
      lTextX := AbsLeft + x;
    Align_Center:
      lTextX := AbsLeft + x - (lTextWidth div 2);
    Align_Right:
      lTextX := AbsLeft + x - lTextWidth;
  end;

  Canvas.DrawText(TextIn, lTextX, AbsTop + y, FForeColor, lNXFont);
end;

procedure TNXControl.RenderClient;
begin
end;

procedure TNXControl.ctrl_FontChanged;
begin
end;

procedure TNXControl.SetSelected(NewState: Boolean);
begin
  if NewState then
  begin
    if (not FCurSelected) and Selectable then
    begin
      if Assigned(Parent) then
        Parent.UnSelectChildren;
      FCurSelected := True;
      ProcessSelected;
    end;
  end
  else
  begin
    if FCurSelected and Selectable then
    begin
      ProcessLostSelected;
      UnSelectChildren;
      FCurSelected := False;
    end;
  end;
end;

procedure TNXControl.UnselectChildren;
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    Children[lIndex].IsSelected := False;
end;

procedure TNXControl.SendSizeCallback(NewW, NewH: integer);
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    Children[lIndex].ParentSizeCallback(NewW, NewH);
end;

procedure TNXControl.ChildAddedCallback;
begin

end;

function TNXControl.InControl(AX, AY: Integer): Boolean;
var
  lIndex: Integer;
  lChild: TNXControl;
  lLocalX: Integer;
  lLocalY: Integer;
begin
  Result := (AX >= Left) and (AX < Left + Width) and
    (AY >= Top) and (AY < Top + Height);

  if not Result then
    Exit;

  lLocalX := AX - Left;
  lLocalY := AY - Top;

  for lIndex := Children.Count - 1 downto 0 do
  begin
    lChild := Children[lIndex];
    if lChild.Visible and lChild.InControl(
      lLocalX - GetChildOriginX(lChild),
      lLocalY - GetChildOriginY(lChild)
    ) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TNXControl.ProcessMouseEnter;
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].MouseEntered then
      Children[lIndex].ProcessMouseExit;

  if Assigned(Parent) then
    for lIndex := 0 to Parent.Children.Count - 1 do
      if Parent.Children[lIndex].MouseEntered then
        Parent.Children[lIndex].ProcessMouseExit;

  FMouseEntered := True;
  DoMouseEnter;
end;

procedure TNXControl.ProcessMouseExit;
var
  lIndex: Integer;
begin
  FMouseEntered := False;
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].MouseEntered then
      Children[lIndex].ProcessMouseExit;

  ButtonStates := [];

  DoMouseExit;
end;

procedure TNXControl.ProcessMouseDown(X, Y: integer; Button: TNXMouseButton);
var
  lIndex: Integer;
  lChild: TNXControl;
  lPassed: Boolean;
begin
  if Button = mbNone then
    Exit;

  lPassed := False;
  for lIndex := Children.Count - 1 downto 0 do
  begin
    if lPassed then
      Break;

    lChild := Children[lIndex];
    if lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) and lChild.Visible then
    begin
      lPassed := True;
      lChild.ProcessMouseDown(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top,
        Button
      );
      lChild.IsSelected := True;
    end;
  end;

  if (not lPassed) or ReceiveAllEvents then
  begin
    UnselectChildren;
    Include(ButtonStates, Button);
    DoMouseDown(X, Y, Button);
  end;
end;

procedure TNXControl.ProcessMouseUp(X, Y: integer; Button: TNXMouseButton);
var
  lIndex: Integer;
  lChild: TNXControl;
  lPassed: Boolean;
begin
  if Button = mbNone then
    Exit;

  if (Parent = nil) and Assigned(GCapturedMouseControl) and
    (GCapturedMouseControl <> Self) then
  begin
    GCapturedMouseControl.ProcessMouseUp(
      X - GCapturedMouseControl.AbsLeft,
      Y - GCapturedMouseControl.AbsTop,
      Button
    );
    Exit;
  end;

  lPassed := False;
  for lIndex := Children.Count - 1 downto 0 do
  begin
    if lPassed then
      Break;

    lChild := Children[lIndex];
    if lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) and lChild.Visible then
    begin
      lPassed := True;
      lChild.ProcessMouseUp(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top,
        Button
      );
    end;
  end;

  if (not lPassed) or ReceiveAllEvents then
    if Button in ButtonStates then
    begin
      DoMouseUp(X, Y, Button);
      ProcessMouseClick(X, Y, Button);
      Exclude(ButtonStates, Button);
    end
    else
      DoMouseUp(X, Y, Button);
end;

procedure TNXControl.ProcessMouseClick(X, Y: integer; Button: TNXMouseButton);
var
  lTicks: UInt32;
begin
  DoMouseClick(X, Y, Button);

  if Assigned(GetPlatform) then
    lTicks := GetPlatform.GetTicks
  else
    lTicks := 0;
  if FHasLastClick and (FLastClickButton = Button) and
    (lTicks - FLastClickTicks <= cDoubleClickMaxMS) and
    (Abs(X - FLastClickX) <= cDoubleClickMaxDistance) and
    (Abs(Y - FLastClickY) <= cDoubleClickMaxDistance) then
  begin
    FHasLastClick := False;
    DoMouseDoubleClick(X, Y, Button);
    Exit;
  end;

  FHasLastClick := True;
  FLastClickButton := Button;
  FLastClickTicks := lTicks;
  FLastClickX := X;
  FLastClickY := Y;
end;

procedure TNXControl.ProcessMouseMotion(X, Y: integer; ButtonState: TNXMouseButtons);
var
  lIndex: Integer;
  lChild: TNXControl;
  lPassed: Boolean;
begin
  if (Parent = nil) and Assigned(GCapturedMouseControl) and
    (GCapturedMouseControl <> Self) then
  begin
    GCapturedMouseControl.ProcessMouseMotion(
      X - GCapturedMouseControl.AbsLeft,
      Y - GCapturedMouseControl.AbsTop,
      ButtonState
    );
    Exit;
  end;

  lPassed := False;
  for lIndex := Children.Count - 1 downto 0 do
  begin
    if lPassed then
      Break;

    lChild := Children[lIndex];
    if lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) and lChild.Visible then
    begin
      lPassed := True;
      if not lChild.MouseEntered then
        lChild.ProcessMouseEnter;
      lChild.ProcessMouseMotion(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top,
        ButtonState
      );
    end
    else
    begin
      if lChild.MouseEntered then
        lChild.ProcessMouseExit;
    end;

  end;
  if not lPassed then
    DoMouseMotion(X, Y, ButtonState);
end;

procedure TNXControl.ProcessTextInput(const AText: string);
var
  lIndex: Integer;
begin
  DoTextInput(AText);

  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessTextInput(AText);
end;

procedure TNXControl.ProcessSelected;
begin
  DoSelected;
end;

procedure TNXControl.ProcessLostSelected;
begin
  DoLostSelected;
end;

procedure TNXControl.ProcessKeyDown(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
begin
  DoKeyDown(AEvent);
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessKeyDown(AEvent);
end;

procedure TNXControl.ProcessKeyUp(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
begin
  DoKeyUp(AEvent);
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessKeyUp(AEvent);
end;

procedure TNXControl.ProcessResize;
begin
  DoResize;
end;

procedure TNXControl.DoMouseEnter;
begin
  if Assigned(FOnMouseEnter) then
    FOnMouseEnter(Self);
end;

procedure TNXControl.DoMouseExit;
begin
  if Assigned(FOnMouseExit) then
    FOnMouseExit(Self);
end;

procedure TNXControl.DoMouseDown(X, Y: integer; Button: TNXMouseButton);
begin
  if Assigned(FOnMouseDown) then
    FOnMouseDown(Self, X, Y, Button);
end;

procedure TNXControl.DoMouseUp(X, Y: integer; Button: TNXMouseButton);
begin
  if Assigned(FOnMouseUp) then
    FOnMouseUp(Self, X, Y, Button);
end;

procedure TNXControl.DoMouseMotion(X, Y: integer; ButtonState: TNXMouseButtons);
begin
  if Assigned(FOnMouseMotion) then
    FOnMouseMotion(Self, X, Y, ButtonState);
end;

procedure TNXControl.DoTextInput(const AText: string);
begin
  if Assigned(FOnTextInput) then
    FOnTextInput(Self, AText);
end;

procedure TNXControl.DoMouseClick(X, Y: integer; Button: TNXMouseButton);
begin
  if Assigned(FOnMouseClick) then
    FOnMouseClick(Self, X, Y, Button);
end;

procedure TNXControl.DoMouseDoubleClick(X, Y: integer; Button: TNXMouseButton);
begin
  if Assigned(FOnMouseDoubleClick) then
    FOnMouseDoubleClick(Self, X, Y, Button);
end;

procedure TNXControl.DoSelected;
begin
  if Assigned(FOnSelected) then
    FOnSelected(Self);
end;

procedure TNXControl.DoLostSelected;
begin
  if Assigned(FOnLostSelected) then
    FOnLostSelected(Self);
end;

procedure TNXControl.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  if Assigned(FOnKeyDown) then
    FOnKeyDown(Self, AEvent);
end;

procedure TNXControl.DoKeyUp(const AEvent: TNXKeyEventData);
begin
  if Assigned(FOnKeyUp) then
    FOnKeyUp(Self, AEvent);
end;

procedure TNXControl.DoResize;
begin
  if Assigned(FOnResize) then
    FOnResize(Self);
end;

end.
