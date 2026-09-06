[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
 [switch]$UnattendedProvisioning
)

$folderPath = Join-Path (Join-Path $env:TEMP 'EDU Scripts') 'TeamSiteTrigger'
$RunTimestamp = Get-Date -Format 'MM-dd-yy_HH-mm-ss'
$NoSPOUNGResults = Join-Path $folderPath "NoSPOUNGResults$RunTimestamp.csv"
$SDSGroupNotTeamifiedResults = Join-Path $folderPath "SDSGroupNotTeamified$RunTimestamp.csv"
$GroupSiteDivergenceResults = Join-Path $folderPath "GroupSiteDivergence$RunTimestamp.csv"
$SPOSiteCreationResults = Join-Path $folderPath "SPOSiteCreationResults$RunTimestamp.csv"
$SPOCandidateRefreshFailureResults = Join-Path $folderPath "SPOCandidateRefreshFailures$RunTimestamp.csv"
$SDSObjectTypeKey = 'extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType'

if (-not (Test-Path -Path $folderPath)) {
 New-Item -ItemType Directory -Path $folderPath | Out-Null
}

function Read-SearchDateRange {
 [CmdletBinding()]
 param()

 do {
  $StartDateText = Read-Host 'Enter the search start date (yyyy-MM-dd)'
  $StartDate = [datetime]::MinValue
  $StartDateIsValid = [datetime]::TryParseExact(
   $StartDateText,
   'yyyy-MM-dd',
   [System.Globalization.CultureInfo]::InvariantCulture,
   [System.Globalization.DateTimeStyles]::None,
   [ref]$StartDate
  )
  if (-not $StartDateIsValid) {
   Write-Host 'Invalid start date. Use yyyy-MM-dd.' -ForegroundColor Yellow
  }
 } until ($StartDateIsValid)

 do {
  $EndDateText = Read-Host 'Enter the search end date (yyyy-MM-dd, inclusive)'
  $InclusiveEndDate = [datetime]::MinValue
  $EndDateIsValid = [datetime]::TryParseExact(
   $EndDateText,
   'yyyy-MM-dd',
   [System.Globalization.CultureInfo]::InvariantCulture,
   [System.Globalization.DateTimeStyles]::None,
   [ref]$InclusiveEndDate
  )

  if (-not $EndDateIsValid) {
   Write-Host 'Invalid end date. Use yyyy-MM-dd.' -ForegroundColor Yellow
  }
  elseif ($InclusiveEndDate -lt $StartDate) {
   Write-Host 'The end date cannot be earlier than the start date.' -ForegroundColor Yellow
   $EndDateIsValid = $false
  }
 } until ($EndDateIsValid)

 return [pscustomobject]@{
  StartDate        = $StartDate
  EndDateExclusive = $InclusiveEndDate.AddDays(1)
 }
}

function Read-SPOProvisioningConfirmation {
 [CmdletBinding()]
 [OutputType([bool])]
 param(
  [Parameter(Mandatory)]
  [ValidateRange(1, [int]::MaxValue)]
  [int]$CandidateCount
 )

 do {
  $Response = Read-Host "Request SharePoint site provisioning for $CandidateCount confirmed group(s)? (Y/N)"
  switch ($Response.Trim().ToUpperInvariant()) {
   'Y' { return $true }
   'N' { return $false }
   default { Write-Warning 'Enter Y to request provisioning or N to skip it.' }
  }
 } while ($true)
}

function ConvertTo-UtcDateTime {
 [CmdletBinding()]
 param(
  [AllowNull()]
  [object]$Value
 )

 if ($null -eq $Value) {
  return $null
 }
 if ($Value -is [datetimeoffset]) {
  return $Value.UtcDateTime
 }

 $DateTime = [datetime]$Value
 if ($DateTime.Kind -eq [System.DateTimeKind]::Unspecified) {
  return [datetime]::SpecifyKind($DateTime, [System.DateTimeKind]::Utc)
 }
 return $DateTime.ToUniversalTime()
}

function Compare-CreationDateTime {
 [CmdletBinding()]
 [OutputType([string])]
 param(
  [AllowNull()]
  [object]$First,

  [AllowNull()]
  [object]$Second
 )

 if ($null -eq $First -or $null -eq $Second) {
  return 'Unknown'
 }
 if ((ConvertTo-UtcDateTime -Value $First) -eq (ConvertTo-UtcDateTime -Value $Second)) {
  return 'False'
 }
 return 'True'
}

