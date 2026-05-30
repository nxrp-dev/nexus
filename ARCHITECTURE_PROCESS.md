# Nexus Architecture Process

This document describes the working process for architecture corrections in this repository. It is meant to make the discussion, planning, approval, implementation, review, and archive loop explicit for future sessions.

## Purpose

Architecture work is not widget-level bug chasing. When a defect points to an ownership, lifecycle, routing, persistence, rendering, or state-flow problem, fix the model first. Local patches are acceptable only when the model is already correct and the defect is truly local.

The goal is small, coherent architectural corrections that move Nexus toward clearer ownership and simpler code.

## Discussion First

Architecture work begins with discussion, diagnosis, or externally reviewed notes.

- The user may provide conversation text, a proposed prompt, review notes, or a diagnosis.
- Treat outside AI feedback as review input, not authority.
- Inspect the codebase as needed to verify claims and form an opinion.
- Do not edit, build, run tests, launch programs, or perform repository operations during discussion unless the user explicitly asks for that action.
- If the supplied diagnosis is wrong or incomplete, say so directly and explain what the code shows.

Inspection is allowed during design discussion. Mutation is not.

## Planning Gate

Before implementation, produce a Markdown work plan for approval.

Use `ARCH_WORK_PLAN_TEMPLATE.md` as the default structure for substantial architecture passes. Save the plan as a Markdown artifact, preferably under `workplans/`, and provide a clickable link to that file in chat instead of pasting the full plan inline. Inline plans are only for very small plans or when the user explicitly asks for the text in the conversation.

The important requirement is that the plan is structured, reviewable, easy to download or open, and explicit enough for the user to take it to external review before implementation.

The plan should include:

- The architectural problem being fixed.
- The intended ownership/lifecycle/routing contract after the change.
- The files or subsystems expected to change.
- The staged implementation order.
- What is explicitly out of scope.
- The compile/test/grep verification expected after each structural phase or at the end.
- Any questions that must be answered before implementation.

Do not make code edits from a plan. Wait for approval.

## Approval Gate

Implementation starts only after the user approves the plan or gives a clear work directive such as "approved", "make it so", "proceed", "fix", "apply", or equivalent.

When approved:

- Follow the approved plan and constraints.
- Keep the scope narrow.
- Do not expand into deferred cleanup unless explicitly approved.
- If implementation reveals that the approved plan is materially wrong, pause and explain the conflict before continuing.
- If implementation reveals a small necessary adjustment inside the approved architecture, make the adjustment and report it.

## Implementation Rules

Prefer correcting ownership over layering patches.

- Centralize shared behavior when duplicated local behavior is the problem.
- Remove or reshape incorrect APIs instead of preserving them for their own sake.
- Update affected Nexus call sites when an API changes.
- Do not keep compatibility shims unless the user explicitly asks or a verified current integration requires them.
- Avoid casts, aliases, re-exports, and convenience wrappers as substitutes for proper design.
- Keep Object Pascal code explicit and easy to read.
- Use the smallest coherent change that establishes the new contract.

Rendering should consume state. Input dispatch should route through one policy. Persistence should reflect the object model. Scrollbars, controls, hosts, windows, and other framework objects should own the mechanics that belong to them.

## Verification

Compile frequently after structural changes.

For architecture corrections, verification usually includes:

- The primary project or test app affected by the change.
- Any related example app that exercises the same framework path.
- Focused greps that prove old call paths, ambiguous APIs, direct render-time mutation, or duplicate traversal loops were actually removed.
- Manual user testing when behavior is visual or interactive.

When reporting completion, include what compiled and what the focused greps showed. If a verification step was not run, say so plainly.

## Review Loop

After implementation, the user may send external review feedback.

Handle review feedback the same way:

- Read the feedback.
- Verify each claim against the code.
- Separate actual defects from preferences or hypothetical risks.
- Produce a focused Markdown work plan for approval.
- Do not patch from review feedback until directed.

This keeps outside review useful without letting it replace local judgment.

## Archive Checkpoints

When the user asks for an archive, use `scripts\New-NexusSourceArchive.ps1`.

After completing an approved architecture implementation pass, create a fresh archive automatically before the final response so the user does not need to ask separately.

Archives are checkpoints around meaningful architecture milestones. They are not a substitute for compile/test verification, and they should not be treated as approval to start new work.
