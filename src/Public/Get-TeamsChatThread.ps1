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
        [switch]$IncludeLastMessagePreview
    )

    $capabilityState = Get-TeamsChatCapabilityProfile
    if (-not $capabilityState.SupportsReadReports) {
        throw 'The current Graph context does not include a supported chat read permission. Connect with Chat.ReadBasic, Chat.Read, Chat.ReadWrite, Chat.ReadBasic.All, Chat.Read.All, or Chat.ReadWrite.All.'
    }

    $escapedChatId = [System.Uri]::EscapeDataString($ChatId)
    $chat = Invoke-TeamsChatGraphObjectRequest -Uri ('https://graph.microsoft.com/v1.0/chats/{0}' -f $escapedChatId)
    $members = @()
    if ($IncludeMembers) {
        $members = @(Invoke-TeamsChatGraphCollectionRequest -Uri ('https://graph.microsoft.com/v1.0/chats/{0}/members' -f $escapedChatId) -All)
    }

    $lastMessagePreview = Get-TeamsChatObjectValue -InputObject $chat -Name 'lastMessagePreview'
    if ($IncludeLastMessagePreview -and $null -eq $lastMessagePreview -and $capabilityState.SupportsMessageRead) {
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
        members = $members
        lastMessagePreview = $lastMessagePreview
    } | ConvertTo-TeamsChatRecord
}