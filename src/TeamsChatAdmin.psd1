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
        'Get-TeamsChatByUser',
        'Get-TeamsChatThread',
        'Get-TeamsChatDeletePlan',
        'Get-TeamsChatCapabilityProfile',
        'Get-TeamsChatCapabilityMatrix',
        'Remove-TeamsChatThread',
        'Remove-TeamsChatThreadsBulk',
        'Test-TeamsChatGraphAccess'
    )
    CmdletsToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Teams', 'MicrosoftGraph', 'Chat', 'PowerShell')
            ProjectUri = 'https://github.com/jetkjhGH/PSStuffS'
            LicenseUri = ''
            ReleaseNotes = 'Portable Teams Chat Admin package with corrected launcher, compatibility wrapper, Windows Forms inspection GUI, and guarded terminal deletion workflows.'
        }
    }
}
