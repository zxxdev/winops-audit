# The certificate cmdlets. Every certificate is made in the test (TestCertificates.ps1), with
# fixed dates, and the clock of the module is set to 2026-11-27 12:00, so the days left are the
# same every day the tests run.
#
# Get-WinOpsAuditCertificate reads the certificate stores of Windows: the unit tests replace the
# private helper that opens them (Get-StoreCertificate) and run on Linux too. A last block reads
# a real store, on Windows only.
#
# Get-WinOpsAuditTlsCertificate is not mocked: the tests run real TLS servers on 127.0.0.1 and
# connect to them, on Linux and on Windows. No test goes out to the network.

BeforeAll {
    $manifest = Join-Path $PSScriptRoot '../src/WinOpsAudit/WinOpsAudit.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestCertificates.ps1')

    # A small private PKI: a root, an intermediate that signs the server certificates, and an
    # old root signed with SHA-1, as many old roots are.
    $pki = @{}
    $pki.Root = New-TestCertificate -Subject 'CN=Contoso Test Root CA, O=Contoso Test' -CertificateAuthority -NotBefore '2025-01-01' -NotAfter '2036-01-01'
    $pki.Intermediate = New-TestCertificate -Subject 'CN=Contoso Test Issuing CA, O=Contoso Test' -Issuer $pki.Root -CertificateAuthority -NotBefore '2025-01-01' -NotAfter '2031-01-01'
    $pki.OldRoot = New-TestCertificate -Subject 'CN=Contoso Old Root, O=Contoso Test' -Hash SHA1 -CertificateAuthority -NotBefore '2020-01-01' -NotAfter '2030-01-01'

    $issued = @{ Issuer = $pki.Intermediate; NotBefore = '2026-01-01' }
    $pki.Web = New-TestCertificate @issued -Subject 'CN=web01.contoso.test' -DnsName 'web01.contoso.test', 'www.contoso.test' -NotAfter '2027-06-30 18:00'
    $pki.Mail = New-TestCertificate @issued -Subject 'CN=mail.contoso.test' -NotAfter '2026-12-10 18:00'
    $pki.Old = New-TestCertificate -Issuer $pki.Intermediate -Subject 'CN=old.contoso.test' -NotBefore '2025-10-01' -NotAfter '2026-10-01 18:00'
    $pki.Legacy = New-TestCertificate @issued -Subject 'CN=legacy.contoso.test' -Hash SHA1 -NotAfter '2027-03-01 18:00'
    $pki.Printer = New-TestCertificate @issued -Subject 'CN=printer.contoso.test' -KeySize 1024 -NotAfter '2027-03-01 18:00'
    $pki.Api = New-TestCertificate @issued -Subject 'CN=api.contoso.test' -KeyAlgorithm EC -NotAfter '2027-03-01 18:00'
    $pki.Next = New-TestCertificate -Issuer $pki.Intermediate -Subject 'CN=next.contoso.test' -NotBefore '2027-01-01' -NotAfter '2028-01-01'

    function Set-TestClock {
        Mock -ModuleName WinOpsAudit Get-CurrentTime { [datetime]'2026-11-27 12:00' }
    }
}

AfterAll {
    Remove-Module WinOpsAudit -ErrorAction Ignore
}

