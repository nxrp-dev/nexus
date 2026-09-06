# NexusBot Ubuntu Handoff

This file is a focused bootstrap for a new Codex session working in the Nexus
repository on Ubuntu. It is current as of 2026-09-06.

It is context, not a work request or implementation authorization. Follow the
human owner's current instruction after reading it.

## Start Here

Read, in this order:

1. the repository-root `AGENTS.md`;
2. this entire file;
3. `NexusTools/BotHost/AGENTS.md`;
4. `NexusTools/BotHost/README.md` only when a command or runtime contract below
   needs confirmation.

Do **not** crawl `.ai/chatgpt/`, `work/requests/`, `work/plans/`, or
`work/reviews/`. Those files contain design history, not required startup
context. Do not reread the historical NexusBot plans unless the human owner
names one specifically.

Do not use sub-agents unless the human owner explicitly requests them in the
current conversation.

## Immediate Objective

Establish a native Ubuntu build and execution of the headless
`NexusTools/BotHost/NexusBotHost` application. Start by compiling the current
checkout on Ubuntu. Treat actual compiler, linker, loader, and runtime output as
the source of remaining work; do not invent a Linux redesign in advance.

The useful completion proof is:

1. native Ubuntu compilation;
2. deterministic NexusBotHost and NexusXMPP tests on Ubuntu;
3. launch from typed JSON configuration;
4. verified TLS connection to the configured XMPP service;
5. one observed room or direct-message response;
6. clean termination through `SIGINT` or `SIGTERM`.

## Settled Architecture

- NexusBotHost is a headless console application. It has no NexusUI, SDL, font,
  image, or other GUI dependency.
- Launch and deployment configuration are RTTI-backed Pascal objects persisted
  as JSON. RTTI and published properties are the data contract; do not replace
  them with free-form JSON handling.
- Credentials are permitted directly in the typed deployment configuration.
  Never echo passwords or API keys to the console, diagnostics, commands, Git,
  or test output.
- Relative paths are resolved against the configuration file that declares
  them.
- All socket work uses bundled Synapse. The OpenAI provider uses Synapse HTTPS;
  WinHTTP is gone and must not return.
- TLS and cryptography use OpenSSL 3. On Linux the current code requests
  `libssl.so.3` and `libcrypto.so.3` dynamically.
- Do not fork or locally patch bundled Synapse merely to eliminate its three
  Free Pascal deprecation warnings for `TimeSeparator` and `ShortMonthNames`.
  They are known third-party warnings, not a Linux blocker.
- XMPP identities and authentication credentials are deliberately ASCII-only.
  UTF-8 message bodies remain transparent. ICU, PRECIS, IDNA, generated Unicode
  tables, and an internationalization framework are outside the current
  requirement and must not be reintroduced.
- Existing XMPP connection threads are justified by blocking socket ownership.
  Provider workers are justified by blocking App Server or HTTPS operations
  that must not block XMPP. Do not add timer, deadline, routing, notification,
  cleanup, or generic background threads.
- NexusXMPP raises its ordinary Pascal events on the XMPP connection thread.
  BotHost handles them through its existing ownership model. Do not add a UI
  message pump or a protocol-result queue.
- All tests belong in the Nexus test framework. Do not create a standalone test
  harness. `nxtest_host` is the generic Nexus test-module host, not a
  feature-specific harness.

## Current Committed State

The Linux-support checkpoint before this handoff is commit `fe58f86` (`Syncing
Linux support progress.`). It contains:

- the headless `NexusBotHost.lpr` entry point;
- Unix `cthreads`, `SIGINT`, and `SIGTERM` handling;
- `TProcess`-based Codex App Server hosting;
- typed configuration-file launch and console activity output;
- Synapse-based OpenAI Responses API transport;
- Linux OpenSSL 3 shared-library names;
- removal of BotHost's NexusUI and SDL dependencies;
- direct-message routing and room-context behavior;
- join-or-create support for temporary MUC rooms.

Primary files for native-build failures are:

- `NexusTools/BotHost/NexusBotHost.lpr`
- `NexusTools/BotHost/NexusBotHost.lpi`
- `NexusTools/BotHost/src/obNXBotHostRuntime.pas`
- `NexusTools/BotHost/src/obNXCodexAppServer.pas`
- `NexusTools/BotHost/src/obNXOpenAIProvider.pas`
- `NexusLib/net/src/xmpp/obNXXMPPOpenSSL.pas`
- `NexusLib/net/src/xmpp/obNXXMPPTransport.pas`
- `lib/synapse/ssl_openssl3.pas`
- `lib/synapse/ssl_openssl3_lib.pas`

Open only the files implicated by an actual failure.

## Important Uncommitted Windows Work

