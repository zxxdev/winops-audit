function Get-WinOpsAuditUpdate {
    # The help is written in docs/commands/WinOpsAudit/Get-WinOpsAuditUpdate.md and built into
    # this file by ./build.ps1 -Task Help.
    # .ExternalHelp WinOpsAudit-help.xml
    [CmdletBinding(HelpUri = 'https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditUpdate.md')]
    [OutputType('WinOpsAudit.Update')]
    param()

    Assert-WindowsHost -Cmdlet $PSCmdlet
    try {
        $fixes = @(Get-CimData -ClassName 'Win32_QuickFixEngineering')
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    $updates = foreach ($fix in $fixes) {
        [pscustomobject]@{
            PSTypeName   = 'WinOpsAudit.Update'
            ComputerName = $fix.CSName
            HotFixId     = $fix.HotFixID
            Description  = $fix.Description
            # Text in the class, in more than one format; $null when Windows does not say.
            InstalledOn  = ConvertFrom-WindowsDate $fix.InstalledOn
            InstalledBy  = $fix.InstalledBy
        }
    }
    # Oldest first; updates with no known date go first.
    $updates | Sort-Object -Property InstalledOn, HotFixId
}
