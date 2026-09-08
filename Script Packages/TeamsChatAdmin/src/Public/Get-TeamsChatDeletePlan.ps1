function Get-TeamsChatDeletePlan {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ChatId,

        [Parameter()]
        [ValidateSet('Single', 'Bulk')]
        [string]$Mode = 'Single',

        [Parameter()]
        [string]$Reason
    )

    process {
        $capabilityState = Get-TeamsChatCapabilityProfile -IsReadOnlyMode:$false -IsDestructiveDeleteEnabled:$true
        foreach ($currentChatId in $ChatId) {
            [pscustomobject]@{
                ChatId = $currentChatId
                PlannedAction = 'SoftDeleteChat'
                Mode = $Mode
                Reason = $Reason
                GraphEndpoint = '/chats/{chat-id}'
                GraphMethod = 'DELETE'
                SupportsExecution = $capabilityState.SupportsSingleChatDeletion
                RequiresExecutionConfirmation = $true
                RequiresTypedConfirmation = if ($Mode -eq 'Bulk') { 'DELETE' } else { $currentChatId }
                TenantThrottle = 'One delete request per second per tenant'
                RestoreWindow = 'Seven days after soft-delete'
            }
        }
    }
}