function Format-DateDifference {
 [CmdletBinding()]
 [OutputType([string])]
 param(
  [AllowNull()]
  [object]$First,

  [AllowNull()]
  [object]$Second,

  [switch]$Absolute
 )

 if ($null -eq $First -or $null -eq $Second) {
  return $null
 }

 $Difference = (ConvertTo-UtcDateTime -Value $Second) - (ConvertTo-UtcDateTime -Value $First)
 $Sign = if ($Difference.TotalSeconds -lt 0 -and -not $Absolute) { '-' } else { '' }
 $Magnitude = [math]::Abs($Difference.TotalSeconds)
 if ($Absolute) {
  $Sign = ''
 }

 if ($Magnitude -lt 60) {
  $Value = $Magnitude
  $Unit = 'second'
 }
 elseif ($Magnitude -lt 3600) {
  $Value = $Magnitude / 60
  $Unit = 'minute'
 }
 elseif ($Magnitude -lt 86400) {
  $Value = $Magnitude / 3600
  $Unit = 'hour'
 }
 else {
  $Value = $Magnitude / 86400
  $Unit = 'day'
 }

 $RoundedValue = [math]::Round($Value, 2)
 $UnitSuffix = if ($RoundedValue -eq 1) { '' } else { 's' }
 $FormattedValue = $RoundedValue.ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
 return "$Sign$FormattedValue $Unit$UnitSuffix"
}

function Get-GroupSiteDivergence {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [object]$Group
 )

 $GroupId = [string]$Group.ExternalDirectoryObjectId
 $UnifiedGroupCreatedDateTime = ConvertTo-UtcDateTime -Value $Group.WhenCreatedUTC
 $GraphGroupCreatedDateTime = $null
 $GroupSiteCreatedDateTime = $null
 $GraphSiteCreatedDateTime = $null
 $GroupSiteId = $null
 $GraphSiteId = $null
 $SiteCollectionId = $null
 $WebId = $null
 $SiteUrl = $null
 $GraphGroupStatus = 'Failed'
 $GroupSiteStatus = 'Failed'
 $GraphSiteStatus = 'Failed'
 $GraphGroupError = $null
 $GroupSiteError = $null
 $GraphSiteError = $null

 try {
  $GraphGroup = Get-MgGroup -GroupId $GroupId -Property 'id', 'createdDateTime' -ErrorAction Stop
  $GraphGroupCreatedDateTime = ConvertTo-UtcDateTime -Value $GraphGroup.CreatedDateTime
  $GraphGroupStatus = 'Success'
 }
 catch {
  $GraphGroupError = $_.Exception.Message
 }

 try {
  $GroupSite = Get-MgGroupSite -GroupId $GroupId -SiteId 'root' -Property 'id', 'createdDateTime', 'webUrl' -ErrorAction Stop
  $GroupSiteId = [string]$GroupSite.Id
  $GroupSiteCreatedDateTime = ConvertTo-UtcDateTime -Value $GroupSite.CreatedDateTime
  $SiteUrl = [string]$GroupSite.WebUrl
  $GroupSiteStatus = 'Success'

  $SiteIdParts = @($GroupSiteId -split ',', 3)
  if ($SiteIdParts.Count -eq 3) {
   $SiteCollectionId = $SiteIdParts[1]
   $WebId = $SiteIdParts[2]
  }
 }
 catch {
  $GroupSiteError = $_.Exception.Message
 }

 if (-not [string]::IsNullOrWhiteSpace($GroupSiteId)) {
  try {
   $GraphSite = Get-MgSite -SiteId $GroupSiteId -Property 'id', 'createdDateTime', 'webUrl' -ErrorAction Stop
   $GraphSiteId = [string]$GraphSite.Id
   $GraphSiteCreatedDateTime = ConvertTo-UtcDateTime -Value $GraphSite.CreatedDateTime
   if (-not [string]::IsNullOrWhiteSpace([string]$GraphSite.WebUrl)) {
    $SiteUrl = [string]$GraphSite.WebUrl
   }
   $GraphSiteStatus = 'Success'
  }
  catch {
   $GraphSiteError = $_.Exception.Message
  }
 }
 else {
  $GraphSiteError = 'Skipped because Get-MgGroupSite did not return a site ID.'
 }

 return [pscustomobject]@{
  GroupId                     = $GroupId
  DisplayName                 = $Group.DisplayName
  Alias                       = $Group.Alias
  UnifiedGroupCreatedDateTime = $UnifiedGroupCreatedDateTime
  GraphGroupCreatedDateTime   = $GraphGroupCreatedDateTime
  GroupCreatedDateDivergent   = Compare-CreationDateTime -First $UnifiedGroupCreatedDateTime -Second $GraphGroupCreatedDateTime
  GroupCreationDivergence     = Format-DateDifference -First $UnifiedGroupCreatedDateTime -Second $GraphGroupCreatedDateTime -Absolute
  GroupSiteId                 = $GroupSiteId
  GraphSiteId                 = $GraphSiteId
  SiteCollectionId            = $SiteCollectionId
  WebId                       = $WebId
  SiteUrl                     = $SiteUrl
  GroupRootSiteCreatedDateTime = $GroupSiteCreatedDateTime
  SiteByIdCreatedDateTime     = $GraphSiteCreatedDateTime
  SiteCreatedDateDivergent    = Compare-CreationDateTime -First $GroupSiteCreatedDateTime -Second $GraphSiteCreatedDateTime
  SiteCreationDivergence      = Format-DateDifference -First $GroupSiteCreatedDateTime -Second $GraphSiteCreatedDateTime -Absolute
  GroupToSiteProvisioningTime = Format-DateDifference -First $GraphGroupCreatedDateTime -Second $GroupSiteCreatedDateTime
  GraphGroupStatus            = $GraphGroupStatus
  GroupSiteStatus             = $GroupSiteStatus
  GraphSiteStatus             = $GraphSiteStatus
  GraphGroupError             = $GraphGroupError
  GroupSiteError              = $GroupSiteError
  GraphSiteError              = $GraphSiteError
 }
}

