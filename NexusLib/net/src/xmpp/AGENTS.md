# NexusXMPP Agent Instructions

These rules apply to `NexusLib/net/src/xmpp`.

## Standards

- Follow `../../../../.ai/standards/pascal.md`.
- Follow `../../AGENTS.md` for Nexus networking boundaries.

## Architecture

- NexusXMPP is a client-to-server XMPP protocol library, not a generic transport or XML framework.
- The connection thread exclusively owns its socket, parser, and protocol state.
- Application callbacks run only through caller-thread event pumping.
- Cross-thread queues are bounded and queued payloads own their data.
- Keep ICU use behind the XMPP-specific ICU adapter.
- Keep OpenSSL use behind the XMPP crypto and TLS owners.
- Never silently fall back to plaintext, `TSSLNone`, disabled verification, ASCII-only JIDs, or incomplete PRECIS processing.
