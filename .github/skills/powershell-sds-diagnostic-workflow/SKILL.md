---
name: powershell-sds-diagnostic-workflow
description: 'Run, troubleshoot, or modify PowerShell SDS provisioning diagnostics for missing SharePoint sites and non-teamified education section groups. Use when investigating School Data Sync provisioning failures, CheckforSDSProvFails, CheckSPOProv, Microsoft Graph group reporting, or Exchange Online group reports.'
argument-hint: 'Describe the SDS provisioning symptom or reporting change'
---

# PowerShell SDS Diagnostic Workflow

Use this workflow to investigate suspected SDS class provisioning failures without changing tenant state.

## Choose the Diagnostic

1. Default to [CheckforSDSProvFails.ps1](../../../CheckforSDSProvFails.ps1). It interactively requests an inclusive `yyyy-MM-dd` date range and applies that range in the Exchange query.
2. Use [CheckSPOProv.ps1](../../../CheckSPOProv.ps1) only for legacy compatibility or a specifically requested fixed date range. It retrieves every Microsoft 365 group, so state the expected tenant-scale impact before running it.
3. Read the selected script's existing guide before recommending commands: [date-scoped diagnostic guide](../../../docs/CheckforSDSProvFails.md) or [legacy diagnostic guide](../../../docs/CheckSPOProv.md).

## Preflight

1. Confirm the operator's intended tenant, the narrowest useful date range, and whether opening CSV files in the local default application is acceptable.
   If the operator does not want files opened automatically, either use a switch/parameter that suppresses opening (if the script supports one) or, under Modify a Diagnostic Safely, add such a parameter before the run; otherwise tell the operator the files will open and confirm before proceeding.
2. Confirm `Microsoft.Graph` and `ExchangeOnlineManagement` are available. Do not install modules, initiate sign-in, or select an account automatically. If either module is missing, stop and provide the operator the `Install-Module` command to run themselves. If `Get-MgContext` returns nothing or `Get-OrganizationConfig` fails, stop and ask the operator to run the `Connect-*` commands and re-verify before any diagnostic run; do not proceed with a partial session.
3. Tell the operator to establish both sessions before a diagnostic run:

   ```powershell
   Connect-ExchangeOnline
   Connect-MgGraph -Scopes 'Group.Read.All'
   ```

4. The preferred script validates both connections. For the legacy script, verify the Exchange session explicitly because it only validates Graph.

   ```powershell
   Get-OrganizationConfig | Select-Object OrganizationId
   Get-MgContext
   ```

## Run and Interpret

1. Instruct the operator to run the chosen script in their authenticated session only after they have confirmed the tenant and range; do not execute the script yourself. Provide the exact command and the date values to enter at the interactive prompts. The diagnostic scripts are read-only but can issue many tenant queries.
2. For `CheckforSDSProvFails.ps1`, enter dates in `yyyy-MM-dd`; the entered end date is inclusive.
3. Explain that the date-scoped script may produce up to two CSV files under `%TEMP%\TeamSiteTrigger\` and opens non-empty results automatically. No file is created for an empty report.
4. Classify findings precisely:
   - A missing-site finding is a hidden-membership, Team-enabled group in range with an empty `SharePointSiteUrl`.
   - A non-teamified finding is a group without the `Team` provisioning option whose SDS education extension identifies it as a `Section`.
5. Report the evidence from the CSV columns, the requested date range, and any per-group Graph inspection warnings. Do not infer that an empty report proves SDS is healthy outside that range.

## Modify a Diagnostic Safely

1. Preserve existing connection validation, interactive date validation, CSV schema, and read-only behavior unless the request explicitly changes one of those contracts.
2. Keep Exchange filtering server-side and date-bounded in the preferred script. Do not replace it with a tenant-wide retrieval.
3. Keep per-group Graph failures recoverable with `Write-Warning` so one inaccessible group does not discard the remaining report.
4. Treat the SDS education extension attribute as a service-defined SDS constant. Preserve its established value and ask before changing it. Do not recommend replacing standard SDS `resourceBehaviorOptions` or `creationOptions` with values from Teams-client-created classes unless the task explicitly changes the provisioning model.
5. Parse-check every changed PowerShell script before an authenticated run:

   ```powershell
   $tokens = $null
   $errors = $null
   [System.Management.Automation.Language.Parser]::ParseFile('.\CheckforSDSProvFails.ps1', [ref] $tokens, [ref] $errors) | Out-Null
   $errors
   ```

## Completion Criteria

- The operator knows which tenant and date range the report covers.
- Both Graph and Exchange Online connections are verified before execution.
- Findings are separated into missing SharePoint sites and non-teamified SDS sections.
- The final result identifies CSV paths or explicitly states that no matching records were found.
- No tenant-changing command is run as part of this diagnostic workflow.