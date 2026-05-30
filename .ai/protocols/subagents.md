# Sub-Agent Policy

This protocol defines how Codex uses sub-agents for Nexus work.

## Purpose

Sub-agents are execution helpers for approved work. They are useful when a task can be split by folder, subsystem, or file ownership without creating conflicting edits.

Sub-agents do not replace the main Codex role. Main Codex remains responsible for orchestration, integration, verification, and the final report to the human owner.

## Approval Gate

Do not spawn or resume a sub-agent for implementation because a work request, external review, prompt, or analysis exists.

Sub-agent implementation work begins only after the human owner directly approves the work plan for implementation.

Before approval, Codex may discuss whether sub-agents would be useful and may include a delegation proposal in the work plan. No sub-agent edits, builds, tests, launches, archives, commits, or repository operations occur before human approval.

## Persistent Role, Bounded Process

Use persistent expertise roles, not unbounded live processes.

Examples:

```text
NexusUI worker
NexusTest worker
NexusSchema explorer
scripts worker
```

A role may be reused across related work while it remains useful and reliable. The live agent process should be closed when it is idle, stale, unreliable, or no longer needed.

If an agent proves unreliable, close it and start a fresh one with the current approved plan, constraints, and assigned scope.

## Folder And Subsystem Ownership

Sub-agents should remain in their assigned area of expertise for their life span.

Examples:

- a NexusUI worker stays focused on `NexusUI/`
- a NexusTest worker stays focused on Nexus test applications and fixtures
- a scripts worker stays focused on `scripts/`

Folder expertise does not override the approved plan. If a task crosses areas, Codex must explicitly assign ownership boundaries before delegation.

## Agent Types

Use read-only explorer agents for bounded codebase questions.

Use worker agents for approved implementation slices.

Do not use a worker when the task is purely inspection, review, or planning.

## Delegation Rules

When implementation is approved and delegation is useful:

1. Decompose the approved plan into bounded slices.
2. Assign each sub-agent a clear role, folder or file ownership, and expected output.
3. Give the sub-agent the approved plan, constraints, forbidden actions, and verification expectations.
4. Tell the sub-agent it is working with other agents and must not revert or overwrite unrelated changes.
5. Avoid assigning two agents to edit the same files at the same time.
6. Refresh reused agents with the current plan and current constraints before each new assignment.
7. Review every sub-agent result before treating it as accepted.

Do not delegate tightly coupled work when the main Codex needs immediate control over the same files or sequence of changes.

## Integration Responsibility

Main Codex must:

- inspect sub-agent changes
- reconcile overlaps
- run or coordinate verification required by the approved plan
- decide whether the result satisfies the target architecture
- report what was delegated, what changed, and what was verified

Sub-agent output is not accepted automatically.

## Reliability

Close and replace a sub-agent when it:

- ignores approved scope or constraints
- edits outside its assigned ownership
- reintroduces rejected architecture
- becomes stale relative to the current worktree or plan
- produces results that require repeated correction

Starting a fresh agent is preferred over preserving a flawed live context.

## Non-Goals

Sub-agents are not used to:

- bypass approval gates
- make external AI review authoritative
- preserve stale context
- parallelize work that cannot be safely split
- avoid main Codex review and verification
