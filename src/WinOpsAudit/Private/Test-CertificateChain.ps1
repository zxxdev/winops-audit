function Test-CertificateChain {
    <#
    .SYNOPSIS
    Decides whether a server sent the intermediate certificates its chain needs (CRT-003).

    .DESCRIPTION
    Private helper. A server should send its own certificate and every intermediate between it
    and the root; the root itself is optional, because the client already has it. When an
    intermediate is missing, a client that has it from before (in its store, its cache, or
    downloaded from the address in the certificate) connects fine, and another one fails. So
    whether this computer can complete the chain proves nothing (ADR 0003).

    The check builds the chain this computer would use, with everything it can find, and then
    looks at which certificates of that chain the server did not send:

      Complete             The chain reaches a root and every intermediate in it was sent.
      MissingIntermediate  The chain reaches a root, but one or more intermediates came from
                           this computer, not from the server. Missing lists them.
      UnknownIssuer        The chain does not reach a root: the issuer named in Missing is not
                           known here. It cannot tell whether the server or this computer lacks
                           it, so it is not reported as a finding.

    CertificateAuthority adds certificates of a private PKI: the self-signed ones are trusted as
    roots instead of this computer's, the others only help to build the chain.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

        [AllowEmptyCollection()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]] $Sent = @(),

        [AllowEmptyCollection()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]] $CertificateAuthority = @(),

        [ValidateRange(1, 300)]
        [int] $TimeoutSeconds = 10
    )

    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    try {
        $policy = $chain.ChainPolicy
        # The question is which certificates the chain needs, not whether it is valid today:
        # revocation is not checked.
        $policy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
        $policy.UrlRetrievalTimeout = [timespan]::FromSeconds($TimeoutSeconds)
        # Not "$certificate" as the loop variable: PowerShell does not tell it from $Certificate,
        # and the loop would replace the certificate being checked.
        foreach ($helper in $Sent) {
            [void]$policy.ExtraStore.Add($helper)
        }
        $roots = @($CertificateAuthority | Where-Object { Test-SelfIssued -Certificate $_ })
        foreach ($helper in $CertificateAuthority | Where-Object { -not (Test-SelfIssued -Certificate $_) }) {
            [void]$policy.ExtraStore.Add($helper)
        }
        if ($roots.Count -gt 0) {
            $policy.TrustMode = [System.Security.Cryptography.X509Certificates.X509ChainTrustMode]::CustomRootTrust
            foreach ($root in $roots) {
                [void]$policy.CustomTrustStore.Add($root)
            }
        }
        [void]$chain.Build($Certificate)

        # Read everything while the chain is alive: the certificates in it belong to the chain.
        $elements = @($chain.ChainElements | ForEach-Object Certificate)
        $top = $elements[-1]
        if (-not (Test-SelfIssued -Certificate $top)) {
            return [pscustomobject]@{
                Status  = 'UnknownIssuer'
                Missing = @($top.Issuer)
            }
        }
        $sentThumbprints = @($Sent | ForEach-Object Thumbprint)
        # Between the server's own certificate (first) and the root (last).
        $missing = @(
            $elements | Select-Object -Skip 1 | Select-Object -SkipLast 1 |
                Where-Object { $_.Thumbprint -notin $sentThumbprints } |
                ForEach-Object Subject
        )
        [pscustomobject]@{
            Status  = if ($missing.Count -gt 0) { 'MissingIntermediate' } else { 'Complete' }
            Missing = $missing
        }
    } finally {
        $chain.Dispose()
    }
}
