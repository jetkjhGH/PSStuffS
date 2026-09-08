function Find-TeamsChatUser {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SearchText,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Top = 25
    )

    $searchValue = $SearchText.Trim()
    if ($searchValue.Length -lt 3) {
        throw 'Enter at least three characters to search users by UPN, display name, first name, or last name.'
    }

    $escapedValue = $searchValue.Replace("'", "''")
    $filter = "startswith(userPrincipalName,'{0}') or startswith(displayName,'{0}') or startswith(givenName,'{0}') or startswith(surname,'{0}')" -f $escapedValue
    $uri = 'https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,givenName,surname,mail,accountEnabled&$top={0}&$filter={1}' -f $Top, [System.Uri]::EscapeDataString($filter)

    Invoke-TeamsChatGraphCollectionRequest -Uri $uri | ForEach-Object {
        [pscustomobject]@{
            Id = Get-TeamsChatObjectValue -InputObject $_ -Name 'id'
            DisplayName = Get-TeamsChatObjectValue -InputObject $_ -Name 'displayName'
            UserPrincipalName = Get-TeamsChatObjectValue -InputObject $_ -Name 'userPrincipalName'
            GivenName = Get-TeamsChatObjectValue -InputObject $_ -Name 'givenName'
            Surname = Get-TeamsChatObjectValue -InputObject $_ -Name 'surname'
            Mail = Get-TeamsChatObjectValue -InputObject $_ -Name 'mail'
            AccountEnabled = Get-TeamsChatObjectValue -InputObject $_ -Name 'accountEnabled'
        }
    }
}