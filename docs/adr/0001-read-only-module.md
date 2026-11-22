# 0001. Keep the module read-only

- **Status:** accepted
- **Date:** 2026-11-23

## Context

WinOpsAudit looks for problems an administrator would otherwise check by hand: certificates about
to expire, folders with broken inheritance, Active Directory accounts nobody uses. For most of them a
fix is easy to imagine: disable the account, restore the inheritance. The module will be run with
privileged accounts, against production servers and the directory, often from a scheduled task.

## Options

1. **Audit and fix.** One module that finds a problem and can also correct it (with `-WhatIf` and
   `-Confirm`). Saves a step, but every run needs write permissions, a wrong rule or a false positive
   changes production, and nobody can run it "just to see" without fear.
2. **Read-only.** The module only reads and reports, as objects. A person decides what to change,
   with the report in front of them, using the tools they already trust.
3. **Read-only by default, fixes behind a switch.** Looks like a middle ground, but the code that
   writes is still in the module, needs the same permissions to be useful and the same review as
   option 1.

## Decision

Option 2: the module never changes the systems it audits. It exports only cmdlets with verbs that
read (`Get`, `Test`, `Find`, `Compare`...) or `Export`, which writes nothing but the report file the
user asks for. A test fails if a cmdlet with any other verb is ever exported.

## Consequences

- It can run with read-only accounts and in production without asking for a change window.
- A finding is something to look at, not something already done: the report has to say clearly
  what was found, where, and what "could not be checked" means.
- Some users will want the fix too. That is a separate tool, and this ADR is where to point them.
- A rule that needs write access to *test* something (for example, creating a file to see if a
  share is writable) is out of scope, even if it would be more accurate.
