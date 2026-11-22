# Contributing

Bug reports and suggestions are very welcome: please
[open an issue](https://github.com/zxxdev/winops-audit/issues/new/choose).
For security problems, follow [SECURITY.md](SECURITY.md) instead.

## How changes are made

Every change follows the same path, including my own:

1. An issue describes the change and its acceptance criteria.
2. Work happens on a branch named `<type>/<issue>-<summary>`, for example `feat/4-cert-expiry`.
3. Commits follow [Conventional Commits](https://www.conventionalcommits.org/):
   `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `build`, `ci`, `chore`.
4. A pull request closes the issue. CI must be green on Linux and Windows before it is merged.
5. Pull requests are squash-merged, so `main` keeps one commit per change.

## Running the checks

Requirements: PowerShell 7.4 or later, on Windows, Linux or macOS.

```powershell
./build.ps1                       # everything below, in this order
./build.ps1 -Task Bootstrap       # installs the pinned tools (current user only)
./build.ps1 -Task Lint            # PSScriptAnalyzer: any finding fails
./build.ps1 -Task Test            # Pester, with coverage; fails below 80%
./build.ps1 -Task Help            # builds the help file from docs/commands
./build.ps1 -Task HelpCheck       # Help, then fails if the result is not committed
```

Test results (JUnit) and coverage (JaCoCo) are written to `out/`.

## The module is read-only

WinOpsAudit audits and reports; it never changes the systems it audits. Every exported cmdlet uses
a verb that reads (`Get`, `Test`, `Find`, `Compare`...) or `Export`, which only writes the report
file you ask for. A test fails if any other verb is exported. A change that writes to an audited
system will not be accepted, however useful: see [ADR 0001](docs/adr/0001-read-only-module.md).

## Help

The help of each cmdlet is written in Markdown, in `docs/commands/WinOpsAudit/<Cmdlet>.md`, and
built into `src/WinOpsAudit/en-US/WinOpsAudit-help.xml` by `./build.ps1 -Task Help`. Commit both.
The tests check that every parameter has its description in the built help.

## Raising a tool version

The build tools are pinned in `build/requirements.psd1`. Dependabot cannot update them, so they are
raised by hand. The pull request must say that the module is the official one (its publisher and
project page) and that the version is at least 7 days old.
