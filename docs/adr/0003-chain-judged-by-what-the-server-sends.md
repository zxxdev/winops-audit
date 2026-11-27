# 0003. Judge the certificate chain by what the server sends

- **Status:** accepted
- **Date:** 2026-11-27

## Context

Rule CRT-003 reports a TLS server that does not send its full chain. A server should send its own
certificate and every intermediate between it and a root; the root itself is optional, because
clients already have it. When an intermediate is missing, some clients connect and others fail:
the ones that already have it (in their store, in a cache from an earlier visit, or downloaded from
the address written in the certificate, the AIA extension) build the chain anyway; the others, such
as many Java, Python or embedded clients, do not. It is a classic "works on my machine" problem,
and an audit run from an administrator's computer is exactly the kind of client that tends to have
the intermediate already.

## Options

1. **Ask .NET whether the chain is valid** (`X509Chain.Build`) and report a problem when it is not.
   Simple, but it answers another question. Windows and .NET complete the chain with everything
   they can find, so a server that sends nothing but its own certificate passes on most
   administrators' computers.
2. **Look only at what the server sent** and follow the issuer names upwards until a root. Does
   not depend on this computer, but has to know which issuer is a root without asking anyone. On
   Windows the root store fills in on demand, so a root that is not there yet would look like a
   missing intermediate.
3. **Build the chain this computer would use, then compare it with what the server sent.** Every
   certificate in that chain between the server's own and the root must be among the ones the
   server sent; any other one came from this computer, so the server should have sent it.

## Decision

Option 3. `Get-WinOpsAuditTlsCertificate` keeps the certificates the server sends (.NET hands them
to the validation callback in `ChainPolicy.ExtraStore`), builds the chain with every source this
computer has, downloads included, and reports as missing every intermediate in that chain that
the server did not send. If the chain does not reach a root at all, the result is `UnknownIssuer`
and no finding: from here it cannot tell whether the server or this computer lacks the issuer.
A private PKI can be passed with `-CertificateAuthority`, so its servers can be judged from a
computer that does not trust it.

## Consequences

- The verdict does not depend on what this computer has cached: a computer that has the
  intermediate still reports it as missing. The tests check that case on purpose.
- It relies on the chain .NET chooses. With cross-signed roots there can be more than one path,
  and the one chosen here may list a certificate that a client with a newer root store would not
  need. The certificates it names are always ones the server did not send.
- Building the chain may download intermediates from the addresses in the certificates, as
  browsers do. Revocation is not checked, so no revocation lists are downloaded.
- `UnknownIssuer` is a gap, said out loud: the audit does not guess.
