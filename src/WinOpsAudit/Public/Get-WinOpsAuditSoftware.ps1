function Get-WinOpsAuditSoftware {
    # The help is written in docs/commands/WinOpsAudit/Get-WinOpsAuditSoftware.md and built into
    # this file by ./build.ps1 -Task Help.
    # .ExternalHelp WinOpsAudit-help.xml
    [CmdletBinding(HelpUri = 'https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditSoftware.md')]
    [OutputType('WinOpsAudit.Software')]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name = '*'
    )

    Assert-WindowsHost -Cmdlet $PSCmdlet

    # Read from the uninstall keys, never from Win32_Product: querying that class makes Windows
    # check, and sometimes repair, every MSI installation (ADR 0002).
    $views = [ordered]@{
        Machine64 = @{ Architecture = 'x64'; Scope = 'Machine' }
        Machine32 = @{ Architecture = 'x86'; Scope = 'Machine' }
        # Installed for the current user only; the key does not say for which architecture.
        User      = @{ Architecture = $null; Scope = 'CurrentUser' }
    }
    $computerName = [Environment]::MachineName
    $programs = foreach ($view in $views.Keys) {
        try {
            $entries = @(Get-UninstallEntry -View $view -ErrorAction Stop)
        } catch {
            # One key that cannot be read does not hide the others: say so and go on.
            $message = "Could not read the $view uninstall key: $($_.Exception.Message)"
            Write-Error -Message $message -Category ReadError -TargetObject $view
            continue
        }
        foreach ($entry in $entries) {
            if (-not (Test-InstalledProgram -Entry $entry)) {
                continue
            }
            [pscustomobject]@{
                PSTypeName   = 'WinOpsAudit.Software'
                ComputerName = $computerName
                Name         = "$($entry.DisplayName)".Trim()
                Version      = $entry.DisplayVersion
                Publisher    = $entry.Publisher
                InstallDate  = ConvertFrom-WindowsDate $entry.InstallDate
                Architecture = $views[$view].Architecture
                Scope        = $views[$view].Scope
                UninstallKey = $entry.KeyName
            }
        }
    }

    foreach ($pattern in $Name) {
        # An exact name that matches nothing is worth an error; a wildcard may match nothing.
        if ([WildcardPattern]::ContainsWildcardCharacters($pattern)) {
            continue
        }
        if (-not ($programs | Where-Object Name -Like $pattern)) {
            $message = "No installed program named '$pattern'. Use wildcards, for example '*$pattern*'."
            Write-Error -Message $message -Category ObjectNotFound -TargetObject $pattern
        }
    }
    # Each program once, even when the patterns overlap. Not sorted by Version: it is text, and
    # "10.0" would come before "9.0".
    $programs |
        Where-Object { $program = $_; $Name.Where({ $program.Name -like $_ }, 'First') } |
        Sort-Object -Property Name, Architecture, Scope
}
