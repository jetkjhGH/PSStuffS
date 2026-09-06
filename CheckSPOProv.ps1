$folderPath = Join-Path (Join-Path $env:TEMP 'EDU Scripts') 'CheckSPOProv'
$NoSPOUNGResults = Join-Path $folderPath "NoSPOUNGResults$(get-date -f MM-dd-yy).csv"
$SDSGroupNotTeamifiedResults = Join-Path $folderPath "SDSGroupNotTeamified$(get-date -f MM-dd-yy).csv"
$SDSObjectTypeKey = 'extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType'
$StartDate = [datetime]'2026-01-01'
$EndDate = [datetime]'2027-01-01'

if (-not (Test-Path -Path $folderPath)) {
	New-Item -ItemType Directory -Path $folderPath | Out-Null
}

Write-Host 'Retrieving all Microsoft 365 groups. This can take several minutes and Exchange does not report progress...' -ForegroundColor Yellow
$RetrievalTimer = [System.Diagnostics.Stopwatch]::StartNew()
$UNGroups = @(Get-UnifiedGroup -ResultSize unlimited)
$RetrievalTimer.Stop()
Write-Host "Retrieved $($UNGroups.Count) groups in $($RetrievalTimer.Elapsed.ToString('hh\:mm\:ss'))." -ForegroundColor Green

#Find SDS Class Teams with no SiteURL
$NoSPOUNGs = $UNGroups | Where-Object {
	[string]::IsNullOrWhiteSpace($_.SharePointSiteUrl) -and
	$_.WhenCreatedUTC -ge $StartDate -and
	$_.WhenCreatedUTC -lt $EndDate -and
	$_.HiddenGroupMembershipEnabled -eq $true -and
	$_.ResourceProvisioningOptions -contains 'Team'
}
$NoSPOUNGs | Select-Object ExternalDirectoryObjectId, WhenCreated, DisplayName, Alias, SharePointSiteUrl, SharePointDocumentsUrl, SharePointNotebookUrl | Export-Csv -Path $NoSPOUNGResults -NoTypeInformation
Invoke-Item $NoSPOUNGResults


##Find SDS created groups not Teamified
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
		$GraphGroup = Get-MgGroup -GroupId $Group.ExternalDirectoryObjectId -ErrorAction Stop
		$EducationObjectType = if ($null -ne $GraphGroup.AdditionalProperties) {
			[string]$GraphGroup.AdditionalProperties[$SDSObjectTypeKey]
		}
		else {
			$null
		}

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