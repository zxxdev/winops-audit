function Get-StoreCertificate {
    <#
    .SYNOPSIS
    Reads every certificate of one certificate store on this computer.

    .DESCRIPTION
    Private helper: the only place the module opens a certificate store. The tests replace it
    with certificates made in the test, so the logic around it is tested on Linux too. The store
    is opened read-only, and only if it exists: opening it never creates it. Any error stops; the
    caller decides whether that ends the cmdlet or only one store.
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.StoreLocation] $Location,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($Name, $Location)
    try {
        $flags = [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly -bor
        [System.Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly
        $store.Open($flags)
        # A new copy of each certificate: they stay usable after the store is closed.
        $store.Certificates
    } finally {
        $store.Dispose()
    }
}
