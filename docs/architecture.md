# Architecture

WinOpsAudit is a PowerShell 7 script module. This page shows how it is put together and how it is
built; it grows with the module.

## The module

```mermaid
flowchart LR
    user([Administrator]) -->|Get-WinOpsAuditRule| public
    subgraph module [WinOpsAudit]
        manifest[WinOpsAudit.psd1<br/>version, exports] --> root[WinOpsAudit.psm1<br/>loads the files]
        root --> public[Public/<br/>one file per cmdlet]
        root --> private[Private/<br/>helpers, not exported]
        public --> private
        private --> data[(Data/Rules.psd1<br/>rule catalog)]
        help[en-US/WinOpsAudit-help.xml] -.->|Get-Help| public
    end
    public -->|objects| out([Format-Table, Export-Csv,<br/>other scripts])
```

- **Manifest (`WinOpsAudit.psd1`).** The module's card: its version, the PowerShell it needs (7.4 or
  later) and the cmdlets it exports. PowerShell reads it before loading anything.
- **Public and private.** `Public/` holds the cmdlets people use, one per file; `Private/` holds
  helpers that are not exported and can change freely.
- **Objects, not text.** Cmdlets return objects with a type name (`WinOpsAudit.Rule`), never
  formatted text: the caller decides whether it becomes a table, a CSV or input for another script.
- **Read-only.** No cmdlet changes anything ([ADR 0001](adr/0001-read-only-module.md)).

## The build

```mermaid
flowchart LR
    md[docs/commands/*.md<br/>help, written by hand] -->|Help| maml[en-US/WinOpsAudit-help.xml]
    src[src/] -->|Lint| psa[PSScriptAnalyzer]
    src -->|Test| pester[Pester: results + coverage]
    maml --> pester
    maml -->|HelpCheck| diff{same as committed?}
```

`build.ps1` runs the same steps locally and in CI, on Linux and Windows. The tools it uses are
pinned in `build/requirements.psd1`.
