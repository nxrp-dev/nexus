# Patch Review Protocol

Patch review checks implementation against the approved plan.

## Review Goal

The review should answer:

```text
Did the implementation preserve the approved architecture?
Did it solve the intended problem?
Did it introduce new ownership, lifecycle, routing, or rendering ambiguity?
```

## Review Inputs

Use:
- the approved work request
- the approved work plan
- the implementation diff or archive
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

Use this structure:

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

If a new architecture issue is discovered, record it as follow-up work unless it blocks the current pass.
