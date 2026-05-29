unit obNXPopup;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXControl,

  tpNXEvents,
  tpNXPlatform;

type
  TNXPopupManager = class;

  TNXPopup = class(TNXControl)
  private
    FFocusedControl: TNXControl;
    FManager: TNXPopupManager;
    FOwner: TNXControl;
    procedure CloseInternal;
  protected
    function AcceptsTabFocus(AControl: TNXControl): Boolean; virtual;
    procedure ClearFocus; virtual;
    procedure CollectTabControls(AHost: TNXControlHost; AList: TList); virtual;
    function CompareTabControls(ALeft, ARight: TNXControl): Integer; virtual;
    procedure DoClosed; virtual;
    procedure DoOpened; virtual;
    procedure SetFocusedControl(AControl: TNXControl); virtual;
    procedure SortTabControls(AList: TList); virtual;
  public
    constructor Create(const AParent: INXControlParent; AOwner: TNXControl); reintroduce; virtual;
    destructor Destroy; override;
    procedure ChildDestroying(AChild: TNXControl); override;
    procedure Close; virtual;
    procedure FocusChild(AChild: TNXControl); override;
    procedure FocusNextControl(AReverse: Boolean); virtual;
    procedure Open; virtual;
    procedure ProcessKeyDown(const AEvent: TNXKeyEventData); override;
    procedure ProcessKeyUp(const AEvent: TNXKeyEventData); override;
    procedure ProcessMouseDown(X, Y: Integer; Button: TNXMouseButton); override;
    procedure ProcessMouseMotion(X, Y: Integer; ButtonState: TNXMouseButtons); override;
    procedure ProcessMouseUp(X, Y: Integer; Button: TNXMouseButton); override;
    procedure ProcessTextInput(const AText: string); override;
    procedure SetAbsoluteBounds(ALeft, ATop, AWidth, AHeight: Integer); virtual;
    procedure SetAbsolutePosition(ALeft, ATop: Integer); virtual;

    property FocusedControl: TNXControl read FFocusedControl;
    property Owner: TNXControl read FOwner;
  end;

  TNXPopupManager = class
  private
    FActivePopup: TNXPopup;
    FHost: INXControlParent;

    procedure ForgetPopup(APopup: TNXPopup);
    function PointInElement(AElement: TNXControl; AX, AY: Integer): Boolean;
  public
    constructor Create(const AHost: INXControlParent);
    procedure BringActiveToFront;
    procedure HidePopup(APopup: TNXPopup);
    procedure HidePopups;
    function ProcessKeyDown(const AEvent: TNXKeyEventData): Boolean;
    function ProcessKeyUp(const AEvent: TNXKeyEventData): Boolean;
    function ProcessMouseDown(AX, AY: Integer; AButton: TNXMouseButton): Boolean;
    function ProcessMouseMotion(AX, AY: Integer; AButtonState: TNXMouseButtons): Boolean;
    function ProcessMouseUp(AX, AY: Integer; AButton: TNXMouseButton): Boolean;
    function ProcessMouseWheel(AX, AY, ADeltaX, ADeltaY: Integer): Boolean;
    function ProcessTextInput(const AText: string): Boolean;
    procedure ShowPopup(APopup: TNXPopup);

    property ActivePopup: TNXPopup read FActivePopup;
  end;

implementation

constructor TNXPopup.Create(const AParent: INXControlParent; AOwner: TNXControl);
begin
  inherited Create(AParent);
  FFocusedControl := nil;
  FManager := nil;
  FOwner := AOwner;
  BorderStyle := BS_Single;
  CanFocus := False;
  Visible := False;
end;

destructor TNXPopup.Destroy;
begin
  if Assigned(FManager) then
    FManager.ForgetPopup(Self);

  inherited Destroy;
end;

procedure TNXPopup.CloseInternal;
begin
  if not Visible then
    Exit;

  Visible := False;
  ClearFocus;
  DoClosed;
end;

function TNXPopup.AcceptsTabFocus(AControl: TNXControl): Boolean;
begin
  Result := Assigned(AControl) and AControl.Visible and AControl.Enabled and
    AControl.CanFocus and AControl.TabStop and (AControl <> Self);
end;

procedure TNXPopup.ClearFocus;
begin
  SetFocusedControl(nil);
end;

procedure TNXPopup.CollectTabControls(AHost: TNXControlHost; AList: TList);
var
  lChild: TNXControl;
  lChildren: TList;
  lIndex: Integer;
