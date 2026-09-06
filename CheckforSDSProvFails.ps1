$folderPath = Join-Path (Join-Path $env:TEMP 'EDU Scripts') 'TeamSiteTrigger'
$RunTimestamp = Get-Date -Format 'MM-dd-yy_HH-mm-ss'
$NoSPOUNGResults = Join-Path $folderPath "NoSPOUNGResults$RunTimestamp.csv"
$SDSGroupNotTeamifiedResults = Join-Path $folderPath "SDSGroupNotTeamified$RunTimestamp.csv"
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

function Invoke-SDSClassTeamWithoutSiteUrlReport {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)]
  [object[]]$Group,

  [Parameter(Mandatory)]
  [datetime]$StartDate,

  [Parameter(Mandatory)]
  [datetime]$EndDateExclusive,

  [Parameter(Mandatory)]
  [string]$OutputPath
 )

 $NoSPOUNGs = @($Group | Where-Object {
  [string]::IsNullOrWhiteSpace($_.SharePointSiteUrl) -and
  $_.WhenCreatedUTC -ge $StartDate -and
  $_.WhenCreatedUTC -lt $EndDateExclusive -and
  $_.HiddenGroupMembershipEnabled -eq $true -and
  $_.ResourceProvisioningOptions -contains 'Team'
 })
 if ($NoSPOUNGs.Count -gt 0) {
  Write-Host "Found $($NoSPOUNGs.Count) SDS Class Teams with no SiteURL." -ForegroundColor Green
  $NoSPOUNGs | Select-Object ExternalDirectoryObjectId, WhenCreated, DisplayName, Alias, SharePointSiteUrl, SharePointDocumentsUrl, SharePointNotebookUrl | Export-Csv -Path $OutputPath -NoTypeInformation
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
   $GraphGroup = Get-MgGroup -GroupId $Candidate.ExternalDirectoryObjectId -ErrorAction Stop
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

function Test-GraphConnection {
 [CmdletBinding()]
 param()

 $AcceptedScopes = @(
  'Group.Read.All'
  'Group.ReadWrite.All'
 )

 $MissingCommands = @(
  @('Get-MgContext', 'Get-MgGroup') | Where-Object {
   -not (Get-Command $_ -ErrorAction SilentlyContinue)
  }
 )
 if ($MissingCommands.Count -gt 0) {
  throw "Required Microsoft Graph command(s) not available: $($MissingCommands -join ', ')"
 }

 $Context = Get-MgContext -ErrorAction Stop
 if ($null -eq $Context -or [string]::IsNullOrWhiteSpace($Context.Account)) {
  throw 'Microsoft Graph is not connected. Run Connect-MgGraph before this script.'
 }

 $MatchingScopes = @($AcceptedScopes | Where-Object { $_ -in $Context.Scopes })
 if ($MatchingScopes.Count -eq 0) {
  throw "Microsoft Graph is missing a required group scope. Reconnect with Connect-MgGraph -Scopes Group.Read.All. Accepted scopes: $($AcceptedScopes -join ', ')"
 }

 Write-Host "Connected to Microsoft Graph as $($Context.Account)." -ForegroundColor Cyan
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
$UNGroups = @(Get-UnifiedGroup -Filter $UnifiedGroupFilter -ResultSize unlimited)
$RetrievalTimer.Stop()
Write-Host "Retrieved $($UNGroups.Count) groups in the selected date range in $($RetrievalTimer.Elapsed.ToString('hh\:mm\:ss'))." -ForegroundColor Green

Invoke-SDSClassTeamWithoutSiteUrlReport -Group $UNGroups -StartDate $StartDate -EndDateExclusive $EndDate -OutputPath $NoSPOUNGResults
Invoke-SDSGroupNotTeamifiedReport -Group $UNGroups -SDSObjectTypeKey $SDSObjectTypeKey -OutputPath $SDSGroupNotTeamifiedResults

