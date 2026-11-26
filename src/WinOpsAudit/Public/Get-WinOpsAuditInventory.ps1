function Get-WinOpsAuditInventory {
    # The help is written in docs/commands/WinOpsAudit/Get-WinOpsAuditInventory.md and built into
    # this file by ./build.ps1 -Task Help.
    # .ExternalHelp WinOpsAudit-help.xml
    [CmdletBinding(HelpUri = 'https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditInventory.md')]
    [OutputType('WinOpsAudit.Inventory')]
    param()

    Assert-WindowsHost -Cmdlet $PSCmdlet
    try {
        $system = Get-CimData -ClassName 'Win32_ComputerSystem'
        $os = Get-CimData -ClassName 'Win32_OperatingSystem'
        $bios = Get-CimData -ClassName 'Win32_BIOS'
        $processors = @(Get-CimData -ClassName 'Win32_Processor')
    } catch {
        # Without the computer and its system there is nothing worth reporting.
        $PSCmdlet.ThrowTerminatingError($_)
    }

    # The updates are only a summary here. If they cannot be read, the rest is still worth
    # having: say so and leave the summary empty, which is not the same as zero updates.
    $updates = $null
    try {
        $updates = @(Get-WinOpsAuditUpdate -ErrorAction Stop)
    } catch {
        $message = "Could not read the installed updates: $($_.Exception.Message)"
        Write-Error -Message $message -Category ReadError -TargetObject 'Win32_QuickFixEngineering'
    }
    $lastUpdate = $updates | Where-Object InstalledOn |
        Sort-Object -Property InstalledOn -Descending |
        Select-Object -First 1 -ExpandProperty InstalledOn

    [pscustomobject]@{
        PSTypeName            = 'WinOpsAudit.Inventory'
        ComputerName          = $system.Name
        Domain                = $system.Domain
        PartOfDomain          = $system.PartOfDomain
        Manufacturer          = $system.Manufacturer
        Model                 = $system.Model
        SerialNumber          = $bios.SerialNumber
        BiosVersion           = $bios.SMBIOSBIOSVersion
        # One name per model of processor: two sockets with the same one show it once.
        Processor             = @($processors | ForEach-Object { "$($_.Name)".Trim() } | Sort-Object -Unique) -join '; '
        ProcessorCount        = $processors.Count
        CoreCount             = [int]($processors | Measure-Object -Property NumberOfCores -Sum).Sum
        LogicalProcessorCount = $system.NumberOfLogicalProcessors
        # The memory Windows can use: a little less than what is installed.
        MemoryGB              = [math]::Round($system.TotalPhysicalMemory / 1GB, 1)
        OperatingSystem       = $os.Caption
        OSVersion             = $os.Version
        OSArchitecture        = $os.OSArchitecture
        InstallDate           = $os.InstallDate
        LastBootUpTime        = $os.LastBootUpTime
        UpdateCount           = if ($null -ne $updates) { $updates.Count } else { $null }
        LastUpdateInstalledOn = $lastUpdate
    }
}
