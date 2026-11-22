# Security policy

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private reporting instead:
[Report a vulnerability](https://github.com/zxxdev/winops-audit/security/advisories/new).

Include the cmdlet involved, what an attacker could do, and the steps to reproduce it.
I will acknowledge the report within a week and keep you updated until it is fixed.

## Scope

WinOpsAudit is meant to be run by administrators, often with privileged accounts, against
servers and Active Directory. That is why it is read-only by design. The main risks are:

- a cmdlet that changes something, or that can be made to;
- credentials ending up in output, logs or reports. No cmdlet takes credentials yet; the ones that
  will, will take a `PSCredential` or a SecretManagement name, never plain text;
- data read from a system (names, paths, certificate fields) that breaks a report, for example
  markup injected into an HTML report;
- a compromised build tool from the PowerShell Gallery.

Reports about any of these are welcome.

## Supported versions

The module is not released yet. Once it is, only the latest version will receive fixes.