function Invoke-GroupSiteDivergenceReport {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [AllowEmptyCollection()]
  [object[]]$Group,

  [Parameter(Mandatory)]
  [string]$OutputPath
 )

 if ($Group.Count -eq 0) {
  Write-Host 'No groups were available for group and site divergence comparison.' -ForegroundColor Green
  return
 }

 $Results = [System.Collections.Generic.List[object]]::new()
 for ($Index = 0; $Index -lt $Group.Count; $Index++) {
  $Candidate = $Group[$Index]
  Write-Host "[$($Index + 1)/$($Group.Count)] Comparing group $($Candidate.ExternalDirectoryObjectId)" -ForegroundColor Yellow
  $Results.Add((Get-GroupSiteDivergence -Group $Candidate))
 }

 $Results | Export-Csv -Path $OutputPath -NoTypeInformation
 Write-Host "Exported $($Results.Count) group and site divergence rows to $OutputPath." -ForegroundColor Green
 Invoke-Item -Path $OutputPath
}

function Find-SDSClassTeamWithoutSiteUrl {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [object[]]$Group,

  [Parameter(Mandatory)]
  [datetime]$StartDate,

  [Parameter(Mandatory)]
    [datetime]$EndDateExclusive
 )

 $NoSPOUNCandidates = @($Group | Where-Object {
  [string]::IsNullOrWhiteSpace($_.SharePointSiteUrl) -and
  $_.WhenCreatedUTC -ge $StartDate -and
  $_.WhenCreatedUTC -lt $EndDateExclusive -and
  $_.HiddenGroupMembershipEnabled -eq $true -and
  $_.ResourceProvisioningOptions -contains 'Team'
 })
 $ConfirmedGroups = [System.Collections.Generic.List[object]]::new()
 $RefreshFailures = [System.Collections.Generic.List[object]]::new()

 foreach ($Candidate in $NoSPOUNCandidates) {
  try {
   $RefreshedGroup = Get-UnifiedGroup -Identity $Candidate.ExternalDirectoryObjectId -ErrorAction Stop
   if ($null -eq $RefreshedGroup) {
    $RefreshFailures.Add([pscustomobject]@{
     ExternalDirectoryObjectId = $Candidate.ExternalDirectoryObjectId
     DisplayName               = $Candidate.DisplayName
     Alias                     = $Candidate.Alias
     RevalidatedAt             = Get-Date
     Status                    = 'NotFound'
     Error                     = 'Get-UnifiedGroup returned no group.'
    })
   }
   elseif ([string]::IsNullOrWhiteSpace($RefreshedGroup.SharePointSiteUrl)) {
    $ConfirmedGroups.Add($RefreshedGroup)
   }
  }
  catch {
   Write-Warning "Unable to refresh Unified Group $($Candidate.ExternalDirectoryObjectId): $($_.Exception.Message)"
   $RefreshFailures.Add([pscustomobject]@{
    ExternalDirectoryObjectId = $Candidate.ExternalDirectoryObjectId
    DisplayName               = $Candidate.DisplayName
    Alias                     = $Candidate.Alias
    RevalidatedAt             = Get-Date
    Status                    = 'RefreshFailed'
    Error                     = $_.Exception.Message
   })
  }
 }

 return [pscustomobject]@{
  CandidateGroups = $NoSPOUNCandidates
  ConfirmedGroups = $ConfirmedGroups
  RefreshFailures = $RefreshFailures
 }
}

