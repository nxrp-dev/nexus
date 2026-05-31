# Codex Work Plan Format

Codex work plans should be saved under `work/plans/` using the same filename as the request.

Create exactly one work plan per request. Do not create duplicate copies, alternate names, or files under legacy `workplans/` locations.

After creating the work plan, commit and push the work-plan artifact. That commit/push is part of the planning handoff and does not authorize implementation.

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

Include the concrete ownership contract where relevant:

- Owner:
- Responsibilities:
- State flow:
- Rendering/input/persistence behavior:

## Scope

List files/areas expected to change.

## Out Of Scope

List what must not change.

## Staged Implementation Plan

Describe the implementation stages.

## Sub-Agent Delegation

Describe whether approved implementation should be delegated.

Include:

- proposed named role or roles
- assigned folders or file ownership
- tasks that remain with main Codex
- coordination and overlap risks
- whether one worker should receive the whole approved plan or the work should be split by ownership

If delegation was requested, the default plan is that workers perform implementation edits and Main Codex coordinates, reviews, integrates, verifies, and reports.

State any concrete reason not to delegate. Do not use vague caution as the reason.

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
- Do not create more than one work-plan file for the same request.
- Commit and push the finished work-plan artifact.
- Do not replace architecture analysis with generic task steps.
- Do not omit non-goals.
- Do not hide uncertainty.
- Do not expand scope beyond the request.
- If the request is ambiguous, identify the ambiguity in the plan.
- Include a sub-agent delegation recommendation when implementation could be safely assigned.
- If delegation was requested, make worker implementation the default unless a concrete integration-seam reason prevents it.
- Include compile, focused grep, and manual verification expectations.
- State any questions that must be answered before implementation.
