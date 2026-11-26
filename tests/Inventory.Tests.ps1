# The inventory cmdlets read CIM and the registry, which only exist on Windows. The unit tests
# replace the two private helpers that read them (Get-CimData, Get-UninstallEntry) with prepared
# data, so they run on Linux and Windows alike. The values are made up (contoso.test); the
# property names are the real ones. The last block runs the cmdlets against the real system, on
# Windows only.

BeforeAll {
    $manifest = Join-Path $PSScriptRoot '../src/WinOpsAudit/WinOpsAudit.psd1'
    Import-Module $manifest -Force

    # One uninstall entry as Get-UninstallEntry returns it: every value, $null when missing.
    function Get-SampleUninstallEntry {
        param(
            [string] $KeyName,
            [string] $DisplayName,
            [string] $DisplayVersion,
            [string] $Publisher,
            [string] $InstallDate,
            [object] $SystemComponent,
            [string] $ParentKeyName,
            [string] $ReleaseType
        )
        [pscustomobject]@{
            KeyName         = $KeyName
            DisplayName     = $DisplayName
            DisplayVersion  = $DisplayVersion
            Publisher       = $Publisher
            InstallDate     = $InstallDate
            SystemComponent = $SystemComponent
            ParentKeyName   = $ParentKeyName
            ReleaseType     = $ReleaseType
        }
    }
}

AfterAll {
    Remove-Module WinOpsAudit -ErrorAction Ignore
}

Describe 'Get-WinOpsAuditInventory (INV-001)' {
    BeforeEach {
        Mock -ModuleName WinOpsAudit Test-WindowsHost { $true }
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' } {
            [pscustomobject]@{
                Name                      = 'SRV-FILE01'
                Domain                    = 'contoso.test'
                PartOfDomain              = $true
                Manufacturer              = 'Contoso Hardware'
                Model                     = 'CX-200'
                NumberOfLogicalProcessors = 32
                TotalPhysicalMemory       = 34224742400
            }
        }
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } {
            [pscustomobject]@{
                Caption        = 'Microsoft Windows Server 2025 Standard'
                Version        = '10.0.26100'
                OSArchitecture = '64-bit'
                InstallDate    = [datetime]'2026-01-15 09:30'
                LastBootUpTime = [datetime]'2026-11-20 06:00'
            }
        }
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_BIOS' } {
            [pscustomobject]@{ SerialNumber = 'CTS-0001'; SMBIOSBIOSVersion = '2.4.1' }
        }
        # Two sockets with the same processor; Windows pads some names with spaces.
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_Processor' } {
            [pscustomobject]@{ Name = 'Contoso CPU 8-Core @ 3.0GHz  '; NumberOfCores = 8 }
            [pscustomobject]@{ Name = 'Contoso CPU 8-Core @ 3.0GHz  '; NumberOfCores = 8 }
        }
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_QuickFixEngineering' } {
            [pscustomobject]@{ CSName = 'SRV-FILE01'; HotFixID = 'KB5001002'; Description = 'Update'; InstalledOn = '10/8/2026'; InstalledBy = 'NT AUTHORITY\SYSTEM' }
            [pscustomobject]@{ CSName = 'SRV-FILE01'; HotFixID = 'KB5001001'; Description = 'Security Update'; InstalledOn = '11/12/2026'; InstalledBy = 'NT AUTHORITY\SYSTEM' }
            [pscustomobject]@{ CSName = 'SRV-FILE01'; HotFixID = 'KB5001003'; Description = 'Update'; InstalledOn = ''; InstalledBy = '' }
        }
    }

    It 'returns one inventory object per computer, not text' {
        $inventory = @(Get-WinOpsAuditInventory)
        $inventory.Count | Should -Be 1
        $inventory[0].PSObject.TypeNames | Should -Contain 'WinOpsAudit.Inventory'
        $inventory[0].PSObject.Properties.Name | Should -Be @(
            'ComputerName', 'Domain', 'PartOfDomain', 'Manufacturer', 'Model', 'SerialNumber',
            'BiosVersion', 'Processor', 'ProcessorCount', 'CoreCount', 'LogicalProcessorCount',
            'MemoryGB', 'OperatingSystem', 'OSVersion', 'OSArchitecture', 'InstallDate',
            'LastBootUpTime', 'UpdateCount', 'LastUpdateInstalledOn')
    }

    It 'takes the computer, the system and the firmware from their CIM classes' {
        $inventory = Get-WinOpsAuditInventory
        $inventory.ComputerName | Should -Be 'SRV-FILE01'
        $inventory.Domain | Should -Be 'contoso.test'
        $inventory.PartOfDomain | Should -BeTrue
        $inventory.SerialNumber | Should -Be 'CTS-0001'
        $inventory.BiosVersion | Should -Be '2.4.1'
        $inventory.OperatingSystem | Should -Be 'Microsoft Windows Server 2025 Standard'
        $inventory.OSVersion | Should -Be '10.0.26100'
        $inventory.LastBootUpTime | Should -Be ([datetime]'2026-11-20 06:00')
    }

    It 'adds up the processors and gives the memory in GB' {
        $inventory = Get-WinOpsAuditInventory
        $inventory.Processor | Should -Be 'Contoso CPU 8-Core @ 3.0GHz'
        $inventory.ProcessorCount | Should -Be 2
        $inventory.CoreCount | Should -Be 16
        $inventory.LogicalProcessorCount | Should -Be 32
        $inventory.MemoryGB | Should -Be 31.9
    }

    It 'sums up the updates: how many, and the date of the last one' {
        $inventory = Get-WinOpsAuditInventory
        $inventory.UpdateCount | Should -Be 3
        $inventory.LastUpdateInstalledOn | Should -Be ([datetime]'2026-11-12')
    }

    It 'still reports the computer when the updates cannot be read, and says so' {
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_QuickFixEngineering' } {
            throw 'Access denied'
        }
        # The error stream, as the user sees it. -ErrorVariable would also collect the error the
        # cmdlet catches and handles inside.
        # -ErrorAction Continue: the build runs with $ErrorActionPreference = 'Stop'.
        $output = Get-WinOpsAuditInventory -ErrorAction Continue 2>&1
        $problems = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $inventory = $output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
        $inventory.ComputerName | Should -Be 'SRV-FILE01'
        $inventory.UpdateCount | Should -BeNullOrEmpty -Because 'unknown is not the same as zero updates'
        $inventory.LastUpdateInstalledOn | Should -BeNullOrEmpty
        $problems.Count | Should -Be 1
        $problems[0].CategoryInfo.Category | Should -Be 'ReadError'
    }

    It 'stops, with nothing returned, when the operating system cannot be read' {
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } {
            throw 'The RPC server is unavailable'
        }
        { Get-WinOpsAuditInventory } | Should -Throw '*RPC server*'
    }

    It 'can be exported: every property is a plain value' {
        $csv = Get-WinOpsAuditInventory | ConvertTo-Csv
        $csv.Count | Should -Be 2
        $csv[1] | Should -Not -Match 'System\.Object\[\]|PSCustomObject'
        ($csv | ConvertFrom-Csv).ComputerName | Should -Be 'SRV-FILE01'
    }
}

