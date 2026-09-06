<#
.SYNOPSIS
 Identifies class Teams whose General channel has no message activity.

.DESCRIPTION
 Accepts Team IDs from a CSV, a paste dialog, or an SDS class-Team search by
 creation date. The script resolves each Team's primary channel directly and
 records both user-authored and system/service messages when evaluating activity.

 Microsoft Graph must already be connected. Exchange Online is required only
 when the SDS date-range search option is selected.

 App-only authentication requires the following Microsoft Graph Application
 permissions with tenant administrator consent:
 - Channel.ReadBasic.All
 - ChannelMessage.Read.All
 - Group.Read.All
 - Team.ReadBasic.All
#>

[CmdletBinding()]
param(
 [Parameter()]
 [string]$OutputDirectory = (Join-Path (Join-Path $env:TEMP 'EDU Scripts') 'ClassChannelActivity'),

 [Parameter()]
 [switch]$SkipOpenResults
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredGraphScopes = @(
 'Channel.ReadBasic.All'
 'ChannelMessage.Read.All'
 'Group.Read.All'
 'Team.ReadBasic.All'
)
$script:EducationObjectTypeAttribute = 'extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType'

function Show-ConnectionRequirements {
 [CmdletBinding()]
 param()

 Write-Host ''
 Write-Host 'Microsoft Graph connection required' -ForegroundColor Yellow
 Write-Host ("  Connect-MgGraph -Scopes {0}" -f ($script:RequiredGraphScopes -join ',')) -ForegroundColor Cyan
 Write-Host '  Exchange Online is checked only if you select SDS discovery by date.'
}

function Test-TeamId {
 [CmdletBinding()]
 [OutputType([bool])]
 param(
  [Parameter(Mandatory)]
  [AllowEmptyString()]
  [string]$Value
 )

 $parsedId = [guid]::Empty
 return [guid]::TryParse($Value.Trim().Trim('"'), [ref]$parsedId)
}

function ConvertTo-UniqueTeamId {
 [CmdletBinding()]
 [OutputType([string[]])]
 param(
  [Parameter(Mandatory)]
  [AllowEmptyCollection()]
  [string[]]$Value
 )

 $invalidIds = @($Value | Where-Object {
  -not [string]::IsNullOrWhiteSpace($_) -and -not (Test-TeamId -Value $_)
 })
 if ($invalidIds.Count -gt 0) {
  throw "Invalid Team ID value(s): $($invalidIds -join ', ')"
 }

 $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
 $teamIds = @(
  foreach ($id in $Value) {
   if (-not [string]::IsNullOrWhiteSpace($id)) {
    $normalizedId = ([guid]$id.Trim().Trim('"')).ToString()
    if ($seenIds.Add($normalizedId)) {
     $normalizedId
    }
   }
  }
 )

 if ($teamIds.Count -eq 0) {
  throw 'No valid Team IDs were supplied.'
 }

 return $teamIds
}

function Import-TeamIdCsv {
 [CmdletBinding()]
 [OutputType([string[]])]
 param()

 $csvPath = (Read-Host 'Enter the full path to the CSV file').Trim().Trim('"')
 if (-not (Test-Path -LiteralPath $csvPath -PathType Leaf)) {
  throw "CSV file not found: $csvPath"
 }

 $rows = @(Import-Csv -LiteralPath $csvPath)
 if ($rows.Count -eq 0) {
  throw "CSV file contains no data rows: $csvPath"
 }

 $candidateColumns = @(
  foreach ($header in $rows[0].PSObject.Properties.Name) {
   if ($rows | Where-Object { Test-TeamId -Value ([string]$_.$header) } | Select-Object -First 1) {
    $header
   }
  }
 )
 if ($candidateColumns.Count -eq 0) {
  throw 'No CSV column contains a valid Team ID.'
 }

 $selectedColumn = $null
 foreach ($column in $candidateColumns) {
  $choice = (Read-Host "Use GUID-bearing column '$column'? (Y/N/Q)").Trim().ToUpperInvariant()
  if ($choice -eq 'Q') {
   throw 'CSV import cancelled by the user.'
  }
  if ($choice -eq 'Y') {
   $selectedColumn = $column
   break
  }
 }
 if ($null -eq $selectedColumn) {
  throw 'No CSV column was selected.'
 }

 $values = @($rows | ForEach-Object { [string]$_.$selectedColumn })
 return ConvertTo-UniqueTeamId -Value $values
}

function Read-TeamIdInputBox {
 [CmdletBinding()]
 [OutputType([string[]])]
 param()

 Add-Type -AssemblyName Microsoft.VisualBasic
 $inputText = [Microsoft.VisualBasic.Interaction]::InputBox(
  'Enter Team IDs separated by commas or new lines:',
  'Enter Team IDs'
 )
 if ([string]::IsNullOrWhiteSpace($inputText)) {
  throw 'No Team IDs were entered.'
 }

 $values = @($inputText -split '[,\r\n]+' | ForEach-Object { $_.Trim().Trim('"') })
 return ConvertTo-UniqueTeamId -Value $values
}

function Read-SearchDateRange {
 [CmdletBinding()]
 param()

 do {
  $startDateText = Read-Host 'Enter the search start date (yyyy-MM-dd)'
  $startDate = [datetime]::MinValue
  $startDateIsValid = [datetime]::TryParseExact(
   $startDateText,
   'yyyy-MM-dd',
   [System.Globalization.CultureInfo]::InvariantCulture,
   [System.Globalization.DateTimeStyles]::None,
   [ref]$startDate
  )
  if (-not $startDateIsValid) {
   Write-Host 'Invalid start date. Use yyyy-MM-dd.' -ForegroundColor Yellow
  }
 } until ($startDateIsValid)

 do {
  $endDateText = Read-Host 'Enter the search end date (yyyy-MM-dd, inclusive)'
  $inclusiveEndDate = [datetime]::MinValue
  $endDateIsValid = [datetime]::TryParseExact(
   $endDateText,
   'yyyy-MM-dd',
   [System.Globalization.CultureInfo]::InvariantCulture,
   [System.Globalization.DateTimeStyles]::None,
   [ref]$inclusiveEndDate
  )
  if (-not $endDateIsValid) {
   Write-Host 'Invalid end date. Use yyyy-MM-dd.' -ForegroundColor Yellow
  }
  elseif ($inclusiveEndDate -lt $startDate) {
   Write-Host 'The end date cannot be earlier than the start date.' -ForegroundColor Yellow
   $endDateIsValid = $false
  }
 } until ($endDateIsValid)

 return [pscustomobject]@{
  StartDate        = $startDate
  EndDateExclusive = $inclusiveEndDate.AddDays(1)
 }
}

function Resolve-GraphAuthenticationType {
 [CmdletBinding()]
 [OutputType([string])]
 param(
  [Parameter(Mandatory)]
  [object]$Context
 )

 if ([string]$Context.AuthType -eq 'Delegated') {
  return 'Delegated'
 }
 if ([string]$Context.AuthType -eq 'AppOnly' -or
  ([string]$Context.AuthType -eq 'UserProvidedAccessToken' -and
  [string]::IsNullOrWhiteSpace([string]$Context.Account))) {
  return 'AppOnly'
 }

 throw "Unsupported Microsoft Graph authentication type: $($Context.AuthType)"
}

function Test-GraphConnection {
 [CmdletBinding()]
 param()

 $requiredCommands = @(
  'Get-MgContext'
  'Get-MgGroup'
  'Get-MgTeamPrimaryChannel'
  'Get-MgTeamChannelMessage'
 )
 $missingCommands = @($requiredCommands | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
 if ($missingCommands.Count -gt 0) {
  throw "Required Microsoft Graph command(s) not available: $($missingCommands -join ', ')"
 }

 $context = Get-MgContext -ErrorAction Stop
 if ($null -eq $context) {
  throw 'Microsoft Graph is not connected. Run Connect-MgGraph before this script.'
 }
 $authType = Resolve-GraphAuthenticationType -Context $context
 if ($authType -eq 'AppOnly') {
  Write-Host 'Connected to Microsoft Graph with app-only authentication.' -ForegroundColor Cyan
  return $context
 }
 if (-not (Get-Command 'Get-MgUserJoinedTeam' -ErrorAction SilentlyContinue)) {
  throw 'Required Microsoft Graph command not available for delegated authentication: Get-MgUserJoinedTeam'
 }

 $grantedScopes = @($context.Scopes)
 $scopeRequirements = @(
  [pscustomobject]@{
   Capability = 'read the primary channel'
   Accepted   = @('Channel.ReadBasic.All', 'ChannelSettings.Read.All', 'ChannelSettings.ReadWrite.All')
  }
  [pscustomobject]@{
   Capability = 'read groups'
   Accepted   = @('Group.Read.All', 'Group.ReadWrite.All', 'Directory.Read.All', 'Directory.ReadWrite.All')
  }
  [pscustomobject]@{
   Capability = 'read channel messages'
   Accepted   = @('ChannelMessage.Read.All', 'Group.Read.All', 'Group.ReadWrite.All')
  }
  [pscustomobject]@{
   Capability = 'list Teams joined by the signed-in user'
   Accepted   = @('Team.ReadBasic.All', 'TeamSettings.Read.All', 'TeamSettings.ReadWrite.All', 'Directory.Read.All', 'Directory.ReadWrite.All')
  }
 )
 $missingCapabilities = @(
  foreach ($requirement in $scopeRequirements) {
   if (@($requirement.Accepted | Where-Object { $_ -in $grantedScopes }).Count -eq 0) {
    $requirement.Capability
   }
  }
 )
 if ($missingCapabilities.Count -gt 0) {
  throw ("Microsoft Graph lacks permission to {0}. Reconnect with: Connect-MgGraph -Scopes {1}" -f ($missingCapabilities -join ', '), ($script:RequiredGraphScopes -join ','))
 }

 Write-Host "Connected to Microsoft Graph as $($context.Account)." -ForegroundColor Cyan
 return $context
}

function Get-DelegatedJoinedTeamIdSet {
 [CmdletBinding()]
 [OutputType([System.Collections.Generic.HashSet[string]])]
 param(
  [Parameter(Mandatory)]
  [string]$Account
 )

 Write-Host "Retrieving Teams joined by $Account..." -ForegroundColor Yellow
 $joinedTeamIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
 foreach ($team in @(Get-MgUserJoinedTeam -UserId $Account -All -ErrorAction Stop)) {
  if (-not [string]::IsNullOrWhiteSpace([string]$team.Id)) {
   $null = $joinedTeamIds.Add([string]$team.Id)
  }
 }

 Write-Host "The delegated account is a direct member of $($joinedTeamIds.Count) Team(s)." -ForegroundColor Cyan
 return ,$joinedTeamIds
}

function Get-GraphErrorInfo {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [System.Management.Automation.ErrorRecord]$ErrorRecord
 )

 $exception = $ErrorRecord.Exception
 $httpStatus = $null
 foreach ($propertyName in @('ResponseStatusCode', 'StatusCode')) {
  $property = $exception.PSObject.Properties[$propertyName]
  if ($null -ne $property -and $null -ne $property.Value) {
   $httpStatus = [string][int]$property.Value
   break
  }
 }
 if ([string]::IsNullOrWhiteSpace($httpStatus)) {
  switch -Regex ($exception.Message) {
   '\[Forbidden\]' { $httpStatus = '403'; break }
   '\[Unauthorized\]' { $httpStatus = '401'; break }
   '\[NotFound\]' { $httpStatus = '404'; break }
   '\[TooManyRequests\]' { $httpStatus = '429'; break }
  }
 }

 $requestId = $null
 $responseHeadersProperty = $exception.PSObject.Properties['ResponseHeaders']
 if ($null -ne $responseHeadersProperty -and $null -ne $responseHeadersProperty.Value) {
  $responseHeaders = $responseHeadersProperty.Value
  foreach ($headerName in @('request-id', 'client-request-id')) {
   if ($responseHeaders -is [System.Collections.IDictionary] -and $responseHeaders.Contains($headerName)) {
    $requestId = [string]$responseHeaders[$headerName]
    break
   }

   $tryGetValuesMethod = $responseHeaders.PSObject.Methods['TryGetValues']
   if ($null -ne $tryGetValuesMethod) {
    $headerValues = $null
    if ($responseHeaders.TryGetValues($headerName, [ref]$headerValues)) {
     $requestId = [string](@($headerValues) | Select-Object -First 1)
     break
    }
   }
  }
 }
 if ($exception.Data.Contains('RequestId')) {
  if ([string]::IsNullOrWhiteSpace($requestId)) {
   $requestId = [string]$exception.Data['RequestId']
  }
 }

 return [pscustomobject]@{
  Message    = $exception.Message
  HttpStatus = $httpStatus
  RequestId  = $requestId
 }
}

function New-GraphOperationException {
 [CmdletBinding()]
 [OutputType([System.Exception])]
 param(
  [Parameter(Mandatory)]
  [string]$Stage,

  [Parameter(Mandatory)]
  [System.Management.Automation.ErrorRecord]$ErrorRecord,

  [Parameter()]
  [string]$ChannelId,

  [Parameter()]
  [string]$ChannelName
 )

 $details = Get-GraphErrorInfo -ErrorRecord $ErrorRecord
 $exception = [System.Exception]::new($details.Message, $ErrorRecord.Exception)
 $exception.Data['ErrorStage'] = $Stage
 $exception.Data['HttpStatus'] = $details.HttpStatus
 $exception.Data['RequestId'] = $details.RequestId
 $exception.Data['ChannelId'] = $ChannelId
 $exception.Data['ChannelName'] = $ChannelName
 return $exception
}

function Test-ExchangeConnection {
 [CmdletBinding()]
 param()

 $requiredCommands = @('Get-OrganizationConfig', 'Get-UnifiedGroup')
 $missingCommands = @($requiredCommands | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
 if ($missingCommands.Count -gt 0) {
  throw "Required Exchange Online command(s) not available: $($missingCommands -join ', ')"
 }

 $organization = Get-OrganizationConfig -ErrorAction Stop
 if ($null -eq $organization -or -not $organization.OrganizationId) {
  throw 'Exchange Online is not connected. Run Connect-ExchangeOnline before using SDS date discovery.'
 }

 Write-Host 'Connected to Exchange Online.' -ForegroundColor Cyan
}

function Find-SDSClassTeamByDate {
 [CmdletBinding()]
 [OutputType([string[]])]
 param(
  [Parameter(Mandatory)]
  [datetime]$StartDate,

  [Parameter(Mandatory)]
  [datetime]$EndDateExclusive
 )

 Test-ExchangeConnection

 $startFilter = $StartDate.ToString('MM/dd/yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
 $endFilter = $EndDateExclusive.ToString('MM/dd/yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
 $filter = "WhenCreatedUTC -ge '$startFilter' -and WhenCreatedUTC -lt '$endFilter'"

 Write-Host 'Retrieving Microsoft 365 groups in the selected date range...' -ForegroundColor Yellow
 $groups = @(Get-UnifiedGroup -Filter $filter -ResultSize Unlimited)
 $candidates = @($groups | Where-Object {
  $_.HiddenGroupMembershipEnabled -eq $true -and
  $_.ResourceProvisioningOptions -contains 'Team'
 })

 $teamIds = @(
  foreach ($candidate in $candidates) {
   try {
    $graphGroup = Get-MgGroup -GroupId $candidate.ExternalDirectoryObjectId -ErrorAction Stop
    $educationObjectType = if ($null -ne $graphGroup.AdditionalProperties) {
     [string]$graphGroup.AdditionalProperties[$script:EducationObjectTypeAttribute]
    }
    else {
     $null
    }

    if ($educationObjectType -eq 'Section') {
     [string]$candidate.ExternalDirectoryObjectId
    }
   }
   catch {
    Write-Warning "Unable to inspect group $($candidate.ExternalDirectoryObjectId): $($_.Exception.Message)"
   }
  }
 )

 if ($teamIds.Count -eq 0) {
  Write-Host 'No SDS class Teams were found in the selected date range.' -ForegroundColor Yellow
  return @()
 }

 Write-Host "Found $($teamIds.Count) SDS class Team(s)." -ForegroundColor Green
 return ConvertTo-UniqueTeamId -Value $teamIds
}

function Show-InputMenu {
 [CmdletBinding()]
 [OutputType([string[]])]
 param()

 do {
  Write-Host ''
  Write-Host 'How would you like to supply the Team IDs?' -ForegroundColor Yellow
  Write-Host '1. Import a CSV file'
  Write-Host '2. Paste Team IDs into an input box'
  Write-Host '3. Search SDS class Teams by creation date'
  $selection = (Read-Host 'Enter 1, 2, or 3').Trim()

  switch ($selection) {
   '1' { return Import-TeamIdCsv }
   '2' { return Read-TeamIdInputBox }
   '3' {
    $dateRange = Read-SearchDateRange
    return Find-SDSClassTeamByDate -StartDate $dateRange.StartDate -EndDateExclusive $dateRange.EndDateExclusive
   }
   default { Write-Host 'Invalid selection. Enter 1, 2, or 3.' -ForegroundColor Yellow }
  }
 } while ($true)
}

function Get-TeamGeneralChannelActivity {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [string]$TeamId
 )

 try {
  $channel = Get-MgTeamPrimaryChannel -TeamId $TeamId -Property 'id', 'displayName' -ErrorAction Stop
 }
 catch {
  throw (New-GraphOperationException -Stage 'PrimaryChannelLookup' -ErrorRecord $_)
 }
 if ($null -eq $channel -or [string]::IsNullOrWhiteSpace([string]$channel.Id)) {
  $exception = [System.Exception]::new("The primary channel was not returned for Team $TeamId.")
  $exception.Data['ErrorStage'] = 'PrimaryChannelLookup'
  throw $exception
 }

 try {
  $messages = @(Get-MgTeamChannelMessage -TeamId $TeamId -ChannelId $channel.Id -All -ErrorAction Stop)
 }
 catch {
  throw (New-GraphOperationException -Stage 'ChannelMessageRead' -ErrorRecord $_ -ChannelId $channel.Id -ChannelName $channel.DisplayName)
 }

 $userMessageDates = [System.Collections.Generic.List[datetime]]::new()
 $systemMessageDates = [System.Collections.Generic.List[datetime]]::new()
 $ignoredSystemEventCount = 0
 foreach ($message in $messages) {
    $bodyContent = if ($null -eq $message.Body) { '' } else { [string]$message.Body.Content }
    $isSystemEvent = [string]$message.MessageType -eq 'systemEvent' -or (
     [string]$message.MessageType -eq 'unknownFutureValue' -and
     $bodyContent -match '(?i)^\s*<systemEventMessage\s*/>\s*$'
    )
    if ($isSystemEvent) {
   $ignoredSystemEventCount++
   continue
  }

  $messageDate = if ($null -ne $message.LastModifiedDateTime) {
   [datetime]$message.LastModifiedDateTime
  }
  else {
   [datetime]$message.CreatedDateTime
  }

  if ($null -ne $message.From -and
   $null -ne $message.From.User -and
   -not [string]::IsNullOrWhiteSpace([string]$message.From.User.Id)) {
   $userMessageDates.Add($messageDate)
  }
  else {
   $systemMessageDates.Add($messageDate)
  }
 }

 $latestUserActivity = $userMessageDates | Sort-Object -Descending | Select-Object -First 1
 $latestSystemActivity = $systemMessageDates | Sort-Object -Descending | Select-Object -First 1
 $latestChannelActivity = @($latestUserActivity, $latestSystemActivity | Where-Object { $null -ne $_ }) | Sort-Object -Descending | Select-Object -First 1
 $latestActivityType = if ($null -eq $latestChannelActivity) {
  $null
 }
 elseif ($null -ne $latestUserActivity -and $latestChannelActivity -eq $latestUserActivity) {
  'User'
 }
 else {
  'SystemOrService'
 }

 return [pscustomobject]@{
  ChannelId                 = [string]$channel.Id
  ChannelName               = [string]$channel.DisplayName
  LatestUserActivity        = $latestUserActivity
  LatestSystemActivity      = $latestSystemActivity
  LatestChannelActivity     = $latestChannelActivity
  LatestActivityType        = $latestActivityType
  UserActivityMessageCount  = $userMessageDates.Count
  SystemActivityMessageCount = $systemMessageDates.Count
  IgnoredSystemEventCount   = $ignoredSystemEventCount
  Status                    = if (($userMessageDates.Count + $systemMessageDates.Count) -gt 0) { 'Active' } else { 'NoChannelActivity' }
 }
}

function Invoke-ClassChannelActivityReport {
 [CmdletBinding()]
 [OutputType([pscustomobject[]])]
 param(
  [Parameter(Mandatory)]
  [string[]]$TeamId,

  [Parameter(Mandatory)]
  [ValidateSet('AppOnly', 'Delegated')]
  [string]$AuthType,

  [Parameter()]
  [System.Collections.Generic.HashSet[string]]$DelegatedTeamIdSet
 )
 if ($AuthType -eq 'Delegated' -and $null -eq $DelegatedTeamIdSet) {
  throw 'Delegated authentication requires the signed-in user joined-Team set.'
 }

 $results = [System.Collections.Generic.List[object]]::new()
 for ($index = 0; $index -lt $TeamId.Count; $index++) {
  $currentTeamId = $TeamId[$index]
  $displayName = $null
  Write-Host ("[{0}/{1}] Checking Team {2}" -f ($index + 1), $TeamId.Count, $currentTeamId) -ForegroundColor Cyan
  if ($AuthType -eq 'Delegated' -and -not $DelegatedTeamIdSet.Contains($currentTeamId)) {
   $results.Add([pscustomobject]@{
    DisplayName       = $null
    TeamId           = $currentTeamId
    ChannelName      = $null
    ChannelId        = $null
    LatestUserActivity = $null
    LatestSystemActivity = $null
    LatestChannelActivity = $null
    LatestActivityType = $null
    UserActivityMessageCount = $null
    SystemActivityMessageCount = $null
    IgnoredSystemEventCount = $null
    Status           = 'DelegatedUserNotMember'
    AuthType         = $AuthType
    ErrorStage       = 'MembershipCheck'
    HttpStatus       = $null
    RequestId        = $null
    Error            = 'The delegated account is not a direct member of this Team.'
   })
   continue
  }

  $errorStage = 'GroupLookup'
  try {
   $group = Get-MgGroup -GroupId $currentTeamId -Property 'displayName' -ErrorAction Stop
   $displayName = [string]$group.DisplayName
   $errorStage = $null
   $activity = Get-TeamGeneralChannelActivity -TeamId $currentTeamId
   $results.Add([pscustomobject]@{
    DisplayName       = $displayName
    TeamId           = $currentTeamId
    ChannelName      = $activity.ChannelName
    ChannelId        = $activity.ChannelId
    LatestUserActivity = $activity.LatestUserActivity
    LatestSystemActivity = $activity.LatestSystemActivity
    LatestChannelActivity = $activity.LatestChannelActivity
    LatestActivityType = $activity.LatestActivityType
    UserActivityMessageCount = $activity.UserActivityMessageCount
    SystemActivityMessageCount = $activity.SystemActivityMessageCount
    IgnoredSystemEventCount = $activity.IgnoredSystemEventCount
    Status           = $activity.Status
    AuthType         = $AuthType
    ErrorStage       = $null
    HttpStatus       = $null
    RequestId        = $null
    Error            = $null
   })
  }
  catch {
   $details = Get-GraphErrorInfo -ErrorRecord $_
   if ($_.Exception.Data.Contains('ErrorStage')) {
    $errorStage = [string]$_.Exception.Data['ErrorStage']
   }
   $channelId = if ($_.Exception.Data.Contains('ChannelId')) { [string]$_.Exception.Data['ChannelId'] } else { $null }
   $channelName = if ($_.Exception.Data.Contains('ChannelName')) { [string]$_.Exception.Data['ChannelName'] } else { $null }
   $httpStatus = if ($_.Exception.Data.Contains('HttpStatus')) { [string]$_.Exception.Data['HttpStatus'] } else { $details.HttpStatus }
   $requestId = if ($_.Exception.Data.Contains('RequestId')) { [string]$_.Exception.Data['RequestId'] } else { $details.RequestId }
   $status = if ($AuthType -eq 'Delegated' -and $errorStage -eq 'ChannelMessageRead' -and $httpStatus -eq '403') {
    'DelegatedAccessDenied'
   }
   else {
    'Error'
   }
   $results.Add([pscustomobject]@{
    DisplayName       = $displayName
    TeamId           = $currentTeamId
    ChannelName      = $channelName
    ChannelId        = $channelId
    LatestUserActivity = $null
    LatestSystemActivity = $null
    LatestChannelActivity = $null
    LatestActivityType = $null
    UserActivityMessageCount = $null
    SystemActivityMessageCount = $null
    IgnoredSystemEventCount = $null
    Status           = $status
    AuthType         = $AuthType
    ErrorStage       = $errorStage
    HttpStatus       = $httpStatus
    RequestId        = $requestId
    Error            = $details.Message
   })
   Write-Warning "Unable to inspect Team ${currentTeamId} during ${errorStage}: $($details.Message)"
  }
 }

 return $results.ToArray()
}

function Export-ClassChannelActivityReport {
 [CmdletBinding()]
 [OutputType([string])]
 param(
  [Parameter(Mandatory)]
  [object[]]$Result,

  [Parameter(Mandatory)]
  [string]$Directory,

  [Parameter()]
  [switch]$DoNotOpen
 )

 if (-not (Test-Path -LiteralPath $Directory)) {
  $null = New-Item -ItemType Directory -Path $Directory
 }

 $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
 $outputPath = Join-Path $Directory "ClassChannelActivity_$timestamp.csv"
 $Result | Export-Csv -LiteralPath $outputPath -NoTypeInformation
 Write-Host "Results exported to $outputPath" -ForegroundColor Green

 if (-not $DoNotOpen) {
  Invoke-Item -LiteralPath $outputPath
 }

 return $outputPath
}

function Invoke-ClassChannelActivityCheck {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [string]$ReportDirectory,

  [Parameter()]
  [switch]$DoNotOpen
 )

 Show-ConnectionRequirements
 $graphContext = Test-GraphConnection
 $teamIds = @(Show-InputMenu)
 if ($teamIds.Count -eq 0) {
  return
 }

 $authType = Resolve-GraphAuthenticationType -Context $graphContext
 $joinedTeamIds = if ($authType -eq 'AppOnly') {
  $null
 }
 else {
  Get-DelegatedJoinedTeamIdSet -Account $graphContext.Account
 }
 $results = @(Invoke-ClassChannelActivityReport -TeamId $teamIds -AuthType $authType -DelegatedTeamIdSet $joinedTeamIds)
 $inactiveCount = @($results | Where-Object Status -eq 'NoChannelActivity').Count
 $errorCount = @($results | Where-Object Status -eq 'Error').Count
 $delegatedAccessCount = @($results | Where-Object Status -in @('DelegatedUserNotMember', 'DelegatedAccessDenied')).Count
 Write-Host "Completed: $inactiveCount without channel activity; $delegatedAccessCount delegated access limitations; $errorCount other errors; $($results.Count) checked." -ForegroundColor Cyan
 $results | Format-Table DisplayName, TeamId, ChannelName, ChannelId, LatestChannelActivity, LatestActivityType, Status, ErrorStage -AutoSize

 $null = Export-ClassChannelActivityReport -Result $results -Directory $ReportDirectory -DoNotOpen:$DoNotOpen
 return $results
}

Invoke-ClassChannelActivityCheck -ReportDirectory $OutputDirectory -DoNotOpen:$SkipOpenResults
 