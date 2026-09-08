<#
.SYNOPSIS
	Reports date-scoped SDS class provisioning conditions.

.DESCRIPTION
	Prompts for an inclusive date range, validates existing Microsoft Graph and Exchange
	Online sessions, and produces up to two CSV reports:

	1. Team-enabled, hidden-membership groups in range that have no SharePoint site URL.
	2. Groups in range that are not Team-enabled but carry the SDS education Section
	   extension.

	The Exchange query is filtered server-side to the selected dates. Microsoft Graph is
	then queried only for non-Team candidates. The script is read-only against the tenant.

.NOTES
	Required modules:
	- ExchangeOnlineManagement
	- Microsoft.Graph.Authentication
	- Microsoft.Graph.Groups

	Connect before running:
		Connect-ExchangeOnline
		Connect-MgGraph -Scopes 'Group.Read.All'

	The entered end date is inclusive. Non-empty CSV reports open automatically in the
	default application.
#>

#region Administrator-adjustable settings

# Change this folder when reports need a controlled retention location. The timestamp keeps
# multiple runs from overwriting one another.
$folderPath = Join-Path (Join-Path $env:TEMP 'EDU Scripts') 'TeamSiteTrigger'
$RunTimestamp = Get-Date -Format 'MM-dd-yy_HH-mm-ss'
$NoSPOUNGResults = Join-Path $folderPath "NoSPOUNGResults$RunTimestamp.csv"
$SDSGroupNotTeamifiedResults = Join-Path $folderPath "SDSGroupNotTeamified$RunTimestamp.csv"

#endregion Administrator-adjustable settings

# This extension name and its Section value are defined by SDS. Do not replace them with
# tenant-specific identifiers or values copied from Teams-client-created classes.
$SDSObjectTypeKey = 'extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType'

# Create the shared output folder before any report attempts to export a CSV.
if (-not (Test-Path -Path $folderPath)) {
 New-Item -ItemType Directory -Path $folderPath | Out-Null
}

function Read-SearchDateRange {
 <#
 .SYNOPSIS
  Prompts for and validates the diagnostic date range.

 .DESCRIPTION
  Accepts dates only in yyyy-MM-dd format. Converts the administrator's inclusive end date
  to an exclusive boundary by adding one day, which avoids time-of-day gaps in the Exchange
  filter and local comparisons.

 .OUTPUTS
  PSCustomObject containing StartDate and EndDateExclusive.
 #>
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
 <#
 .SYNOPSIS
  Exports Team-enabled SDS class candidates that have no SharePoint site URL.

 .DESCRIPTION
  Filters the date-scoped Exchange group collection for hidden-membership, Team-enabled
  groups with an empty SharePointSiteUrl. Exports and opens the CSV only when matches exist.

  The selected columns form the report contract. Add columns only when downstream consumers
  are also updated.
 #>
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
 <#
 .SYNOPSIS
  Exports SDS Section groups that are not Team-enabled.

 .DESCRIPTION
  Reduces the Exchange result set to groups without the Team provisioning option, then
  retrieves each candidate from Graph to inspect the SDS education extension. Per-group
  Graph failures produce warnings and do not stop the remaining report.

  The SDS extension key is supplied as a parameter for testability, but routine operators
  should use the service-defined value configured by the script.
 #>
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
   # A group can disappear or become inaccessible between the Exchange and Graph queries.
   # Keep that failure local so the remaining candidates are still evaluated.
   $GraphGroup = Get-MgGroup -GroupId $Candidate.ExternalDirectoryObjectId -ErrorAction Stop
   $EducationObjectType = if ($null -ne $GraphGroup.AdditionalProperties) {
    [string]$GraphGroup.AdditionalProperties[$SDSObjectTypeKey]
   }
   else {
    $null
   }

   # Section is the SDS service-defined marker for an education class group.
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
 <#
 .SYNOPSIS
  Validates the Microsoft Graph command availability, session, and group-read scope.

 .DESCRIPTION
  Accepts the least-privileged Group.Read.All scope or the broader Group.ReadWrite.All
  scope. This function never initiates sign-in or requests additional consent.
 #>
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
 <#
 .SYNOPSIS
  Validates the Exchange Online commands and active organization session.

 .DESCRIPTION
  Calls Get-OrganizationConfig as a lightweight connection check. It does not initiate
  sign-in and stops the workflow before the date-scoped group query if no session exists.
 #>
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

# Validate both sessions before issuing report queries. The script deliberately does not
# call Connect-* so the administrator controls the target tenant and account.
Test-GraphConnection
Test-ExchangeConnection

# Get-UnifiedGroup expects an Exchange filter string. Using an exclusive end boundary keeps
# all times on the administrator's selected end date while preserving server-side filtering.
$StartDateFilterValue = $StartDate.ToString('MM/dd/yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
$EndDateFilterValue = $EndDate.ToString('MM/dd/yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
$UnifiedGroupFilter = "WhenCreatedUTC -ge '$StartDateFilterValue' -and WhenCreatedUTC -lt '$EndDateFilterValue'"

Write-Host "Retrieving Microsoft 365 groups created from $($StartDate.ToString('yyyy-MM-dd')) through $($EndDate.AddDays(-1).ToString('yyyy-MM-dd')). Exchange does not report progress..." -ForegroundColor Yellow
$RetrievalTimer = [System.Diagnostics.Stopwatch]::StartNew()
$UNGroups = @(Get-UnifiedGroup -Filter $UnifiedGroupFilter -ResultSize unlimited)
$RetrievalTimer.Stop()
Write-Host "Retrieved $($UNGroups.Count) groups in the selected date range in $($RetrievalTimer.Elapsed.ToString('hh\:mm\:ss'))." -ForegroundColor Green

# Run the two independent classifications over the same date-scoped Exchange snapshot.
Invoke-SDSClassTeamWithoutSiteUrlReport -Group $UNGroups -StartDate $StartDate -EndDateExclusive $EndDate -OutputPath $NoSPOUNGResults
Invoke-SDSGroupNotTeamifiedReport -Group $UNGroups -SDSObjectTypeKey $SDSObjectTypeKey -OutputPath $SDSGroupNotTeamifiedResults
