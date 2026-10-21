# Patch Review Protocol

Patch review checks implementation against the owner's requested scope and
approved design, using a work plan when one was provided.

## Review Goal

The review should answer:

```text
Did the implementation preserve the approved architecture?
Did it solve the intended problem?
Did it introduce new ownership, lifecycle, routing, or rendering ambiguity?
```

## Review Inputs

Use:
- the owner's requirements
- the approved work request or plan, when provided
- the implementation diff, or an archive when supplied
- compile/test results if available

## Review Priorities

Prioritize architectural correctness over cosmetic cleanup.

Look for:
- scope drift
- duplicate systems
- new one-off behavior
- lifecycle bypasses
- raw state mutation
- render-time state negotiation
- input/routing bypasses
- unclear ownership
- hidden compatibility shims
- missed cleanup of old compensation code

## Review Output

Report findings and verification limits in chat. Save a review only when the
owner requests one, following the root `AGENTS.md` Verification Workflow.

For a requested saved review, use this structure:

```markdown
# Review: <Topic>

## Verdict

Accept / Accept with follow-up / Request correction / Reject

## Summary

Briefly state the result.

## Verified Against Plan

List plan items satisfied.

## Issues

List blocking and non-blocking issues separately.

## Architecture Notes

Explain any architectural concerns.

## Suggested Commit Message

Provide a concise commit message if accepted.
```

## Non-Goals

Do not reopen unrelated architecture work during patch review.

If a new architecture issue is discovered, report it to the owner. Do not start
unrelated work or create an unrequested tracking artifact.
