# Work Plan: NexusBot Deterministic Implied Replies

## Inputs

- Human request in the current conversation to support implied replies without
  an AI evaluator.
- Agreed initial policy: infer only from strong conversational signals and
  prefer missed replies over ambiguous multi-bot routing.
- Existing explicit mention and XEP-0461 reply routing in `NexusBotHost`.

## Architecture Problem

Each bot currently makes a stateless routing decision from its own copy of a
room message. Implied replies require short-lived room state, and independently
owned state could allow two summoned bots to accept the same message. The
controller already owns every active bot host, so it must own the shared room
conversation state.

## Target Contract

- Explicit mentions and XEP-0461 replies retain priority.
- A successfully emitted bot answer establishes a short-lived claim on the
  room conversation for the participant whose prompt produced the answer.
- The next unaddressed live message is implied for that bot only when it comes
  from the same room occupant, no other participant or bot has intervened, and
  the claim has not expired.
- An explicit address, an explicit reply to another occupant, an intervening
  participant, bot output, room departure, or timeout clears the claim.
- All active hosts consult one controller-owned tracker.
- State is memory-only and is empty after process restart.
- Every inferred acceptance is journaled with its reason.
- No model or provider request participates in the routing decision.

## Implementation

1. Add a BotHost conversation tracker object with explicit ownership,
   synchronization, bot registration, pending-answer reflection, room claim,
   interruption, expiration, and implied-target decisions.
2. Attach every controller-managed host to the shared tracker for the host's
   lifetime.
3. Have room routing observe every live message before applying the existing
   explicit router. Permit the existing router to construct a prompt when the
   tracker identifies that host as the implied target.
4. Record a pending claim only after a room answer is accepted by the XMPP send
   queue; activate it when the bot's reflected room message is observed.
5. Clear room state when a bot leaves or loses a room.
6. Add focused tests for explicit precedence, same-participant continuation,
   competing bots, interruption, expiration, reflected answer activation, and
   room cleanup.

## Verification

- Build and run `NexusBotHostTestModule`.
- Rebuild `NexusBotHost`.
- Confirm `git diff --check` and inspect the final diff for ownership and
  lifecycle correctness.
- Restart the persistent NexusBotHost service and confirm XMPP room and
  provider readiness.
- Create the required architecture archive checkpoint.

## Out of Scope

- AI classification or semantic topic detection.
- Persistent conversation claims.
- Inference across rooms, private messages, restarts, or server history.
- Relaxing existing explicit-address validation or authorization behavior.
