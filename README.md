# PSStuffS

PowerShell utilities for Microsoft 365 education environments, including School Data Sync
(SDS) diagnostics and Microsoft Graph-based class Team creation.

## Repository Layout

- `Script Packages\TeamsChatAdmin\` contains the Teams Chat Admin launcher and its `src` module tree.
- `Single Script Tools\` contains standalone PowerShell utilities.

## Single Script Tools

| Script | Purpose | Documentation |
| --- | --- | --- |
| [Single Script Tools\New-EducationClassTeams.ps1](Single%20Script%20Tools/New-EducationClassTeams.ps1) | Interactively creates activated or non-activated `educationClass` Teams in batches. | [Read the guide](docs/New-EducationClassTeams.md) |
| [Single Script Tools\GetGroupsBrokenSPO.ps1](Single%20Script%20Tools/GetGroupsBrokenSPO.ps1) | Diagnoses group/site divergence and can explicitly request site provisioning for revalidated missing-site candidates. | [Read the guide](docs/GetGroupsBrokenSPO.md) |
| [Single Script Tools\IdentifyClassesNoChannelActiivity.ps1](Single%20Script%20Tools/IdentifyClassesNoChannelActiivity.ps1) | Reports General-channel user and system/service activity for selected class Teams. | [Read the guide](docs/IdentifyClassesNoChannelActiivity.md) |
| [Single Script Tools\Remove-Targeted_Section_Memberships.ps1](Single%20Script%20Tools/Remove-Targeted_Section_Memberships.ps1) | Removes non-owner members from CSV-targeted groups and records successful removals. | [Read the guide](docs/Remove-Targeted-Section-Memberships.md) |

## Script Package

| Package | Purpose | Documentation |
| --- | --- | --- |
| [Script Packages\TeamsChatAdmin\ChatManagementInterface.ps1](Script%20Packages/TeamsChatAdmin/ChatManagementInterface.ps1) | Launches the PowerShell 7 Teams chat admin module for Graph-backed chat inspection, reporting, deletion previews, and guarded deletion. | [Read the guide](docs/TeamsChatAdmin.md) |

## General requirements

- Windows PowerShell 5.1 or PowerShell 7
- Permission to run local PowerShell scripts
- A Microsoft 365 account with access appropriate to the selected script
- The Microsoft Graph PowerShell SDK for Graph-based scripts
- The Exchange Online PowerShell module for scripts that use `Get-UnifiedGroup`
- PowerShell 7 is required for the Teams chat admin module

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

## Using The Guides

Each guide is written for an admin operator: start with **Purpose** to confirm why the script exists, then review **Requirements/Connect** before running it. Use each guide's configuration, adjustment, or troubleshooting section for supported tweaks. Warnings call out changes that alter report meaning, tenant scope, Graph permissions, or tenant-writing behavior and should be tested in a non-production tenant first.

Create a portable Teams Chat Admin customer package with:

```powershell
.\tools\Publish-TeamsChatAdminPackage.ps1
```
