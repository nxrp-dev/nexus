# Known engine NXTest failures

`Nexus2D.Bitmap.MissingBMP` reproduces undefined behavior in
`nexus-mobile/platform/shared/Rtt_BitmapUtils.cpp`, in `bitmapUtil::loadBMP`.
When `SDL_LoadBMP` fails, execution reaches the end of the non-void function.
The Linux image loader assigns that result to its image-data pointer and
expects a null pointer on failure. A missing or unreadable BMP therefore takes
an undefined return path.

The NXTest compiles the actual engine source with its configured compile
options and Clang's return sanitizer. It supplies a nonexistent BMP filename;
UBSan reports “execution reached the end of a value-returning function without
returning a value.” The engine implementation remains unfixed.

Build `nxbuildEngineTests.nxproject`, then select this regression directly:

```text
nxbuildEngineTests /absolute/path/to/Nexus2DEngine.nxproject --test=Nexus2D.Bitmap.MissingBMP
```

The expected result after repair is a successful process exit with a null image.
