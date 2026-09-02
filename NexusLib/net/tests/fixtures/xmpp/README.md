# Synthetic XMPP TLS Fixtures

These certificates and the server private key are synthetic test-only material for the local loopback TLS tests. They do not identify or protect any deployed service and must never be used outside the test executable.

- `ca.crt` signs the trusted `localhost` server certificate.
- `server.crt` contains the `DNS:localhost` subject alternative name.
- `server.key` is the intentionally public test server key.
- `untrusted-ca.crt` provides a different trust anchor for the rejected-issuer test.
- `server.ext` records the server certificate extensions used when producing the fixture.
