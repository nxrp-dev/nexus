# Sub-Agent Policy

This protocol defines how Codex uses sub-agents for Nexus work.

## Purpose

Sub-agents are execution helpers for approved work. When delegation is requested and implementation is approved, sub-agents should perform the implementation edits by default unless there is a concrete integration-seam reason not to.

Sub-agents do not replace the main Codex role. Main Codex remains responsible for orchestration, integration, verification, and the final report to the human owner.

## Approval Gate

Do not spawn or resume a sub-agent for implementation because a work request, external review, prompt, or analysis exists.

Sub-agent implementation work begins only after the human owner directly approves the work plan for implementation.

Before approval, Codex may discuss whether sub-agents would be useful and may include a delegation proposal in the work plan. No sub-agent edits, builds, tests, launches, archives, commits, or repository operations occur before human approval.

When the human owner has requested delegation, approved implementation should be delegated unless Main Codex can name a compelling reason to keep the edit local. The reason must be specific, such as:

- the next local step is blocked on immediate hands-on inspection
- the change cannot be given clear file, folder, or subsystem ownership
- the work has a tight integration seam that would create high conflict risk
- the current worktree state makes delegated edits unsafe
- the work is too small to delegate without adding coordination cost

## Spawn Prefix

When the human owner prefixes a message with `spawn:`, treat it as an explicit request to use a sub-agent process for that work.

The `spawn:` prefix means:

- spawn or reuse the appropriate named sub-agent by default
- follow the existing assignment, ownership, and approval rules
- assign the work according to the sub-agent's folder or subsystem expertise
- keep Main Codex responsible for coordination, review, integration, verification, and final reporting

If Main Codex does not spawn after a `spawn:` request, it must state the compelling reason. Acceptable reasons are concrete process or integration risks, not vague caution.

The `spawn:` prefix does not make external review authoritative and does not bypass architecture approval gates. If the requested work still requires a work plan or implementation approval, create or wait for that approval before assigning implementation edits.

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

Use worker agents for approved implementation work.

Do not use a worker when the task is purely inspection, review, or planning.

## Delegation Rules

When delegation is requested and implementation is approved:

1. Prefer assigning the approved implementation to a named worker role.
2. Delegate the whole approved plan to one worker when it has coherent ownership.
3. Decompose the plan into bounded worker slices only when the write sets are naturally separate.
4. Assign each sub-agent a clear role, folder or file ownership, and expected output.
5. Give the sub-agent the full approved plan, constraints, forbidden actions, and verification expectations.
6. Tell the sub-agent it is working with other agents and must not revert or overwrite unrelated changes.
7. Avoid assigning two agents to edit the same files at the same time.
8. Refresh reused agents with the current plan and current constraints before each new assignment.
9. Review every sub-agent result before treating it as accepted.

Do not delegate tightly coupled work when the main Codex needs immediate control over the same files or sequence of changes.

If Main Codex decides not to delegate approved implementation after delegation was requested, it must state the concrete reason before proceeding locally.

## Integration Responsibility

Main Codex must:

- coordinate the sub-agent assignment
- inspect sub-agent changes
- reconcile overlaps
- make integration edits when needed
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
