---
document type: cmdlet
external help file: WinOpsAudit-help.xml
HelpUri: https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditInventory.md
Locale: en-US
Module Name: WinOpsAudit
ms.date: 11/26/2026
PlatyPS schema version: 2024-05-01
title: Get-WinOpsAuditInventory
---

# Get-WinOpsAuditInventory

## SYNOPSIS

Describes this computer: hardware, operating system, domain and installed updates.

## SYNTAX

### __AllParameterSets

```
Get-WinOpsAuditInventory [<CommonParameters>]
```

## ALIASES

This cmdlet has no aliases.

## DESCRIPTION

Returns one object for the computer it runs on, read through CIM: who made it and which model it is, its serial number and firmware version, its processors and memory, its operating system, when it was installed and last started, the domain it belongs to, and how many updates are installed and when the last one was.

Every property is a plain value, so the object can be filtered, exported to CSV or JSON, or saved and compared with a later run. The list of updates itself comes from Get-WinOpsAuditUpdate.

If the updates cannot be read, the object is still returned with UpdateCount and LastUpdateInstalledOn empty, and an error says why: empty means unknown, not zero. If the computer, its firmware, its processors or its operating system cannot be read, the cmdlet stops with an error and returns nothing.

It only runs on Windows. Nothing is changed.

## EXAMPLES

### Example 1: Describe this computer

```powershell
Get-WinOpsAuditInventory
```

### Example 2: A few properties as a table

```powershell
Get-WinOpsAuditInventory | Format-Table ComputerName, OperatingSystem, MemoryGB, LastUpdateInstalledOn
```

### Example 3: Save it to compare later

```powershell
Get-WinOpsAuditInventory | Export-Csv -Path .\inventory.csv -NoTypeInformation
```

Every property is a single value, so each becomes one column of the CSV file.

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

### WinOpsAudit.Inventory

One object with the properties ComputerName, Domain, PartOfDomain, Manufacturer, Model, SerialNumber, BiosVersion, Processor, ProcessorCount, CoreCount, LogicalProcessorCount, MemoryGB, OperatingSystem, OSVersion, OSArchitecture, InstallDate, LastBootUpTime, UpdateCount and LastUpdateInstalledOn.

## NOTES

The data comes from the CIM classes Win32_ComputerSystem, Win32_OperatingSystem, Win32_BIOS, Win32_Processor and Win32_QuickFixEngineering. MemoryGB is the memory Windows can use (TotalPhysicalMemory), a little less than what is installed. This is audit rule INV-001.

## RELATED LINKS

- [Get-WinOpsAuditUpdate](Get-WinOpsAuditUpdate.md)
- [Get-WinOpsAuditSoftware](Get-WinOpsAuditSoftware.md)
- [Project on GitHub](https://github.com/zxxdev/winops-audit)
