<#
.SYNOPSIS
	Reports legacy SDS class provisioning conditions from Exchange Online and Microsoft Graph.

.DESCRIPTION
	Retrieves every Microsoft 365 group through Exchange Online, then produces:

	1. A CSV of Team-enabled, hidden-membership groups in the configured date range that
	   do not have a SharePoint site URL.
	2. A CSV of groups that are not Team-enabled but carry the SDS education Section
	   extension in Microsoft Graph.

	This is the legacy, tenant-wide diagnostic. Prefer CheckforSDSProvFails.ps1 for normal
	operations because it prompts for a date range and applies that range to the Exchange
	query instead of retrieving every group in the tenant.

	The script is read-only against Microsoft 365. It assumes the administrator has already
	connected to Exchange Online and Microsoft Graph.

.NOTES
	Required modules:
	- ExchangeOnlineManagement
	- Microsoft.Graph.Authentication
	- Microsoft.Graph.Groups

	Connect before running:
		Connect-ExchangeOnline
		Connect-MgGraph -Scopes 'Group.Read.All'

	Adjust only the report folder and date range in the Administrator-adjustable settings
	section for routine use. The SDS extension key and Section value are service-defined
	constants and should not be changed.
#>

#region Administrator-adjustable settings

# Change this folder if reports must be retained somewhere other than the user's TEMP
# directory. Keep the two file names distinct because they contain different CSV schemas.
$folderPath = Join-Path (Join-Path $env:TEMP 'EDU Scripts') 'CheckSPOProv'
$NoSPOUNGResults = Join-Path $folderPath "NoSPOUNGResults$(get-date -f MM-dd-yy).csv"
$SDSGroupNotTeamifiedResults = Join-Path $folderPath "SDSGroupNotTeamified$(get-date -f MM-dd-yy).csv"

# The start is inclusive and the end is exclusive. This example covers calendar year 2026.
# Keep the window as narrow as possible when using this legacy tenant-wide report.
$StartDate = [datetime]'2026-01-01'
$EndDate = [datetime]'2027-01-01'

#endregion Administrator-adjustable settings

# This extension name is defined by the SDS service. Do not substitute a tenant-specific
# extension or a value observed on a Teams-client-created group.
$SDSObjectTypeKey = 'extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType'

# Create the output folder before either report attempts to export a CSV.
if (-not (Test-Path -Path $folderPath)) {
	New-Item -ItemType Directory -Path $folderPath | Out-Null
}

# This legacy query intentionally retrieves the full tenant inventory. In large tenants it
# can take several minutes and should not be expanded with additional per-group work.
Write-Host 'Retrieving all Microsoft 365 groups. This can take several minutes and Exchange does not report progress...' -ForegroundColor Yellow
$RetrievalTimer = [System.Diagnostics.Stopwatch]::StartNew()
$UNGroups = @(Get-UnifiedGroup -ResultSize unlimited)
$RetrievalTimer.Stop()
Write-Host "Retrieved $($UNGroups.Count) groups in $($RetrievalTimer.Elapsed.ToString('hh\:mm\:ss'))." -ForegroundColor Green

# Missing-site candidates must already be Teams, use hidden membership, fall within the
# configured window, and have no SharePoint URL. These conditions reduce false positives
# from ordinary Microsoft 365 groups that do not provision a site on the same schedule.
$NoSPOUNGs = $UNGroups | Where-Object {
	[string]::IsNullOrWhiteSpace($_.SharePointSiteUrl) -and
	$_.WhenCreatedUTC -ge $StartDate -and
	$_.WhenCreatedUTC -lt $EndDate -and
	$_.HiddenGroupMembershipEnabled -eq $true -and
	$_.ResourceProvisioningOptions -contains 'Team'
}
$NoSPOUNGs | Select-Object ExternalDirectoryObjectId, WhenCreated, DisplayName, Alias, SharePointSiteUrl, SharePointDocumentsUrl, SharePointNotebookUrl | Export-Csv -Path $NoSPOUNGResults -NoTypeInformation
Invoke-Item $NoSPOUNGResults


# The second report uses Graph because Exchange does not expose the SDS education extension.
# It starts with non-Team groups to avoid a Graph request for every group in the tenant.
$MissingGraphCommands = @(@('Get-MgContext', 'Get-MgGroup') | Where-Object {
	-not (Get-Command $_ -ErrorAction SilentlyContinue)
})
if ($MissingGraphCommands.Count -gt 0) {
	throw "Required Graph command(s) unavailable: $($MissingGraphCommands -join ', '). Install/import Microsoft.Graph and connect with Connect-MgGraph."
}

$GraphContext = Get-MgContext -ErrorAction Stop
if ($null -eq $GraphContext -or [string]::IsNullOrWhiteSpace($GraphContext.Account)) {
	throw 'Microsoft Graph is not connected. Run Connect-MgGraph before creating the SDS report.'
}

$NonTeamGroups = @($UNGroups | Where-Object {
	$_.ResourceProvisioningOptions -notcontains 'Team'
})
$SDSGroupNotTeamified = [System.Collections.Generic.List[object]]::new()

Write-Host "Checking $($NonTeamGroups.Count) non-Team groups for the SDS Section extension..." -ForegroundColor Yellow
foreach ($Group in $NonTeamGroups) {
	try {
		# Per-group failures are recoverable: warn and continue so one inaccessible or
		# concurrently deleted group does not discard the remainder of the report.
		$GraphGroup = Get-MgGroup -GroupId $Group.ExternalDirectoryObjectId -ErrorAction Stop
		$EducationObjectType = if ($null -ne $GraphGroup.AdditionalProperties) {
			[string]$GraphGroup.AdditionalProperties[$SDSObjectTypeKey]
		}
		else {
			$null
		}

		# Section is the SDS service-defined marker for an education class group.
		if ($EducationObjectType -eq 'Section') {
			$SDSGroupNotTeamified.Add([pscustomobject]@{
				ExternalDirectoryObjectId = $Group.ExternalDirectoryObjectId
				WhenCreated              = $Group.WhenCreated
				DisplayName              = $Group.DisplayName
				Alias                    = $Group.Alias
				EducationObjectType      = $EducationObjectType
				ResourceProvisioningOptions = ($Group.ResourceProvisioningOptions -join ';')
			})
		}
	}
	catch {
		Write-Warning "Unable to inspect group $($Group.ExternalDirectoryObjectId): $($_.Exception.Message)"
	}
}

if ($SDSGroupNotTeamified.Count -gt 0) {
	$SDSGroupNotTeamified | Export-Csv -Path $SDSGroupNotTeamifiedResults -NoTypeInformation
	Write-Host "Found $($SDSGroupNotTeamified.Count) SDS Section groups that are not Team-enabled." -ForegroundColor Green
	Invoke-Item $SDSGroupNotTeamifiedResults
}
else {
	Write-Host 'No SDS Section groups without Team provisioning were found.' -ForegroundColor Green
}