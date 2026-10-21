# Codex Work Plan Format

Use this format when the owner requests a saved work plan. Save it under
`work/plans/` using the same topic name as the request, when present.

For each requested saved plan, create one file. Do not create duplicate copies,
alternate names, or files under legacy `workplans/` locations.

Follow the root `AGENTS.md` Verification Workflow for records and repository
actions. Saving a plan does not authorize a commit, push, or implementation.

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

State that implementation remains local unless the human owner explicitly
requested sub-agent use. Do not propose, recommend, or infer delegation from
task size, separable ownership, architecture scope, or potential parallelism.
Plan approval and implementation approval do not authorize sub-agents.

Only when the human owner explicitly requested sub-agent use, include the
requested roles, ownership, sequencing, overlap risks, and Main Codex
responsibilities.

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
- Do not replace architecture analysis with generic task steps.
- Do not omit non-goals.
- Do not hide uncertainty.
- Do not expand scope beyond the request.
- If the request is ambiguous, identify the ambiguity in the plan.
- Never include a sub-agent recommendation unless the human owner explicitly requested sub-agent use.
- Otherwise state that implementation remains local and that no sub-agent use is authorized by the plan.
- Include compile, focused grep, and manual verification expectations.
- State any questions that must be answered before implementation.
