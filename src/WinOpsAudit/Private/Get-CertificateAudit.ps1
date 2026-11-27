function Get-CertificateAudit {
    <#
    .SYNOPSIS
    Checks one certificate against the rules that need nothing but the certificate.

    .DESCRIPTION
    Private helper, shared by the cmdlets that read certificates from a store and from a server.
    It describes the certificate and applies two rules:

      CRT-001  It has expired, or expires within WarningDays days.
      CRT-002  It is signed with MD2, MD4, MD5 or SHA-1, or its key is short: RSA under 2048
               bits, EC under 256, or DSA of any size.

    The signature of a self-signed certificate (a root, for example) is not checked: nobody
    verifies it, because it is trusted for being in the store, not for its signature. Its key
    is checked like any other.

    Returns an ordered dictionary, so each cmdlet can put the values in its own object.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

        [Parameter(Mandatory)]
        [int] $WarningDays,

        [Parameter(Mandatory)]
        [datetime] $Now
    )

    # Signature algorithms no longer accepted, by OID.
    $weakSignatures = @{
        '1.2.840.113549.1.1.2' = 'MD2'
        '1.2.840.113549.1.1.3' = 'MD4'
        '1.2.840.113549.1.1.4' = 'MD5'
        '1.2.840.113549.1.1.5' = 'SHA-1'
        '1.3.14.3.2.29'        = 'SHA-1'
        '1.2.840.10040.4.3'    = 'SHA-1'
        '1.2.840.10045.4.1'    = 'SHA-1'
    }

    $publicKey = $Certificate.PublicKey
    $keyAlgorithm = switch ($publicKey.Oid.Value) {
        '1.2.840.113549.1.1.1' { 'RSA' }
        '1.2.840.10045.2.1' { 'EC' }
        '1.2.840.10040.4.1' { 'DSA' }
        default { if ($publicKey.Oid.FriendlyName) { $publicKey.Oid.FriendlyName } else { $publicKey.Oid.Value } }
    }
    $keySize = $null
    $key = $null
    try {
        $key = switch ($keyAlgorithm) {
            'RSA' { $publicKey.GetRSAPublicKey() }
            'EC' { $publicKey.GetECDsaPublicKey() }
            'DSA' { $publicKey.GetDSAPublicKey() }
        }
        if ($key) {
            $keySize = $key.KeySize
        }
    } catch {
        # A key this system cannot read: its size stays unknown rather than guessed.
        Write-Verbose "Could not read the key of $($Certificate.Subject): $($_.Exception.Message)"
    } finally {
        # Each call gives a new key object, which holds a handle of the system until disposed.
        if ($key) {
            $key.Dispose()
        }
    }

    $weak = [System.Collections.Generic.List[string]]::new()
    $signature = $Certificate.SignatureAlgorithm.Value
    if ($weakSignatures.ContainsKey($signature) -and -not (Test-SelfIssued -Certificate $Certificate)) {
        $weak.Add("signed with $($weakSignatures[$signature])")
    }
    # An unknown size is not a short one: in PowerShell $null -lt 2048 would be true.
    if ($null -eq $keySize -and $keyAlgorithm -ne 'DSA') {
        Write-Verbose "The key size of $($Certificate.Subject) is unknown: not checked."
    } elseif ($keyAlgorithm -eq 'RSA' -and $keySize -lt 2048) {
        $weak.Add("RSA key of $keySize bits, under 2048")
    } elseif ($keyAlgorithm -eq 'EC' -and $keySize -lt 256) {
        $weak.Add("EC key of $keySize bits, under 256")
    } elseif ($keyAlgorithm -eq 'DSA') {
        $weak.Add('DSA key, no longer accepted')
    }

    # Whole days left, cut towards zero: 13.9 days is 13, and the window counts in whole days.
    $daysLeft = [int][math]::Truncate(($Certificate.NotAfter - $Now).TotalDays)
    $status = if ($Certificate.NotAfter -le $Now) {
        'Expired'
    } elseif ($Certificate.NotBefore -gt $Now) {
        'NotYetValid'
    } elseif ($daysLeft -le $WarningDays) {
        'Expiring'
    } else {
        'Valid'
    }

    $findings = [System.Collections.Generic.List[string]]::new()
    if ($status -in 'Expired', 'Expiring') {
        $findings.Add('CRT-001')
    }
    if ($weak.Count -gt 0) {
        $findings.Add('CRT-002')
    }

    $dnsNames = @()
    $san = $Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' } | Select-Object -First 1
    if ($san) {
        $names = [System.Security.Cryptography.X509Certificates.X509SubjectAlternativeNameExtension]::new($san.RawData, $san.Critical)
        $dnsNames = @($names.EnumerateDnsNames())
    }

    [ordered]@{
        Subject            = $Certificate.Subject
        Issuer             = $Certificate.Issuer
        DnsNames           = $dnsNames -join '; '
        Thumbprint         = $Certificate.Thumbprint
        SerialNumber       = $Certificate.SerialNumber
        NotBefore          = $Certificate.NotBefore
        NotAfter           = $Certificate.NotAfter
        DaysLeft           = $daysLeft
        Status             = $status
        SignatureAlgorithm = if ($Certificate.SignatureAlgorithm.FriendlyName) { $Certificate.SignatureAlgorithm.FriendlyName } else { $signature }
        KeyAlgorithm       = $keyAlgorithm
        KeySize            = $keySize
        WeakReason         = $weak -join '; '
        Findings           = $findings
    }
}
