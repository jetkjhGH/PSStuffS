function Remove-TeamsChatThreadsBulk {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ChatId,

        [Parameter()]
        [string]$Reason,

        [Parameter()]
        [ValidateSet('DELETE')]
        [string]$TypedConfirmation,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$ThrottleSeconds = 1,

        [Parameter()]
        [string]$AuditPath = (Join-Path -Path $env:TEMP -ChildPath 'EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv')
    )

    begin {
        if ($TypedConfirmation -ne 'DELETE') {
            throw "Bulk chat deletion requires -TypedConfirmation DELETE. Use -WhatIf with Get-TeamsChatDeletePlan first to preview targets."
        }
    }

    process {
        foreach ($currentChatId in $ChatId) {
            if ($PSCmdlet.ShouldProcess($currentChatId, 'Bulk soft-delete Microsoft Teams chat')) {
                Remove-TeamsChatThread -ChatId $currentChatId -Reason $Reason -TypedConfirmation $currentChatId -AuditPath $AuditPath -Confirm:$false
                Start-Sleep -Seconds $ThrottleSeconds
            }
            else {
                New-TeamsChatAuditLog -Action 'BulkSoftDeleteChat' -ChatId $currentChatId -Status 'SkippedByShouldProcess' -Reason $Reason -AuditPath $AuditPath | Out-Null
                [pscustomobject]@{
                    ChatId = $currentChatId
                    Action = 'BulkSoftDeleteChat'
                    Status = 'SkippedByShouldProcess'
                    AuditPath = $AuditPath
                    ErrorMessage = $null
                }
            }
        }
    }
}