Describe 'Get-WinOpsAuditCertificate' {
    BeforeEach {
        Set-TestClock
        Mock -ModuleName WinOpsAudit Test-WindowsHost { $true }
        Mock -ModuleName WinOpsAudit Get-StoreCertificate -ParameterFilter { $Name -eq 'My' } {
            $pki.Web, $pki.Mail, $pki.Old, $pki.Legacy, $pki.Printer, $pki.Api, $pki.Next
        }
        Mock -ModuleName WinOpsAudit Get-StoreCertificate -ParameterFilter { $Name -eq 'Root' } {
            $pki.Root, $pki.OldRoot
        }
        Mock -ModuleName WinOpsAudit Get-StoreCertificate -ParameterFilter { $Name -eq 'WebHosting' } {
            throw 'The system cannot find the file specified.'
        }
    }

    It 'returns one object per certificate, not text, the first to expire first' {
        $certificates = @(Get-WinOpsAuditCertificate)
        $certificates.Count | Should -Be 7
        $certificates[0].PSObject.TypeNames | Should -Contain 'WinOpsAudit.Certificate'
        $certificates[0].PSObject.Properties.Name | Should -Be @(
            'ComputerName', 'Store', 'Subject', 'Issuer', 'DnsNames', 'FriendlyName', 'Thumbprint',
            'SerialNumber', 'NotBefore', 'NotAfter', 'DaysLeft', 'Status', 'SignatureAlgorithm',
            'KeyAlgorithm', 'KeySize', 'WeakReason', 'HasPrivateKey', 'Findings')
        $certificates.Subject | Should -Be @(
            'CN=old.contoso.test', 'CN=mail.contoso.test', 'CN=api.contoso.test',
            'CN=legacy.contoso.test', 'CN=printer.contoso.test', 'CN=web01.contoso.test',
            'CN=next.contoso.test')
    }

    It 'reads LocalMachine\My unless told otherwise' {
        $certificates = Get-WinOpsAuditCertificate
        $certificates.Store | Sort-Object -Unique | Should -Be 'LocalMachine\My'
        Should -Invoke -ModuleName WinOpsAudit Get-StoreCertificate -Times 1 -Exactly -ParameterFilter {
            $Location -eq 'LocalMachine' -and $Name -eq 'My'
        }
    }

    It 'describes the certificate: names, dates, days left and key' {
        $web = Get-WinOpsAuditCertificate | Where-Object Subject -EQ 'CN=web01.contoso.test'
        $web.Issuer | Should -Be 'CN=Contoso Test Issuing CA, O=Contoso Test'
        $web.DnsNames | Should -Be 'web01.contoso.test; www.contoso.test'
        $web.Thumbprint | Should -Be $pki.Web.Thumbprint
        $web.NotAfter | Should -Be ([datetime]'2027-06-30 18:00')
        $web.DaysLeft | Should -Be 215
        $web.Status | Should -Be 'Valid'
        $web.SignatureAlgorithm | Should -Be 'sha256RSA'
        $web.KeyAlgorithm | Should -Be 'RSA'
        $web.KeySize | Should -Be 2048
        $web.HasPrivateKey | Should -BeTrue
        $web.Findings | Should -BeNullOrEmpty
    }

    It 'flags a certificate that expires within 30 days, and one that has expired (CRT-001)' {
        $certificates = Get-WinOpsAuditCertificate
        $mail = $certificates | Where-Object Subject -EQ 'CN=mail.contoso.test'
        $mail.Status | Should -Be 'Expiring'
        $mail.DaysLeft | Should -Be 13
        $mail.Findings | Should -Be 'CRT-001'
        $old = $certificates | Where-Object Subject -EQ 'CN=old.contoso.test'
        $old.Status | Should -Be 'Expired'
        $old.DaysLeft | Should -Be -56
        $old.Findings | Should -Be 'CRT-001'
    }

    It 'does not flag a certificate with more than 30 days left, or one not valid yet (CRT-001)' {
        $certificates = Get-WinOpsAuditCertificate
        ($certificates | Where-Object Subject -EQ 'CN=web01.contoso.test').Findings | Should -BeNullOrEmpty
        $next = $certificates | Where-Object Subject -EQ 'CN=next.contoso.test'
        $next.Status | Should -Be 'NotYetValid'
        $next.Findings | Should -BeNullOrEmpty
    }

    It 'lists only the certificates that expire within N days with -ExpiringInDays, expired ones included' -ForEach @(
        @{ Days = 0; Expected = @('CN=old.contoso.test') }
        @{ Days = 13; Expected = @('CN=old.contoso.test', 'CN=mail.contoso.test') }
        @{ Days = 30; Expected = @('CN=old.contoso.test', 'CN=mail.contoso.test') }
        @{ Days = 94; Expected = @('CN=old.contoso.test', 'CN=mail.contoso.test', 'CN=api.contoso.test', 'CN=legacy.contoso.test', 'CN=printer.contoso.test') }
    ) {
        $certificates = @(Get-WinOpsAuditCertificate -ExpiringInDays $Days)
        $certificates.Subject | Should -Be $Expected
        $certificates.Findings | ForEach-Object { $_ | Should -Match 'CRT-001' }
    }

    It 'flags a certificate signed with SHA-1 (CRT-002)' {
        $legacy = Get-WinOpsAuditCertificate | Where-Object Subject -EQ 'CN=legacy.contoso.test'
        $legacy.SignatureAlgorithm | Should -Be 'sha1RSA'
        $legacy.WeakReason | Should -Be 'signed with SHA-1'
        $legacy.Findings | Should -Be 'CRT-002'
    }

    It 'flags an RSA key under 2048 bits (CRT-002)' {
        $printer = Get-WinOpsAuditCertificate | Where-Object Subject -EQ 'CN=printer.contoso.test'
        $printer.KeySize | Should -Be 1024
        $printer.WeakReason | Should -Be 'RSA key of 1024 bits, under 2048'
        $printer.Findings | Should -Be 'CRT-002'
    }

    It 'does not flag SHA-256 with RSA 2048 or with an EC key of 256 bits (CRT-002)' {
        $certificates = Get-WinOpsAuditCertificate
        $api = $certificates | Where-Object Subject -EQ 'CN=api.contoso.test'
        $api.KeyAlgorithm | Should -Be 'EC'
        $api.KeySize | Should -Be 256
        $api.WeakReason | Should -BeNullOrEmpty
        ($certificates | Where-Object Subject -EQ 'CN=web01.contoso.test').WeakReason | Should -BeNullOrEmpty
    }

    It 'does not flag the SHA-1 signature of a self-signed root, which nobody checks (CRT-002)' {
        $oldRoot = Get-WinOpsAuditCertificate -StoreName Root | Where-Object Subject -Like 'CN=Contoso Old Root*'
        $oldRoot.SignatureAlgorithm | Should -Be 'sha1RSA'
        $oldRoot.WeakReason | Should -BeNullOrEmpty
        $oldRoot.Findings | Should -BeNullOrEmpty
    }

    It 'reads several stores and says which store each certificate is in' {
        $certificates = Get-WinOpsAuditCertificate -StoreLocation CurrentUser -StoreName My, Root
        $certificates.Count | Should -Be 9
        @($certificates | Where-Object Store -EQ 'CurrentUser\Root').Count | Should -Be 2
        @($certificates | Where-Object Store -EQ 'CurrentUser\My').Count | Should -Be 7
    }

    It 'goes on with the other stores when one cannot be opened, and says which' {
        # The error stream, as the user sees it (see the same check for the inventory).
        $output = Get-WinOpsAuditCertificate -StoreName WebHosting, Root -ErrorAction Continue 2>&1
        $problems = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $certificates = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
        $certificates.Count | Should -Be 2
        $problems.Count | Should -Be 1
        $problems[0].CategoryInfo.Category | Should -Be 'ReadError'
        $problems[0].TargetObject | Should -Be 'LocalMachine\WebHosting'
    }

    It 'rejects a store it does not know before reading anything' {
        { Get-WinOpsAuditCertificate -StoreName 'Printers' } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Get-WinOpsAuditCertificate'
        Should -Invoke -ModuleName WinOpsAudit Get-StoreCertificate -Times 0 -Exactly
    }

    It 'can be exported, and shows a short table by default' {
        $csv = Get-WinOpsAuditCertificate | ConvertTo-Csv
        $csv[1] | Should -Not -Match 'System\.Object\[\]|PSCustomObject|List`1'
        ($csv | ConvertFrom-Csv).Count | Should -Be 7
        $table = Get-WinOpsAuditCertificate | Out-String
        $table | Should -Match 'Store\s+Subject\s+NotAfter\s+DaysLeft\s+Status\s+Findings'
        $table | Should -Not -Match 'Thumbprint'
    }

    It 'stops outside Windows before reading anything' {
        Mock -ModuleName WinOpsAudit Test-WindowsHost { $false }
        { Get-WinOpsAuditCertificate } | Should -Throw -ErrorId 'WindowsOnly,Get-WinOpsAuditCertificate'
        Should -Invoke -ModuleName WinOpsAudit Get-StoreCertificate -Times 0 -Exactly
    }
}

