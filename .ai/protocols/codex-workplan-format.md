# Codex Work Plan Format

Codex work plans should be saved under `work/plans/` using the same filename as the request.

Example:

```text
work/requests/control-state-lifecycle.md
work/plans/control-state-lifecycle.md
```

## Required Structure

Use this structure unless the request specifies a more specific one.

```markdown
# Work Plan: <Topic>

## Inputs

- Source request:
- Related discussion/review notes:
- Existing constraints:

## Summary

Briefly describe the architecture issue and the intended correction.

## Verified Findings

List what was confirmed in the code.

## Architecture Problem

Explain the root design problem.

## Target Contract

Describe the intended final-state architecture.

## Scope

List files/areas expected to change.

## Out Of Scope

List what must not change.

## Staged Implementation Plan

Describe the implementation stages.

## Verification Plan

List compile commands, greps, and manual tests.

## Risks And Questions

List risks, ambiguity, and anything needing human decision.

## Approval Gate

State that no implementation begins until the human owner explicitly authorizes it.
```

## Important Rules

- Do not treat the source request as implementation authorization.
- Do not edit code while creating the work plan.
- Do not replace architecture analysis with generic task steps.
- Do not omit non-goals.
- Do not hide uncertainty.
- Do not expand scope beyond the request.
- If the request is ambiguous, identify the ambiguity in the plan.