begin
  if (not Assigned(AHost)) or (not Assigned(AList)) then
    Exit;

  lChildren := TList.Create;
  try
    for lIndex := 0 to AHost.Children.Count - 1 do
    begin
      lChild := AHost.Children[lIndex];
      if lChild.Visible and lChild.Enabled then
        lChildren.Add(lChild);
    end;

    SortTabControls(lChildren);

    for lIndex := 0 to lChildren.Count - 1 do
    begin
      lChild := TNXControl(lChildren[lIndex]);
      if AcceptsTabFocus(lChild) then
        AList.Add(lChild);
      CollectTabControls(lChild, AList);
    end;
  finally
    lChildren.Free;
  end;
end;

function TNXPopup.CompareTabControls(ALeft, ARight: TNXControl): Integer;
begin
  Result := 0;
  if ALeft.AbsTop < ARight.AbsTop then
    Result := -1
  else if ALeft.AbsTop > ARight.AbsTop then
    Result := 1
  else if ALeft.AbsLeft < ARight.AbsLeft then
    Result := -1
  else if ALeft.AbsLeft > ARight.AbsLeft then
    Result := 1;
end;

procedure TNXPopup.SetFocusedControl(AControl: TNXControl);
begin
  if Assigned(AControl) and
    ((AControl = Self) or (not AControl.CanFocus) or (not AControl.Enabled)) then
    AControl := nil;

  if FFocusedControl = AControl then
    Exit;

  if Assigned(FFocusedControl) then
    FFocusedControl.IsFocused := False;

  FFocusedControl := AControl;

  if Assigned(FFocusedControl) then
    FFocusedControl.IsFocused := True;
end;

procedure TNXPopup.SortTabControls(AList: TList);
var
  lIndex: Integer;
  lInsertIndex: Integer;
  lValue: Pointer;
begin
  if not Assigned(AList) then
    Exit;

  for lIndex := 1 to AList.Count - 1 do
  begin
    lValue := AList[lIndex];
    lInsertIndex := lIndex - 1;

    while (lInsertIndex >= 0) and
      (CompareTabControls(TNXControl(AList[lInsertIndex]),
        TNXControl(lValue)) > 0) do
    begin
      AList[lInsertIndex + 1] := AList[lInsertIndex];
      Dec(lInsertIndex);
    end;

    AList[lInsertIndex + 1] := lValue;
  end;
end;

procedure TNXPopup.ChildDestroying(AChild: TNXControl);
begin
  if FFocusedControl = AChild then
    FFocusedControl := nil;

  inherited ChildDestroying(AChild);
end;

procedure TNXPopup.Close;
begin
  if Assigned(FManager) then
    FManager.HidePopup(Self)
  else
    CloseInternal;
end;

procedure TNXPopup.FocusChild(AChild: TNXControl);
begin
  SetFocusedControl(AChild);
end;

procedure TNXPopup.FocusNextControl(AReverse: Boolean);
var
  lControls: TList;
  lCurrentIndex: Integer;
  lNextIndex: Integer;
begin
  lControls := TList.Create;
  try
    CollectTabControls(Self, lControls);
    if lControls.Count = 0 then
    begin
      ClearFocus;
      Exit;
    end;

    lCurrentIndex := lControls.IndexOf(FFocusedControl);
    if lCurrentIndex < 0 then
    begin
      if AReverse then
        lNextIndex := lControls.Count - 1
      else
        lNextIndex := 0;
    end
    else if AReverse then
      lNextIndex := (lCurrentIndex + lControls.Count - 1) mod lControls.Count
    else
      lNextIndex := (lCurrentIndex + 1) mod lControls.Count;

    SetFocusedControl(TNXControl(lControls[lNextIndex]));
  finally
    lControls.Free;
  end;
end;

procedure TNXPopup.Open;
begin
  if Visible then
    Exit;

  Visible := True;
  DoOpened;
end;

procedure TNXPopup.DoClosed;
begin
end;

procedure TNXPopup.DoOpened;
begin
end;

procedure TNXPopup.ProcessKeyDown(const AEvent: TNXKeyEventData);
begin
  if AEvent.Key = nkTab then
  begin
    FocusNextControl(nmShift in AEvent.Modifiers);
    Exit;
  end;

  if AEvent.Key = nkEscape then
  begin
    inherited ProcessKeyDown(AEvent);
    Exit;
  end;

  if Assigned(FFocusedControl) and FFocusedControl.Visible and
    FFocusedControl.Enabled then
    FFocusedControl.ProcessKeyDown(AEvent)
  else
    inherited ProcessKeyDown(AEvent);
end;

procedure TNXPopup.ProcessKeyUp(const AEvent: TNXKeyEventData);
begin
  if Assigned(FFocusedControl) and FFocusedControl.Visible and
    FFocusedControl.Enabled then
    FFocusedControl.ProcessKeyUp(AEvent)
  else
    inherited ProcessKeyUp(AEvent);
