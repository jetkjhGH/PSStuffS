function Get-TeamsChatBetweenUsers {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OtherUser,

        [Parameter()]
        [switch]$All
    )

    $normalizedOtherUser = $OtherUser.Trim()
    $comparisonValue = $normalizedOtherUser.ToLowerInvariant()
    $chats = @(Get-TeamsChatByUser -UserId $UserId -IncludeMembers -IncludeLastMessagePreview -All:$All)

    foreach ($chat in $chats) {
        $memberMatched = $false
        foreach ($member in @($chat.Members)) {
            $memberValues = @(
                Get-TeamsChatObjectValue -InputObject $member -Name 'userId'
                Get-TeamsChatObjectValue -InputObject $member -Name 'email'
                Get-TeamsChatObjectValue -InputObject $member -Name 'displayName'
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            foreach ($memberValue in $memberValues) {
                if ($memberValue.Trim().ToLowerInvariant() -eq $comparisonValue) {
                    $memberMatched = $true
                    break
                }
            }

            if ($memberMatched) {
                break
            }
        }

        if (-not $memberMatched -and -not [string]::IsNullOrWhiteSpace($chat.ParticipantSummary)) {
            $memberMatched = $chat.ParticipantSummary.ToLowerInvariant().Contains($comparisonValue)
        }

        if ($memberMatched) {
            $chat
        }
    }
}