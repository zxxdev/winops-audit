function Get-WinOpsAuditRule {
    # The help is written in docs/commands/WinOpsAudit/Get-WinOpsAuditRule.md and built into
    # this file by ./build.ps1 -Task Help.
    # .ExternalHelp WinOpsAudit-help.xml
    [CmdletBinding(HelpUri = 'https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditRule.md')]
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
        # Each rule once, even when patterns overlap ('AD-*', 'AD-001') or the pipeline repeats ids.
        $sent = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    process {
        foreach ($pattern in $Id) {
            $found = $false
            foreach ($rule in $rules) {
                if ($rule.Id -notlike $pattern) { continue }
                # The id exists: excluded by -Area is not "not found".
                $found = $true
                if ($Area -and $rule.Area -notin $Area) { continue }
                if (-not $sent.Add($rule.Id)) { continue }
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
