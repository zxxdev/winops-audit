---
document type: module
Help Version: 0.1.0
HelpInfoUri: ''
Locale: en-US
Module Guid: f96ef356-b003-45ba-8187-0a3937b0a3b0
Module Name: WinOpsAudit
ms.date: 11/27/2026
PlatyPS schema version: 2024-05-01
title: WinOpsAudit Module
---

# WinOpsAudit Module

## Description

Read-only audits for Windows administrators: inventory, certificates, folder permissions and Active Directory. Returns objects; never changes anything.

## WinOpsAudit

### [Get-WinOpsAuditCertificate](Get-WinOpsAuditCertificate.md)

Lists the certificates in the certificate stores of this computer, with when they expire and what is wrong with them.

### [Get-WinOpsAuditInventory](Get-WinOpsAuditInventory.md)

Describes this computer: hardware, operating system, domain and installed updates.

### [Get-WinOpsAuditRule](Get-WinOpsAuditRule.md)

Lists the audit rules WinOpsAudit knows about.

### [Get-WinOpsAuditSoftware](Get-WinOpsAuditSoftware.md)

Lists the programs installed on this computer.

### [Get-WinOpsAuditTlsCertificate](Get-WinOpsAuditTlsCertificate.md)

Connects to TLS servers and audits the certificate each one presents, and the chain it sends with it.

### [Get-WinOpsAuditUpdate](Get-WinOpsAuditUpdate.md)

Lists the updates installed on this computer.
