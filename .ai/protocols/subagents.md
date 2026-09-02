# Sub-Agent Policy

This protocol defines the narrow condition under which Codex may use sub-agents
for Nexus work.

## Owner-Only Authorization

Never spawn, resume, message, or delegate work to a sub-agent unless the human
owner explicitly requests sub-agent use in the current conversation.

None of the following authorizes sub-agent use:

- a work request or work plan;
- approval to implement a work plan;
- architecture-change scope;
- a large or complex task;
- separable folders or ownership boundaries;
- an opportunity to parallelize work;
- a prior use of sub-agents;
- Codex's own recommendation.

Codex must not propose or recommend delegation on its own. The capability exists
for manual invocation by the human owner only.

The `spawn:` prefix is an explicit request to use a sub-agent for that work. A
plain implementation request without `spawn:` or another direct instruction to
use sub-agents must be performed locally.

## Approval Gates

An explicit request to use a sub-agent does not bypass architecture planning or
implementation approval. Both conditions must be satisfied independently when
the task otherwise requires them:

1. the human owner explicitly requests sub-agent use; and
2. the human owner authorizes the implementation work.

## Execution After Explicit Request

When the human owner explicitly requests sub-agent use:

- assign a clear, bounded folder or subsystem scope;
- avoid overlapping write ownership;
- provide the approved plan, constraints, and verification expectations;
- ensure the sub-agent does not revert unrelated work;
- review every result before accepting it;
- keep Main Codex responsible for integration, verification, and final reporting;
- stop using the sub-agent when the requested delegated work is complete.

Sub-agents remain helpers, not authorities. Their output is never accepted
without Main Codex review.

## Default

The default is always local execution by Main Codex. If explicit human-owner
authorization for sub-agent use is absent or ambiguous, do not use a sub-agent.
