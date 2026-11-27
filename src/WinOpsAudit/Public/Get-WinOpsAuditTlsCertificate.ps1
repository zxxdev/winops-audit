function Get-WinOpsAuditTlsCertificate {
    # The help is written in docs/commands/WinOpsAudit/Get-WinOpsAuditTlsCertificate.md and built
    # into this file by ./build.ps1 -Task Help.
    # .ExternalHelp WinOpsAudit-help.xml
    [CmdletBinding(HelpUri = 'https://github.com/zxxdev/winops-audit/blob/main/docs/commands/WinOpsAudit/Get-WinOpsAuditTlsCertificate.md')]
    [OutputType('WinOpsAudit.TlsCertificate')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('HostName', 'DnsName')]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,

        [ValidateRange(1, 65535)]
        [int] $Port = 443,

        [ValidateRange(0, 36500)]
        [int] $ExpiringInDays,

        [ValidateRange(1, 300)]
        [int] $TimeoutSeconds = 10,

        [System.Security.Cryptography.X509Certificates.X509Certificate2[]] $CertificateAuthority = @()
    )

    begin {
        # The same window as Get-WinOpsAuditCertificate: only the expiring ones with
        # -ExpiringInDays, all of them and 30 days ahead without it.
        $onlyExpiring = $PSBoundParameters.ContainsKey('ExpiringInDays')
        $warningDays = if ($onlyExpiring) { $ExpiringInDays } else { 30 }
    }

    process {
        foreach ($name in $ComputerName) {
            $target = "${name}:$Port"
            try {
                $tls = Get-TlsCertificateData -ComputerName $name -Port $Port -TimeoutSeconds $TimeoutSeconds -ErrorAction Stop
            } catch {
                # A server that does not answer does not stop the others: say why and go on.
                $reason = $_.Exception
                while ($reason.InnerException) {
                    $reason = $reason.InnerException
                }
                $message = "Could not read the certificate of ${target}: $($reason.Message)"
                Write-Error -Message $message -Category ConnectionError -TargetObject $target
                continue
            }

            try {
                $audit = Get-CertificateAudit -Certificate $tls.Certificate -WarningDays $warningDays -Now (Get-CurrentTime) -ErrorAction Stop
                if ($onlyExpiring -and $audit.Status -notin 'Expired', 'Expiring') {
                    continue
                }
                $chain = Test-CertificateChain -Certificate $tls.Certificate -Sent $tls.Sent -CertificateAuthority $CertificateAuthority -TimeoutSeconds $TimeoutSeconds -ErrorAction Stop
            } catch {
                # A certificate that cannot be checked does not stop the other servers.
                $message = "Could not audit the certificate of ${target}: $($_.Exception.Message)"
                Write-Error -Message $message -Category ReadError -TargetObject $target
                continue
            }
            $findings = @($audit.Findings) + @(if ($chain.Status -eq 'MissingIntermediate') { 'CRT-003' })

            [pscustomobject]@{
                PSTypeName         = 'WinOpsAudit.TlsCertificate'
                ComputerName       = $name
                Port               = $Port
                Protocol           = $tls.Protocol
                Subject            = $audit.Subject
                Issuer             = $audit.Issuer
                DnsNames           = $audit.DnsNames
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
                SentCount          = $tls.Sent.Count
                ChainStatus        = $chain.Status
                MissingCertificate = $chain.Missing -join '; '
                Findings           = $findings -join '; '
            }
        }
    }
}
