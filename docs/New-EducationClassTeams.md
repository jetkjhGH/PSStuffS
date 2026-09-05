# New-EducationClassTeams.ps1

## Purpose

`New-EducationClassTeams.ps1` interactively creates one or more Microsoft Teams based on
the Microsoft Graph `educationClass` template.

It supports two creation methods:

- **Non-Activated:** Creates all Microsoft 365 Unified groups first, marks them as education
  sections, waits at least 30 seconds for replication, and then teamifies each group with
  retries. These classes follow the SDS-style pending activation behavior.
- **Activated:** Creates each Team directly from the `educationClass` template and assigns
  the selected user as an owner.

The script also:

- Accepts an owner by user principal name, email address, or Entra object ID.
- Offers predefined naming patterns and a custom tokenized pattern.
- Generates unique mail nicknames for non-activated groups.
- Checks proposed display names against existing Microsoft 365 groups.
- Supports batches of up to 500 Teams.
- Supports `-WhatIf` and PowerShell confirmation behavior.
- Reports `Created`, `CreatedOwnerPending`, `GroupOnly`, `Failed`, or `WhatIf` for every requested Team.

## Requirements

- Microsoft Graph PowerShell SDK
- An existing delegated Microsoft Graph connection
- The following delegated scopes:
  - `Group.ReadWrite.All`
  - `Team.Create`
  - `TeamMember.ReadWrite.All`
  - `User.Read.All`
- An account permitted to create Microsoft 365 groups and Teams

Install the SDK if needed:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

## Connect to Microsoft Graph

The script validates an existing connection but intentionally does not connect for you.

```powershell
Connect-MgGraph -Scopes @(
    'Group.ReadWrite.All'
    'Team.Create'
    'TeamMember.ReadWrite.All'
    'User.Read.All'
)
```

Confirm the active context:

```powershell
Get-MgContext
```

Your tenant may require an administrator to grant consent for these scopes.

## Run the script

Open PowerShell in the repository folder:

```powershell
Set-Location C:\PSSTuffS
.\New-EducationClassTeams.ps1
```

The script prompts for:

1. Activated or non-activated creation.
2. Team owner.
3. Naming convention.
4. Values required by the selected naming tokens.
5. Number of Teams and starting index.
6. Class description.
7. Final confirmation after name-conflict checks.

### Preview without creating anything

```powershell
.\New-EducationClassTeams.ps1 -WhatIf
```

`-WhatIf` still asks the interactive questions and displays the planned operations, but it
does not create groups or Teams.

### Request confirmation for each operation

```powershell
.\New-EducationClassTeams.ps1 -Confirm
```

## Naming tokens

Custom patterns can use:

| Token | Value |
| --- | --- |
| `{Subject}` | Subject or course name |
| `{Period}` | Class period |
| `{SchoolYear}` | School year |
| `{Teacher}` | Teacher name |
| `{Index}` | Per-Team sequence number |

If a multi-Team pattern omits `{Index}`, the script appends it automatically.

Example custom pattern:

```text
{SchoolYear} - {Subject} - Period {Period} - Section {Index}
```

## Non-activated creation and retries

The non-activated path is intentionally divided into two phases:

1. Create every Unified group.
2. Wait 30 seconds, then teamify each successful group.

The Teams templates service may temporarily return `404 NotFound` while a new group
replicates. Teamification retries transient failures with increasing delays. Authorization
and validation failures are not retried.

The minimum batch delay is configured near the beginning of the script:

```powershell
$script:GroupSettleSeconds = 30
```

Increase this value if large batches regularly need several teamification retries.

## Results

The script returns one object per requested Team:

| Property | Meaning |
| --- | --- |
| `DisplayName` | Generated Team name |
| `Method` | `Activated` or `NonActivated` |
| `MailNickname` | Alias generated for a non-activated group |
| `GroupId` | Created Microsoft 365 group ID |
| `TeamId` | Team ID; normally the same as the group ID |
| `NameConflict` | Whether the display name existed before creation |
| `Status` | `Created`, `CreatedOwnerPending`, `GroupOnly`, `Failed`, or `WhatIf` |
| `Error` | Failure details, when applicable |

`CreatedOwnerPending` means the Team exists, but assigning the selected owner did not
complete after bounded retries. Do not recreate the Team; use its reported `TeamId` when
resolving the owner assignment.

`GroupOnly` means the Unified group exists, but all teamification retries failed. Do not
recreate that group; use its reported `GroupId` when retrying teamification.

## Sign out

```powershell
Disconnect-MgGraph
```
