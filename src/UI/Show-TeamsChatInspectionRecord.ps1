function Show-TeamsChatInspectionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Chat
    )

    process {
        $details = [pscustomobject]@{
            Index = $Chat.Index
            ChatType = $Chat.ChatType
            ParticipantDetails = $Chat.ParticipantDetails
            Topic = $Chat.Topic
            LastUpdatedDateTime = $Chat.LastUpdatedDateTime
            LastMessagePreviewDateTime = $Chat.LastMessagePreviewDateTime
            LastMessagePreviewFrom = $Chat.LastMessagePreviewFrom
            LastMessagePreviewText = $Chat.LastMessagePreviewText
            ChatId = $Chat.ChatId
        }

        $details | Format-List
    }
}