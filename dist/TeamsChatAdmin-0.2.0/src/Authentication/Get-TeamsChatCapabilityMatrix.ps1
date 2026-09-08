function Get-TeamsChatCapabilityMatrix {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    return @(
        [pscustomobject]@{
            Feature = 'List chats'
            Endpoint = '/chats and /users/{id}/chats'
            Method = 'GET'
            GraphVersion = 'v1.0'
            DelegatedPermission = 'Chat.ReadBasic, Chat.Read, Chat.ReadWrite'
            ApplicationPermission = 'Chat.ReadBasic.All, Chat.Read.All, Chat.ReadWrite.All'
            RequiredAdminRole = 'None for supported delegated access; admin constraints depend on the specific scenario'
            SupportedChatType = '1:1, group, meeting'
            PowerShellSdkCommand = 'Get-MgChat / Get-MgUserChat'
            RawRestFallback = 'GET /users/{id}/chats or /chats'
            KnownRestriction = 'Expand members is limited to 25 items in the current documented behavior; $top max 50; pagination via @odata.nextLink'
            DestructiveOperation = $false
            ConfirmationRequirement = 'Not required'
        },
        [pscustomobject]@{
            Feature = 'Get chat'
            Endpoint = '/chats/{chat-id}'
            Method = 'GET'
            GraphVersion = 'v1.0'
            DelegatedPermission = 'Chat.ReadBasic, Chat.Read, Chat.ReadWrite'
            ApplicationPermission = 'Chat.ReadBasic.WhereInstalled, Chat.Manage.Chat, Chat.Read.All, Chat.ReadBasic.All, Chat.ReadWrite.All, ChatSettings.Read.Chat, ChatSettings.ReadWrite.Chat'
            RequiredAdminRole = 'Depends on scope and tenant access'
            SupportedChatType = '1:1, group, meeting'
            PowerShellSdkCommand = 'Get-MgChat'
            RawRestFallback = 'GET /chats/{chat-id}'
            KnownRestriction = 'Returns chat metadata only; messages are separate'
            DestructiveOperation = $false
            ConfirmationRequirement = 'Not required'
        },
        [pscustomobject]@{
            Feature = 'List chat members'
            Endpoint = '/chats/{chat-id}/members'
            Method = 'GET'
            GraphVersion = 'v1.0'
            DelegatedPermission = 'Chat.ReadBasic, ChatMember.ReadWrite, Chat.Read, Chat.ReadWrite, ChatMember.Read'
            ApplicationPermission = 'ChatMember.Read.All'
            RequiredAdminRole = 'Depends on scope and tenant access'
            SupportedChatType = '1:1, group, meeting'
            PowerShellSdkCommand = 'Get-MgChatMember'
            RawRestFallback = 'GET /chats/{chat-id}/members'
            KnownRestriction = 'Membership IDs are opaque and must not be parsed for meaning'
            DestructiveOperation = $false
            ConfirmationRequirement = 'Not required'
        },
        [pscustomobject]@{
            Feature = 'List chat messages'
            Endpoint = '/chats/{chat-id}/messages'
            Method = 'GET'
            GraphVersion = 'v1.0'
            DelegatedPermission = 'Chat.Read, Chat.ReadWrite'
            ApplicationPermission = 'ChatMessage.Read.Chat, Chat.Read.All, Chat.ReadWrite.All'
            RequiredAdminRole = 'Depends on scope and tenant access'
            SupportedChatType = '1:1, group, meeting'
            PowerShellSdkCommand = 'Get-MgChatMessage'
            RawRestFallback = 'GET /chats/{chat-id}/messages'
            KnownRestriction = 'Message reads can expose sensitive content and should be exported only to approved locations'
            DestructiveOperation = $false
            ConfirmationRequirement = 'Not required'
        },
        [pscustomobject]@{
            Feature = 'Delete chat'
            Endpoint = '/chats/{chat-id}'
            Method = 'DELETE'
            GraphVersion = 'v1.0'
            DelegatedPermission = 'Chat.ManageDeletion.All'
            ApplicationPermission = 'Chat.ManageDeletion.Chat, Chat.ManageDeletion.All'
            RequiredAdminRole = 'Delegated path requires tenant/admin or Teams service admin'
            SupportedChatType = '1:1, group, meeting; not channel threads'
            PowerShellSdkCommand = 'Remove-MgChat'
            RawRestFallback = 'DELETE /chats/{chat-id}'
            KnownRestriction = '7-day restore window; one delete request per second per tenant; not supported for channel chat threads'
            DestructiveOperation = $true
            ConfirmationRequirement = 'Required: preview + typed confirmation'
        },
        [pscustomobject]@{
            Feature = 'Restore deleted chat'
            Endpoint = '/teamwork/deletedChats/{deletedChatId}/undoDelete'
            Method = 'POST'
            GraphVersion = 'v1.0'
            DelegatedPermission = 'Chat.ManageDeletion.All'
            ApplicationPermission = 'Chat.ManageDeletion.Chat, Chat.ManageDeletion.All'
            RequiredAdminRole = 'Tenant admin or Teams service admin constraints apply to delegated admin operations'
            SupportedChatType = '1:1, group, meeting; not channel threads'
            PowerShellSdkCommand = 'Undo-MgTeamworkDeletedChatDelete'
            RawRestFallback = 'POST /teamwork/deletedChats/{deletedChatId}/undoDelete'
            KnownRestriction = 'Restore window is seven days after soft-delete; operation is not supported for non-admin users'
            DestructiveOperation = $true
            ConfirmationRequirement = 'Required: audit-derived or pasted target + typed confirmation'
        }
    )
}
