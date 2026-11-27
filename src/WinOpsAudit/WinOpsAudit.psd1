@{
    RootModule           = 'WinOpsAudit.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'f96ef356-b003-45ba-8187-0a3937b0a3b0'
    Author               = 'zxxdev'
    CompanyName          = 'zxxdev'
    Copyright            = '(c) 2026 zxxdev. MIT License.'
    Description          = 'Read-only audits for Windows administrators: inventory, certificates, folder permissions and Active Directory. Returns objects; never changes anything.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    # Only read-only verbs: the tests fail if a Set-, Remove- or similar cmdlet is ever exported.
    FunctionsToExport    = @(
        'Get-WinOpsAuditCertificate'
        'Get-WinOpsAuditInventory'
        'Get-WinOpsAuditRule'
        'Get-WinOpsAuditSoftware'
        'Get-WinOpsAuditTlsCertificate'
        'Get-WinOpsAuditUpdate'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    # Default table views for the objects; they change how they look, not what they hold.
    FormatsToProcess     = @('WinOpsAudit.Format.ps1xml')

    PrivateData          = @{
        PSData = @{
            Tags       = @('Audit', 'Windows', 'ActiveDirectory', 'Certificates', 'NTFS', 'Inventory', 'ReadOnly', 'PSEdition_Core')
            LicenseUri = 'https://github.com/zxxdev/winops-audit/blob/main/LICENSE'
            ProjectUri = 'https://github.com/zxxdev/winops-audit'
        }
    }
}
