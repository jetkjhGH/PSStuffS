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
    Write-Host '2. List chats for a user, then select a row'
    if ($SessionState.CapabilityState.HasDeletionPermission) {
        Write-Host '3. Inspect and preview/delete one chat'
        Write-Host '4. Inspect and preview/delete multiple chats'
    }
    else {
        Write-Host '3. Inspect one chat from the last list'
        Write-Host '4. Inspect multiple chats from pasted IDs, last list, or CSV'
    }
    Write-Host '5. View audit log'
    Write-Host '6. Restore deleted chat (not executable until Graph restore endpoint is verified)'
    if ($SessionState.AllowDestructiveActions) {
        Write-Host '7. Disable deletion workflows for this session'
    }
    elseif ($SessionState.CapabilityState.HasDeletionPermission) {
        Write-Host '7. Enable deletion workflows for this session'
    }
    else {
        Write-Host '7. Explain deletion permission requirements'
    }
    Write-Host 'H. Help'
    Write-Host 'Q. Quit'
    Write-Host ''

    return (Read-Host 'Select an option').Trim()
}