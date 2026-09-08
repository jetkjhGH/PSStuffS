function Invoke-TeamsChatGraphCollectionRequest {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [switch]$All
    )

    $invokeGraphCommand = Get-Command -Name 'Invoke-MgGraphRequest' -ErrorAction SilentlyContinue
    if (-not $invokeGraphCommand) {
        throw 'Microsoft Graph PowerShell SDK is required. Install Microsoft.Graph.Authentication and connect with the required chat permissions before running this command.'
    }

    $results = [System.Collections.Generic.List[object]]::new()
    $nextUri = $Uri

    do {
        try {
            $response = Invoke-MgGraphRequest -Method GET -Uri $nextUri -ErrorAction Stop
        }
        catch {
            if (Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) {
                throw 'Microsoft Graph rejected the request because the current token is expired or invalid. Reconnect with Connect-MgGraph using the required Teams chat scopes, then rerun the menu option.'
            }

            throw
        }

        $responseValues = Get-TeamsChatObjectValue -InputObject $response -Name 'value'
        $pageValues = if ($null -eq $responseValues) { @() } else { @($responseValues) }
        foreach ($item in $pageValues) {
            $results.Add($item)
        }

        if ($All) {
            $nextUri = Get-TeamsChatObjectValue -InputObject $response -Name '@odata.nextLink'
        }
        else {
            $nextUri = $null
        }
    } while (-not [string]::IsNullOrWhiteSpace($nextUri))

    return $results.ToArray()
}