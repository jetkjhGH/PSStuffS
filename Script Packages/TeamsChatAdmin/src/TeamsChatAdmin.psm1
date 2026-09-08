$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ModuleDirectories = @(
    'Private',
    'Authentication',
    'Graph',
    'Domain',
    'UI',
    'Reporting',
    'Audit',
    'Public'
)

foreach ($directoryName in $script:ModuleDirectories) {
    $directoryPath = Join-Path -Path $script:ModuleRoot -ChildPath $directoryName
    if (Test-Path -LiteralPath $directoryPath) {
        Get-ChildItem -Path $directoryPath -Recurse -Filter '*.ps1' | Sort-Object FullName | ForEach-Object {
            . $_.FullName
        }
    }
}

Export-ModuleMember -Function @(
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
