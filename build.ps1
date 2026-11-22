<#
.SYNOPSIS
Builds and checks WinOpsAudit: the same steps locally and in CI.

.DESCRIPTION
Tasks, run in the order given:
  Bootstrap  Installs the tools pinned in build/requirements.psd1 (current user only).
  Lint       PSScriptAnalyzer over the module, the tests and this script. Any finding fails.
  Test       Pester, with test results (JUnit) and code coverage (JaCoCo) in ./out.
             Fails below the coverage target.
  Help       Writes the command reference in docs/commands from the comment-based help.
  HelpCheck  Like Help, then fails if docs/commands differs from what is committed.
  All        Bootstrap, Lint, Test and HelpCheck.

.EXAMPLE
./build.ps1 -Task Lint, Test
#>
[CmdletBinding()]
param(
    [ValidateSet('Bootstrap', 'Lint', 'Test', 'Help', 'HelpCheck', 'All')]
    [string[]] $Task = 'All'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = $PSScriptRoot
$manifest = Join-Path $root 'src/WinOpsAudit/WinOpsAudit.psd1'
$out = Join-Path $root 'out'
$coverageTarget = 80

function Import-Tool {
    param([Parameter(Mandatory)] [string] $Name)
    $version = (Import-PowerShellDataFile (Join-Path $root 'build/requirements.psd1'))[$Name]
    Import-Module -Name $Name -RequiredVersion $version -Force
}

function Invoke-Bootstrap {
    $requirements = Import-PowerShellDataFile (Join-Path $root 'build/requirements.psd1')
    foreach ($name in $requirements.Keys | Sort-Object) {
        $version = $requirements[$name]
        if (Get-Module -ListAvailable -Name $name | Where-Object Version -EQ $version) {
            Write-Information "$name $version is already installed." -InformationAction Continue
            continue
        }
        Write-Information "Installing $name $version from the PowerShell Gallery." -InformationAction Continue
        Install-PSResource -Name $name -Version $version -Repository PSGallery -Scope CurrentUser -TrustRepository -Quiet
    }
}

function Invoke-Lint {
    Import-Tool PSScriptAnalyzer
    $settings = Join-Path $root 'PSScriptAnalyzerSettings.psd1'
    $paths = (Join-Path $root 'src'), (Join-Path $root 'tests'), (Join-Path $root 'build.ps1')
    $findings = $paths | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings $settings }
    if ($findings) {
        $table = $findings | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message | Out-String
        Write-Information $table -InformationAction Continue
        throw "PSScriptAnalyzer found $(@($findings).Count) problem(s)."
    }
    Write-Information 'PSScriptAnalyzer: no findings.' -InformationAction Continue
}

function Invoke-Test {
    Import-Tool Pester
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $root 'tests'
    $config.Run.Throw = $true
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'JUnitXml'
    $config.TestResult.OutputPath = Join-Path $out 'test-results.xml'
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = Join-Path $root 'src'
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = Join-Path $out 'coverage.xml'
    $config.CodeCoverage.CoveragePercentTarget = $coverageTarget
    $result = Invoke-Pester -Configuration $config
    $coverage = [math]::Round($result.CodeCoverage.CoveragePercent, 1)
    if ($coverage -lt $coverageTarget) {
        throw "Code coverage is $coverage%, below the $coverageTarget% target."
    }
}

function Invoke-Help {
    # PlatyPS reads optional help properties that may not exist, which strict mode turns into
    # errors. Strict mode stays on everywhere else; this only affects this function's scope.
    Set-StrictMode -Off
    Import-Tool Microsoft.PowerShell.PlatyPS
    Import-Module $manifest -Force

    # The Markdown pages are the source of the help: one per cmdlet (Verb-Noun.md).
    $pages = @(Get-ChildItem -Path (Join-Path $root 'docs/commands/WinOpsAudit') -Filter '*-*.md')

    # Bring them in line with the code (new or changed parameters, syntax).
    foreach ($page in $pages) {
        Update-MarkdownCommandHelp -Path $page.FullName -NoBackup | Out-Null
    }

    # A new parameter arrives as a placeholder for its description: it must be written.
    $placeholders = $pages | Select-String -Pattern '{{' -SimpleMatch
    if ($placeholders) {
        $placeholders | ForEach-Object { Write-Information "$($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -InformationAction Continue }
        throw 'The help has placeholders to fill in (above).'
    }

    # Build the help file Get-Help reads (MAML) into the module.
    $help = $pages | ForEach-Object { Import-MarkdownCommandHelp -Path $_.FullName }
    $staging = Join-Path $out 'help'
    Remove-Item -Path $staging -Recurse -Force -ErrorAction Ignore
    Export-MamlCommandHelp -CommandHelp $help -OutputFolder $staging -Force | Out-Null
    $maml = Get-ChildItem -Path $staging -Recurse -Filter '*.xml' | Select-Object -First 1
    $target = Join-Path $root 'src/WinOpsAudit/en-US'
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item -LiteralPath $maml.FullName -Destination (Join-Path $target 'WinOpsAudit-help.xml') -Force
    Write-Information 'Help built into src/WinOpsAudit/en-US/WinOpsAudit-help.xml.' -InformationAction Continue
}

function Invoke-HelpCheck {
    Invoke-Help
    $paths = 'docs/commands', 'src/WinOpsAudit/en-US'
    git -C $root add --intent-to-add -- $paths
    git -C $root diff --exit-code --stat -- $paths
    if ($LASTEXITCODE -ne 0) {
        throw 'The help is out of date: run ./build.ps1 -Task Help and commit the result.'
    }
}

$steps = if ($Task -contains 'All') { 'Bootstrap', 'Lint', 'Test', 'HelpCheck' } else { $Task }
foreach ($step in $steps) {
    Write-Information "== $step" -InformationAction Continue
    & "Invoke-$step"
}
