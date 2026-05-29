# Documentation Style Guide

Nexus documentation should explain a practical Pascal tooling ecosystem: what it does, why it exists, and how a developer uses it.

The default reader is a capable developer who wants useful information quickly. They may know Pascal, Lazarus, Delphi, VS Code, or only part of that stack. The docs should help them become productive without sounding like internal onboarding notes.

## Documentation Goals

Nexus docs should:

- Explain the problems Nexus solves.
- Show what a developer can do today.
- Make workflows easy to follow.
- Keep module boundaries understandable without making boundaries the whole story.
- Separate public usage docs from internal architecture and maintainer notes.

## Page Types

### Overview Pages

Overview pages are first-contact pages. They should answer:

- What is this?
- What problem does it solve?
- Why is it useful?
- What can I do with it?
- Where should I go next?

Avoid leading with implementation status, internal class names, or historical decisions unless they are necessary to understand the product.

### Guides

Guides should help the reader complete a task.

Good guides use concrete steps, expected outputs, and links to related concepts. They should not drift into broad architecture explanation unless that explanation directly helps the task.

### Reference Pages

Reference pages should be precise and easy to scan. Prefer tables, short definitions, command examples, and direct descriptions.

Reference pages do not need marketing language, but they should still be written for readers, not for code archaeology.

### Architecture Pages

Architecture pages may discuss internals, ownership, boundaries, and design tradeoffs.

Even there, explain the practical consequence: how the architecture affects extension, debugging, behavior, or use.

### Status Pages

Status pages are the right place for maturity notes, incomplete work, and known gaps.

Do not scatter caveats through overview pages in a way that makes the project sound smaller or weaker than it is.

## Voice

Use a clear, confident, technical voice.

Prefer:

- "Nexus Pascal adds VS Code workflows for Free Pascal and Lazarus projects."
- "NexusSchema keeps schema intent in one place and generates repeatable output from templates."
- "NexusTest runs tests through a shared-library boundary so test modules can be loaded and monitored by tools."

Avoid:

- "This page will cover..."
- "Currently this is rough but..."
- "The repository owns..."
- "Near-term work is..."
- Internal phrasing that sounds like project management notes.

## Ordering

Put reader value before internals.

A useful order is:

1. Purpose
2. Problem solved
3. Main capabilities
4. Basic usage
5. Links to deeper pages
6. Architecture, status, or maintainer details where appropriate

## Limitations

Be honest about limitations, but place them deliberately.

Limitations should help the reader make decisions. They should not distract from the main explanation or make first-contact pages read like defect reports.
