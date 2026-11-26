function Assert-WindowsHost {
    <#
    .SYNOPSIS
    Stops the calling cmdlet with a clear error when it does not run on Windows.

    .DESCRIPTION
    Private helper. The inventory reads CIM and the registry, which only exist on Windows. On
    another system the cmdlet stops before reading anything, with the error id WindowsOnly,
    instead of failing later with "Get-CimInstance is not recognized".
    #>
    [CmdletBinding()]
    param(
        # The $PSCmdlet of the public cmdlet, so the error is reported as that cmdlet's.
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet] $Cmdlet
    )

    if (Test-WindowsHost) {
        return
    }
    $name = $Cmdlet.MyInvocation.MyCommand.Name
    $exception = [System.PlatformNotSupportedException]::new(
        "$name reads Windows data (CIM and the registry): run it on Windows.")
    $record = [System.Management.Automation.ErrorRecord]::new(
        $exception, 'WindowsOnly', [System.Management.Automation.ErrorCategory]::NotImplemented, $null)
    $Cmdlet.ThrowTerminatingError($record)
}
