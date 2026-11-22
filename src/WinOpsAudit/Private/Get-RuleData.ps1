function Get-RuleData {
    <#
    .SYNOPSIS
    Reads the rule catalog that ships with the module (Data/Rules.psd1).

    .DESCRIPTION
    Private helper: not exported. Returns the rules as hashtables, in the order of the file.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $path = Join-Path -Path $PSScriptRoot -ChildPath '../Data/Rules.psd1'
    (Import-PowerShellDataFile -LiteralPath $path).Rules
}
