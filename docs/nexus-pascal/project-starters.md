# Nexus Pascal Project Starters

Project starters are guided project creation workflows. They are intended to
create a useful project seed rather than drop static files into a folder.

## Guided Creation

Nexus Pascal project creation is LS-backed. The extension provides the UI, and
NexusLS provides the project model, fields, validation, planning, and generated
outputs.

This allows project creation to understand concepts such as:

- project kind
- target folder
- Lazarus project import
- Nexus project metadata
- build and run expectations

## Nexus Projects

Nexus project creation is expected to produce a `.nxp` project file and the
source files needed to begin work.

For users, the goal is a guided experience:

1. choose the project type
2. confirm the target folder and project name
3. review the plan
4. create the project
5. build or open the generated project

## Importing Existing Projects

Existing Lazarus projects can be imported into Nexus project workflows. When an
`.lpi` is imported, the generated Nexus project should track that Lazarus
project as the source project rather than treating a random `.lpr` as the main
project.

## Custom Starters

Custom starters are a future extension point. The preferred direction is not a
collection of disconnected templates, but a project system that can describe
inputs, validate them, and generate a coherent project from a typed plan.
