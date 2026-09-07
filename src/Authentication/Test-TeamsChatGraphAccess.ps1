function Test-TeamsChatGraphAccess {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $getContextCommand = Get-Command -Name 'Get-MgContext' -ErrorAction SilentlyContinue
    $invokeGraphCommand = Get-Command -Name 'Invoke-MgGraphRequest' -ErrorAction SilentlyContinue

    $context = $null
    $contextError = $null
    if ($getContextCommand) {
        try {
            $context = Get-MgContext -ErrorAction Stop
        }
        catch {
            $contextError = $_.Exception.Message
        }
    }

    $scopes = @()
    $authType = 'Unknown'
    $account = $null
    $tenantId = $null
    $clientId = $null

    if ($context) {
        $scopes = @($context.Scopes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($context.AuthType) {
            $authType = [string]$context.AuthType
        }
        $account = $context.Account
        $tenantId = $context.TenantId
        $clientId = $context.ClientId
    }

    return [pscustomobject]@{
        GraphSdkAvailable = [bool]$getContextCommand
        GraphRequestAvailable = [bool]$invokeGraphCommand
        Connected = [bool]$context
        AuthType = $authType
        Account = $account
        TenantId = $tenantId
        ClientId = $clientId
        Scopes = $scopes
        ContextError = $contextError
    }
}