Describe 'Get-WinOpsAuditUpdate (INV-001)' {
    BeforeEach {
        Mock -ModuleName WinOpsAudit Test-WindowsHost { $true }
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_QuickFixEngineering' } {
            [pscustomobject]@{ CSName = 'SRV-FILE01'; HotFixID = 'KB5001001'; Description = 'Security Update'; InstalledOn = '11/12/2026'; InstalledBy = 'NT AUTHORITY\SYSTEM' }
            [pscustomobject]@{ CSName = 'SRV-FILE01'; HotFixID = 'KB5001003'; Description = 'Update'; InstalledOn = ''; InstalledBy = '' }
            [pscustomobject]@{ CSName = 'SRV-FILE01'; HotFixID = 'KB5001002'; Description = 'Update'; InstalledOn = '10/8/2026'; InstalledBy = 'CONTOSO\admin.jane' }
        }
    }

    It 'returns one update object per installed update' {
        $updates = @(Get-WinOpsAuditUpdate)
        $updates.Count | Should -Be 3
        $updates[0].PSObject.TypeNames | Should -Contain 'WinOpsAudit.Update'
        $updates[0].PSObject.Properties.Name | Should -Be 'ComputerName', 'HotFixId', 'Description', 'InstalledOn', 'InstalledBy'
    }

    It 'sorts them oldest first, with the undated ones first' {
        (Get-WinOpsAuditUpdate).HotFixId | Should -Be 'KB5001003', 'KB5001002', 'KB5001001'
    }

    It 'turns the install date into a date, and leaves it empty when Windows does not say' {
        $updates = Get-WinOpsAuditUpdate
        ($updates | Where-Object HotFixId -EQ 'KB5001001').InstalledOn | Should -Be ([datetime]'2026-11-12')
        ($updates | Where-Object HotFixId -EQ 'KB5001003').InstalledOn | Should -BeNullOrEmpty
    }

    It 'can be filtered and exported' {
        $security = Get-WinOpsAuditUpdate | Where-Object Description -EQ 'Security Update'
        $security.HotFixId | Should -Be 'KB5001001'
        $csv = Get-WinOpsAuditUpdate | ConvertTo-Csv | ConvertFrom-Csv
        $csv.HotFixId | Should -Be 'KB5001003', 'KB5001002', 'KB5001001'
    }

    It 'shows a short table by default, with the date only' {
        $table = Get-WinOpsAuditUpdate | Out-String
        $table | Should -Match 'HotFixId\s+Description\s+InstalledOn\s+InstalledBy'
        $table | Should -Match 'KB5001001\s+Security Update\s+2026-11-12'
        $table | Should -Not -Match 'ComputerName'
    }

    It 'stops with the reason when the updates cannot be read' {
        Mock -ModuleName WinOpsAudit Get-CimData -ParameterFilter { $ClassName -eq 'Win32_QuickFixEngineering' } {
            throw 'Access denied'
        }
        { Get-WinOpsAuditUpdate } | Should -Throw '*Access denied*'
    }
}

