# Nexus UI Cross Platform

Nexus UI is designed so the public framework shape is not tied to a platform
visual component library. The current backend is SDL2, and most active
development should be understood through that backend boundary.

## Backend Boundary

`TNXPlatform` owns backend/platform services:

- create and destroy the native window
- poll platform events
- provide renderer/canvas operations
- start and stop platform text input
- access clipboard operations
- provide font services
- load and destroy images
- provide timing

`TNXSDL2` is the active implementation. `TNXCanvas` and Nexus event records keep
most control code independent from SDL2 details.

## Windows

The example project is currently Windows-oriented. `NexusUI/example` includes
Windows runtime DLLs for SDL2, SDL2_image, SDL2_ttf, image codecs, and zlib.
The Lazarus project emits output under `output\LifeStatNXL\$(TargetCPU)-$(TargetOS)`.

## Other Desktop Targets

The architecture keeps Linux and macOS possible through SDL2 and Free Pascal,
but this documentation should not claim parity until those targets are built and
exercised. Platform-specific deployment should verify:

- SDL2 and related runtime libraries are present
- font and image loading work
- text input works for the target platform
- file paths for skins and resources resolve correctly
- window creation, resizing, clipboard, and timing behave as expected

## Mobile Targets

Android and iOS are not current documented targets. They would require backend,
build, packaging, text input, font, file, and lifecycle work beyond the current
desktop example.

## Deployment Notes

Deploy the executable with the runtime libraries and resources used by the
active backend. For SDL2 builds, that includes SDL2 itself and any image/font
extension libraries required by the application. If a skin loads image assets,
ship the skin files and referenced images with stable relative paths.
