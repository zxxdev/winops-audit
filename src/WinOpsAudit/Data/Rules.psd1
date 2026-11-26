@{
    # The audit rules WinOpsAudit has or will have. Get-WinOpsAuditRule reads this file.
    # Status: Planned (not written yet) or Available (has its cmdlet, tests and help).
    # Session: the roadmap session that brings the rule.
    Rules = @(
        @{ Id = 'INV-001'; Area = 'Inventory'; Title = 'Hardware, operating system and installed updates'; Severity = 'Info'; Status = 'Available'; Session = 'WK-02' }
        @{ Id = 'INV-002'; Area = 'Inventory'; Title = 'Installed software, read from the uninstall registry keys'; Severity = 'Info'; Status = 'Available'; Session = 'WK-02' }
        @{ Id = 'CRT-001'; Area = 'Certificates'; Title = 'Certificate expires within the warning window'; Severity = 'High'; Status = 'Planned'; Session = 'WK-03' }
        @{ Id = 'CRT-002'; Area = 'Certificates'; Title = 'Weak signature algorithm or key size'; Severity = 'Medium'; Status = 'Planned'; Session = 'WK-03' }
        @{ Id = 'CRT-003'; Area = 'Certificates'; Title = 'Server does not send its full chain'; Severity = 'Medium'; Status = 'Planned'; Session = 'WK-03' }
        @{ Id = 'ACL-001'; Area = 'FolderPermissions'; Title = 'Inheritance broken on a folder'; Severity = 'Low'; Status = 'Planned'; Session = 'WK-04' }
        @{ Id = 'ACL-002'; Area = 'FolderPermissions'; Title = 'Permission granted to a user instead of a group'; Severity = 'Medium'; Status = 'Planned'; Session = 'WK-04' }
        @{ Id = 'ACL-003'; Area = 'FolderPermissions'; Title = 'Full control granted where modify would do'; Severity = 'Medium'; Status = 'Planned'; Session = 'WK-04' }
        @{ Id = 'AD-001'; Area = 'ActiveDirectory'; Title = 'Account not used for a long time (lastLogonTimestamp)'; Severity = 'Medium'; Status = 'Planned'; Session = 'WK-06' }
        @{ Id = 'AD-002'; Area = 'ActiveDirectory'; Title = 'Password set never to expire on a person''s account'; Severity = 'Medium'; Status = 'Planned'; Session = 'WK-06' }
        @{ Id = 'AD-003'; Area = 'ActiveDirectory'; Title = 'Member of a privileged group, nested groups included'; Severity = 'High'; Status = 'Planned'; Session = 'WK-06' }
        @{ Id = 'AD-004'; Area = 'ActiveDirectory'; Title = 'Computer or account trusted for unconstrained delegation'; Severity = 'High'; Status = 'Planned'; Session = 'WK-06' }
    )
}
