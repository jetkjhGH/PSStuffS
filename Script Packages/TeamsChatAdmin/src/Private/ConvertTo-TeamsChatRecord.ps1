function ConvertTo-TeamsChatRecord {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Chat
    )

    process {
        $lastMessagePreview = Get-TeamsChatObjectValue -InputObject $Chat -Name 'lastMessagePreview'
        $lastMessagePreviewBody = Get-TeamsChatObjectValue -InputObject $lastMessagePreview -Name 'body'
        $lastMessagePreviewFrom = Get-TeamsChatObjectValue -InputObject $lastMessagePreview -Name 'from'
        $memberValues = Get-TeamsChatObjectValue -InputObject $Chat -Name 'members'
        $members = if ($null -eq $memberValues) { @() } else { @($memberValues) }
        $memberLabels = foreach ($member in $members) {
            $displayName = Get-TeamsChatObjectValue -InputObject $member -Name 'displayName'
            $email = Get-TeamsChatObjectValue -InputObject $member -Name 'email'
            $userId = Get-TeamsChatObjectValue -InputObject $member -Name 'userId'

            if (-not [string]::IsNullOrWhiteSpace($displayName)) {
                if (-not [string]::IsNullOrWhiteSpace($email)) {
                    '{0} <{1}>' -f $displayName, $email
                }
                else {
                    $displayName
                }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($email)) {
                $email
            }
            elseif (-not [string]::IsNullOrWhiteSpace($userId)) {
                $userId
            }
        }
        $memberDisplayNames = foreach ($member in $members) {
            $displayName = Get-TeamsChatObjectValue -InputObject $member -Name 'displayName'
            $email = Get-TeamsChatObjectValue -InputObject $member -Name 'email'
            $userId = Get-TeamsChatObjectValue -InputObject $member -Name 'userId'

            if (-not [string]::IsNullOrWhiteSpace($displayName)) {
                $displayName
            }
            elseif (-not [string]::IsNullOrWhiteSpace($email)) {
                $email
            }
            elseif (-not [string]::IsNullOrWhiteSpace($userId)) {
                $userId
            }
        }
        $lastMessagePreviewText = ConvertTo-TeamsChatPlainText -Content (Get-TeamsChatObjectValue -InputObject $lastMessagePreviewBody -Name 'content')
        $chatStatus = Get-TeamsChatObjectValue -InputObject $Chat -Name 'chatStatus'
        if ([string]::IsNullOrWhiteSpace($chatStatus)) {
            $odataType = Get-TeamsChatObjectValue -InputObject $Chat -Name '@odata.type'
            $chatStatus = if ($odataType -match 'deletedChat') { 'Deleted' } else { 'Active' }
        }

        [pscustomobject]@{
            ChatId = Get-TeamsChatObjectValue -InputObject $Chat -Name 'id'
            ChatStatus = $chatStatus
            Topic = Get-TeamsChatObjectValue -InputObject $Chat -Name 'topic'
            ChatType = Get-TeamsChatObjectValue -InputObject $Chat -Name 'chatType'
            CreatedDateTime = Get-TeamsChatObjectValue -InputObject $Chat -Name 'createdDateTime'
            LastUpdatedDateTime = Get-TeamsChatObjectValue -InputObject $Chat -Name 'lastUpdatedDateTime'
            WebUrl = Get-TeamsChatObjectValue -InputObject $Chat -Name 'webUrl'
            IsHiddenForAllMembers = Get-TeamsChatObjectValue -InputObject $Chat -Name 'isHiddenForAllMembers'
            LastMessagePreviewId = Get-TeamsChatObjectValue -InputObject $lastMessagePreview -Name 'id'
            LastMessagePreviewDateTime = Get-TeamsChatObjectValue -InputObject $lastMessagePreview -Name 'createdDateTime'
            LastMessagePreviewIsDeleted = Get-TeamsChatObjectValue -InputObject $lastMessagePreview -Name 'isDeleted'
            LastMessagePreviewType = Get-TeamsChatObjectValue -InputObject $lastMessagePreview -Name 'messageType'
            LastMessagePreviewFrom = Get-TeamsChatIdentityName -IdentitySet $lastMessagePreviewFrom
            LastMessagePreviewText = $lastMessagePreviewText
            LastMessagePreviewSnippet = Format-TeamsChatTextSnippet -Text $lastMessagePreviewText
            MemberCount = if ($members.Count -gt 0) { $members.Count } else { $null }
            ParticipantSummary = if ($memberLabels.Count -gt 0) { $memberLabels -join '; ' } else { $null }
            ParticipantDisplayNames = if ($memberDisplayNames.Count -gt 0) { $memberDisplayNames -join ', ' } else { $null }
            Members = $members
            RawChat = $Chat
        }
    }
}