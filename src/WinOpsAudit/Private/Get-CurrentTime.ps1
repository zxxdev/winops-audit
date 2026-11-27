function Get-CurrentTime {
    <#
    .SYNOPSIS
    Gives the current local time.

    .DESCRIPTION
    Private helper: the clock of the module. The tests replace it to set the time to a fixed
    moment, so "expires in 13 days" gives the same answer every day the tests run.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param()

    [datetime]::Now
}
