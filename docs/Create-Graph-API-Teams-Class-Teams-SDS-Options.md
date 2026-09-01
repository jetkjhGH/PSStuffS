# Create Graph API Teams (Class Teams - SDS Options).ps1

## Purpose

This is a legacy example script demonstrating two Microsoft Graph class-Team creation
methods:

1. Create a non-activated SDS-style Unified group with the education `Section` extension,
   wait 10 seconds, and teamify it with the `educationClass` template.
2. Create a separate activated Team directly from the `educationClass` template.

**Important:** Running the script executes both examples. It contains hard-coded tenant
values and is intended as a reference or controlled test script. For interactive batch
creation, use [`New-EducationClassTeams.ps1`](New-EducationClassTeams.md).

## Requirements

- Microsoft Graph PowerShell SDK
- A Microsoft Graph connection with permissions to:
  - Create and update Microsoft 365 groups
  - Create Teams
  - Read Teams for the final `Get-MgTeam` call
- A valid owner object ID from the connected tenant

Install the SDK if needed:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

## Connect to Microsoft Graph

A typical delegated connection is:

```powershell
Connect-MgGraph -Scopes @(
    'Group.ReadWrite.All'
    'Team.Create'
    'Team.ReadBasic.All'
)
```

Required consent can vary with tenant policy and Microsoft Graph SDK behavior.

## Configure before running

Edit these values at the top of the script:

```powershell
$OwnerOID = 'OWNER-OBJECT-ID'
$DisplayName = 'Unique non-activated class name'
$ClassDescrip = 'Class description'
$MailAlias = 'UniqueMailAlias'
```

Also edit the activated example near the bottom:

```powershell
displayName = 'Unique activated class name'
description = 'Class description'
```

The owner ID can be found with:

```powershell
Get-MgUser -UserId teacher@contoso.com |
    Select-Object Id, DisplayName, UserPrincipalName
```

The mail alias must be unique and should contain only characters accepted by Exchange.

## Run the script

```powershell
Set-Location C:\PSSTuffS
& '.\Create Graph API Teams (Class Teams - SDS Options).ps1'
```

The call operator (`&`) is useful because the file name contains spaces and parentheses.

## Limitations

- Both examples run every time.
- There is no interactive confirmation or `-WhatIf` support.
- Values are hard-coded.
- The fixed 10-second wait may not be long enough for group replication.
- The teamification call does not retry transient failures.
- The activated example does not explicitly assign the configured owner.

Use [`New-EducationClassTeams.ps1`](New-EducationClassTeams.md) for safer operational use.

## Sign out

```powershell
Disconnect-MgGraph
```
