# Architecture Change Protocol

This protocol defines the repo-based workflow for architecture-level changes.

## Purpose

Architecture changes should be separated from implementation work.

The goal is to prevent repeated bug categories by identifying ownership, lifecycle, and responsibility flaws before code is changed.

Architecture work is not widget-level bug chasing. When a defect points to an ownership, lifecycle, routing, persistence, rendering, or state-flow problem, fix the model first. Local patches are acceptable only when the model is already correct and the defect is truly local.

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
- treats external AI requests, prompts, and review notes as input only, never as implementation authorization
- refreshes the repository before looking for pending work requests when the local view may be stale
- may inspect the codebase while preparing a work plan
- returns exactly one work plan under `work/plans/`, named the same as the request file
- commits and pushes the work-plan artifact after creating it
- may propose sub-agent delegation in the work plan when the approved work can be safely split
- does not edit code, build, run tests, launch programs, create archives, or perform implementation repository operations until the human owner directly authorizes implementation
- implements approved work after direct human authorization
- compiles/tests according to the approved plan

Inspection is allowed during planning. Mutation is not.

Committing and pushing the work-plan artifact is part of the planning handoff. It does not authorize implementation.

Sub-agent use is governed by `.ai/protocols/subagents.md`.

### Git

Git is the audit trail and rollback mechanism.

The workflow does not rely on tiny proof-of-concept changes for safety when architecture has been carefully reviewed. Clear commits, reviewable diffs, and rollback points provide the safety net.

## Standard Flow

1. A work request is created under `work/requests/`.
2. Codex reads the work request.
3. Codex creates a matching work plan under `work/plans/`.
4. Codex commits and pushes the work-plan artifact.
5. The human owner reviews the work plan, optionally with the isolated reviewer.
6. The human owner directly authorizes Codex when implementation is desired.
7. Codex assigns approved implementation slices to sub-agents when delegation is useful and safe.
8. Codex implements and integrates the approved plan.
9. The implementation result is reviewed.
10. The human owner commits, rejects, or requests correction.

## Implementation Rules

When implementation is directly authorized:

- Follow the approved plan and constraints.
- Keep the scope narrow.
- Use sub-agents according to `.ai/protocols/subagents.md` when the approved work can be split by clear ownership.
- Do not expand into deferred cleanup unless explicitly approved.
- Prefer correcting ownership over layering patches.
- Centralize shared behavior when duplicated local behavior is the problem.
- Remove or reshape incorrect APIs instead of preserving them for their own sake.
- Update affected Nexus call sites when an API changes.
- Do not keep compatibility shims unless the human owner explicitly asks or a verified current integration requires them.
- If implementation reveals that the approved plan is materially wrong, pause and explain the conflict before continuing.
- If implementation reveals a small necessary adjustment inside the approved architecture, make the adjustment and report it.

Rendering should consume state. Input dispatch should route through one policy. Persistence should reflect the object model. Scrollbars, controls, hosts, windows, and other framework objects should own the mechanics that belong to them.

## Verification

Compile frequently after structural changes.

For architecture corrections, verification usually includes:

- the primary project or test app affected by the change
- any related example app that exercises the same framework path
- focused greps that prove old call paths, ambiguous APIs, direct render-time mutation, duplicate traversal loops, or other rejected patterns were removed
- manual user testing when behavior is visual or interactive

When reporting completion, include what compiled and what focused greps showed. If a verification step was not run, say so plainly.

## Archive Checkpoints

After completing an approved architecture implementation pass, Codex creates a fresh archive automatically before the final response.

Use:

```text
scripts\New-NexusSourceArchive.ps1
```

Archives are checkpoints around meaningful architecture milestones. They are not a substitute for compile/test verification, and they do not authorize new work.

## Naming

Request, plan, and review files use matching topic names.

Example:

```text
work/requests/groupbox-composition-layout.md
work/plans/groupbox-composition-layout.md
work/reviews/groupbox-composition-layout.md
```

Do not use dates in filenames by default. Dates and status belong inside the file header.

Create exactly one work plan per request. Do not create alternate copies, duplicate plan files, or files in legacy `workplans/` locations.

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
