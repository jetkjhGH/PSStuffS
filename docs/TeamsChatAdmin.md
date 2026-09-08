# Teams Chat Admin

`ChatManagementInterface.ps1` launches the `TeamsChatAdmin` PowerShell 7 module for Microsoft Teams chat inspection, reporting, and guarded administrative actions through Microsoft Graph.

## What it does

Use this tool to inspect Teams chat threads before taking administrative action. It helps an admin identify the right thread by user, participant list, topic, last-message preview, and chat ID.

The module currently provides:

- Graph SDK context inspection through `Test-TeamsChatGraphAccess`.
- Permission-based capability detection through `Get-TeamsChatCapabilityProfile`.
- A documented capability matrix through `Get-TeamsChatCapabilityMatrix`.
- Read-only user chat listing through `Get-TeamsChatByUser`.
- Direct chat inspection by chat ID through `Get-TeamsChatThread`, including deleted-chat lookup when deletion permission is available.
- Non-destructive deletion preview objects through `Get-TeamsChatDeletePlan`.
- Guarded single-chat soft deletion through `Remove-TeamsChatThread`.
- Guarded bulk chat soft deletion through `Remove-TeamsChatThreadsBulk`.
- Deleted-chat restore through `Restore-TeamsChatDeletedThread`.
- Audit-backed restore candidate listing through `Get-TeamsChatRestoreCandidate`.
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

## Admin Distribution Guide

For customer/admin download, extract, prerequisite, and launch instructions, use the distribution runbook:

- [Teams Chat Admin Distribution Runbook](TeamsChatAdmin-Distribution.md)

That runbook is also copied into every generated package as `README_DISTRIBUTION.md`.

## Launch From Source

These commands are for maintainers or admins running from the repository source tree. Admins running the packaged zip should follow the distribution runbook.

Default launch prompts you to choose whether to continue in the terminal or use the optional Windows GUI when Windows Forms is available:

```powershell
.\ChatManagementInterface.ps1
```

Terminal mode:

```powershell
.\ChatManagementInterface.ps1 -UiMode Terminal
```

On startup, the interface shows Graph connection status, read capability, deletion permission status, deletion workflow status, and the audit path. If deletion permission is present, the interface asks whether to enable deletion workflows for the current session. Choosing read-only mode leaves deletion and restore commands unavailable from the menu until option 9 enables them.

Windows GUI mode, when Windows Forms is available:

```powershell
.\ChatManagementInterface.ps1 -UiMode Windows
```

The Windows GUI keeps normal selections, chat listing, single-chat inspection, bulk inspection, delete, restore, audit viewing, and help output inside the GUI. Enable deletion and restore workflows from the Status panel when the current Graph context has deletion permission. List, inspect, bulk, delete, and restore inputs/results are preserved while moving between panels. Selecting a row in List Chats stores that chat as the current selection; Inspect One Chat and Delete Chat can both use that current chat ID. The Delete Chat panel can preview and delete a chat with exact typed confirmation in a full-width confirmation dialog for long chat IDs. The Restore Chat panel can load audit-log candidates or accept a pasted deleted chat ID, preview the restore, and execute it with typed confirmation. Terminal mode remains the cross-platform fallback.

Noninteractive capability check:

```powershell
.\ChatManagementInterface.ps1 -NonInteractive
```

From the terminal menu, enter `G` to open the Windows GUI without restarting the tool. Existing session state, including the last chat list and deletion/restore mode, is passed into the GUI.

## Create A Portable Package

This section is for maintainers preparing the zip file for admins. Admins should follow the [distribution runbook](TeamsChatAdmin-Distribution.md) instead.

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

The package script validates staged PowerShell files with the parser before creating the zip. Keep `ChatManagementInterface.ps1` beside `src`; the launcher imports `src\TeamsChatAdmin.psd1` relative to its own location.

## Read-only reporting

List chats for a user:

```powershell
Import-Module .\src\TeamsChatAdmin.psd1 -Force
Get-TeamsChatByUser -UserId user@contoso.edu -IncludeLastMessagePreview -All
```

`Get-TeamsChatByUser` uses Microsoft Graph `/users/{id}/chats`, supports pagination with `-All`, and can request `members` or `lastMessagePreview` expansions.

Search for shared threads between two users:

```powershell
Get-TeamsChatBetweenUsers -UserId user1@contoso.edu -OtherUser user2@contoso.edu -All
```

This lists chats for the first user, expands members and last-message preview, then filters to chats where the second user appears by user ID, email, display name, or participant text. In the terminal interface, option `10` runs the same search and stores the results as the current row-number list for inspection or deletion.

