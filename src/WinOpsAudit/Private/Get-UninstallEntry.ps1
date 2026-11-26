function Get-UninstallEntry {
    <#
    .SYNOPSIS
    Reads the raw entries of one uninstall key of the registry.

    .DESCRIPTION
    Private helper: the only place the module reads the registry, so the tests can replace it.
    Programs register themselves under an Uninstall key to appear in "Installed apps". There are
    three places to look, one per view:

      Machine64  HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, 64-bit programs
      Machine32  the same key as 32-bit programs see it (WOW6432Node)
      User       the same key under HKCU: programs installed for the current user only

    The registry view is chosen explicitly, so the result does not depend on whether PowerShell
    itself runs as a 32-bit or a 64-bit process. Nothing is filtered here: the caller decides
    which entries are programs.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Machine64', 'Machine32', 'User')]
        [string] $View
    )

    $hive, $registryView = switch ($View) {
        'Machine64' { 'LocalMachine', 'Registry64' }
        'Machine32' { 'LocalMachine', 'Registry32' }
        'User' { 'CurrentUser', 'Default' }
    }
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $registryView)
    try {
        $uninstall = $base.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
        # A user who never installed anything just for themselves has no key: no entries.
        if (-not $uninstall) {
            return
        }
        try {
            foreach ($keyName in $uninstall.GetSubKeyNames()) {
                try {
                    $entry = $uninstall.OpenSubKey($keyName)
                } catch {
                    # An entry with a restrictive ACL must not hide the rest of the key.
                    Write-Warning "Skipped the uninstall entry '$keyName' ($View): $($_.Exception.Message)"
                    continue
                }
                if (-not $entry) {
                    continue
                }
                try {
                    [pscustomobject]@{
                        KeyName         = $keyName
                        DisplayName     = $entry.GetValue('DisplayName')
                        DisplayVersion  = $entry.GetValue('DisplayVersion')
                        Publisher       = $entry.GetValue('Publisher')
                        InstallDate     = $entry.GetValue('InstallDate')
                        SystemComponent = $entry.GetValue('SystemComponent')
                        ParentKeyName   = $entry.GetValue('ParentKeyName')
                        ReleaseType     = $entry.GetValue('ReleaseType')
                    }
                } finally {
                    $entry.Dispose()
                }
            }
        } finally {
            $uninstall.Dispose()
        }
    } finally {
        $base.Dispose()
    }
}
