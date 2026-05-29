# Nexus UI Getting Started

The current working example is `NexusUI/example/LifeStatNXL.lpr`. It is the best
place to copy the basic application shape from, because it exercises the active
runtime, skin loading, menus, tabs, data controls, layout controls, popups, and
dialogs.

## Minimal Application Shape

A Nexus UI application creates the global application runtime, loads skin data
if desired, attaches controls to `Application.RootWindow`, then enters the run
loop:

```pascal
program MyNexusUIApp;
{$mode objfpc}{$H+}
{$apptype GUI}

uses
  obNXApplication,
  obNXButton,
  obNXWindow,
  tpNXPlatform;

var
  lButton: TNXButton;

begin
  Application.Initialize('My Nexus UI App', 800, 600);
  Application.Skin.LoadNamedSkin('default', Application.Canvas);

  lButton := TNXButton.Create(Application.RootWindow,
    MakeNXRect(20, 20, 120, 28));
  lButton.Caption := 'Run';

  Application.Run;
end.
```

Use the control units you actually instantiate. The demo imports units such as
`obNXPanel`, `obNXTabControl`, `obNXGrid`, `obNXTreeView`, `obNXToolbar`, and
`obNXStatusBar` because it builds a broad sample surface.

## Build and Run

The Lazarus project file for the demo is `NexusUI/example/LifeStatNXL.lpi`.
Its unit search path includes:

- `..`
- `..\..\NexusUI`
- `..\..\..\common\sdl\units`
- `..\..\..\common\sdl_ext`

When creating another project, keep the Nexus UI units and SDL units reachable
through the compiler search path, and copy or deploy the needed runtime DLLs or
shared libraries with the executable. The example directory currently carries
the Windows SDL2, SDL2_image, SDL2_ttf, image codec, and zlib DLLs used by the
demo.

## Project Structure

A small project usually has:

- one `.lpr` application entry point
- Nexus UI unit search paths
- SDL backend/runtime libraries near the executable
- optional `skins` and `resources` folders
- ordinary Pascal units for application-specific screens and events

## Control Construction

Controls are retained objects. Create them with a parent, then configure bounds,
layout, captions, values, and events:

```pascal
lPanel := TNXPanel.Create(Application.RootWindow);
lPanel.Align := caClient;

lButton := TNXButton.Create(lPanel, MakeNXRect(12, 12, 100, 24));
lButton.Caption := 'Save';
```

Parent relationships matter for rendering order, hit testing, coordinate
conversion, focus traversal, layout, and lifetime behavior.
