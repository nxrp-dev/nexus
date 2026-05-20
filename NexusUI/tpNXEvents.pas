unit tpNXEvents;

{$mode objfpc}{$H+}

interface

uses
  tpNXPlatform;

type
  TNXEventType = (
    nxeNone,
    nxeQuit,
    nxeWindowResized,
    nxeWindowExposed,
    nxeKeyDown,
    nxeKeyUp,
    nxeMouseMotion,
    nxeMouseDown,
    nxeMouseUp,
    nxeTextInput
  );

  TNXKey = (
    nkUnknown,
    nkBackspace,
    nkDelete,
    nkLeft,
    nkRight,
    nkUp,
    nkDown,
    nkHome,
    nkEnd,
    nkEscape,
    nkEnter,
    nkTab,
    nkA,
    nkC,
    nkV,
    nkX
  );

  TNXModifier = (
    nmShift,
    nmControl,
    nmAlt
  );

  TNXModifiers = set of TNXModifier;

  TNXKeyEventData = record
    Key: TNXKey;
    Modifiers: TNXModifiers;
    Repeat_: Boolean;
  end;

  TNXMouseEventData = record
    X: Integer;
    Y: Integer;
    Button: TNXMouseButton;
    ButtonState: TNXMouseButtons;
  end;

  TNXWindowEventData = record
    Width: Integer;
    Height: Integer;
  end;

  TNXEvent = record
    EventType: TNXEventType;
    Key: TNXKeyEventData;
    Mouse: TNXMouseEventData;
    Text: string;
    Window: TNXWindowEventData;
  end;

implementation

end.
