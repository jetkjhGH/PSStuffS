function Restore-TeamsChatDeletedThread {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('ChatId', 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$DeletedChatId,

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
        if (-not $capabilityState.SupportsDeletedChatRestore) {
            throw 'The current Graph context does not permit deleted-chat restore. Connect with Chat.ManageDeletion.All or Chat.ManageDeletion.Chat and enable deletion workflows for this session.'
        }

        if (-not $Force -and $TypedConfirmation -ne $DeletedChatId) {
            throw ('Refusing to restore chat {0}. Pass -TypedConfirmation with the exact deleted chat ID.' -f $DeletedChatId)
        }

        $status = 'SkippedByShouldProcess'
        $errorMessage = $null
        $escapedDeletedChatId = [System.Uri]::EscapeDataString($DeletedChatId)
        $uri = 'https://graph.microsoft.com/v1.0/teamwork/deletedChats/{0}/undoDelete' -f $escapedDeletedChatId

        try {
            if ($PSCmdlet.ShouldProcess($DeletedChatId, 'Restore deleted Microsoft Teams chat')) {
                $undoCommand = Get-Command -Name 'Undo-MgTeamworkDeletedChatDelete' -ErrorAction SilentlyContinue
                if ($undoCommand) {
                    Undo-MgTeamworkDeletedChatDelete -DeletedChatId $DeletedChatId -ErrorAction Stop | Out-Null
                }
                else {
                    Invoke-MgGraphRequest -Method POST -Uri $uri -ErrorAction Stop | Out-Null
                }

                $status = 'Restored'
            }
        }
        catch {
            $status = 'Failed'
            $errorMessage = if (Test-TeamsChatGraphAuthenticationError -ErrorRecord $_) { 'Microsoft Graph rejected the restore request because the current token is expired or invalid. Reconnect with Connect-MgGraph using the required Teams chat deletion scopes, then rerun the workflow.' } else { $_.Exception.Message }
            throw
        }
        finally {
            if (-not $WhatIfPreference) {
                New-TeamsChatAuditLog -Action 'RestoreDeletedChat' -ChatId $DeletedChatId -Status $status -Reason $Reason -ErrorMessage $errorMessage -AuditPath $AuditPath | Out-Null
            }
        }

        [pscustomobject]@{
            ChatId = $DeletedChatId
            Action = 'RestoreDeletedChat'
            Status = $status
            AuditPath = $AuditPath
            ErrorMessage = $errorMessage
        }
    }
}