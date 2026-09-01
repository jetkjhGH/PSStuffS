# CheckSPOProv.ps1

## Purpose

`CheckSPOProv.ps1` is the earlier, non-interactive version of the SDS provisioning report.
It:

1. Retrieves every Microsoft 365 group through Exchange Online.
2. Reports Team-enabled, hidden-membership groups created during a hard-coded date range
   that do not have a SharePoint site URL.
3. Uses Microsoft Graph to inspect every non-Team group and reports those marked as an
   education `Section`.

For interactive date selection and a server-side Exchange date filter, prefer
[`CheckforSDSProvFails.ps1`](CheckforSDSProvFails.md).

## Requirements

- Exchange Online PowerShell module
- Microsoft Graph PowerShell SDK
- An existing Exchange Online connection
- An existing Microsoft Graph connection
- Permission to read all Microsoft 365 groups in Exchange Online
- Graph `Group.Read.All` or `Group.ReadWrite.All`

Install the modules if needed:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Microsoft.Graph -Scope CurrentUser
```

## Connect

```powershell
Connect-ExchangeOnline
Connect-MgGraph -Scopes 'Group.Read.All'
```

The script explicitly validates Microsoft Graph. Its use of `Get-UnifiedGroup` also requires
an active Exchange Online session, although this older script does not validate that session
before beginning.

## Configure the date range

Edit the exclusive date range near the beginning of the script:

```powershell
$StartDate = [datetime]'2026-01-01'
$EndDate = [datetime]'2027-01-01'
```

The start is inclusive and the end is exclusive. The example above covers all of 2026.

## Run the script

```powershell
Set-Location C:\PSSTuffS
.\CheckSPOProv.ps1
```

## Output

The script writes dated CSV files directly to the current user's temporary directory:

```text
%TEMP%\NoSPOUNGResultsMM-dd-yy.csv
%TEMP%\SDSGroupNotTeamifiedMM-dd-yy.csv
```

It opens the SharePoint-site report automatically. It opens the non-teamified SDS report
only when matches exist.

## Performance considerations

This version runs:

```powershell
Get-UnifiedGroup -ResultSize unlimited
```

It retrieves the entire tenant's Microsoft 365 group inventory before filtering locally.
It then sends one Graph request for every non-Team group. In a large tenant this can take a
long time and may be throttled.

Prefer [`CheckforSDSProvFails.ps1`](CheckforSDSProvFails.md), which filters the Exchange query
to a user-selected date range.

## Sign out

```powershell
Disconnect-ExchangeOnline -Confirm:$false
Disconnect-MgGraph
```
