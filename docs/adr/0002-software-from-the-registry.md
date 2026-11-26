# 0002. Read installed software from the registry, not from Win32_Product

- **Status:** accepted
- **Date:** 2026-11-26

## Context

`Get-WinOpsAuditSoftware` has to list the programs installed on a computer. Windows has no single
place that knows them all: MSI installers, other installers (Inno Setup, NSIS, custom ones), per-user
installs and Store apps each register in their own way. The module is read-only
([ADR 0001](0001-read-only-module.md)) and is meant to run on production servers.

## Options

1. **The CIM class `Win32_Product`.** The obvious one, and the one most old scripts use. It only
   knows MSI installations, and querying it makes the Windows Installer check every one of them:
   it is slow (minutes on a busy server) and, when a check fails, it starts a repair, which leaves
   event 1035 in the Application log and can change files. A query that may change the system
   breaks ADR 0001.
2. **The uninstall keys of the registry.** Every installer that wants to appear in "Installed apps"
   writes an entry under `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`: in the 64-bit view,
   in the 32-bit view (`WOW6432Node`) and in the current user's hive. It is what Windows Settings
   reads, it is fast and reading it changes nothing.
3. **`Get-Package` (PackageManagement).** Combines several sources, the registry among them, but it
   is not part of PowerShell 7, and adds a dependency for little more than option 2.

## Decision

Option 2. The registry is opened in each view explicitly (64-bit, 32-bit, current user), so the
result does not depend on whether PowerShell runs as a 32-bit or 64-bit process. The entries that
"Installed apps" hides are left out the same way: no `DisplayName`, `SystemComponent = 1`, a
`ParentKeyName` (an update of another program) or a `ReleaseType` of an update.

## Consequences

- Fast and read-only: it can run on any server, any time.
- What the uninstall keys do not hold is not listed: Store apps, programs installed for other users
  who are not logged on (their hive is not loaded), and portable programs that were never
  installed. The help says so.
- An installer can write a wrong or empty `DisplayVersion` or `InstallDate`; the values are reported
  as found, and an install date that is not a date is left empty rather than guessed.
- The filter is a copy of what Windows Settings does, not a documented contract. If an entry shows
  up there and not here, or the other way round, the filter is what to look at.
