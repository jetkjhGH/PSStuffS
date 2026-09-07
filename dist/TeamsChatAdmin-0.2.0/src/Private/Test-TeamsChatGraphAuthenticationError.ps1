function Test-TeamsChatGraphAuthenticationError {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $message = $ErrorRecord.ToString()
    $exceptionMessage = $ErrorRecord.Exception.Message
    $combinedMessage = '{0} {1}' -f $message, $exceptionMessage

    return (
        $combinedMessage -match '401\s+Unauthorized' -or
        $combinedMessage -match 'InvalidAuthenticationToken' -or
        $combinedMessage -match 'token is expired' -or
        $combinedMessage -match 'Lifetime validation failed'
    )
}