function Invoke-SPOCandidateRefreshFailureReport {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [AllowEmptyCollection()]
  [object[]]$RefreshFailure,

  [Parameter(Mandatory)]
  [string]$OutputPath
 )

 if ($RefreshFailure.Count -eq 0) {
  return
 }

 $RefreshFailure | Export-Csv -Path $OutputPath -NoTypeInformation
 Write-Warning "Unable to revalidate $($RefreshFailure.Count) missing-site candidate(s). They were excluded from site triggering. Details: $OutputPath"
 Invoke-Item -Path $OutputPath
}

function Test-TransientSPOTriggerError {
 [CmdletBinding()]
 [OutputType([bool])]
 param(
  [Parameter(Mandatory)]
  [string]$Message
 )

 return $Message -match '(?i)(\[?(404|408|429|500|502|503|504)\]?|not found|timed? out|timeout|throttl|service unavailable|temporarily unavailable)'
}

function Invoke-SPOSiteTrigger {
 [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
 param(
  [Parameter(Mandatory)]
  [AllowEmptyCollection()]
  [object[]]$Group,

  [Parameter()]
  [ValidateRange(1, 20)]
  [int]$MaximumAttempts = 3,

  [Parameter()]
  [ValidateRange(0, 300)]
  [int]$RetryDelaySeconds = 5
 )

 $Results = [System.Collections.Generic.List[object]]::new()
 Write-Host "Triggering Team site provisioning for $($Group.Count) group(s)." -ForegroundColor Cyan

 for ($Index = 0; $Index -lt $Group.Count; $Index++) {
  $Candidate = $Group[$Index]
  $GroupId = [string]$Candidate.ExternalDirectoryObjectId
  $Step = $Index + 1

  if (-not $PSCmdlet.ShouldProcess("$GroupId ($($Candidate.DisplayName))", 'Request SharePoint site provisioning through Microsoft Graph')) {
   $Status = if ($WhatIfPreference) { 'WhatIf' } else { 'Skipped' }
   $ErrorMessage = if ($WhatIfPreference) { 'WhatIf: no Microsoft Graph request was sent.' } else { 'Operator declined the provisioning request.' }
   $Results.Add([pscustomobject]@{
    Step        = $Step
    DisplayName = [string]$Candidate.DisplayName
    GroupId     = $GroupId
    Status      = $Status
    Attempts    = 0
    SiteId      = $null
    SiteUrl     = $null
    Error       = $ErrorMessage
   })
   continue
  }

  for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
   try {
    $Site = Get-MgGroupSite -GroupId $GroupId -SiteId 'root' -ErrorAction Stop
    $SiteId = [string]$Site.Id
    if ([string]::IsNullOrWhiteSpace($SiteId)) {
     $Results.Add([pscustomobject]@{
      Step        = $Step
      DisplayName = [string]$Candidate.DisplayName
      GroupId     = $GroupId
      Status      = 'Unverified'
      Attempts    = $Attempt
      SiteId      = $null
      SiteUrl     = [string]$Site.WebUrl
      Error       = 'Get-MgGroupSite returned no site ID.'
     })
     Write-Warning "[$Step/$($Group.Count)] The request for $GroupId returned no site ID. Provisioning was not confirmed."
     break
    }
    $Results.Add([pscustomobject]@{
     Step        = $Step
     DisplayName = [string]$Candidate.DisplayName
     GroupId     = $GroupId
     Status      = 'Triggered'
     Attempts    = $Attempt
    SiteId      = $SiteId
     SiteUrl     = [string]$Site.WebUrl
     Error       = $null
    })
    Write-Host "[$Step/$($Group.Count)] Triggered $GroupId on attempt $Attempt" -ForegroundColor Green
    break
   }
   catch {
    $ErrorMessage = $_.Exception.Message
    if ($ErrorMessage -match '(?i)\[accessDenied\]|\bAccess denied\b') {
     $Results.Add([pscustomobject]@{
      Step        = $Step
      DisplayName = [string]$Candidate.DisplayName
      GroupId     = $GroupId
      Status      = 'AccessDenied'
      Attempts    = $Attempt
      SiteId      = $null
      SiteUrl     = $null
      Error       = $ErrorMessage
     })
     Write-Warning "[$Step/$($Group.Count)] Access denied for $GroupId. Provisioning was not confirmed: $ErrorMessage"
     break
    }

    $ShouldRetry = $Attempt -lt $MaximumAttempts -and (Test-TransientSPOTriggerError -Message $ErrorMessage)
    if ($ShouldRetry) {
     Write-Host "[$Step/$($Group.Count)] Trigger attempt $Attempt failed for $GroupId; retrying in $RetryDelaySeconds second(s): $ErrorMessage" -ForegroundColor Yellow
     Start-Sleep -Seconds $RetryDelaySeconds
     continue
    }

    $Results.Add([pscustomobject]@{
     Step        = $Step
     DisplayName = [string]$Candidate.DisplayName
     GroupId     = $GroupId
     Status      = 'Failed'
     Attempts    = $Attempt
     SiteId      = $null
     SiteUrl     = $null
     Error       = $ErrorMessage
    })
    Write-Host "[$Step/$($Group.Count)] Failed $GroupId after $Attempt attempt(s): $ErrorMessage" -ForegroundColor Red
    break
   }
  }
 }

 return $Results
}

