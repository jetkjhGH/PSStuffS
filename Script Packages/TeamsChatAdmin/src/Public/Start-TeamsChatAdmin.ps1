function Start-TeamsChatAdmin {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [ValidateSet('Terminal', 'Windows', 'Auto')]
        [string]$UiMode = 'Auto',

        [Parameter()]
        [string]$AuditPath = (Join-Path -Path $env:TEMP -ChildPath 'EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv')
    )

    $selectedUiMode = Read-TeamsChatUiMode -RequestedUiMode $UiMode -NonInteractive:$NonInteractive
    $allowDestructiveActions = $false
    $capabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$allowDestructiveActions

    if (-not $NonInteractive -and $selectedUiMode -eq 'Terminal' -and $capabilityState.HasDeletionPermission) {
        Write-Host ''
        Write-Host 'Deletion permissions were detected in the current Graph context.' -ForegroundColor Yellow
        Write-Host 'Deletion workflows stay disabled until you enable them for this session.' -ForegroundColor Yellow
        $enableDeletion = Read-Host 'Enable deletion workflows for this session? Type Y to enable, or press Enter for read-only mode'
        $allowDestructiveActions = $enableDeletion.Trim().ToUpperInvariant() -eq 'Y'
        $capabilityState = Get-TeamsChatCapabilityProfile -DeletionSessionEnabled:$allowDestructiveActions
    }

    $sessionState = [pscustomobject]@{
        UiMode = $selectedUiMode
        AllowDestructiveActions = $allowDestructiveActions
        AuditPath = $AuditPath
        CapabilityState = $capabilityState
        LastChatResults = @()
        LastListUserId = ''
    }
    $module = Get-Module -Name 'TeamsChatAdmin' | Select-Object -First 1
    $moduleVersion = $module.Version
    if ($null -eq $moduleVersion -or $moduleVersion.ToString() -eq '0.0') {
        $manifestCandidatePath = if ($module -and $module.Path) { Join-Path -Path (Split-Path -Path $module.Path -Parent) -ChildPath 'TeamsChatAdmin.psd1' } else { $null }
        if ($manifestCandidatePath -and (Test-Path -LiteralPath $manifestCandidatePath)) {
            $moduleVersion = (Import-PowerShellDataFile -Path $manifestCandidatePath).ModuleVersion
        }
        else {
            $moduleVersion = 'unknown'
        }
    }

    Write-Host ''
    Write-Host 'Teams Chat Admin' -ForegroundColor Cyan
    Write-Host ('Version: {0}' -f $moduleVersion)
    Write-Host ('Auth type: {0}' -f $capabilityState.AuthType)
    Write-Host ('Connected: {0}' -f $capabilityState.Connected)
    Write-Host ('Read reports: {0}' -f $capabilityState.SupportsReadReports)
    Write-Host ('Deletion permission detected: {0}' -f $capabilityState.HasDeletionPermission)
    Write-Host ('Deletion workflows enabled: {0}' -f $sessionState.AllowDestructiveActions)
    Write-Host ('Audit log: {0}' -f $sessionState.AuditPath)
    Write-Host $capabilityState.Warning -ForegroundColor Yellow
    Write-Host ''

    if ($NonInteractive) {
        return $sessionState
    }

    if ($selectedUiMode -eq 'Windows') {
        Start-TeamsChatWindowsGui -SessionState $sessionState
        return
    }

    Invoke-TeamsChatAdminInteractive -SessionState $sessionState
}
