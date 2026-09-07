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
        [pscustomobject]@{ Option = '3'; Action = if ($SessionState.CapabilityState.HasDeletionPermission) { 'Inspect and preview/delete one chat' } else { 'Inspect one chat from the last list' }; Availability = if ($SessionState.CapabilityState.HasDeletionPermission) { 'Available after session enablement' } else { 'Inspection only' } },
        [pscustomobject]@{ Option = '4'; Action = if ($SessionState.CapabilityState.HasDeletionPermission) { 'Inspect and preview/delete multiple chats' } else { 'Inspect multiple chats' }; Availability = if ($SessionState.CapabilityState.HasDeletionPermission) { 'Available after session enablement' } else { 'Inspection only' } },
        [pscustomobject]@{ Option = '5'; Action = 'View audit log'; Availability = 'Always' },
        [pscustomobject]@{ Option = '6'; Action = 'Restore deleted chat'; Availability = 'Disabled until Graph restore endpoint is verified' },
        [pscustomobject]@{ Option = '7'; Action = if ($SessionState.AllowDestructiveActions) { 'Disable deletion workflows' } elseif ($SessionState.CapabilityState.HasDeletionPermission) { 'Enable deletion workflows' } else { 'Explain deletion permission requirements' }; Availability = 'Always' },
        [pscustomobject]@{ Option = 'H'; Action = 'Help'; Availability = 'Always' },
        [pscustomobject]@{ Option = 'Q'; Action = 'Quit' }
    ) | Out-GridView -Title 'Teams Chat Admin' -OutputMode Single

    if ($null -eq $selection) {
        return 'Q'
    }

    return $selection.Option
}