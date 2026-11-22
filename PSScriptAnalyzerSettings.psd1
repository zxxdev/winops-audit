@{
    # Every default rule, plus the ones that keep the code consistent. A warning fails the build
    # just like an error (see build.ps1).
    IncludeDefaultRules = $true
    Severity            = @('Error', 'Warning', 'Information')
    Rules               = @{
        PSUseCompatibleSyntax      = @{ Enable = $true; TargetVersions = @('7.4') }
        PSPlaceOpenBrace           = @{ Enable = $true; OnSameLine = $true }
        PSPlaceCloseBrace          = @{ Enable = $true; NoEmptyLineBefore = $true }
        PSUseConsistentIndentation = @{ Enable = $true; IndentationSize = 4; Kind = 'space' }
        PSUseConsistentWhitespace  = @{ Enable = $true; CheckPipeForRedundantWhitespace = $true }
        PSAlignAssignmentStatement = @{ Enable = $true; CheckHashtable = $true }
        PSUseCorrectCasing         = @{ Enable = $true }
        PSAvoidUsingCmdletAliases  = @{ Enable = $true }
    }
}
