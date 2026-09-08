# Single Script Tools

This folder contains maintained standalone PowerShell utilities for Microsoft 365 education administration. Read the matching guide before running a script, especially before tenant-writing actions.

| Script | Purpose | Guide |
| --- | --- | --- |
| [New-EducationClassTeams.ps1](New-EducationClassTeams.ps1) | Batch creation of activated or non-activated education class Teams. | [Guide](../docs/New-EducationClassTeams.md) |
| [GetGroupsBrokenSPO.ps1](GetGroupsBrokenSPO.ps1) | Diagnose group/site divergence and optionally request site provisioning after revalidation. | [Guide](../docs/GetGroupsBrokenSPO.md) |
| [IdentifyClassesNoChannelActiivity.ps1](IdentifyClassesNoChannelActiivity.ps1) | Report General-channel user and system/service activity for selected class Teams. | [Guide](../docs/IdentifyClassesNoChannelActiivity.md) |
| [Remove-Targeted_Section_Memberships.ps1](Remove-Targeted_Section_Memberships.ps1) | Remove non-owner members from CSV-targeted groups and record successful removals. | [Guide](../docs/Remove-Targeted-Section-Memberships.md) |

Legacy and reference scripts are kept separately in [legacy-tests](../legacy-tests/).