function Invoke-SPOSiteTriggerReport {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [AllowEmptyCollection()]
  [object[]]$Group,

  [Parameter(Mandatory)]
  [string]$OutputPath,

  [Parameter()]
  [ValidateRange(1, 20)]
  [int]$MaximumAttempts = 3,

  [Parameter()]
  [ValidateRange(0, 300)]
  [int]$RetryDelaySeconds = 5
 )

 if ($Group.Count -eq 0) {
  Write-Host 'No confirmed groups require a SharePoint site trigger.' -ForegroundColor Green
  return
 }

 $Results = @(Invoke-SPOSiteTrigger -Group $Group -MaximumAttempts $MaximumAttempts -RetryDelaySeconds $RetryDelaySeconds)
 $Results | Export-Csv -Path $OutputPath -NoTypeInformation

 $TriggeredCount = @($Results | Where-Object Status -eq 'Triggered').Count
 $WhatIfCount = @($Results | Where-Object Status -eq 'WhatIf').Count
 $SkippedCount = @($Results | Where-Object Status -eq 'Skipped').Count
 $AccessDeniedCount = @($Results | Where-Object Status -eq 'AccessDenied').Count
 $UnverifiedCount = @($Results | Where-Object Status -eq 'Unverified').Count
 $FailedCount = @($Results | Where-Object Status -eq 'Failed').Count
 Write-Host "Site trigger complete. Triggered: $TriggeredCount; WhatIf: $WhatIfCount; Skipped: $SkippedCount; Access denied: $AccessDeniedCount; Unverified: $UnverifiedCount; Failed: $FailedCount" -ForegroundColor Cyan
 Write-Host "Site trigger results: $OutputPath" -ForegroundColor Cyan
 Invoke-Item -Path $OutputPath
}

function Invoke-SDSClassTeamWithoutSiteUrlReport {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [AllowEmptyCollection()]
  [object[]]$Group,

  [Parameter(Mandatory)]
  [string]$OutputPath
 )

 if ($Group.Count -gt 0) {
  Write-Host "Found $($Group.Count) SDS Class Teams with no SiteURL." -ForegroundColor Green
  $Group | Select-Object ExternalDirectoryObjectId, WhenCreated, DisplayName, Alias, SharePointSiteUrl, SharePointDocumentsUrl, SharePointNotebookUrl | Export-Csv -Path $OutputPath -NoTypeInformation
  Invoke-Item -Path $OutputPath
 }
 else {
  Write-Host 'No SDS Class Teams with no SiteURL were found.' -ForegroundColor Green
 }
}

