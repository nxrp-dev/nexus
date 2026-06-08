# Nexus Pascal Debugging

Nexus Pascal aims to make Pascal debugging fit naturally into VS Code.

## Debug Configurations

Debugging uses VS Code launch configurations. Nexus Pascal helps by connecting
debug targets to project and build context.

For a useful debug session, VS Code needs to know:

- which executable to run
- which debugger integration to use
- the working directory
- build tasks that should run before launch
- source paths needed to step through code

## Breakpoints

Breakpoints are managed by VS Code and the configured debugger. Nexus Pascal's
role is to keep project build output and source paths predictable so breakpoints
map to the intended code.

## Watches And Variables

Watch, variable, and call stack behavior depends on the debugger backend and the
debug information emitted by the compiler.

For best results, build with debug information enabled and use a debugger that
understands the target platform and compiler output.

## Android And Future Targets

Android debugging requires a larger toolchain: SDK, NDK, Java, device or
emulator support, package deployment, and native debugging support.

Nexus Pascal's Android toolchain configuration is a step toward that workflow,
but full Android build/debug support requires additional project and packaging
work.
