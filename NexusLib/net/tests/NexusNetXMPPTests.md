# NexusNet XMPP Test Record

This is the retained verification record for the deterministic Win64
NexusXMPP test target and the explicitly identified live-server checks below.

## Verified 2026-09-02

The test executable was rebuilt from source with FPC 3.2.2 using `-B` and all units/binaries directed under `output/`:

```powershell
fpc -B -FuNexusLib\net\src\xmpp -Fulib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\fcl-xml -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetXMPPTests\units -FEoutput\NexusNetXMPPTests\bin NexusLib\net\tests\NexusNetXMPPTests.lpr
```

Result: successful clean compilation. The only warnings were three existing deprecation warnings in bundled `synautil.pas`.

The executable was run with the Git for Windows OpenSSL 3 directory on `PATH`:

```powershell
$env:Path = 'C:\Program Files\Git\mingw64\bin;' + $env:Path
output\NexusNetXMPPTests\bin\NexusNetXMPPTests.exe
```

Result: `NexusNet XMPP tests passed.`

Covered behavior includes ICU availability, PRECIS/JID processing, arbitrary stream chunk boundaries, retained namespaces, dispatcher ownership, IQ correlation and synchronous capacity, combined direct-TLS/STARTTLS SRV ordering, OpenSSL primitives, trusted loopback TLS, rejected service identity, rejected issuer, blocked-read interruption, positive and negative SCRAM transcripts, bounded queues, legal state transitions, stream-management resumption eligibility and expiry, replay reservation and cancellation, rejected-resume reporting, resumed-session identity checks, 32-bit counter wraparound, discovery, roster retrieval/push/subscription storage, connection failure events, caller-thread callbacks, and repeated client connection lifecycles.

## Openfire live interoperability

On 2026-09-02, `NexusNetXMPPLiveTest.lpr` was run against a locally controlled
Openfire 5.1.2 server using `nexus.local`, STARTTLS on `127.0.0.1:5222`, and two
temporary test accounts. Passwords were supplied only through environment
variables.

The live target is built with:

```powershell
fpc -B -FuNexusLib\net\src\xmpp -Fulib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\fcl-xml -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetXMPPLiveTest\units -FEoutput\NexusNetXMPPLiveTest\bin NexusLib\net\tests\NexusNetXMPPLiveTest.lpr
```

It reads `NEXUS_XMPP_USER1`, `NEXUS_XMPP_PASSWORD1`,
`NEXUS_XMPP_USER2`, `NEXUS_XMPP_PASSWORD2`, `NEXUS_XMPP_CA_FILE`,
`NEXUS_XMPP_HOST`, and `NEXUS_XMPP_PORT`. Setting
`NEXUS_XMPP_EXPECT_TLS_FAILURE=1` runs the single-client negative TLS case.

With the unrelated synthetic test CA, the client rejected Openfire with
`certificate verify failed`. With the checked-in public Openfire certificate,
both clients completed verified TLS, PLAIN authentication explicitly enabled
for this controlled TLS-only test, resource binding, presence, and a message
exchange. The final positive test passed six consecutive runs using unique
resources for each session.

The live run identified and corrected two interoperability defects: the stream
framer did not accept Openfire's leading XML declaration, and the transport's
fixed-length receive discarded valid short reads when its timeout elapsed.

The retained Openfire certificate is
`fixtures/xmpp/openfire-nexus-local.crt`. It must be replaced and its fingerprint
reviewed if the controlled server regenerates its certificate.

## Remaining external verification boundary

Prosody and ejabberd remain unverified. Accepted live XEP-0198 resumption across
a forced client-side transport interruption was not exercised by this basic
two-client exchange.
