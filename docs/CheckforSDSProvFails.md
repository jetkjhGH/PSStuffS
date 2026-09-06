# CheckforSDSProvFails.ps1

## Purpose

`CheckforSDSProvFails.ps1` creates two diagnostic reports for SDS-provisioned classes:

1. **Class Teams without a SharePoint site URL**
   - Hidden-membership Microsoft 365 groups
   - Team-enabled
   - Created within the interactively selected date range
   - Missing `SharePointSiteUrl`
2. **SDS section groups that are not Team-enabled**
   - Microsoft 365 groups without the `Team` resource provisioning option
   - Carrying the education extension value `ObjectType = Section`

The script prompts for an inclusive start and end date in `yyyy-MM-dd` format.

## Requirements

- Exchange Online PowerShell module
- Microsoft Graph PowerShell SDK
- An existing Exchange Online connection
- An existing delegated Microsoft Graph connection
- Permission to read Microsoft 365 groups in Exchange Online
- One of these Graph delegated scopes:
  - `Group.Read.All`
  - `Group.ReadWrite.All`

Install the modules if needed:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Microsoft.Graph -Scope CurrentUser
```

## Connect

Connect to both services before running the script:

```powershell
Connect-ExchangeOnline
Connect-MgGraph -Scopes 'Group.Read.All'
```

The script validates both connections and stops with guidance if either is unavailable.

Verify them manually if needed:

```powershell
Get-OrganizationConfig | Select-Object OrganizationId
Get-MgContext
```

## Run the script

```powershell
Set-Location C:\PSSTuffS
.\CheckforSDSProvFails.ps1
```

Example date entry:

```text
Enter the search start date (yyyy-MM-dd): 2026-08-01
Enter the search end date (yyyy-MM-dd, inclusive): 2026-08-31
```

The Exchange query is restricted to the selected date range. The end date is inclusive.

## Output

Reports are written to:

```text
%TEMP%\EDU Scripts\TeamSiteTrigger\
```

Possible files:

```text
NoSPOUNGResultsMM-dd-yy_HH-mm-ss.csv
SDSGroupNotTeamifiedMM-dd-yy_HH-mm-ss.csv
```

The script opens each CSV automatically when it contains results. It does not create an
empty report when no matching groups are found.

### SharePoint provisioning report columns

- `ExternalDirectoryObjectId`
- `WhenCreated`
- `DisplayName`
- `Alias`
- `SharePointSiteUrl`
- `SharePointDocumentsUrl`
- `SharePointNotebookUrl`

### Non-teamified SDS group report columns

- `ExternalDirectoryObjectId`
- `WhenCreated`
- `DisplayName`
- `Alias`
- `EducationObjectType`
- `ResourceProvisioningOptions`

## Performance considerations

Exchange retrieves the groups in the selected date range first. The script then calls
Microsoft Graph once for each non-Team group to inspect the education extension. Large date
ranges can therefore take several minutes and may produce many Graph requests.

Start with the narrowest useful date range.

## Sign out

```powershell
Disconnect-ExchangeOnline -Confirm:$false
Disconnect-MgGraph
```
