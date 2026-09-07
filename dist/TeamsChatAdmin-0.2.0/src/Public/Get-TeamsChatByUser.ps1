function Get-TeamsChatByUser {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserId,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$Top = 50,

        [Parameter()]
        [switch]$IncludeMembers,

        [Parameter()]
        [switch]$IncludeLastMessagePreview,

        [Parameter()]
        [switch]$All
    )

    $capabilityState = Get-TeamsChatCapabilityProfile
    if (-not $capabilityState.SupportsReadReports) {
        throw 'The current Graph context does not include a supported chat read permission. Connect with Chat.ReadBasic, Chat.Read, Chat.ReadWrite, Chat.ReadBasic.All, Chat.Read.All, or Chat.ReadWrite.All.'
    }

    $escapedUserId = [System.Uri]::EscapeDataString($UserId)
    $queryParameters = [System.Collections.Generic.List[string]]::new()
    $queryParameters.Add(('$top={0}' -f $Top))

    $expandProperties = [System.Collections.Generic.List[string]]::new()
    if ($IncludeMembers) {
        $expandProperties.Add('members')
    }
    if ($IncludeLastMessagePreview) {
        $expandProperties.Add('lastMessagePreview')
    }
    if ($expandProperties.Count -gt 0) {
        $queryParameters.Add(('$expand={0}' -f ($expandProperties -join ',')))
    }

    $queryString = if ($queryParameters.Count -gt 0) { '?' + ($queryParameters -join '&') } else { '' }
    $uri = 'https://graph.microsoft.com/v1.0/users/{0}/chats{1}' -f $escapedUserId, $queryString

    Invoke-TeamsChatGraphCollectionRequest -Uri $uri -All:$All | ConvertTo-TeamsChatRecord
}