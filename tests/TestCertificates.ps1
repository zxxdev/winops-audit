# Helpers for the certificate tests, dot-sourced by Certificates.Tests.ps1. They make certificates
# in memory (a root, an intermediate and the certificates they sign) and run a small TLS server
# on 127.0.0.1, so the tests need no network and no files. Every name is made up (contoso.test).

# Signs a certificate with SHA-1 and RSA, which .NET no longer does on its own: the tests need
# such a certificate to check that CRT-002 finds it.
class Sha1RsaSigner : System.Security.Cryptography.X509Certificates.X509SignatureGenerator {
    hidden [System.Security.Cryptography.RSA] $Key

    Sha1RsaSigner([System.Security.Cryptography.RSA] $key) {
        $this.Key = $key
    }

    # sha1WithRSAEncryption (1.2.840.113549.1.1.5) with NULL parameters, encoded in DER.
    [byte[]] GetSignatureAlgorithmIdentifier([System.Security.Cryptography.HashAlgorithmName] $hashAlgorithm) {
        return [byte[]](0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x05, 0x05, 0x00)
    }

    [byte[]] SignData([byte[]] $data, [System.Security.Cryptography.HashAlgorithmName] $hashAlgorithm) {
        return $this.Key.SignData($data, [System.Security.Cryptography.HashAlgorithmName]::SHA1,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    }

    [System.Security.Cryptography.X509Certificates.PublicKey] BuildPublicKey() {
        return [System.Security.Cryptography.X509Certificates.X509SignatureGenerator]::CreateForRSA(
            $this.Key, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1).PublicKey
    }
}

function New-TestCertificate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Makes an object in memory; changes nothing on the system.')]
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param(
        [Parameter(Mandatory)]
        [string] $Subject,

        # Signs the new certificate; without it, the certificate is self-signed.
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Issuer,

        [Parameter(Mandatory)]
        [datetime] $NotBefore,

        [Parameter(Mandatory)]
        [datetime] $NotAfter,

        [ValidateSet('RSA', 'EC')]
        [string] $KeyAlgorithm = 'RSA',

        [int] $KeySize = 2048,

        [ValidateSet('SHA256', 'SHA1')]
        [string] $Hash = 'SHA256',

        [switch] $CertificateAuthority,

        [string[]] $DnsName
    )

    # The request always says SHA-256: .NET refuses to sign with SHA-1. A SHA-1 certificate is
    # signed by Sha1RsaSigner instead.
    $sha256 = [System.Security.Cryptography.HashAlgorithmName]::SHA256
    if ($KeyAlgorithm -eq 'RSA') {
        $key = [System.Security.Cryptography.RSA]::Create($KeySize)
        $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            $Subject, $key, $sha256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } else {
        $curve = [System.Security.Cryptography.ECCurve+NamedCurves]::nistP256
        $key = [System.Security.Cryptography.ECDsa]::Create($curve)
        $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new($Subject, $key, $sha256)
    }

    $extensions = $request.CertificateExtensions
    $extensions.Add([System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new(
            $CertificateAuthority.IsPresent, $false, 0, $true))
    $extensions.Add([System.Security.Cryptography.X509Certificates.X509SubjectKeyIdentifierExtension]::new(
            $request.PublicKey, $false))
    if ($Issuer) {
        $extensions.Add([System.Security.Cryptography.X509Certificates.X509AuthorityKeyIdentifierExtension]::CreateFromCertificate(
                $Issuer, $true, $false))
    }
    if ($DnsName) {
        $san = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
        $DnsName | ForEach-Object { $san.AddDnsName($_) }
        $extensions.Add($san.Build())
    }

    if (-not $Issuer -and $Hash -eq 'SHA256') {
        return $request.CreateSelfSigned($NotBefore, $NotAfter)
    }
    $serial = [byte[]]::new(16)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($serial)
    $serial[0] = $serial[0] -band 0x7F
    # Signed with the key of the issuer (always RSA here), or with its own when it is self-signed.
    $signingKey = if ($Issuer) { [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Issuer) } else { $key }
    $issuerName = if ($Issuer) { $Issuer.SubjectName } else { $request.SubjectName }
    $signer = if ($Hash -eq 'SHA1') {
        [Sha1RsaSigner]::new($signingKey)
    } else {
        [System.Security.Cryptography.X509Certificates.X509SignatureGenerator]::CreateForRSA(
            $signingKey, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    }
    $certificate = $request.Create($issuerName, $signer, $NotBefore, $NotAfter, $serial)
    if ($key -is [System.Security.Cryptography.RSA]) {
        [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::CopyWithPrivateKey($certificate, $key)
    } else {
        [System.Security.Cryptography.X509Certificates.ECDsaCertificateExtensions]::CopyWithPrivateKey($certificate, $key)
    }
}

function Start-TestTlsServer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Starts a listener on 127.0.0.1 for the length of a test.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The certificate the server presents, with its private key.
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

        # The other certificates it sends with it, usually the intermediates.
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]] $Chain = @(),

        # Accept connections but never answer: for the timeout tests.
        [switch] $Silent
    )

    if ($IsWindows) {
        # Schannel cannot use a key that only lives in memory: give it one it can open.
        $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
            $Certificate.Export('Pkcs12'), [string]::Empty,
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet)
    }
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    if ($Silent) {
        return [pscustomobject]@{ Port = $listener.LocalEndpoint.Port; Listener = $listener; Shell = $null; Handle = $null }
    }

    # The server runs in its own runspace, on another thread, while the test connects to it.
    $shell = [powershell]::Create()
    [void]$shell.AddScript({
            param($Listener, $Certificate, $Chain)
            $extra = [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
            foreach ($certificate in $Chain) {
                [void]$extra.Add($certificate)
            }
            # offline: build the chain from what is given, without looking anything up.
            $context = [System.Net.Security.SslStreamCertificateContext]::Create($Certificate, $extra, $true)
            while ($true) {
                try {
                    $client = $Listener.AcceptTcpClient()
                } catch {
                    # The test stopped the listener: the server ends.
                    break
                }
                try {
                    $ssl = [System.Net.Security.SslStream]::new($client.GetStream(), $false)
                    $options = [System.Net.Security.SslServerAuthenticationOptions]::new()
                    $options.ServerCertificateContext = $context
                    $ssl.AuthenticateAsServer($options)
                } catch {
                    # The client may hang up as soon as it has the certificate.
                    $null = $_
                } finally {
                    if ($ssl) { $ssl.Dispose() }
                    $client.Dispose()
                }
            }
        }).AddArgument($listener).AddArgument($Certificate).AddArgument($Chain)
    $handle = $shell.BeginInvoke()
    [pscustomobject]@{ Port = $listener.LocalEndpoint.Port; Listener = $listener; Shell = $shell; Handle = $handle }
}

function Stop-TestTlsServer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Stops the listener a test started.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Server
    )

    $Server.Listener.Stop()
    if ($Server.Shell) {
        [void]$Server.Shell.EndInvoke($Server.Handle)
        $Server.Shell.Dispose()
    }
}
