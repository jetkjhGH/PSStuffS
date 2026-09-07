function Remove-TeamsChatThread {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string]$ChatId,

        [Parameter()]
        [string]$Reason,

        [Parameter()]
        [string]$TypedConfirmation,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [string]$AuditPath = (Join-Path -Path $env:TEMP -ChildPath 'EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv')
    )

    process {
        $capabilityState = Get-TeamsChatCapabilityProfile -IsReadOnlyMode:$false -IsDestructiveDeleteEnabled:$true
        if (-not $capabilityState.SupportsSingleChatDeletion) {
            throw 'The current Graph context does not permit chat deletion. Connect with Chat.ManageDeletion.All or Chat.ManageDeletion.Chat and run this command again.'
        }

        if (-not $Force -and $TypedConfirmation -ne $ChatId) {
            throw ('Refusing to delete chat {0}. Pass -TypedConfirmation with the exact chat ID, or use -WhatIf to preview.' -f $ChatId)
        }

        $status = 'SkippedByShouldProcess'
        $errorMessage = $null
        $uri = 'https://graph.microsoft.com/v1.0/chats/{0}' -f [System.Uri]::EscapeDataString($ChatId)

        try {
            if ($PSCmdlet.ShouldProcess($ChatId, 'Soft-delete Microsoft Teams chat')) {
                Invoke-MgGraphRequest -Method DELETE -Uri $uri -ErrorAction Stop | Out-Null
                $status = 'Deleted'
            }
        }
        catch {
            $status = 'Failed'
            $errorMessage = if (Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) { 'Microsoft Graph rejected the delete request because the current token is expired or invalid. Reconnect with Connect-MgGraph using the required Teams chat deletion scopes, then rerun the workflow.' } else { $_.Exception.Message }
            throw
        }
        finally {
            New-TeamsChatAuditLog -Action 'SoftDeleteChat' -ChatId $ChatId -Status $status -Reason $Reason -ErrorMessage $errorMessage -AuditPath $AuditPath | Out-Null
        }

        [pscustomobject]@{
            ChatId = $ChatId
            Action = 'SoftDeleteChat'
            Status = $status
            AuditPath = $AuditPath
            ErrorMessage = $errorMessage
        }
    }
}