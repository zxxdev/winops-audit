---
document type: cmdlet
external help file: WinOpsAudit-help.xml
HelpUri: https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditTlsCertificate.md
Locale: en-US
Module Name: WinOpsAudit
ms.date: 11/27/2026
PlatyPS schema version: 2024-05-01
title: Get-WinOpsAuditTlsCertificate
---

# Get-WinOpsAuditTlsCertificate

## SYNOPSIS

Connects to TLS servers and audits the certificate each one presents, and the chain it sends with it.

## SYNTAX

### __AllParameterSets

```
Get-WinOpsAuditTlsCertificate [-ComputerName] <string[]> [-Port <int>] [-ExpiringInDays <int>]
 [-TimeoutSeconds <int>] [-CertificateAuthority <X509Certificate2[]>] [<CommonParameters>]
```

## ALIASES

This cmdlet has no aliases.

## DESCRIPTION

Opens a TLS connection to each server, reads the certificate it presents and the other certificates it sends, and closes the connection: nothing is sent after the handshake. Any certificate is accepted, because the point is to look at it, not to trust it.

Returns one object per server with the same description as Get-WinOpsAuditCertificate (subject, dates, days left, algorithm, key) and rules CRT-001 and CRT-002, plus what the server sends:

- CRT-003: the server does not send the intermediate certificates its chain needs. A client that has them from before (in its store, in its cache, or downloaded from the address written in the certificate) connects fine, and another one fails. So whether this computer can complete the chain proves nothing: the check builds the chain this computer would use, with everything it can find, and reports every intermediate in it that the server did not send. ChainStatus is Complete when the chain reaches a self-signed root and every intermediate in it was sent; MissingIntermediate when some were not; or UnknownIssuer when the chain does not reach a self-signed root at all, because an issuer is not known here: then it cannot tell who lacks the certificate, and no finding is reported. Whether this computer trusts the root is not part of this rule: a self-signed server certificate, or a private root it does not trust, can still be Complete.

Building the chain can download intermediate certificates from the addresses written in the certificates, as browsers do. Revocation is not checked.

A server that cannot be reached, or does not finish the handshake in time, writes an error that names it, and the command goes on with the others.

It runs on any system PowerShell 7 runs on. Nothing is changed.

## EXAMPLES

### Example 1: The certificate of a web server

```powershell
Get-WinOpsAuditTlsCertificate -ComputerName www.contoso.test
```

### Example 2: Several servers, only the ones that expire within 30 days

```powershell
'www.contoso.test', 'mail.contoso.test', 'vpn.contoso.test' | Get-WinOpsAuditTlsCertificate -ExpiringInDays 30
```

### Example 3: Other ports: LDAPS and RDP

```powershell
Get-WinOpsAuditTlsCertificate -ComputerName dc01.contoso.test -Port 636
Get-WinOpsAuditTlsCertificate -ComputerName srv-file01.contoso.test -Port 3389
```

Any service that starts TLS as soon as it connects works. Services that start in plain text and switch to TLS later (SMTP with STARTTLS, for example) do not.

### Example 4: Servers of a private PKI

```powershell
$pki = Get-ChildItem -Path Cert:\LocalMachine\Root, Cert:\LocalMachine\CA | Where-Object Subject -like '*O=Contoso*'
Import-Csv .\servers.csv | Get-WinOpsAuditTlsCertificate -CertificateAuthority $pki | Where-Object ChainStatus -ne 'Complete'
```

The CSV file needs a column named ComputerName (or HostName). The certificates of the private PKI let the check build the chain even on a computer that does not trust that PKI.

## PARAMETERS

### -CertificateAuthority

Certificates of a private PKI, for servers whose chain this computer does not know. The self-signed ones are trusted as roots, instead of the roots of this computer; the others only help to build the chain. They are not treated as sent by the server: an intermediate found only here is still reported as missing.

```yaml
Type: System.Security.Cryptography.X509Certificates.X509Certificate2[]
DefaultValue: '@()'
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ComputerName

One or more servers, by name or IP address. The name is also sent in the handshake (SNI), so a server with several sites presents the certificate of that name. Takes names from the pipeline, as text or as a property named ComputerName, HostName or DnsName.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- HostName
- DnsName
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ExpiringInDays

Lists only the servers whose certificate expires within this many days, the expired ones included, and uses the same number of days as the warning window of rule CRT-001. Without this parameter every server is listed and the window is 30 days.

```yaml
Type: System.Int32
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Port

The TCP port, the same for every server. 443 unless told otherwise.

```yaml
Type: System.Int32
DefaultValue: '443'
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TimeoutSeconds

How long to wait for each server to accept the connection, and then for each step of the handshake, before giving up on it. 10 seconds unless told otherwise.

```yaml
Type: System.Int32
DefaultValue: '10'
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

The names of the servers, as text or as a property named ComputerName, HostName or DnsName.

## OUTPUTS

### WinOpsAudit.TlsCertificate

One object per server, with the properties ComputerName, Port, Protocol (the TLS version agreed), Subject, Issuer, DnsNames, Thumbprint, SerialNumber, NotBefore, NotAfter, DaysLeft, Status, SignatureAlgorithm, KeyAlgorithm, KeySize, WeakReason, SentCount (how many certificates the server sent besides its own), ChainStatus, MissingCertificate (the subjects of the certificates the server should have sent, or the unknown issuer) and Findings. The default table shows ComputerName, Port, Subject, DaysLeft, Status, ChainStatus and Findings.

## NOTES

It does not check whether the names in the certificate match the server, whether the certificate has been revoked, or which TLS versions and ciphers the server accepts besides the one agreed. Why CRT-003 is judged from what the server sends, and not from whether this computer can build the chain, is explained in ADR 0003 of the project. These are audit rules CRT-001, CRT-002 and CRT-003.

## RELATED LINKS

- [Get-WinOpsAuditCertificate](Get-WinOpsAuditCertificate.md)
- [ADR 0003: judge the chain by what the server sends](https://github.com/zxxdev/winops-audit/blob/main/docs/adr/0003-chain-judged-by-what-the-server-sends.md)
- [Project on GitHub](https://github.com/zxxdev/winops-audit)
