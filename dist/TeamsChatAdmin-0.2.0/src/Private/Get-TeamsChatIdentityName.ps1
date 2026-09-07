function Get-TeamsChatIdentityName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$IdentitySet
    )

    if ($null -eq $IdentitySet) {
        return $null
    }

    foreach ($identityType in @('user', 'application', 'device')) {
        $identity = Get-TeamsChatObjectValue -InputObject $IdentitySet -Name $identityType
        $displayName = Get-TeamsChatObjectValue -InputObject $identity -Name 'displayName'
        if (-not [string]::IsNullOrWhiteSpace($displayName)) {
            return $displayName
        }
    }

    return $null
}