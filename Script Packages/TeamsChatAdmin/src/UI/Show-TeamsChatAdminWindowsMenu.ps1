function Show-TeamsChatAdminWindowsMenu {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$SessionState
    )

    $outGridViewCommand = Get-Command -Name 'Out-GridView' -ErrorAction SilentlyContinue
    if (-not $IsWindows -or -not $outGridViewCommand) {
        Write-Warning 'Windows rich mode requires Windows PowerShell graphical components with Out-GridView. Falling back to terminal mode.'
        return Show-TeamsChatAdminMenu -SessionState $SessionState
    }

    $selection = @(
        [pscustomobject]@{ Option = '1'; Action = 'Status and capability details'; Availability = 'Always' },
        [pscustomobject]@{ Option = '2'; Action = 'List chats for a user, then select a row'; Availability = if ($SessionState.CapabilityState.SupportsReadReports) { 'Available' } else { 'Missing read permission' } },
        [pscustomobject]@{ Option = '3'; Action = 'Inspect one chat'; Availability = if ($SessionState.CapabilityState.SupportsReadReports) { 'Available' } else { 'Missing read permission' } },
        [pscustomobject]@{ Option = '4'; Action = 'Inspect multiple chats'; Availability = if ($SessionState.CapabilityState.SupportsReadReports) { 'Available' } else { 'Missing read permission' } },
        [pscustomobject]@{ Option = '5'; Action = 'Preview and delete one chat'; Availability = if ($SessionState.AllowDestructiveActions) { 'Enabled' } elseif ($SessionState.CapabilityState.HasDeletionPermission) { 'Requires workflow enablement' } else { 'Missing deletion permission' } },
        [pscustomobject]@{ Option = '6'; Action = 'Preview and delete multiple chats'; Availability = if ($SessionState.AllowDestructiveActions) { 'Enabled' } elseif ($SessionState.CapabilityState.HasDeletionPermission) { 'Requires workflow enablement' } else { 'Missing deletion permission' } },
        [pscustomobject]@{ Option = '7'; Action = 'Restore deleted chat from audit logs or pasted ID'; Availability = if ($SessionState.AllowDestructiveActions) { 'Enabled' } elseif ($SessionState.CapabilityState.HasDeletionPermission) { 'Requires workflow enablement' } else { 'Missing deletion permission' } },
        [pscustomobject]@{ Option = '8'; Action = 'View audit log'; Availability = 'Always' },
        [pscustomobject]@{ Option = '9'; Action = if ($SessionState.AllowDestructiveActions) { 'Disable deletion and restore workflows' } elseif ($SessionState.CapabilityState.HasDeletionPermission) { 'Enable deletion and restore workflows' } else { 'Explain deletion and restore permission requirements' }; Availability = 'Always' },
        [pscustomobject]@{ Option = '10'; Action = 'Search threads between two users'; Availability = if ($SessionState.CapabilityState.SupportsReadReports) { 'Available' } else { 'Missing read permission' } },
        [pscustomobject]@{ Option = 'G'; Action = 'Launch Windows GUI'; Availability = 'Available when Windows Forms is available' },
        [pscustomobject]@{ Option = 'H'; Action = 'Help'; Availability = 'Always' },
        [pscustomobject]@{ Option = 'Q'; Action = 'Quit' }
    ) | Out-GridView -Title 'Teams Chat Admin' -OutputMode Single

    if ($null -eq $selection) {
        return 'Q'
    }

    return $selection.Option
}