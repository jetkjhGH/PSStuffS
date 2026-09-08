# Script Packages

This folder contains multi-file, redistributable PowerShell packages. Each package keeps its launcher beside its source module tree so it can be staged and distributed without altering relative paths.

| Package | Purpose | Documentation |
| --- | --- | --- |
| [TeamsChatAdmin](TeamsChatAdmin/) | Microsoft Teams chat inspection, user search, guarded deletion, restore, and audit tooling. | [Usage guide](../docs/TeamsChatAdmin.md) and [distribution runbook](../docs/TeamsChatAdmin-Distribution.md) |

Use [Publish-TeamsChatAdminPackage.ps1](../tools/Publish-TeamsChatAdminPackage.ps1) from the repository root to create the versioned distributable ZIP.
