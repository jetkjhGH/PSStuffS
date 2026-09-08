function Show-TeamsChatAdminMenu {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$SessionState
    )

    Write-Host ''
    Write-Host 'Teams Chat Admin' -ForegroundColor Cyan
    Write-Host ('Graph connected: {0} | Read reports: {1} | Deletion permission: {2} | Deletion mode: {3}' -f $SessionState.CapabilityState.Connected, $SessionState.CapabilityState.SupportsReadReports, $SessionState.CapabilityState.HasDeletionPermission, $SessionState.AllowDestructiveActions)
    Write-Host ''
    Write-Host '1. Status and capability details'
    Write-Host 'U. Find a user by UPN or name'
    Write-Host '2. List chats for a user, then select a row'
    Write-Host '3. Inspect one chat'
    Write-Host '4. Inspect multiple chats'
    Write-Host '5. Preview and delete one chat'
    Write-Host '6. Preview and delete multiple chats'
    Write-Host '7. Restore deleted chat from audit logs or pasted ID'
    Write-Host '8. View audit log'
    if ($SessionState.AllowDestructiveActions) {
        Write-Host '9. Disable deletion and restore workflows for this session'
    }
    elseif ($SessionState.CapabilityState.HasDeletionPermission) {
        Write-Host '9. Enable deletion and restore workflows for this session'
    }
    else {
        Write-Host '9. Explain deletion and restore permission requirements'
    }
    Write-Host '10. Search threads between two users'
    Write-Host 'G. Launch Windows GUI'
    Write-Host 'H. Help'
    Write-Host 'Q. Quit'
    Write-Host ''

    return (Read-Host 'Select an option').Trim()
}