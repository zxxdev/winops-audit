---
document type: cmdlet
external help file: WinOpsAudit-help.xml
HelpUri: https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditCertificate.md
Locale: en-US
Module Name: WinOpsAudit
ms.date: 11/27/2026
PlatyPS schema version: 2024-05-01
title: Get-WinOpsAuditCertificate
---

# Get-WinOpsAuditCertificate

## SYNOPSIS

Lists the certificates in the certificate stores of this computer, with when they expire and what is wrong with them.

## SYNTAX

### __AllParameterSets

```
Get-WinOpsAuditCertificate [-StoreLocation <string>] [-StoreName <string[]>]
 [-ExpiringInDays <int>] [<CommonParameters>]
```

## ALIASES

This cmdlet has no aliases.

## DESCRIPTION

Returns one object per certificate in the stores asked for, LocalMachine\My unless told otherwise: the store it is in, its subject, issuer and DNS names, its validity dates, how many whole days it has left, its signature algorithm and key, and the audit rules it breaks.

Two rules are checked:

- CRT-001: the certificate has expired, or expires within the warning window. The window is the value of ExpiringInDays, or 30 days without it.
- CRT-002: it is signed with MD2, MD4, MD5 or SHA-1, or its key is too short: RSA under 2048 bits, EC under 256, or DSA of any size. The signature of a self-signed certificate, such as a root, is not checked: nobody verifies it, because a root is trusted for being in the store. Its key is checked like any other.

With ExpiringInDays, only the certificates that expire within that many days come out, the expired ones included. The certificates that expire first come first.

The stores are opened read-only, and only if they exist. If one store cannot be opened, the certificates of the others are still returned and an error says which store failed.

It only runs on Windows. Nothing is changed.

## EXAMPLES

### Example 1: The certificates of the computer

```powershell
Get-WinOpsAuditCertificate
```

Lists the certificates in LocalMachine\My, where the certificates of the services of the computer (IIS, RDP, LDAPS, WinRM...) usually are.

### Example 2: The certificates that expire within 30 days

```powershell
Get-WinOpsAuditCertificate -ExpiringInDays 30
```

The expired ones come out too, with a negative DaysLeft.

### Example 3: Weak certificates in several stores

```powershell
Get-WinOpsAuditCertificate -StoreName My, WebHosting, 'Remote Desktop' | Where-Object Findings -match 'CRT-002' | Select-Object Store, Subject, WeakReason
```

### Example 4: The trusted roots of the current user that expire this year

```powershell
Get-WinOpsAuditCertificate -StoreLocation CurrentUser -StoreName Root -ExpiringInDays 365
```

## PARAMETERS

### -ExpiringInDays

Lists only the certificates that expire within this many days, the expired ones included, and uses the same number of days as the warning window of rule CRT-001. A certificate with 13.9 days left counts as 13. Without this parameter every certificate is listed and the window is 30 days.

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

### -StoreLocation

Whose stores to read: LocalMachine, the stores of the computer, or CurrentUser, the stores of the user running the command.

```yaml
Type: System.String
DefaultValue: LocalMachine
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
AcceptedValues:
- LocalMachine
- CurrentUser
HelpMessage: ''
```

### -StoreName

One or more stores to read. My is the Personal store, where most service certificates are; WebHosting is where IIS can keep its own; Remote Desktop holds the certificate of RDP; Root and CA hold the trusted roots and the intermediate authorities; TrustedPublisher, the publishers trusted to sign code.

```yaml
Type: System.String[]
DefaultValue: My
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
AcceptedValues:
- My
- WebHosting
- Remote Desktop
- Root
- CA
- TrustedPublisher
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

This cmdlet takes no input from the pipeline.

## OUTPUTS

### WinOpsAudit.Certificate

One object per certificate, with the properties ComputerName, Store, Subject, Issuer, DnsNames, FriendlyName, Thumbprint, SerialNumber, NotBefore, NotAfter, DaysLeft, Status (Valid, Expiring, Expired or NotYetValid), SignatureAlgorithm, KeyAlgorithm (RSA, EC or DSA), KeySize, WeakReason, HasPrivateKey and Findings (the ids of the rules it breaks, separated by "; "). The default table shows Store, Subject, NotAfter, DaysLeft, Status and Findings.

## NOTES

It does not check whether a certificate has been revoked, whether its chain is trusted on this computer, or whether its names match the service that uses it. To see what a server sends to its clients, including the intermediate certificates (rule CRT-003), use Get-WinOpsAuditTlsCertificate. These are audit rules CRT-001 and CRT-002.

## RELATED LINKS

- [Get-WinOpsAuditTlsCertificate](Get-WinOpsAuditTlsCertificate.md)
- [Project on GitHub](https://github.com/zxxdev/winops-audit)
