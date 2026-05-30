# Architecture Change Protocol

This protocol defines the repo-based workflow for architecture-level changes.

## Purpose

Architecture changes should be separated from implementation work.

The goal is to prevent repeated bug categories by identifying ownership, lifecycle, and responsibility flaws before code is changed.

## Roles

### Human Owner

The human owner is the final authority.

The human owner:
- identifies concerns and priorities
- provides authorization directly to Codex when appropriate
- decides whether work lands in Git
- uses Git as the rollback and safety mechanism

### Isolated Reviewer

The isolated reviewer produces architecture analysis and work-request files.

The isolated reviewer:
- reviews the current architecture
- identifies root causes
- writes structured work requests
- reviews Codex work plans
- reviews completed implementation results

The isolated reviewer does not authorize Codex to edit code.

### Codex

Codex reads work requests and returns structured work plans.

Codex:
- treats work-request files as planning input only
- returns a work plan under `work/plans/`
- does not edit code until the human owner directly authorizes implementation
- implements approved work after direct human authorization
- compiles/tests according to the approved plan

### Git

Git is the audit trail and rollback mechanism.

The workflow does not rely on tiny proof-of-concept changes for safety when architecture has been carefully reviewed. Clear commits, reviewable diffs, and rollback points provide the safety net.

## Standard Flow

1. A work request is created under `work/requests/`.
2. Codex reads the work request.
3. Codex creates a matching work plan under `work/plans/`.
4. The human owner reviews the work plan, optionally with the isolated reviewer.
5. The human owner directly authorizes Codex when implementation is desired.
6. Codex implements the approved plan.
7. The implementation result is reviewed.
8. The human owner commits, rejects, or requests correction.

## Naming

Request, plan, and review files use matching topic names.

Example:

```text
work/requests/groupbox-composition-layout.md
work/plans/groupbox-composition-layout.md
work/reviews/groupbox-composition-layout.md
```

Do not use dates in filenames by default. Dates and status belong inside the file header.

## Work Request Rule

Every Codex work request must start with exactly:

```text
This is a demand for a work plan.
```

That phrase is the only directive-style statement required.

Work requests may include strong design rules and desired final-state language, but must not include authorization language such as:
- proceed
- start
- implement now
- make the changes
- do the work
- apply this

The work request describes architectural direction and asks Codex to explain its plan before any code changes.

## POC Rule

Do not recommend partial proof-of-concept work by default.

For carefully reviewed architecture changes, the normal target is full implementation after approval. A POC is only appropriate when the human owner explicitly wants one for understanding, exploration, or risk isolation.
