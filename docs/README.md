# Documentation

Operator guides for the PowerShell utilities and the Teams Chat Admin package.

## Guides by script family

| Script family | Guide(s) |
| --- | --- |
| [Single Script Tools](../Single%20Script%20Tools) | [New-EducationClassTeams.md](New-EducationClassTeams.md), [GetGroupsBrokenSPO.md](GetGroupsBrokenSPO.md), [IdentifyClassesNoChannelActiivity.md](IdentifyClassesNoChannelActiivity.md), [Remove-Targeted-Section-Memberships.md](Remove-Targeted-Section-Memberships.md) |
| [Script Packages/TeamsChatAdmin](../Script%20Packages/TeamsChatAdmin) | [TeamsChatAdmin.md](TeamsChatAdmin.md), [TeamsChatAdmin-Distribution.md](TeamsChatAdmin-Distribution.md) |
| Legacy/reference scripts | [CheckforSDSProvFails.md](CheckforSDSProvFails.md), [CheckSPOProv.md](CheckSPOProv.md), [Create-Graph-API-Teams-Class-Teams-SDS-Options.md](Create-Graph-API-Teams-Class-Teams-SDS-Options.md) |

Start with the root [README.md](../README.md) to choose a tool, then read its guide before connecting to Microsoft 365 or making tenant changes.

## Folder structure by script type

```text
PSStuffS/
├─ docs/                                                    # Operator runbooks and task-specific guides
│  ├─ README.md                                             # Documentation index
│  ├─ New-EducationClassTeams.md                            # Class Team creation workflow
│  ├─ GetGroupsBrokenSPO.md                                 # SharePoint provisioning diagnosis
│  ├─ IdentifyClassesNoChannelActiivity.md                  # General-channel activity reporting
│  ├─ Remove-Targeted-Section-Memberships.md                # CSV-driven membership cleanup
│  ├─ TeamsChatAdmin.md                                     # Chat admin module usage and commands
│  ├─ TeamsChatAdmin-Distribution.md                        # Package distribution and deployment guide
│  ├─ CheckforSDSProvFails.md                               # Legacy SDS provisioning diagnostic
│  ├─ CheckSPOProv.md                                       # Legacy SharePoint provisioning report
│  └─ Create-Graph-API-Teams-Class-Teams-SDS-Options.md     # Legacy Graph API examples
├─ Single Script Tools/                                      # Standalone utilities grouped by admin task type
│  ├─ New-EducationClassTeams.ps1                            # Create class Teams in batches
│  ├─ GetGroupsBrokenSPO.ps1                                 # Find and remediate 
│  ├─ Remove-Targeted_Section_Memberships.ps1                # Remove non-owner section members by CSV
missing SharePoint sites
│  └─ IdentifyClassesNoChannelActiivity.ps1                  # Audit General-channel activity
├─ Script Packages/                                          # Distribution-ready module packages
│  └─ TeamsChatAdmin/                                        # Teams Chat Admin package and PowerShell module
│     ├─ ChatManagementInterface.ps1                         # Entry point for the package
│     ├─ src/                                               # Module source and public/private functions
│     │  ├─ TeamsChatAdmin.psd1                              # Module manifest
│     │  ├─ TeamsChatAdmin.psm1                              # Module entry script
│     │  ├─ Authentication/                                  # Graph access checks and capability discovery
│     │  ├─ Graph/                                           # Graph request helpers
│     │  ├─ Public/                                          # Admin-facing cmdlets and workflows
│     │  ├─ Private/                                         # Internal conversion and formatting helpers
│     │  ├─ Audit/                                           # Audit log generation and retention helpers
│     │  └─ UI/                                              # Terminal and Windows GUI interfaces
│     └─ README.md                                           # Package-specific guidance when present
├─ tools/                                                    # Repository tooling and packaging scripts
│  └─ Publish-TeamsChatAdminPackage.ps1                       # Build package ZIP for distribution
├─ legacy-tests/                                             # Historical scripts and reference examples
│  ├─ CheckforSDSProvFails.ps1                               # Legacy SDS validation script
│  ├─ CheckSPOProv.ps1                                       # Legacy tenant-wide SharePoint diagnostic
│  ├─ Create Graph API Teams (Class Teams - SDS Options).ps1 # Historical Graph API examples
│  └─ README.md                                              # Notes for legacy examples
├─ README.md                                                 # Primary entry point and overview
├─ AGENTS.md                                                  # Repository guidance and conventions
└─ docs/README.md                                            # Guide index
```
