# Remove-Targeted_Section_Memberships.ps1

## Purpose

`Remove-Targeted_Section_Memberships.ps1` removes every non-owner user member from each Microsoft
365 group listed in an input CSV. Owners are preserved even though Graph also returns them in the
member collection.

This is a tenant-changing legacy utility. It has no `-WhatIf` support and no per-member
confirmation. Test with one non-production class and review the input carefully before a broad run.

## Requirements and connection

- Microsoft Graph PowerShell SDK
- Delegated `Group.ReadWrite.All`
- Permission to update membership for every targeted group

Unlike most scripts in this repository, this utility calls `Connect-MgGraph` itself:

```powershell
Connect-MgGraph -Scopes 'Group.ReadWrite.All' -NoWelcome
```

Confirm the account and tenant shown during authentication. The script disconnects Graph after the
run.

## Input CSV

The CSV must contain:

| Column | Required | Purpose |
| --- | --- | --- |
| `GraphId` | Yes | Microsoft 365 group object ID to process |
| `Name` | No | Friendly label for progress and output; `GraphId` is used when omitted |

Example:

```csv
GraphId,Name
11111111-1111-1111-1111-111111111111,Algebra Section 1
22222222-2222-2222-2222-222222222222,Biology Section 2
```

Remove blank IDs, duplicates, and any group that should not have its non-owner membership cleared.
The script validates the column and blank values but does not verify the target list with the
operator before removal.

## Run

```powershell
Set-Location C:\PSSTuffS
& '.\Single Script Tools\Remove-Targeted_Section_Memberships.ps1' -Path 'C:\Temp\SectionUsage.csv'
```

For the first test, supply a CSV containing one non-production group and verify its owner/member
state in the admin center before and after the run.

## Processing behavior

For each group, the script:

1. Retrieves all user owners.
2. Retrieves all user members.
3. Excludes every member whose ID is also an owner ID.
4. Removes each remaining member.
5. Records successful removal calls.

A group-level Graph failure produces a warning and processing continues with later groups. The
warning currently does not include the full Graph exception, so retain the console output when
troubleshooting.

## Output and adjustments

Successful removals are written to:

```text
.\RemovedStudents.csv
```

The path is relative to the current working directory. Change `$outFile` in the clearly marked
administrator adjustment if the audit needs a controlled retention location.

The CSV contains `GroupId`, `GroupName`, `MemberId`, and `MemberName`. It records only successful
removal calls; it is not a record of owners, skipped owner-members, or group-level failures.

Do not weaken the owner-ID exclusion when adapting this script. If preview or approval controls
are needed, add `SupportsShouldProcess` before using the utility for broader operational work.
