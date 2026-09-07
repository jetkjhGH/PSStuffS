function Test-TeamsChatPermission {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$GrantedPermission,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$RequiredPermission
    )

    $normalizedGrantedPermissions = @(
        $GrantedPermission |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim().ToLowerInvariant() }
    )

    foreach ($permission in $RequiredPermission) {
        if ([string]::IsNullOrWhiteSpace($permission)) {
            continue
        }

        if ($normalizedGrantedPermissions -contains $permission.Trim().ToLowerInvariant()) {
            return $true
        }
    }

    return $false
}