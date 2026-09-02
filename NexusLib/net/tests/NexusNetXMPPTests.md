# NexusNet XMPP Test Record

This is the retained verification record for the deterministic Win64 NexusXMPP test target. It does not claim live-server interoperability.

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

Covered behavior includes ICU availability, PRECIS/JID processing, arbitrary stream chunk boundaries, retained namespaces, dispatcher ownership, IQ correlation and synchronous capacity, combined direct-TLS/STARTTLS SRV ordering, OpenSSL primitives, trusted loopback TLS, rejected service identity, rejected issuer, blocked-read interruption, positive and negative SCRAM transcripts, bounded queues, legal state transitions, accepted/rejected stream-management state and replay accounting, discovery, roster retrieval/push/subscription storage, connection failure events, caller-thread callbacks, and repeated client connection lifecycles.

## External verification boundary

No Prosody, ejabberd, or Openfire executable is installed in the verification environment, and no controlled server configuration or test account was supplied. The console target therefore compiles, but live-server interoperability remains unverified and is not represented as a passing test.
