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
.\GetGroupsBrokenSPO.ps1
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
| Diagnostic with preview | `.\GetGroupsBrokenSPO.ps1 -WhatIf` | Finds and revalidates candidates, then writes `WhatIf` trigger rows without sending a Graph provisioning request. |
| Interactive remediation | `.\GetGroupsBrokenSPO.ps1` | Prompts once when revalidated candidates exist. Enter `Y` to request provisioning or `N` to skip it. |
| Per-group confirmation | `.\GetGroupsBrokenSPO.ps1 -Confirm` | Adds PowerShell confirmation for each individual request after the batch prompt. |
| Explicit unattended approval | `.\GetGroupsBrokenSPO.ps1 -UnattendedProvisioning` | Bypasses the batch `Y/N` prompt only. It still uses `-Confirm` if specified and still performs current Exchange revalidation. |

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
2. Run `.\GetGroupsBrokenSPO.ps1 -WhatIf` for one known test group or a narrow date range.
3. Review all candidate, refresh-failure, and trigger-result rows.
4. Run without `-WhatIf`, answer `Y`, and use `-Confirm` for the first live test.
5. Re-run the diagnostic later to confirm that Graph and Exchange both show a site URL and ID.
# GetGroupsBrokenSPO.ps1

## Purpose

`GetGroupsBrokenSPO.ps1` is a date-scoped diagnostic for Microsoft 365 groups. It writes:

1. An initial point-in-time report of SDS class Teams whose Exchange group data has no
   `SharePointSiteUrl`.
2. A report of candidates that could not be revalidated through Exchange before any
   remediation.
3. A group and SharePoint site divergence report using Microsoft Graph.
4. A report of SDS `Section` groups that are not Team-enabled.

When current Exchange revalidation finds groups still missing a site URL, the script prompts
before requesting SharePoint provisioning. It does not send a request unless the operator
answers `Y`.

## Requirements

- ExchangeOnlineManagement module and an existing Exchange Online connection.
- Microsoft Graph PowerShell SDK and an existing Graph connection.
- Read access to Microsoft 365 groups in Exchange Online.
- For delegated Graph authentication, one of `Group.Read.All`, `Group.ReadWrite.All`,
  `Directory.Read.All`, or `Directory.ReadWrite.All`, plus `Sites.Read.All` or
  `Sites.ReadWrite.All`.
- For app-only Graph authentication, equivalent application permissions approved in Entra.

Connect before running the script:

```powershell
Connect-ExchangeOnline
Connect-MgGraph -Scopes 'Group.Read.All', 'Sites.Read.All'
```

The script validates existing sessions and does not sign in automatically.

## Run

Run diagnostics for an inclusive date range:

```powershell
.\GetGroupsBrokenSPO.ps1
```

Enter dates as `yyyy-MM-dd` when prompted. The script restricts its Exchange query to that
range.

Preview the actions that would be requested for currently revalidated missing-site candidates:

```powershell
.\GetGroupsBrokenSPO.ps1 -WhatIf
```

To request provisioning, run the standard command after reviewing the diagnostic output and
confirming the tenant and range:

```powershell
.\GetGroupsBrokenSPO.ps1
```

When the script identifies currently confirmed candidates, enter `Y` at the provisioning prompt.
Enter `N` to skip provisioning. Add `-Confirm` to receive an additional prompt for every group.
`-WhatIf` does not send Graph requests or prompt, but writes planned-action rows to the trigger
report.

For an attended session where the batch approval prompt is not appropriate, explicitly bypass it:

```powershell
.\GetGroupsBrokenSPO.ps1 -UnattendedProvisioning
```

`-UnattendedProvisioning` bypasses only the site-provisioning approval prompt after a successful
recheck. It does not bypass the date-range prompts or `-Confirm` prompts. Use `-WhatIf` first to
review the actions that this mode would request.

## Revalidation And Results

An empty `SharePointSiteUrl` in the initial CSV is an observation at the time the date-scoped
query ran. SharePoint can provision a site asynchronously after that observation.

Before a provisioning request, the script obtains each candidate again through
`Get-UnifiedGroup`. Only a successful recheck that still has an empty `SharePointSiteUrl` is
eligible for triggering. Recheck failures are exported separately and are never triggered.

The trigger report uses these statuses:

- `Triggered`: Graph returned a non-empty site ID.
- `WhatIf`: the request was planned but not sent.
- `Skipped`: the operator declined the confirmation prompt.
- `AccessDenied`: Graph did not authorize the request.
- `Unverified`: Graph returned without a site ID.
- `Failed`: the request did not complete successfully.

## Output

Reports are written under `%TEMP%\TeamSiteTrigger\` using a run timestamp:

- `NoSPOUNGResults...csv`: initial missing-site candidates.
- `SPOCandidateRefreshFailures...csv`: candidates that Exchange could not revalidate.
- `SPOSiteCreationResults...csv`: planned or requested provisioning actions, produced only when
   confirmed candidates exist and the operator approves provisioning, or when `-WhatIf` is used.
- `GroupSiteDivergence...csv`: Exchange and Graph group/site comparisons. The site creation
   columns identify their Graph route: `GroupRootSiteCreatedDateTime` comes from
   `Get-MgGroupSite -SiteId root`, while `SiteByIdCreatedDateTime` comes from `Get-MgSite` using
   the returned site ID. `GroupCreationDivergence` and `SiteCreationDivergence` are absolute
   timestamp differences formatted in seconds, minutes, hours, or days. `GroupToSiteProvisioningTime`
   is the signed elapsed time from `GraphGroupCreatedDateTime` to
   `GroupRootSiteCreatedDateTime`, using the same adaptive unit.
- `SDSGroupNotTeamified...csv`: SDS `Section` groups without Team provisioning.

The existing diagnostic CSV column layouts are preserved. The refresh-failure CSV is additive.
