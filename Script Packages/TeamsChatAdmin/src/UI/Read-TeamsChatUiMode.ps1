function Read-TeamsChatUiMode {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateSet('Terminal', 'Windows', 'Auto')]
        [string]$RequestedUiMode = 'Auto',

        [Parameter()]
        [switch]$NonInteractive
    )

    if ($NonInteractive) {
        return 'Terminal'
    }

    if ($RequestedUiMode -ne 'Auto') {
        return $RequestedUiMode
    }

    $windowsGuiAvailability = Test-TeamsChatWindowsGuiAvailable
    $windowsGuiAvailable = $windowsGuiAvailability.IsAvailable

    Write-Host ''
    Write-Host 'Choose interface' -ForegroundColor Cyan
    Write-Host '1. Continue in this terminal'
    if ($windowsGuiAvailable) {
        Write-Host '2. Switch to Windows GUI'
    }
    else {
        Write-Host '2. Windows GUI is unavailable; continue in terminal'
    }

    $selection = Read-Host 'Select 1 or 2'
    if ($selection.Trim() -eq '2' -and $windowsGuiAvailable) {
        return 'Windows'
    }

    if ($selection.Trim() -eq '2' -and -not $windowsGuiAvailable) {
        Write-Warning ('{0} Continuing in terminal mode.' -f $windowsGuiAvailability.Reason)
    }

    return 'Terminal'
}