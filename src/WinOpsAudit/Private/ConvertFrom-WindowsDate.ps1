function ConvertFrom-WindowsDate {
    <#
    .SYNOPSIS
    Turns a date as Windows stores it in text into a DateTime, or $null.

    .DESCRIPTION
    Private helper. Windows keeps some dates as text, in more than one format:

      yyyyMMdd           InstallDate of the uninstall keys (20261112)
      M/d/yyyy           InstalledOn of Win32_QuickFixEngineering (11/12/2026), whatever the
                         language of the system
      16 hex digits      InstalledOn on some older systems: a FILETIME (01dc5a8f3e2b4000)

    A value that is already a DateTime is returned as it is: on Windows, the type data of
    PowerShell turns InstalledOn of Win32_QuickFixEngineering into a date before the module sees
    it. Anything else, or nothing, gives $null: an unknown date is reported as unknown, not
    guessed.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [object] $Value
    )

    if ($Value -is [datetime]) {
        return $Value
    }
    $text = "$Value".Trim()
    if (-not $text) {
        return $null
    }
    $date = [datetime]::MinValue
    $formats = [string[]]@('yyyyMMdd', 'M/d/yyyy')
    $invariant = [cultureinfo]::InvariantCulture
    if ([datetime]::TryParseExact($text, $formats, $invariant, 'None', [ref] $date)) {
        return $date
    }
    if ($text -match '^[0-9a-fA-F]{16}$') {
        try {
            return [datetime]::FromFileTime([Convert]::ToInt64($text, 16))
        } catch [System.ArgumentOutOfRangeException] {
            return $null
        }
    }
    $null
}
