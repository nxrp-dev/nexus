unit obNXMaster;
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  tpNXEvents,
  obNXElement,
  obNXFont,
  obNXPopup,
  obNXWindow;

type
  TNXMaster = class(TNXElement)
  private
    FFont: TNXFont;
    FPopups: TNXPopupManager;
    FWindows: TNXWindowManager;
    procedure SetMasterSize(AWidth, AHeight: Integer);
  protected
    function GetFontForChildren: TNXFont; override;
  public
    constructor Create(AParent: TNXElement); overload; override;
    destructor Destroy; override;

    procedure SetParent(NewParent: TNXElement); override;
    procedure SetWidth(AWidth: Integer); override;
    procedure SetHeight(AHeight: Integer); override;

    procedure Render; override;

    procedure InjectNXEvent(const AEvent: TNXEvent);
    procedure ResizeToWindow;

    property Font: TNXFont read FFont write FFont;
    property Popups: TNXPopupManager read FPopups;
    property Windows: TNXWindowManager read FWindows;
  end;

implementation

uses
  obNXApplication;

constructor TNXMaster.Create(AParent: TNXElement);
begin
  inherited Create(AParent);
  FPopups := TNXPopupManager.Create(Self);
  FWindows := TNXWindowManager.Create(Self);
  Visible := True;

  Application.Platform.StopTextInput;
end;

destructor TNXMaster.Destroy;
begin
  FreeAndNil(FWindows);
  FreeAndNil(FPopups);
  inherited Destroy;
end;

procedure TNXMaster.Render;
begin
  Canvas.Clear(Skin.FormBackColor);
end;

procedure TNXMaster.SetMasterSize(AWidth, AHeight: Integer);
begin
  inherited SetWidth(AWidth);
  inherited SetHeight(AHeight);
end;

procedure TNXMaster.SetParent(NewParent: TNXElement);
begin
  raise Exception.Create('SetParent called in TNXMaster');
end;

function TNXMaster.GetFontForChildren: TNXFont;
begin
  Result := FFont;
end;

procedure TNXMaster.SetWidth(AWidth: Integer);
begin
  raise Exception.Create('SetWidth called in TNXMaster');
end;

procedure TNXMaster.SetHeight(AHeight: Integer);
begin
  raise Exception.Create('SetHeight called in TNXMaster');
end;

procedure TNXMaster.ResizeToWindow;
var
  lHeight: Integer;
  lWidth: Integer;
begin
  if (not Assigned(Canvas)) or (not Assigned(Canvas.Platform)) then
  begin
    SetMasterSize(0, 0);
    Exit;
  end;

  Canvas.Platform.GetDisplaySize(lWidth, lHeight);
  SetMasterSize(lWidth, lHeight);
end;

procedure TNXMaster.InjectNXEvent(const AEvent: TNXEvent);
begin
  case AEvent.EventType of
    nxeKeyDown:
      if not Windows.ProcessKeyDown(AEvent.Key) then
        ProcessKeyDown(AEvent.Key);

    nxeKeyUp:
      if not Windows.ProcessKeyUp(AEvent.Key) then
        ProcessKeyUp(AEvent.Key);

    nxeMouseMotion:
      if not Windows.ProcessMouseMotion(AEvent.Mouse.X, AEvent.Mouse.Y,
        AEvent.Mouse.ButtonState) then
        ProcessMouseMotion(AEvent.Mouse.X, AEvent.Mouse.Y,
          AEvent.Mouse.ButtonState);

    nxeMouseDown:
    begin
      if not Windows.ProcessMouseDown(AEvent.Mouse.X, AEvent.Mouse.Y,
        AEvent.Mouse.Button) then
      begin
        Popups.ProcessMouseDown(AEvent.Mouse.X, AEvent.Mouse.Y,
          AEvent.Mouse.Button);
        ProcessMouseDown(AEvent.Mouse.X, AEvent.Mouse.Y,
          AEvent.Mouse.Button);
        Popups.BringActiveToFront;
      end;
    end;

    nxeMouseUp:
      if not Windows.ProcessMouseUp(AEvent.Mouse.X, AEvent.Mouse.Y,
        AEvent.Mouse.Button) then
        ProcessMouseUp(AEvent.Mouse.X, AEvent.Mouse.Y,
          AEvent.Mouse.Button);

    nxeTextInput:
      if not Windows.ProcessTextInput(AEvent.Text) then
        ProcessTextInput(AEvent.Text);
  end;
end;

end.
