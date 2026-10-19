# Configuration publications integration

This Linux fixture builds C objects and a shared library, then compiles a Pascal
NXTest consumer requiring an intermediate project. The consumer names no producer
directories. It inherits common Pascal sources, common and configuration-specific
headers, and the selected object/library directories through the dependency graph.

Debug supplies the value 101; Release supplies 202. Four NXTests check the common
source, selected Pascal include, linked object and dynamically loaded library.
All outputs live under the configured external `Tools.OutputRoot`.

From the Nexus repository, set `NXBUILD` to the rebuilt nxbuild executable and
`NX_OUT` to `Tools.OutputRoot`:

```sh
for configuration in Debug Release; do
    "$NXBUILD" /action=validate /project=projects/nxbuild/test/fixtures/configuration-publications/Consumer.nxproject /buildconfiguration="$configuration"
    "$NXBUILD" /action=plan /project=projects/nxbuild/test/fixtures/configuration-publications/Consumer.nxproject /buildconfiguration="$configuration"
    "$NXBUILD" /action=build /project=projects/nxbuild/test/fixtures/configuration-publications/Consumer.nxproject /buildconfiguration="$configuration"
    "$NX_OUT/configuration-publications/linux/x86_64/$configuration/application/ConfigurationTests" "$configuration"
done
"$NX_OUT/configuration-publications/linux/x86_64/Debug/application/ConfigurationTests" Debug
```

Planning and validation must work before the generated directories exist.
After Release builds, Debug's objects, library and executable must be unchanged
and its four tests must still pass. ELF inspection should show a dependency on
`libnxconfiguration.so` and a runtime search path of `$ORIGIN/../libraries`.
The recipe uses `LinkerOptions` for that runtime search path. FPC's `-Xr`, exposed
as `RuntimeLinkPath`, sets a link-time `--rpath-link` search path instead.

The unit-suite `ConfigurationPublications` NXTest additionally exercises Linux
and Windows selections on x86-64 and ARM64, checks configuration-specific
compiler defines, and verifies all four inherited publication categories.
These are descriptor checks; native execution of this fixture is Linux-only.
