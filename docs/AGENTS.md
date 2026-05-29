# Documentation Agent Notes

These rules apply to documentation under `docs/`.

## Before Editing

Before changing a documentation page, decide:

- Who is this page for?
- What should the reader understand or be able to do after reading it?
- Is this usage documentation, architecture documentation, reference documentation, or internal maintainer documentation?
- Does the page explain value and use before internal implementation details?

## Audience

- Public documentation is for Pascal developers, VS Code users, framework users, and project evaluators.
- Internal maintainer and architecture details are important, but they should not dominate overview, installation, quick-start, or guide pages.
- Do not write as if onboarding an internal junior developer. Write as if explaining a capable tool to a capable developer.

## Page Rules

- Overview pages should explain what the thing is, what problem it solves, what the reader can do with it, and where to go next.
- Guides should be task-oriented and runnable where practical.
- Reference pages should be precise, searchable, and light on narrative.
- Architecture pages may discuss internals, but should connect those internals to behavior, tradeoffs, or extension points.
- Status and limitations belong in a deliberate section or status page, not sprinkled through the main pitch.

## Tone

- Lead with purpose, capability, and workflow.
- Avoid internal meeting-note language.
- Avoid vague placeholders such as "this page will cover."
- Avoid highlighting random weaknesses on first-contact pages.
- Do not bury the mission of a component under implementation history.

## Style Source

Use `documentation-style.md` as the human-readable writing guide for tone, page types, and examples.
