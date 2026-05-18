unit obNXElement;
{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Math, fgl, obNXCanvas, obNXFont, obNXSkin,
  tpNXEvents, tpNXPlatform, obNXPlatform;

type
  TNXElement = class;
  TNXElementList = specialize TFPGObjectList<TNXElement>;
  TNXMouseEvent = procedure(Sender: TObject; X, Y: Integer; Button: TNXMouseButton) of object;
  TNXMouseMotionEvent = procedure(Sender: TObject; X, Y: Integer; ButtonState: TNXMouseButtons) of object;
  TNXTextInputEvent = procedure(Sender: TObject; const AText: string) of object;
  TNXKeyEvent = procedure(Sender: TObject; const AEvent: TNXKeyEventData) of object;

  TNXElement = class
  private
    FChildren: TNXElementList;
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
    FParent: TNXElement;
  protected
    ButtonStates: TNXMouseButtons;
    procedure SetParent(NewParent: TNXElement); virtual;
    procedure SetWidth(NewWidth: integer); virtual;
    procedure SetHeight(NewHeight: integer); virtual;
    procedure SetSelected(NewState: Boolean); virtual;
    procedure SetCanvas(ACanvas: TNXCanvas); virtual;
    procedure PropagateParentContext; virtual;
    procedure AttachToParent(AParent: TNXElement); virtual;
    procedure BringToFront; virtual;
    procedure CaptureMouse; virtual;
    procedure ReleaseMouseCapture; virtual;
    function HasMouseCapture: Boolean; virtual;

    function GetAbsLeft: Integer; virtual;
    function GetAbsTop: Integer; virtual;
    function GetChildOriginX(AChild: TNXElement): Integer; virtual;
    function GetChildOriginY(AChild: TNXElement): Integer; virtual;
    function GetFontForChildren: TNXFont; virtual;
    function GetPlatform: TNXPlatform; virtual;
    function GetSkin: TNXSkin; virtual;

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
    procedure Paint; virtual;
    procedure Render; virtual;
    constructor Create(AParent: TNXElement); virtual;
    destructor Destroy; override;
    procedure AddChild(Child: TNXElement); virtual;
    procedure FreeChild(Child: TNXElement); virtual;
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
    property AbsTop: Integer read GetAbsTop;
    property Children: TNXElementList read FChildren;
    property Enabled: Boolean read FEnabled write FEnabled;
    property FontForChildren: TNXFont read GetFontForChildren;
    property Height: Integer read FHeight write SetHeight;
    property Left: Integer read FLeft write FLeft;
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
    property Parent: TNXElement read FParent;
    property ReceiveAllEvents: Boolean read FReceiveAllEvents write FReceiveAllEvents;
    property Canvas: TNXCanvas read FCanvas write SetCanvas;
    property Selectable: Boolean read FSelectable write FSelectable;
    property IsSelected: Boolean read FCurSelected write SetSelected;
    property IsDestroying: Boolean read FDestroying;
    property Skin: TNXSkin read GetSkin;
    property Top: Integer read FTop write FTop;
    property Visible: Boolean read FVisible write FVisible;
    property Width: Integer read FWidth write SetWidth;
  end;


implementation

uses
  obNXApplication;

var
  GCapturedMouseElement: TNXElement = nil;

const
  cDoubleClickMaxMS = 500;
  cDoubleClickMaxDistance = 4;

procedure TNXElement.AddChild(Child: TNXElement);
begin
  if not Assigned(Child) then
    Exit;

  if Child.Parent = Self then
  begin
    if Children.IndexOf(Child) < 0 then
    begin
      Children.Add(Child);
      Child.ChildAddedCallback;
    end;
    Exit;
  end;

  if Assigned(Child.Parent) then
    raise Exception.Create('Cannot add child that is already attached to another parent');

  Children.Add(Child);
  Child.SetParent(Self);
  Child.ChildAddedCallback;
end;

procedure TNXElement.FreeChild(Child: TNXElement);
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

procedure TNXElement.SetParent(NewParent: TNXElement);
begin
  FParent := NewParent;
  if not Assigned(Parent) or not Assigned(Parent.Canvas) then
    Exit;

  SetCanvas(Parent.Canvas);
  ParentSizeCallback(Parent.Width, Parent.Height);
  PropagateParentContext;
end;

procedure TNXElement.PropagateParentContext;
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
  begin
    Children[lIndex].SetCanvas(Canvas);
    Children[lIndex].SetParent(Self);
  end;
end;

procedure TNXElement.Paint;
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

procedure TNXElement.ParentSizeCallback(NewW, NewH: Integer);
begin

end;

procedure TNXElement.Render;
begin
end;

procedure TNXElement.AttachToParent(AParent: TNXElement);
begin
  if Assigned(AParent) then
    AParent.AddChild(Self);
end;

constructor TNXElement.Create(AParent: TNXElement);
begin
  FChildren := TNXElementList.Create(True);
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
end;

destructor TNXElement.Destroy;
begin
  FDestroying := True;

  if GCapturedMouseElement = Self then
    GCapturedMouseElement := nil;

  FreeAndNil(FChildren);
  inherited Destroy;
end;

procedure TNXElement.CaptureMouse;
begin
  GCapturedMouseElement := Self;
end;

procedure TNXElement.ReleaseMouseCapture;
begin
  if GCapturedMouseElement = Self then
    GCapturedMouseElement := nil;
end;

function TNXElement.HasMouseCapture: Boolean;
begin
  Result := GCapturedMouseElement = Self;
end;

procedure TNXElement.SetWidth(NewWidth: integer);
begin
  FWidth := NewWidth;
  ProcessResize;
  SendSizeCallback(NewWidth, Height);
end;

procedure TNXElement.SetHeight(NewHeight: integer);
begin
  FHeight := NewHeight;
  ProcessResize;
  SendSizeCallback(Width, NewHeight);
end;

procedure TNXElement.SetCanvas(ACanvas: TNXCanvas);
begin
  FCanvas := ACanvas;
end;

procedure TNXElement.BringToFront;
var
  lIndex: Integer;
begin
  if not Assigned(Parent) then
    Exit;

  lIndex := Parent.Children.IndexOf(Self);
  if (lIndex >= 0) and (lIndex < Parent.Children.Count - 1) then
    Parent.Children.Move(lIndex, Parent.Children.Count - 1);
end;

function TNXElement.GetAbsLeft: integer;
begin
  if Parent = nil then
    Result := 0
  else
    Result := Parent.AbsLeft + Parent.GetChildOriginX(Self) + Left;
end;

function TNXElement.GetAbsTop: integer;
begin
  if Parent = nil then
    Result := 0
  else
    Result := Parent.AbsTop + Parent.GetChildOriginY(Self) + Top;
end;

function TNXElement.GetChildOriginX(AChild: TNXElement): Integer;
begin
  Result := 0;
end;

function TNXElement.GetChildOriginY(AChild: TNXElement): Integer;
begin
  Result := 0;
end;

function TNXElement.GetFontForChildren: TNXFont;
begin
  Result := nil;
end;

function TNXElement.GetPlatform: TNXPlatform;
begin
  Result := nil;
  if Assigned(Canvas) then
    Result := Canvas.Platform;
end;

function TNXElement.GetSkin: TNXSkin;
begin
  Result := nil;

  if Assigned(Parent) then
    Result := Parent.Skin
  else if Assigned(Application) then
    Result := Application.Skin;
end;

procedure TNXElement.SetSelected(NewState: Boolean);
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

procedure TNXElement.UnselectChildren;
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    Children[lIndex].IsSelected := False;
end;

procedure TNXElement.SendSizeCallback(NewW, NewH: integer);
var
  lIndex: Integer;
begin
  for lIndex := 0 to Children.Count - 1 do
    Children[lIndex].ParentSizeCallback(NewW, NewH);
end;

procedure TNXElement.ChildAddedCallback;
begin

end;

function TNXElement.InControl(AX, AY: Integer): Boolean;
var
  lIndex: Integer;
  lChild: TNXElement;
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

procedure TNXElement.ProcessMouseEnter;
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

procedure TNXElement.ProcessMouseExit;
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

procedure TNXElement.ProcessMouseDown(X, Y: integer; Button: TNXMouseButton);
var
  lIndex: Integer;
  lChild: TNXElement;
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

procedure TNXElement.ProcessMouseUp(X, Y: integer; Button: TNXMouseButton);
var
  lIndex: Integer;
  lChild: TNXElement;
  lPassed: Boolean;
begin
  if Button = mbNone then
    Exit;

  if (Parent = nil) and Assigned(GCapturedMouseElement) and
    (GCapturedMouseElement <> Self) then
  begin
    GCapturedMouseElement.ProcessMouseUp(
      X - GCapturedMouseElement.AbsLeft,
      Y - GCapturedMouseElement.AbsTop,
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

procedure TNXElement.ProcessMouseClick(X, Y: integer; Button: TNXMouseButton);
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

procedure TNXElement.ProcessMouseMotion(X, Y: integer; ButtonState: TNXMouseButtons);
var
  lIndex: Integer;
  lChild: TNXElement;
  lPassed: Boolean;
begin
  if (Parent = nil) and Assigned(GCapturedMouseElement) and
    (GCapturedMouseElement <> Self) then
  begin
    GCapturedMouseElement.ProcessMouseMotion(
      X - GCapturedMouseElement.AbsLeft,
      Y - GCapturedMouseElement.AbsTop,
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

procedure TNXElement.ProcessTextInput(const AText: string);
var
  lIndex: Integer;
begin
  DoTextInput(AText);

  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessTextInput(AText);
end;

procedure TNXElement.ProcessSelected;
begin
  DoSelected;
end;

procedure TNXElement.ProcessLostSelected;
begin
  DoLostSelected;
end;

procedure TNXElement.ProcessKeyDown(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
begin
  DoKeyDown(AEvent);
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessKeyDown(AEvent);
end;

procedure TNXElement.ProcessKeyUp(const AEvent: TNXKeyEventData);
var
  lIndex: Integer;
begin
  DoKeyUp(AEvent);
  for lIndex := 0 to Children.Count - 1 do
    if Children[lIndex].IsSelected then
      Children[lIndex].ProcessKeyUp(AEvent);
end;

procedure TNXElement.ProcessResize;
begin
  DoResize;
end;

procedure TNXElement.DoMouseEnter;
begin
  if Assigned(FOnMouseEnter) then
    FOnMouseEnter(Self);
end;

procedure TNXElement.DoMouseExit;
begin
  if Assigned(FOnMouseExit) then
    FOnMouseExit(Self);
end;

procedure TNXElement.DoMouseDown(X, Y: integer; Button: TNXMouseButton);
begin
  if Assigned(FOnMouseDown) then
    FOnMouseDown(Self, X, Y, Button);
end;

procedure TNXElement.DoMouseUp(X, Y: integer; Button: TNXMouseButton);
begin
  if Assigned(FOnMouseUp) then
    FOnMouseUp(Self, X, Y, Button);
end;

procedure TNXElement.DoMouseMotion(X, Y: integer; ButtonState: TNXMouseButtons);
begin
  if Assigned(FOnMouseMotion) then
    FOnMouseMotion(Self, X, Y, ButtonState);
end;

procedure TNXElement.DoTextInput(const AText: string);
begin
  if Assigned(FOnTextInput) then
    FOnTextInput(Self, AText);
end;

procedure TNXElement.DoMouseClick(X, Y: integer; Button: TNXMouseButton);
begin
  if Assigned(FOnMouseClick) then
    FOnMouseClick(Self, X, Y, Button);
end;

procedure TNXElement.DoMouseDoubleClick(X, Y: integer; Button: TNXMouseButton);
begin
  if Assigned(FOnMouseDoubleClick) then
    FOnMouseDoubleClick(Self, X, Y, Button);
end;

procedure TNXElement.DoSelected;
begin
  if Assigned(FOnSelected) then
    FOnSelected(Self);
end;

procedure TNXElement.DoLostSelected;
begin
  if Assigned(FOnLostSelected) then
    FOnLostSelected(Self);
end;

procedure TNXElement.DoKeyDown(const AEvent: TNXKeyEventData);
begin
  if Assigned(FOnKeyDown) then
    FOnKeyDown(Self, AEvent);
end;

procedure TNXElement.DoKeyUp(const AEvent: TNXKeyEventData);
begin
  if Assigned(FOnKeyUp) then
    FOnKeyUp(Self, AEvent);
end;

procedure TNXElement.DoResize;
begin
  if Assigned(FOnResize) then
    FOnResize(Self);
end;

end.
