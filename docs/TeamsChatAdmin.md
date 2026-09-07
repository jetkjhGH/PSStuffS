# Teams Chat Admin

`ChatManagementInterface.ps1` launches the `TeamsChatAdmin` PowerShell 7 module for Microsoft Teams chat inspection, reporting, and guarded administrative actions through Microsoft Graph.

## Current implementation

The initial implementation provides:

- Graph SDK context inspection through `Test-TeamsChatGraphAccess`.
- Permission-based capability detection through `Get-TeamsChatCapabilityProfile`.
- A documented capability matrix through `Get-TeamsChatCapabilityMatrix`.
- Read-only user chat listing through `Get-TeamsChatByUser`.
- Direct chat inspection by chat ID through `Get-TeamsChatThread`.
- Non-destructive deletion preview objects through `Get-TeamsChatDeletePlan`.
- Guarded single-chat soft deletion through `Remove-TeamsChatThread`.
- Guarded bulk chat soft deletion through `Remove-TeamsChatThreadsBulk`.
- Terminal and optional Windows Forms GUI entrypoints.

Deletion commands are not diagnostic shortcuts. They require supported Graph deletion permissions, a deletion-enabled session choice in the interface, PowerShell `ShouldProcess`, typed confirmation, and audit logging.

## Requirements

- PowerShell 7 or later.
- Microsoft Graph PowerShell SDK.
- An existing Microsoft Graph connection with the permissions required for the action.

Example read-only connection:

```powershell
Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All
```

Example deletion-capable connection, subject to tenant policy and admin consent:

```powershell
Connect-MgGraph -Scopes Chat.ManageDeletion.All
```

For application permissions, grant and consent to the corresponding Graph application permissions before using an app-only Graph context.

`Get-MgContext` can still show a connected context after the underlying access token has expired. The module checks Graph request failures for `401 Unauthorized` and `InvalidAuthenticationToken`; when detected, the interface returns to the menu and prompts you to reconnect with `Connect-MgGraph` before retrying the operation.

## Launching

## Admin Quick Start From Zip

Give admins the generated `TeamsChatAdmin-<version>.zip` file from the `dist` folder.

1. Download `TeamsChatAdmin-<version>.zip` to the admin workstation.
2. Right-click the zip file, select **Properties**, choose **Unblock** if it is present, then select **OK**.
3. Extract the zip to a local folder such as `C:\Tools\TeamsChatAdmin`.
4. Open PowerShell 7 in the extracted folder:

	```powershell
	cd C:\Tools\TeamsChatAdmin
	```

5. If script execution is blocked, allow scripts for only this PowerShell process:

	```powershell
	Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
	```

6. Install the Microsoft Graph PowerShell SDK if it is not already installed:

	```powershell
	Install-Module Microsoft.Graph -Scope CurrentUser
	```

7. Connect to Microsoft Graph with read-only chat scopes:

	```powershell
	Connect-MgGraph -Scopes Chat.ReadBasic.All, Chat.Read.All
	```

8. Run the tool:

	```powershell
	.\ChatManagementInterface.ps1
	```

9. Choose terminal or Windows GUI when prompted. For GUI-only launch:

	```powershell
	.\ChatManagementInterface.ps1 -UiMode Windows
	```

For deletion workflows, reconnect with deletion permissions after required tenant/admin consent is in place:

```powershell
Connect-MgGraph -Scopes Chat.ManageDeletion.All
```

The extracted package must keep `ChatManagementInterface.ps1` beside the `src` folder.

Default launch prompts you to choose whether to continue in the terminal or use the optional Windows GUI when Windows Forms is available:

```powershell
.\ChatManagementInterface.ps1
```

Terminal mode:

```powershell
.\ChatManagementInterface.ps1 -UiMode Terminal
```

On startup, the interface shows Graph connection status, read capability, deletion permission status, deletion workflow status, and the audit path. If deletion permission is present, the interface asks whether to enable deletion workflows for the current session. Choosing read-only mode leaves deletion commands unavailable from the menu until option 7 enables them.

Windows GUI mode, when Windows Forms is available:

```powershell
.\ChatManagementInterface.ps1 -UiMode Windows
```

