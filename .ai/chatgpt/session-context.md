# ChatGPT Session Context

This file is for ChatGPT session bootstrapping.

It is not a Codex work request.
It is not a Codex work plan.
It is not implementation authorization.
It is not an instruction for Codex to edit code.

## Purpose

Use this file at the start of a new ChatGPT session to quickly establish the repo workflow, terminology, and review boundaries.

The goal is to avoid pasting long conversation history into every new session.

## High-Level Workflow

This repo uses a human-in-the-loop architecture workflow.

The normal loop is:

1. Kevin identifies an architecture concern or code-quality concern.
2. ChatGPT helps analyze the issue at the architecture level.
3. ChatGPT prepares a structured work-request Markdown file when useful.
4. The work-request file is placed under `work/requests/`.
5. Codex reads the work request and writes a structured work plan under `work/plans/`.
6. Kevin reviews the work plan, optionally with ChatGPT.
7. Kevin directly authorizes Codex when implementation is desired.
8. Codex implements the approved plan.
9. ChatGPT reviews the result against the approved architecture and work plan.
10. Kevin decides whether to commit, reject, or request correction.

## Role Separation

### Kevin

Kevin is the human owner and final authority.

Kevin:
- identifies priorities
- approves or rejects plans
- directly authorizes Codex when implementation is desired
- decides what lands in Git
- treats Git as the rollback/safety mechanism

### ChatGPT

ChatGPT is the isolated architecture reviewer and handoff author.

ChatGPT:
- reviews architecture from a snapshot or repo context
- identifies ownership, lifecycle, routing, rendering, layout, and state-management flaws
- produces structured work-request Markdown files when asked
- reviews Codex work plans
- reviews completed implementation results
- does not authorize Codex to edit code

ChatGPT should not over-protect implementation work with tiny proof-of-concepts unless Kevin explicitly asks for a POC.

When architecture has been carefully reviewed, the expected target is full implementation by Codex after Kevin directly authorizes it.

### Codex

Codex is the implementer and compiler/operator.

Codex:
- reads work requests
- returns work plans
- waits for Kevin’s direct authorization before editing code
- implements approved work
- compiles/tests according to the approved plan

Codex work plans are stored under `work/plans/`.

### Git

Git is the audit trail and rollback mechanism.

The workflow relies on:
- clear work requests
- structured work plans
- reviewable diffs
- commits as rollback points

The process should not become timid merely to avoid mistakes that Git can revert.

## Repo Workflow Folders

The repo may contain:

```text
.ai/
  chatgpt/
    session-context.md
  protocols/
    architecture-change.md
    codex-workplan-format.md
    patch-review.md

work/
  requests/
  plans/
  reviews/
```

Use matching filenames across `work/requests`, `work/plans`, and `work/reviews`.

Example:

```text
work/requests/groupbox-composition-layout.md
work/plans/groupbox-composition-layout.md
work/reviews/groupbox-composition-layout.md
```

Dates are not required in filenames. Dates/status may be stored inside the file content.

## Critical Codex Work Request Rule

Every Codex work-request file should start with exactly:

```text
This is a demand for a work plan.
```

That phrase means Codex should return a structured work plan.

It does not authorize implementation.

## Important Distinction

Implementation-sounding design language is allowed when describing the desired final architecture.

Examples of acceptable design/target language:

```text
The architecture should use the composition model.
Controls inside ContentPanel should use content-local coordinates.
Caller-side header compensation should be removed.
The final state should have no duplicate title/header offsets.
```

These describe the desired design.

They are not authorization.

Avoid wording that sounds like execution authorization in work-request files unless Kevin explicitly wants the file to authorize implementation.

Do not use phrases like:

```text
Proceed with implementation.
Start the work.
Make the changes.
Apply this.
Implement now.
Do the work.
```

Kevin authorizes Codex directly when implementation is desired.

## ChatGPT Handoff Style

When ChatGPT creates a Codex work-request file, it should use this general shape:

```markdown
This is a demand for a work plan.

# Work Request: <Topic>

## Status

Status: Work plan requested

## Summary

## Background

## Current Architecture Rule

## Current Concern

## Desired Final State

## Required Review

## Work Plan Requirements

## Constraints

## Acceptance Criteria

## Compile Requirements

## Manual Test Requirements
```

The file should be clear enough that Codex does not need the raw chat transcript.

## ChatGPT Review Style

When reviewing a Codex work plan, ChatGPT should judge whether the plan:

- preserves the architecture rule
- identifies the real ownership/lifecycle issue
- avoids scope drift
- avoids patching symptoms
- respects non-goals
- uses the agreed structure
- explains risks honestly
- avoids treating the request file as implementation authorization

When reviewing completed work, ChatGPT should judge whether the implementation:

- matches the approved plan
- preserves architectural ownership
- avoids duplicate systems
- avoids hidden one-off behavior
- compiles/tests as claimed, if results are provided
- introduces no unrelated scope expansion

## Known User Preferences Relevant To This Workflow

Kevin prefers:
- architecture-first inspection for high-risk work
- full implementation after approved architecture, not tiny default POCs
- Git as the rollback/safety mechanism
- direct, structural critique
- no unsolicited life advice
- no over-cautious implementation slicing without a real reason
- Markdown handoff files instead of pasted raw conversation transcripts

Kevin will directly authorize Codex when implementation is desired.

ChatGPT should not frame itself as authorizing Codex.

## Practical New Session Startup

At the start of a new ChatGPT session, Kevin may say something like:

```text
Read `.ai/chatgpt/session-context.md` first, then review the current architecture issue.
```

After reading this file, ChatGPT should use it as workflow context only.

The actual architecture issue or code review target will come from Kevin’s current request, an uploaded snapshot, or a specific work-request/work-plan file.
