# Work Requests, Plans, and Reviews

This folder stores repo-visible AI workflow artifacts.

## Folders

```text
work/requests/
work/plans/
work/reviews/
```

## Purpose

These files preserve the reasoning behind architecture changes.

They are not source code and are not implementation authorization by themselves.

## File Pairing

Use matching names across folders.

Example:

```text
work/requests/groupbox-composition-layout.md
work/plans/groupbox-composition-layout.md
work/reviews/groupbox-composition-layout.md
```

## Request Files

Request files are architecture handoffs to Codex.

Every request file must start with:

```text
This is a demand for a work plan.
```

Request files should describe:
- summary
- background
- architecture rule
- current concern
- desired final state
- constraints
- required review
- work plan requirements
- acceptance criteria

## Plan Files

Plan files are produced by Codex.

They explain what Codex plans to do, based on the request, before the human owner authorizes implementation.

## Review Files

Review files document post-implementation review results.

They may be written manually or generated from a review discussion.
