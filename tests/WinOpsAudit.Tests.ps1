BeforeAll {
    $manifest = Join-Path $PSScriptRoot '../src/WinOpsAudit/WinOpsAudit.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module WinOpsAudit -ErrorAction Ignore
}

Describe 'The module' {
    It 'has a valid manifest' {
        $info = Test-ModuleManifest -Path $manifest
        $info.Name | Should -Be 'WinOpsAudit'
        $info.Version | Should -BeOfType [version]
    }

    It 'exports exactly the cmdlets the manifest lists' {
        $listed = (Import-PowerShellDataFile $manifest).FunctionsToExport | Sort-Object
        $exported = (Get-Command -Module WinOpsAudit).Name | Sort-Object
        $exported | Should -Be $listed
    }

    It 'keeps its helpers private' {
        $helpers = Get-ChildItem -Path (Join-Path $PSScriptRoot '../src/WinOpsAudit/Private') -Filter '*.ps1'
        $helpers.Count | Should -BeGreaterThan 0
        foreach ($helper in $helpers) {
            Get-Command -Module WinOpsAudit -Name $helper.BaseName -ErrorAction Ignore |
                Should -BeNullOrEmpty -Because "$($helper.BaseName) is a private helper"
        }
    }

    It 'is read-only: every exported cmdlet uses a verb that does not change anything' {
        $readOnly = 'Get', 'Test', 'Find', 'Export', 'Compare', 'Measure', 'Search', 'Resolve'
        foreach ($command in Get-Command -Module WinOpsAudit) {
            $command.Verb | Should -BeIn $readOnly -Because "$($command.Name) must not change anything"
        }
    }

    It 'documents every exported cmdlet: synopsis, description, an example and each parameter' {
        foreach ($command in Get-Command -Module WinOpsAudit) {
            $help = Get-Help $command.Name -Full
            $help.Synopsis | Should -Not -BeNullOrEmpty -Because "$($command.Name) needs a synopsis"
            $help.Description.Text | Should -Not -BeNullOrEmpty -Because "$($command.Name) needs a description"
            @($help.Examples.Example).Count | Should -BeGreaterThan 0 -Because "$($command.Name) needs an example"
            $common = [System.Management.Automation.PSCmdlet]::CommonParameters
            foreach ($name in $command.Parameters.Keys | Where-Object { $_ -notin $common }) {
                $parameter = $help.Parameters.Parameter | Where-Object Name -EQ $name
                $parameter.Description.Text | Should -Not -BeNullOrEmpty -Because "-$name of $($command.Name) needs a description"
            }
        }
    }
}

Describe 'Get-WinOpsAuditRule' {
    It 'returns rule objects, not text' {
        $rules = Get-WinOpsAuditRule
        $rules.Count | Should -BeGreaterThan 0
        $rules[0].PSObject.TypeNames | Should -Contain 'WinOpsAudit.Rule'
        $rules[0].PSObject.Properties.Name | Should -Be 'Id', 'Area', 'Title', 'Severity', 'Status', 'Session'
    }

    It 'gives every rule a unique id, a known area, a severity and a status' {
        $rules = Get-WinOpsAuditRule
        ($rules.Id | Sort-Object -Unique).Count | Should -Be $rules.Count
        $rules.Area | Should -BeIn 'Inventory', 'Certificates', 'FolderPermissions', 'ActiveDirectory'
        $rules.Severity | Should -BeIn 'Info', 'Low', 'Medium', 'High'
        $rules.Status | Should -BeIn 'Planned', 'Available'
    }

    It 'filters by area' {
        $rules = Get-WinOpsAuditRule -Area Certificates
        $rules.Count | Should -BeGreaterThan 0
        $rules.Area | Should -Be (@('Certificates') * $rules.Count)
    }

    It 'filters by id with wildcards, and takes ids from the pipeline' {
        (Get-WinOpsAuditRule -Id 'AD-*').Id | Should -Be 'AD-001', 'AD-002', 'AD-003', 'AD-004'
        (Get-WinOpsAuditRule -Id 'CRT-00?').Id | Should -Be 'CRT-001', 'CRT-002', 'CRT-003'
        ('CRT-001', 'ACL-002' | Get-WinOpsAuditRule).Id | Should -Be 'CRT-001', 'ACL-002'
    }

    It 'returns each rule once, even when the ids overlap or repeat' {
        (Get-WinOpsAuditRule -Id 'AD-*', 'AD-001').Id | Should -Be 'AD-001', 'AD-002', 'AD-003', 'AD-004'
        ('CRT-001', 'crt-001' | Get-WinOpsAuditRule).Id | Should -Be 'CRT-001'
    }

    It 'combines -Id and -Area, and an id left out by -Area is not an error' {
        $rules = Get-WinOpsAuditRule -Id 'CRT-001', 'INV-001' -Area Inventory -ErrorVariable problems -ErrorAction SilentlyContinue
        $rules.Id | Should -Be 'INV-001'
        $problems.Count | Should -Be 0
    }

    It 'writes an error for an exact id that does not exist, and goes on with the rest' {
        $rules = Get-WinOpsAuditRule -Id 'NOPE-1', 'CRT-001' -ErrorVariable problems -ErrorAction SilentlyContinue
        $rules.Id | Should -Be 'CRT-001'
        $problems.Count | Should -Be 1
        $problems[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
    }

    It 'writes no error when a wildcard matches nothing' {
        Get-WinOpsAuditRule -Id 'NOPE-*' -ErrorVariable problems -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        $problems.Count | Should -Be 0
    }

    It 'agrees with the other places that list the areas and the rules' {
        $command = Get-Command Get-WinOpsAuditRule
        $validAreas = $command.Parameters['Area'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            ForEach-Object ValidValues
        $rules = Get-WinOpsAuditRule
        ($rules.Area | Sort-Object -Unique) | Should -Be ($validAreas | Sort-Object)
        # progress.yml lists the same rule ids, for roadmap-badges.
        $catalog = Get-Content (Join-Path $PSScriptRoot '../progress.yml') -Raw
        $catalogIds = [regex]::Matches($catalog, '\{ id: ([A-Z]+-\d{3}),') | ForEach-Object { $_.Groups[1].Value }
        ($catalogIds | Sort-Object) | Should -Be ($rules.Id | Sort-Object)
    }

    It 'rejects an unknown area before doing anything' {
        { Get-WinOpsAuditRule -Area 'Printers' } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Get-WinOpsAuditRule'
    }
}