The Windows GUI keeps normal selections, chat listing, single-chat inspection, bulk inspection, audit viewing, and help output inside the GUI. List, inspect, and bulk inputs/results are preserved while moving between panels. Selecting a row in List Chats stores that chat as the current selection; Inspect One Chat pre-fills that chat ID and keeps the previous inspection output available for copying. Deletion execution remains guarded in terminal workflows for this milestone and will move into dedicated GUI panels after the shared workflow helpers are extracted. Terminal mode remains the cross-platform fallback.

Noninteractive capability check:

```powershell
.\ChatManagementInterface.ps1 -NonInteractive
```

## Portable Package

Create a customer-ready package from the repository root:

```powershell
.\tools\Publish-TeamsChatAdminPackage.ps1
```

The packaging script creates a versioned folder and zip under `dist\`, containing:

```text
TeamsChatAdmin-<version>/
	ChatManagementInterface.ps1
	README_DISTRIBUTION.md
	src/
```

Use `-NoZip` to create only the staged folder:

```powershell
.\tools\Publish-TeamsChatAdminPackage.ps1 -NoZip
```

## Read-only reporting

List chats for a user:

```powershell
Import-Module .\src\TeamsChatAdmin.psd1 -Force
Get-TeamsChatByUser -UserId user@contoso.edu -IncludeLastMessagePreview -All
```

`Get-TeamsChatByUser` uses Microsoft Graph `/users/{id}/chats`, supports pagination with `-All`, and can request `members` or `lastMessagePreview` expansions.

In the interactive interface, chat listing requests both expansions and stores the last result set with row numbers. Each result prints as a compact row block with display-name participants, topic, preview sender, preview timestamp, and a shortened message preview when Microsoft Graph returns those fields. One-on-one chats often have a blank topic, so participant names are the primary inspection signal for deciding whether the thread is the intended target. Microsoft Graph currently limits expanded chat members to 25 entries, which is enough for one-on-one inspection but can be incomplete for larger group or meeting chats.

Use option 3 to select a row number from that list instead of copying a long chat ID from a truncated table. Type `F` at the option 3 prompt to show full stored chat IDs, participant details with email addresses, and full preview text.

## Interactive deletion workflows

Option 3 is the single-chat workflow. It collects a chat ID or row number and shows the cached inspection details when available. If the current Graph context does not include deletion permission, the workflow stops after inspection and does not create a deletion preview. If deletion permission exists, it asks for a reason, shows a deletion preview, optionally runs `-WhatIf`, then asks whether to execute. Execution requires typing the exact chat ID.

Option 4 is the bulk workflow. It can use pasted IDs, all rows from the last chat list, or a CSV file with a `ChatId` column. In inspection-only mode, it de-duplicates targets, shows option-3-style details for cached chat IDs, and retrieves missing chat IDs directly from Microsoft Graph when permissions allow. If deletion permission exists, it then shows target count and a deletion preview before offering `-WhatIf` and execution. Execution requires typing `DELETE`.

The preview engine is also available directly:

```powershell
Get-TeamsChatDeletePlan -ChatId '19:example@thread.v2' -Reason 'Legal hold cleanup validation'
```

Single-chat deletion requires the exact chat ID as typed confirmation and supports `-WhatIf`:

```powershell
Remove-TeamsChatThread -ChatId '19:example@thread.v2' -Reason 'Approved admin action' -TypedConfirmation '19:example@thread.v2' -WhatIf
```

Bulk deletion requires the literal `DELETE` typed confirmation and honors tenant throttling guidance:

```powershell
$chatIds | Remove-TeamsChatThreadsBulk -Reason 'Approved bulk admin action' -TypedConfirmation DELETE -WhatIf
```

Without `-WhatIf`, these commands call Microsoft Graph `DELETE /chats/{chat-id}` only when the capability profile confirms deletion permissions and `ShouldProcess` approves the target.

## Audit output

Deletion attempts write audit rows to:

```text
%TEMP%\EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv
```

The audit file records timestamp, local operator identity, action, chat ID, status, reason, and error text.

## Deleted-chat restore

Microsoft Graph delete documentation describes a seven-day restore window after chat soft-delete. Restore support remains capability-gated until the exact restore endpoint is verified in public Microsoft Graph documentation for the tenant/runtime being used.