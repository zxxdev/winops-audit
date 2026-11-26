---
document type: cmdlet
external help file: WinOpsAudit-help.xml
HelpUri: https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditUpdate.md
Locale: en-US
Module Name: WinOpsAudit
ms.date: 11/26/2026
PlatyPS schema version: 2024-05-01
title: Get-WinOpsAuditUpdate
---

# Get-WinOpsAuditUpdate

## SYNOPSIS

Lists the updates installed on this computer.

## SYNTAX

### __AllParameterSets

```
Get-WinOpsAuditUpdate [<CommonParameters>]
```

## ALIASES

This cmdlet has no aliases.

## DESCRIPTION

Returns one object per installed update, read from the CIM class Win32_QuickFixEngineering: its KB number, its kind (Update, Security Update...), when it was installed and by whom. The oldest come first; updates with no known date come before them.

Windows keeps the install date as text, in more than one format. It is turned into a date, and left empty when Windows does not record it, rather than guessed.

It only runs on Windows. Nothing is changed.

## EXAMPLES

### Example 1: List the installed updates

```powershell
Get-WinOpsAuditUpdate
```

### Example 2: Is a given update installed?

```powershell
Get-WinOpsAuditUpdate | Where-Object HotFixId -eq 'KB5001001'
```

No output means it is not installed.

### Example 3: The updates of the last 30 days

```powershell
Get-WinOpsAuditUpdate | Where-Object InstalledOn -gt (Get-Date).AddDays(-30)
```

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

This cmdlet takes no input from the pipeline.

## OUTPUTS

### WinOpsAudit.Update

One object per update, with the properties ComputerName, HotFixId, Description, InstalledOn and InstalledBy. The default table leaves out ComputerName and shows the date without the time.

## NOTES

Win32_QuickFixEngineering lists the updates of Windows itself installed through Windows Update or as packages. It does not list updates of other products (Office, for example) or of Microsoft Defender's definitions. Get-HotFix reads the same class; the tests check on Windows that both give the same updates and dates. This is part of audit rule INV-001.

## RELATED LINKS

- [Get-WinOpsAuditInventory](Get-WinOpsAuditInventory.md)
- [Project on GitHub](https://github.com/zxxdev/winops-audit)