Describe 'Get-WinOpsAuditTlsCertificate' {
    BeforeAll {
        $servers = @{}
        # A server that sends its intermediate, as it should.
        $servers.Full = Start-TestTlsServer -Certificate $pki.Web -Chain $pki.Intermediate
        # The same certificate without the intermediate: the classic mistake.
        $servers.LeafOnly = Start-TestTlsServer -Certificate $pki.Web
        $servers.Expired = Start-TestTlsServer -Certificate $pki.Old -Chain $pki.Intermediate
        $selfSigned = New-TestCertificate -Subject 'CN=selfsigned.contoso.test' -NotBefore '2026-01-01' -NotAfter '2027-06-30 18:00'
        $servers.SelfSigned = Start-TestTlsServer -Certificate $selfSigned
        # Accepts the connection and never answers.
        $servers.Silent = Start-TestTlsServer -Certificate $pki.Web -Silent
        # The private PKI, as an administrator would pass it.
        $authority = $pki.Root, $pki.Intermediate
    }

    AfterAll {
        $servers.Values | ForEach-Object { Stop-TestTlsServer -Server $_ }
    }

    BeforeEach {
        Set-TestClock
    }

    It 'returns one object per server, with the certificate it presents and how it connected' {
        $result = @(Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $servers.Full.Port -CertificateAuthority $authority)
        $result.Count | Should -Be 1
        $result[0].PSObject.TypeNames | Should -Contain 'WinOpsAudit.TlsCertificate'
        $result[0].PSObject.Properties.Name | Should -Be @(
            'ComputerName', 'Port', 'Protocol', 'Subject', 'Issuer', 'DnsNames', 'Thumbprint',
            'SerialNumber', 'NotBefore', 'NotAfter', 'DaysLeft', 'Status', 'SignatureAlgorithm',
            'KeyAlgorithm', 'KeySize', 'WeakReason', 'SentCount', 'ChainStatus',
            'MissingCertificate', 'Findings')
        $result[0].ComputerName | Should -Be '127.0.0.1'
        $result[0].Port | Should -Be $servers.Full.Port
        $result[0].Protocol | Should -Match '^Tls'
        $result[0].Thumbprint | Should -Be $pki.Web.Thumbprint
        $result[0].DnsNames | Should -Be 'web01.contoso.test; www.contoso.test'
        $result[0].DaysLeft | Should -Be 215
    }

    It 'finds the chain complete when the server sends its intermediate (CRT-003)' {
        $result = Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $servers.Full.Port -CertificateAuthority $authority
        $result.SentCount | Should -Be 1
        $result.ChainStatus | Should -Be 'Complete'
        $result.MissingCertificate | Should -BeNullOrEmpty
        $result.Findings | Should -BeNullOrEmpty
    }

    It 'flags a server that does not send its intermediate, even when this computer has it (CRT-003)' {
        $result = Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $servers.LeafOnly.Port -CertificateAuthority $authority
        $result.SentCount | Should -Be 0
        $result.ChainStatus | Should -Be 'MissingIntermediate'
        $result.MissingCertificate | Should -Be 'CN=Contoso Test Issuing CA, O=Contoso Test'
        $result.Findings | Should -Be 'CRT-003'
    }

    It 'does not claim a missing intermediate when the issuer is unknown here (CRT-003)' {
        # Without -CertificateAuthority this computer does not know the private root: it cannot
        # tell who lacks the certificate, so it says so and reports no finding.
        $result = Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $servers.LeafOnly.Port
        $result.ChainStatus | Should -Be 'UnknownIssuer'
        $result.MissingCertificate | Should -Be 'CN=Contoso Test Issuing CA, O=Contoso Test'
        $result.Findings | Should -BeNullOrEmpty
    }

    It 'finds the chain of a self-signed certificate complete: there is nothing to send (CRT-003)' {
        $result = Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $servers.SelfSigned.Port
        $result.SentCount | Should -Be 0
        $result.ChainStatus | Should -Be 'Complete'
        $result.Findings | Should -BeNullOrEmpty
    }

    It 'flags a server whose certificate has expired (CRT-001)' {
        $result = Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $servers.Expired.Port -CertificateAuthority $authority
        $result.Status | Should -Be 'Expired'
        $result.DaysLeft | Should -Be -56
        $result.Findings | Should -Be 'CRT-001'
    }

    It 'lists only the servers whose certificate expires within N days with -ExpiringInDays' {
        $ports = $servers.Full.Port, $servers.Expired.Port
        $results = $ports | ForEach-Object {
            Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $_ -ExpiringInDays 30 -CertificateAuthority $authority
        }
        @($results).Count | Should -Be 1
        $results.Subject | Should -Be 'CN=old.contoso.test'
    }

    It 'goes on with the other servers when one does not answer, and says which' {
        # Nothing listens on 127.0.0.2: the connection is refused.
        $output = '127.0.0.2', '127.0.0.1' |
            Get-WinOpsAuditTlsCertificate -Port $servers.Full.Port -CertificateAuthority $authority -ErrorAction Continue 2>&1
        $problems = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $results = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
        $results.ComputerName | Should -Be '127.0.0.1'
        $problems.Count | Should -Be 1
        $problems[0].CategoryInfo.Category | Should -Be 'ConnectionError'
        $problems[0].TargetObject | Should -Be "127.0.0.2:$($servers.Full.Port)"
    }

    It 'gives up on a server that accepts the connection and never answers' {
        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        $output = Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $servers.Silent.Port -TimeoutSeconds 1 -ErrorAction Continue 2>&1
        $clock.Stop()
        $problems = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $problems.Count | Should -Be 1
        $problems[0].CategoryInfo.Category | Should -Be 'ConnectionError'
        $clock.Elapsed.TotalSeconds | Should -BeLessThan 10
    }

    It 'takes the names from the pipeline, also as a property' {
        $results = [pscustomobject]@{ ComputerName = '127.0.0.1' }, [pscustomobject]@{ HostName = '127.0.0.1' } |
            Get-WinOpsAuditTlsCertificate -Port $servers.Full.Port -CertificateAuthority $authority
        @($results).Count | Should -Be 2
    }

    It 'can be exported, and shows a short table by default' {
        $result = Get-WinOpsAuditTlsCertificate -ComputerName 127.0.0.1 -Port $servers.LeafOnly.Port -CertificateAuthority $authority
        $csv = $result | ConvertTo-Csv
        $csv[1] | Should -Not -Match 'System\.Object\[\]|PSCustomObject|List`1'
        $table = $result | Out-String
        $table | Should -Match 'ComputerName\s+Port\s+Subject\s+DaysLeft\s+Status\s+ChainStatus\s+Findings'
    }
}

