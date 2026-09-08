# GetGroupsBrokenSPO.ps1

## Purpose

`GetGroupsBrokenSPO.ps1` investigates Microsoft 365 groups created within an operator-selected
date range. It combines Exchange Online group data with Microsoft Graph group and SharePoint site
data to help administrators investigate delayed or failed SharePoint provisioning for class Teams.

The script is diagnostic first. When it finds a class Team without an Exchange
`SharePointSiteUrl`, it immediately rechecks the group before considering a provisioning request.
This matters because SharePoint provisioning can complete asynchronously after the initial report
was generated.

## Prerequisites

Install these modules if they are not already available:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

Connect to the intended tenant before starting. The script validates existing sessions and never
opens a sign-in prompt itself.

```powershell
Connect-ExchangeOnline
Connect-MgGraph -Scopes 'Group.Read.All', 'Sites.Read.All'
```

For delegated access, the signed-in account also needs access to the returned group sites. App-only
Graph authentication is supported and is generally more reliable for tenant-wide site inspection;
the corresponding application permissions must be consented in Entra ID.

## Standard Run

Run the script from the repository folder:

```powershell
& '.\Single Script Tools\GetGroupsBrokenSPO.ps1'
```

Enter an inclusive start and end date in `yyyy-MM-dd` form. Start with the narrowest useful range:
each group in the range is compared against Graph, and each potential missing-site candidate is
rechecked through Exchange Online.

The script opens generated CSV files in the configured default application. The report remains
diagnostic unless it finds currently confirmed missing-site candidates and you answer `Y` to the
provisioning prompt.

## Provisioning Controls

`Get-MgGroupSite -SiteId root` can prompt the service to resume site provisioning. It is a
tenant-affecting request and is guarded carefully.

| Mode | Command | Behavior |
| --- | --- | --- |
| Diagnostic with preview | `& '.\Single Script Tools\GetGroupsBrokenSPO.ps1' -WhatIf` | Finds and revalidates candidates, then writes `WhatIf` trigger rows without sending a Graph provisioning request. |
| Interactive remediation | `& '.\Single Script Tools\GetGroupsBrokenSPO.ps1'` | Prompts once when revalidated candidates exist. Enter `Y` to request provisioning or `N` to skip it. |
| Per-group confirmation | `& '.\Single Script Tools\GetGroupsBrokenSPO.ps1' -Confirm` | Adds PowerShell confirmation for each individual request after the batch prompt. |
| Explicit unattended approval | `& '.\Single Script Tools\GetGroupsBrokenSPO.ps1' -UnattendedProvisioning` | Bypasses the batch `Y/N` prompt only. It still uses `-Confirm` if specified and still performs current Exchange revalidation. |

Use `-WhatIf` with the same date range before unattended provisioning. `-UnattendedProvisioning`
does not bypass the date prompts, connection checks, or revalidation. It should be used only after
an administrator has confirmed the target tenant and reviewed the candidate output.

## Reports

