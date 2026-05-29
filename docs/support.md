# Support

Nexus is an active Pascal tooling project. Support works best when reports are specific, reproducible, and tied to the part of Nexus you are using.

## Where To Report Problems

Use GitHub issues for bugs, missing behavior, packaging problems, documentation errors, and focused feature requests:

- [Nexus issues](https://github.com/nxrp-dev/nexus/issues)

Use the issue title to name the affected area when possible:

- `Nexus Pascal: build task does not find Lazarus project`
- `NexusLS: go to definition misses property type`
- `NexusUI: popup loses mouse capture`
- `NexusSchema: generated Firebird script has wrong field type`
- `NexusTest: test module result cannot be read twice`

## What To Include

Good reports save time. Include:

- the Nexus component involved
- operating system
- Free Pascal version
- Lazarus version, when relevant
- VS Code version, when relevant
- extension version or commit
- the project type being used: FPC, Lazarus, Nexus, schema, test module, or UI application
- the command or action you ran
- what happened
- what you expected
- a small reproducible example, if possible

For language-server problems, include the Pascal snippet and the exact cursor location or symbol involved.

For build problems, include the project file type, build mode, output path, and the important compiler or lazbuild output.

For NexusUI problems, include the control, layout, input action, and screenshot if the issue is visual.

## Feature Requests

Feature requests should describe the workflow problem, not only the desired control, command, or setting.

Useful:

> I need to run a selected Lazarus build mode from VS Code without hand-writing a task.

Less useful:

> Add more task options.

Nexus is opinionated. A request may be rejected if it weakens the project direction, adds compatibility debt, or solves a narrow problem in the wrong layer.

## Security Issues

Do not post security-sensitive reports publicly if they include credentials, private paths, proprietary source, or exploitable behavior.

Use a private contact path if one is published for the project. If no private path is available, open a minimal public issue that says a private security report is needed without including sensitive details.

## What Support Is Not

Nexus support is not general Pascal consulting, Lazarus training, VS Code training, or commercial integration support.

The docs should help with normal usage. Issues should focus on Nexus behavior.

## Before Filing

Check:

- the relevant module documentation
- [Project Status](project-status.md)
- [NAQ](naq.md)
- existing GitHub issues

If the behavior is already documented as not implemented, an issue can still be useful, but describe the real workflow need so it can be weighed against the project direction.

