function Test-InstalledProgram {
    <#
    .SYNOPSIS
    Tells whether an uninstall entry is a program a person would recognise as installed.

    .DESCRIPTION
    Private helper. The uninstall keys hold more than programs. The same entries Windows leaves
    out of "Installed apps" are left out here:

      - no DisplayName: nothing to show;
      - SystemComponent = 1: a part of another program, hidden on purpose;
      - ParentKeyName: an update or a module of another program, listed under it;
      - ReleaseType of an update (Update, Hotfix, Security Update...).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [psobject] $Entry
    )

    if ([string]::IsNullOrWhiteSpace($Entry.DisplayName)) {
        return $false
    }
    if ($Entry.SystemComponent -eq 1) {
        return $false
    }
    if ($Entry.ParentKeyName) {
        return $false
    }
    $updateTypes = 'Update', 'Hotfix', 'Security Update', 'Update Rollup', 'Service Pack'
    if ($Entry.ReleaseType -in $updateTypes) {
        return $false
    }
    $true
}