In the interactive interface, chat listing requests both expansions and stores the last result set with row numbers. Each result prints as a compact row block with display-name participants, topic, preview sender, preview timestamp, and a shortened message preview when Microsoft Graph returns those fields. One-on-one chats often have a blank topic, so participant names are the primary inspection signal for deciding whether the thread is the intended target. Microsoft Graph currently limits expanded chat members to 25 entries, which is enough for one-on-one inspection but can be incomplete for larger group or meeting chats.

Use option 3 to select a row number from that list instead of copying a long chat ID from a truncated table. Type `F` at the option 3 prompt to show full stored chat IDs, participant details with email addresses, and full preview text.

## Interactive inspection and deletion workflows

Option 3 is single-chat inspection only. It collects a chat ID or row number and shows the cached inspection details when available. For pasted IDs, it checks the active chat endpoint first; if that returns not found and the current Graph context has deletion permission, it checks `GET /teamwork/deletedChats/{deletedChatId}` and reports `ChatStatus = Deleted`. It never asks for a deletion reason or deletion confirmation.

Option 4 is multiple-chat inspection only. It can use pasted IDs, all rows from the last chat list, or a CSV file with a `ChatId` column. It de-duplicates targets, shows option-3-style details for cached chat IDs, and retrieves missing chat IDs directly from Microsoft Graph when permissions allow, including the deleted-chat fallback for not-found active chats. It never asks for a deletion reason or deletion confirmation.

Option 5 is single-chat deletion. It first runs the same inspection as option 3, then asks for a reason, shows a deletion preview, asks whether to execute, and requires typing the exact chat ID.

Option 6 is multiple-chat deletion. It first runs the same inspection as option 4, then asks for a reason, shows a deletion preview, asks whether to execute, and requires typing `DELETE`.

Option 8 shows the audit log. Option 9 enables or disables deletion and restore workflows for the current session. Option 10 searches for shared chat threads between two users and stores the results for row-number inspection or deletion. `G` launches the Windows GUI from the terminal menu.

The preview engine is also available directly:

```powershell
Get-TeamsChatDeletePlan -ChatId '19:example@thread.v2' -Reason 'Legal hold cleanup validation'
```

Direct command use supports `-WhatIf`. The `-WhatIf` path previews the Graph delete action only; it does not create the audit directory or write an audit CSV because no deletion request was sent.

```powershell
Remove-TeamsChatThread -ChatId '19:example@thread.v2' -Reason 'Approved admin action' -TypedConfirmation '19:example@thread.v2' -WhatIf
```

Bulk deletion requires the literal `DELETE` typed confirmation and honors tenant throttling guidance:

```powershell
$chatIds | Remove-TeamsChatThreadsBulk -Reason 'Approved bulk admin action' -TypedConfirmation DELETE -WhatIf
```

Without `-WhatIf`, these commands call Microsoft Graph `DELETE /chats/{chat-id}` only when the capability profile confirms deletion permissions and `ShouldProcess` approves the target.

## Supported Adjustments

| Adjustment | Where | Notes |
| --- | --- | --- |
| UI mode | `-UiMode Terminal`, `-UiMode Windows`, or `Auto` | `Auto` prompts at launch. GUI mode requires Windows Forms; terminal mode is the fallback. |
| Package output | `tools\Publish-TeamsChatAdminPackage.ps1 -OutputPath` | Use this to publish a zip somewhere other than `dist\`. |
| Package name | `tools\Publish-TeamsChatAdminPackage.ps1 -PackageName` | Keep the default unless producing a customer-specific artifact. |
| Audit path | Public deletion commands expose `-AuditPath`; the launcher currently uses the default | Use a durable approved location when audit retention is required. |
| Graph scopes | Connect before launch with the needed scopes | The tool warns when Graph SDK commands are missing but never installs modules or signs in automatically. |

Changing Graph endpoints, permission gates, deletion safeguards, or restore behavior is a developer change. Validate those changes against current Microsoft Graph documentation and a test tenant before using them in production.

## Audit output

Deletion attempts write audit rows to:

```text
%TEMP%\EDU Scripts\TeamsChatAdmin\TeamsChatAdminAudit.csv
```

The audit file records timestamp, local operator identity, action, chat ID, status, reason, and error text.

## Deleted-chat restore

Microsoft Graph supports restoring deleted chats with:

```http
POST /teamwork/deletedChats/{deletedChatId}/undoDelete
```

The Microsoft Graph PowerShell SDK command is:

```powershell
Undo-MgTeamworkDeletedChatDelete -DeletedChatId $deletedChatId
```

Option 7 lists restore candidates from the current audit log and any `*TeamsChatAdminAudit*.csv` files in the working folder, then also allows a pasted deleted chat ID. Restore requires deletion permission, deletion/restore mode enabled for the session, an execution confirmation, and typing the exact deleted chat ID.

The restore window is seven days after soft-delete. Restore operations are not supported for non-admin users. Successful restore attempts are written to the audit log as `Action = RestoreDeletedChat` and `Status = Restored`.