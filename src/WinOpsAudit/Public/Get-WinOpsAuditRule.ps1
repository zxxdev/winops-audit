function Get-WinOpsAuditRule {
    <#
    .SYNOPSIS
    Lists the audit rules WinOpsAudit knows about.

    .DESCRIPTION
    Returns one object per audit rule: its id, the area it audits, what it looks for, how
    serious a finding is, and whether it is available yet or still planned. The objects can be
    filtered, sorted and exported like any other PowerShell output.

    Nothing is audited and nothing is changed: this only reads the catalog that ships with the
    module.

    .PARAMETER Id
    One or more rule ids. Wildcards are allowed, for example 'AD-*'.

    .PARAMETER Area
    Only the rules of these areas: Inventory, Certificates, FolderPermissions or
    ActiveDirectory.

    .EXAMPLE
    Get-WinOpsAuditRule

    Lists every rule.

    .EXAMPLE
    Get-WinOpsAuditRule -Area Certificates | Format-Table Id, Severity, Title

    Shows the certificate rules as a table.

    .EXAMPLE
    Get-WinOpsAuditRule -Id 'AD-*' | Where-Object Severity -eq 'High'

    Lists the Active Directory rules whose findings are serious.

    .OUTPUTS
    WinOpsAudit.Rule

    .LINK
    https://github.com/zxxdev/winops-audit
    #>
    [CmdletBinding()]
    [OutputType('WinOpsAudit.Rule')]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Id = '*',

        [ValidateSet('Inventory', 'Certificates', 'FolderPermissions', 'ActiveDirectory')]
        [string[]] $Area
    )

    begin {
        $rules = Get-RuleData
    }

    process {
        foreach ($pattern in $Id) {
            $found = $false
            foreach ($rule in $rules) {
                if ($rule.Id -notlike $pattern) { continue }
                if ($Area -and $rule.Area -notin $Area) { continue }
                $found = $true
                [pscustomobject]@{
                    PSTypeName = 'WinOpsAudit.Rule'
                    Id         = $rule.Id
                    Area       = $rule.Area
                    Title      = $rule.Title
                    Severity   = $rule.Severity
                    Status     = $rule.Status
                    Session    = $rule.Session
                }
            }
            # An exact id that matches nothing is a mistake; a wildcard may match nothing.
            if (-not $found -and -not [WildcardPattern]::ContainsWildcardCharacters($pattern)) {
                $message = "No audit rule with id '$pattern'. Run Get-WinOpsAuditRule to see them all."
                Write-Error -Message $message -Category ObjectNotFound -TargetObject $pattern
            }
        }
    }
}
