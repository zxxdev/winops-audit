---
document type: cmdlet
external help file: WinOpsAudit-help.xml
HelpUri: https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditSoftware.md
Locale: en-US
Module Name: WinOpsAudit
ms.date: 11/26/2026
PlatyPS schema version: 2024-05-01
title: Get-WinOpsAuditSoftware
---

# Get-WinOpsAuditSoftware

## SYNOPSIS

Lists the programs installed on this computer.

## SYNTAX

### __AllParameterSets

```
Get-WinOpsAuditSoftware [[-Name] <string[]>] [<CommonParameters>]
```

## ALIASES

This cmdlet has no aliases.

## DESCRIPTION

Returns one object per installed program: its name, version, publisher and install date, whether it is a 64-bit or a 32-bit program, and whether it is installed for the whole computer or only for the current user.

The programs are read from the uninstall keys of the registry, the same place "Installed apps" in Windows Settings reads them from: the 64-bit and 32-bit keys of the computer and the key of the current user. It never queries the CIM class Win32_Product, which makes Windows check, and sometimes repair, every MSI installation. Entries that "Installed apps" hides are left out too: parts of other programs (SystemComponent), updates of other programs, and entries with no name.

If one of the keys cannot be read, the programs of the others are still returned and an error says which key failed.

It only runs on Windows. Nothing is changed.

## EXAMPLES

### Example 1: List the installed programs

```powershell
Get-WinOpsAuditSoftware
```

### Example 2: Find a program by name

```powershell
Get-WinOpsAuditSoftware -Name '*Java*'
```

Wildcards find every program whose name matches. An exact name that is not installed writes an error.

### Example 3: The 32-bit programs, exported to a file

```powershell
Get-WinOpsAuditSoftware | Where-Object Architecture -eq 'x86' | Export-Csv -Path .\software-x86.csv -NoTypeInformation
```

## PARAMETERS

### -Name

One or more program names. Wildcards are allowed, for example `*Java*`, and the case does not matter. An exact name that matches no installed program writes an error and the command goes on with the rest; a wildcard that matches nothing is not an error.

```yaml
Type: System.String[]
DefaultValue: '*'
SupportsWildcards: true
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
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

### None

This cmdlet takes no input from the pipeline.

## OUTPUTS

### WinOpsAudit.Software

One object per program, with the properties ComputerName, Name, Version, Publisher, InstallDate, Architecture (x64, x86, or empty for programs of the current user, whose key does not say), Scope (Machine or CurrentUser) and UninstallKey (the name of its registry key). The default table shows Name, Version, Publisher, Architecture and Scope.

## NOTES

Programs installed for other users who are not logged on are not listed: their part of the registry is only loaded while they are. Apps from the Microsoft Store are not listed either: they are not registered under the uninstall keys. Why the registry and not Win32_Product is explained in ADR 0002 of the project. This is audit rule INV-002.

## RELATED LINKS

- [Get-WinOpsAuditInventory](Get-WinOpsAuditInventory.md)
- [ADR 0002: installed software from the registry](https://github.com/zxxdev/winops-audit/blob/main/docs/adr/0002-software-from-the-registry.md)
- [Project on GitHub](https://github.com/zxxdev/winops-audit)
