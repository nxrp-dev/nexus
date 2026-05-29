# Attribution

Nexus is directed and developed by Kevin Collins as a Pascal tooling and framework ecosystem.

The project builds on decades of Pascal practice and uses several external projects, libraries, and tools. This page credits the major visible influences and dependencies without implying that they own Nexus architecture, APIs, or design direction.

## Project Lineage

### Nexus Pascal

Nexus Pascal began as a hard fork of FPCToolkit. It is now a Nexus-owned VS Code extension focused on Free Pascal, Lazarus, and Nexus project workflows.

FPCToolkit provided useful starting material for Pascal editing, extension packaging, and VS Code integration. Nexus Pascal is no longer intended to remain compatible with FPCToolkit when a cleaner Nexus design requires different behavior.

### NexusLS

NexusLS replaces legacy Pascal language-server behavior with a Nexus-owned server, test path, cache model, and service structure.

The older Pascal language-server ecosystem remains an important reference point for expected editor behavior: navigation, hover, completion, diagnostics, inactive regions, document symbols, and project-aware parsing.

## Pascal Foundations

Nexus is built for the Free Pascal and Lazarus ecosystem.

- Free Pascal provides the compiler, runtime, language, packages, and many standard units used across Nexus.
- Lazarus provides project conventions, build-mode behavior, CodeTools/LazUtils support, and long-standing Pascal IDE expectations.
- Delphi, VCL, and LCL concepts influence the way Nexus thinks about controls, ownership, events, forms, projects, and developer ergonomics.

Those influences are practical references, not compatibility promises. Nexus uses Pascal tradition where it helps and changes direction where the old shape gets in the way.

## Major External Technology

### VS Code

Nexus Pascal integrates with Visual Studio Code through the extension API, task system, debug configuration model, language features, commands, menus, and settings.

### SDL2

NexusUI currently uses SDL2 as its active backend for windowing, rendering, input, clipboard, timing, image loading, and font-related services through a Nexus platform abstraction.

SDL2, SDL2_image, and SDL2_ttf are external dependencies and are not part of NexusUI.

### Mustache

NexusSchema renders generated output through Mustache templates. The schema model supplies structured metadata; templates describe target-specific output.

### SQLite

NexusLS uses SQLite-backed symbol caching through Free Pascal database units. The cache supports faster repeated symbol lookup while keeping the language server project-aware.

### Material for MkDocs

The Nexus documentation site is built with Material for MkDocs.

## NexusUI Attribution

NexusUI has a more specific attribution file for its early scaffold, SDL dependencies, Pascal UI influences, and AI-assisted development notes:

- `NexusUI/ATTRIBUTION.md`

## AI-Assisted Development

Nexus has been developed with AI-assisted coding and review support, including ChatGPT and Codex, under Kevin Collins' direction, review, and design control.

AI assistance does not own the project and does not replace the author's design judgment, authorship, or licensing decisions.