Reports use a timestamped name under `%TEMP%\EDU Scripts\TeamSiteTrigger\`.

| File | What it means |
| --- | --- |
| `NoSPOUNGResults...csv` | Point-in-time class-Team candidates where Exchange initially returned no site URL. This is not proof that a site is still missing later. |
| `SPOCandidateRefreshFailures...csv` | Candidate groups that could not be rechecked. They are deliberately excluded from provisioning requests. |
| `SPOSiteCreationResults...csv` | `WhatIf` or provisioning outcomes for revalidated candidates. It is created only when a preview or action is attempted. |
| `GroupSiteDivergence...csv` | Exchange and Graph group/site identifiers, timestamps, source-specific status, and errors for every group in the selected range. |
| `SDSGroupNotTeamified...csv` | SDS section groups that are not Team-enabled. |

### Trigger Results

Read the `Status` column in `SPOSiteCreationResults...csv` before treating a request as resolved.

| Status | Meaning |
| --- | --- |
| `Triggered` | Graph returned a non-empty site ID. The request was accepted, but the site can still need time to appear in Exchange. |
| `WhatIf` | Planned only; no Graph request was sent. |
| `Skipped` | The operator declined an individual confirmation. |
| `AccessDenied` | Graph did not authorize the request. Review Graph permissions and site access. |
| `Unverified` | Graph completed without returning a site ID. Treat as unresolved. |
| `Failed` | The request failed after the bounded retry handling. Review the `Error` column. |

### Divergence Results

The report keeps source timestamps separate:

- `UnifiedGroupCreatedDateTime` is the Exchange Online value.
- `GraphGroupCreatedDateTime` is the Microsoft Graph group value.
- `GroupRootSiteCreatedDateTime` comes from `Get-MgGroupSite -SiteId root`.
- `SiteByIdCreatedDateTime` comes from `Get-MgSite` for the returned site ID.
- `GroupCreationDivergence` and `SiteCreationDivergence` are absolute timestamp differences,
   rendered as seconds, minutes, hours, or days.
- `GroupToSiteProvisioningTime` is the signed elapsed time from Graph group creation to the
   group-root site creation time. A negative value should be investigated as a source-timestamp
   inconsistency.

`GraphGroupStatus`, `GroupSiteStatus`, and `GraphSiteStatus` show whether each lookup succeeded.
Use the corresponding error columns to distinguish an absent site from an access or service error.

## Configuration

The supported operator-controlled settings are:

| Setting | How to change it | Notes |
| --- | --- | --- |
| Search range | Answer the two date prompts | The end date is inclusive. This is the main scope control. |
| Batch approval | Answer the `Y/N` prompt | Choose `N` to leave the run diagnostic-only. |
| Preview / confirmation | Use `-WhatIf` or `-Confirm` | These are standard PowerShell common parameters. |
| Unattended approval | Use `-UnattendedProvisioning` | Use only with an authenticated, tenant-confirmed automation context. |
| Retry behavior | Change the final `Invoke-SPOSiteTriggerReport` call’s `-MaximumAttempts` and `-RetryDelaySeconds` values | Defaults are three attempts and five seconds. Keep retries bounded; do not add broad retries that mask authorization or permanent errors. |
| Output folder | Change `$folderPath` near the top of the script | The default `%TEMP%\EDU Scripts\TeamSiteTrigger\` avoids writing reports into the repository. Preserve timestamped filenames if reports are retained for audit. |

The SDS extension key, `Section` marker, and candidate criteria are intentionally service-specific.
Do not replace them with values from Teams-client-created classes. Changing the hidden-membership,
Team-enabled, or date criteria changes which groups can be reported or remediated and should be
validated in a test tenant first.

## Inline function map

The script now places a concise administrator comment before each function. The main groups are:

- **Input and time helpers:** validate the date range and normalize/compare source timestamps.
- **Divergence reporting:** gather Exchange group, Graph group, group-root site, and direct-site
  evidence without treating a failed source lookup as evidence that a site is absent.
- **Candidate revalidation:** separate initial missing-site observations from currently confirmed
  candidates and refresh failures.
- **Provisioning controls:** classify retryable errors, apply `ShouldProcess`, and export every
  trigger outcome.
- **Connection validation:** check existing Graph and Exchange sessions without initiating sign-in.

The comments above the final workflow identify the supported retry arguments and the server-side
Exchange date filter. Keep the filter date-bounded and keep remediation retries restricted to
transient failures.

## Troubleshooting

- **No CSV for a report:** Some reports are not created when they have no rows. Read the console
   summary first.
- **Initial missing-site row now has a site URL:** This is expected when asynchronous provisioning
   completed after the initial Exchange query. Only the successful recheck controls remediation.
- **`AccessDenied` or site lookup errors:** Confirm the Graph session targets the intended tenant,
   has the required permissions, and, for delegated authentication, has access to the site.
- **Large date ranges are slow:** Exchange filtering is server-side, but Graph lookups are
   performed per group. Run smaller ranges or split the investigation by date.

## Safe Test Procedure

1. Authenticate to a test tenant and confirm the tenant before entering the date range.
2. Run `& '.\Single Script Tools\GetGroupsBrokenSPO.ps1' -WhatIf` for one known test group or a narrow date range.
3. Review all candidate, refresh-failure, and trigger-result rows.
4. Run without `-WhatIf`, answer `Y`, and use `-Confirm` for the first live test.
5. Re-run the diagnostic later to confirm that Graph and Exchange both show a site URL and ID.