function Invoke-SDSGroupNotTeamifiedReport {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [object[]]$Group,

  [Parameter(Mandatory)]
  [string]$SDSObjectTypeKey,

  [Parameter(Mandatory)]
  [string]$OutputPath
 )

 $NonTeamGroups = @($Group | Where-Object {
  $_.ResourceProvisioningOptions -notcontains 'Team'
 })
 $SDSGroupNotTeamified = [System.Collections.Generic.List[object]]::new()

 Write-Host "Checking $($NonTeamGroups.Count) non-Team groups for the SDS Section extension..." -ForegroundColor Yellow
 foreach ($Candidate in $NonTeamGroups) {
  try {
  $GraphGroup = Get-MgGroup -GroupId $Candidate.ExternalDirectoryObjectId -Property 'id', $SDSObjectTypeKey -ErrorAction Stop
   $EducationObjectType = if ($null -ne $GraphGroup.AdditionalProperties) {
    [string]$GraphGroup.AdditionalProperties[$SDSObjectTypeKey]
   }
   else {
    $null
   }

   if ($EducationObjectType -eq 'Section') {
    $SDSGroupNotTeamified.Add([pscustomobject]@{
     ExternalDirectoryObjectId = $Candidate.ExternalDirectoryObjectId
     WhenCreated              = $Candidate.WhenCreated
     DisplayName              = $Candidate.DisplayName
     Alias                    = $Candidate.Alias
     EducationObjectType      = $EducationObjectType
     ResourceProvisioningOptions = ($Candidate.ResourceProvisioningOptions -join ';')
    })
   }
  }
  catch {
   Write-Warning "Unable to inspect group $($Candidate.ExternalDirectoryObjectId): $($_.Exception.Message)"
  }
 }

 if ($SDSGroupNotTeamified.Count -gt 0) {
  $SDSGroupNotTeamified | Export-Csv -Path $OutputPath -NoTypeInformation
  Write-Host "Found $($SDSGroupNotTeamified.Count) SDS created groups that are not Team-enabled." -ForegroundColor Green
  Invoke-Item -Path $OutputPath
 }
 else {
  Write-Host 'No SDS created groups without Team provisioning were found.' -ForegroundColor Green
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

 $RequiredCommands = @('Get-MgContext', 'Get-MgGroup', 'Get-MgGroupSite', 'Get-MgSite')
 $MissingCommands = @($RequiredCommands | Where-Object {
  -not (Get-Command $_ -ErrorAction SilentlyContinue)
 })
 if ($MissingCommands.Count -gt 0) {
  throw "Required Microsoft Graph command(s) not available: $($MissingCommands -join ', ')"
 }

 $Context = Get-MgContext -ErrorAction Stop
 if ($null -eq $Context) {
  throw 'Microsoft Graph is not connected. Run Connect-MgGraph before this script.'
 }
 $AuthenticationType = Resolve-GraphAuthenticationType -Context $Context
 if ($AuthenticationType -eq 'AppOnly') {
  Write-Host 'Connected to Microsoft Graph with app-only authentication (preferred).' -ForegroundColor Cyan
  Write-Host 'Application permissions are managed in Entra and cannot be validated from Get-MgContext.' -ForegroundColor Cyan
  return $Context
 }

 $ScopeRequirements = @(
  [pscustomobject]@{ Capability = 'read groups'; Accepted = @('Group.Read.All', 'Group.ReadWrite.All', 'Directory.Read.All', 'Directory.ReadWrite.All') }
  [pscustomobject]@{ Capability = 'read sites'; Accepted = @('Sites.Read.All', 'Sites.ReadWrite.All') }
 )
 $MissingCapabilities = @(
  foreach ($Requirement in $ScopeRequirements) {
   if (@($Requirement.Accepted | Where-Object { $_ -in $Context.Scopes }).Count -eq 0) {
    $Requirement.Capability
   }
  }
 )
 if ($MissingCapabilities.Count -gt 0) {
  throw "Microsoft Graph lacks permission to $($MissingCapabilities -join ', '). Reconnect with: Connect-MgGraph -Scopes Group.Read.All,Sites.Read.All"
 }

 Write-Host "Connected to Microsoft Graph as $($Context.Account)." -ForegroundColor Cyan
 Write-Warning 'Delegated site retrieval can fail unless the signed-in user has access to the group site; app-only authentication is preferred.'
 return $Context
}

