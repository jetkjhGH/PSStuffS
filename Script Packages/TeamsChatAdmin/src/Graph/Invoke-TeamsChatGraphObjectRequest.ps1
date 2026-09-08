function Invoke-TeamsChatGraphObjectRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $invokeGraphCommand = Get-Command -Name 'Invoke-MgGraphRequest' -ErrorAction SilentlyContinue
    if (-not $invokeGraphCommand) {
        throw 'Microsoft Graph PowerShell SDK is required. Install Microsoft.Graph.Authentication and connect with the required chat permissions before running this command.'
    }

    try {
        return Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop
    }
    catch {
        if (Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) {
            throw 'Microsoft Graph rejected the request because the current token is expired or invalid. Reconnect with Connect-MgGraph using the required Teams chat scopes, then rerun the menu option.'
        }

        throw
    }
}