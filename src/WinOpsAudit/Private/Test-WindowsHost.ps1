function Test-WindowsHost {
    <#
    .SYNOPSIS
    Tells whether this session runs on Windows.

    .DESCRIPTION
    Private helper: a function instead of reading $IsWindows directly, so the tests can pretend
    to be on Windows, or not, on any system.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $IsWindows
}
