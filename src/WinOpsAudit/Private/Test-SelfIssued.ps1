function Test-SelfIssued {
    <#
    .SYNOPSIS
    Tells whether a certificate names itself as its issuer, as a root does.

    .DESCRIPTION
    Private helper. Compares the subject and the issuer byte for byte, as encoded in the
    certificate, rather than as text: two names can look the same and be written differently.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate
    )

    [Convert]::ToBase64String($Certificate.SubjectName.RawData) -ceq
    [Convert]::ToBase64String($Certificate.IssuerName.RawData)
}