Describe 'Dates as Windows writes them' {
    It 'reads <Text> as <Expected>' -ForEach @(
        @{ Text = '20261112'; Expected = '2026-11-12' }
        @{ Text = '11/12/2026'; Expected = '2026-11-12' }
        @{ Text = '3/9/2026'; Expected = '2026-03-09' }
        @{ Text = ' 20260309 '; Expected = '2026-03-09' }
    ) {
        $date = InModuleScope WinOpsAudit -Parameters @{ Text = $Text } { ConvertFrom-WindowsDate $Text }
        $date | Should -Be ([datetime]$Expected)
    }

    # Found on the Windows runner: there the type data of PowerShell has already turned
    # InstalledOn into a date, time included, before the module reads it.
    It 'keeps a value that is already a date' {
        $when = [datetime]::new(2026, 11, 12)
        $date = InModuleScope WinOpsAudit -Parameters @{ When = $when } { ConvertFrom-WindowsDate $When }
        $date | Should -Be $when
    }

    It 'reads a FILETIME written in hexadecimal' {
        $when = [datetime]::new(2026, 3, 9, 14, 30, 0, [System.DateTimeKind]::Local)
        $hex = '{0:x16}' -f $when.ToFileTime()
        $date = InModuleScope WinOpsAudit -Parameters @{ Hex = $hex } { ConvertFrom-WindowsDate $Hex }
        $date | Should -Be $when
    }

    It 'gives nothing for <Case>, instead of guessing' -ForEach @(
        @{ Case = 'no value'; Text = $null }
        @{ Case = 'an empty value'; Text = '' }
        @{ Case = 'a date in another order'; Text = '2026-11-12' }
        @{ Case = 'a day that does not exist'; Text = '20260231' }
        @{ Case = 'words'; Text = 'yesterday' }
        @{ Case = 'a hex value out of range'; Text = 'ffffffffffffffff' }
    ) {
        InModuleScope WinOpsAudit -Parameters @{ Text = $Text } { ConvertFrom-WindowsDate $Text } |
            Should -BeNullOrEmpty
    }
}