When this handoff was created, the Windows working tree also contained a
verified but uncommitted ICU/PRECIS removal. It is deliberately **not** part of
the handoff commit. A fresh Ubuntu checkout will not contain it unless it has
subsequently been committed or transferred by the owner.

The agreed final direction of that change is:

- delete `obNXXMPPICU.pas`, `obNXXMPPPRECIS.pas`,
  `tpNXXMPPPRECISTableData.inc`, and
  `scripts/Generate-NXXMPPPRECISTables.ps1`;
- add `NexusLib/net/src/xmpp/utNXXMPPASCII.pas`;
- make JID, resource, username, and password preparation explicitly ASCII-only;
- preserve UTF-8 stanza and message content;
- remove ICU/PRECIS references from tests and documentation.

Before changing anything on Ubuntu, run `git status --short` and inspect the
last few commits. Do not overwrite Ubuntu-side work. If the ICU-removal commit
is absent, report that fact to the owner instead of silently rebuilding a
second implementation from this summary.

## Verified Windows Baseline

Immediately before this handoff was written, the Windows tree including the
uncommitted ICU removal produced these results:

- `lazbuild -B NexusTools/BotHost/NexusBotHost.lpi`: passed;
- `lazbuild -B NexusTools/BotHost/tests/NexusBotHostTestModule.lpi`: passed;
- complete `NexusBotHost` suite through `nxtest_host`, including the real-pipe
  fake Codex App Server fixture: 16 passed, 0 failed, 0 skipped;
- clean NexusXMPP test compilation with only the three known bundled-Synapse
  deprecation warnings;
- `NexusNetXMPPTests`: passed.

This proves the current behavior on Win64. It does not prove Ubuntu compilation
or runtime loading.

## Ubuntu First Pass

Use the installed native Free Pascal/Lazarus toolchain. Confirm versions first,
then build from the repository root:

```sh
fpc -iV
lazbuild --version
openssl version
lazbuild -B NexusTools/BotHost/NexusBotHost.lpi
lazbuild -B NexusTools/BotHost/tests/NexusBotHostTestModule.lpi
```

Do not begin by reading more architecture documents. If compilation fails,
capture the first real error, inspect its direct owner, make the smallest
coherent correction, and rebuild.

For the generic Nexus test host, the repository already provides:

```sh
NexusTools/Test/build_linux.sh
```

Use the resulting `nxtest_host` with the native BotHost test-module shared
library. Compile `NexusTools/BotHost/tests/FakeCodexAppServer.lpr` natively,
export its absolute path as `NEXUS_BOTHOST_FAKE_APP_SERVER`, and run the
`NexusBotHost` suite. Locate generated binaries from the build output rather
than assuming Windows filenames or directories.

Then compile and run `NexusLib/net/tests/NexusNetXMPPTests.lpr` with native
Linux unit/output paths equivalent to the documented Win64 command in
`NexusLib/net/tests/NexusNetXMPPTests.md`.

## Runtime Inputs

Example typed configuration shapes are in:

- `NexusTools/BotHost/config/NexusBotHostLaunch.example.json`
- `NexusTools/BotHost/config/NexusBotController.example.json`

Do not place real credentials in the repository. The owner has a working remote
XMPP deployment using the account `nexus@nexus.remote` and room
`nexus-test@conference.nexus.remote`; obtain current credentials and certificate
paths from the owner or an existing deployment file.

The launch form is:

```sh
./NexusBotHost --config /absolute/path/to/NexusBotHostLaunch.json
```

The OpenAI bot additionally needs a valid API key and readable public CA bundle
in its typed deployment binding. The Codex bot needs a Linux Codex executable
and runtime directory. Do not assume Windows executable paths survive in the
configuration.

## Expected External Linux Dependencies

Verify rather than assume package names on the installed Ubuntu release. The
runtime requirements visible in current code are:

- Free Pascal and Lazarus for native builds;
- OpenSSL 3 runtime libraries discoverable as `libssl.so.3` and
  `libcrypto.so.3`;
- a readable CA bundle for XMPP and a readable public CA bundle for OpenAI;
- the Codex executable only when running a Codex-backed bot.

ICU and SDL are not requirements.

## Scope Discipline

- Fix only demonstrated Ubuntu compile, link, load, or runtime failures.
- Do not redesign working code merely because the platform changed.
- Do not add compatibility shims without a verified integration requirement.
- Do not weaken TLS verification to make a test pass.
- Do not expose secrets while diagnosing configuration.
- Keep the human owner informed of the exact failure and correction.

## Suggested New-Session Prompt

```text
Read AGENTS.md and .ai/codex/nexusbot-ubuntu-handoff.md. Do not scan historical
work requests, plans, reviews, or ChatGPT context. Inspect git status and recent
commits, then continue the native Ubuntu NexusBotHost build from the first
actual compiler or runtime failure. Do not use sub-agents. Do not edit until I
explicitly direct you to proceed.
```
