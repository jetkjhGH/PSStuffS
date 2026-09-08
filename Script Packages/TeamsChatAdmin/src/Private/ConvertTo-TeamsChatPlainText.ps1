function ConvertTo-TeamsChatPlainText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$Content
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $null
    }

    $withoutTags = [regex]::Replace($Content, '<[^>]+>', ' ')
    $decoded = [System.Net.WebUtility]::HtmlDecode($withoutTags)
    $normalized = [regex]::Replace($decoded, '\s+', ' ').Trim()

    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return '[attachment or non-text preview]'
    }

    return $normalized
}