Describe 'Get-WinOpsAuditSoftware (INV-002)' {
    BeforeEach {
        Mock -ModuleName WinOpsAudit Test-WindowsHost { $true }
        Mock -ModuleName WinOpsAudit Get-UninstallEntry -ParameterFilter { $View -eq 'Machine64' } {
            Get-SampleUninstallEntry -KeyName '{6F1A2B3C-0001}' -DisplayName 'Contoso Backup Agent' -DisplayVersion '4.2.0' -Publisher 'Contoso Ltd' -InstallDate '20260301'
            # What "Installed apps" does not show either:
            Get-SampleUninstallEntry -KeyName '{6F1A2B3C-0002}' -DisplayName 'Contoso Backup Agent Core' -DisplayVersion '4.2.0' -SystemComponent 1
            Get-SampleUninstallEntry -KeyName 'KB000001' -DisplayName 'Update for Contoso Backup Agent (KB000001)' -ParentKeyName '{6F1A2B3C-0001}'
            Get-SampleUninstallEntry -KeyName '{6F1A2B3C-0003}' -DisplayName 'Security Update for Contoso Office' -ReleaseType 'Security Update'
            Get-SampleUninstallEntry -KeyName 'OrphanKey'
        }
        Mock -ModuleName WinOpsAudit Get-UninstallEntry -ParameterFilter { $View -eq 'Machine32' } {
            Get-SampleUninstallEntry -KeyName 'FabrikamViewer' -DisplayName 'Fabrikam Viewer ' -DisplayVersion '1.0' -Publisher 'Fabrikam' -InstallDate 'not a date'
            # Shown in "Installed apps": SystemComponent is 0, not 1.
            Get-SampleUninstallEntry -KeyName 'FabrikamTools' -DisplayName 'Fabrikam Tools' -DisplayVersion '2.5' -Publisher 'Fabrikam' -SystemComponent 0
        }
        Mock -ModuleName WinOpsAudit Get-UninstallEntry -ParameterFilter { $View -eq 'User' } {
            Get-SampleUninstallEntry -KeyName 'TailspinNotes' -DisplayName 'Tailspin Notes' -DisplayVersion '3.1' -Publisher 'Tailspin' -InstallDate '20261101'
        }
    }

    It 'returns one software object per installed program, sorted by name' {
        $software = @(Get-WinOpsAuditSoftware)
        $software.Name | Should -Be 'Contoso Backup Agent', 'Fabrikam Tools', 'Fabrikam Viewer', 'Tailspin Notes'
        $software[0].PSObject.TypeNames | Should -Contain 'WinOpsAudit.Software'
        $software[0].PSObject.Properties.Name | Should -Be @(
            'ComputerName', 'Name', 'Version', 'Publisher', 'InstallDate', 'Architecture', 'Scope', 'UninstallKey')
        $software[0].ComputerName | Should -Be ([Environment]::MachineName)
    }

    It 'leaves out what "Installed apps" hides: components, updates and entries with no name' {
        $keys = (Get-WinOpsAuditSoftware).UninstallKey
        $keys | Should -Not -Contain '{6F1A2B3C-0002}' -Because 'SystemComponent = 1 is a hidden part of another program'
        $keys | Should -Not -Contain 'KB000001' -Because 'an entry with ParentKeyName is an update of another program'
        $keys | Should -Not -Contain '{6F1A2B3C-0003}' -Because 'a ReleaseType of Security Update is an update'
        $keys | Should -Not -Contain 'OrphanKey' -Because 'an entry with no DisplayName has nothing to show'
    }

    It 'says where each program is registered: architecture and scope' {
        $software = Get-WinOpsAuditSoftware
        $contoso = $software | Where-Object Name -EQ 'Contoso Backup Agent'
        $contoso.Architecture | Should -Be 'x64'
        $contoso.Scope | Should -Be 'Machine'
        $fabrikam = $software | Where-Object Name -EQ 'Fabrikam Viewer'
        $fabrikam.Architecture | Should -Be 'x86'
        $fabrikam.Scope | Should -Be 'Machine'
        $tailspin = $software | Where-Object Name -EQ 'Tailspin Notes'
        $tailspin.Architecture | Should -BeNullOrEmpty
        $tailspin.Scope | Should -Be 'CurrentUser'
    }

    It 'turns the install date into a date, and leaves it empty when it is not one' {
        $software = Get-WinOpsAuditSoftware
        ($software | Where-Object Name -EQ 'Contoso Backup Agent').InstallDate | Should -Be ([datetime]'2026-03-01')
        ($software | Where-Object Name -EQ 'Fabrikam Viewer').InstallDate | Should -BeNullOrEmpty
    }

    It 'filters by name with wildcards, and returns each program once' {
        (Get-WinOpsAuditSoftware -Name 'Fabrikam*').Name | Should -Be 'Fabrikam Tools', 'Fabrikam Viewer'
        (Get-WinOpsAuditSoftware 'Fabrikam*', '*Viewer').Name | Should -Be 'Fabrikam Tools', 'Fabrikam Viewer'
        (Get-WinOpsAuditSoftware -Name 'tailspin notes').Name | Should -Be 'Tailspin Notes'
    }

    It 'writes an error for an exact name that is not installed, and goes on with the rest' {
        $software = Get-WinOpsAuditSoftware -Name 'Northwind CRM', 'Tailspin Notes' -ErrorVariable problems -ErrorAction SilentlyContinue
        $software.Name | Should -Be 'Tailspin Notes'
        $problems.Count | Should -Be 1
        $problems[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
    }

    It 'writes no error when a wildcard matches nothing' {
        Get-WinOpsAuditSoftware -Name 'Northwind*' -ErrorVariable problems -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
        $problems.Count | Should -Be 0
    }

    It 'goes on with the other keys when one cannot be read, and says which' {
        Mock -ModuleName WinOpsAudit Get-UninstallEntry -ParameterFilter { $View -eq 'Machine32' } {
            throw 'Requested registry access is not allowed.'
        }
        # The error stream, as the user sees it (see the same check for the inventory).
        $output = Get-WinOpsAuditSoftware -ErrorAction Continue 2>&1
        $problems = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $software = $output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
        $software.Name | Should -Be 'Contoso Backup Agent', 'Tailspin Notes'
        $problems.Count | Should -Be 1
        $problems[0].CategoryInfo.Category | Should -Be 'ReadError'
        $problems[0].TargetObject | Should -Be 'Machine32'
    }

    It 'can be exported, and shows a short table by default' {
        $csv = Get-WinOpsAuditSoftware | ConvertTo-Csv | ConvertFrom-Csv
        $csv.Count | Should -Be 4
        $csv[0].UninstallKey | Should -Be '{6F1A2B3C-0001}'
        $table = Get-WinOpsAuditSoftware | Out-String
        $table | Should -Match 'Name\s+Version\s+Publisher\s+Architecture\s+Scope'
        $table | Should -Not -Match 'UninstallKey'
    }
}

Describe 'Outside Windows' {
    BeforeEach {
        Mock -ModuleName WinOpsAudit Test-WindowsHost { $false }
        Mock -ModuleName WinOpsAudit Get-CimData { throw 'must not be called' }
        Mock -ModuleName WinOpsAudit Get-UninstallEntry { throw 'must not be called' }
    }

    It '<Command> stops before reading anything, with a clear error' -ForEach @(
        @{ Command = 'Get-WinOpsAuditInventory' }
        @{ Command = 'Get-WinOpsAuditUpdate' }
        @{ Command = 'Get-WinOpsAuditSoftware' }
    ) {
        { & $Command } | Should -Throw -ErrorId "WindowsOnly,$Command"
        Should -Invoke -ModuleName WinOpsAudit Get-CimData -Times 0 -Exactly
        Should -Invoke -ModuleName WinOpsAudit Get-UninstallEntry -Times 0 -Exactly
    }
}

# Against the real system: proves that Windows gives what the mocks above pretend it gives.
Describe 'On a real Windows computer' -Skip:(-not $IsWindows) {
    It 'Get-WinOpsAuditInventory describes this computer' {
        $inventory = @(Get-WinOpsAuditInventory)
        $inventory.Count | Should -Be 1
        $inventory[0].ComputerName | Should -Be ([Environment]::MachineName)
        $inventory[0].OperatingSystem | Should -BeLike '*Windows*'
        $inventory[0].MemoryGB | Should -BeGreaterThan 0
        $inventory[0].CoreCount | Should -BeGreaterThan 0
        $inventory[0].LogicalProcessorCount | Should -BeGreaterOrEqual $inventory[0].CoreCount
        $inventory[0].LastBootUpTime | Should -BeOfType [datetime]
    }

    It 'Get-WinOpsAuditUpdate finds the same updates and dates as Get-HotFix' {
        $ours = @(Get-WinOpsAuditUpdate)
        $theirs = @(Get-HotFix)
        @($ours.HotFixId | Sort-Object) | Should -Be @($theirs.HotFixID | Sort-Object)
        foreach ($fix in $theirs | Where-Object InstalledOn) {
            $match = @($ours | Where-Object HotFixId -EQ $fix.HotFixID)[0]
            $match.InstalledOn | Should -Not -BeNullOrEmpty -Because "Get-HotFix gives $($fix.HotFixID) a date"
            $match.InstalledOn.Date | Should -Be $fix.InstalledOn.Date
        }
    }

    It 'Get-WinOpsAuditSoftware lists the installed programs, each with a name and a scope' {
        $software = @(Get-WinOpsAuditSoftware)
        $software.Count | Should -BeGreaterThan 0
        foreach ($program in $software) {
            $program.Name | Should -Not -BeNullOrEmpty
            $program.Scope | Should -BeIn 'Machine', 'CurrentUser'
        }
        @($software | Where-Object Scope -EQ 'Machine').Count | Should -BeGreaterThan 0
    }

    It 'Get-WinOpsAuditSoftware can be exported to a CSV file and read back' {
        $path = Join-Path $TestDrive 'software.csv'
        $software = @(Get-WinOpsAuditSoftware)
        $software | Export-Csv -Path $path
        @(Import-Csv -Path $path).Count | Should -Be $software.Count
    }
}
