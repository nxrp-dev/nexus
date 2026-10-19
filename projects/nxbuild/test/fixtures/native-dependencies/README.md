# Generated native dependency integration

This Linux fixture uses the actual nxbuild CLI and configured NexusFPC/Clang
compilers. `All.nxproject` requires Pascal and C consumers; both require one
shared producer. Its Process operation generates Pascal source, Pascal/C
includes and C source. LLVM then produces an object and a shared library.
The consumers inherit every directory from the producer, without copying its
resource paths. The Pascal executable runs two NXTests; the C executable
returns zero only when the shared-library function returns 42.

From the Nexus repository, set `NXBUILD` to the rebuilt executable and `NX_OUT`
to the configured external `Tools.OutputRoot`:

```sh
"$NXBUILD" /action=plan /project=projects/nxbuild/test/fixtures/native-dependencies/All.nxproject /targetos=linux /targetcpu=x86_64
"$NXBUILD" /action=build /project=projects/nxbuild/test/fixtures/native-dependencies/All.nxproject /targetos=linux /targetcpu=x86_64
"$NX_OUT/generated-dependencies/x86_64-linux/pascal/Debug/GeneratedNativeTests"
LD_LIBRARY_PATH="$NX_OUT/generated-dependencies/x86_64-linux/Debug/libraries${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$NX_OUT/generated-dependencies/x86_64-linux/c/Debug/GeneratedCConsumer"
```

Use a fresh external OutputRoot for the once-only check. Planning must leave it
absent. After one aggregate build, `Debug/generated/producer-runs.txt` beneath the
fixture output directory must have exactly one line. Each subsequent build
runs the producer again: this fixture checks per-invocation graph deduplication,
not incremental caching. `readelf -d` on the C executable identifies
`libnxgenerated.so` as an actual runtime dependency.
