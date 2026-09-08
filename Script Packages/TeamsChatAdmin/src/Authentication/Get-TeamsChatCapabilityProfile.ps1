function Get-TeamsChatCapabilityProfile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string]$AuthType,

        [Parameter()]
        [string[]]$Scopes = @(),

        [Parameter()]
        [string[]]$Roles = @(),

        [Parameter()]
        [bool]$GraphSdkAvailable = $false,

        [Parameter()]
        [bool]$IsReadOnlyMode = $true,

        [Parameter()]
        [bool]$IsDestructiveDeleteEnabled = $false,

        [Parameter()]
        [bool]$DeletionSessionEnabled = $false
    )

    $access = Test-TeamsChatGraphAccess
    if ([string]::IsNullOrWhiteSpace($AuthType)) {
        $AuthType = $access.AuthType
    }

    if ($Scopes.Count -eq 0 -and $access.Scopes.Count -gt 0) {
        $Scopes = $access.Scopes
    }

    if (-not $GraphSdkAvailable) {
        $GraphSdkAvailable = $access.GraphSdkAvailable
    }

    $normalizedScopes = @($Scopes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $normalizedRoles = @($Roles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $readReportPermissions = @('Chat.ReadBasic', 'Chat.Read', 'Chat.ReadWrite', 'Chat.ReadBasic.All', 'Chat.Read.All', 'Chat.ReadWrite.All')
    $messageReadPermissions = @('Chat.Read', 'Chat.ReadWrite', 'ChatMessage.Read.Chat', 'Chat.Read.All', 'Chat.ReadWrite.All')
    $deletePermissions = @('Chat.ManageDeletion.All', 'Chat.ManageDeletion.Chat')
    $supportsReadReports = Test-TeamsChatPermission -GrantedPermission $normalizedScopes -RequiredPermission $readReportPermissions
    $supportsMessageRead = Test-TeamsChatPermission -GrantedPermission $normalizedScopes -RequiredPermission $messageReadPermissions
    $hasDeletionPermission = Test-TeamsChatPermission -GrantedPermission $normalizedScopes -RequiredPermission $deletePermissions
    $DeletionSessionEnabled = $DeletionSessionEnabled -or (-not $IsReadOnlyMode -and $IsDestructiveDeleteEnabled)
    $deleteEnabled = $DeletionSessionEnabled -and $hasDeletionPermission
    $restoreEnabled = $deleteEnabled

    return [pscustomobject]@{
        AuthType = $AuthType
        Connected = $access.Connected
        Account = $access.Account
        TenantId = $access.TenantId
        ClientId = $access.ClientId
        Scopes = $normalizedScopes
        Roles = $normalizedRoles
        GraphSdkAvailable = $GraphSdkAvailable
        GraphRequestAvailable = $access.GraphRequestAvailable
        IsReadOnlyMode = $IsReadOnlyMode
        HasDeletionPermission = $hasDeletionPermission
        DeletionSessionEnabled = $DeletionSessionEnabled
        IsDestructiveDeleteEnabled = $deleteEnabled
        SupportsReadReports = $supportsReadReports
        SupportsMessageRead = $supportsMessageRead
        SupportsSingleChatDeletion = $deleteEnabled
        SupportsBulkChatDeletion = $deleteEnabled
        SupportsDeletedChatRestore = $restoreEnabled
        Warning = if ($deleteEnabled) { 'Deletion and restore workflows are enabled for this session. Every action still requires preview, typed confirmation, and audit logging.' } elseif ($hasDeletionPermission) { 'Deletion and restore permission is present, but those workflows are disabled for this session until enabled from the interface.' } else { 'Deletion and restore workflows are unavailable because the current Graph context lacks Chat.ManageDeletion.All or Chat.ManageDeletion.Chat.' }
        Capabilities = @(
            [pscustomobject]@{
                Feature = 'List chats'
                Status = if ($supportsReadReports) { 'Available' } else { 'MissingPermission' }
                GraphVersion = 'v1.0'
                Delegated = 'Chat.ReadBasic, Chat.Read, Chat.ReadWrite'
                Application = 'Chat.ReadBasic.All, Chat.Read.All, Chat.ReadWrite.All'
                Destructive = $false
            },
            [pscustomobject]@{
                Feature = 'Get a chat'
                Status = 'Planned'
                GraphVersion = 'v1.0'
                Delegated = 'Chat.ReadBasic, Chat.Read, Chat.ReadWrite'
                Application = 'Chat.ReadBasic.WhereInstalled, Chat.Manage.Chat, Chat.Read.All, Chat.ReadBasic.All, Chat.ReadWrite.All, ChatSettings.Read.Chat, ChatSettings.ReadWrite.Chat'
                Destructive = $false
            },
            [pscustomobject]@{
                Feature = 'List members'
                Status = 'Planned'
                GraphVersion = 'v1.0'
                Delegated = 'Chat.ReadBasic, ChatMember.ReadWrite, Chat.Read, Chat.ReadWrite, ChatMember.Read'
                Application = 'ChatMember.Read.All'
                Destructive = $false
            },
            [pscustomobject]@{
                Feature = 'List messages'
                Status = if ($supportsMessageRead) { 'Available' } else { 'MissingPermission' }
                GraphVersion = 'v1.0'
                Delegated = 'Chat.Read, Chat.ReadWrite'
                Application = 'ChatMessage.Read.Chat, Chat.Read.All, Chat.ReadWrite.All'
                Destructive = $false
            },
            [pscustomobject]@{
                Feature = 'Delete chat'
                Status = if ($deleteEnabled) { 'AvailableWithConfirmation' } elseif ($hasDeletionPermission) { 'DisabledBySessionChoice' } else { 'MissingPermission' }
                GraphVersion = 'v1.0'
                Delegated = 'Chat.ManageDeletion.All'
                Application = 'Chat.ManageDeletion.Chat, Chat.ManageDeletion.All'
                Destructive = $true
            },
            [pscustomobject]@{
                Feature = 'Restore deleted chat'
                Status = if ($restoreEnabled) { 'AvailableWithConfirmation' } elseif ($hasDeletionPermission) { 'DisabledBySessionChoice' } else { 'MissingPermission' }
                GraphVersion = 'v1.0'
                Delegated = 'Chat.ManageDeletion.All'
                Application = 'Chat.ManageDeletion.Chat, Chat.ManageDeletion.All'
                Destructive = $true
            }
        )
    }
}
