@{
    RootModule = 'TeamsChatAdmin.psm1'
    ModuleVersion = '0.2.0'
    GUID = '6f3ce4d2-6ef7-4d3a-9d17-6d6cd4cb3d90'
    Author = 'PSStuffS'
    CompanyName = 'PSStuffS'
    Copyright = '(c) 2026'
    Description = 'PowerShell 7 module for Microsoft Teams chat inspection, reporting, and safe administrative actions.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @(
        'Start-TeamsChatAdmin',
        'Invoke-TeamsChatAdminInteractive',
        'Get-TeamsChatAuditLog',
        'Get-TeamsChatRestoreCandidate',
        'Get-TeamsChatBetweenUsers',
        'Get-TeamsChatByUser',
        'Get-TeamsChatThread',
        'Find-TeamsChatUser',
        'Show-TeamsChatUserSearchDialog',
        'Get-TeamsChatDeletePlan',
        'Get-TeamsChatCapabilityProfile',
        'Get-TeamsChatCapabilityMatrix',
        'Remove-TeamsChatThread',
        'Remove-TeamsChatThreadsBulk',
        'Restore-TeamsChatDeletedThread',
        'Test-TeamsChatGraphAccess'
    )
    CmdletsToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Teams', 'MicrosoftGraph', 'Chat', 'PowerShell')
            ProjectUri = 'https://github.com/jetkjhGH/PSStuffS'
            LicenseUri = ''
            ReleaseNotes = 'Portable Teams Chat Admin package with Windows Forms inspection GUI, guarded deletion workflows, audit-backed restore candidates, deleted-chat restore support, and user-pair chat search.'
        }
    }
}
