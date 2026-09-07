function New-TeamsChatAuditLog {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Action,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ChatId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Status,

        [Parameter()]
        [string]$Reason,

        [Parameter()]
        [string]$ErrorMessage,

        [Parameter()]
        [string]$AuditPath = (Join-Path -Path $env:TEMP -ChildPath 'EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv')
    )

    $auditDirectory = Split-Path -Path $AuditPath -Parent
    if (-not (Test-Path -LiteralPath $auditDirectory)) {
        New-Item -Path $auditDirectory -ItemType Directory -Force | Out-Null
    }

    $entry = [pscustomobject]@{
        TimestampUtc = [DateTime]::UtcNow.ToString('o')
        Operator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Action = $Action
        ChatId = $ChatId
        Status = $Status
        Reason = $Reason
        ErrorMessage = $ErrorMessage
    }

    $entry | Export-Csv -Path $AuditPath -NoTypeInformation -Append
    return $AuditPath
}