<#
.SYNOPSIS
	Legacy examples for creating activated and non-activated educationClass Teams.

.DESCRIPTION
	Demonstrates two independent Graph creation patterns in one file:

	1. Create a Unified group with the SDS education Section extension, assign one owner and
	   member, wait briefly, and teamify it with the educationClass template.
	2. Create a separate activated educationClass Team directly from the template.

	Running this file executes both examples and changes the connected tenant. It has no
	-WhatIf support, no conflict checks, and no teamification retries. Use
	New-EducationClassTeams.ps1 for maintained operational use.

.NOTES
	Connect to Microsoft Graph before running. Review every value in the Administrator
	adjustments sections and use only test-tenant identifiers.
#>

#region Administrator adjustments - non-activated example

# Replace every value in this section before running. OwnerOID must be an existing user
# object ID in the connected tenant. DisplayName and MailAlias should be unique.
$OwnerOID = 'b2a5115e-61f0-4eea-88ec-10c5334ad60d'
$DisplayName = "Kyle Graph Class Test 2026 - 8-28-1"
$ClassDescrip = "Graph PS - Created by Kyle H"
$MailAlias = "KyleGraphClassTest20268281"

# Increase this delay if the Teams template service cannot see the group yet. This legacy
# example does not retry; the maintained script uses a two-phase batch and bounded retries.
$GroupReplicationDelaySeconds = 10

#endregion Administrator adjustments - non-activated example

# Stable Microsoft Graph v1.0 endpoint for Unified group creation.
$uri = 'https://graph.microsoft.com/v1.0/groups/'

# The education extension, creationOptions, and resourceBehaviorOptions below are
# service-defined SDS provisioning values. Do not replace them with tenant-specific IDs or
# values observed on Teams-client-created classes unless changing the provisioning model is
# the explicit goal.
$Body = @"
{
  "displayName": "$DisplayName",
  "description": "$ClassDescrip",
  "groupTypes": ["Unified"],
  "mailEnabled": true,
  "mailNickname": "$MailAlias",
  "securityEnabled": false,
  "members@odata.bind": [
    "https://graph.microsoft.com/v1.0/users/$OwnerOID"
  ],
  "owners@odata.bind": [
    "https://graph.microsoft.com/v1.0/users/$OwnerOID"
  ],
  "visibility": "HiddenMembership",
  "creationOptions": [
    "ExchangeProvisioningFlags:4556"
  ],
  "extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType": "Section",
  "resourceBehaviorOptions": [
    "appRoleForSite:22d27567-b3f0-4dc2-9ec2-46ed368ba538:fullcontrol",
    "appRoleForSite:c9a559d2-7aab-4f13-a6ed-e7e9c52aec87:fullcontrol",
    "appRoleForSite:13291f5a-59ac-4c59-b0fa-d1632e8f3292:fullcontrol",
    "appRoleForSite:2d4d3d8e-2be3-4bef-9f87-7875a61c29de:fullcontrol",
    "appRoleForSite:8f348934-64be-4bb2-bc16-c54c96789f43:fullcontrol",
    "InstantOnDisabled",
    "FileNotificationsDisabled",
	"ProvisionSiteOnDemand",
    "WelcomeEmailDisabled",
    "ConnectorsDisabled",
    "SubscribeNewGroupMembers"
  ]
}
"@

# Create the backing Unified group. Invoke-MgGraphRequest is used because the education
# extension is supplied directly in the JSON payload.
$GraphClass = Invoke-MgGraphRequest -uri $uri -Body $Body -Method POST -ContentType "application/json"

# The new group and its Team share the same object ID after teamification.
$GID = $GraphClass.id

$GID

# Group visibility in Graph does not guarantee visibility in the Teams template service.
Start-Sleep -Seconds $GroupReplicationDelaySeconds

# Teamify the existing group with the educationClass template. A transient 404 here usually
# means replication is incomplete; this legacy example requires a manual retry.
$params = @{
	"template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('educationClass')"
	"group@odata.bind" = "https://graph.microsoft.com/v1.0/groups('$GID')"
}

New-MgTeam -BodyParameter $params

Get-MgTeam -TeamId $gid

#region Administrator adjustments - activated example

# This is a second, independent Team. Change both fields before running. Direct creation
# activates the class immediately, but this legacy example does not explicitly assign the
# OwnerOID above to the activated Team.
$params = @{ 
	"template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('educationClass')" 
	displayName = "Kyle Graph Class Test - Activated| RBO | 1-23-26" 
	description = "Created via Graph PowerShell" 
} 

#endregion Administrator adjustments - activated example

New-MgTeam -BodyParameter $params