# NAQ

NAQ means Never Asked Questions: the questions a developer should ask before deciding whether Nexus is worth their attention.

## Why does Nexus exist?

Pascal development has strong tools, but the experience is fragmented. Free Pascal, Lazarus, VS Code, schema generation, testing, language-server behavior, and AI-assisted development often live in separate mental and technical worlds.

Nexus exists to make those pieces work as one ecosystem.

## What problem is Nexus trying to solve?

Nexus is trying to make Pascal development feel modern without throwing away what makes Pascal productive:

- explicit code
- strong types
- clear ownership
- fast native binaries
- practical desktop application patterns
- repeatable generated output
- project-aware tooling

The goal is not to imitate another language stack. The goal is to make Pascal sharper.

## Is Nexus a replacement for Lazarus?

No.

Lazarus remains important for Free Pascal projects, project files, packages, build modes, CodeTools, and many existing workflows. Nexus Pascal and NexusLS are intended to make Pascal work well in VS Code while respecting Lazarus project semantics where they matter.

NexusUI is a separate UI framework. It is not the Lazarus LCL and does not try to be a drop-in replacement for it.

## Is Nexus a replacement for Delphi?

No.

Delphi and the VCL remain important reference points for productive Pascal development. Nexus borrows the good instincts: ownership, events, explicit object models, forms, controls, and practical application structure.

Nexus is not trying to clone Delphi. It is building a Pascal ecosystem around Free Pascal, Lazarus, VS Code, schema tooling, testing, and Nexus-owned runtime libraries.

## Why VS Code?

VS Code has become the common editor surface for many developers. It has a strong extension model, integrated tasks, debugging hooks, source-control workflows, terminals, and language-server integration.

Nexus Pascal uses that surface to bring Pascal project creation, builds, debugging, and code intelligence into a workspace developers already use.

## Why build a new language server?

Pascal language tooling needs project context. Units, include files, conditionals, Lazarus build modes, search paths, and compiler options all affect what the code means.

NexusLS exists so Pascal language features can be shaped around Nexus goals instead of patched around someone else's assumptions.

## Why build NexusUI?

NexusUI gives Nexus a code-first Pascal UI framework with explicit ownership, retained controls, skinning, window management, popups, layout, and testable behavior.

It is built for applications where the code should remain readable and the framework should not hide important behavior behind designer metadata.

## Why build NexusSchema?

Repeated structure is a source of bugs. Database scripts, provider lists, import files, code stubs, and other generated artifacts often describe the same facts in different places.

NexusSchema keeps schema intent in one place and renders repeatable output through templates.

## Why build NexusTest?

NexusTest gives Nexus projects a shared-library test boundary. Test modules can be loaded, listed, run, and monitored by tools without turning the UI into the owner of test state.

That makes testing useful for command-line workflows, GUI test runners, language-server validation, and future automation.

## Is Nexus production-ready?

Nexus already contains working pieces, but it is still actively evolving. Treat it as a serious working system under active development, not a polished commercial SDK.

The important point is direction: Nexus is being shaped around coherent Pascal workflows, not around preserving every legacy decision.

## Can I contribute?

Nexus is not organized around public contribution as a project goal.

Use it, study it, fork it, or build with it if it helps you. If you need behavior the project does not provide, the cleanest path may be a fork or a separate tool. Nexus itself will stay focused on its own design direction.