end;

procedure TNXPopup.ProcessMouseDown(X, Y: Integer; Button: TNXMouseButton);
var
  lChild: TNXControl;
  lFocusControl: TNXControl;
  lIndex: Integer;
begin
  if Button = mbNone then
    Exit;

  for lIndex := Children.Count - 1 downto 0 do
  begin
    lChild := Children[lIndex];
    if lChild.Visible and lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) then
    begin
      lFocusControl := lChild.FindFocusableControlAt(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top
      );
      SetFocusedControl(lFocusControl);
      lChild.ProcessMouseDown(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top,
        Button
      );
      Exit;
    end;
  end;

  ClearFocus;
end;

procedure TNXPopup.ProcessMouseMotion(X, Y: Integer;
  ButtonState: TNXMouseButtons);
var
  lCapturedControl: TNXControl;
  lChild: TNXControl;
  lIndex: Integer;
  lPassed: Boolean;
  lPoint: TNXPoint;
begin
  lCapturedControl := NXCapturedMouseControl;
  if Assigned(lCapturedControl) then
  begin
    lPoint := LocalToScreen(X, Y);
    lPoint := lCapturedControl.ScreenToLocal(lPoint.x, lPoint.y);
    lCapturedControl.ProcessMouseMotion(
      lPoint.x,
      lPoint.y,
      ButtonState
    );
    Exit;
  end;

  lPassed := False;
  for lIndex := Children.Count - 1 downto 0 do
  begin
    lChild := Children[lIndex];
    if lChild.Visible and lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) then
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
    else if lChild.MouseEntered then
      lChild.ProcessMouseExit;

    if lPassed then
      Break;
  end;
end;

procedure TNXPopup.ProcessMouseUp(X, Y: Integer; Button: TNXMouseButton);
var
  lCapturedControl: TNXControl;
  lChild: TNXControl;
  lIndex: Integer;
  lPoint: TNXPoint;
begin
  if Button = mbNone then
    Exit;

  lCapturedControl := NXCapturedMouseControl;
  if Assigned(lCapturedControl) then
  begin
    lPoint := LocalToScreen(X, Y);
    lPoint := lCapturedControl.ScreenToLocal(lPoint.x, lPoint.y);
    lCapturedControl.ProcessMouseUp(
      lPoint.x,
      lPoint.y,
      Button
    );
    Exit;
  end;

  for lIndex := Children.Count - 1 downto 0 do
  begin
    lChild := Children[lIndex];
    if lChild.Visible and lChild.InControl(
      X - GetChildOriginX(lChild),
      Y - GetChildOriginY(lChild)
    ) then
    begin
      lChild.ProcessMouseUp(
        X - GetChildOriginX(lChild) - lChild.Left,
        Y - GetChildOriginY(lChild) - lChild.Top,
        Button
      );
      Exit;
    end;
  end;
end;

procedure TNXPopup.ProcessTextInput(const AText: string);
begin
  if Assigned(FFocusedControl) and FFocusedControl.Visible and
    FFocusedControl.Enabled then
    FFocusedControl.ProcessTextInput(AText)
  else
    inherited ProcessTextInput(AText);
end;

procedure TNXPopup.SetAbsoluteBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  Width := AWidth;
  Height := AHeight;
  SetAbsolutePosition(ALeft, ATop);
end;

procedure TNXPopup.SetAbsolutePosition(ALeft, ATop: Integer);
var
  lPoint: TNXPoint;
begin
  if Assigned(Parent) then
  begin
    lPoint := Parent.ScreenToLocal(ALeft, ATop);
    Left := lPoint.x - Parent.GetChildOriginX(Self);
    Top := lPoint.y - Parent.GetChildOriginY(Self);
  end
  else
  begin
    Left := ALeft;
    Top := ATop;
  end;
end;

constructor TNXPopupManager.Create(const AHost: INXControlParent);
begin
  inherited Create;
  FHost := AHost;
  FActivePopup := nil;
end;

procedure TNXPopupManager.BringActiveToFront;
var
  lIndex: Integer;
begin
  if not Assigned(FHost) or not Assigned(FActivePopup) then
    Exit;

  lIndex := FHost.Children.IndexOf(FActivePopup);
  if (lIndex >= 0) and (lIndex < FHost.Children.Count - 1) then
    FHost.Children.Move(lIndex, FHost.Children.Count - 1);
end;

function TNXPopupManager.PointInElement(AElement: TNXControl; AX,
  AY: Integer): Boolean;
