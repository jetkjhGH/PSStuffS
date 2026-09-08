function Get-TeamsChatThread {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ChatId,

        [Parameter()]
        [switch]$IncludeMembers,

        [Parameter()]
        [switch]$IncludeLastMessagePreview,

        [Parameter()]
        [switch]$IncludeMessageCount
    )

    $capabilityState = Get-TeamsChatCapabilityProfile
    if (-not $capabilityState.SupportsReadReports -and -not $capabilityState.HasDeletionPermission) {
        throw 'The current Graph context does not include supported chat read or deleted-chat inspection permission. Connect with Chat.ReadBasic, Chat.Read, Chat.ReadWrite, Chat.ReadBasic.All, Chat.Read.All, Chat.ReadWrite.All, Chat.ManageDeletion.All, or Chat.ManageDeletion.Chat.'
    }

    $escapedChatId = [System.Uri]::EscapeDataString($ChatId)
    $isDeletedChat = $false
    if ($capabilityState.SupportsReadReports) {
        try {
            $chat = Invoke-TeamsChatGraphObjectRequest -Uri ('https://graph.microsoft.com/v1.0/chats/{0}' -f $escapedChatId)
        }
        catch {
            $graphErrorMessage = '{0} {1}' -f $_.ToString(), $_.Exception.Message
            $isNotFound = $graphErrorMessage -match '404\s+NotFound' -or $graphErrorMessage -match 'NotFound\s+\(Not Found\)' -or $graphErrorMessage -match '\bNot Found\b'
            if (-not $isNotFound) {
                throw
            }

            if (-not $capabilityState.HasDeletionPermission) {
                throw ('Chat {0} was not found as an active chat. Deleted-chat inspection requires Chat.ManageDeletion.All or Chat.ManageDeletion.Chat.' -f $ChatId)
            }

            $chat = Invoke-TeamsChatGraphObjectRequest -Uri ('https://graph.microsoft.com/v1.0/teamwork/deletedChats/{0}' -f $escapedChatId)
            $isDeletedChat = $true
        }
    }
    else {
        $chat = Invoke-TeamsChatGraphObjectRequest -Uri ('https://graph.microsoft.com/v1.0/teamwork/deletedChats/{0}' -f $escapedChatId)
        $isDeletedChat = $true
    }

    $members = @()
    if ($IncludeMembers -and -not $isDeletedChat) {
        $members = @(Invoke-TeamsChatGraphCollectionRequest -Uri ('https://graph.microsoft.com/v1.0/chats/{0}/members' -f $escapedChatId) -All)
    }

    $lastMessagePreview = Get-TeamsChatObjectValue -InputObject $chat -Name 'lastMessagePreview'
    $messageCount = $null
    if ($IncludeMessageCount -and -not $isDeletedChat -and $capabilityState.SupportsMessageRead) {
        try {
            $messages = @(Invoke-TeamsChatGraphCollectionRequest -Uri ('https://graph.microsoft.com/v1.0/chats/{0}/messages' -f $escapedChatId) -All)
            $messageCount = $messages.Count
            if ($IncludeLastMessagePreview -and $null -eq $lastMessagePreview -and $messages.Count -gt 0) {
                $lastMessagePreview = $messages | Select-Object -First 1
            }
        }
        catch {
            if (Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) {
                throw
            }

            Write-Warning ('Unable to retrieve a message preview for chat {0}: {1}' -f $ChatId, $_.Exception.Message)
        }
    }
    elseif ($IncludeLastMessagePreview -and $null -eq $lastMessagePreview -and $capabilityState.SupportsMessageRead) {
        try {
            $messages = @(Invoke-TeamsChatGraphCollectionRequest -Uri ('https://graph.microsoft.com/v1.0/chats/{0}/messages?$top=1' -f $escapedChatId))
            if ($messages.Count -gt 0) {
                $lastMessagePreview = $messages | Select-Object -First 1
            }
        }
        catch {
            if (Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) {
                throw
            }

            Write-Warning ('Unable to retrieve a message preview for chat {0}: {1}' -f $ChatId, $_.Exception.Message)
        }
    }

    [pscustomobject]@{
        id = Get-TeamsChatObjectValue -InputObject $chat -Name 'id'
        topic = Get-TeamsChatObjectValue -InputObject $chat -Name 'topic'
        chatType = Get-TeamsChatObjectValue -InputObject $chat -Name 'chatType'
        createdDateTime = Get-TeamsChatObjectValue -InputObject $chat -Name 'createdDateTime'
        lastUpdatedDateTime = Get-TeamsChatObjectValue -InputObject $chat -Name 'lastUpdatedDateTime'
        webUrl = Get-TeamsChatObjectValue -InputObject $chat -Name 'webUrl'
        isHiddenForAllMembers = Get-TeamsChatObjectValue -InputObject $chat -Name 'isHiddenForAllMembers'
        chatStatus = if ($isDeletedChat) { 'Deleted' } else { 'Active' }
        members = $members
        messageCount = $messageCount
        lastMessagePreview = $lastMessagePreview
    } | ConvertTo-TeamsChatRecord
}