# Against the real system: proves that Windows gives what the mocks above pretend it gives.
Describe 'On a real Windows certificate store' -Skip:(-not $IsWindows) {
    BeforeAll {
        # A certificate that expires in ten days, added to the store of the user running the
        # tests and removed at the end. Only the certificate: its key stays in memory.
        $now = Get-Date
        $made = New-TestCertificate -Subject 'CN=winopsaudit-test.contoso.test' -NotBefore $now.AddDays(-1) -NotAfter $now.AddDays(10).AddHours(1)
        $added = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($made.RawData)
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'CurrentUser')
        $store.Open('ReadWrite')
        $store.Add($added)
        $store.Dispose()
    }

    AfterAll {
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'CurrentUser')
        $store.Open('ReadWrite')
        $store.Remove($added)
        $store.Dispose()
    }

    It 'lists a certificate of CurrentUser\My that expires in ten days (CRT-001)' {
        $found = @(Get-WinOpsAuditCertificate -StoreLocation CurrentUser -ExpiringInDays 10 |
                Where-Object Thumbprint -EQ $added.Thumbprint)
        $found.Count | Should -Be 1
        $found[0].Store | Should -Be 'CurrentUser\My'
        $found[0].DaysLeft | Should -Be 10
        $found[0].Status | Should -Be 'Expiring'
        $found[0].HasPrivateKey | Should -BeFalse
        $found[0].Findings | Should -Be 'CRT-001'
    }

    It 'leaves it out with a shorter window' {
        Get-WinOpsAuditCertificate -StoreLocation CurrentUser -ExpiringInDays 9 |
            Where-Object Thumbprint -EQ $added.Thumbprint | Should -BeNullOrEmpty
    }

    It 'reads the trusted roots of the computer' {
        $roots = @(Get-WinOpsAuditCertificate -StoreName Root)
        $roots.Count | Should -BeGreaterThan 0
        $roots.Store | Sort-Object -Unique | Should -Be 'LocalMachine\Root'
    }
}
