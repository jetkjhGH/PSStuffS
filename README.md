# PSStuffS

PowerShell utilities for Microsoft 365 education environments, including School Data Sync
(SDS) diagnostics and Microsoft Graph-based class Team creation.

## Scripts

| Script | Purpose | Documentation |
| --- | --- | --- |
| `New-EducationClassTeams.ps1` | Interactively creates activated or non-activated `educationClass` Teams in batches. | [Read the guide](docs/New-EducationClassTeams.md) |
| `Create Graph API Teams (Class Teams - SDS Options).ps1` | Legacy examples for creating one non-activated class Team and one activated class Team. | [Read the guide](docs/Create-Graph-API-Teams-Class-Teams-SDS-Options.md) |
| `CheckforSDSProvFails.ps1` | Reports SDS class Teams without SharePoint sites and SDS groups that were not teamified. | [Read the guide](docs/CheckforSDSProvFails.md) |
| `CheckSPOProv.ps1` | Earlier reporting script for SharePoint provisioning and non-teamified SDS groups. | [Read the guide](docs/CheckSPOProv.md) |
| `GetGroupsBrokenSPO.ps1` | Diagnoses group/site divergence and can explicitly request site provisioning for revalidated missing-site candidates. | [Read the guide](docs/GetGroupsBrokenSPO.md) |
| `IdentifyClassesNoChannelActiivity.ps1` | Reports General-channel user and system/service activity for selected class Teams. | [Read the guide](docs/IdentifyClassesNoChannelActiivity.md) |

## General requirements

- Windows PowerShell 5.1 or PowerShell 7
- Permission to run local PowerShell scripts
- A Microsoft 365 account with access appropriate to the selected script
- The Microsoft Graph PowerShell SDK for Graph-based scripts
- The Exchange Online PowerShell module for scripts that use `Get-UnifiedGroup`

Install the modules for the current user:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

The scripts do not store credentials. Authenticate through the Microsoft sign-in windows
opened by `Connect-MgGraph` and `Connect-ExchangeOnline`.

Repository-owned report scripts write their default outputs beneath `%TEMP%\EDU Scripts\`.
Each script keeps a separate report subfolder there; see its guide for the exact path.

If local execution policy blocks a script, allow it only for the current PowerShell process:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

See the individual guides for required connections and scopes.
