function Get-TeamsChatRestoreCandidate {
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter()]
        [string[]]$AuditPath = @(),

        [Parameter()]
        [string]$WorkingDirectory = (Get-Location).Path
    )

    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($path in @($AuditPath)) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $candidatePaths.Add($path)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory) -and (Test-Path -LiteralPath $WorkingDirectory)) {
        foreach ($file in @(Get-ChildItem -Path $WorkingDirectory -Filter '*TeamsChatAdminAudit*.csv' -File -ErrorAction SilentlyContinue)) {
            $candidatePaths.Add($file.FullName)
        }
    }

    $defaultTempAuditPath = Join-Path -Path $env:TEMP -ChildPath 'EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv'
    $candidatePaths.Add($defaultTempAuditPath)

    $existingPaths = @($candidatePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingPaths.Count -eq 0) {
        return @()
    }

    $rows = foreach ($path in $existingPaths) {
        foreach ($row in @(Import-Csv -Path $path)) {
            if ($row.PSObject.Properties.Match('ChatId').Count -eq 0 -or [string]::IsNullOrWhiteSpace($row.ChatId)) {
                continue
            }

            [pscustomobject]@{
                TimestampUtc = $row.TimestampUtc
                Operator = $row.Operator
                Action = $row.Action
                ChatId = $row.ChatId
                Status = $row.Status
                Reason = $row.Reason
                ErrorMessage = $row.ErrorMessage
                SourcePath = $path
            }
        }
    }

    $restoredIds = @($rows | Where-Object { $_.Action -eq 'RestoreDeletedChat' -and $_.Status -eq 'Restored' } | ForEach-Object { $_.ChatId } | Select-Object -Unique)
    $deletedRows = @($rows | Where-Object { $_.Action -in @('SoftDeleteChat', 'BulkSoftDeleteChat') -and $_.Status -eq 'Deleted' -and $_.ChatId -notin $restoredIds })

    $latestByChatId = @{}
    foreach ($row in $deletedRows) {
        $timestamp = [datetime]::MinValue
        if (-not [string]::IsNullOrWhiteSpace($row.TimestampUtc)) {
            [datetime]::TryParse($row.TimestampUtc, [ref]$timestamp) | Out-Null
        }

        if (-not $latestByChatId.ContainsKey($row.ChatId) -or $timestamp -gt $latestByChatId[$row.ChatId].ParsedTimestampUtc) {
            $latestByChatId[$row.ChatId] = [pscustomobject]@{
                ParsedTimestampUtc = $timestamp
                TimestampUtc = $row.TimestampUtc
                Operator = $row.Operator
                ChatId = $row.ChatId
                Reason = $row.Reason
                SourcePath = $row.SourcePath
            }
        }
    }

    $index = 0
    return @($latestByChatId.Values | Sort-Object ParsedTimestampUtc -Descending | ForEach-Object {
        $index++
        [pscustomobject]@{
            Index = $index
            ChatId = $_.ChatId
            DeletedTimestampUtc = $_.TimestampUtc
            DeletedBy = $_.Operator
            DeleteReason = $_.Reason
            AuditPath = $_.SourcePath
            RestoreWindow = 'Seven days after soft-delete'
        }
    })
}