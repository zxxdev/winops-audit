function Get-CimData {
    <#
    .SYNOPSIS
    Reads every instance of one CIM class on this computer.

    .DESCRIPTION
    Private helper: the only place the module calls Get-CimInstance. The tests replace it with
    prepared data, so the logic around it is tested on Linux too, where CIM does not exist. Any
    error stops: the caller decides whether that ends the cmdlet or only one part of it.
    #>
    [CmdletBinding()]
    [OutputType('Microsoft.Management.Infrastructure.CimInstance')]
    param(
        [Parameter(Mandatory)]
        [string] $ClassName
    )

    Get-CimInstance -ClassName $ClassName -ErrorAction Stop
}
