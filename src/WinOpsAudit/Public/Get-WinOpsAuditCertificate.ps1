function Get-WinOpsAuditCertificate {
    # The help is written in docs/commands/WinOpsAudit/Get-WinOpsAuditCertificate.md and built
    # into this file by ./build.ps1 -Task Help.
    # .ExternalHelp WinOpsAudit-help.xml
    [CmdletBinding(HelpUri = 'https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditCertificate.md')]
    [OutputType('WinOpsAudit.Certificate')]
    param(
        [ValidateSet('LocalMachine', 'CurrentUser')]
        [string] $StoreLocation = 'LocalMachine',

        [ValidateSet('My', 'WebHosting', 'Remote Desktop', 'Root', 'CA', 'TrustedPublisher')]
        [string[]] $StoreName = 'My',

        [ValidateRange(0, 36500)]
        [int] $ExpiringInDays
    )

    Assert-WindowsHost -Cmdlet $PSCmdlet

    # With -ExpiringInDays, only the certificates that expire within that many days (or already
    # have) come out. Without it, all of them, and CRT-001 warns 30 days ahead.
    $onlyExpiring = $PSBoundParameters.ContainsKey('ExpiringInDays')
    $warningDays = if ($onlyExpiring) { $ExpiringInDays } else { 30 }
    $now = Get-CurrentTime
    $computerName = [Environment]::MachineName

    foreach ($name in $StoreName | Select-Object -Unique) {
        $store = "$StoreLocation\$name"
        try {
            $certificates = @(Get-StoreCertificate -Location $StoreLocation -Name $name -ErrorAction Stop)
        } catch {
            # One store that cannot be opened does not hide the others: say so and go on.
            $message = "Could not open the $store certificate store: $($_.Exception.Message)"
            Write-Error -Message $message -Category ReadError -TargetObject $store
            continue
        }

        $rows = foreach ($certificate in $certificates) {
            try {
                $audit = Get-CertificateAudit -Certificate $certificate -WarningDays $warningDays -Now $now -ErrorAction Stop
            } catch {
                # One certificate that cannot be read does not hide the others in the store.
                $message = "Could not audit the certificate $($certificate.Thumbprint) in ${store}: $($_.Exception.Message)"
                Write-Error -Message $message -Category ReadError -TargetObject $certificate.Thumbprint
                continue
            }
            if ($onlyExpiring -and $audit.Status -notin 'Expired', 'Expiring') {
                continue
            }
            [pscustomobject]@{
                PSTypeName         = 'WinOpsAudit.Certificate'
                ComputerName       = $computerName
                Store              = $store
                Subject            = $audit.Subject
                Issuer             = $audit.Issuer
                DnsNames           = $audit.DnsNames
                FriendlyName       = $certificate.FriendlyName
                Thumbprint         = $audit.Thumbprint
                SerialNumber       = $audit.SerialNumber
                NotBefore          = $audit.NotBefore
                NotAfter           = $audit.NotAfter
                DaysLeft           = $audit.DaysLeft
                Status             = $audit.Status
                SignatureAlgorithm = $audit.SignatureAlgorithm
                KeyAlgorithm       = $audit.KeyAlgorithm
                KeySize            = $audit.KeySize
                WeakReason         = $audit.WeakReason
                HasPrivateKey      = $certificate.HasPrivateKey
                Findings           = $audit.Findings -join '; '
            }
        }
        # The first to expire first.
        $rows | Sort-Object -Property NotAfter, Subject
    }
}
