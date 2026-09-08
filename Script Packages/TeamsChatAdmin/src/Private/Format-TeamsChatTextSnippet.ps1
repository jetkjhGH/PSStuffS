function Format-TeamsChatTextSnippet {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$Text,

        [Parameter()]
        [ValidateRange(20, 500)]
        [int]$MaximumLength = 90
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $normalized = [regex]::Replace($Text, '\s+', ' ').Trim()
    if ($normalized.Length -le $MaximumLength) {
        return $normalized
    }

    return ('{0}...' -f $normalized.Substring(0, $MaximumLength - 3))
}