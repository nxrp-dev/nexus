This is a demand for a work plan.

# Work Request: <Topic>

## Status

Status: Work plan requested

## Summary

Briefly describe the architecture issue or target correction.

## Background

Explain the prior discussion and decisions that led to this request.

## Current Architecture Rule

State the principle that must be preserved or established.

## Current Concern

Describe the behavior, code smell, or repeated bug pattern.

## Desired Final State

Describe the target architecture.

Implementation-sounding design language is acceptable here when it describes the final state, but this file is not authorization to edit code.

## Required Review

List the files, classes, methods, or behavior Codex should inspect before proposing changes.

Inspection is authorized for plan creation. Code edits, builds, tests, program launches, archives, commits, and repository operations are not authorized by this file.

## Work Plan Requirements

The work plan should explain:
1. verified findings
2. root architecture problem
3. target contract
4. implementation phases
5. non-goals
6. risks and questions
7. compile/test plan
8. manual verification plan

## Constraints

No code edits are authorized by this file.

Do not expand scope beyond this request.

Do not include implementation authorization language in this request. The human owner authorizes implementation directly after reviewing the work plan.

## Acceptance Criteria

List what must be true after an approved implementation is completed.

## Compile Requirements

```text
lazbuild --build-all NexusTest\NexusTestUI\NexusTestUI.lpi
lazbuild NexusUI\example\LifeStatNXL.lpi
fpc NexusUI\testNXPersist.lpr
```

## Manual Test Requirements

List targeted manual checks.
