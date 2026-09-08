function Get-TeamsChatAuditLog {
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter()]
        [ValidateRange(1, 500)]
        [int]$Last = 10,

        [Parameter()]
        [string]$AuditPath = (Join-Path -Path $env:TEMP -ChildPath 'EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv')
    )

    if (-not (Test-Path -LiteralPath $AuditPath)) {
        return @()
    }

    return @(Import-Csv -Path $AuditPath | Select-Object -Last $Last)
}