function Test-ExchangeConnection {
 [CmdletBinding()]
 param()

 $MissingCommands = @(
  @('Get-OrganizationConfig', 'Get-UnifiedGroup') | Where-Object {
   -not (Get-Command $_ -ErrorAction SilentlyContinue)
  }
 )
 if ($MissingCommands.Count -gt 0) {
  throw "Required Exchange Online command(s) not available: $($MissingCommands -join ', ')"
 }

 $OrganizationConfig = Get-OrganizationConfig -ErrorAction Stop
 if ($null -eq $OrganizationConfig -or -not $OrganizationConfig.OrganizationId) {
  throw 'Exchange Online is not connected. Run Connect-ExchangeOnline before this script.'
 }

 Write-Host "Connected to Exchange Online. Org ID: $($OrganizationConfig.OrganizationId)" -ForegroundColor Cyan
}

$DateRange = Read-SearchDateRange
$StartDate = $DateRange.StartDate
$EndDate = $DateRange.EndDateExclusive

Test-GraphConnection
Test-ExchangeConnection

$StartDateFilterValue = $StartDate.ToString('MM/dd/yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
$EndDateFilterValue = $EndDate.ToString('MM/dd/yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
$UnifiedGroupFilter = "WhenCreatedUTC -ge '$StartDateFilterValue' -and WhenCreatedUTC -lt '$EndDateFilterValue'"

Write-Host "Retrieving Microsoft 365 groups created from $($StartDate.ToString('yyyy-MM-dd')) through $($EndDate.AddDays(-1).ToString('yyyy-MM-dd')). Exchange does not report progress..." -ForegroundColor Yellow
$RetrievalTimer = [System.Diagnostics.Stopwatch]::StartNew()
try {
 $UNGroups = @(Get-UnifiedGroup -Filter $UnifiedGroupFilter -ResultSize unlimited -ErrorAction Stop)
}
catch {
 $RetrievalTimer.Stop()
 throw "Unable to retrieve Microsoft 365 groups in the selected date range: $($_.Exception.Message)"
}
$RetrievalTimer.Stop()
Write-Host "Retrieved $($UNGroups.Count) groups in the selected date range in $($RetrievalTimer.Elapsed.ToString('hh\:mm\:ss'))." -ForegroundColor Green

$MissingSiteCandidates = Find-SDSClassTeamWithoutSiteUrl -Group $UNGroups -StartDate $StartDate -EndDateExclusive $EndDate
$NoSPOUNGs = @($MissingSiteCandidates.ConfirmedGroups)
Invoke-SDSClassTeamWithoutSiteUrlReport -Group @($MissingSiteCandidates.CandidateGroups) -OutputPath $NoSPOUNGResults
Invoke-SPOCandidateRefreshFailureReport -RefreshFailure @($MissingSiteCandidates.RefreshFailures) -OutputPath $SPOCandidateRefreshFailureResults
if ($NoSPOUNGs.Count -eq 0) {
 Write-Host 'No currently confirmed groups require a SharePoint site provisioning request.' -ForegroundColor Green
}
elseif ($WhatIfPreference) {
 Invoke-SPOSiteTriggerReport -Group $NoSPOUNGs -OutputPath $SPOSiteCreationResults -MaximumAttempts 3 -RetryDelaySeconds 5
}
elseif ($UnattendedProvisioning) {
 Write-Warning "Unattended provisioning was explicitly requested for $($NoSPOUNGs.Count) confirmed group(s)."
 Invoke-SPOSiteTriggerReport -Group $NoSPOUNGs -OutputPath $SPOSiteCreationResults -MaximumAttempts 3 -RetryDelaySeconds 5
}
elseif (Read-SPOProvisioningConfirmation -CandidateCount $NoSPOUNGs.Count) {
 Invoke-SPOSiteTriggerReport -Group $NoSPOUNGs -OutputPath $SPOSiteCreationResults -MaximumAttempts 3 -RetryDelaySeconds 5
}
else {
 Write-Host 'Skipping SharePoint site provisioning at the operator request.' -ForegroundColor Cyan
}
Invoke-GroupSiteDivergenceReport -Group $UNGroups -OutputPath $GroupSiteDivergenceResults
Invoke-SDSGroupNotTeamifiedReport -Group $UNGroups -SDSObjectTypeKey $SDSObjectTypeKey -OutputPath $SDSGroupNotTeamifiedResults