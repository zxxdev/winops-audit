function Get-TlsCertificateData {
    <#
    .SYNOPSIS
    Connects to a TLS server and returns the certificate it presents and the others it sends.

    .DESCRIPTION
    Private helper: the only place the module opens a network connection. It does the TLS
    handshake and nothing more: no data is sent after it, and the connection is closed.

    Any certificate is accepted, because the point is to look at it, not to trust it: an expired
    certificate is exactly what the audit wants to see. The certificates the server sends
    besides its own are the ones .NET hands to the validation callback in
    ChainPolicy.ExtraStore; that list is what CRT-003 judges.

    Returns Certificate, Sent (the other certificates, in the order received) and Protocol.
    Any error stops; the caller turns it into an error for that server only.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $ComputerName,

        [Parameter(Mandatory)]
        [int] $Port,

        [Parameter(Mandatory)]
        [int] $TimeoutSeconds
    )

    $timeout = [timespan]::FromSeconds($TimeoutSeconds)
    $seen = @{}
    # Called by SslStream during the handshake, on this thread, with the arguments
    # (sender, certificate, chain, errors). Copies what it needs, because SslStream disposes its
    # own objects afterwards, and accepts the certificate whatever it is.
    $accept = {
        $presented = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($args[1].GetRawCertData())
        $seen.Certificate = $presented
        $seen.Sent = @(
            if ($args[2]) {
                $args[2].ChainPolicy.ExtraStore |
                    Where-Object Thumbprint -NE $presented.Thumbprint |
                    ForEach-Object { [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($_.RawData) }
            }
        )
        $true
    }.GetNewClosure()

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        if (-not $client.ConnectAsync($ComputerName, $Port).Wait($timeout)) {
            throw [System.TimeoutException]::new("No answer within $TimeoutSeconds seconds.")
        }
        $stream = $client.GetStream()
        # Also a limit for the handshake: a port that accepts the connection and then says
        # nothing must not hang the audit.
        $stream.ReadTimeout = $stream.WriteTimeout = [int]$timeout.TotalMilliseconds
        $ssl = [System.Net.Security.SslStream]::new($stream, $false)
        try {
            $options = [System.Net.Security.SslClientAuthenticationOptions]::new()
            # The name is sent in the handshake (SNI): a server with several sites picks by it.
            $options.TargetHost = $ComputerName
            $options.CertificateRevocationCheckMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
            $options.RemoteCertificateValidationCallback = $accept
            $ssl.AuthenticateAsClient($options)
            [pscustomobject]@{
                Certificate = $seen.Certificate
                Sent        = $seen.Sent
                Protocol    = "$($ssl.SslProtocol)"
            }
        } finally {
            $ssl.Dispose()
        }
    } finally {
        $client.Dispose()
    }
}
