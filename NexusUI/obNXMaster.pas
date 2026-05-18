unit obNXMaster;
{$mode objfpc}{$H+}

interface

uses
  SysUtils, tpNXEvents, obNXElement, obNXFont, obNXPopup;

type
  TGUI_Master = class(TNXElement)
  private
    FFont: TNXFont;
    FPopups: TNXPopupManager;
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
  end;

implementation

uses
  obNXApplication;

constructor TGUI_Master.Create(AParent: TNXElement);
begin
  inherited Create(AParent);
  FPopups := TNXPopupManager.Create(Self);
  Visible := True;

  Application.Platform.StopTextInput;
end;

destructor TGUI_Master.Destroy;
begin
  FreeAndNil(FPopups);
  inherited Destroy;
end;

procedure TGUI_Master.Render;
begin
  Canvas.Clear(Skin.FormBackColor);
end;

procedure TGUI_Master.SetMasterSize(AWidth, AHeight: Integer);
begin
  inherited SetWidth(AWidth);
  inherited SetHeight(AHeight);
end;

procedure TGUI_Master.SetParent(NewParent: TNXElement);
begin
  raise Exception.Create('SetParent called in TGUI_Master');
end;

function TGUI_Master.GetFontForChildren: TNXFont;
begin
  Result := FFont;
end;

procedure TGUI_Master.SetWidth(AWidth: Integer);
begin
  raise Exception.Create('SetWidth called in TGUI_Master');
end;

procedure TGUI_Master.SetHeight(AHeight: Integer);
begin
  raise Exception.Create('SetHeight called in TGUI_Master');
end;

procedure TGUI_Master.ResizeToWindow;
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

procedure TGUI_Master.InjectNXEvent(const AEvent: TNXEvent);
begin
  case AEvent.EventType of
    nxeKeyDown:
      ProcessKeyDown(AEvent.Key);

    nxeKeyUp:
      ProcessKeyUp(AEvent.Key);

    nxeMouseMotion:
      ProcessMouseMotion(AEvent.Mouse.X, AEvent.Mouse.Y,
        AEvent.Mouse.ButtonState);

    nxeMouseDown:
    begin
      Popups.ProcessMouseDown(AEvent.Mouse.X, AEvent.Mouse.Y,
        AEvent.Mouse.Button);
      ProcessMouseDown(AEvent.Mouse.X, AEvent.Mouse.Y,
        AEvent.Mouse.Button);
      Popups.BringActiveToFront;
    end;

    nxeMouseUp:
      ProcessMouseUp(AEvent.Mouse.X, AEvent.Mouse.Y,
        AEvent.Mouse.Button);

    nxeTextInput:
      ProcessTextInput(AEvent.Text);
  end;
end;

end.
