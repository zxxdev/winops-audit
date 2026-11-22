---
document type: cmdlet
external help file: WinOpsAudit-help.xml
HelpUri: https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditRule.md
Locale: en-US
Module Name: WinOpsAudit
ms.date: 11/23/2026
PlatyPS schema version: 2024-05-01
title: Get-WinOpsAuditRule
---

# Get-WinOpsAuditRule

## SYNOPSIS

Lists the audit rules WinOpsAudit knows about.

## SYNTAX

### __AllParameterSets

```
Get-WinOpsAuditRule [[-Id] <string[]>] [-Area <string[]>] [<CommonParameters>]
```

## ALIASES

This cmdlet has no aliases.

## DESCRIPTION

Returns one object per audit rule: its id, the area it audits, what it looks for, how serious a finding is, and whether it is available yet or still planned. The objects can be filtered, sorted and exported like any other PowerShell output.

Nothing is audited and nothing is changed: this only reads the catalog that ships with the module.

## EXAMPLES

### Example 1: List every rule

```powershell
Get-WinOpsAuditRule
```

### Example 2: The certificate rules as a table

```powershell
Get-WinOpsAuditRule -Area Certificates | Format-Table Id, Severity, Title
```

### Example 3: The serious Active Directory rules

```powershell
Get-WinOpsAuditRule -Id 'AD-*' | Where-Object Severity -eq 'High'
```

Wildcards in `-Id` select several rules; `Where-Object` then keeps the ones with high severity.

## PARAMETERS

### -Area

Only the rules of these areas: Inventory, Certificates, FolderPermissions or ActiveDirectory.

```yaml
Type: System.String[]
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

### -Id

One or more rule ids. Wildcards are allowed, for example `AD-*`. An exact id that matches no rule writes an error and the command goes on with the rest; a wildcard that matches nothing is not an error.

```yaml
Type: System.String[]
DefaultValue: '*'
SupportsWildcards: true
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
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

### System.String[]

Rule ids, from the pipeline or from the Id property of the objects in it.

## OUTPUTS

### WinOpsAudit.Rule

One object per rule, with the properties Id, Area, Title, Severity, Status and Session (the roadmap session that brings the rule).

## NOTES

The catalog is in `Data/Rules.psd1` inside the module. A rule is Planned until its cmdlet, tests and help are written; then it is Available.

## RELATED LINKS

- [Project on GitHub](https://github.com/zxxdev/winops-audit)
