function Test-TeamsChatWindowsGuiAvailable {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $isWindowsPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    if (-not $isWindowsPlatform) {
        return [pscustomobject]@{
            IsAvailable = $false
            Reason = 'Windows GUI mode requires Windows.'
        }
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{
            IsAvailable = $false
            Reason = ('Windows GUI mode requires System.Windows.Forms and System.Drawing: {0}' -f $_.Exception.Message)
        }
    }

    return [pscustomobject]@{
        IsAvailable = $true
        Reason = 'Windows Forms is available.'
    }
}