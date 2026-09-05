# PSStuffS Agent Guide

## Scope

This repository contains interactive PowerShell utilities for Microsoft 365 education and School Data Sync (SDS). The root [README.md](README.md) is the setup entry point; use the matching guide in [docs](docs) for each script's operational procedure instead of duplicating it in code comments or new documentation.

## Working conventions

- Treat `New-EducationClassTeams.ps1` as the maintained production batch-creation script. Preserve `CmdletBinding`, `SupportsShouldProcess`, `Set-StrictMode -Version Latest`, and `$ErrorActionPreference = 'Stop'`; retain a useful `-WhatIf` path for tenant-writing changes.
- `Create Graph API Teams (Class Teams - SDS Options).ps1` is a legacy/example script. Do not use it as the template for production error handling or validation.
- Reporting scripts require an existing Microsoft Graph session and Exchange Online session. Creation scripts require an existing Graph session. Scripts validate connections but do not call `Connect-MgGraph` or `Connect-ExchangeOnline` themselves.
- Keep module and scope checks actionable. Graph commands must remain compatible with the Microsoft Graph PowerShell SDK; reporting code using `Get-UnifiedGroup` depends on ExchangeOnlineManagement.
- Preserve interactive validation loops and the established user-facing output style: `Write-Warning` for recoverable problems, `throw` for blocking prerequisites, and contextual `try`/`catch` around per-item remote operations when continuing is safe.
- Treat the SDS extension attribute and Graph/SharePoint resource behavior values as tenant-sensitive configuration. Only change these values when the task explicitly requests it; otherwise leave them untouched and call out in your response if a change appears necessary.
- Avoid credential storage, broad retries that hide non-transient errors, and unrelated formatting changes. Keep CSV output paths and columns backward compatible unless the task explicitly changes that contract.

## Validation

- Before an authenticated run, parse-check every changed script with PowerShell's parser, for example:

  ```powershell
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile('.\New-EducationClassTeams.ps1', [ref] $null, [ref] $errors) | Out-Null
  $errors
  ```

- After the operator confirms they have authenticated to a test tenant, run the changed creation script with `-WhatIf` yourself and report the output; never run it against an unconfirmed session, and never run the script without `-WhatIf`.
- Do not run tenant-writing paths, sign-in commands, or broad tenant reports automatically. Ask the operator to authenticate and choose the target tenant/date range.

## Script guides

- [New-EducationClassTeams guide](docs/New-EducationClassTeams.md): creation modes, naming tokens, scopes, and `-WhatIf` behavior.
- [CheckforSDSProvFails guide](docs/CheckforSDSProvFails.md): preferred date-scoped SDS provisioning diagnostic and CSV output.
- [CheckSPOProv guide](docs/CheckSPOProv.md): legacy report; avoid expanding its unrestricted tenant-wide query.
- [Graph API examples guide](docs/Create-Graph-API-Teams-Class-Teams-SDS-Options.md): limitations of the legacy reference examples.