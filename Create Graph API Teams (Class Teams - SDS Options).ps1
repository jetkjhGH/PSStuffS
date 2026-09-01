#Graph Create Class - Non Activated
$OwnerOID = 'b2a5115e-61f0-4eea-88ec-10c5334ad60d'
$DisplayName = "Kyle Graph Class Test 2026 - 8-28-1"
$ClassDescrip = "Graph PS - Created by Kyle H"
#Must be unique
$MailAlias = "KyleGraphClassTest20268281"

#Graph URI for Groups 
$uri = @'
https://graph.microsoft.com/v1.0/groups/
'@

#Set the properties for the 365 Group. Display Name, Description, and MailNickname(alias) are required. The Class Team will be non-activated as the education extension is present
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

#Create the 365 Group using the data supplied above using the New-MgGroup API
$GraphClass = Invoke-MgGraphRequest -uri $uri -Body $Body -Method POST -ContentType "application/json"
 
#Pull the GroupID for use in Teamification
$GID = $GraphClass.id

$GID

Sleep 10

##Create team from group
$params = @{
	"template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('educationClass')"
	"group@odata.bind" = "https://graph.microsoft.com/v1.0/groups('$GID')"
}

New-MgTeam -BodyParameter $params

Get-MgTeam -TeamId $gid

#Graph Create Class - Activated
#The parameters of the Team being created, there are more options than the detailed information above for more examples and the cmdlet documentation for the full list
$params = @{ 
	"template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('educationClass')" 
	displayName = "Kyle Graph Class Test - Activated| RBO | 1-23-26" 
	description = "Created via Graph PowerShell" 
} 

New-MgTeam -BodyParameter $params