begin
  Result := Assigned(AElement) and AElement.Visible and
    AElement.ContainsScreenPoint(AX, AY);
end;

procedure TNXPopupManager.ForgetPopup(APopup: TNXPopup);
begin
  if not Assigned(APopup) then
    Exit;

  if FActivePopup = APopup then
    FActivePopup := nil;

  if APopup.FManager = Self then
    APopup.FManager := nil;
end;

procedure TNXPopupManager.HidePopup(APopup: TNXPopup);
begin
  if not Assigned(APopup) then
    Exit;

  if FActivePopup = APopup then
    FActivePopup := nil;

  APopup.CloseInternal;
end;

procedure TNXPopupManager.HidePopups;
begin
  HidePopup(FActivePopup);
end;

function TNXPopupManager.ProcessKeyDown(const AEvent: TNXKeyEventData): Boolean;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if (AEvent.Key = nkEscape) and (not FActivePopup.CanFocus) then
  begin
    HidePopup(FActivePopup);
    Exit;
  end;

  if FActivePopup.CanFocus then
    FActivePopup.ProcessKeyDown(AEvent)
  else if Assigned(FActivePopup.Owner) then
    FActivePopup.Owner.ProcessKeyDown(AEvent);
end;

function TNXPopupManager.ProcessKeyUp(const AEvent: TNXKeyEventData): Boolean;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if FActivePopup.CanFocus then
    FActivePopup.ProcessKeyUp(AEvent)
  else if Assigned(FActivePopup.Owner) then
    FActivePopup.Owner.ProcessKeyUp(AEvent);
end;

function TNXPopupManager.ProcessMouseDown(AX, AY: Integer;
  AButton: TNXMouseButton): Boolean;
var
  lPoint: TNXPoint;
begin
  Result := False;
  if AButton = mbNone then
    Exit;

  if not Assigned(FActivePopup) or not FActivePopup.Visible then
    Exit;

  if PointInElement(FActivePopup, AX, AY) then
  begin
    lPoint := FActivePopup.ScreenToLocal(AX, AY);
    FActivePopup.ProcessMouseDown(lPoint.x, lPoint.y, AButton);
    Result := True;
    Exit;
  end;

  if PointInElement(FActivePopup.Owner, AX, AY) then
    Exit;

  HidePopup(FActivePopup);
end;

function TNXPopupManager.ProcessMouseMotion(AX, AY: Integer;
  AButtonState: TNXMouseButtons): Boolean;
var
  lPoint: TNXPoint;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if PointInElement(FActivePopup, AX, AY) then
  begin
    if not FActivePopup.MouseEntered then
      FActivePopup.ProcessMouseEnter;

    lPoint := FActivePopup.ScreenToLocal(AX, AY);
    FActivePopup.ProcessMouseMotion(lPoint.x, lPoint.y, AButtonState);
    Exit;
  end;

  if FActivePopup.MouseEntered then
    FActivePopup.ProcessMouseExit;

  Result := False;
end;

function TNXPopupManager.ProcessMouseUp(AX, AY: Integer;
  AButton: TNXMouseButton): Boolean;
var
  lPoint: TNXPoint;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if PointInElement(FActivePopup, AX, AY) then
  begin
    lPoint := FActivePopup.ScreenToLocal(AX, AY);
    FActivePopup.ProcessMouseUp(lPoint.x, lPoint.y, AButton);
    Exit;
  end;

  Result := False;
end;

function TNXPopupManager.ProcessMouseWheel(AX, AY, ADeltaX,
  ADeltaY: Integer): Boolean;
var
  lPoint: TNXPoint;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if PointInElement(FActivePopup, AX, AY) then
  begin
    lPoint := FActivePopup.ScreenToLocal(AX, AY);
    FActivePopup.ProcessMouseWheel(lPoint.x, lPoint.y, ADeltaX, ADeltaY);
    Exit;
  end;

  Result := False;
end;

function TNXPopupManager.ProcessTextInput(const AText: string): Boolean;
begin
  Result := Assigned(FActivePopup) and FActivePopup.Visible;
  if not Result then
    Exit;

  if FActivePopup.CanFocus then
    FActivePopup.ProcessTextInput(AText)
  else if Assigned(FActivePopup.Owner) then
    FActivePopup.Owner.ProcessTextInput(AText);
end;

procedure TNXPopupManager.ShowPopup(APopup: TNXPopup);
begin
  if not Assigned(APopup) then
    Exit;

  if Assigned(FActivePopup) and (FActivePopup <> APopup) then
    HidePopup(FActivePopup);

  FActivePopup := APopup;
  APopup.FManager := Self;
  BringActiveToFront;
  APopup.Open;
end;

end.
